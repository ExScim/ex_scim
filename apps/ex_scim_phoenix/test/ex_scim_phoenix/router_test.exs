defmodule ExScimPhoenix.RouterTest do
  use ExUnit.Case, async: true

  # Dummy controller for the custom-controller override test. Route compilation
  # only stores the module reference; a minimal plug interface silences the
  # "init/1 is undefined" verification warning.
  defmodule CustomUserController do
    def init(opts), do: opts
    def call(conn, _opts), do: conn
  end

  # Routers compiled with different feature-toggle options.
  defmodule AllRouter do
    use Phoenix.Router
    use ExScimPhoenix.Router
  end

  defmodule NoBulkRouter do
    use Phoenix.Router
    use ExScimPhoenix.Router, bulk: false
  end

  defmodule NoMeRouter do
    use Phoenix.Router
    use ExScimPhoenix.Router, me: false
  end

  defmodule NoUsersRouter do
    use Phoenix.Router
    use ExScimPhoenix.Router, users: false
  end

  defmodule NoGroupsRouter do
    use Phoenix.Router
    use ExScimPhoenix.Router, groups: false
  end

  defmodule NoSearchRouter do
    use Phoenix.Router
    use ExScimPhoenix.Router, search: false
  end

  defmodule MinimalRouter do
    use Phoenix.Router
    use ExScimPhoenix.Router, users: false, groups: false, me: false, bulk: false, search: false
  end

  defmodule CustomControllerRouter do
    use Phoenix.Router
    use ExScimPhoenix.Router, user_controller: ExScimPhoenix.RouterTest.CustomUserController
  end

  describe "default routes (all features enabled)" do
    test "generates the full set of User routes" do
      assert has_route?(AllRouter, :get, "/Users")
      assert has_route?(AllRouter, :post, "/Users")
      assert has_route?(AllRouter, :get, "/Users/:id")
      assert has_route?(AllRouter, :put, "/Users/:id")
      assert has_route?(AllRouter, :patch, "/Users/:id")
      assert has_route?(AllRouter, :delete, "/Users/:id")
    end

    test "generates Group, Me, search, and bulk routes" do
      assert has_route?(AllRouter, :get, "/Groups")
      assert has_route?(AllRouter, :delete, "/Groups/:id")
      assert has_route?(AllRouter, :get, "/Me")
      assert has_route?(AllRouter, :delete, "/Me")
      assert has_route?(AllRouter, :post, "/Users/.search")
      assert has_route?(AllRouter, :post, "/Groups/.search")
      assert has_route?(AllRouter, :post, "/.search")
      assert has_route?(AllRouter, :post, "/Bulk")
    end

    test "generates discovery routes" do
      assert has_route?(AllRouter, :get, "/ServiceProviderConfig")
      assert has_route?(AllRouter, :get, "/ResourceTypes")
      assert has_route?(AllRouter, :get, "/ResourceTypes/:id")
      assert has_route?(AllRouter, :get, "/Schemas")
      assert has_route?(AllRouter, :get, "/Schemas/:id")
    end

    test "maps verbs/paths to the correct controller actions" do
      assert action(AllRouter, :get, "/Users") == :index
      assert action(AllRouter, :post, "/Users") == :create
      assert action(AllRouter, :get, "/Users/:id") == :show
      assert action(AllRouter, :put, "/Users/:id") == :update
      assert action(AllRouter, :patch, "/Users/:id") == :patch
      assert action(AllRouter, :delete, "/Users/:id") == :delete
      assert action(AllRouter, :post, "/.search") == :search_all
      assert action(AllRouter, :post, "/Users/.search") == :search
    end

    test "routes point at the default controllers" do
      assert plug(AllRouter, :get, "/Users") == ExScimPhoenix.Controller.UserController
      assert plug(AllRouter, :get, "/Groups") == ExScimPhoenix.Controller.GroupController
      assert plug(AllRouter, :get, "/Me") == ExScimPhoenix.Controller.MeController
      assert plug(AllRouter, :post, "/Bulk") == ExScimPhoenix.Controller.BulkController
    end
  end

  describe "feature toggles" do
    test "bulk: false omits the /Bulk route" do
      refute has_route?(NoBulkRouter, :post, "/Bulk")
      # other routes remain
      assert has_route?(NoBulkRouter, :get, "/Users")
    end

    test "me: false omits all /Me routes" do
      refute has_route?(NoMeRouter, :get, "/Me")
      refute has_route?(NoMeRouter, :post, "/Me")
      refute has_route?(NoMeRouter, :put, "/Me")
      refute has_route?(NoMeRouter, :patch, "/Me")
      refute has_route?(NoMeRouter, :delete, "/Me")
      assert has_route?(NoMeRouter, :get, "/Users")
    end

    test "users: false omits /Users routes and /Users/.search" do
      refute has_route?(NoUsersRouter, :get, "/Users")
      refute has_route?(NoUsersRouter, :post, "/Users/.search")
      # groups remain
      assert has_route?(NoUsersRouter, :get, "/Groups")
      assert has_route?(NoUsersRouter, :post, "/Groups/.search")
    end

    test "groups: false omits /Groups routes and /Groups/.search" do
      refute has_route?(NoGroupsRouter, :get, "/Groups")
      refute has_route?(NoGroupsRouter, :post, "/Groups/.search")
      assert has_route?(NoGroupsRouter, :get, "/Users")
    end

    test "search: false omits /.search but keeps resource-scoped search" do
      refute has_route?(NoSearchRouter, :post, "/.search")
      # resource-scoped search follows the users/groups toggles, not :search
      assert has_route?(NoSearchRouter, :post, "/Users/.search")
      assert has_route?(NoSearchRouter, :post, "/Groups/.search")
    end

    test "discovery routes are always present, even with every feature disabled" do
      assert has_route?(MinimalRouter, :get, "/ServiceProviderConfig")
      assert has_route?(MinimalRouter, :get, "/ResourceTypes")
      assert has_route?(MinimalRouter, :get, "/ResourceTypes/:id")
      assert has_route?(MinimalRouter, :get, "/Schemas")
      assert has_route?(MinimalRouter, :get, "/Schemas/:id")

      # ...and the toggled-off groups are gone
      refute has_route?(MinimalRouter, :get, "/Users")
      refute has_route?(MinimalRouter, :get, "/Groups")
      refute has_route?(MinimalRouter, :get, "/Me")
      refute has_route?(MinimalRouter, :post, "/Bulk")
      refute has_route?(MinimalRouter, :post, "/.search")
    end
  end

  describe "custom controllers" do
    test "user_controller option overrides the default User controller" do
      assert plug(CustomControllerRouter, :get, "/Users") ==
               ExScimPhoenix.RouterTest.CustomUserController

      assert plug(CustomControllerRouter, :post, "/Users") ==
               ExScimPhoenix.RouterTest.CustomUserController

      # non-overridden controllers keep their defaults
      assert plug(CustomControllerRouter, :get, "/Groups") ==
               ExScimPhoenix.Controller.GroupController
    end
  end

  # --- helpers ---

  defp find(router, verb, path) do
    Enum.find(router.__routes__(), &(&1.verb == verb and &1.path == path))
  end

  defp has_route?(router, verb, path), do: find(router, verb, path) != nil
  defp action(router, verb, path), do: find(router, verb, path).plug_opts
  defp plug(router, verb, path), do: find(router, verb, path).plug
end
