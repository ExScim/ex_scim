defmodule ExScim.Lifecycle.Adapter do
  @moduledoc """
  Behaviour for lifecycle hooks around SCIM operations.

  Implement this behaviour to run custom logic before or after SCIM operations.
  All callbacks are optional. Unimplemented callbacks are no-ops.

  ## Configuration

      config :ex_scim, lifecycle_adapter: MyApp.ScimLifecycle

  ## Before hooks

  Fire after validation/mapping/metadata, immediately before storage.
  Can modify domain data or reject the operation by returning `{:error, term()}`.

  ## After hooks

  Fire after successful storage + SCIM response mapping. Observe-only (return `:ok`).

  ## Error hook

  Fires when an operation fails. Observe-only.

  ## Example

      defmodule MyApp.ScimLifecycle do
        use ExScim.Lifecycle.Adapter

        @impl true
        def before_create(:user, data, _caller) do
          if some_business_rule_violated?(data) do
            {:error, {:forbidden, "Business rule violated"}}
          else
            {:ok, data}
          end
        end

        @impl true
        def after_create(:user, scim_response, _caller) do
          MyApp.Notifications.send_welcome(scim_response["id"])
          :ok
        end
      end
  """

  @typedoc "The type of resource being operated on: `:user` or `:group`."
  @type resource_type :: :user | :group

  @typedoc "The domain-level resource data (struct or map) being processed."
  @type resource_data :: term()

  @typedoc "The unique identifier of the resource."
  @type resource_id :: binary()

  @typedoc "The SCIM JSON response map after mapping from the domain struct."
  @type scim_response :: map()

  @typedoc "The authenticated caller scope for the current request."
  @type caller :: ExScim.Scope.t()

  @typedoc "The SCIM operation type that triggered the hook."
  @type operation :: :create | :replace | :patch | :delete | :get

  # Before hooks: can modify data or reject

  @doc "Fires before a resource is created. Return `{:ok, data}` to proceed or `{:error, reason}` to reject."
  @callback before_create(resource_type(), resource_data(), caller()) ::
              {:ok, resource_data()} | {:error, term()}

  @doc "Fires before a resource is replaced (PUT). Return `{:ok, data}` to proceed or `{:error, reason}` to reject."
  @callback before_replace(resource_type(), resource_id(), resource_data(), caller()) ::
              {:ok, resource_data()} | {:error, term()}

  @doc "Fires before a resource is patched. Return `{:ok, data}` to proceed or `{:error, reason}` to reject."
  @callback before_patch(resource_type(), resource_id(), resource_data(), caller()) ::
              {:ok, resource_data()} | {:error, term()}

  @doc "Fires before a resource is deleted. Return `:ok` to proceed or `{:error, reason}` to reject."
  @callback before_delete(resource_type(), resource_id(), caller()) ::
              :ok | {:error, term()}

  @doc "Fires before a resource is retrieved. Return `:ok` to proceed or `{:error, reason}` to reject."
  @callback before_get(resource_type(), resource_id(), caller()) ::
              :ok | {:error, term()}

  # After hooks: observe only

  @doc "Fires after a resource is successfully created. Observe-only."
  @callback after_create(resource_type(), scim_response(), caller()) :: :ok

  @doc "Fires after a resource is successfully replaced. Observe-only."
  @callback after_replace(resource_type(), scim_response(), caller()) :: :ok

  @doc "Fires after a resource is successfully patched. Observe-only."
  @callback after_patch(resource_type(), scim_response(), caller()) :: :ok

  @doc "Fires after a resource is successfully deleted. Observe-only."
  @callback after_delete(resource_type(), resource_id(), caller()) :: :ok

  @doc "Fires after a resource is successfully retrieved. Observe-only."
  @callback after_get(resource_type(), scim_response(), caller()) :: :ok

  # Error hook: observe only

  @doc "Fires when an operation fails. Observe-only; intended for logging or metrics."
  @callback on_error(operation(), resource_type(), term(), caller()) :: :ok

  @optional_callbacks [
    before_create: 3,
    before_replace: 4,
    before_patch: 4,
    before_delete: 3,
    before_get: 3,
    after_create: 3,
    after_replace: 3,
    after_patch: 3,
    after_delete: 3,
    after_get: 3,
    on_error: 4
  ]

  defmacro __using__(_opts) do
    quote do
      @behaviour ExScim.Lifecycle.Adapter

      @impl true
      def before_create(_resource_type, resource_data, _caller), do: {:ok, resource_data}

      @impl true
      def before_replace(_resource_type, _resource_id, resource_data, _caller),
        do: {:ok, resource_data}

      @impl true
      def before_patch(_resource_type, _resource_id, resource_data, _caller),
        do: {:ok, resource_data}

      @impl true
      def before_delete(_resource_type, _resource_id, _caller), do: :ok

      @impl true
      def before_get(_resource_type, _resource_id, _caller), do: :ok

      @impl true
      def after_create(_resource_type, _scim_response, _caller), do: :ok

      @impl true
      def after_replace(_resource_type, _scim_response, _caller), do: :ok

      @impl true
      def after_patch(_resource_type, _scim_response, _caller), do: :ok

      @impl true
      def after_delete(_resource_type, _resource_id, _caller), do: :ok

      @impl true
      def after_get(_resource_type, _scim_response, _caller), do: :ok

      @impl true
      def on_error(_operation, _resource_type, _error, _caller), do: :ok

      defoverridable before_create: 3,
                     before_replace: 4,
                     before_patch: 4,
                     before_delete: 3,
                     before_get: 3,
                     after_create: 3,
                     after_replace: 3,
                     after_patch: 3,
                     after_delete: 3,
                     after_get: 3,
                     on_error: 4
    end
  end
end
