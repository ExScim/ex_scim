defmodule ClientWeb.ScimClientDemoLiveTest do
  use ClientWeb.ConnCase, async: true

  import Phoenix.LiveViewTest

  @base_url "https://example.com/scim/v2"
  @bearer_token "test-token"

  defp connect_client(view) do
    view
    |> form("#config-form", %{"base_url" => @base_url, "bearer_token" => @bearer_token})
    |> render_change()

    view
  end

  describe "mount and rendering" do
    test "shows placeholder when no client configured", %{conn: conn} do
      {:ok, view, html} = live(conn, ~p"/search")
      assert html =~ "Connect to a SCIM provider"
      refute has_element?(view, "button", "Add Filter")
    end

    test "shows composer after configuring client", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/search")
      connect_client(view)
      html = render(view)

      assert html =~ "Add Filter"
      assert html =~ "Search"
      assert html =~ "Request Preview"
    end
  end

  describe "filter row management" do
    test "initial state has no filter rows", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/search")
      connect_client(view)

      refute has_element?(view, "#filter-row-form-1")
    end

    test "add_filter_row adds a row", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/search")
      connect_client(view)

      view |> element("button", "Add Filter") |> render_click()

      assert has_element?(view, "#filter-row-form-1")
    end

    test "remove_filter_row removes a specific row leaving others", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/search")
      connect_client(view)

      view |> element("button", "Add Filter") |> render_click()
      view |> element("button", "Add Filter") |> render_click()
      assert has_element?(view, "#filter-row-form-1")
      assert has_element?(view, "#filter-row-form-2")

      view |> element("#filter-row-form-1 button[phx-click=remove_filter_row]") |> render_click()

      refute has_element?(view, "#filter-row-form-1")
      assert has_element?(view, "#filter-row-form-2")
    end

    test "removing the last row results in zero rows", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/search")
      connect_client(view)

      view |> element("button", "Add Filter") |> render_click()
      assert has_element?(view, "#filter-row-form-1")

      view |> element("#filter-row-form-1 button[phx-click=remove_filter_row]") |> render_click()

      refute has_element?(view, "#filter-row-form-1")
      assert has_element?(view, "button", "Add Filter")
    end

    test "can add a row after removing all rows", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/search")
      connect_client(view)

      view |> element("button", "Add Filter") |> render_click()
      assert has_element?(view, "#filter-row-form-1")

      view |> element("#filter-row-form-1 button[phx-click=remove_filter_row]") |> render_click()
      refute has_element?(view, "#filter-row-form-1")

      view |> element("button", "Add Filter") |> render_click()
      assert has_element?(view, "#filter-row-form-2")
    end
  end

  describe "filter row updates" do
    test "changing attribute updates the row", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/search")
      connect_client(view)

      view |> element("button", "Add Filter") |> render_click()

      view
      |> form("#filter-row-form-1", %{"attribute" => "displayName", "row-id" => "1"})
      |> render_change()

      assert has_element?(view, "#filter-attr-1 option[selected][value=displayName]")
    end

    test "changing operator updates the row", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/search")
      connect_client(view)

      view |> element("button", "Add Filter") |> render_click()

      view
      |> form("#filter-row-form-1", %{"operator" => "co", "row-id" => "1"})
      |> render_change()

      assert has_element?(view, "#filter-op-1 option[selected][value=co]")
    end

    test "setting a value causes filter param to appear in preview", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/search")
      connect_client(view)

      view |> element("button", "Add Filter") |> render_click()

      view
      |> form("#filter-row-form-1", %{"value" => "john", "row-id" => "1"})
      |> render_change()

      html = render(view)
      assert html =~ "filter="
    end

    test "empty value row is excluded from filter", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/search")
      connect_client(view)

      html = render(view)
      refute html =~ "filter="
    end

    test "pr operator is included without value", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/search")
      connect_client(view)

      view |> element("button", "Add Filter") |> render_click()

      view
      |> form("#filter-row-form-1", %{"operator" => "pr", "row-id" => "1"})
      |> render_change()

      html = render(view)
      assert html =~ "filter="
      refute has_element?(view, "#filter-val-1")
    end
  end

  describe "resource type" do
    test "changing to Groups updates preview path", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/search")
      connect_client(view)

      view |> element("select[name=resource_type]") |> render_change(%{"resource_type" => "Groups"})

      html = render(view)
      assert html =~ "/Groups"
    end

    test "changing to Groups shows group attributes", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/search")
      connect_client(view)

      view |> element("select[name=resource_type]") |> render_change(%{"resource_type" => "Groups"})
      view |> element("button", "Add Filter") |> render_click()

      html = render(view)
      assert html =~ "displayName"
      assert html =~ "members.value"
    end

    test "changing type clears previous results", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/search")
      connect_client(view)

      # Set some state then switch type
      view |> element("select[name=resource_type]") |> render_change(%{"resource_type" => "Groups"})
      view |> element("select[name=resource_type]") |> render_change(%{"resource_type" => "Users"})

      refute has_element?(view, ".card-title", "Results")
    end
  end

  describe "combinator" do
    test "changing combinator to or is reflected in preview with two filled rows", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/search")
      connect_client(view)

      # Add and fill first row
      view |> element("button", "Add Filter") |> render_click()

      view
      |> form("#filter-row-form-1", %{"value" => "john", "row-id" => "1"})
      |> render_change()

      # Add and fill second row
      view |> element("button", "Add Filter") |> render_click()

      view
      |> form("#filter-row-form-2", %{"value" => "jane", "row-id" => "2"})
      |> render_change()

      # Change combinator
      view
      |> element("#filter-combinator-2")
      |> render_change(%{"combinator" => "or"})

      # URI.encode_query encodes spaces as +, so "or" appears as "+or+" in the preview URL
      html = render(view)
      assert html =~ "+or+"
    end

    test "default and combinator works with multiple rows", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/search")
      connect_client(view)

      view |> element("button", "Add Filter") |> render_click()

      view
      |> form("#filter-row-form-1", %{"value" => "john", "row-id" => "1"})
      |> render_change()

      view |> element("button", "Add Filter") |> render_click()

      view
      |> form("#filter-row-form-2", %{"value" => "jane", "row-id" => "2"})
      |> render_change()

      # URI.encode_query encodes spaces as +, so "and" appears as "+and+" in the preview URL
      html = render(view)
      assert html =~ "+and+"
    end
  end

  describe "page size" do
    test "default page size is 50 in preview", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/search")
      connect_client(view)

      html = render(view)
      assert html =~ "count=50"
    end

    test "changing page size in composer updates preview", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/search")
      connect_client(view)

      view
      |> element("select[phx-change=update_search_page_size]")
      |> render_change(%{"page_size" => "25"})

      html = render(view)
      assert html =~ "count=25"
    end
  end

  describe "request preview" do
    test "shows configured base URL", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/search")
      connect_client(view)

      html = render(view)
      assert html =~ @base_url
    end

    test "with no filled filters shows only count and startIndex", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/search")
      connect_client(view)

      html = render(view)
      assert html =~ "count=50"
      assert html =~ "startIndex=1"
      refute html =~ "filter="
    end

    test "with filled filter shows filter param", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/search")
      connect_client(view)

      view |> element("button", "Add Filter") |> render_click()

      view
      |> form("#filter-row-form-1", %{"value" => "test", "row-id" => "1"})
      |> render_change()

      html = render(view)
      assert html =~ "filter="
    end
  end

  describe "search execution" do
    test "execute_search without client does not crash and shows no results", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/search")

      # Sending the event directly (button is hidden when no client) should not crash
      render_click(view, "execute_search")

      refute has_element?(view, ".card-title", "Results")
      assert render(view) =~ "Connect to a SCIM provider"
    end
  end
end
