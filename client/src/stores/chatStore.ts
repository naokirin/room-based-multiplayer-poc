import { create } from "zustand";
import { socketManager } from "../services/socket";

interface ChatMessage {
	id: string;
	sender_id: string;
	sender_name: string;
	content: string;
	sent_at: string;
}

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
			const error = err as { message?: string };
			set({
				isLoading: false,
				error: error.message || "Failed to send message",
			});
			throw err;
		}
	},

	addMessage: (message: ChatMessage) => {
		const currentMessages = get().messages;

		// Ignore or update duplicate messages with the same id
		const exists = currentMessages.some((m) => m.id === message.id);
		if (exists) {
			const updatedMessages = currentMessages.map((m) =>
				m.id === message.id ? message : m,
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

		// Set up chat message listener
		socketManager.onEvent("chat:new_message", (payload) => {
			const message = payload as ChatMessage;
			get().addMessage(message);
		});

		set({ isInitialized: true });
	},
}));
