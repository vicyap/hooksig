defmodule HooksigWeb.StripeSignatureLive do
  use HooksigWeb, :live_view

  alias Hooksig.{Stripe, Tools}
  alias HooksigWeb.SEO

  @path "/stripe/webhook-signature-verifier"
  @base_title "Stripe Webhook Signature Verifier"

  @base_description "Paste a Stripe webhook payload, Stripe-Signature header, and your endpoint signing secret. We compute the expected HMAC-SHA256 signature and explain exactly why verification failed — with framework-specific fixes."

  @example_secret "whsec_test_example_do_not_use_in_production_b8d3a7f4c1e2"

  @example_payload_template ~s({"id":"evt_3MhKnXJxnvBdN8eY","object":"event","api_version":"2024-04-10","created":__TS__,"data":{"object":{"id":"cs_test_a1b2c3","object":"checkout.session","amount_total":2999,"currency":"usd","customer":"cus_QabcXYZ","payment_status":"paid","status":"complete"}},"livemode":false,"type":"checkout.session.completed"})

  @frameworks Tools.frameworks()

  @impl true
  def mount(params, _session, socket) do
    framework = params["framework"]
    valid_framework? = framework in @frameworks

    framework = if valid_framework?, do: framework, else: nil

    canonical_path = if framework, do: "#{@path}/#{framework}", else: @path

    title =
      if framework do
        "Stripe Webhook Signature Verification in #{Tools.framework_label(framework)} — hooksig"
      else
        @base_title <> " — hooksig"
      end

    description =
      if framework do
        "Debug Stripe webhook signature verification in #{Tools.framework_label(framework)}. Paste payload, header, and secret — see the exact failure and a copy-paste fix for #{Tools.framework_label(framework)}."
      else
        @base_description
      end

    {:ok,
     socket
     |> assign(:framework, framework)
     |> assign(:page_title, title)
     |> assign(:page_description, description)
     |> assign(:canonical_url, SEO.canonical_url(canonical_path))
     |> assign(:structured_data, structured_data(canonical_path, title, description))
     |> apply_inputs("", "", "")}
  end

  @impl true
  def handle_event("verify", %{"verify" => params}, socket) when is_map(params) do
    {:noreply,
     apply_inputs(
       socket,
       Map.get(params, "payload", ""),
       Map.get(params, "signature", ""),
       Map.get(params, "secret", "")
     )}
  end

  def handle_event("load_example", %{"kind" => kind}, socket) do
    {payload, signature, secret} =
      case kind do
        "valid" -> build_valid_example()
        "tampered" -> build_tampered_example()
        "wrong_secret" -> build_wrong_secret_example()
        "stale" -> build_stale_example()
      end

    {:noreply, apply_inputs(socket, payload, signature, secret)}
  end

  def handle_event("clear", _params, socket), do: {:noreply, apply_inputs(socket, "", "", "")}

  defp apply_inputs(socket, payload, signature, secret) do
    socket
    |> assign(:payload, payload)
    |> assign(:signature, signature)
    |> assign(:secret, secret)
    |> assign(:result, run_verification(payload, signature, secret))
    |> assign(
      :form,
      to_form(%{"payload" => payload, "signature" => signature, "secret" => secret}, as: :verify)
    )
  end

  defp run_verification("", _, _), do: :empty
  defp run_verification(_, "", _), do: :empty
  defp run_verification(_, _, ""), do: :empty

  defp run_verification(payload, signature, secret) do
    case Stripe.verify(payload, signature, secret) do
      {:ok, result} -> {:ok, result}
      {:error, _reason, result} -> {:error, result}
    end
  end

  defp structured_data(path, title, description) do
    [
      SEO.software_application(%{title: title, description: description, path: path}),
      SEO.breadcrumbs([
        {"hooksig", "/"},
        {"Tools", "/tools"},
        {"Stripe Webhook Signature Verifier", @path}
      ])
    ]
  end

  defp build_valid_example do
    ts = System.system_time(:second)
    payload = String.replace(@example_payload_template, "__TS__", Integer.to_string(ts))
    sig = sign("#{ts}.#{payload}", @example_secret)
    {payload, "t=#{ts},v1=#{sig}", @example_secret}
  end

  defp build_tampered_example do
    {payload, header, secret} = build_valid_example()
    tampered = String.replace(payload, ~s("amount_total":2999), ~s("amount_total":1))
    {tampered, header, secret}
  end

  defp build_wrong_secret_example do
    {payload, header, _} = build_valid_example()
    {payload, header, "whsec_a_different_endpoint_secret_aaaa1111bbbb"}
  end

  defp build_stale_example do
    ts = System.system_time(:second) - 86_400
    payload = String.replace(@example_payload_template, "__TS__", Integer.to_string(ts))
    sig = sign("#{ts}.#{payload}", @example_secret)
    {payload, "t=#{ts},v1=#{sig}", @example_secret}
  end

  defp sign(payload, secret) do
    :hmac
    |> :crypto.mac(:sha256, secret, payload)
    |> Base.encode16(case: :lower)
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.tool_page
      flash={@flash}
      title={page_h1(@framework)}
      eyebrow="Stripe · Webhook debugging"
      icon="hero-shield-check"
      description="Paste a Stripe webhook payload, Stripe-Signature header, and your endpoint signing secret. We compute the expected HMAC-SHA256 and explain exactly why verification failed. Inputs stay in memory on this request — nothing is logged."
    >
      <section class="pt-4">
        <div class="flex flex-wrap items-center gap-2">
          <span class="text-xs font-medium uppercase tracking-wide text-base-content/60">Try</span>
          <button
            type="button"
            class="btn btn-soft btn-xs"
            phx-click="load_example"
            phx-value-kind="valid"
          >
            Valid signature
          </button>
          <button
            type="button"
            class="btn btn-soft btn-xs"
            phx-click="load_example"
            phx-value-kind="tampered"
          >
            Tampered payload
          </button>
          <button
            type="button"
            class="btn btn-soft btn-xs"
            phx-click="load_example"
            phx-value-kind="wrong_secret"
          >
            Wrong secret
          </button>
          <button
            type="button"
            class="btn btn-soft btn-xs"
            phx-click="load_example"
            phx-value-kind="stale"
          >
            Stale timestamp
          </button>
          <span class="flex-1"></span>
          <button
            type="button"
            class="btn btn-ghost btn-xs"
            phx-click="clear"
            disabled={@payload == "" and @signature == "" and @secret == ""}
          >
            <.icon name="hero-trash" class="size-3" /> Clear
          </button>
        </div>
      </section>

      <section class="grid grid-cols-1 gap-6 pt-6 lg:grid-cols-2">
        <.form
          for={@form}
          id="verify-form"
          phx-change="verify"
          phx-submit="verify"
          class="flex flex-col gap-4"
        >
          <label class="flex flex-col gap-1">
            <span class="text-sm font-medium">Raw request body</span>
            <span class="text-xs text-base-content/60">
              The exact bytes Stripe POSTed — before any JSON parser runs.
            </span>
            <textarea
              id={@form[:payload].id}
              name={@form[:payload].name}
              class="textarea textarea-bordered min-h-[14rem] font-mono text-xs leading-5"
              placeholder={~s({"id":"evt_…","type":"checkout.session.completed",…})}
              phx-debounce="200"
              spellcheck="false"
            >{@payload}</textarea>
          </label>

          <label class="flex flex-col gap-1">
            <span class="text-sm font-medium">
              <code class="text-xs">Stripe-Signature</code> header
            </span>
            <span class="text-xs text-base-content/60">
              Full value, e.g. <code class="text-xs">t=1700000000,v1=…</code>.
            </span>
            <textarea
              id={@form[:signature].id}
              name={@form[:signature].name}
              class="textarea textarea-bordered min-h-[5rem] font-mono text-xs leading-5"
              placeholder="t=1700000000,v1=abcdef…"
              phx-debounce="200"
              spellcheck="false"
            >{@signature}</textarea>
          </label>

          <label class="flex flex-col gap-1">
            <span class="text-sm font-medium">Endpoint signing secret</span>
            <span class="text-xs text-base-content/60">
              Starts with <code class="text-xs">whsec_</code>. Found in Dashboard → Developers → Webhooks → your endpoint.
            </span>
            <input
              type="text"
              id={@form[:secret].id}
              name={@form[:secret].name}
              value={@secret}
              class="input input-bordered font-mono text-xs"
              placeholder="whsec_…"
              phx-debounce="200"
              autocomplete="off"
              spellcheck="false"
            />
          </label>
        </.form>

        <aside class="flex flex-col gap-4">
          <.result_panel result={@result} />
        </aside>
      </section>

      <section class="prose prose-sm dark:prose-invert mt-12 max-w-3xl">
        <h2>How Stripe webhook signatures work</h2>
        <p>
          Stripe sends each webhook with a <code phx-no-curly-interpolation>Stripe-Signature</code>
          header of the form <code phx-no-curly-interpolation>t=&lt;unix-seconds&gt;,v1=&lt;hex&gt;</code>. Verification:
        </p>
        <ol>
          <li>
            Concatenate the timestamp, a literal <code phx-no-curly-interpolation>.</code>, and the raw request body.
          </li>
          <li>
            Compute
            <code phx-no-curly-interpolation>
              HMAC-SHA256(secret, &quot;&lt;t&gt;.&lt;body&gt;&quot;)
            </code>
            as lowercase hex.
          </li>
          <li>
            Constant-time compare to the <code phx-no-curly-interpolation>v1=</code> value.
          </li>
          <li>Reject if the timestamp is more than 300 seconds old.</li>
        </ol>
        <p>
          If a single byte of the body changes between Stripe and your handler — a JSON parser re-serializing, a proxy adding a trailing newline, a charset conversion — the HMAC will not match.
        </p>

        <h2>Framework-specific fixes</h2>

        <.framework_block name="nextjs" highlighted={@framework == "nextjs"} />
        <.framework_block name="express" highlighted={@framework == "express"} />
        <.framework_block name="laravel" highlighted={@framework == "laravel"} />
        <.framework_block name="rails" highlighted={@framework == "rails"} />
        <.framework_block name="fastapi" highlighted={@framework == "fastapi"} />
        <.framework_block name="phoenix" highlighted={@framework == "phoenix"} />

        <h2>FAQ</h2>
        <h3>
          Why does it work with <code phx-no-curly-interpolation>stripe listen</code>
          but fail in production?
        </h3>
        <p>
          The Stripe CLI prints a different signing secret than your dashboard endpoint. Use the dashboard secret in deployed environments.
        </p>

        <h3>Can I verify without the official SDK?</h3>
        <p>
          Yes — the algorithm is HMAC-SHA256 over <code phx-no-curly-interpolation>&quot;&lt;timestamp&gt;.&lt;body&gt;&quot;</code>. This tool runs exactly that and shows the expected signature.
        </p>

        <h3>What is the default tolerance?</h3>
        <p>
          300 seconds. Raise it in your SDK call (e.g.
          <code phx-no-curly-interpolation>tolerance: 31536000</code>
          in Node) when replaying captured events.
        </p>

        <h3>Related tools</h3>
        <ul>
          <li><.link navigate="/stripe/event-simulator">Stripe Event Simulator</.link></li>
          <li><.link navigate="/stripe/event-semantics">Stripe Event Semantics</.link></li>
          <li><.link navigate="/stripe/test-cards">Stripe Test Cards</.link></li>
          <li>
            <.link navigate="/paddle/webhook-signature-verifier">
              Paddle Webhook Signature Verifier
            </.link>
          </li>
        </ul>
      </section>
    </Layouts.tool_page>
    """
  end

  defp page_h1(nil), do: "Stripe Webhook Signature Verifier"

  defp page_h1(framework),
    do: "Stripe Webhook Signature Verification in #{Tools.framework_label(framework)}"

  attr :result, :any, required: true

  defp result_panel(%{result: :empty} = assigns) do
    ~H"""
    <div class="flex h-full min-h-[24rem] flex-col items-center justify-center rounded-box border border-dashed border-base-300 bg-base-200/40 p-8 text-center">
      <.icon name="hero-arrow-left-circle" class="size-8 text-base-content/40" />
      <p class="mt-3 text-sm font-medium text-base-content/70">
        Paste a signature, payload, and secret
      </p>
      <p class="mt-1 text-xs text-base-content/60">
        Or click an example above to see the verification flow.
      </p>
    </div>
    """
  end

  defp result_panel(%{result: {status, result}} = assigns) do
    assigns = assigns |> assign(:status, status) |> assign(:result, result)

    ~H"""
    <div class={[
      "rounded-box border p-5",
      @status == :ok && "border-success/50 bg-success/5",
      @status != :ok && "border-error/50 bg-error/5"
    ]}>
      <div class="flex items-center gap-3">
        <.icon :if={@status == :ok} name="hero-check-circle" class="size-7 text-success" />
        <.icon :if={@status != :ok} name="hero-x-circle" class="size-7 text-error" />
        <div>
          <p class="text-base font-semibold">
            {if @status == :ok, do: "Signature valid", else: "Signature invalid"}
          </p>
          <p class="text-xs text-base-content/70">{diagnosis_label(@result.diagnosis)}</p>
        </div>
      </div>

      <dl class="mt-5 grid grid-cols-1 gap-3 text-xs sm:grid-cols-2">
        <div :if={@result.timestamp} class="flex flex-col gap-0.5">
          <dt class="font-medium text-base-content/60">Timestamp (t=)</dt>
          <dd class="font-mono">{@result.timestamp}</dd>
        </div>
        <div :if={@result.age_seconds != nil} class="flex flex-col gap-0.5">
          <dt class="font-medium text-base-content/60">Age</dt>
          <dd class="font-mono">{age_label(@result.age_seconds, @result.tolerance_seconds)}</dd>
        </div>
        <div :if={@result.signatures != []} class="flex flex-col gap-0.5 sm:col-span-2">
          <dt class="font-medium text-base-content/60">Signatures from header (v1=)</dt>
          <dd class="break-all font-mono">
            <span :for={sig <- @result.signatures} class="block">{sig}</span>
          </dd>
        </div>
        <div :if={@result.expected_signature} class="flex flex-col gap-0.5 sm:col-span-2">
          <dt class="font-medium text-base-content/60">Expected signature (computed)</dt>
          <dd class="break-all font-mono">{@result.expected_signature}</dd>
        </div>
        <div :if={@result.signed_payload_preview} class="flex flex-col gap-0.5 sm:col-span-2">
          <dt class="font-medium text-base-content/60">Signed payload preview</dt>
          <dd class="break-all rounded bg-base-200/60 p-2 font-mono">
            {@result.signed_payload_preview}
          </dd>
        </div>
      </dl>

      <ul :if={@result.hints != []} class="mt-5 flex flex-col gap-2 text-xs leading-5">
        <li :for={hint <- @result.hints} class="flex gap-2">
          <.icon name="hero-light-bulb" class="size-4 shrink-0 text-warning" />
          <span>{hint}</span>
        </li>
      </ul>
    </div>
    """
  end

  attr :name, :string, required: true
  attr :highlighted, :boolean, default: false

  defp framework_block(assigns) do
    ~H"""
    <div class={[@highlighted && "rounded-box border border-primary/40 bg-primary/5 p-4"]}>
      <h3 id={"stripe-#{@name}"}>{Tools.framework_label(@name)}</h3>
      <pre phx-no-curly-interpolation><code><%= stripe_snippet(@name) %></code></pre>
    </div>
    """
  end

  defp stripe_snippet("nextjs"),
    do: """
    // app/api/stripe/route.ts
    import Stripe from "stripe"
    const stripe = new Stripe(process.env.STRIPE_SECRET_KEY!)

    export async function POST(req: Request) {
      const sig = req.headers.get("stripe-signature")!
      const body = await req.text() // raw text — never req.json()
      const event = stripe.webhooks.constructEvent(body, sig, process.env.STRIPE_WEBHOOK_SECRET!)
      return Response.json({ received: true })
    }
    """

  defp stripe_snippet("express"),
    do: """
    app.post(
      "/webhook",
      express.raw({ type: "application/json" }), // not express.json()
      (req, res) => {
        const event = stripe.webhooks.constructEvent(
          req.body,                       // Buffer of raw bytes
          req.headers["stripe-signature"],
          process.env.STRIPE_WEBHOOK_SECRET
        )
        res.json({ received: true })
      }
    )
    """

  defp stripe_snippet("laravel"),
    do: """
    $payload = $request->getContent(); // raw — not $request->all()
    $event = \\Stripe\\Webhook::constructEvent(
        $payload,
        $request->header('Stripe-Signature'),
        config('services.stripe.webhook_secret')
    );
    """

  defp stripe_snippet("rails"),
    do: """
    payload = request.body.read # raw bytes
    event = Stripe::Webhook.construct_event(
      payload,
      request.env['HTTP_STRIPE_SIGNATURE'],
      Rails.application.credentials.stripe_webhook_secret
    )
    """

  defp stripe_snippet("fastapi"),
    do: """
    @app.post("/webhook")
    async def webhook(request: Request):
        payload = await request.body()  # bytes
        sig = request.headers["stripe-signature"]
        event = stripe.Webhook.construct_event(payload, sig, settings.WEBHOOK_SECRET)
        return {"received": True}
    """

  defp stripe_snippet("phoenix"),
    do: """
    # endpoint.ex: capture raw body before parsing
    plug Plug.Parsers,
      parsers: [:urlencoded, :multipart, {:json, body_reader: {CacheBodyReader, :read_body, []}}],
      json_decoder: Jason

    # controller: verify using the raw body
    raw_body = conn.assigns.raw_body
    sig = get_req_header(conn, "stripe-signature") |> List.first()
    {:ok, _} = Hooksig.Stripe.verify(raw_body, sig, secret)
    """

  defp diagnosis_label(:valid), do: "All checks passed."

  defp diagnosis_label(:signature_mismatch),
    do: "Our computed signature does not match any v1= signature in the header."

  defp diagnosis_label(:timestamp_outside_tolerance),
    do: "Signature is mathematically valid but the timestamp is too old."

  defp diagnosis_label(:timestamp_in_future), do: "Signature timestamp is in the future."
  defp diagnosis_label(:missing_timestamp), do: "No `t=` segment found in the header."
  defp diagnosis_label(:missing_v1_signature), do: "No `v1=` segment found in the header."
  defp diagnosis_label(:empty_payload), do: "Paste the raw request body."
  defp diagnosis_label(:empty_secret), do: "Paste your endpoint signing secret."
  defp diagnosis_label(:empty_signature_header), do: "Paste the Stripe-Signature header."
  defp diagnosis_label(_), do: "Unknown."

  defp age_label(age, tolerance) when age >= 0 and age <= tolerance,
    do: "#{age}s (within #{tolerance}s)"

  defp age_label(age, tolerance) when age >= 0, do: "#{age}s (older than #{tolerance}s)"
  defp age_label(age, _), do: "#{age}s (in the future)"
end
