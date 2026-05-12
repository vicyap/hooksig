defmodule HooksigWeb.StripeProrationLive do
  use HooksigWeb, :live_view

  alias HooksigWeb.SEO

  @path "/stripe/proration-calculator"
  @title "Stripe Proration Calculator | hooksig"
  @description "Model a Stripe plan upgrade, downgrade, or seat change. See the exact prorated credit, new charge, and resulting invoice total — the way Stripe computes it."

  @impl true
  def mount(_params, _session, socket) do
    inputs = %{
      "current_price" => "1000",
      "new_price" => "2500",
      "period_days" => "30",
      "days_used" => "12"
    }

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
         {"Stripe Proration Calculator", @path}
       ])
     ])
     |> apply_inputs(inputs)}
  end

  @impl true
  def handle_event("calc", %{"proration" => params}, socket) do
    {:noreply, apply_inputs(socket, params)}
  end

  defp apply_inputs(socket, params) do
    current = parse_int(params["current_price"])
    new_price = parse_int(params["new_price"])
    period_days = parse_int(params["period_days"], 30)
    days_used = parse_int(params["days_used"])

    period_days = max(period_days, 1)
    days_used = days_used |> max(0) |> min(period_days)
    days_remaining = period_days - days_used

    credit = -1 * div(current * days_remaining, period_days)
    new_charge = div(new_price * days_remaining, period_days)
    invoice_total = credit + new_charge

    socket
    |> assign(
      :form,
      to_form(params, as: :proration)
    )
    |> assign(:current, current)
    |> assign(:new_price, new_price)
    |> assign(:period_days, period_days)
    |> assign(:days_used, days_used)
    |> assign(:days_remaining, days_remaining)
    |> assign(:credit, credit)
    |> assign(:new_charge, new_charge)
    |> assign(:invoice_total, invoice_total)
  end

  defp parse_int(value, default \\ 0)

  defp parse_int(value, default) when is_binary(value) do
    case Integer.parse(String.trim(value)) do
      {n, _} -> n
      :error -> default
    end
  end

  defp parse_int(_, default), do: default

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.tool_page
      flash={@flash}
      title="Stripe Proration Calculator"
      eyebrow="Stripe · Subscriptions"
      icon="hero-calculator"
      description="Model a plan change mid-period. Computes the prorated credit for unused time on the old plan and the new charge for the rest of the period — the way Stripe computes proration with proration_behavior=create_prorations."
    >
      <.form
        for={@form}
        id="proration-form"
        phx-change="calc"
        class="mt-6 grid grid-cols-1 gap-4 sm:grid-cols-2"
      >
        <label class="flex flex-col gap-1">
          <span class="text-sm font-medium">Current plan price (cents)</span>
          <input
            type="number"
            id={@form[:current_price].id}
            name={@form[:current_price].name}
            value={@form[:current_price].value}
            class="input input-bordered"
            phx-debounce="120"
            min="0"
          />
        </label>
        <label class="flex flex-col gap-1">
          <span class="text-sm font-medium">New plan price (cents)</span>
          <input
            type="number"
            id={@form[:new_price].id}
            name={@form[:new_price].name}
            value={@form[:new_price].value}
            class="input input-bordered"
            phx-debounce="120"
            min="0"
          />
        </label>
        <label class="flex flex-col gap-1">
          <span class="text-sm font-medium">Billing period length (days)</span>
          <input
            type="number"
            id={@form[:period_days].id}
            name={@form[:period_days].name}
            value={@form[:period_days].value}
            class="input input-bordered"
            phx-debounce="120"
            min="1"
          />
        </label>
        <label class="flex flex-col gap-1">
          <span class="text-sm font-medium">Days into current period at change</span>
          <input
            type="number"
            id={@form[:days_used].id}
            name={@form[:days_used].name}
            value={@form[:days_used].value}
            class="input input-bordered"
            phx-debounce="120"
            min="0"
          />
        </label>
      </.form>

      <section class="mt-8 rounded-box border border-base-300 bg-base-200/40 p-5">
        <h2 class="text-sm font-medium uppercase tracking-wide text-base-content/60">
          Resulting invoice line items
        </h2>
        <dl class="mt-4 grid grid-cols-1 gap-3 text-sm sm:grid-cols-2">
          <div class="flex flex-col gap-0.5">
            <dt class="font-medium text-base-content/60">Unused time on old plan</dt>
            <dd class="font-mono text-base">{format_cents(@credit)}</dd>
          </div>
          <div class="flex flex-col gap-0.5">
            <dt class="font-medium text-base-content/60">Remaining time on new plan</dt>
            <dd class="font-mono text-base">{format_cents(@new_charge)}</dd>
          </div>
          <div class="flex flex-col gap-0.5 sm:col-span-2">
            <dt class="font-medium text-base-content/60">Invoice total now</dt>
            <dd class="font-mono text-lg">{format_cents(@invoice_total)}</dd>
          </div>
          <div class="flex flex-col gap-0.5 sm:col-span-2">
            <dt class="font-medium text-base-content/60">Days remaining in period</dt>
            <dd class="font-mono text-base">{@days_remaining} of {@period_days}</dd>
          </div>
        </dl>
      </section>

      <section class="prose prose-sm dark:prose-invert mt-12 max-w-3xl">
        <h2>How Stripe proration works</h2>
        <p>
          When you change a subscription mid-period with
          <code phx-no-curly-interpolation>proration_behavior=create_prorations</code>
          (the default), Stripe emits two invoice line items:
        </p>
        <ol>
          <li>
            A negative line crediting the customer for the unused time on the old plan.
          </li>
          <li>A positive line charging for the remainder of the period on the new plan.</li>
        </ol>
        <p>
          The proration is per-day, computed as <code phx-no-curly-interpolation>price &times; days_remaining / period_days</code>.
          The two lines may not match exactly due to rounding, so the actual invoice total can differ by a cent.
        </p>

        <h3>Related</h3>
        <ul>
          <li><.link navigate="/stripe/event-semantics">Stripe Event Semantics</.link></li>
          <li>
            <.link navigate="/stripe/subscription-states">Stripe Subscription State Machine</.link>
          </li>
        </ul>
      </section>
    </Layouts.tool_page>
    """
  end

  defp format_cents(cents) when cents < 0,
    do: "-$" <> :erlang.float_to_binary(abs(cents) / 100, decimals: 2)

  defp format_cents(cents),
    do: "$" <> :erlang.float_to_binary(cents / 100, decimals: 2)
end
