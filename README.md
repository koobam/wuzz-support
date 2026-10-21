# wuzz-support

Realtime chat for Wuzz: customer ↔ support (admins) and customer ↔ outlet.
Elixir / Phoenix Channels, MongoDB. It verifies the Ed25519 access tokens minted by wuzz-backend's
`user` service and never issues its own.

## Roles (JWT `roles` claim)

| role            | can see                                   |
|-----------------|-------------------------------------------|
| _(none)_        | the customer's own conversations          |
| `outlet:<id>`   | outlet `<id>`'s conversations             |
| `admin`         | every conversation                        |

> wuzz-backend's user service does not issue `admin` / `outlet:<id>` roles yet.

## Run

```
cd ../wuzz-backend && make dev     # postgres :5433, mongo :27018, kafka, redis
mix setup
mix phx.server                     # :4000
```

Production env: `MONGODB_URI`, `SECRET_KEY_BASE`, `JWT_PUBLIC_KEYS`, `CORS_ORIGINS`, optional `JWT_ISSUER`, `PORT`.

## API

REST (`Authorization: Bearer <token>`): `GET/POST /api/conversations`,
`GET /api/conversations/:id/messages?before=<iso8601>`, `POST /api/conversations/:id/close`.

Socket: `wss://host/socket/websocket?token=<token>`
- `conversation:<id>` — push `message {body}`, `typing`; receive `message`, `typing`
- `inbox:admin`, `inbox:outlet:<id>` — receive `conversation_updated`

## Storage

Chat lives in MongoDB (`conversations`, `messages`); indexes are created at boot, including a partial-unique one so a customer has at most one open thread per counterpart. Env: `MONGODB_URI`.

## Calls (WebRTC)

Audio/video calls are peer to peer; this service relays signalling on the conversation channel and issues ICE servers.

- Channel events: `call:invite {video}` → `{call_id}`; `call:accept`, `call:reject`, `call:end` `{call_id}`; `call:signal {call_id, description | candidate}`. Peers receive `call:incoming`, `call:accepted`, `call:rejected`, `call:ended`, `call:signal`. Staff outside the thread get `incoming_call` on their inbox topic.
- `GET /api/ice-servers` returns STUN, plus TURN with short-lived HMAC credentials when `TURN_URLS` and `TURN_SECRET` are set (coturn `use-auth-secret`). Without TURN, peers behind symmetric NAT cannot connect.
