defmodule HooksigWeb.Layouts do
  @moduledoc """
  Layouts and reusable page chrome.

  - `root.html.heex` is the HTML skeleton, including SEO meta and JSON-LD.
  - `tool_page/1` is the shared tool layout: hero, breadcrumbs, content slot, footer.
  - `app/1` is a lightweight wrapper for the homepage and content pages.
  """
  use HooksigWeb, :html

  embed_templates "layouts/*"

  @doc """
  Shared chrome for every tool page: top nav, eyebrow, title, description,
  and a content slot. Use as `<Layouts.tool_page …>`.
  """
  attr :flash, :map, required: true
  attr :title, :string, required: true
  attr :eyebrow, :string, default: nil
  attr :icon, :string, default: "hero-bolt"
  attr :description, :string, default: nil
  slot :inner_block, required: true
  slot :actions

  def tool_page(assigns) do
    ~H"""
    <main class="min-h-screen bg-base-100">
      <.flash_group flash={@flash} />
      <.site_nav />

      <div class="mx-auto w-full max-w-5xl px-4 py-6 sm:px-6 lg:px-8">
        <header class="flex flex-col gap-3 border-b border-base-300 pb-5 sm:flex-row sm:items-start sm:justify-between sm:gap-4">
          <div class="flex min-w-0 items-start gap-3">
            <div class="flex size-10 shrink-0 items-center justify-center rounded-box bg-base-200 text-base-content">
              <.icon name={@icon} class="size-5" />
            </div>
            <div class="min-w-0">
              <p
                :if={@eyebrow}
                class="text-xs font-medium uppercase tracking-wide text-base-content/60"
              >
                {@eyebrow}
              </p>
              <h1 class="text-xl font-semibold leading-7">{@title}</h1>
              <p :if={@description} class="mt-2 max-w-3xl text-sm leading-6 text-base-content/80">
                {@description}
              </p>
            </div>
          </div>
          <div class="flex shrink-0 items-center gap-2">
            {render_slot(@actions)}
          </div>
        </header>

        {render_slot(@inner_block)}

        <.site_footer />
      </div>
    </main>
    """
  end

  @doc """
  Lightweight content wrapper for the homepage and informational pages.
  """
  attr :flash, :map, required: true
  slot :inner_block, required: true

  def content_page(assigns) do
    ~H"""
    <main class="min-h-screen bg-base-100">
      <.flash_group flash={@flash} />
      <.site_nav />

      <div class="mx-auto w-full max-w-5xl px-4 py-10 sm:px-6 lg:px-8">
        {render_slot(@inner_block)}
        <.site_footer />
      </div>
    </main>
    """
  end

  defp site_nav(assigns) do
    ~H"""
    <nav class="border-b border-base-300 bg-base-100/80 backdrop-blur">
      <div class="mx-auto flex w-full max-w-5xl items-center justify-between px-4 py-3 sm:px-6 lg:px-8">
        <.link navigate="/" class="flex items-center gap-2">
          <span class="flex size-7 items-center justify-center rounded bg-primary text-primary-content">
            <.icon name="hero-bolt" class="size-4" />
          </span>
          <span class="font-semibold tracking-tight">hooksig</span>
        </.link>
        <div class="flex items-center gap-1 text-sm">
          <.link navigate="/tools" class="btn btn-ghost btn-sm">Tools</.link>
          <a
            href="https://github.com/vicyap/hooksig"
            class="btn btn-ghost btn-sm"
            rel="noopener"
          >
            GitHub
          </a>
          <.theme_toggle />
        </div>
      </div>
    </nav>
    """
  end

  defp site_footer(assigns) do
    ~H"""
    <footer class="mt-16 border-t border-base-300 pt-6 text-xs text-base-content/60">
      <div class="flex flex-col gap-2 sm:flex-row sm:items-center sm:justify-between">
        <p>
          hooksig &mdash; fast, private webhook debugging tools.
        </p>
        <p class="flex items-center gap-3">
          <.link navigate="/" class="link link-hover">Home</.link>
          <.link navigate="/tools" class="link link-hover">All tools</.link>
          <a href="https://github.com/vicyap/hooksig" class="link link-hover" rel="noopener">
            Open source
          </a>
        </p>
      </div>
    </footer>
    """
  end

  attr :flash, :map, required: true, doc: "the map of flash messages"
  attr :id, :string, default: "flash-group"

  def flash_group(assigns) do
    ~H"""
    <div id={@id} aria-live="polite">
      <.flash kind={:info} flash={@flash} />
      <.flash kind={:error} flash={@flash} />

      <.flash
        id="client-error"
        kind={:error}
        title="We can't find the internet"
        phx-disconnected={show(".phx-client-error #client-error") |> JS.remove_attribute("hidden")}
        phx-connected={hide("#client-error") |> JS.set_attribute({"hidden", ""})}
        hidden
      >
        Attempting to reconnect
        <.icon name="hero-arrow-path" class="ml-1 size-3 motion-safe:animate-spin" />
      </.flash>

      <.flash
        id="server-error"
        kind={:error}
        title="Something went wrong!"
        phx-disconnected={show(".phx-server-error #server-error") |> JS.remove_attribute("hidden")}
        phx-connected={hide("#server-error") |> JS.set_attribute({"hidden", ""})}
        hidden
      >
        Attempting to reconnect
        <.icon name="hero-arrow-path" class="ml-1 size-3 motion-safe:animate-spin" />
      </.flash>
    </div>
    """
  end

  @doc """
  Dark/light theme toggle. Wired up by the inline script in `root.html.heex`.
  """
  def theme_toggle(assigns) do
    ~H"""
    <div class="card relative flex flex-row items-center border-2 border-base-300 bg-base-300 rounded-full">
      <div class="absolute w-1/3 h-full rounded-full border-1 border-base-200 bg-base-100 brightness-200 left-0 [[data-theme=light]_&]:left-1/3 [[data-theme=dark]_&]:left-2/3 transition-[left]" />
      <button
        class="flex p-2 cursor-pointer w-1/3"
        phx-click={JS.dispatch("phx:set-theme")}
        data-phx-theme="system"
        aria-label="System theme"
      >
        <.icon name="hero-computer-desktop-micro" class="size-4 opacity-75 hover:opacity-100" />
      </button>
      <button
        class="flex p-2 cursor-pointer w-1/3"
        phx-click={JS.dispatch("phx:set-theme")}
        data-phx-theme="light"
        aria-label="Light theme"
      >
        <.icon name="hero-sun-micro" class="size-4 opacity-75 hover:opacity-100" />
      </button>
      <button
        class="flex p-2 cursor-pointer w-1/3"
        phx-click={JS.dispatch("phx:set-theme")}
        data-phx-theme="dark"
        aria-label="Dark theme"
      >
        <.icon name="hero-moon-micro" class="size-4 opacity-75 hover:opacity-100" />
      </button>
    </div>
    """
  end
end
