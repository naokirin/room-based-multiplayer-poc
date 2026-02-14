defmodule GameServerWeb.RoomChannelTest do
  use GameServerWeb.ChannelCase, async: false

  alias GameServer.Redis
  alias GameServer.Rooms.RoomSupervisor
  alias GameServerWeb.RoomChannel

  @room_id "test-room-#{System.unique_integer([:positive])}"
  @user1_id "user-1"
  @user2_id "user-2"

  setup do
    # Ensure JWT_SECRET is set for any test that might use connect/3 later
    previous = System.get_env("JWT_SECRET")
    System.put_env("JWT_SECRET", "test-secret")
    on_exit(fn ->
      if previous, do: System.put_env("JWT_SECRET", previous), else: System.delete_env("JWT_SECRET")
    end)

    on_exit(fn ->
      # Clean up room if it was started
      case Registry.lookup(GameServer.RoomRegistry, @room_id) do
        [{pid, _}] -> RoomSupervisor.stop_room(pid)
        [] -> :ok
      end
    end)

    :ok
  end

  describe "join/3" do
    test "returns error when neither room_token nor reconnect_token is provided" do
      socket = build_socket(@user1_id)
      assert {:error, %{reason: "missing_token"}} =
               subscribe_and_join(socket, RoomChannel, "room:#{@room_id}", %{})
    end

    test "returns error when room_token is invalid or not in Redis" do
      socket = build_socket(@user1_id)
      assert {:error, %{reason: reason}} =
               subscribe_and_join(socket, RoomChannel, "room:#{@room_id}", %{"room_token" => "invalid-token"})

      assert reason in ["invalid_token", "invalid_token_data", "token_mismatch", "redis_error"]
    end

    @tag :integration
    test "joins successfully with valid room_token when room exists and token in Redis", %{} do
      # Start a room
      room_opts = [
        room_id: @room_id,
        game_type: "simple_card_battle",
        player_ids: [@user1_id, @user2_id]
      ]

      assert {:ok, _pid} = RoomSupervisor.start_room(room_opts)

      # Set room_token in Redis (must match room_id and user_id)
      token_value = Jason.encode!(%{
        "room_id" => @room_id,
        "user_id" => @user1_id,
        "status" => "pending"
      })

      redis_key = "room_token:valid-token-#{@room_id}"
      assert {:ok, _} = Redis.command(["SETEX", redis_key, 300, token_value])

      socket = build_socket(@user1_id)

      assert {:ok, reply, _socket} =
               subscribe_and_join(socket, RoomChannel, "room:#{@room_id}", %{
                 "room_token" => "valid-token-#{@room_id}",
                 "display_name" => "Player1"
               })

      assert Map.has_key?(reply, :players)
      assert Map.has_key?(reply, :status)
      assert reply.status == :waiting
      assert Map.has_key?(reply, :reconnect_token)
    end
  end

  describe "handle_in game:action" do
    test "replies missing_nonce when nonce is not provided" do
      # Use a room that exists so we get past rate limit and into the nonce check
      room_id = "room-no-nonce-#{System.unique_integer([:positive])}"
      room_opts = [room_id: room_id, game_type: "simple_card_battle", player_ids: [@user1_id, @user2_id]]
      assert {:ok, _pid} = RoomSupervisor.start_room(room_opts)
      token_value = Jason.encode!(%{"room_id" => room_id, "user_id" => @user1_id, "status" => "pending"})
      redis_key = "room_token:no-nonce-#{room_id}"
      assert {:ok, _} = Redis.command(["SETEX", redis_key, 300, token_value])

      socket = build_socket(@user1_id)
      assert {:ok, _reply, socket} =
               subscribe_and_join(socket, RoomChannel, "room:#{room_id}", %{
                 "room_token" => "no-nonce-#{room_id}",
                 "display_name" => "P1"
               })

      ref = push(socket, "game:action", %{"action" => "play_card", "card_id" => "x"})
      assert_reply ref, :error, %{reason: "missing_nonce"}

      # Cleanup
      case Registry.lookup(GameServer.RoomRegistry, room_id) do
        [{pid, _}] -> RoomSupervisor.stop_room(pid)
        [] -> :ok
      end
    end
  end

  describe "handle_in room:leave" do
    @tag :integration
    test "replies ok when leaving after join", %{} do
      room_opts = [room_id: @room_id, game_type: "simple_card_battle", player_ids: [@user1_id, @user2_id]]
      assert {:ok, _pid} = RoomSupervisor.start_room(room_opts)
      token_value = Jason.encode!(%{"room_id" => @room_id, "user_id" => @user1_id, "status" => "pending"})
      redis_key = "room_token:leave-test-#{@room_id}"
      assert {:ok, _} = Redis.command(["SETEX", redis_key, 300, token_value])

      socket = build_socket(@user1_id)
      assert {:ok, _reply, socket} =
               subscribe_and_join(socket, RoomChannel, "room:#{@room_id}", %{
                 "room_token" => "leave-test-#{@room_id}",
                 "display_name" => "P1"
               })

      Process.unlink(socket.channel_pid)
      ref = leave(socket)
      assert_reply ref, :ok
    end
  end

end
