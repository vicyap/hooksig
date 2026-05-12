defmodule HooksigWeb.StripeSubscriptionStatesLive do
  use HooksigWeb, :live_view

  alias HooksigWeb.SEO

  @path "/stripe/subscription-states"
  @title "Stripe Subscription Status: trialing, active, past_due, canceled, unpaid, incomplete | hooksig"
  @description "Every Stripe subscription status, what triggers it, what events fire, and how to handle each in your application logic. The complete subscription state machine."

  @states [
    %{
      name: "trialing",
      label: "trialing",
      color: "info",
      entry: "Subscription is in a free trial period.",
      exits: [
        "active (trial ends, payment succeeds)",
        "past_due (trial ends, payment fails)",
        "canceled (customer cancels during trial)"
      ],
      events: [
        "customer.subscription.created",
        "customer.subscription.trial_will_end (3 days before end)"
      ]
    },
    %{
      name: "active",
      label: "active",
      color: "success",
      entry: "Subscription is in good standing and access should be granted.",
      exits: [
        "past_due (renewal payment fails)",
        "canceled (canceled immediately)",
        "unpaid (after configured retry exhaustion)"
      ],
      events: [
        "customer.subscription.created",
        "customer.subscription.updated",
        "invoice.paid (on each renewal)"
      ]
    },
    %{
      name: "incomplete",
      label: "incomplete",
      color: "warning",
      entry:
        "Initial payment requires action (3DS, etc.) or failed but is retryable. Customer has 23 hours to complete payment.",
      exits: ["active (payment completes)", "incomplete_expired (23 hours pass)"],
      events: ["customer.subscription.created (with status=incomplete)"]
    },
    %{
      name: "incomplete_expired",
      label: "incomplete_expired",
      color: "neutral",
      entry:
        "Initial payment was never completed within the 23-hour window. Terminal state — the subscription is permanently inactive and was never billed.",
      exits: ["(terminal)"],
      events: ["customer.subscription.updated (status=incomplete_expired)"]
    },
    %{
      name: "past_due",
      label: "past_due",
      color: "warning",
      entry:
        "A renewal payment failed. Stripe will retry per your dunning settings. Access should usually be maintained for the grace period, then revoked.",
      exits: ["active (retry succeeds)", "canceled (you cancel)", "unpaid (retries exhausted)"],
      events: ["invoice.payment_failed", "customer.subscription.updated"]
    },
    %{
      name: "unpaid",
      label: "unpaid",
      color: "error",
      entry:
        "All dunning retries failed. Subscription is no longer being charged; access should be revoked. Configurable: Stripe can also auto-cancel.",
      exits: ["active (manual invoice payment)", "canceled (you cancel)"],
      events: ["customer.subscription.updated (status=unpaid)"]
    },
    %{
      name: "canceled",
      label: "canceled",
      color: "neutral",
      entry: "Subscription is canceled. May have been canceled immediately or at period end.",
      exits: ["(terminal)"],
      events: ["customer.subscription.deleted"]
    },
    %{
      name: "paused",
      label: "paused",
      color: "info",
      entry:
        "Subscription is paused — customer is not billed and no invoices generate. Access policy is your call (Stripe does not enforce).",
      exits: ["active (resumed)", "canceled"],
      events: ["customer.subscription.paused", "customer.subscription.resumed"]
    }
  ]

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
         {"Stripe Subscription State Machine", @path}
       ])
     ])
     |> assign(:states, @states)
     |> assign(:focused, "active")}
  end

  @impl true
  def handle_event("focus", %{"state" => state}, socket) do
    {:noreply, assign(socket, :focused, state)}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.tool_page
      flash={@flash}
      title="Stripe Subscription State Machine"
      eyebrow="Stripe · Reference"
      icon="hero-arrows-right-left"
      description="Every Stripe subscription status, the transitions between them, the webhook events that fire, and how to handle each in your application logic."
    >
      <section class="grid grid-cols-2 gap-2 pt-6 sm:grid-cols-4">
        <button
          :for={state <- @states}
          type="button"
          phx-click="focus"
          phx-value-state={state.name}
          class={[
            "flex flex-col items-start rounded-box border p-3 text-left transition",
            state.name == @focused && "border-primary bg-primary/5",
            state.name != @focused && "border-base-300 hover:border-base-content/40"
          ]}
        >
          <span class={["badge badge-sm badge-#{state.color}"]}>{state.label}</span>
        </button>
      </section>

      <section
        :for={state <- @states}
        :if={state.name == @focused}
        class="mt-6 rounded-box border border-base-300 bg-base-100 p-6"
      >
        <h2 class="text-lg font-semibold">
          <code phx-no-curly-interpolation>{state.label}</code>
        </h2>
        <p class="mt-2 text-sm leading-6 text-base-content/80">{state.entry}</p>

        <dl class="mt-5 grid grid-cols-1 gap-4 text-sm sm:grid-cols-2">
          <div>
            <dt class="text-xs font-medium uppercase tracking-wide text-base-content/60">
              Transitions out
            </dt>
            <ul class="mt-1 list-disc pl-5">
              <li :for={exit <- state.exits}>{exit}</li>
            </ul>
          </div>
          <div>
            <dt class="text-xs font-medium uppercase tracking-wide text-base-content/60">
              Events
            </dt>
            <ul class="mt-1 list-disc pl-5 font-mono text-xs">
              <li :for={event <- state.events}>{event}</li>
            </ul>
          </div>
        </dl>
      </section>

      <section class="prose prose-sm dark:prose-invert mt-12 max-w-3xl">
        <h2>How to use this</h2>
        <ul>
          <li>
            Map your "user has access" check to the subscription status, not to anything else. Anything else gets stale.
          </li>
          <li>
            For most apps: grant access on <code phx-no-curly-interpolation>trialing</code>
            and <code phx-no-curly-interpolation>active</code>; show a billing warning on <code phx-no-curly-interpolation>past_due</code>; revoke on
            <code phx-no-curly-interpolation>unpaid</code>
            and <code phx-no-curly-interpolation>canceled</code>.
          </li>
          <li>
            <code phx-no-curly-interpolation>incomplete_expired</code>
            means the subscription was never paid — your handler should never have provisioned in the first place if you waited for <code phx-no-curly-interpolation>invoice.paid</code>.
          </li>
        </ul>

        <h3>Related</h3>
        <ul>
          <li><.link navigate="/stripe/event-semantics">Stripe Event Semantics</.link></li>
          <li><.link navigate="/stripe/proration-calculator">Stripe Proration Calculator</.link></li>
          <li>
            <.link navigate="/stripe/webhook-signature-verifier">
              Stripe Webhook Signature Verifier
            </.link>
          </li>
        </ul>
      </section>
    </Layouts.tool_page>
    """
  end
end
