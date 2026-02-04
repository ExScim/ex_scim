defmodule ExScimPhoenix.Controller.MeController do
  @moduledoc """
  SCIM 2.0 /Me controller for authenticated user profile management.
  """

  use Phoenix.Controller, formats: [:json]
  require Logger

  alias ExScim.Operations.Users
  alias ExScim.Auth.Principal
  alias ExScim.Config
  import ExScimPhoenix.ErrorResponse

  plug(ExScimPhoenix.Plugs.RequireScopes, [scopes: "scim:me:read"] when action in [:read])
  plug(ExScimPhoenix.Plugs.RequireScopes, [scopes: "scim:me:create"] when action in [:create])

  plug(
    ExScimPhoenix.Plugs.RequireScopes,
    [scopes: ["scim:me:update"]] when action in [:update, :patch]
  )

  plug(ExScimPhoenix.Plugs.RequireScopes, [scopes: "scim:me:delete"] when action in [:delete])

  def show(conn, _params) do
    case conn.assigns[:scim_principal] do
      %Principal{id: user_id} = caller ->
        with {:ok, user} <- Users.get_user(user_id, caller) do
          conn
          |> put_resp_header("location", scim_me_location(conn))
          |> json(user)
        else
          {:error, :insufficient_scope} ->
            send_scim_error(
              conn,
              :forbidden,
              :insufficient_scope,
              "The authenticated user lacks required scope for /Me endpoint"
            )

          {:error, :not_found} ->
            send_scim_error(conn, :not_found, :not_found, "Authenticated user not found")

          {:error, :mapping_error} ->
            send_scim_error(conn, :internal_server_error, :internal_error, "Error mapping user data")
        end

      _ ->
        send_scim_error(
          conn,
          :unauthorized,
          :no_authn,
          "Authentication required for /Me endpoint"
        )
    end
  end

  def create(conn, user_params) do
    caller = conn.assigns[:scim_principal]

    with {:ok, enhanced_params} <- enhance_params_for_me_create(user_params, caller),
         {:ok, user} <- Users.create_user_from_scim(enhanced_params, caller) do
      conn
      |> put_status(:created)
      |> put_resp_header("location", scim_me_location(conn))
      |> put_resp_header("etag", get_in(user, ["meta", "etag"]))
      |> json(user)
    else
      {:error, :anonymous_not_allowed} ->
        send_scim_error(conn, :forbidden, :forbidden, "Anonymous self-registration not allowed")

      {:error, :already_exists} ->
        send_scim_error(
          conn,
          :conflict,
          :uniqueness,
          "User already exists for authenticated subject"
        )

      {:error, :conflict} ->
        send_scim_error(
          conn,
          :conflict,
          :uniqueness,
          "User already exists for authenticated subject"
        )

      {:error, :mapping_error} ->
        send_scim_error(conn, :internal_server_error, :internal_error, "Error mapping user data")

      {:error, errors} when is_list(errors) ->
        send_validation_errors(conn, errors)

      {:error, reason} ->
        Logger.error("Error in /Me create: #{inspect(reason)}")
        send_scim_error(conn, :bad_request, :invalid_value, "Invalid self-registration request")
    end
  end

  def update(conn, user_params) do
    caller = conn.assigns[:scim_principal]
    user_id = caller.id
    clean_params = Map.delete(user_params, "id")

    case Users.replace_user_from_scim(user_id, clean_params, caller) do
      {:ok, user} ->
        conn
        |> put_resp_header("location", scim_me_location(conn))
        |> put_resp_header("etag", get_in(user, ["meta", "etag"]))
        |> json(user)

      {:error, :user_not_found} ->
        send_scim_error(conn, :not_found, :not_found, "Authenticated user not found")

      {:error, :conflict} ->
        send_scim_error(conn, :conflict, :uniqueness, "User data conflicts with existing user")

      {:error, :mapping_error} ->
        send_scim_error(conn, :internal_server_error, :internal_error, "Error mapping user data")

      {:error, errors} when is_list(errors) ->
        send_validation_errors(conn, errors)

      {:error, reason} ->
        Logger.error("Error updating /Me: #{inspect(reason)}")
        send_scim_error(conn, :internal_server_error, :internal_error, "Internal server error")
    end
  end

  def patch(conn, patch_params) do
    caller = conn.assigns[:scim_principal]
    user_id = caller.id
    clean_params = Map.delete(patch_params, "id")

    case Users.patch_user_from_scim(user_id, clean_params, caller) do
      {:ok, user} ->
        conn
        |> put_resp_header("location", scim_me_location(conn))
        |> put_resp_header("etag", get_in(user, ["meta", "etag"]))
        |> json(user)

      {:error, :user_not_found} ->
        send_scim_error(conn, :not_found, :not_found, "Authenticated user not found")

      {:error, :invalid_patch_operation} ->
        send_scim_error(conn, :bad_request, :invalid_syntax, "Invalid patch operation")

      {:error, :no_target} ->
        send_scim_error(
          conn,
          :bad_request,
          :no_target,
          "Path attribute did not yield a valid target"
        )

      {:error, :invalid_path} ->
        send_scim_error(
          conn,
          :bad_request,
          :invalid_path,
          "Path attribute is invalid or malformed"
        )

      {:error, :mapping_error} ->
        send_scim_error(conn, :internal_server_error, :internal_error, "Error mapping user data")

      {:error, errors} when is_list(errors) ->
        send_validation_errors(conn, errors)

      {:error, reason} ->
        Logger.error("Error patching /Me: #{inspect(reason)}")
        send_scim_error(conn, :internal_server_error, :internal_error, "Internal server error")
    end
  end

  def delete(conn, _params) do
    user_id = conn.assigns[:scim_principal].id

    case Users.delete_user(user_id) do
      :ok ->
        send_resp(conn, :no_content, "")

      {:error, :not_found} ->
        send_scim_error(conn, :not_found, :not_found, "Authenticated user not found")

      {:error, reason} ->
        Logger.error("Error deleting /Me: #{inspect(reason)}")
        send_scim_error(conn, :internal_server_error, :internal_error, "Internal server error")
    end
  end

  defp enhance_params_for_me_create(user_params, principal) do
    case principal do
      %Principal{metadata: %{claims: claims}} when is_map(claims) ->
        # Extract user info from JWT claims
        enhanced_params =
          user_params
          |> maybe_add_from_claims("userName", claims, "preferred_username")
          |> maybe_add_from_claims("emails", claims, "email")
          |> maybe_add_from_claims("name", claims, ["given_name", "family_name"])
          |> Map.put("externalId", claims["sub"])

        {:ok, enhanced_params}

      %Principal{metadata: %{user_info: user_info}} when is_map(user_info) ->
        # Extract from OAuth user info
        enhanced_params =
          user_params
          |> Map.put("externalId", user_info.subject)
          |> maybe_add_field("userName", user_info.username)
          |> maybe_add_field("emails", format_emails(user_info.email))

        {:ok, enhanced_params}

      %Principal{id: id} ->
        # Fallback — use principal id as externalId
        enhanced_params = Map.put(user_params, "externalId", id)
        {:ok, enhanced_params}
    end
  end

  defp maybe_add_from_claims(params, _field, _claims, _claim_key) when map_size(params) == 0 do
    params
  end

  defp maybe_add_from_claims(params, field, claims, claim_key) when is_binary(claim_key) do
    case Map.get(claims, claim_key) do
      nil -> params
      value -> Map.put_new(params, field, value)
    end
  end

  defp maybe_add_from_claims(params, "name", claims, ["given_name", "family_name"]) do
    given_name = Map.get(claims, "given_name")
    family_name = Map.get(claims, "family_name")

    if given_name || family_name do
      name =
        %{}
        |> maybe_add_field("givenName", given_name)
        |> maybe_add_field("familyName", family_name)

      Map.put_new(params, "name", name)
    else
      params
    end
  end

  defp maybe_add_field(map, _key, nil), do: map
  defp maybe_add_field(map, key, value), do: Map.put(map, key, value)

  defp format_emails(nil), do: nil

  defp format_emails(email) when is_binary(email) do
    [%{"value" => email, "primary" => true}]
  end

  defp format_emails(emails) when is_list(emails) do
    emails
    |> Enum.with_index()
    |> Enum.map(fn {email, index} ->
      %{"value" => email, "primary" => index == 0}
    end)
  end

  defp scim_me_location(_conn) do
    "#{Config.scim_base_url()}/Me"
  end
end
