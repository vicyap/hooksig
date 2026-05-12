defmodule Hooksig.StripeTest do
  use ExUnit.Case, async: true

  alias Hooksig.Stripe

  @secret "whsec_test_secret_aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa"
  @payload ~s({"id":"evt_123","type":"checkout.session.completed"})

  defp valid_inputs(payload \\ @payload, secret \\ @secret, ts \\ 1_700_000_000) do
    sig = :crypto.mac(:hmac, :sha256, secret, "#{ts}.#{payload}") |> Base.encode16(case: :lower)
    {payload, "t=#{ts},v1=#{sig}", secret, ts}
  end

  describe "verify/4" do
    test "accepts a valid signature within tolerance" do
      {payload, header, secret, ts} = valid_inputs()
      assert {:ok, result} = Stripe.verify(payload, header, secret, now: ts)
      assert result.ok?
      assert result.diagnosis == :valid
      assert result.timestamp == ts
      assert result.age_seconds == 0
      assert result.within_tolerance?
      assert result.hints == []
    end

    test "rejects a tampered payload" do
      {_payload, header, secret, ts} = valid_inputs()
      tampered = ~s({"id":"evt_456","type":"checkout.session.completed"})

      assert {:error, :signature_mismatch, result} =
               Stripe.verify(tampered, header, secret, now: ts)

      refute result.ok?
      assert result.diagnosis == :signature_mismatch
      assert result.expected_signature
      assert length(result.hints) > 0
    end

    test "rejects a stale timestamp outside tolerance" do
      {payload, header, secret, ts} = valid_inputs(@payload, @secret, 1_700_000_000)
      # 1 day later
      assert {:error, :timestamp_outside_tolerance, result} =
               Stripe.verify(payload, header, secret, now: ts + 86_400)

      assert result.match?
      refute result.within_tolerance?
      assert result.age_seconds == 86_400
      assert hd(result.hints) =~ "older than"
    end

    test "rejects timestamps in the future" do
      {payload, header, secret, ts} = valid_inputs()

      assert {:error, :timestamp_in_future, result} =
               Stripe.verify(payload, header, secret, now: ts - 10)

      assert result.match?
      assert result.diagnosis == :timestamp_in_future
    end

    test "errors on missing timestamp segment" do
      assert {:error, :missing_timestamp, result} =
               Stripe.verify(@payload, "v1=abcdef", @secret)

      assert result.diagnosis == :missing_timestamp
    end

    test "errors on missing v1 segment" do
      assert {:error, :missing_v1_signature, result} =
               Stripe.verify(@payload, "t=1700000000", @secret)

      assert result.diagnosis == :missing_v1_signature
    end

    test "errors on empty payload" do
      assert {:error, :empty_payload, _result} = Stripe.verify("", "t=1,v1=x", @secret)
    end

    test "errors on empty secret" do
      assert {:error, :empty_secret, _result} = Stripe.verify(@payload, "t=1,v1=x", "")
    end

    test "errors on empty signature header" do
      assert {:error, :empty_signature_header, _result} = Stripe.verify(@payload, "", @secret)
    end

    test "hints about non-whsec_ secret" do
      {payload, header, _, ts} = valid_inputs()
      bad_secret = "sk_test_imnotawebhooksecret"

      assert {:error, :signature_mismatch, result} =
               Stripe.verify(payload, header, bad_secret, now: ts)

      assert Enum.any?(result.hints, &String.contains?(&1, "whsec_"))
    end

    test "accepts multiple v1 signatures (key rotation)" do
      ts = 1_700_000_000

      sig1 =
        :crypto.mac(:hmac, :sha256, @secret, "#{ts}.#{@payload}") |> Base.encode16(case: :lower)

      sig_unrelated = String.duplicate("a", 64)
      header = "t=#{ts},v1=#{sig_unrelated},v1=#{sig1}"

      assert {:ok, %{ok?: true}} = Stripe.verify(@payload, header, @secret, now: ts)
    end
  end
end
