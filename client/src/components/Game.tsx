import { useEffect, useRef, useState } from "react";
import { GameRenderer } from "../game/GameRenderer";
import { useAuthStore } from "../stores/authStore";
import { useChatStore } from "../stores/chatStore";
import { useGameStore } from "../stores/gameStore";
import { Chat } from "./Chat";

/** 勝敗ダイアログを出すまでの待ち時間（最後に出したカードを表示する時間） */
const RESULT_DIALOG_DELAY_MS = 2500;

export function Game() {
	const canvasRef = useRef<HTMLDivElement>(null);
	const rendererRef = useRef<GameRenderer | null>(null);

	const {
		gameState,
		myHand,
		lastPlayedCard,
		isMyTurn,
		status,
		turnTimeRemaining,
		gameResult,
		isDisconnected,
		isReconnecting,
		playCard,
		leaveRoom,
		reconnectToRoom,
	} = useGameStore();

	const { user } = useAuthStore();
	const { initialize: initializeChat } = useChatStore();

	const [showResult, setShowResult] = useState(false);

	// Initialize chat store
	useEffect(() => {
		initializeChat();
	}, [initializeChat]);

	// Initialize PixiJS renderer
	useEffect(() => {
		if (!canvasRef.current || rendererRef.current) {
			return;
		}

		const renderer = new GameRenderer(canvasRef.current, {
			width: 800,
			height: 600,
		});

		renderer.onCardClick((cardId) => {
			// For MVP, auto-target opponent for damage cards
			// In full implementation, show target selection UI
			const card = myHand.find((c) => c.id === cardId);
			if (card?.effect === "deal_damage" && gameState) {
				const myUserId = user?.id;
				const opponentId = Object.keys(gameState.players).find(
					(id) => id !== myUserId,
				);
				playCard(cardId, opponentId);
			} else {
				playCard(cardId);
			}
		});

		rendererRef.current = renderer;

		return () => {
			renderer.destroy();
			rendererRef.current = null;
		};
	}, []);

	// Update renderer when game state changes (guard: user may be null briefly)
	useEffect(() => {
		if (!rendererRef.current) return;
		const myUserId = user?.id ?? "";
		rendererRef.current.updateState(
			gameState,
			myHand,
			isMyTurn,
			myUserId,
			lastPlayedCard ?? undefined,
		);
	}, [gameState, myHand, isMyTurn, user, lastPlayedCard]);

	// 勝敗がついたら最後のカードを表示してからダイアログを表示
	useEffect(() => {
		if (status !== "finished" && status !== "aborted") return;
		const timerId = window.setTimeout(() => {
			setShowResult(true);
		}, RESULT_DIALOG_DELAY_MS);
		return () => clearTimeout(timerId);
	}, [status]);

	const handleLeaveGame = () => {
		leaveRoom();
	};

	const handleCloseResult = () => {
		setShowResult(false);
		leaveRoom();
	};

	return (
		<div
			style={{
				display: "flex",
				flexDirection: "column",
				alignItems: "center",
				padding: "20px",
				minHeight: "100vh",
				backgroundColor: "#0f0f23",
			}}
		>
			{/* Header */}
			<div
				style={{
					width: "800px",
					display: "flex",
					justifyContent: "space-between",
					alignItems: "center",
					marginBottom: "10px",
				}}
			>
				<div style={{ color: "#fff" }}>
					{status === "waiting" && <h3>Waiting for players...</h3>}
					{status === "playing" && (
						<div>
							<span style={{ fontSize: "18px", fontWeight: "bold" }}>
								{isMyTurn ? "🟢 Your Turn" : "🟡 Opponent's Turn"}
							</span>
							<span
								style={{
									marginLeft: "15px",
									fontSize: "16px",
									color: "#aaa",
								}}
							>
								Time remaining: {turnTimeRemaining}s
							</span>
						</div>
					)}
				</div>
				<button
					type="button"
					onClick={handleLeaveGame}
					style={{
						padding: "8px 16px",
						backgroundColor: "#dc3545",
						color: "#fff",
						border: "none",
						borderRadius: "4px",
						cursor: "pointer",
					}}
				>
					Leave Game
				</button>
			</div>

			{/* PixiJS Canvas */}
			<div
				ref={canvasRef}
				style={{
					border: "2px solid #333",
					borderRadius: "8px",
					overflow: "hidden",
				}}
			/>

			{/* Chat */}
			<div
				style={{
					width: "800px",
					marginTop: "20px",
				}}
			>
				<Chat />
			</div>

			{/* Disconnection/Reconnection Overlay (T095) */}
			{(isDisconnected || isReconnecting) && (
				<div
					style={{
						position: "fixed",
						top: 0,
						left: 0,
						right: 0,
						bottom: 0,
						backgroundColor: "rgba(0, 0, 0, 0.7)",
						display: "flex",
						justifyContent: "center",
						alignItems: "center",
						zIndex: 999,
					}}
				>
					<div
						style={{
							backgroundColor: "#fff",
							padding: "30px",
							borderRadius: "12px",
							textAlign: "center",
							minWidth: "300px",
						}}
					>
						{isReconnecting && (
							<>
								<h3 style={{ margin: "0 0 15px 0" }}>Reconnecting...</h3>
								<p style={{ fontSize: "14px", color: "#666", margin: 0 }}>
									Please wait while we restore your connection.
								</p>
							</>
						)}

						{isDisconnected && !isReconnecting && (
							<>
								<h3 style={{ margin: "0 0 15px 0" }}>Connection Lost</h3>
								<p
									style={{
										fontSize: "14px",
										color: "#666",
										margin: "0 0 20px 0",
									}}
								>
									Attempting to reconnect...
								</p>
								<button
									type="button"
									onClick={() => reconnectToRoom()}
									style={{
										padding: "8px 20px",
										fontSize: "14px",
										backgroundColor: "#007bff",
										color: "#fff",
										border: "none",
										borderRadius: "4px",
										cursor: "pointer",
									}}
								>
									Retry Now
								</button>
							</>
						)}
					</div>
				</div>
			)}

			{/* Game Result Modal */}
			{showResult && gameResult && (
				<div
					style={{
						position: "fixed",
						top: 0,
						left: 0,
						right: 0,
						bottom: 0,
						backgroundColor: "rgba(0, 0, 0, 0.8)",
						display: "flex",
						justifyContent: "center",
						alignItems: "center",
						zIndex: 1000,
					}}
				>
					<div
						style={{
							backgroundColor: "#fff",
							padding: "40px",
							borderRadius: "12px",
							textAlign: "center",
							minWidth: "400px",
						}}
					>
						{status === "finished" && (
							<>
								<h2 style={{ margin: "0 0 20px 0" }}>
									{user && gameResult.winner_id === user.id
										? "🎉 You Win!"
										: "😔 You Lose"}
								</h2>
								<p
									style={{
										fontSize: "16px",
										color: "#666",
										margin: "0 0 30px 0",
									}}
								>
									{gameResult.reason}
								</p>
							</>
						)}

						{status === "aborted" && (
							<>
								<h2 style={{ margin: "0 0 20px 0" }}>⚠️ Game Aborted</h2>
								<p
									style={{
										fontSize: "16px",
										color: "#666",
										margin: "0 0 30px 0",
									}}
								>
									{gameResult.reason}
								</p>
							</>
						)}

						<button
							type="button"
							onClick={handleCloseResult}
							style={{
								padding: "12px 30px",
								fontSize: "16px",
								backgroundColor: "#007bff",
								color: "#fff",
								border: "none",
								borderRadius: "4px",
								cursor: "pointer",
							}}
						>
							Return to Lobby
						</button>
					</div>
				</div>
			)}
		</div>
	);
}
