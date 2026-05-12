defmodule HooksigWeb.SitemapController do
  use HooksigWeb, :controller

  alias Hooksig.Tools
  alias HooksigWeb.SEO

  def index(conn, _params) do
    conn
    |> put_resp_content_type("application/xml")
    |> send_resp(200, render_sitemap(build_urls()))
  end

  defp build_urls do
    base = [
      %{loc: SEO.canonical_url("/"), priority: "1.0", changefreq: "weekly"},
      %{loc: SEO.canonical_url("/tools"), priority: "0.9", changefreq: "weekly"}
    ]

    tool_urls =
      Enum.flat_map(Tools.all(), fn tool ->
        primary = %{loc: SEO.canonical_url(tool.path), priority: "0.8", changefreq: "weekly"}

        framework_urls =
          Enum.map(tool.frameworks, fn fw ->
            %{
              loc: SEO.canonical_url("#{tool.path}/#{fw}"),
              priority: "0.6",
              changefreq: "monthly"
            }
          end)

        [primary | framework_urls]
      end)

    base ++ tool_urls
  end

  defp render_sitemap(urls) do
    body =
      Enum.map_join(urls, "\n", fn url ->
        ~s(  <url><loc>#{url.loc}</loc><changefreq>#{url.changefreq}</changefreq><priority>#{url.priority}</priority></url>)
      end)

    """
    <?xml version="1.0" encoding="UTF-8"?>
    <urlset xmlns="http://www.sitemaps.org/schemas/sitemap/0.9">
    #{body}
    </urlset>
    """
  end
end
