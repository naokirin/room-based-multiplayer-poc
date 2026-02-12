defmodule GameServer.Auth.JWTTest do
  use ExUnit.Case, async: true

  alias GameServer.Auth.JWT

  @jwt_secret "test-jwt-secret"

  setup do
    System.put_env("JWT_SECRET", @jwt_secret)
    on_exit(fn -> System.put_env("JWT_SECRET", @jwt_secret) end)
    :ok
  end

  describe "verify_token/1" do
    test "verifies a valid HS256 token" do
      signer = Joken.Signer.create("HS256", @jwt_secret)
      claims = %{"user_id" => "abc-123", "exp" => Joken.current_time() + 3600, "iat" => Joken.current_time()}
      {:ok, token, _claims} = Joken.encode_and_sign(claims, signer)

      assert {:ok, decoded} = JWT.verify_token(token)
      assert decoded["user_id"] == "abc-123"
    end

    test "rejects a token signed with wrong secret" do
      wrong_signer = Joken.Signer.create("HS256", "wrong-secret")
      claims = %{"user_id" => "abc-123", "exp" => Joken.current_time() + 3600}
      {:ok, token, _claims} = Joken.encode_and_sign(claims, wrong_signer)

      assert {:error, _reason} = JWT.verify_token(token)
    end

    test "rejects a malformed token" do
      assert {:error, _reason} = JWT.verify_token("not.a.jwt")
    end
  end

  describe "decode_token/1" do
    test "decodes and validates a valid token" do
      signer = Joken.Signer.create("HS256", @jwt_secret)
      claims = %{"user_id" => "abc-123", "exp" => Joken.current_time() + 3600, "iat" => Joken.current_time()}
      {:ok, token, _claims} = Joken.encode_and_sign(claims, signer)

      assert {:ok, decoded} = JWT.decode_token(token)
      assert decoded["user_id"] == "abc-123"
    end

    test "rejects an expired token" do
      signer = Joken.Signer.create("HS256", @jwt_secret)
      claims = %{"user_id" => "abc-123", "exp" => Joken.current_time() - 10, "iat" => Joken.current_time() - 3610}
      {:ok, token, _claims} = Joken.encode_and_sign(claims, signer)

      assert {:error, _reason} = JWT.decode_token(token)
    end
  end
end
