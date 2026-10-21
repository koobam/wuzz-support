import Config

# Host port 27018 (docker compose, wuzz-backend `make dev`). From a container use host.docker.internal.
config :wuzz_support, :mongo,
  name: :mongo,
  url: "mongodb://host.docker.internal:27018/wuzz_support",
  pool_size: 5

config :wuzz_support, WuzzSupportWeb.Endpoint,
  http: [ip: {0, 0, 0, 0}, port: 4000],
  check_origin: false,
  secret_key_base: String.duplicate("dev-only-secret", 8)

# Same fixed development Ed25519 public key as wuzz-backend's authn/keys.go
# (kid 5cde776e2b33f4f2), so a token from `user` verifies here unconfigured.
config :wuzz_support, :auth,
  issuer: "wuzz-backend",
  public_keys: ["jteU+0uYZ/0/Vr9evQRJ02WEHKwhkILiyIlcvZVE2+U="]

config :wuzz_support, :cors_origins, ["http://localhost:5174"]
