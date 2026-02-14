import { create } from "zustand";
import { socketManager } from "../services/socket";
import type { ChatMessage } from "../types";
import { getErrorMessage } from "../utils/error";

interface ChatStoreState {
	messages: ChatMessage[];
	isLoading: boolean;
	error: string | null;
	isInitialized: boolean;
}

interface ChatStoreActions {
	sendMessage: (content: string) => Promise<void>;
	addMessage: (message: ChatMessage) => void;
	clearMessages: () => void;
	initialize: () => void;
}

type ChatStore = ChatStoreState & ChatStoreActions;

const MAX_MESSAGES = 100;

export const useChatStore = create<ChatStore>((set, get) => ({
	// State
	messages: [],
	isLoading: false,
	error: null,
	isInitialized: false,

	// Actions
	sendMessage: async (content: string) => {
		if (!content.trim()) {
			return;
		}

		set({ isLoading: true, error: null });

		try {
			const result = await socketManager.pushChat(content);

			if (!result.sent) {
				throw new Error("Failed to send message");
			}

			set({ isLoading: false });
		} catch (err: unknown) {
			set({
				isLoading: false,
				error: getErrorMessage(err, "Failed to send message"),
			});
			throw err;
		}
	},

	addMessage: (message: ChatMessage) => {
		const currentMessages = get().messages;
		const messageId = message.message_id;

		// Ignore or update duplicate messages with the same message_id
		const exists = currentMessages.some((m) => m.message_id === messageId);
		if (exists) {
			const updatedMessages = currentMessages.map((m) =>
				m.message_id === messageId ? message : m,
			);
			set({ messages: updatedMessages });
			return;
		}

		// Add new message and keep max 100 (immutable)
		const updatedMessages = [...currentMessages, message].slice(-MAX_MESSAGES);

		set({ messages: updatedMessages });
	},

	clearMessages: () => {
		set({ messages: [], error: null });
	},

	initialize: () => {
		// Avoid registering multiple listeners (e.g. React StrictMode double effect)
		if (get().isInitialized) {
			return;
		}

		// Set up chat message listener (server sends message_id per types/index.ts)
		socketManager.onEvent("chat:new_message", (payload) => {
			const message = payload as ChatMessage;
			get().addMessage(message);
		});

		set({ isInitialized: true });
	},
}));
