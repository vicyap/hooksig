import Config

# For development, we disable any cache and enable
# debugging and code reloading.
config :hooksig, HooksigWeb.Endpoint,
  http: [ip: {127, 0, 0, 1}],
  check_origin: false,
  code_reloader: true,
  debug_errors: true,
  secret_key_base: "UX24w766xmN9ogH9rmgbGTbPAF9c8g23pwUbLMdbSSuAo23kBWBnGgKcJrU5o0Z+",
  watchers: [
    esbuild: {Esbuild, :install_and_run, [:hooksig, ~w(--sourcemap=inline --watch)]},
    tailwind: {Tailwind, :install_and_run, [:hooksig, ~w(--watch)]}
  ]

# Reload browser tabs when matching files change.
config :hooksig, HooksigWeb.Endpoint,
  live_reload: [
    web_console_logger: true,
    patterns: [
      ~r"priv/static/(?!uploads/).*\.(js|css|png|jpeg|jpg|gif|svg)$",
      ~r"lib/hooksig_web/router\.ex$",
      ~r"lib/hooksig_web/(controllers|live|components)/.*\.(ex|heex)$"
    ]
  ]

# Enable dev routes for dashboard and mailbox
config :hooksig, dev_routes: true

# Do not include metadata nor timestamps in development logs
config :logger, :default_formatter, format: "[$level] $message\n"

# Set a higher stacktrace during development. Avoid configuring such
# in production as building large stacktraces may be expensive.
config :phoenix, :stacktrace_depth, 20

# Initialize plugs at runtime for faster development compilation
config :phoenix, :plug_init_mode, :runtime

config :phoenix_live_view,
  debug_heex_annotations: true,
  debug_attributes: true,
  enable_expensive_runtime_checks: true
