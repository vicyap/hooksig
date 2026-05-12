defmodule HooksigWeb.Router do
  use HooksigWeb, :router

  pipeline :browser do
    plug :accepts, ["html"]
    plug :fetch_session
    plug :fetch_live_flash
    plug :put_root_layout, html: {HooksigWeb.Layouts, :root}
    plug :protect_from_forgery
    plug :put_secure_browser_headers
  end

  pipeline :api do
    plug :accepts, ["json"]
  end

  scope "/", HooksigWeb do
    pipe_through :browser

    live "/", HomeLive, :index
    live "/tools", HomeLive, :tools

    # Stripe
    live "/stripe/webhook-signature-verifier", StripeSignatureLive, :index
    live "/stripe/webhook-signature-verifier/:framework", StripeSignatureLive, :framework
    live "/stripe/event-simulator", StripeEventSimulatorLive, :index
    live "/stripe/test-cards", StripeTestCardsLive, :index
    live "/stripe/proration-calculator", StripeProrationLive, :index
    live "/stripe/event-semantics", StripeEventSemanticsLive, :index
    live "/stripe/subscription-states", StripeSubscriptionStatesLive, :index

    # Paddle
    live "/paddle/webhook-signature-verifier", PaddleSignatureLive, :index
    live "/paddle/webhook-signature-verifier/:framework", PaddleSignatureLive, :framework

    # Lemon Squeezy
    live "/lemon-squeezy/webhook-signature-verifier", LemonSqueezySignatureLive, :index

    live "/lemon-squeezy/webhook-signature-verifier/:framework",
         LemonSqueezySignatureLive,
         :framework

    get "/sitemap.xml", SitemapController, :index
  end
end
