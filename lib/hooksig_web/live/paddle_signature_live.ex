defmodule HooksigWeb.PaddleSignatureLive do
  use HooksigWeb, :live_view

  alias Hooksig.{Paddle, Tools}
  alias HooksigWeb.SEO

  @path "/paddle/webhook-signature-verifier"
  @base_title "Paddle Webhook Signature Verifier"
  @base_description "Paste a Paddle Billing v2 webhook body, Paddle-Signature header, and endpoint secret. We compute the expected HMAC-SHA256 signature, compare it with what Paddle sent, and explain exactly why verification failed."

  @example_secret "pdl_ntfset_01h_example_do_not_use_aabbccddeeff"
  @example_payload_template ~s({"event_id":"evt_01j_example","event_type":"transaction.completed","occurred_at":"2026-04-01T12:00:00.000Z","data":{"id":"txn_01j_example","status":"completed","customer_id":"ctm_01j_example","items":[{"price":{"id":"pri_01j_example","unit_price":{"amount":"2999","currency_code":"USD"}}}]}})

  @frameworks Tools.frameworks()

  @impl true
  def mount(params, _session, socket) do
    framework = params["framework"]
    valid? = framework in @frameworks
    framework = if valid?, do: framework, else: nil
    canonical_path = if framework, do: "#{@path}/#{framework}", else: @path

    title =
      if framework,
        do:
          "Paddle Webhook Signature Verification in #{Tools.framework_label(framework)} — hooksig",
        else: @base_title <> " — hooksig"

    description =
      if framework,
        do:
          "Debug Paddle Billing v2 webhook signature verification in #{Tools.framework_label(framework)}.",
        else: @base_description

    {:ok,
     socket
     |> assign(:framework, framework)
     |> assign(:page_title, title)
     |> assign(:page_description, description)
     |> assign(:canonical_url, SEO.canonical_url(canonical_path))
     |> assign(
       :structured_data,
       [
         SEO.software_application(%{
           title: title,
           description: description,
           path: canonical_path
         }),
         SEO.breadcrumbs([
           {"hooksig", "/"},
           {"Tools", "/tools"},
           {"Paddle Webhook Signature Verifier", @path}
         ])
       ]
     )
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

  def handle_event("load_example", _params, socket) do
    {payload, signature, secret} = build_valid_example()
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
    case Paddle.verify(payload, signature, secret) do
      {:ok, result} -> {:ok, result}
      {:error, _reason, result} -> {:error, result}
    end
  end

  defp build_valid_example do
    ts = System.system_time(:second)
    payload = @example_payload_template
    sig = sign("#{ts}:#{payload}", @example_secret)
    {payload, "ts=#{ts};h1=#{sig}", @example_secret}
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
      eyebrow="Paddle · Webhook debugging"
      icon="hero-shield-check"
      description="Paste a Paddle Billing v2 webhook body, Paddle-Signature header, and your endpoint secret. We compute the expected HMAC-SHA256 signature and explain why verification failed."
    >
      <section class="pt-4">
        <div class="flex flex-wrap items-center gap-2">
          <span class="text-xs font-medium uppercase tracking-wide text-base-content/60">Try</span>
          <button type="button" class="btn btn-soft btn-xs" phx-click="load_example">
            Valid signature
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
            <span class="text-xs text-base-content/60">Exact bytes Paddle POSTed.</span>
            <textarea
              id={@form[:payload].id}
              name={@form[:payload].name}
              class="textarea textarea-bordered min-h-[14rem] font-mono text-xs leading-5"
              placeholder={~s({"event_id":"evt_…","event_type":"transaction.completed",…})}
              phx-debounce="200"
              spellcheck="false"
            >{@payload}</textarea>
          </label>

          <label class="flex flex-col gap-1">
            <span class="text-sm font-medium">
              <code class="text-xs">Paddle-Signature</code> header
            </span>
            <span class="text-xs text-base-content/60">
              e.g. <code class="text-xs">ts=1700000000;h1=…</code>.
            </span>
            <textarea
              id={@form[:signature].id}
              name={@form[:signature].name}
              class="textarea textarea-bordered min-h-[5rem] font-mono text-xs leading-5"
              placeholder="ts=1700000000;h1=…"
              phx-debounce="200"
              spellcheck="false"
            >{@signature}</textarea>
          </label>

          <label class="flex flex-col gap-1">
            <span class="text-sm font-medium">Notification destination secret</span>
            <span class="text-xs text-base-content/60">
              From Paddle Dashboard → Developer tools → Notifications → your destination.
            </span>
            <input
              type="text"
              id={@form[:secret].id}
              name={@form[:secret].name}
              value={@secret}
              class="input input-bordered font-mono text-xs"
              placeholder="pdl_ntfset_…"
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
        <h2>How Paddle Billing v2 signatures work</h2>
        <p>
          Paddle sends a <code phx-no-curly-interpolation>Paddle-Signature</code>
          header of the form <code phx-no-curly-interpolation>ts=&lt;unix-seconds&gt;;h1=&lt;hex&gt;</code>. To verify:
        </p>
        <ol>
          <li>
            Build the signed payload as
            <code phx-no-curly-interpolation>&lt;ts&gt;:&lt;raw_body&gt;</code>
            (colon, not period).
          </li>
          <li>Compute HMAC-SHA256 with your destination secret.</li>
          <li>
            Constant-time compare to the <code phx-no-curly-interpolation>h1=</code> value.
          </li>
        </ol>

        <h2>Related</h2>
        <ul>
          <li>
            <.link navigate="/stripe/webhook-signature-verifier">
              Stripe Webhook Signature Verifier
            </.link>
          </li>
          <li>
            <.link navigate="/lemon-squeezy/webhook-signature-verifier">
              Lemon Squeezy Webhook Signature Verifier
            </.link>
          </li>
        </ul>
      </section>
    </Layouts.tool_page>
    """
  end

  defp page_h1(nil), do: "Paddle Webhook Signature Verifier"

  defp page_h1(framework),
    do: "Paddle Webhook Signature Verification in #{Tools.framework_label(framework)}"

  attr :result, :any, required: true

  defp result_panel(%{result: :empty} = assigns) do
    ~H"""
    <div class="flex h-full min-h-[24rem] flex-col items-center justify-center rounded-box border border-dashed border-base-300 bg-base-200/40 p-8 text-center">
      <.icon name="hero-arrow-left-circle" class="size-8 text-base-content/40" />
      <p class="mt-3 text-sm font-medium text-base-content/70">
        Paste signature, payload, and secret
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
          <p class="text-xs text-base-content/70">{label(@result.diagnosis)}</p>
        </div>
      </div>

      <dl class="mt-5 grid grid-cols-1 gap-3 text-xs sm:grid-cols-2">
        <div :if={@result.timestamp} class="flex flex-col gap-0.5">
          <dt class="font-medium text-base-content/60">Timestamp (ts=)</dt>
          <dd class="font-mono">{@result.timestamp}</dd>
        </div>
        <div :if={@result.age_seconds != nil} class="flex flex-col gap-0.5">
          <dt class="font-medium text-base-content/60">Age</dt>
          <dd class="font-mono">{@result.age_seconds}s</dd>
        </div>
        <div :if={@result.signatures != []} class="flex flex-col gap-0.5 sm:col-span-2">
          <dt class="font-medium text-base-content/60">h1= signatures</dt>
          <dd class="break-all font-mono">
            <span :for={sig <- @result.signatures} class="block">{sig}</span>
          </dd>
        </div>
        <div :if={@result.expected_signature} class="flex flex-col gap-0.5 sm:col-span-2">
          <dt class="font-medium text-base-content/60">Expected signature (computed)</dt>
          <dd class="break-all font-mono">{@result.expected_signature}</dd>
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

  defp label(:valid), do: "All checks passed."
  defp label(:signature_mismatch), do: "Computed signature does not match any h1= value."
  defp label(:timestamp_outside_tolerance), do: "Signature valid but timestamp too old."
  defp label(:timestamp_in_future), do: "Timestamp is in the future."
  defp label(:missing_timestamp), do: "No `ts=` segment in the header."
  defp label(:missing_h1_signature), do: "No `h1=` segment in the header."
  defp label(:empty_payload), do: "Paste the raw request body."
  defp label(:empty_secret), do: "Paste your destination secret."
  defp label(:empty_signature_header), do: "Paste the Paddle-Signature header."
  defp label(_), do: "Unknown."
end
