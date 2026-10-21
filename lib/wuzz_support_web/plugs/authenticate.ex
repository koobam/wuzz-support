defmodule WuzzSupportWeb.Plugs.Authenticate do
  import Plug.Conn

  alias WuzzSupport.Auth.Token

  def init(opts), do: opts

  def call(conn, _opts) do
    with ["Bearer " <> token] <- get_req_header(conn, "authorization"),
         {:ok, identity} <- Token.verify(token) do
      assign(conn, :identity, identity)
    else
      _ ->
        conn
        |> put_status(:unauthorized)
        |> Phoenix.Controller.json(%{error: "unauthorized"})
        |> halt()
    end
  end
end
