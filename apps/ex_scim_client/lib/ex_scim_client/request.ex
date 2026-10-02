defmodule ExScimClient.Request do
  @moduledoc """
  Request builder DSL for composing HTTP requests.

  ## Examples

      iex> client = ExScimClient.Client.new("https://example.com/scim/v2", "token")
      iex> {:ok, _response} = ExScimClient.Request.new(client)
      ...> |> ExScimClient.Request.path("/Users")
      ...> |> ExScimClient.Request.method(:get)
      ...> |> ExScimClient.Request.run()

  """
  alias Req
  alias ExScimClient.Client
  alias ExScimClient.Filter
  alias ExScimClient.Sorting
  alias ExScimClient.Pagination

  @type t :: keyword()

  @doc """
  Creates a new request from a client configuration.

  ## Examples

      iex> client = ExScimClient.Client.new("https://example.com/scim/v2", "token")
      iex> request = ExScimClient.Request.new(client)
      iex> is_list(request)
      true

  """
  @spec new(Client.t()) :: t()
  def new(%Client{base_url: base, default_headers: headers} = client) do
    [
      base_url: base,
      headers: auth_headers(client) ++ headers
    ]
  end

  defp auth_headers(%Client{auth: {:bearer, token}}) do
    [{"authorization", "Bearer #{token}"}]
  end

  defp auth_headers(%Client{auth: {:basic, username, password}}) do
    credentials = Base.encode64("#{username}:#{password}")
    [{"authorization", "Basic #{credentials}"}]
  end

  defp auth_headers(%Client{auth: {:header, name, value}}) do
    [{name, value}]
  end

  defp auth_headers(%Client{auth: :none}) do
    []
  end

  defp auth_headers(%Client{auth: nil, bearer: bearer}) when is_binary(bearer) do
    [{"authorization", "Bearer #{bearer}"}]
  end

  defp auth_headers(%Client{}) do
    []
  end

  @doc """
  Sets bearer token authentication for the request.

  ## Examples

      iex> client = ExScimClient.Client.new("https://example.com/scim/v2", "token")
      iex> request = ExScimClient.Request.new(client) |> ExScimClient.Request.bearer("new_token")
      iex> headers = Keyword.get(request, :headers)
      iex> Enum.any?(headers, fn {key, value} -> key == "authorization" and String.starts_with?(value, "Bearer new_token") end)
      true

  """
  @spec bearer(t(), String.t()) :: t()
  def bearer(req, token) do
    headers = Keyword.get(req, :headers, [])
    Keyword.put(req, :headers, [{"authorization", "Bearer #{token}"} | headers])
  end

  @doc """
  Sets basic authentication for the request.

  ## Examples

      iex> client = ExScimClient.Client.new("https://example.com/scim/v2", "token")
      iex> request = ExScimClient.Request.new(client) |> ExScimClient.Request.basic("user", "pass")
      iex> headers = Keyword.get(request, :headers)
      iex> Enum.any?(headers, fn {key, value} -> key == "authorization" and String.starts_with?(value, "Basic ") end)
      true

  """
  @spec basic(t(), String.t(), String.t()) :: t()
  def basic(req, username, password) do
    credentials = Base.encode64("#{username}:#{password}")
    headers = Keyword.get(req, :headers, [])
    Keyword.put(req, :headers, [{"authorization", "Basic #{credentials}"} | headers])
  end

  @doc """
  Sets the path for the request.

  ## Examples

      iex> client = ExScimClient.Client.new("https://example.com/scim/v2", "token")
      iex> request = ExScimClient.Request.new(client) |> ExScimClient.Request.path("/Users")
      iex> Keyword.get(request, :url)
      "https://example.com/scim/v2/Users"

  """
  @spec path(t(), String.t()) :: t()
  def path(req, endpoint) do
    base_url = Keyword.get(req, :base_url)

    if is_nil(base_url) do
      raise ArgumentError, "base_url cannot be nil"
    end

    # Ensure base_url ends with / and endpoint starts without /
    normalized_base = if String.ends_with?(base_url, "/"), do: base_url, else: base_url <> "/"
    normalized_endpoint = String.trim_leading(endpoint, "/")

    full_url = normalized_base <> normalized_endpoint
    Keyword.put(req, :url, full_url)
  end

  @doc """
  Sets the HTTP method for the request.

  ## Examples

      iex> client = ExScimClient.Client.new("https://example.com/scim/v2", "token")
      iex> request = ExScimClient.Request.new(client) |> ExScimClient.Request.method(:post)
      iex> Keyword.get(request, :method)
      :post

  """
  @spec method(t(), atom()) :: t()
  def method(req, verb) do
    Keyword.put(req, :method, verb)
  end

  @doc """
  Sets the JSON body for the request.

  ## Examples

      iex> client = ExScimClient.Client.new("https://example.com/scim/v2", "token")
      iex> user_data = %{"userName" => "jdoe", "active" => true}
      iex> request = ExScimClient.Request.new(client) |> ExScimClient.Request.body(user_data)
      iex> Keyword.get(request, :json)
      %{"userName" => "jdoe", "active" => true}

  """
  @spec body(t(), map()) :: t()
  def body(req, json) do
    Keyword.put(req, :json, json)
  end

  @doc """
  Adds a filter to the request.

  Accepts either a Filter struct or a filter string.

  ## Examples

      iex> client = ExScimClient.Client.new("https://example.com/scim/v2", "token")
      iex> filter_struct = ExScimClient.Filter.new() |> ExScimClient.Filter.equals("active", "true")
      iex> request = ExScimClient.Request.new(client) |> ExScimClient.Request.filter(filter_struct)
      iex> scim_params = Keyword.get(request, :scim_params, %{})
      iex> Map.get(scim_params, :filter)
      "active eq true"

      iex> client = ExScimClient.Client.new("https://example.com/scim/v2", "token")
      iex> request = ExScimClient.Request.new(client) |> ExScimClient.Request.filter("userName eq jdoe")
      iex> scim_params = Keyword.get(request, :scim_params, %{})
      iex> Map.get(scim_params, :filter)
      "userName eq jdoe"

  """
  @spec filter(t(), Filter.t() | String.t()) :: t()
  def filter(req, %Filter{} = filter_struct) do
    filter(req, Filter.build(filter_struct))
  end

  def filter(req, filter_string) when is_binary(filter_string) do
    scim_params = Keyword.get(req, :scim_params, %{})
    updated_params = Map.put(scim_params, :filter, filter_string)
    Keyword.put(req, :scim_params, updated_params)
  end

  def filter(req, _), do: req

  @doc """
  Adds sorting parameters to the request.

  ## Examples

      iex> client = ExScimClient.Client.new("https://example.com/scim/v2", "token")
      iex> sorting = ExScimClient.Sorting.new("userName", :desc)
      iex> request = ExScimClient.Request.new(client) |> ExScimClient.Request.sort_by(sorting)
      iex> scim_params = Keyword.get(request, :scim_params, %{})
      iex> {Map.get(scim_params, :sort_by), Map.get(scim_params, :sort_order)}
      {"userName", :desc}

  """
  @spec sort_by(t(), Sorting.t()) :: t()
  def sort_by(req, %Sorting{} = sorting_struct) do
    updated_params =
      req
      |> Keyword.get(:scim_params, %{})
      |> Map.merge(%{sort_by: sorting_struct.by, sort_order: sorting_struct.order})

    Keyword.put(req, :scim_params, updated_params)
  end

  def sort_by(req, _), do: req

  @doc """
  Adds pagination parameters to the request.

  ## Examples

      iex> client = ExScimClient.Client.new("https://example.com/scim/v2", "token")
      iex> pagination = ExScimClient.Pagination.new(1, 50)
      iex> request = ExScimClient.Request.new(client) |> ExScimClient.Request.paginate(pagination)
      iex> scim_params = Keyword.get(request, :scim_params, %{})
      iex> {Map.get(scim_params, :start_index), Map.get(scim_params, :count)}
      {1, 50}

  """
  @spec paginate(t(), Pagination.t()) :: t()
  def paginate(req, %Pagination{} = pagination_struct) do
    updated_params =
      req
      |> Keyword.get(:scim_params, %{})
      |> Map.merge(%{start_index: pagination_struct.start_index, count: pagination_struct.count})

    Keyword.put(req, :scim_params, updated_params)
  end

  def paginate(req, _), do: req

  @doc """
  Sets attributes to include in the response.

  ## Examples

      iex> client = ExScimClient.Client.new("https://example.com/scim/v2", "token")
      iex> request = ExScimClient.Request.new(client) |> ExScimClient.Request.attributes(["userName", "emails"])
      iex> scim_params = Keyword.get(request, :scim_params, %{})
      iex> Map.get(scim_params, :attributes)
      ["userName", "emails"]

  """
  @spec attributes(t(), list(String.t())) :: t()
  def attributes(req, attribute_list) when is_list(attribute_list) do
    scim_params = Keyword.get(req, :scim_params, %{})
    updated_params = Map.put(scim_params, :attributes, attribute_list)
    Keyword.put(req, :scim_params, updated_params)
  end

  def attributes(req, _), do: req

  @doc """
  Sets attributes to exclude from the response.

  ## Examples

      iex> client = ExScimClient.Client.new("https://example.com/scim/v2", "token")
      iex> request = ExScimClient.Request.new(client) |> ExScimClient.Request.excluded_attributes(["meta", "groups"])
      iex> scim_params = Keyword.get(request, :scim_params, %{})
      iex> Map.get(scim_params, :excluded_attributes)
      ["meta", "groups"]

  """
  @spec excluded_attributes(t(), list(String.t())) :: t()
  def excluded_attributes(req, attribute_list)
      when is_list(attribute_list) do
    scim_params = Keyword.get(req, :scim_params, %{})
    updated_params = Map.put(scim_params, :excluded_attributes, attribute_list)
    Keyword.put(req, :scim_params, updated_params)
  end

  def excluded_attributes(req, _), do: req

  defp build_query_parameters(req) do
    case Keyword.get(req, :scim_params) do
      nil ->
        req

      scim_params when map_size(scim_params) == 0 ->
        req

      scim_params ->
        current_url = Keyword.get(req, :url)
        if is_nil(current_url), do: raise(ArgumentError, "url cannot be nil")

        query_map = build_scim_query_map(scim_params)
        updated_url = merge_query_parameter(current_url, query_map)

        req
        |> Keyword.put(:url, updated_url)
        # Clean up after building
        |> Keyword.delete(:scim_params)
    end
  end

  defp build_scim_query_map(scim_params) do
    scim_params
    |> Enum.reduce(%{}, fn
      {:filter, %Filter{} = filter}, acc ->
        Map.put(acc, "filter", Filter.build(filter))

      {:filter, filter_string}, acc when is_binary(filter_string) ->
        Map.put(acc, "filter", filter_string)

      {:sort_by, attribute}, acc ->
        Map.put(acc, "sortBy", attribute)

      # Default, don't add
      {:sort_order, :asc}, acc ->
        acc

      {:sort_order, :desc}, acc ->
        Map.put(acc, "sortOrder", "descending")

      {:start_index, index}, acc ->
        Map.put(acc, "startIndex", to_string(index))

      {:count, count}, acc ->
        Map.put(acc, "count", to_string(count))

      {:attributes, attrs}, acc when is_list(attrs) ->
        Map.put(acc, "attributes", Enum.join(attrs, ","))

      {:excluded_attributes, attrs}, acc when is_list(attrs) ->
        Map.put(acc, "excludedAttributes", Enum.join(attrs, ","))

      # Ignore unknown parameters
      {_key, _value}, acc ->
        acc
    end)
  end

  defp merge_query_parameter(current_url, params) do
    uri = URI.parse(current_url)

    # Merge new params with existing query params
    existing_params = URI.decode_query(uri.query || "")
    merged_params = Map.merge(existing_params, params)

    %{uri | query: URI.encode_query(merged_params)}
    |> URI.to_string()
  end

  @doc """
  Executes the built request.

  ## Examples

      iex> client = ExScimClient.Client.new("https://example.com/scim/v2", "token")
      iex> {:ok, _response} = ExScimClient.Request.new(client)
      ...> |> ExScimClient.Request.path("/Users")
      ...> |> ExScimClient.Request.method(:get)
      ...> |> ExScimClient.Request.run()

  """
  @spec run(t()) :: {:ok, map()} | {:error, term()}
  def run(req) do
    req
    |> build_query_parameters()
    |> do_run()
  end

  defp do_run(req) do
    try do
      with request <- Req.new(req),
           {:ok, response} <- Req.request(request) do
        if response.status >= 200 and response.status < 300 do
          {:ok, response.body}
        else
          {:error, %{status: response.status, body: response.body}}
        end
      else
        {:error, %Req.TransportError{reason: reason}} -> {:error, reason}
        error -> {:error, error}
      end
    rescue
      error -> {:error, error}
    end
  end
end
