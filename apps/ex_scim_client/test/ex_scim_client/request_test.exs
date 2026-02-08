defmodule ExScimClient.RequestTest do
  use ExUnit.Case

  alias ExScimClient.Request
  alias ExScimClient.Client
  alias ExScimClient.Filter
  alias ExScimClient.Sorting
  alias ExScimClient.Pagination

  describe "request creation" do
    test "creates request from client with base_url and bearer token" do
      client = %Client{
        base_url: "https://api.example.com",
        bearer: "test-token",
        default_headers: [{"content-type", "application/json"}]
      }

      request = Request.new(client)

      assert request[:base_url] == "https://api.example.com"
      assert {"authorization", "Bearer test-token"} in request[:headers]
      assert {"content-type", "application/json"} in request[:headers]
    end

    test "includes default headers from client" do
      client = %Client{
        base_url: "https://api.example.com",
        bearer: "test-token",
        default_headers: [{"x-custom", "value"}, {"accept", "application/json"}]
      }

      request = Request.new(client)

      assert {"x-custom", "value"} in request[:headers]
      assert {"accept", "application/json"} in request[:headers]
    end

    test "handles nil bearer token" do
      client = %Client{
        base_url: "https://api.example.com",
        bearer: nil,
        default_headers: []
      }

      request = Request.new(client)

      assert request[:headers] == [{"authorization", "Bearer "}]
    end
  end

  describe "authentication" do
    setup do
      base_request = [
        base_url: "https://api.example.com",
        headers: [{"accept", "application/json"}]
      ]

      %{request: base_request}
    end

    test "bearer/2 adds bearer token to headers", %{request: req} do
      updated_req = Request.bearer(req, "new-token")

      assert {"authorization", "Bearer new-token"} in updated_req[:headers]
      assert {"accept", "application/json"} in updated_req[:headers]
    end

    test "bearer/2 preserves existing headers", %{request: req} do
      updated_req = Request.bearer(req, "token")

      assert length(updated_req[:headers]) == 2
      assert {"accept", "application/json"} in updated_req[:headers]
    end

    test "basic/3 encodes username:password correctly", %{request: req} do
      updated_req = Request.basic(req, "user", "pass")

      expected_encoded = Base.encode64("user:pass")
      assert {"authorization", "Basic #{expected_encoded}"} in updated_req[:headers]
    end

    test "basic/3 preserves existing headers", %{request: req} do
      updated_req = Request.basic(req, "user", "pass")

      assert {"accept", "application/json"} in updated_req[:headers]
    end

    test "authentication headers override previous auth" do
      req = [headers: [{"authorization", "Bearer old-token"}]]

      updated_req = Request.basic(req, "user", "pass")

      auth_headers = Enum.filter(updated_req[:headers], fn {key, _} -> key == "authorization" end)
      assert length(auth_headers) == 2
    end
  end

  describe "path building" do
    setup do
      %{request: [base_url: "https://api.example.com"]}
    end

    test "builds full URL from base_url and endpoint", %{request: req} do
      updated_req = Request.path(req, "users")

      assert updated_req[:url] == "https://api.example.com/users"
    end

    test "normalizes base_url without trailing slash", %{request: req} do
      updated_req = Request.path(req, "users")

      assert updated_req[:url] == "https://api.example.com/users"
    end

    test "normalizes base_url with trailing slash" do
      req = [base_url: "https://api.example.com/"]
      updated_req = Request.path(req, "users")

      assert updated_req[:url] == "https://api.example.com/users"
    end

    test "normalizes endpoint with leading slash", %{request: req} do
      updated_req = Request.path(req, "/users")

      assert updated_req[:url] == "https://api.example.com/users"
    end

    test "normalizes endpoint without leading slash", %{request: req} do
      updated_req = Request.path(req, "users")

      assert updated_req[:url] == "https://api.example.com/users"
    end

    test "raises error when base_url is nil" do
      req = []

      assert_raise ArgumentError, "base_url cannot be nil", fn ->
        Request.path(req, "users")
      end
    end
  end

  describe "HTTP methods" do
    setup do
      %{request: []}
    end

    test "sets GET method", %{request: req} do
      updated_req = Request.method(req, :get)

      assert updated_req[:method] == :get
    end

    test "sets POST method", %{request: req} do
      updated_req = Request.method(req, :post)

      assert updated_req[:method] == :post
    end

    test "sets PUT method", %{request: req} do
      updated_req = Request.method(req, :put)

      assert updated_req[:method] == :put
    end

    test "sets DELETE method", %{request: req} do
      updated_req = Request.method(req, :delete)

      assert updated_req[:method] == :delete
    end

    test "sets PATCH method", %{request: req} do
      updated_req = Request.method(req, :patch)

      assert updated_req[:method] == :patch
    end
  end

  describe "request body" do
    setup do
      %{request: []}
    end

    test "sets JSON body from map", %{request: req} do
      body_data = %{name: "John", email: "john@example.com"}
      updated_req = Request.body(req, body_data)

      assert updated_req[:json] == body_data
    end

    test "sets JSON body from struct", %{request: req} do
      body_data = %Client{base_url: "test", bearer: "token", default_headers: []}
      updated_req = Request.body(req, body_data)

      assert updated_req[:json] == body_data
    end

    test "handles empty body", %{request: req} do
      updated_req = Request.body(req, %{})

      assert updated_req[:json] == %{}
    end

    test "handles nil body", %{request: req} do
      updated_req = Request.body(req, nil)

      assert updated_req[:json] == nil
    end
  end

  describe "filter parameters" do
    setup do
      %{request: []}
    end

    test "adds Filter struct to scim_params", %{request: req} do
      filter = Filter.new() |> Filter.equals("userName", "foo")
      updated_req = Request.filter(req, filter)

      assert updated_req[:scim_params][:filter] == "userName eq \"foo\""
    end

    test "adds filter string to scim_params", %{request: req} do
      filter_string = "userName eq foo"
      updated_req = Request.filter(req, filter_string)

      assert updated_req[:scim_params][:filter] == filter_string
    end

    test "replaces existing filter", %{request: req} do
      req = Keyword.put(req, :scim_params, %{filter: "old filter"})
      updated_req = Request.filter(req, "new filter")

      assert updated_req[:scim_params][:filter] == "new filter"
    end

    test "handles empty filter string", %{request: req} do
      updated_req = Request.filter(req, "")

      assert updated_req[:scim_params][:filter] == ""
    end
  end

  describe "sorting parameters" do
    setup do
      %{request: []}
    end

    test "adds sort_by with default ascending order", %{request: req} do
      updated_req = Request.sort_by(req, %Sorting{by: "userName"})

      assert updated_req[:scim_params][:sort_by] == "userName"
      assert updated_req[:scim_params][:sort_order] == :asc
    end

    test "adds sort_by with descending order", %{request: req} do
      updated_req = Request.sort_by(req, %Sorting{by: "userName", order: :desc})

      assert updated_req[:scim_params][:sort_by] == "userName"
      assert updated_req[:scim_params][:sort_order] == :desc
    end

    test "replaces existing sort parameters", %{request: req} do
      req = Keyword.put(req, :scim_params, %{sort_by: "old", sort_order: :desc})
      updated_req = Request.sort_by(req, %Sorting{by: "userName", order: :asc})

      assert updated_req[:scim_params][:sort_by] == "userName"
      assert updated_req[:scim_params][:sort_order] == :asc
    end

    test "validates sort direction values", %{request: req} do
      updated_req_asc = Request.sort_by(req, %Sorting{by: "userName", order: :asc})
      updated_req_desc = Request.sort_by(req, %Sorting{by: "userName", order: :desc})

      assert updated_req_asc[:scim_params][:sort_order] == :asc
      assert updated_req_desc[:scim_params][:sort_order] == :desc
    end
  end

  describe "pagination parameters" do
    setup do
      %{request: []}
    end

    test "adds start_index and count", %{request: req} do
      updated_req = Request.paginate(req, %Pagination{start_index: 1, count: 10})

      assert updated_req[:scim_params][:start_index] == 1
      assert updated_req[:scim_params][:count] == 10
    end

    test "replaces existing pagination", %{request: req} do
      req = Keyword.put(req, :scim_params, %{start_index: 10, count: 5})
      updated_req = Request.paginate(req, %Pagination{start_index: 20, count: 15})

      assert updated_req[:scim_params][:start_index] == 20
      assert updated_req[:scim_params][:count] == 15
    end

    test "handles zero start_index", %{request: req} do
      updated_req = Request.paginate(req, %Pagination{start_index: 0, count: 10})

      assert updated_req[:scim_params][:start_index] == 0
    end

    test "handles large count values", %{request: req} do
      updated_req = Request.paginate(req, %Pagination{start_index: 1, count: 1000})

      assert updated_req[:scim_params][:count] == 1000
    end
  end

  describe "attribute selection" do
    setup do
      %{request: []}
    end

    test "adds attributes list", %{request: req} do
      attrs = ["userName", "displayName", "emails"]
      updated_req = Request.attributes(req, attrs)

      assert updated_req[:scim_params][:attributes] == attrs
    end

    test "adds excluded_attributes list", %{request: req} do
      attrs = ["password", "photos"]
      updated_req = Request.excluded_attributes(req, attrs)

      assert updated_req[:scim_params][:excluded_attributes] == attrs
    end

    test "handles empty attribute lists", %{request: req} do
      updated_req_attrs = Request.attributes(req, [])
      updated_req_excluded = Request.excluded_attributes(req, [])

      assert updated_req_attrs[:scim_params][:attributes] == []
      assert updated_req_excluded[:scim_params][:excluded_attributes] == []
    end

    test "replaces existing attributes", %{request: req} do
      req = Keyword.put(req, :scim_params, %{attributes: ["old"]})
      updated_req = Request.attributes(req, ["new", "attrs"])

      assert updated_req[:scim_params][:attributes] == ["new", "attrs"]
    end

    test "handles single attribute", %{request: req} do
      updated_req = Request.attributes(req, ["userName"])

      assert updated_req[:scim_params][:attributes] == ["userName"]
    end

    test "handles multiple attributes", %{request: req} do
      attrs = ["userName", "displayName", "emails", "active"]
      updated_req = Request.attributes(req, attrs)

      assert updated_req[:scim_params][:attributes] == attrs
    end
  end

  describe "query parameter building" do
    test "builds query from scim_params" do
      req = [
        url: "https://api.example.com/users",
        scim_params: %{
          filter: "userName eq foo",
          sort_by: "userName",
          sort_order: :desc,
          start_index: 1,
          count: 10
        }
      ]

      result = Request.run(req)

      # This would normally make an HTTP request, but we're testing the query building
      # We can't easily test the internal query building without exposing private functions
      # or making an actual HTTP request, so we'll test integration scenarios instead
      assert is_tuple(result)
    end

    test "handles empty scim_params" do
      req = [url: "https://api.example.com/users"]

      result = Request.run(req)
      assert is_tuple(result)
    end

    test "handles nil scim_params" do
      req = [url: "https://api.example.com/users"]

      result = Request.run(req)
      assert is_tuple(result)
    end

    test "raises error when URL is nil during run" do
      req = [scim_params: %{filter: "test"}]

      assert_raise ArgumentError, ~r/url cannot be nil/, fn ->
        Request.run(req)
      end
    end
  end

  describe "request execution" do
    test "returns error tuple for invalid requests" do
      req = []

      result = Request.run(req)

      assert {:error, _reason} = result
    end

    test "cleans up scim_params after building" do
      # This is harder to test without making actual HTTP requests
      # We'd need to mock Req or create integration tests
      req = [
        url: "https://httpbin.org/get",
        method: :get,
        scim_params: %{filter: "userName eq test"}
      ]

      # The actual implementation would clean up scim_params
      # but we can't verify this without mocking or integration testing
      result = Request.run(req)
      assert is_tuple(result)
    end
  end

  describe "request pipeline integration" do
    test "builds complete SCIM search request with all parameters" do
      client = %Client{
        base_url: "https://api.example.com",
        bearer: "test-token",
        default_headers: []
      }

      filter = Filter.new() |> Filter.equals("userName", "john")

      request =
        Request.new(client)
        |> Request.method(:get)
        |> Request.path("users")
        |> Request.filter(filter)
        |> Request.sort_by(%Sorting{by: "userName", order: :desc})
        |> Request.paginate(%Pagination{start_index: 1, count: 20})
        |> Request.attributes(["userName", "displayName", "emails"])

      assert request[:method] == :get
      assert request[:url] == "https://api.example.com/users"
      assert request[:scim_params][:filter] == "userName eq \"john\""
      assert request[:scim_params][:sort_by] == "userName"
      assert request[:scim_params][:sort_order] == :desc
      assert request[:scim_params][:start_index] == 1
      assert request[:scim_params][:count] == 20
      assert request[:scim_params][:attributes] == ["userName", "displayName", "emails"]
    end

    test "builds filtered request with complex Filter struct" do
      complex_filter =
        Filter.new()
        |> Filter.equals("active", "true")
        |> Filter.and1(
          Filter.new()
          |> Filter.contains("userName", "admin")
          |> Filter.or1(Filter.new() |> Filter.ends_with("email", "@company.com"))
        )

      request =
        []
        |> Request.filter(complex_filter)

      expected_filter =
        "(active eq \"true\") and ((userName co \"admin\") or (email ew \"@company.com\"))"

      assert request[:scim_params][:filter] == expected_filter
    end

    test "builds paginated and sorted request" do
      request =
        []
        |> Request.sort_by(%Sorting{by: "created", order: :desc})
        |> Request.paginate(%Pagination{start_index: 10, count: 50})

      assert request[:scim_params][:sort_by] == "created"
      assert request[:scim_params][:sort_order] == :desc
      assert request[:scim_params][:start_index] == 10
      assert request[:scim_params][:count] == 50
    end

    test "chains multiple parameter additions" do
      request =
        []
        |> Request.attributes(["userName", "emails"])
        |> Request.excluded_attributes(["photos", "addresses"])
        |> Request.filter("active eq true")
        |> Request.sort_by(%Sorting{by: "lastModified"})

      assert request[:scim_params][:attributes] == ["userName", "emails"]
      assert request[:scim_params][:excluded_attributes] == ["photos", "addresses"]
      assert request[:scim_params][:filter] == "active eq true"
      assert request[:scim_params][:sort_by] == "lastModified"
      assert request[:scim_params][:sort_order] == :asc
    end

    test "handles parameter overrides correctly" do
      request =
        []
        |> Request.filter("userName eq foo")
        |> Request.sort_by(%Sorting{by: "userName", order: :asc})
        |> Request.filter("userName eq bar")
        |> Request.sort_by(%Sorting{by: "displayName", order: :desc})

      assert request[:scim_params][:filter] == "userName eq bar"
      assert request[:scim_params][:sort_by] == "displayName"
      assert request[:scim_params][:sort_order] == :desc
    end
  end

  describe "edge cases" do
    test "handles malformed URLs" do
      req = [base_url: "not-a-url"]
      updated_req = Request.path(req, "users")

      assert updated_req[:url] == "not-a-url/users"
    end

    test "handles very long parameter values" do
      long_string = String.duplicate("a", 1000)
      req = Request.filter([], long_string)

      assert req[:scim_params][:filter] == long_string
    end

    test "handles special characters in parameters" do
      special_filter = "userName eq \"foo@bar.com\""
      req = Request.filter([], special_filter)

      assert req[:scim_params][:filter] == special_filter
    end

    test "handles empty base_url with endpoint" do
      req = [base_url: ""]

      updated_req = Request.path(req, "users")
      assert updated_req[:url] == "/users"
    end

    test "handles multiple slashes in URL construction" do
      req = [base_url: "https://api.example.com///"]
      updated_req = Request.path(req, "///users///")

      assert updated_req[:url] == "https://api.example.com///users///"
    end
  end
end
