defmodule Hooksig.Paddle do
  @moduledoc """
  Paddle Billing v2 webhook signature verification.

  Paddle signs each webhook with a header of the form:

      Paddle-Signature: ts=<unix-seconds>;h1=<sha256_hmac_hex>

  The signed payload is `<ts>:<raw_body>` (note the colon, not period like Stripe),
  HMAC'd with SHA-256 using the endpoint secret.
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
        signed_payload = "#{timestamp}:#{payload}"
        expected = compute_signature(signed_payload, secret)
        match? = Enum.any?(signatures, &Plug.Crypto.secure_compare(&1, expected))
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
            diagnosis: diagnosis(match?, within?, age),
            hints: hints(match?, within?, age, tolerance, payload)
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
      |> String.split(";", trim: true)
      |> Enum.map(&String.split(&1, "=", parts: 2))

    timestamp =
      Enum.find_value(parts, fn
        ["ts", value] -> parse_int(value)
        _ -> nil
      end)

    signatures =
      Enum.flat_map(parts, fn
        ["h1", value] -> [String.trim(value)]
        _ -> []
      end)

    cond do
      is_nil(timestamp) -> {:error, :missing_timestamp}
      signatures == [] -> {:error, :missing_h1_signature}
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

  defp diagnosis(true, true, _), do: :valid
  defp diagnosis(false, _, _), do: :signature_mismatch
  defp diagnosis(true, false, age) when age < 0, do: :timestamp_in_future
  defp diagnosis(true, false, _), do: :timestamp_outside_tolerance

  defp hints(true, true, _, _, _), do: []

  defp hints(false, _, _, _, payload) do
    [
      "The request body must be the raw bytes Paddle posted — most Paddle errors come from frameworks parsing or re-serializing the JSON.",
      "Confirm the secret matches this specific Paddle notification destination. Each destination has its own secret key.",
      "Paddle uses sandbox and live environments with separate secrets. A live event will not verify with a sandbox secret."
    ]
    |> maybe_add_compact_json_hint(payload)
  end

  defp hints(true, false, age, _, _) when age < 0,
    do: [
      "Timestamp is in the future. Check the system clock on the sender — a skewed clock will fail every signature."
    ]

  defp hints(true, false, _, tolerance, _),
    do: [
      "Signature matches but the timestamp is older than #{tolerance}s. Paddle SDKs reject this by default to prevent replay attacks."
    ]

  defp maybe_add_compact_json_hint(hints, <<"{", _::binary>> = payload) do
    if not String.contains?(payload, "\n") and String.contains?(payload, ":") do
      hints ++
        [
          "The payload looks like compact JSON. If your framework parsed it and you re-serialized, the bytes no longer match what Paddle signed."
        ]
    else
      hints
    end
  end

  defp maybe_add_compact_json_hint(hints, _), do: hints

  defp empty_payload_hints,
    do: ["Paste the raw request body exactly as Paddle sent it."]

  defp empty_secret_hints,
    do: [
      "Paste the secret key for this Paddle notification destination. It is shown in the Paddle Dashboard under Developer tools → Notifications → your destination."
    ]

  defp empty_header_hints,
    do: ["Paste the value of the `Paddle-Signature` header — e.g. `ts=1700000000;h1=…`."]

  defp header_parse_hints(:missing_timestamp),
    do: [
      "Could not find a `ts=<unix-seconds>` segment. Make sure you copied the full `Paddle-Signature` header."
    ]

  defp header_parse_hints(:missing_h1_signature),
    do: [
      "Could not find an `h1=<hex>` segment. Paddle Billing v2 uses `h1` for HMAC-SHA256 signatures."
    ]

  defp header_parse_hints(_), do: []

  defp preview(text) when byte_size(text) <= 200, do: text
  defp preview(text), do: binary_part(text, 0, 200) <> "…"
end
