defmodule DedentWeb.DedentLive do
  use DedentWeb, :live_view

  alias Dedent.Text

  @impl true
  def mount(_params, _session, socket) do
    {:ok, assign_text(socket, "")}
  end

  @impl true
  def handle_event("update", %{"dedent" => params}, socket) when is_map(params) do
    input = Map.get(params, "input", "")

    {:noreply, assign_text(socket, input)}
  end

  def handle_event("update", _params, socket) do
    {:noreply, assign_text(socket, "")}
  end

  def handle_event("clear", _params, socket) do
    {:noreply, assign_text(socket, "")}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <main class="min-h-screen bg-base-100">
      <Layouts.flash_group flash={@flash} />

      <div class="mx-auto flex min-h-screen w-full max-w-7xl flex-col px-4 py-4 sm:px-6 lg:px-8">
        <header class="flex min-h-14 items-center justify-between gap-4 border-b border-base-300">
          <div class="flex min-w-0 items-center gap-3">
            <div class="flex size-9 shrink-0 items-center justify-center rounded-box bg-base-200 text-base-content">
              <.icon name="hero-bars-3-bottom-left" class="size-5" />
            </div>
            <div class="min-w-0">
              <h1 class="truncate text-lg font-semibold leading-6">Dedent</h1>
              <div class="mt-1 flex items-center gap-2">
                <span class="badge badge-soft badge-primary badge-sm">smart</span>
                <span class="badge badge-soft badge-neutral badge-sm">{@input_lines} lines</span>
              </div>
            </div>
          </div>

          <div class="flex items-center gap-2">
            <button
              type="button"
              class="btn btn-ghost btn-sm"
              phx-click="clear"
              disabled={@input == ""}
            >
              <.icon name="hero-trash" class="size-4" /> Clear
            </button>
            <Layouts.theme_toggle />
          </div>
        </header>

        <section class="grid flex-1 grid-cols-1 gap-4 py-4 lg:grid-cols-2">
          <.form
            for={@form}
            id="dedent-form"
            phx-change="update"
            phx-submit="update"
            class="flex min-h-[28rem] flex-col rounded-box border border-base-300 bg-base-100"
          >
            <div class="flex h-12 items-center justify-between gap-3 border-b border-base-300 px-4">
              <label for={@form[:input].id} class="text-sm font-medium">Input</label>
              <span class="text-xs tabular-nums text-base-content/60">{@input_chars} chars</span>
            </div>
            <textarea
              id={@form[:input].id}
              name={@form[:input].name}
              class="textarea textarea-ghost min-h-[28rem] flex-1 resize-none rounded-none border-0 font-mono text-sm leading-6 focus:outline-none"
              placeholder="Paste terminal output"
              phx-debounce="120"
              autofocus
            >{@input}</textarea>
          </.form>

          <section class="flex min-h-[28rem] flex-col rounded-box border border-base-300 bg-base-100">
            <div class="flex h-12 items-center justify-between gap-3 border-b border-base-300 px-4">
              <div class="flex items-center gap-3">
                <label for="dedent-output" class="text-sm font-medium">Output</label>
                <span class="text-xs tabular-nums text-base-content/60">{@output_chars} chars</span>
              </div>

              <button
                id="copy-output"
                type="button"
                class="btn btn-primary btn-sm"
                phx-hook="CopyToClipboard"
                data-clipboard-target="#dedent-output"
                disabled={@output == ""}
              >
                <.icon name="hero-clipboard-document" class="size-4" /> Copy
              </button>
            </div>
            <textarea
              id="dedent-output"
              class="textarea textarea-ghost min-h-[28rem] flex-1 resize-none rounded-none border-0 font-mono text-sm leading-6 focus:outline-none"
              readonly
            >{@output}</textarea>
          </section>
        </section>
      </div>
    </main>
    """
  end

  defp assign_text(socket, input) do
    output = Text.clean(input)

    assign(socket,
      form: to_form(%{"input" => input}, as: :dedent),
      input: input,
      output: output,
      input_chars: String.length(input),
      output_chars: String.length(output),
      input_lines: line_count(input)
    )
  end

  defp line_count(""), do: 0
  defp line_count(text), do: text |> String.split("\n", trim: false) |> length()
end
