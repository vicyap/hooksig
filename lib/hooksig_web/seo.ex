defmodule HooksigWeb.SEO do
  @moduledoc """
  Canonical URL + JSON-LD helpers. Used by LiveViews to populate the
  `:canonical_url`, `:structured_data`, `:page_title`, and `:page_description`
  assigns consumed by `root.html.heex`.
  """

  @default_host "hooksig.fly.dev"

  @spec canonical_host() :: String.t()
  def canonical_host do
    Application.get_env(:hooksig, :canonical_host, @default_host)
  end

  @spec canonical_url(String.t()) :: String.t()
  def canonical_url(path) when is_binary(path) do
    "https://" <> canonical_host() <> path
  end

  @spec software_application(map()) :: map()
  def software_application(%{title: title, description: description, path: path}) do
    %{
      "@context" => "https://schema.org",
      "@type" => "SoftwareApplication",
      "name" => title,
      "description" => description,
      "url" => canonical_url(path),
      "applicationCategory" => "DeveloperApplication",
      "operatingSystem" => "Any",
      "offers" => %{"@type" => "Offer", "price" => "0", "priceCurrency" => "USD"},
      "publisher" => %{"@type" => "Organization", "name" => "hooksig"}
    }
  end

  @spec faq([{String.t(), String.t()}]) :: map()
  def faq(items) do
    %{
      "@context" => "https://schema.org",
      "@type" => "FAQPage",
      "mainEntity" =>
        Enum.map(items, fn {question, answer} ->
          %{
            "@type" => "Question",
            "name" => question,
            "acceptedAnswer" => %{"@type" => "Answer", "text" => answer}
          }
        end)
    }
  end

  @spec breadcrumbs([{String.t(), String.t()}]) :: map()
  def breadcrumbs(items) do
    %{
      "@context" => "https://schema.org",
      "@type" => "BreadcrumbList",
      "itemListElement" =>
        items
        |> Enum.with_index(1)
        |> Enum.map(fn {{name, path}, position} ->
          %{
            "@type" => "ListItem",
            "position" => position,
            "name" => name,
            "item" => canonical_url(path)
          }
        end)
    }
  end

  @spec website() :: map()
  def website do
    %{
      "@context" => "https://schema.org",
      "@type" => "WebSite",
      "name" => "hooksig",
      "url" => canonical_url("/"),
      "description" =>
        "Free webhook debugging tools for Stripe, Paddle, Lemon Squeezy, and Polar."
    }
  end
end
