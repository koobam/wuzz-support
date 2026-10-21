defmodule WuzzSupport.CallsTest do
  use ExUnit.Case, async: false

  alias WuzzSupport.Auth.Identity
  alias WuzzSupport.Calls

  @identity %Identity{id: "u42", roles: []}

  setup do
    previous = Application.get_env(:wuzz_support, :ice)
    on_exit(fn -> Application.put_env(:wuzz_support, :ice, previous) end)
    :ok
  end

  test "STUN only when no TURN secret is configured" do
    Application.put_env(:wuzz_support, :ice,
      stun_urls: ["stun:s.example:3478"],
      turn_urls: [],
      turn_secret: nil,
      ttl: 3600
    )

    assert Calls.ice_servers(@identity) == [%{urls: ["stun:s.example:3478"]}]
  end

  test "TURN credentials are coturn's ephemeral kind" do
    Application.put_env(:wuzz_support, :ice,
      stun_urls: ["stun:s.example:3478"],
      turn_urls: ["turn:t.example:3478"],
      turn_secret: "shh",
      ttl: 600
    )

    [stun, turn] = Calls.ice_servers(@identity, 1_000)
    assert stun == %{urls: ["stun:s.example:3478"]}
    assert turn.urls == ["turn:t.example:3478"]
    assert turn.username == "1600:u42"
    assert turn.credential == :crypto.mac(:hmac, :sha, "shh", "1600:u42") |> Base.encode64()
  end

  test "an empty TURN secret does not enable TURN" do
    Application.put_env(:wuzz_support, :ice,
      stun_urls: ["stun:s"],
      turn_urls: ["turn:t"],
      turn_secret: "",
      ttl: 600
    )

    assert [%{urls: ["stun:s"]}] = Calls.ice_servers(@identity)
  end

  test "valid_signal? accepts offers, answers and bounded candidates" do
    assert Calls.valid_signal?(%{"description" => %{"type" => "offer", "sdp" => "v=0"}})
    assert Calls.valid_signal?(%{"description" => %{"type" => "answer", "sdp" => "v=0"}})

    assert Calls.valid_signal?(%{
             "candidate" => %{"candidate" => "candidate:1 1 udp 1 1.2.3.4 5 typ host"}
           })
  end

  test "valid_signal? rejects oversized or malformed payloads" do
    refute Calls.valid_signal?(%{
             "description" => %{"type" => "offer", "sdp" => String.duplicate("a", 20_001)}
           })

    refute Calls.valid_signal?(%{"description" => %{"type" => "pranswer", "sdp" => "v=0"}})
    refute Calls.valid_signal?(%{"candidate" => %{"candidate" => String.duplicate("a", 2_001)}})

    refute Calls.valid_signal?(%{
             "candidate" => Map.new(1..7, &{"k#{&1}", "v"}) |> Map.put("candidate", "c")
           })

    refute Calls.valid_signal?(%{})
    refute Calls.valid_signal?("offer")
  end

  test "call ids are bounded strings" do
    assert Calls.valid_call_id?("abc")
    refute Calls.valid_call_id?("")
    refute Calls.valid_call_id?(String.duplicate("a", 65))
    refute Calls.valid_call_id?(123)
  end
end
