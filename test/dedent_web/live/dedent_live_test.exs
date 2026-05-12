defmodule DedentWeb.DedentLiveTest do
  use DedentWeb.ConnCase, async: true

  import Phoenix.LiveViewTest

  test "renders the dedent tool", %{conn: conn} do
    {:ok, _view, html} = live(conn, ~p"/")

    assert html =~ "Dedent"
    assert html =~ "Paste terminal output"
  end

  test "updates output as input changes", %{conn: conn} do
    {:ok, view, _html} = live(conn, ~p"/")

    view
    |> form("#dedent-form", dedent: %{input: "• r/GLP1\n\n  Title: small GLP cut"})
    |> render_change()

    html =
      view
      |> element("#dedent-output")
      |> render()

    assert html =~ "r/GLP1"
    assert html =~ "Title: small GLP cut"
    refute html =~ "• r/GLP1"
  end

  test "repairs wrapped markdown prompts automatically", %{conn: conn} do
    {:ok, view, _html} = live(conn, ~p"/")

    view
    |> form("#dedent-form",
      dedent: %{
        input:
          "Scan my Claude Code prompt history for cases where I described a well-known\nsoftware-engineering concept in long-form words.\nSteps:\n1. Build the file.\n   Keep the records spread across the full time range.\n2. Return markdown."
      }
    )
    |> render_change()

    html =
      view
      |> element("#dedent-output")
      |> render()

    assert html =~
             "Scan my Claude Code prompt history for cases where I described a well-known software-engineering concept in long-form words."

    assert html =~ "Steps:\n\n1. Build the file."
    assert html =~ "2. Return markdown."
  end

  test "clears input and output", %{conn: conn} do
    {:ok, view, _html} = live(conn, ~p"/")

    view
    |> form("#dedent-form", dedent: %{input: "  alpha"})
    |> render_change()

    assert render(view) =~ "alpha"

    view
    |> element("button", "Clear")
    |> render_click()

    refute render(view) =~ "alpha"
  end
end
