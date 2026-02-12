import { Socket, Channel } from "phoenix";
import { v4 as uuidv4 } from "uuid";

class SocketManager {
  private socket: Socket | null = null;
  private channel: Channel | null = null;
  private roomId: string | null = null;

  connect(wsUrl: string, token: string): void {
    if (this.socket) {
      this.disconnect();
    }

    // Parse WebSocket URL and create Socket
    this.socket = new Socket(wsUrl, {
      params: {
        token,
        protocol_version: "1.0",
      },
    });

    this.socket.connect();

    // Listen for connection events
    this.socket.onOpen(() => {
      console.log("WebSocket connected");
    });

    this.socket.onError((error) => {
      console.error("WebSocket error:", error);
    });

    this.socket.onClose(() => {
      console.log("WebSocket closed");
    });
  }

  joinRoom(
    roomId: string,
    params: { room_token?: string; reconnect_token?: string }
  ): Promise<Channel> {
    if (!this.socket) {
      throw new Error("Socket not connected");
    }

    this.roomId = roomId;
    const channelName = `room:${roomId}`;

    this.channel = this.socket.channel(channelName, params);

    return new Promise((resolve, reject) => {
      if (!this.channel) {
        reject(new Error("Channel creation failed"));
        return;
      }

      this.channel
        .join()
        .receive("ok", (response) => {
          console.log("Joined room successfully", response);
          resolve(this.channel!);
        })
        .receive("error", (response) => {
          console.error("Failed to join room", response);
          reject(new Error(response.reason || "Failed to join room"));
        })
        .receive("timeout", () => {
          console.error("Room join timeout");
          reject(new Error("Room join timeout"));
        });
    });
  }

  pushAction(action: string, cardId: string, target?: string): void {
    if (!this.channel) {
      throw new Error("Not connected to room");
    }

    const nonce = uuidv4();
    const payload: {
      nonce: string;
      action: string;
      card_id: string;
      target_user_id?: string;
    } = {
      nonce,
      action,
      card_id: cardId,
    };

    if (target) {
      payload.target_user_id = target;
    }

    this.channel.push("game:action", payload);
  }

  pushChat(content: string): void {
    if (!this.channel) {
      throw new Error("Not connected to room");
    }

    this.channel.push("chat:send", { content });
  }

  onEvent(event: string, callback: (payload: unknown) => void): void {
    if (!this.channel) {
      throw new Error("Not connected to room");
    }

    this.channel.on(event, callback);
  }

  offEvent(event: string): void {
    if (!this.channel) {
      return;
    }

    this.channel.off(event);
  }

  getChannel(): Channel | null {
    return this.channel;
  }

  disconnect(): void {
    if (this.channel) {
      this.channel.leave();
      this.channel = null;
    }

    if (this.socket) {
      this.socket.disconnect();
      this.socket = null;
    }

    this.roomId = null;
  }
}

export const socketManager = new SocketManager();
