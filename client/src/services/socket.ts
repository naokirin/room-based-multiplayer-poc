import { type Channel, Socket } from "phoenix";
import { v4 as uuidv4 } from "uuid";

/** Phoenix チャネル用プロトコルバージョン（game-server の user_socket と揃えること）。 */
const SOCKET_PROTOCOL_VERSION = "1.0";

type DisconnectCallback = () => void;

class SocketManager {
	private socket: Socket | null = null;
	private channel: Channel | null = null;
	private roomId: string | null = null;
	private disconnectCallback: DisconnectCallback | null = null;
	private connectPromise: Promise<void> | null = null;

	/**
	 * Connect to the WebSocket. Returns a promise that resolves when the
	 * connection is open, or rejects on error/close before open.
	 */
	connect(wsUrl: string, token: string): Promise<void> {
		if (this.socket) {
			this.disconnect();
		}

		this.socket = new Socket(wsUrl, {
			params: {
				token,
				protocol_version: SOCKET_PROTOCOL_VERSION,
			},
		});

		this.connectPromise = new Promise((resolve, reject) => {
			let settled = false;
			const cleanup = (refs: string[]) => {
				if (this.socket) this.socket.off(refs);
			};

			const openRef = this.socket.onOpen(() => {
				if (settled) return;
				settled = true;
				cleanup([openRef, errorRef, closeRef]);
				console.log("WebSocket connected");
				// Re-register persistent callbacks for disconnect after connection is open
				this.socket?.onError((error: unknown) => {
					console.error("WebSocket error:", error);
					if (this.disconnectCallback) this.disconnectCallback();
				});
				this.socket?.onClose(() => {
					console.log("WebSocket closed");
					if (this.disconnectCallback) this.disconnectCallback();
				});
				resolve();
			});

			const errorRef = this.socket.onError((error: unknown) => {
				if (settled) return;
				settled = true;
				cleanup([openRef, errorRef, closeRef]);
				console.error("WebSocket error:", error);
				if (this.disconnectCallback) {
					this.disconnectCallback();
				}
				reject(new Error("WebSocket connection failed"));
			});

			const closeRef = this.socket.onClose(() => {
				if (settled) return;
				settled = true;
				cleanup([openRef, errorRef, closeRef]);
				console.log("WebSocket closed");
				if (this.disconnectCallback) {
					this.disconnectCallback();
				}
				reject(new Error("WebSocket closed before connection opened"));
			});
		});

		this.socket.connect();
		return this.connectPromise;
	}

	setDisconnectCallback(callback: DisconnectCallback): void {
		this.disconnectCallback = callback;
	}

	getRoomId(): string | null {
		return this.roomId;
	}

	isConnected(): boolean {
		return this.socket !== null && this.channel !== null;
	}

	/**
	 * Create a channel for the given room without joining yet.
	 * Register event listeners via onEvent() before calling joinChannel().
	 */
	createChannel(
		roomId: string,
		params: {
			room_token?: string;
			reconnect_token?: string;
			display_name?: string;
		},
	): void {
		if (!this.socket) {
			throw new Error("Socket not connected");
		}

		this.roomId = roomId;
		const channelName = `room:${roomId}`;
		this.channel = this.socket.channel(channelName, params);
	}

	/**
	 * Join the previously created channel. Must call createChannel() first.
	 */
	joinChannel(): Promise<Record<string, unknown>> {
		const channel = this.channel;
		if (!channel) {
			throw new Error("Channel not created. Call createChannel() first.");
		}

		return new Promise((resolve, reject) => {
			channel
				.join()
				.receive("ok", (response) => {
					console.log("Joined room successfully", response);
					resolve(response as Record<string, unknown>);
				})
				.receive("error", (response) => {
					console.error("Failed to join room", response);
					const reason =
						(response as { reason?: string }).reason ?? "Failed to join room";
					reject(new Error(reason));
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

		this.channel
			.push("game:action", payload)
			.receive("error", (response: unknown) => {
				console.error("game:action error:", response);
			});
	}

	pushChat(content: string): Promise<{ message_id: string; sent: boolean }> {
		const channel = this.channel;
		if (!channel) {
			throw new Error("Not connected to room");
		}

		return new Promise((resolve, reject) => {
			channel
				.push("chat:send", { content })
				.receive("ok", (response) => {
					resolve(response as { message_id: string; sent: boolean });
				})
				.receive("error", (response) => {
					reject(
						new Error(
							(response as { reason?: string }).reason ||
								"Failed to send chat message",
						),
					);
				})
				.receive("timeout", () => {
					reject(new Error("Chat send timeout"));
				});
		});
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

	/**
	 * Notify server of voluntary leave, then disconnect. Runs callback after disconnect
	 * (or immediately if not in a channel). Use this when the user clicks "Leave Game".
	 */
	leaveRoom(callback?: () => void): void {
		if (!this.channel) {
			this.disconnect();
			callback?.();
			return;
		}

		const done = () => {
			this.disconnect();
			callback?.();
		};

		this.channel
			.push("room:leave", {})
			.receive("ok", done)
			.receive("error", done)
			.receive("timeout", done);
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
