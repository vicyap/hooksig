defmodule HooksigWeb.LemonSqueezySignatureLive do
  use HooksigWeb, :live_view

  alias Hooksig.{LemonSqueezy, Tools}
  alias HooksigWeb.SEO

  @path "/lemon-squeezy/webhook-signature-verifier"
  @base_title "Lemon Squeezy Webhook Signature Verifier"
  @base_description "Paste a Lemon Squeezy webhook body, X-Signature header, and signing secret. We compute the expected HMAC-SHA256 and explain why verification failed."

  @example_secret "ls_whsec_example_do_not_use_in_production_abcdef1234567890"

  @example_payload_template ~s({"meta":{"event_name":"order_created","custom_data":{"plan":"pro"}},"data":{"type":"orders","id":"123456","attributes":{"order_number":1001,"status":"paid","total":2999,"currency":"USD","user_email":"jane@example.com"}}})

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
          "Lemon Squeezy Webhook Signature Verification in #{Tools.framework_label(framework)} — hooksig",
        else: @base_title <> " — hooksig"

    description =
      if framework,
        do:
          "Debug Lemon Squeezy webhook signature verification in #{Tools.framework_label(framework)}.",
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
           {"Lemon Squeezy Webhook Signature Verifier", @path}
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
    case LemonSqueezy.verify(payload, signature, secret) do
      {:ok, result} -> {:ok, result}
      {:error, _reason, result} -> {:error, result}
    end
  end

  defp build_valid_example do
    payload = @example_payload_template
    sig = :crypto.mac(:hmac, :sha256, @example_secret, payload) |> Base.encode16(case: :lower)
    {payload, sig, @example_secret}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.tool_page
      flash={@flash}
      title={page_h1(@framework)}
      eyebrow="Lemon Squeezy · Webhook debugging"
      icon="hero-shield-check"
      description="Paste a Lemon Squeezy webhook body, X-Signature header, and signing secret. We compute the expected HMAC-SHA256 and tell you exactly why verification failed."
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
            <span class="text-xs text-base-content/60">Exact bytes Lemon Squeezy POSTed.</span>
            <textarea
              id={@form[:payload].id}
              name={@form[:payload].name}
              class="textarea textarea-bordered min-h-[14rem] font-mono text-xs leading-5"
              placeholder={~s({"meta":{"event_name":"order_created",…}})}
              phx-debounce="200"
              spellcheck="false"
            >{@payload}</textarea>
          </label>

          <label class="flex flex-col gap-1">
            <span class="text-sm font-medium">
              <code class="text-xs">X-Signature</code> header
            </span>
            <span class="text-xs text-base-content/60">
              Just hex — no prefix.
            </span>
            <textarea
              id={@form[:signature].id}
              name={@form[:signature].name}
              class="textarea textarea-bordered min-h-[5rem] font-mono text-xs leading-5"
              placeholder="abcdef…"
              phx-debounce="200"
              spellcheck="false"
            >{@signature}</textarea>
          </label>

          <label class="flex flex-col gap-1">
            <span class="text-sm font-medium">Webhook signing secret</span>
            <span class="text-xs text-base-content/60">
              The secret you set when creating the webhook in the Lemon Squeezy dashboard.
            </span>
            <input
              type="text"
              id={@form[:secret].id}
              name={@form[:secret].name}
              value={@secret}
              class="input input-bordered font-mono text-xs"
              placeholder="ls_whsec_…"
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
        <h2>How Lemon Squeezy signatures work</h2>
        <p>
          Lemon Squeezy sends an <code phx-no-curly-interpolation>X-Signature</code>
          header that is just the lowercase hex of <code phx-no-curly-interpolation>HMAC-SHA256(secret, body)</code>. No timestamp, no
          <code phx-no-curly-interpolation>v1=</code>
          prefix. To verify, compute HMAC-SHA256 with your signing secret over the raw body and compare in constant time.
        </p>

        <h2>Related</h2>
        <ul>
          <li>
            <.link navigate="/stripe/webhook-signature-verifier">
              Stripe Webhook Signature Verifier
            </.link>
          </li>
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

  defp page_h1(nil), do: "Lemon Squeezy Webhook Signature Verifier"

  defp page_h1(framework),
    do: "Lemon Squeezy Webhook Signature Verification in #{Tools.framework_label(framework)}"

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

      <dl class="mt-5 grid grid-cols-1 gap-3 text-xs">
        <div :if={@result.signature} class="flex flex-col gap-0.5">
          <dt class="font-medium text-base-content/60">X-Signature</dt>
          <dd class="break-all font-mono">{@result.signature}</dd>
        </div>
        <div :if={@result.expected_signature} class="flex flex-col gap-0.5">
          <dt class="font-medium text-base-content/60">Expected (computed)</dt>
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
  defp label(:signature_mismatch), do: "Computed HMAC does not match X-Signature."
  defp label(:empty_payload), do: "Paste the raw request body."
  defp label(:empty_secret), do: "Paste your webhook signing secret."
  defp label(:empty_signature_header), do: "Paste the X-Signature header."
  defp label(_), do: "Unknown."
end
