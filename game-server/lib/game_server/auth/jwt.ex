defmodule GameServer.Auth.JWT do
  @moduledoc """
  JWT verification for access tokens using shared secret (HS256).
  """

  use Joken.Config

  @impl true
  def token_config do
    default_claims(skip: [:aud, :iss])
  end

  def verify_token(token) do
    secret = secret_key()
    signer = Joken.Signer.create("HS256", secret)

    case Joken.verify(token, signer) do
      {:ok, claims} ->
        {:ok, claims}

      {:error, reason} ->
        {:error, reason}
    end
  end

  def decode_token(token) do
    secret = secret_key()
    signer = Joken.Signer.create("HS256", secret)

    case Joken.verify_and_validate(token_config(), token, signer) do
      {:ok, claims} ->
        {:ok, claims}

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp secret_key do
    System.get_env("JWT_SECRET") ||
      raise "JWT_SECRET environment variable is required"
  end
end
