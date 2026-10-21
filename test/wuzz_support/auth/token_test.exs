defmodule WuzzSupport.Auth.TokenTest do
  use ExUnit.Case, async: false

  alias WuzzSupport.Auth.{Identity, Token}

  @issuer "wuzz-backend"

  setup do
    {_, public_raw} = key = keypair()
    previous = Application.get_env(:wuzz_support, :auth)

    Application.put_env(:wuzz_support, :auth,
      issuer: @issuer,
      public_keys: [Base.encode64(public_raw)]
    )

    on_exit(fn -> restore(:auth, previous) end)
    {:ok, key: key}
  end

  test "accepts a valid token and reads the identity", %{key: key} do
    token =
      sign(key, %{
        "sub" => "u1",
        "name" => "Ana",
        "roles" => ["admin"],
        "iss" => @issuer,
        "exp" => in_seconds(60)
      })

    assert {:ok, %Identity{id: "u1", name: "Ana", roles: ["admin"]}} = Token.verify(token)
  end

  test "a missing roles claim means no roles", %{key: key} do
    token = sign(key, %{"sub" => "u1", "iss" => @issuer, "exp" => in_seconds(60)})
    assert {:ok, %Identity{roles: []}} = Token.verify(token)
  end

  test "rejects an expired token", %{key: key} do
    token = sign(key, %{"sub" => "u1", "iss" => @issuer, "exp" => in_seconds(-5)})
    assert Token.verify(token) == :error
  end

  test "rejects a token from another issuer", %{key: key} do
    token = sign(key, %{"sub" => "u1", "iss" => "someone-else", "exp" => in_seconds(60)})
    assert Token.verify(token) == :error
  end

  test "rejects a token without a subject", %{key: key} do
    token = sign(key, %{"iss" => @issuer, "exp" => in_seconds(60)})
    assert Token.verify(token) == :error
  end

  test "rejects a token signed with a different key" do
    token = sign(keypair(), %{"sub" => "u1", "iss" => @issuer, "exp" => in_seconds(60)})
    assert Token.verify(token) == :error
  end

  test "rejects garbage and non-strings" do
    assert Token.verify("not.a.jwt") == :error
    assert Token.verify("") == :error
    assert Token.verify(nil) == :error
  end

  test "accepts a token signed by any of several configured keys", %{key: key} do
    {_, other_public} = keypair()
    {_, public_raw} = key

    Application.put_env(:wuzz_support, :auth,
      issuer: @issuer,
      public_keys: [Base.encode64(other_public), Base.encode64(public_raw)]
    )

    token = sign(key, %{"sub" => "u1", "iss" => @issuer, "exp" => in_seconds(60)})
    assert {:ok, %Identity{id: "u1"}} = Token.verify(token)
  end

  test "ignores a configured key that is not 32 bytes", %{key: key} do
    {_, public_raw} = key

    Application.put_env(:wuzz_support, :auth,
      issuer: @issuer,
      public_keys: [Base.encode64("short"), Base.encode64(public_raw)]
    )

    token = sign(key, %{"sub" => "u1", "iss" => @issuer, "exp" => in_seconds(60)})
    assert {:ok, _} = Token.verify(token)
  end

  # A fresh Ed25519 key: the JWK to sign with and the raw 32-byte public key the
  # service is configured with.
  defp keypair do
    jwk = JOSE.JWK.generate_key({:okp, :Ed25519})
    {_, {:Ed25519, public_raw}} = jwk |> JOSE.JWK.to_public() |> JOSE.JWK.to_okp()
    {jwk, public_raw}
  end

  defp sign({jwk, _public}, claims) do
    {_, token} = JOSE.JWT.sign(jwk, %{"alg" => "EdDSA"}, claims) |> JOSE.JWS.compact()
    token
  end

  defp in_seconds(n), do: System.system_time(:second) + n

  defp restore(key, nil), do: Application.delete_env(:wuzz_support, key)
  defp restore(key, value), do: Application.put_env(:wuzz_support, key, value)
end
