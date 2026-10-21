defmodule WuzzSupportWeb.Router do
  use Phoenix.Router

  pipeline :api do
    plug :accepts, ["json"]
  end

  pipeline :authed do
    plug WuzzSupportWeb.Plugs.Authenticate
  end

  # Liveness for orchestrators; no auth, no database.
  get "/healthz", WuzzSupportWeb.HealthController, :show

  scope "/api", WuzzSupportWeb do
    pipe_through [:api, :authed]

    get "/ice-servers", ConversationController, :ice_servers
    get "/conversations", ConversationController, :index
    post "/conversations", ConversationController, :create
    get "/conversations/:id/messages", ConversationController, :messages
    post "/conversations/:id/close", ConversationController, :close
  end
end
