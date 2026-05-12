defmodule HooksigWeb.HomeLive do
  use HooksigWeb, :live_view

  alias Hooksig.Tools
  alias HooksigWeb.SEO

  @impl true
  def mount(_params, _session, socket) do
    {:ok,
     socket
     |> assign(
       :page_title,
       "hooksig — free webhook debugging tools for Stripe, Paddle, Lemon Squeezy"
     )
     |> assign(
       :page_description,
       "Verify webhook signatures, decode events, simulate payloads, and debug Stripe / Paddle / Lemon Squeezy integrations. Free, fast, private — your data never leaves the request."
     )
     |> assign(:canonical_url, SEO.canonical_url("/"))
     |> assign(:structured_data, SEO.website())
     |> assign(:tools, Tools.all())
     |> assign(:by_category, Tools.by_category())}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.content_page flash={@flash}>
      <section class="py-10">
        <p class="inline-flex items-center gap-2 rounded-full border border-base-300 bg-base-200/40 px-3 py-1 text-xs font-medium text-base-content/70">
          <span class="size-1.5 rounded-full bg-success"></span>
          Stripe · Paddle · Lemon Squeezy · Polar
        </p>
        <h1 class="mt-6 text-4xl font-semibold leading-tight tracking-tight sm:text-5xl">
          Webhook debugging tools<br />that don't store your data.
        </h1>
        <p class="mt-5 max-w-2xl text-base leading-7 text-base-content/80">
          Verify signatures, decode events, simulate payloads, and debug payment integrations — without sending anything to a third party. Inputs live in memory for one request, then disappear.
        </p>
        <div class="mt-6 flex flex-wrap items-center gap-3 text-sm">
          <.link
            navigate="/stripe/webhook-signature-verifier"
            class="btn btn-primary"
          >
            Verify a Stripe webhook <.icon name="hero-arrow-right" class="size-4" />
          </.link>
          <.link navigate="/tools" class="btn btn-ghost">All tools</.link>
        </div>
      </section>

      <section class="pt-8">
        <h2 class="text-sm font-medium uppercase tracking-wide text-base-content/60">
          Tools
        </h2>
        <div class="mt-4 grid grid-cols-1 gap-3 sm:grid-cols-2 lg:grid-cols-3">
          <.link
            :for={tool <- @tools}
            navigate={tool.path}
            class="group flex flex-col gap-3 rounded-box border border-base-300 bg-base-100 p-5 transition hover:border-primary/40 hover:shadow-sm"
          >
            <div class="flex items-center gap-3">
              <span class="flex size-9 items-center justify-center rounded bg-base-200 text-base-content">
                <.icon name={tool.icon} class="size-5" />
              </span>
              <span class="badge badge-sm">{tool.category}</span>
            </div>
            <h3 class="text-base font-semibold leading-6 group-hover:text-primary">
              {tool.title}
            </h3>
            <p class="text-sm leading-5 text-base-content/70">{tool.short}</p>
          </.link>
        </div>
      </section>

      <section class="prose prose-sm dark:prose-invert mt-16 max-w-3xl">
        <h2>Why hooksig?</h2>
        <p>
          When a Stripe webhook signature fails, the official error is "No signatures found matching the expected signature for payload." That's the whole message. No hint about whether your secret is wrong, your body was parsed, or the timestamp is stale.
        </p>
        <p>
          hooksig fills that gap. Paste what you have, see exactly what's wrong, and copy a framework-specific fix.
        </p>

        <h2>Coverage</h2>
        <ul>
          <li>
            <strong>Stripe</strong>
            &mdash; signature verifier, event simulator, test cards, proration calculator, event semantics, subscription state machine
          </li>
          <li><strong>Paddle</strong> &mdash; Billing v2 signature verifier</li>
          <li><strong>Lemon Squeezy</strong> &mdash; X-Signature verifier</li>
          <li><strong>Polar</strong> &mdash; coming soon</li>
        </ul>
      </section>
    </Layouts.content_page>
    """
  end
end
