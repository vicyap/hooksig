defmodule HooksigWeb.StripeEventSimulatorLive do
  use HooksigWeb, :live_view

  alias Hooksig.EventSimulator
  alias HooksigWeb.SEO

  @path "/stripe/event-simulator"
  @title "Stripe Event Simulator — Generate Webhook Payloads | hooksig"
  @description "Generate realistic Stripe event payloads (checkout.session.completed, invoice.paid, customer.subscription.updated, payment_intent.succeeded, charge.refunded). Optionally sign with your test secret to produce a verifiable webhook."

  @impl true
  def mount(_params, _session, socket) do
    type = "checkout.session.completed"

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
         {"Stripe Event Simulator", @path}
       ])
     ])
     |> assign(:event_type, type)
     |> assign(:secret, "")
     |> assign_event(type, "")}
  end

  @impl true
  def handle_event("update", %{"event" => params}, socket) do
    type = Map.get(params, "type", socket.assigns.event_type)
    secret = Map.get(params, "secret", socket.assigns.secret)

    {:noreply,
     socket
     |> assign(:event_type, type)
     |> assign(:secret, secret)
     |> assign_event(type, secret)}
  end

  def handle_event("regenerate", _params, socket) do
    {:noreply, assign_event(socket, socket.assigns.event_type, socket.assigns.secret)}
  end

  defp assign_event(socket, type, "") do
    payload = EventSimulator.build(type)

    socket
    |> assign(:payload, payload)
    |> assign(:signature, nil)
    |> assign(:timestamp, nil)
    |> assign(
      :form,
      to_form(%{"type" => type, "secret" => ""}, as: :event)
    )
  end

  defp assign_event(socket, type, secret) do
    %{payload: payload, signature: signature, timestamp: ts} =
      EventSimulator.build_and_sign(type, secret)

    socket
    |> assign(:payload, payload)
    |> assign(:signature, signature)
    |> assign(:timestamp, ts)
    |> assign(
      :form,
      to_form(%{"type" => type, "secret" => secret}, as: :event)
    )
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.tool_page
      flash={@flash}
      title="Stripe Event Simulator"
      eyebrow="Stripe · Testing"
      icon="hero-bolt"
      description="Generate realistic Stripe webhook payloads. Pick an event type, optionally paste a whsec_ test secret, and get a fully-signed payload + Stripe-Signature header you can POST to your handler."
    >
      <.form
        for={@form}
        id="event-form"
        phx-change="update"
        class="grid grid-cols-1 gap-4 pt-6 sm:grid-cols-2"
      >
        <label class="flex flex-col gap-1">
          <span class="text-sm font-medium">Event type</span>
          <select id={@form[:type].id} name={@form[:type].name} class="select select-bordered">
            <option
              :for={{value, label} <- EventSimulator.event_types()}
              value={value}
              selected={value == @event_type}
            >
              {value} — {label}
            </option>
          </select>
        </label>

        <label class="flex flex-col gap-1">
          <span class="text-sm font-medium">
            Signing secret <span class="text-base-content/50">(optional)</span>
          </span>
          <input
            type="text"
            id={@form[:secret].id}
            name={@form[:secret].name}
            value={@secret}
            class="input input-bordered font-mono text-xs"
            placeholder="whsec_test_…"
            phx-debounce="200"
            autocomplete="off"
            spellcheck="false"
          />
        </label>
      </.form>

      <div class="mt-3">
        <button type="button" class="btn btn-soft btn-sm" phx-click="regenerate">
          <.icon name="hero-arrow-path" class="size-4" /> Regenerate
        </button>
      </div>

      <section class="pt-6">
        <h2 class="text-sm font-medium uppercase tracking-wide text-base-content/60">Payload</h2>
        <pre
          class="mt-2 max-h-[28rem] overflow-auto rounded-box border border-base-300 bg-base-200/40 p-4 font-mono text-xs leading-5"
          phx-no-curly-interpolation
        ><code><%= @payload %></code></pre>
      </section>

      <section :if={@signature} class="pt-6">
        <h2 class="text-sm font-medium uppercase tracking-wide text-base-content/60">
          Stripe-Signature header
        </h2>
        <pre
          class="mt-2 overflow-auto rounded-box border border-base-300 bg-base-200/40 p-4 font-mono text-xs leading-5"
          phx-no-curly-interpolation
        ><code><%= @signature %></code></pre>

        <h3 class="mt-6 text-sm font-medium uppercase tracking-wide text-base-content/60">
          POST it with curl
        </h3>
        <pre
          class="mt-2 overflow-auto rounded-box border border-base-300 bg-base-200/40 p-4 font-mono text-xs leading-5"
          phx-no-curly-interpolation
        ><code><%= curl_command(@payload, @signature) %></code></pre>
      </section>

      <section class="prose prose-sm dark:prose-invert mt-12 max-w-3xl">
        <h2>Notes</h2>
        <ul>
          <li>
            Payloads are illustrative. They include the most commonly-needed fields but are not byte-identical to live Stripe events.
          </li>
          <li>
            If you provide a signing secret, the
            <code phx-no-curly-interpolation>Stripe-Signature</code>
            header is computed exactly the way Stripe does, so a properly-implemented handler will verify it.
          </li>
          <li>Timestamps are set to "now," so signatures pass the default 300s tolerance.</li>
        </ul>

        <h3>Related</h3>
        <ul>
          <li>
            <.link navigate="/stripe/webhook-signature-verifier">
              Stripe Webhook Signature Verifier
            </.link>
          </li>
          <li><.link navigate="/stripe/event-semantics">Stripe Event Semantics</.link></li>
        </ul>
      </section>
    </Layouts.tool_page>
    """
  end

  defp curl_command(payload, signature) do
    """
    curl -X POST http://localhost:4000/stripe/webhooks \\
      -H "Content-Type: application/json" \\
      -H "Stripe-Signature: #{signature}" \\
      --data-raw '#{payload}'
    """
  end
end
