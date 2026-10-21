defmodule WuzzSupportWeb.HealthController do
  use WuzzSupportWeb, :controller

  def show(conn, _params), do: json(conn, %{status: "ok"})
end
