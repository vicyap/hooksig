defmodule HooksigWeb.StripeEventSemanticsLive do
  use HooksigWeb, :live_view

  alias HooksigWeb.SEO

  @path "/stripe/event-semantics"
  @title "Stripe Event Semantics: checkout.session.completed vs invoice.paid vs payment_intent.succeeded | hooksig"
  @description "Which Stripe event should your webhook handler listen to? Disambiguate checkout.session.completed, invoice.paid, invoice.payment_succeeded, and payment_intent.succeeded with timing, payload differences, and use cases."

  @impl true
  def mount(_params, _session, socket) do
    {:ok,
     socket
     |> assign(:page_title, @title)
     |> assign(:page_description, @description)
     |> assign(:canonical_url, SEO.canonical_url(@path))
     |> assign(:structured_data, [
       SEO.software_application(%{title: @title, description: @description, path: @path}),
       SEO.breadcrumbs([
         {"hooksig", "/"},
         {"Tools", "/tools"},
         {"Stripe Event Semantics", @path}
       ]),
       SEO.faq([
         {"Should I use checkout.session.completed or invoice.paid for subscription signups?",
          "Use checkout.session.completed to provision the account on first purchase. Use invoice.paid (or invoice.payment_succeeded) for every renewal afterward."},
         {"What is the difference between invoice.paid and invoice.payment_succeeded?",
          "They fire at the same time and carry the same data. invoice.paid is the canonical name; invoice.payment_succeeded is an alias kept for legacy integrations. Subscribe to one, not both."},
         {"Does payment_intent.succeeded fire for subscription renewals?",
          "Only for the underlying payment. For subscription logic (granting access, etc.) listen to invoice.paid — it fires once per invoice and carries the subscription context."}
       ])
     ])}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.tool_page
      flash={@flash}
      title="Stripe Event Semantics"
      eyebrow="Stripe · Reference"
      icon="hero-book-open"
      description="A definitive guide to picking the right Stripe webhook event. Each event fires at a specific moment and carries different data — use the wrong one and your handler will miss renewals, double-provision, or charge twice."
    >
      <section class="prose prose-sm dark:prose-invert mt-8 max-w-3xl">
        <h2>The four "payment succeeded" events</h2>

        <h3><code phx-no-curly-interpolation>checkout.session.completed</code></h3>
        <p>
          Fires <strong>once</strong>
          when a Checkout session reaches a terminal state. For one-time payments and the first payment of a subscription, this is the canonical "the customer just paid you" signal.
        </p>
        <ul>
          <li>
            <strong>Use for:</strong> provisioning access on first purchase / subscription signup
          </li>
          <li>
            <strong>Do not use for:</strong> subscription renewals (fires only on the first checkout)
          </li>
          <li>
            <strong>Beware:</strong>
            for async payment methods (bank debit, etc.) the session is "complete" before the money clears. Check <code phx-no-curly-interpolation>payment_status === "paid"</code>.
          </li>
        </ul>

        <h3><code phx-no-curly-interpolation>invoice.paid</code></h3>
        <p>
          Fires every time a subscription invoice is paid — including the first one if it goes through Checkout, and every renewal after.
        </p>
        <ul>
          <li>
            <strong>Use for:</strong> subscription renewal logic, granting another period of access
          </li>
          <li>
            <strong>Carries:</strong>
            <code phx-no-curly-interpolation>subscription</code>, <code phx-no-curly-interpolation>customer</code>, <code phx-no-curly-interpolation>period_start</code>, <code phx-no-curly-interpolation>period_end</code>, amount, currency
          </li>
        </ul>

        <h3><code phx-no-curly-interpolation>invoice.payment_succeeded</code></h3>
        <p>
          An <strong>alias</strong>
          for <code phx-no-curly-interpolation>invoice.paid</code>. Same timing, same payload. Subscribe to one or the other — never both, or you will double-process.
        </p>

        <h3><code phx-no-curly-interpolation>payment_intent.succeeded</code></h3>
        <p>
          Fires when an individual PaymentIntent moves to <code phx-no-curly-interpolation>succeeded</code>. For subscriptions this is the underlying payment; for one-time charges it is the only signal.
        </p>
        <ul>
          <li>
            <strong>Use for:</strong>
            direct PaymentIntent integrations not using Checkout or Subscriptions
          </li>
          <li>
            <strong>Do not use for:</strong>
            subscription bookkeeping — listen to <code phx-no-curly-interpolation>invoice.paid</code>
            instead
          </li>
        </ul>

        <h2>Recommended subscriptions per integration type</h2>
        <table>
          <thead>
            <tr>
              <th>Integration</th>
              <th>Event(s) to subscribe to</th>
            </tr>
          </thead>
          <tbody>
            <tr>
              <td>Stripe Checkout, one-time payment</td>
              <td><code phx-no-curly-interpolation>checkout.session.completed</code></td>
            </tr>
            <tr>
              <td>Stripe Checkout, subscription</td>
              <td>
                <code phx-no-curly-interpolation>checkout.session.completed</code>
                + <code phx-no-curly-interpolation>invoice.paid</code>
                + <code phx-no-curly-interpolation>customer.subscription.deleted</code>
              </td>
            </tr>
            <tr>
              <td>Direct PaymentIntent</td>
              <td><code phx-no-curly-interpolation>payment_intent.succeeded</code></td>
            </tr>
            <tr>
              <td>Billing / Subscriptions API</td>
              <td>
                <code phx-no-curly-interpolation>invoice.paid</code>
                + <code phx-no-curly-interpolation>invoice.payment_failed</code>
                + <code phx-no-curly-interpolation>customer.subscription.*</code>
              </td>
            </tr>
          </tbody>
        </table>

        <h2>Common mistakes</h2>
        <ul>
          <li>
            Subscribing to both <code phx-no-curly-interpolation>invoice.paid</code>
            and <code phx-no-curly-interpolation>invoice.payment_succeeded</code>
            and double-processing renewals.
          </li>
          <li>
            Using <code phx-no-curly-interpolation>payment_intent.succeeded</code>
            for subscriptions and missing the renewal context.
          </li>
          <li>
            Provisioning on <code phx-no-curly-interpolation>checkout.session.completed</code>
            for async payments before the bank debit actually settles.
          </li>
        </ul>

        <h3>Related</h3>
        <ul>
          <li>
            <.link navigate="/stripe/webhook-signature-verifier">
              Stripe Webhook Signature Verifier
            </.link>
          </li>
          <li><.link navigate="/stripe/event-simulator">Stripe Event Simulator</.link></li>
          <li>
            <.link navigate="/stripe/subscription-states">Stripe Subscription State Machine</.link>
          </li>
        </ul>
      </section>
    </Layouts.tool_page>
    """
  end
end
