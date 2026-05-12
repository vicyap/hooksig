defmodule Hooksig.Tools do
  @moduledoc """
  Registry of every tool on hooksig. Drives the homepage grid, the sitemap,
  breadcrumbs, and related-tools lists.
  """

  @frameworks ~w(nextjs express laravel rails fastapi phoenix)

  @tools [
    %{
      slug: "stripe-webhook-signature-verifier",
      title: "Stripe Webhook Signature Verifier",
      short: "Verify Stripe-Signature headers",
      description:
        "Paste a payload, Stripe-Signature header, and whsec_ secret. We compute the expected HMAC-SHA256 signature and explain exactly why verification failed.",
      icon: "hero-shield-check",
      category: "Stripe",
      path: "/stripe/webhook-signature-verifier",
      live_view: HooksigWeb.StripeSignatureLive,
      frameworks: @frameworks
    },
    %{
      slug: "paddle-webhook-signature-verifier",
      title: "Paddle Webhook Signature Verifier",
      short: "Verify Paddle Billing v2 signatures",
      description:
        "Decode and verify Paddle Billing v2 webhook signatures. Paste the request body, the Paddle-Signature header, and your endpoint secret.",
      icon: "hero-shield-check",
      category: "Paddle",
      path: "/paddle/webhook-signature-verifier",
      live_view: HooksigWeb.PaddleSignatureLive,
      frameworks: @frameworks
    },
    %{
      slug: "lemon-squeezy-webhook-signature-verifier",
      title: "Lemon Squeezy Webhook Signature Verifier",
      short: "Verify Lemon Squeezy signatures",
      description:
        "Decode and verify Lemon Squeezy webhook signatures from the X-Signature header.",
      icon: "hero-shield-check",
      category: "Lemon Squeezy",
      path: "/lemon-squeezy/webhook-signature-verifier",
      live_view: HooksigWeb.LemonSqueezySignatureLive,
      frameworks: @frameworks
    },
    %{
      slug: "stripe-test-cards",
      title: "Stripe Test Cards",
      short: "Searchable test card library",
      description:
        "Complete library of Stripe test card numbers — success, decline, 3DS, insufficient funds, authentication required, fraud — with copy buttons and scenario filters.",
      icon: "hero-credit-card",
      category: "Stripe",
      path: "/stripe/test-cards",
      live_view: HooksigWeb.StripeTestCardsLive,
      frameworks: []
    },
    %{
      slug: "stripe-event-simulator",
      title: "Stripe Event Simulator",
      short: "Generate webhook payloads",
      description:
        "Build realistic Stripe event payloads for testing webhook handlers — optionally signed with your test secret to produce verifiable requests.",
      icon: "hero-bolt",
      category: "Stripe",
      path: "/stripe/event-simulator",
      live_view: HooksigWeb.StripeEventSimulatorLive,
      frameworks: []
    },
    %{
      slug: "stripe-proration-calculator",
      title: "Stripe Proration Calculator",
      short: "Compute proration line items",
      description:
        "Model an upgrade, downgrade, or seat change. See the exact proration line items Stripe would emit and the resulting invoice total.",
      icon: "hero-calculator",
      category: "Stripe",
      path: "/stripe/proration-calculator",
      live_view: HooksigWeb.StripeProrationLive,
      frameworks: []
    },
    %{
      slug: "stripe-event-semantics",
      title: "Stripe Event Semantics",
      short: "Pick the right Stripe event",
      description:
        "checkout.session.completed vs invoice.paid vs invoice.payment_succeeded vs payment_intent.succeeded — what fires when, and which one your handler should listen to.",
      icon: "hero-book-open",
      category: "Stripe",
      path: "/stripe/event-semantics",
      live_view: HooksigWeb.StripeEventSemanticsLive,
      frameworks: []
    },
    %{
      slug: "stripe-subscription-states",
      title: "Stripe Subscription State Machine",
      short: "Subscription status transitions",
      description:
        "Every Stripe subscription status — trialing, active, incomplete, past_due, canceled, unpaid, paused — and what triggers each transition.",
      icon: "hero-arrows-right-left",
      category: "Stripe",
      path: "/stripe/subscription-states",
      live_view: HooksigWeb.StripeSubscriptionStatesLive,
      frameworks: []
    }
  ]

  def all, do: @tools
  def categories, do: @tools |> Enum.map(& &1.category) |> Enum.uniq()
  def by_category, do: Enum.group_by(@tools, & &1.category)
  def frameworks, do: @frameworks
  def get(slug), do: Enum.find(@tools, &(&1.slug == slug))

  def framework_label("nextjs"), do: "Next.js"
  def framework_label("express"), do: "Express"
  def framework_label("laravel"), do: "Laravel"
  def framework_label("rails"), do: "Rails"
  def framework_label("fastapi"), do: "FastAPI"
  def framework_label("phoenix"), do: "Phoenix"
  def framework_label(slug), do: slug
end
