import Config

config :wuzz_support, WuzzSupportWeb.Endpoint,
  adapter: Bandit.PhoenixAdapter,
  pubsub_server: WuzzSupport.PubSub,
  render_errors: [formats: [json: WuzzSupportWeb.ErrorJSON], layout: false]

config :phoenix, :json_library, Jason

# Calls: STUN always; TURN (relay for peers behind symmetric NAT) only when
# TURN_URLS and TURN_SECRET are set (see runtime.exs). Secret matches coturn's static-auth-secret.
config :wuzz_support, :ice,
  stun_urls: ["stun:stun.l.google.com:19302"],
  turn_urls: [],
  turn_secret: nil,
  ttl: 3600

config :logger, :default_formatter, format: "$time $metadata[$level] $message\n"

import_config "#{config_env()}.exs"
