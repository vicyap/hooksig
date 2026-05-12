defmodule Hooksig.Stripe do
  @moduledoc """
  Stripe webhook signature verification.

  Mirrors the verification step in Stripe's official SDKs
  (`stripe.Webhook.constructEvent`, `Stripe::Webhook.construct_event`, etc.)
  so a developer can paste a failing webhook, signature header, and signing
  secret and see exactly why verification failed.
  """

  @default_tolerance 300

  @type result :: %{
          ok?: boolean(),
          timestamp: integer() | nil,
          signatures: [String.t()],
          expected_signature: String.t() | nil,
          signed_payload_preview: String.t() | nil,
          match?: boolean(),
          age_seconds: integer() | nil,
          within_tolerance?: boolean(),
          tolerance_seconds: integer(),
          diagnosis: atom(),
          hints: [String.t()]
        }

  @doc """
  Verifies a Stripe webhook signature.

  Returns `{:ok, result}` when the signature is valid and the timestamp is
  within tolerance. Returns `{:error, reason, result}` otherwise. The `result`
  map always contains enough information to render the verification flow in a
  UI.

  Options:

    * `:tolerance` — max age in seconds, default `300` (matches Stripe SDKs).
    * `:now` — override "now" for deterministic testing (Unix seconds).
  """
  @spec verify(binary(), binary(), binary(), keyword()) ::
          {:ok, result()} | {:error, atom(), result()}
  def verify(payload, signature_header, secret, opts \\ []) do
    tolerance = Keyword.get(opts, :tolerance, @default_tolerance)
    now = Keyword.get(opts, :now, System.system_time(:second))
    base = base_result(tolerance)

    cond do
      not is_binary(payload) or payload == "" ->
        {:error, :empty_payload,
         %{base | diagnosis: :empty_payload, hints: empty_payload_hints()}}

      not is_binary(secret) or secret == "" ->
        {:error, :empty_secret, %{base | diagnosis: :empty_secret, hints: empty_secret_hints()}}

      not is_binary(signature_header) or signature_header == "" ->
        {:error, :empty_signature_header,
         %{base | diagnosis: :empty_signature_header, hints: empty_header_hints()}}

      true ->
        verify_parsed(payload, signature_header, secret, tolerance, now, base)
    end
  end

  defp base_result(tolerance) do
    %{
      ok?: false,
      timestamp: nil,
      signatures: [],
      expected_signature: nil,
      signed_payload_preview: nil,
      match?: false,
      age_seconds: nil,
      within_tolerance?: false,
      tolerance_seconds: tolerance,
      diagnosis: :unknown,
      hints: []
    }
  end

  defp verify_parsed(payload, header, secret, tolerance, now, base) do
    case parse_header(header) do
      {:ok, timestamp, signatures} ->
        signed_payload = "#{timestamp}.#{payload}"
        expected = compute_signature(signed_payload, secret)
        match? = Enum.any?(signatures, &secure_equal?(&1, expected))
        age = now - timestamp
        within? = age >= 0 and age <= tolerance

        result = %{
          base
          | timestamp: timestamp,
            signatures: signatures,
            expected_signature: expected,
            signed_payload_preview: preview(signed_payload),
            match?: match?,
            age_seconds: age,
            within_tolerance?: within?,
            ok?: match? and within?,
            diagnosis: diagnosis(match?, within?, age, tolerance),
            hints: hints(match?, within?, age, tolerance, payload, secret)
        }

        if result.ok?, do: {:ok, result}, else: {:error, result.diagnosis, result}

      {:error, reason} ->
        {:error, reason, %{base | diagnosis: reason, hints: header_parse_hints(reason)}}
    end
  end

  defp parse_header(header) do
    parts =
      header
      |> String.trim()
      |> String.split(",", trim: true)
      |> Enum.map(&String.split(&1, "=", parts: 2))

    timestamp =
      Enum.find_value(parts, fn
        ["t", value] -> parse_int(value)
        _ -> nil
      end)

    signatures =
      Enum.flat_map(parts, fn
        ["v1", value] -> [String.trim(value)]
        _ -> []
      end)

    cond do
      is_nil(timestamp) -> {:error, :missing_timestamp}
      signatures == [] -> {:error, :missing_v1_signature}
      true -> {:ok, timestamp, signatures}
    end
  end

  defp parse_int(value) do
    case Integer.parse(String.trim(value)) do
      {n, ""} -> n
      {_, _rest} -> nil
      :error -> nil
    end
  end

  defp compute_signature(signed_payload, secret) do
    :hmac
    |> :crypto.mac(:sha256, secret, signed_payload)
    |> Base.encode16(case: :lower)
  end

  defp secure_equal?(a, b) when is_binary(a) and is_binary(b),
    do: Plug.Crypto.secure_compare(a, b)

  defp secure_equal?(_, _), do: false

  defp diagnosis(true, true, _, _), do: :valid
  defp diagnosis(false, _, _, _), do: :signature_mismatch
  defp diagnosis(true, false, age, _) when age < 0, do: :timestamp_in_future
  defp diagnosis(true, false, _, _), do: :timestamp_outside_tolerance

  defp hints(true, true, _, _, _, _), do: []

  defp hints(false, _, _, _, payload, secret), do: mismatch_hints(payload, secret)

  defp hints(true, false, age, _, _, _) when age < 0,
    do: [
      "The `t=` timestamp is in the future. Check the system clock on the machine sending the webhook — a skewed clock will fail every signature."
    ]

  defp hints(true, false, _, tolerance, _, _),
    do: [
      "The signature matches, but the timestamp is older than #{tolerance}s. " <>
        "Stripe SDKs reject this by default to prevent replay attacks. " <>
        "When replaying an old event for testing, raise the tolerance."
    ]

  defp mismatch_hints(payload, secret) do
    base = [
      "Most common cause: the request body was parsed (JSON or form middleware) before verification. " <>
        "Use the raw request body bytes — do not re-serialize a parsed object.",
      "Confirm the signing secret matches this specific webhook endpoint. " <>
        "Each endpoint in the Stripe dashboard has its own `whsec_...` secret.",
      "Test mode events must be verified with the test-mode endpoint secret, and live mode events with the live-mode secret.",
      "Check that no proxy, CDN, or middleware is re-encoding the body (charset conversion, trailing newline, gzip)."
    ]

    base
    |> add_if(
      not String.starts_with?(secret, "whsec_"),
      "Your secret does not start with `whsec_`. Stripe webhook signing secrets always start with `whsec_`; you may be using a publishable or API key by mistake."
    )
    |> add_if(
      looks_recompacted?(payload),
      "The payload looks like compact JSON on a single line. If your framework parsed the body and you re-serialized it (`JSON.stringify`, `Jason.encode!`, etc.), the bytes no longer match what Stripe signed. Capture the raw body before any parser runs."
    )
  end

  defp empty_payload_hints,
    do: [
      "Paste the raw request body exactly as Stripe sent it. Do not pretty-print, re-serialize, or trim it."
    ]

  defp empty_secret_hints,
    do: [
      "Paste the webhook signing secret for this endpoint. It starts with `whsec_` and is shown in the Stripe Dashboard under Developers → Webhooks → your endpoint."
    ]

  defp empty_header_hints,
    do: [
      "Paste the value of the `Stripe-Signature` request header. It looks like `t=1700000000,v1=...`."
    ]

  defp header_parse_hints(:missing_timestamp),
    do: [
      "Could not find a `t=<unix-seconds>` segment in the signature header. " <>
        "Make sure you copied the full `Stripe-Signature` header, not just the signature value."
    ]

  defp header_parse_hints(:missing_v1_signature),
    do: [
      "Could not find a `v1=<hex>` segment. Stripe uses scheme `v1` for HMAC-SHA256 signatures. " <>
        "Old `v0` signatures are for the deprecated webhook signing version."
    ]

  defp header_parse_hints(_), do: []

  defp preview(text) when byte_size(text) <= 200, do: text
  defp preview(text), do: binary_part(text, 0, 200) <> "…"

  defp looks_recompacted?(<<"{", _::binary>> = payload) do
    not String.contains?(payload, "\n") and String.contains?(payload, ":")
  end

  defp looks_recompacted?(_), do: false

  defp add_if(list, true, hint), do: list ++ [hint]
  defp add_if(list, false, _), do: list
end
