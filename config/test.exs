import Config

config :wuzz_support, :mongo,
  name: :mongo,
  url: "mongodb://localhost:27018/wuzz_support_test",
  pool_size: 2

config :wuzz_support, WuzzSupportWeb.Endpoint,
  http: [ip: {127, 0, 0, 1}, port: 4002],
  secret_key_base: String.duplicate("test-only-secret", 8),
  server: false

config :wuzz_support, :auth,
  issuer: "wuzz-backend",
  public_keys: ["jteU+0uYZ/0/Vr9evQRJ02WEHKwhkILiyIlcvZVE2+U="]

config :wuzz_support, :cors_origins, ["http://localhost:5174"]
config :logger, level: :warning
