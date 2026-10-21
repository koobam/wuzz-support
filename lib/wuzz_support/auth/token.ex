defmodule WuzzSupport.Auth.Token do
  @moduledoc """
  Verifies EdDSA access tokens locally against the configured public keys —
  the same model as wuzz-backend's authn.Verifier: this service can check
  tokens but never mint one.
  """
  alias WuzzSupport.Auth.Identity

  @spec verify(String.t()) :: {:ok, Identity.t()} | :error
  def verify(token) when is_binary(token) do
    cfg = Application.fetch_env!(:wuzz_support, :auth)

    Enum.find_value(cfg[:public_keys], :error, fn b64 ->
      with {:ok, raw} <- Base.decode64(String.trim(b64)),
           32 <- byte_size(raw),
           jwk = JOSE.JWK.from_okp({:Ed25519, raw}),
           {true, %JOSE.JWT{fields: claims}, _jws} <-
             JOSE.JWT.verify_strict(jwk, ["EdDSA"], token),
           :ok <- check_claims(claims, cfg[:issuer]) do
        {:ok,
         %Identity{
           id: claims["sub"],
           name: claims["name"],
           roles: List.wrap(claims["roles"])
         }}
      else
        _ -> nil
      end
    end)
  rescue
    _ -> :error
  end

  def verify(_), do: :error

  defp check_claims(%{"iss" => iss, "exp" => exp, "sub" => sub}, issuer)
       when is_binary(sub) and sub != "" and is_number(exp) do
    if iss == issuer and exp > System.system_time(:second), do: :ok, else: :error
  end

  defp check_claims(_, _), do: :error
end
