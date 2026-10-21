defmodule WuzzSupport.Calls do
  @moduledoc """
  WebRTC call plumbing. Media is peer-to-peer; this service only relays
  signalling (see `ConversationChannel`) and hands out ICE servers.

  TURN credentials are the ephemeral kind coturn's `use-auth-secret` mode
  expects: username `"<expiry>:<user id>"`, credential `base64(hmac_sha1(secret, username))`.
  Nothing long-lived ever reaches a client.
  """
  alias WuzzSupport.Auth.Identity

  @max_sdp_bytes 20_000
  @max_candidate_bytes 2_000

  @doc "ICE servers for `identity`: STUN always, TURN when a shared secret is configured."
  def ice_servers(%Identity{} = identity, now \\ System.os_time(:second)) do
    cfg = Application.get_env(:wuzz_support, :ice, [])
    stun = %{urls: List.wrap(cfg[:stun_urls])}

    case {cfg[:turn_urls], cfg[:turn_secret]} do
      {urls, secret} when is_list(urls) and urls != [] and is_binary(secret) and secret != "" ->
        username = "#{now + (cfg[:ttl] || 3600)}:#{identity.id}"
        credential = :crypto.mac(:hmac, :sha, secret, username) |> Base.encode64()
        [stun, %{urls: urls, username: username, credential: credential}]

      _ ->
        [stun]
    end
  end

  @doc "Validates a `call:signal` payload: a session description or an ICE candidate, bounded in size."
  def valid_signal?(%{"description" => %{"type" => type, "sdp" => sdp}})
      when type in ["offer", "answer"] and is_binary(sdp),
      do: byte_size(sdp) <= @max_sdp_bytes

  def valid_signal?(%{"candidate" => %{"candidate" => c} = cand}) when is_binary(c),
    do: byte_size(c) <= @max_candidate_bytes and map_size(cand) <= 6

  def valid_signal?(_), do: false

  def new_call_id, do: WuzzSupport.MongoIds.uuid()

  def valid_call_id?(id), do: is_binary(id) and byte_size(id) in 1..64
end
