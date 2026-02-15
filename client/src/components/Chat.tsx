import type React from "react";
import { useEffect, useRef, useState } from "react";
import { MAX_CHAT_INPUT_LENGTH } from "../constants";
import { useAuthStore } from "../stores/authStore";
import { useChatStore } from "../stores/chatStore";

export const Chat: React.FC = () => {
	const [input, setInput] = useState("");
	const messagesEndRef = useRef<HTMLDivElement>(null);

	const { messages, isLoading, error, sendMessage } = useChatStore();
	const currentUser = useAuthStore((state) => state.user);

	// Auto-scroll to bottom when new messages arrive (intentionally depend on messages)
	// biome-ignore lint/correctness/useExhaustiveDependencies: scroll when message list changes
	useEffect(() => {
		messagesEndRef.current?.scrollIntoView({ behavior: "smooth" });
	}, [messages]);

	const handleSubmit = async (e: React.FormEvent) => {
		e.preventDefault();

		if (!input.trim() || isLoading) {
			return;
		}

		try {
			await sendMessage(input.trim());
			setInput("");
		} catch (err) {
			console.error("Failed to send message:", err);
		}
	};

	const formatTime = (isoString: string) => {
		const date = new Date(isoString);
		return date.toLocaleTimeString("ja-JP", {
			hour: "2-digit",
			minute: "2-digit",
		});
	};

	return (
		<div className="chat-container">
			<div className="chat-header">
				<h3>Chat</h3>
			</div>

			<div className="chat-messages">
				{messages.length === 0 ? (
					<div className="chat-empty">メッセージはまだありません</div>
				) : (
					messages.map((msg) => (
						<div
							key={msg.message_id}
							className={`chat-message ${
								msg.sender_id === currentUser?.id ? "own-message" : ""
							}`}
						>
							<div className="message-header">
								<span className="message-sender">{msg.sender_name}</span>
								<span className="message-time">{formatTime(msg.sent_at)}</span>
							</div>
							<div className="message-content">{msg.content}</div>
						</div>
					))
				)}
				<div ref={messagesEndRef} />
			</div>

			{error && <div className="chat-error">{error}</div>}

			<form onSubmit={handleSubmit} className="chat-input-form">
				<input
					type="text"
					value={input}
					onChange={(e) => setInput(e.target.value)}
					placeholder="メッセージを入力..."
					maxLength={MAX_CHAT_INPUT_LENGTH}
					disabled={isLoading}
					className="chat-input"
				/>
				<button
					type="submit"
					disabled={isLoading || !input.trim()}
					className="chat-send-button"
				>
					送信
				</button>
			</form>

			<style>{`
        .chat-container {
          display: flex;
          flex-direction: column;
          height: 400px;
          width: 100%;
          border: 1px solid #ccc;
          border-radius: 8px;
          background: white;
        }

        .chat-header {
          padding: 12px 16px;
          border-bottom: 1px solid #e0e0e0;
          background: #f5f5f5;
          border-radius: 8px 8px 0 0;
        }

        .chat-header h3 {
          margin: 0;
          font-size: 16px;
          font-weight: 600;
        }

        .chat-messages {
          flex: 1;
          overflow-y: auto;
          padding: 16px;
          display: flex;
          flex-direction: column;
          gap: 12px;
        }

        .chat-empty {
          text-align: center;
          color: #999;
          padding: 32px 16px;
        }

        .chat-message {
          display: flex;
          flex-direction: column;
          gap: 4px;
          padding: 8px 12px;
          border-radius: 8px;
          background: #f0f0f0;
          max-width: 80%;
        }

        .chat-message.own-message {
          align-self: flex-end;
          background: #e3f2fd;
        }

        .message-header {
          display: flex;
          justify-content: space-between;
          align-items: center;
          gap: 8px;
        }

        .message-sender {
          font-weight: 600;
          font-size: 12px;
          color: #333;
        }

        .message-time {
          font-size: 11px;
          color: #666;
        }

        .message-content {
          font-size: 14px;
          color: #333;
          word-wrap: break-word;
        }

        .chat-error {
          padding: 8px 16px;
          background: #ffebee;
          color: #c62828;
          font-size: 12px;
          border-top: 1px solid #e0e0e0;
        }

        .chat-input-form {
          display: flex;
          gap: 8px;
          padding: 12px 16px;
          border-top: 1px solid #e0e0e0;
          background: #fafafa;
          border-radius: 0 0 8px 8px;
        }

        .chat-input {
          flex: 1;
          padding: 8px 12px;
          border: 1px solid #ccc;
          border-radius: 4px;
          font-size: 14px;
        }

        .chat-input:disabled {
          background: #f5f5f5;
          cursor: not-allowed;
        }

        .chat-send-button {
          padding: 8px 16px;
          background: #2196f3;
          color: white;
          border: none;
          border-radius: 4px;
          font-size: 14px;
          font-weight: 500;
          cursor: pointer;
          transition: background 0.2s;
        }

        .chat-send-button:hover:not(:disabled) {
          background: #1976d2;
        }

        .chat-send-button:disabled {
          background: #ccc;
          cursor: not-allowed;
        }
      `}</style>
		</div>
	);
};
