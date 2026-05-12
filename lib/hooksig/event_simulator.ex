defmodule Hooksig.EventSimulator do
  @moduledoc """
  Generates realistic Stripe webhook event payloads for testing handlers.
  Optionally signs the payload with a user-supplied secret to produce a
  verifiable `Stripe-Signature` header.
  """

  @event_types [
    {"checkout.session.completed", "Checkout session completed (customer paid)"},
    {"invoice.paid", "Invoice paid (subscription renewal)"},
    {"invoice.payment_succeeded", "Invoice payment succeeded"},
    {"invoice.payment_failed", "Invoice payment failed (dunning starts)"},
    {"customer.subscription.created", "Subscription created"},
    {"customer.subscription.updated", "Subscription updated"},
    {"customer.subscription.deleted", "Subscription canceled"},
    {"payment_intent.succeeded", "PaymentIntent succeeded"},
    {"payment_intent.payment_failed", "PaymentIntent failed"},
    {"charge.refunded", "Charge refunded"},
    {"customer.subscription.trial_will_end", "Trial ending in 3 days"}
  ]

  def event_types, do: @event_types

  def build(type, opts \\ []) do
    ts = Keyword.get(opts, :timestamp, System.system_time(:second))
    payload = payload_for(type, ts)
    Jason.encode!(payload)
  end

  def build_and_sign(type, secret, opts \\ []) do
    ts = Keyword.get(opts, :timestamp, System.system_time(:second))
    payload = build(type, timestamp: ts)
    sig = :crypto.mac(:hmac, :sha256, secret, "#{ts}.#{payload}") |> Base.encode16(case: :lower)
    %{payload: payload, signature: "t=#{ts},v1=#{sig}", timestamp: ts}
  end

  defp payload_for(type, ts) do
    %{
      id: "evt_" <> random_id(),
      object: "event",
      api_version: "2024-04-10",
      created: ts,
      livemode: false,
      pending_webhooks: 1,
      type: type,
      data: %{object: object_for(type, ts)},
      request: %{id: "req_" <> random_id(), idempotency_key: nil}
    }
  end

  defp object_for("checkout.session.completed", _ts) do
    %{
      id: "cs_test_" <> random_id(),
      object: "checkout.session",
      mode: "payment",
      payment_status: "paid",
      status: "complete",
      amount_total: 2999,
      amount_subtotal: 2999,
      currency: "usd",
      customer: "cus_" <> random_id(),
      customer_email: "jane@example.com",
      payment_intent: "pi_" <> random_id()
    }
  end

  defp object_for("invoice.paid", ts), do: invoice("paid", ts)
  defp object_for("invoice.payment_succeeded", ts), do: invoice("paid", ts)
  defp object_for("invoice.payment_failed", ts), do: invoice("open", ts)

  defp object_for("customer.subscription." <> _, ts) do
    %{
      id: "sub_" <> random_id(),
      object: "subscription",
      status: "active",
      customer: "cus_" <> random_id(),
      current_period_start: ts - 86_400,
      current_period_end: ts + 30 * 86_400,
      cancel_at_period_end: false,
      collection_method: "charge_automatically",
      items: %{
        object: "list",
        data: [
          %{
            id: "si_" <> random_id(),
            price: %{
              id: "price_" <> random_id(),
              product: "prod_" <> random_id(),
              unit_amount: 2999,
              currency: "usd",
              recurring: %{interval: "month"}
            },
            quantity: 1
          }
        ]
      }
    }
  end

  defp object_for("payment_intent." <> rest, _ts) do
    status = if rest == "succeeded", do: "succeeded", else: "requires_payment_method"

    %{
      id: "pi_" <> random_id(),
      object: "payment_intent",
      amount: 2999,
      currency: "usd",
      status: status,
      customer: "cus_" <> random_id()
    }
  end

  defp object_for("charge.refunded", _ts) do
    %{
      id: "ch_" <> random_id(),
      object: "charge",
      amount: 2999,
      amount_refunded: 2999,
      currency: "usd",
      refunded: true,
      status: "succeeded"
    }
  end

  defp object_for(_, _ts), do: %{}

  defp invoice(status, ts) do
    %{
      id: "in_" <> random_id(),
      object: "invoice",
      status: status,
      amount_paid: if(status == "paid", do: 2999, else: 0),
      amount_due: 2999,
      currency: "usd",
      customer: "cus_" <> random_id(),
      subscription: "sub_" <> random_id(),
      period_start: ts - 30 * 86_400,
      period_end: ts,
      collection_method: "charge_automatically",
      hosted_invoice_url: "https://invoice.stripe.com/i/example"
    }
  end

  defp random_id do
    :crypto.strong_rand_bytes(12) |> Base.encode16(case: :lower)
  end
end
