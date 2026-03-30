defmodule ScimTester.SchemaPayload do
  @moduledoc """
  Generates SCIM test payloads based on a provider's declared schema.

  Operates on raw schema JSON maps (same format returned by /Schemas endpoint).
  Generates type-appropriate values using name-based heuristics for known SCIM
  attributes, with type-based fallbacks for unknown ones.
  """

  alias ScimTester.DataGenConfig

  @user_schema_uri "urn:ietf:params:scim:schemas:core:2.0:User"

  @server_controlled_names MapSet.new(["id", "meta", "groups"])

  @doc """
  Generates a create payload from the given schema.

  Includes all required writable attributes plus a random subset of optional ones.
  Always includes `userName` and the `schemas` key.
  """
  def generate_create_payload(schema, config \\ DataGenConfig.default()) do
    schema_uri = Map.get(schema, "id", @user_schema_uri)
    {required, optional} = schema |> writable_attributes() |> partition_attributes()

    # Always ensure userName is present
    {required, optional} = ensure_username(required, optional)

    selected_optional = Enum.take_random(optional, min(5, length(optional)))
    attrs = required ++ selected_optional

    payload =
      Enum.reduce(attrs, %{}, fn attr, acc ->
        name = Map.get(attr, "name")
        value = generate_value(attr, config)

        if value != :skip do
          put_attribute(acc, name, value)
        else
          acc
        end
      end)

    Map.put(payload, "schemas", [schema_uri])
  end

  @doc """
  Generates an update payload by modifying 2-4 mutable attributes of the existing user.

  Preserves `userName` and skips immutable attributes.
  """
  def generate_update_payload(schema, existing_user, config \\ DataGenConfig.default()) do
    mutable_attrs =
      schema
      |> writable_attributes()
      |> Enum.reject(fn attr ->
        name = Map.get(attr, "name")
        mutability = Map.get(attr, "mutability", "readWrite")
        name == "userName" or mutability == "immutable"
      end)

    count = min(Enum.random(2..4), length(mutable_attrs))
    selected = Enum.take_random(mutable_attrs, count)

    Enum.reduce(selected, existing_user, fn attr, acc ->
      name = Map.get(attr, "name")
      value = generate_value(attr, config)

      if value != :skip do
        put_attribute(acc, name, value)
      else
        acc
      end
    end)
  end

  @doc """
  Generates SCIM PATCH operations from the schema.

  Picks one non-required, mutable, non-complex, non-userName attribute and returns
  a replace operation for it. Falls back through increasingly relaxed criteria.
  """
  def generate_patch_operations(schema, config \\ DataGenConfig.default()) do
    attrs = writable_attributes(schema)

    # Ideal: non-required, mutable, non-complex, non-userName
    candidate =
      Enum.find(attrs, fn attr ->
        name = Map.get(attr, "name")
        type = Map.get(attr, "type", "string")
        required = Map.get(attr, "required", false)
        name != "userName" and !required and type != "complex"
      end)

    # Fallback: any mutable non-required
    candidate =
      candidate ||
        Enum.find(attrs, fn attr ->
          name = Map.get(attr, "name")
          required = Map.get(attr, "required", false)
          name != "userName" and !required
        end)

    case candidate do
      nil ->
        # Absolute fallback
        [
          %{
            "op" => "replace",
            "path" => "title",
            "value" => "Senior #{DataGenConfig.random_job_title(config)}"
          }
        ]

      attr ->
        name = Map.get(attr, "name")
        value = generate_value(attr, config)
        value = if value == :skip, do: "test_#{random_string(8)}", else: value

        # For complex/multi-valued attrs, use the generated value directly
        [%{"op" => "replace", "path" => name, "value" => value}]
    end
  end

  @doc """
  Extracts writable attributes from a schema, excluding server-controlled
  and reference-type attributes.
  """
  def writable_attributes(schema) do
    schema
    |> Map.get("attributes", [])
    |> Enum.reject(fn attr ->
      name = Map.get(attr, "name", "")
      type = Map.get(attr, "type", "string")
      mutability = Map.get(attr, "mutability", "readWrite")

      mutability == "readOnly" or
        type == "reference" or
        MapSet.member?(@server_controlled_names, name)
    end)
  end

  @doc """
  Splits attributes into `{required, optional}` based on the `required` field.
  """
  def partition_attributes(attrs) do
    Enum.split_with(attrs, fn attr ->
      Map.get(attr, "required", false) == true
    end)
  end

  # Ensure userName is in the required list
  defp ensure_username(required, optional) do
    has_username =
      Enum.any?(required ++ optional, fn attr ->
        Map.get(attr, "name") == "userName"
      end)

    if has_username do
      # Move userName to required if it's in optional
      {in_opt, rest_opt} =
        Enum.split_with(optional, fn attr -> Map.get(attr, "name") == "userName" end)

      {required ++ in_opt, rest_opt}
    else
      # Synthesize a userName attribute
      synthetic = %{"name" => "userName", "type" => "string", "required" => true}
      {[synthetic | required], optional}
    end
  end

  defp put_attribute(map, name, value), do: Map.put(map, name, value)

  # --- Value Generation ---

  defp generate_value(attr, config) do
    name = Map.get(attr, "name", "")
    type = Map.get(attr, "type", "string")
    multi_valued = Map.get(attr, "multiValued", false)
    canonical_values = Map.get(attr, "canonicalValues")
    sub_attributes = Map.get(attr, "subAttributes", [])

    cond do
      canonical_values && is_list(canonical_values) && canonical_values != [] ->
        value = Enum.random(canonical_values)
        if multi_valued, do: [value], else: value

      value = name_heuristic(name, config) ->
        value

      true ->
        type_fallback(type, multi_valued, sub_attributes, config)
    end
  end

  # Name-based heuristics for known SCIM attribute names
  defp name_heuristic("userName", _config), do: "test_user_#{random_string(8)}"

  defp name_heuristic("displayName", config) do
    "#{DataGenConfig.random_first_name(config)} #{DataGenConfig.random_last_name(config)}"
  end

  defp name_heuristic("givenName", config), do: DataGenConfig.random_first_name(config)
  defp name_heuristic("familyName", config), do: DataGenConfig.random_last_name(config)
  defp name_heuristic("title", config), do: DataGenConfig.random_job_title(config)
  defp name_heuristic("active", _config), do: true
  defp name_heuristic("userType", _config), do: Enum.random(["Employee", "Contractor", "Intern"])
  defp name_heuristic("preferredLanguage", _config), do: Enum.random(["en", "de", "fr", "es"])
  defp name_heuristic("locale", _config), do: Enum.random(["en-US", "de-DE", "fr-FR"])

  defp name_heuristic("timezone", _config),
    do: Enum.random(["America/New_York", "Europe/Berlin", "UTC"])

  defp name_heuristic("nickName", _config), do: "nick_#{random_string(5)}"

  defp name_heuristic("profileUrl", config),
    do: DataGenConfig.random_url(config, "users/#{random_string(8)}")

  defp name_heuristic("externalId", _config), do: "ext_#{random_string(10)}"

  defp name_heuristic("name", config) do
    %{
      "givenName" => DataGenConfig.random_first_name(config),
      "familyName" => DataGenConfig.random_last_name(config)
    }
  end

  defp name_heuristic("emails", config) do
    first = DataGenConfig.random_first_name(config)
    last = DataGenConfig.random_last_name(config)
    email = DataGenConfig.random_email(config, first, last)
    [%{"value" => email, "type" => "work", "primary" => true}]
  end

  defp name_heuristic("phoneNumbers", _config) do
    suffix = Enum.random(1000..9999)
    [%{"value" => "+1-555-#{suffix}", "type" => "work"}]
  end

  defp name_heuristic("addresses", _config) do
    [%{"streetAddress" => "123 Test St", "locality" => "Testville", "type" => "work"}]
  end

  defp name_heuristic("photos", config) do
    [
      %{
        "value" => DataGenConfig.random_url(config, "photos/#{random_string(8)}.jpg"),
        "type" => "photo"
      }
    ]
  end

  defp name_heuristic("ims", _config) do
    [%{"value" => "test_#{random_string(6)}", "type" => "aim"}]
  end

  defp name_heuristic("roles", _config) do
    [%{"value" => "user"}]
  end

  defp name_heuristic("entitlements", _config) do
    [%{"value" => "basic"}]
  end

  defp name_heuristic("x509Certificates", _config), do: :skip

  defp name_heuristic(_name, _config), do: nil

  # Type-based fallback for unknown attributes
  defp type_fallback("string", _multi, _sub, _config), do: "test_#{random_string(8)}"
  defp type_fallback("boolean", _multi, _sub, _config), do: true
  defp type_fallback("integer", _multi, _sub, _config), do: Enum.random(1..100)
  defp type_fallback("decimal", _multi, _sub, _config), do: Enum.random(1..100) / 10.0

  defp type_fallback("dateTime", _multi, _sub, _config),
    do: DateTime.utc_now() |> DateTime.to_iso8601()

  defp type_fallback("binary", _multi, _sub, _config), do: :skip

  defp type_fallback("complex", multi, sub_attributes, config) do
    sub_map =
      sub_attributes
      |> Enum.reject(fn sub ->
        sub_name = Map.get(sub, "name", "")
        sub_mutability = Map.get(sub, "mutability", "readWrite")
        sub_name == "$ref" or sub_mutability == "readOnly"
      end)
      |> Enum.reduce(%{}, fn sub, acc ->
        sub_name = Map.get(sub, "name", "")
        sub_value = generate_value(sub, config)

        if sub_value != :skip do
          Map.put(acc, sub_name, sub_value)
        else
          acc
        end
      end)

    if multi, do: [sub_map], else: sub_map
  end

  defp type_fallback(_unknown, _multi, _sub, _config), do: "test_#{random_string(8)}"

  defp random_string(length) do
    chars = "abcdefghijklmnopqrstuvwxyz0123456789"
    chars_list = String.graphemes(chars)

    1..length
    |> Enum.map(fn _ -> Enum.random(chars_list) end)
    |> Enum.join("")
  end
end
