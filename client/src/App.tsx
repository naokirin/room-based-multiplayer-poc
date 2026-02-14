import { useEffect, useState } from "react";
import { Auth } from "./components/Auth";
import { ErrorBoundary } from "./components/ErrorBoundary";
import { Game } from "./components/Game";
import { Lobby } from "./components/Lobby";
import { useAuthStore } from "./stores/authStore";
import { useGameStore } from "./stores/gameStore";
import { useLobbyStore } from "./stores/lobbyStore";

type Screen = "auth" | "lobby" | "game";

function App() {
	const [screen, setScreen] = useState<Screen>("auth");

	const {
		isAuthenticated,
		initializeFromStorage,
		serverUnreachable,
		retryConnection,
	} = useAuthStore();
	const { matchmakingStatus, currentMatch, clearMatch } = useLobbyStore();
	const { roomId, joinRoom } = useGameStore();
	const [retrying, setRetrying] = useState(false);

	// Initialize auth from localStorage on mount
	useEffect(() => {
		initializeFromStorage();
	}, [initializeFromStorage]);

	// Screen routing: game only when we have joined a room (roomId set)
	useEffect(() => {
		if (!isAuthenticated) {
			setScreen("auth");
			return;
		}
		if (roomId) {
			setScreen("game");
			return;
		}
		setScreen("lobby");
	}, [isAuthenticated, roomId]);

	// When matched, join room; only then will roomId be set and we navigate to game
	useEffect(() => {
		if (matchmakingStatus !== "matched" || !currentMatch) return;
		const { room_id, room_token, ws_url } = currentMatch;
		clearMatch();
		joinRoom(room_id, room_token, ws_url).catch((err: unknown) => {
			console.error("Failed to join room:", err);
		});
	}, [matchmakingStatus, currentMatch, joinRoom, clearMatch]);

	const handleRetryConnection = async () => {
		setRetrying(true);
		try {
			await retryConnection();
		} finally {
			setRetrying(false);
		}
	};

	return (
		<div
			style={{
				minHeight: "100vh",
				backgroundColor: screen === "game" ? "#0f0f23" : "#f5f5f5",
			}}
		>
			{serverUnreachable && (
				<div
					style={{
						padding: "12px 20px",
						backgroundColor: "#856404",
						color: "#fff",
						display: "flex",
						alignItems: "center",
						justifyContent: "space-between",
						flexWrap: "wrap",
						gap: "12px",
					}}
				>
					<span>
						Cannot connect to the server. Please ensure the API is running (e.g.{" "}
						<code style={{ background: "rgba(0,0,0,0.2)", padding: "2px 6px" }}>
							http://localhost:3001
						</code>
						).
					</span>
					<button
						type="button"
						aria-label="Retry connection to server"
						onClick={handleRetryConnection}
						disabled={retrying}
						style={{
							padding: "6px 14px",
							backgroundColor: "rgba(255,255,255,0.25)",
							color: "#fff",
							border: "1px solid rgba(255,255,255,0.5)",
							borderRadius: "var(--radius-button)",
							cursor: retrying ? "not-allowed" : "pointer",
						}}
					>
						{retrying ? "Retrying…" : "Retry"}
					</button>
				</div>
			)}
			{screen === "auth" && <Auth />}
			{screen === "lobby" && <Lobby />}
			{screen === "game" && (
				<ErrorBoundary returnToLobby>
					<Game />
				</ErrorBoundary>
			)}
		</div>
	);
}

export default App;
