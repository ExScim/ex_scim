defmodule ProviderWeb.Router do
  use ProviderWeb, :router

  pipeline :browser do
    plug(:accepts, ["html"])
    plug(:fetch_session)
    plug(:fetch_live_flash)
    plug(:put_root_layout, html: {ProviderWeb.Layouts, :root})
    plug(:protect_from_forgery)
    plug(:put_secure_browser_headers)
  end

  pipeline :api do
    plug(:accepts, ["json"])
  end

  pipeline :scim_api do
    plug(:accepts, ["json", "scim+json"])
    plug(:put_secure_browser_headers)
    plug(ExScimPhoenix.Plugs.ScimContentType)
    plug(ExScimPhoenix.Plugs.RequestLogger)
    plug(ExScimPhoenix.Plugs.ScimAuth)
    # plug ProviderWeb.Plugs.ScimErrorHandler
  end

  # SCIM v2 API routes - RFC 7644 compliant
  scope "/scim/v2" do
    pipe_through(:scim_api)

    use ExScimPhoenix.Router
  end

  scope "/", ProviderWeb do
    pipe_through(:browser)

    get("/", PageController, :home)

    live("/users", UserLive.Index, :index)
    live("/users/new", UserLive.Form, :new)
    live("/users/:id/edit", UserLive.Form, :edit)

    live("/users/:id", UserLive.Show, :show)
    live("/users/:id/show/edit", UserLive.Show, :edit)

    live("/groups", GroupLive.Index, :index)
    live("/groups/new", GroupLive.Form, :new)
    live("/groups/:id/edit", GroupLive.Form, :edit)

    live("/groups/:id", GroupLive.Show, :show)
    live("/groups/:id/show/edit", GroupLive.Show, :edit)
  end

  # Other scopes may use custom stacks.
  # scope "/api", ProviderWeb do
  #   pipe_through :api
  # end

  # Enable LiveDashboard and Swoosh mailbox preview in development
  if Application.compile_env(:provider, :dev_routes) do
    # If you want to use the LiveDashboard in production, you should put
    # it behind authentication and allow only admins to access it.
    # If your application does not have an admins-only section yet,
    # you can use Plug.BasicAuth to set up some basic authentication
    # as long as you are also using SSL (which you should anyway).
    import Phoenix.LiveDashboard.Router

    scope "/dev" do
      pipe_through(:browser)

      live_dashboard("/dashboard", metrics: ProviderWeb.Telemetry)
      forward("/mailbox", Plug.Swoosh.MailboxPreview)
    end
  end
end
