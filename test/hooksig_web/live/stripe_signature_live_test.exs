defmodule HooksigWeb.StripeSignatureLiveTest do
  use HooksigWeb.ConnCase, async: true

  import Phoenix.LiveViewTest

  test "renders the Stripe verifier page", %{conn: conn} do
    {:ok, _view, html} = live(conn, ~p"/stripe/webhook-signature-verifier")

    assert html =~ "Stripe Webhook Signature Verifier"
    assert html =~ "Stripe-Signature"
    assert html =~ "whsec_"
  end

  test "loads a valid example and shows success", %{conn: conn} do
    {:ok, view, _html} = live(conn, ~p"/stripe/webhook-signature-verifier")

    view
    |> element("button[phx-value-kind='valid']")
    |> render_click()

    html = render(view)
    assert html =~ "Signature valid"
  end

  test "loads a tampered example and shows mismatch", %{conn: conn} do
    {:ok, view, _html} = live(conn, ~p"/stripe/webhook-signature-verifier")

    view
    |> element("button[phx-value-kind='tampered']")
    |> render_click()

    html = render(view)
    assert html =~ "Signature invalid"
    assert html =~ "does not match"
  end

  test "framework variant page sets a framework-specific title", %{conn: conn} do
    {:ok, _view, html} = live(conn, ~p"/stripe/webhook-signature-verifier/nextjs")
    assert html =~ "Next.js"
  end
end
