import Config

if config_env() == :prod do
  config :wuzz_support, :mongo,
    name: :mongo,
    url: System.fetch_env!("MONGODB_URI"),
    pool_size: String.to_integer(System.get_env("POOL_SIZE", "10"))

  # Days to keep chat messages and closed threads. 0 keeps them forever.
  config :wuzz_support,
         :retention_days,
         String.to_integer(System.get_env("MESSAGE_RETENTION_DAYS", "0"))

  config :wuzz_support, WuzzSupportWeb.Endpoint,
    # A release does not start the HTTP server unless told to.
    server: true,
    http: [ip: {0, 0, 0, 0}, port: String.to_integer(System.get_env("PORT", "4000"))],
    check_origin: String.split(System.fetch_env!("CORS_ORIGINS"), ",", trim: true),
    secret_key_base: System.fetch_env!("SECRET_KEY_BASE")

  # Base64 raw Ed25519 public keys, comma-separated — same format as the Go
  # services' JWT_PUBLIC_KEYS.
  config :wuzz_support, :auth,
    issuer: System.get_env("JWT_ISSUER", "wuzz-backend"),
    public_keys: String.split(System.fetch_env!("JWT_PUBLIC_KEYS"), ",", trim: true)

  config :wuzz_support, :ice,
    stun_urls:
      String.split(System.get_env("STUN_URLS", "stun:stun.l.google.com:19302"), ",", trim: true),
    turn_urls: String.split(System.get_env("TURN_URLS", ""), ",", trim: true),
    turn_secret: System.get_env("TURN_SECRET"),
    ttl: String.to_integer(System.get_env("TURN_TTL", "3600"))

  config :wuzz_support,
         :cors_origins,
         String.split(System.fetch_env!("CORS_ORIGINS"), ",", trim: true)
end
