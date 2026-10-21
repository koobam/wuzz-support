defmodule WuzzSupportWeb.Endpoint do
  use Phoenix.Endpoint, otp_app: :wuzz_support

  # Clients connect to /socket/websocket?token=<access token>.
  socket "/socket", WuzzSupportWeb.UserSocket,
    websocket: [connect_info: [:peer_data]],
    longpoll: false

  plug Plug.RequestId
  plug Plug.Telemetry, event_prefix: [:phoenix, :endpoint]

  plug Plug.Parsers,
    parsers: [:json],
    pass: ["application/json"],
    json_decoder: Phoenix.json_library()

  plug CORSPlug, origin: &WuzzSupportWeb.Endpoint.cors_origins/0
  plug WuzzSupportWeb.Router

  def cors_origins, do: Application.get_env(:wuzz_support, :cors_origins, [])
end
