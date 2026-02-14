import { beforeEach, describe, expect, it, vi } from "vitest";
import { socketManager } from "../services/socket";
import type { ChatMessage } from "../types";
import { useChatStore } from "./chatStore";

vi.mock("../services/socket", () => ({
	socketManager: {
		pushChat: vi.fn(),
		onEvent: vi.fn(),
	},
}));

function makeMessage(overrides: Partial<ChatMessage> = {}): ChatMessage {
	return {
		message_id: `msg-${Math.random().toString(36).slice(2)}`,
		sender_id: "user-1",
		sender_name: "Alice",
		content: "Hello",
		sent_at: new Date().toISOString(),
		...overrides,
	};
}

describe("chatStore", () => {
	beforeEach(() => {
		vi.clearAllMocks();
		useChatStore.getState().clearMessages();
		useChatStore.setState({ isInitialized: false });
	});

	describe("addMessage", () => {
		it("appends a new message", () => {
			const msg = makeMessage({ message_id: "m1", content: "Hi" });

			useChatStore.getState().addMessage(msg);

			expect(useChatStore.getState().messages).toHaveLength(1);
			expect(useChatStore.getState().messages[0]).toEqual(msg);
		});

		it("updates existing message when message_id duplicates", () => {
			const msg1 = makeMessage({ message_id: "m1", content: "First" });
			const msg2 = makeMessage({ message_id: "m1", content: "Updated" });

			useChatStore.getState().addMessage(msg1);
			useChatStore.getState().addMessage(msg2);

			expect(useChatStore.getState().messages).toHaveLength(1);
			expect(useChatStore.getState().messages[0].content).toBe("Updated");
		});

		it("keeps at most 100 messages", () => {
			for (let i = 0; i < 105; i++) {
				useChatStore
					.getState()
					.addMessage(
						makeMessage({ message_id: `m${i}`, content: `Msg ${i}` }),
					);
			}

			expect(useChatStore.getState().messages).toHaveLength(100);
			expect(useChatStore.getState().messages[0].message_id).toBe("m5");
		});
	});

	describe("clearMessages", () => {
		it("clears messages and error", () => {
			useChatStore.getState().addMessage(makeMessage());
			useChatStore.setState({ error: "Something failed" });

			useChatStore.getState().clearMessages();

			expect(useChatStore.getState().messages).toEqual([]);
			expect(useChatStore.getState().error).toBeNull();
		});
	});

	describe("sendMessage", () => {
		it("does nothing when content is empty or whitespace", async () => {
			await useChatStore.getState().sendMessage("");
			await useChatStore.getState().sendMessage("   ");

			expect(socketManager.pushChat).not.toHaveBeenCalled();
		});

		it("clears loading and does not set error on success", async () => {
			vi.mocked(socketManager.pushChat).mockResolvedValue({
				message_id: "m1",
				sent: true,
			});

			await useChatStore.getState().sendMessage("Hello");

			expect(socketManager.pushChat).toHaveBeenCalledWith("Hello");
			expect(useChatStore.getState().isLoading).toBe(false);
			expect(useChatStore.getState().error).toBeNull();
		});

		it("sets error and rethrows on failure", async () => {
			vi.mocked(socketManager.pushChat).mockRejectedValue(
				new Error("Send failed"),
			);

			await expect(useChatStore.getState().sendMessage("Hi")).rejects.toThrow(
				"Send failed",
			);

			expect(useChatStore.getState().error).toContain("Send failed");
			expect(useChatStore.getState().isLoading).toBe(false);
		});

		it("sets error when server returns sent: false", async () => {
			vi.mocked(socketManager.pushChat).mockResolvedValue({
				message_id: "m1",
				sent: false,
			});

			await expect(useChatStore.getState().sendMessage("Hi")).rejects.toThrow(
				"Failed to send message",
			);

			expect(useChatStore.getState().error).toBeTruthy();
		});
	});

	describe("initialize", () => {
		it("registers chat:new_message listener and sets isInitialized", () => {
			expect(useChatStore.getState().isInitialized).toBe(false);

			useChatStore.getState().initialize();

			expect(socketManager.onEvent).toHaveBeenCalledWith(
				"chat:new_message",
				expect.any(Function),
			);
			expect(useChatStore.getState().isInitialized).toBe(true);
		});

		it("does not register twice when already initialized", () => {
			useChatStore.getState().initialize();
			vi.mocked(socketManager.onEvent).mockClear();
			useChatStore.getState().initialize();

			expect(socketManager.onEvent).not.toHaveBeenCalled();
		});

		it("invoking registered callback adds message to store", () => {
			let callback: (payload: ChatMessage) => void = () => {};
			vi.mocked(socketManager.onEvent).mockImplementation(
				(_event: string, fn: (payload: ChatMessage) => void) => {
					callback = fn;
				},
			);

			useChatStore.getState().initialize();

			const msg = makeMessage({ message_id: "m1", content: "From socket" });
			callback(msg);

			expect(useChatStore.getState().messages).toHaveLength(1);
			expect(useChatStore.getState().messages[0].content).toBe("From socket");
		});
	});
});
