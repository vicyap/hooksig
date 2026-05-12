defmodule Hooksig.LemonSqueezy do
  @moduledoc """
  Lemon Squeezy webhook signature verification.

  Lemon Squeezy uses an `X-Signature` header containing only a hex-encoded
  HMAC-SHA256 of the raw request body — no timestamp.
  """

  @type result :: %{
          ok?: boolean(),
          signature: String.t() | nil,
          expected_signature: String.t() | nil,
          payload_preview: String.t() | nil,
          match?: boolean(),
          diagnosis: atom(),
          hints: [String.t()]
        }

  @spec verify(binary(), binary(), binary()) ::
          {:ok, result()} | {:error, atom(), result()}
  def verify(payload, signature_header, secret) do
    base = base_result()

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
        signature = String.trim(signature_header) |> String.downcase()
        expected = compute_signature(payload, secret)
        match? = Plug.Crypto.secure_compare(signature, expected)

        result = %{
          base
          | signature: signature,
            expected_signature: expected,
            payload_preview: preview(payload),
            match?: match?,
            ok?: match?,
            diagnosis: if(match?, do: :valid, else: :signature_mismatch),
            hints: hints(match?, payload)
        }

        if result.ok?, do: {:ok, result}, else: {:error, result.diagnosis, result}
    end
  end

  defp base_result do
    %{
      ok?: false,
      signature: nil,
      expected_signature: nil,
      payload_preview: nil,
      match?: false,
      diagnosis: :unknown,
      hints: []
    }
  end

  defp compute_signature(payload, secret) do
    :hmac
    |> :crypto.mac(:sha256, secret, payload)
    |> Base.encode16(case: :lower)
  end

  defp hints(true, _), do: []

  defp hints(false, payload) do
    [
      "The request body must be the raw bytes Lemon Squeezy posted. Frameworks that parse JSON and re-serialize will corrupt the signature.",
      "Confirm the signing secret matches the webhook URL in the Lemon Squeezy dashboard. Test-mode and live-mode webhooks use separate secrets.",
      "The `X-Signature` header is just hex — no `t=` or `v1=` prefix. If you see a prefix, you may be reading the wrong header."
    ]
    |> maybe_add_compact_json_hint(payload)
  end

  defp maybe_add_compact_json_hint(hints, <<"{", _::binary>> = payload) do
    if not String.contains?(payload, "\n") and String.contains?(payload, ":") do
      hints ++
        [
          "The payload looks like compact JSON on one line. If your framework re-serialized the body, the HMAC will not match."
        ]
    else
      hints
    end
  end

  defp maybe_add_compact_json_hint(hints, _), do: hints

  defp empty_payload_hints, do: ["Paste the raw request body Lemon Squeezy sent."]

  defp empty_secret_hints,
    do: [
      "Paste your Lemon Squeezy webhook signing secret. It is set when you create the webhook in the Lemon Squeezy dashboard."
    ]

  defp empty_header_hints,
    do: ["Paste the value of the `X-Signature` request header — a hex string."]

  defp preview(text) when byte_size(text) <= 200, do: text
  defp preview(text), do: binary_part(text, 0, 200) <> "…"
end
