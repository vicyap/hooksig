defmodule HooksigWeb.StripeTestCardsLive do
  use HooksigWeb, :live_view

  alias Hooksig.TestCards
  alias HooksigWeb.SEO

  @path "/stripe/test-cards"
  @title "Stripe Test Cards — Complete Library | hooksig"
  @description "Every Stripe test card number — success, decline, 3DS challenge, insufficient funds, authentication required, fraud, international. Filterable, copyable, with exact failure codes."

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
         {"Stripe Test Cards", @path}
       ])
     ])
     |> assign(:query, "")
     |> assign(:scenario, "all")
     |> assign(:cards, TestCards.filter("", "all"))}
  end

  @impl true
  def handle_event("filter", %{"q" => q, "scenario" => scenario}, socket) do
    {:noreply,
     socket
     |> assign(:query, q)
     |> assign(:scenario, scenario)
     |> assign(:cards, TestCards.filter(q, scenario))}
  end

  def handle_event("filter", %{"q" => q}, socket) do
    {:noreply,
     socket
     |> assign(:query, q)
     |> assign(:cards, TestCards.filter(q, socket.assigns.scenario))}
  end

  def handle_event("filter", %{"scenario" => scenario}, socket) do
    {:noreply,
     socket
     |> assign(:scenario, scenario)
     |> assign(:cards, TestCards.filter(socket.assigns.query, scenario))}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.tool_page
      flash={@flash}
      title="Stripe Test Cards"
      eyebrow="Stripe · Reference"
      icon="hero-credit-card"
      description="The complete Stripe test card library: success, decline, 3D Secure, insufficient funds, authentication required, fraud, international. Use any future expiration date, any 3-digit CVC (4 for Amex)."
    >
      <section class="flex flex-col gap-3 pt-6 sm:flex-row sm:items-center">
        <input
          type="text"
          value={@query}
          phx-keyup="filter"
          phx-debounce="120"
          name="q"
          placeholder="Search by number, brand, or scenario…"
          class="input input-bordered flex-1"
          autocomplete="off"
        />
        <select name="scenario" phx-change="filter" class="select select-bordered sm:w-64">
          <option
            :for={{value, label} <- TestCards.scenarios()}
            value={value}
            selected={value == @scenario}
          >
            {label}
          </option>
        </select>
      </section>

      <section class="pt-6">
        <div class="overflow-x-auto rounded-box border border-base-300">
          <table class="table table-zebra">
            <thead>
              <tr>
                <th>Card number</th>
                <th>Brand</th>
                <th>Scenario</th>
                <th>Behavior</th>
              </tr>
            </thead>
            <tbody>
              <tr :for={card <- @cards}>
                <td class="font-mono text-xs">{card.number}</td>
                <td class="text-sm">{card.brand}</td>
                <td>
                  <span class="badge badge-sm">{card.scenario}</span>
                </td>
                <td class="max-w-md text-sm leading-5 text-base-content/80">{card.description}</td>
              </tr>
              <tr :if={@cards == []}>
                <td colspan="4" class="py-8 text-center text-sm text-base-content/60">
                  No cards match those filters.
                </td>
              </tr>
            </tbody>
          </table>
        </div>
      </section>

      <section class="prose prose-sm dark:prose-invert mt-12 max-w-3xl">
        <h2>Notes</h2>
        <ul>
          <li>
            Test cards only work in <strong>test mode</strong>
            (Stripe API key starts with <code phx-no-curly-interpolation>sk_test_</code>).
          </li>
          <li>Use any future expiration date and any 3-digit CVC (4 digits for American Express).</li>
          <li>
            Postal code: any 5-digit US ZIP (e.g. <code phx-no-curly-interpolation>42424</code>) unless testing AVS, in which case use
            <code phx-no-curly-interpolation>42424</code>
            for line1 match, <code phx-no-curly-interpolation>02134</code>
            for full match, <code phx-no-curly-interpolation>92929</code>
            for failure.
          </li>
        </ul>

        <h3>Related</h3>
        <ul>
          <li><.link navigate="/stripe/event-simulator">Stripe Event Simulator</.link></li>
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
