import { useEffect, useState } from "react";
import { api } from "../services/api";
import { useAuthStore } from "../stores/authStore";
import { useGameStore } from "../stores/gameStore";
import { useLobbyStore } from "../stores/lobbyStore";
import type { Announcement } from "../types";

export function Lobby() {
	const {
		gameTypes,
		matchmakingStatus,
		queuedAt,
		queuedTimeoutSeconds,
		error,
		fetchGameTypes,
		joinQueue,
		cancelQueue,
	} = useLobbyStore();

	const { error: gameError } = useGameStore();

	const { user, logout } = useAuthStore();

	const [elapsedSeconds, setElapsedSeconds] = useState(0);
	const [announcements, setAnnouncements] = useState<Announcement[]>([]);
	/** Use API timeout when queued; fallback if server did not send it */
	const timeoutSeconds = queuedTimeoutSeconds ?? 60;

	useEffect(() => {
		fetchGameTypes();
		api
			.getAnnouncements()
			.then((res) => setAnnouncements(res.announcements))
			.catch((err) => console.error("Failed to fetch announcements:", err));
	}, [fetchGameTypes]);

	// Update elapsed time when queued and auto-cancel on timeout
	useEffect(() => {
		if (matchmakingStatus === "queued" && queuedAt) {
			const startTime = new Date(queuedAt).getTime();
			const interval = setInterval(() => {
				const elapsed = Math.floor((Date.now() - startTime) / 1000);
				setElapsedSeconds(elapsed);

				// Auto-cancel when timeout is reached
				if (elapsed >= timeoutSeconds) {
					clearInterval(interval);
					cancelQueue();
				}
			}, 1000);

			return () => clearInterval(interval);
		}
		setElapsedSeconds(0);
	}, [matchmakingStatus, queuedAt, timeoutSeconds, cancelQueue]);

	const handlePlay = (gameTypeId: string) => {
		joinQueue(gameTypeId);
	};

	const handleCancel = () => {
		cancelQueue();
	};

	const handleLogout = () => {
		logout();
	};

	return (
		<div
			style={{
				maxWidth: "800px",
				margin: "50px auto",
				padding: "30px",
			}}
		>
			{/* Header */}
			<div
				style={{
					display: "flex",
					justifyContent: "space-between",
					alignItems: "center",
					marginBottom: "30px",
					paddingBottom: "15px",
					borderBottom: "2px solid #eee",
				}}
			>
				<div>
					<h2 style={{ margin: 0 }}>Game Lobby</h2>
					<p style={{ margin: "5px 0 0 0", color: "#666" }}>
						Welcome, {user?.display_name}!
					</p>
				</div>
				<button
					type="button"
					aria-label="Log out"
					onClick={handleLogout}
					style={{
						padding: "var(--padding-button)",
						backgroundColor: "var(--color-danger)",
						color: "#fff",
						border: "none",
						borderRadius: "var(--radius-button)",
						cursor: "pointer",
					}}
				>
					Logout
				</button>
			</div>

			{/* Announcements */}
			{announcements.length > 0 && (
				<div style={{ marginBottom: "20px" }}>
					{announcements.map((announcement) => (
						<div
							key={announcement.id}
							style={{
								padding: "15px 20px",
								marginBottom: "10px",
								backgroundColor: "#e7f1ff",
								border: "1px solid #b6d4fe",
								borderRadius: "8px",
							}}
						>
							<h4 style={{ margin: "0 0 6px 0", color: "#084298" }}>
								{announcement.title}
							</h4>
							<p
								style={{ margin: "0 0 6px 0", fontSize: "14px", color: "#333" }}
							>
								{announcement.body}
							</p>
							<p style={{ margin: 0, fontSize: "12px", color: "#666" }}>
								{new Date(announcement.published_at).toLocaleDateString()}
							</p>
						</div>
					))}
				</div>
			)}

			{/* Matchmaking Status */}
			{matchmakingStatus === "queued" && (
				<div
					style={{
						padding: "20px",
						marginBottom: "20px",
						backgroundColor: "var(--color-warning-bg)",
						border: "1px solid var(--color-warning-border)",
						borderRadius: "var(--radius-card)",
						textAlign: "center",
					}}
				>
					<h3 style={{ margin: "0 0 10px 0" }}>Searching for match...</h3>
					<p style={{ margin: "0 0 5px 0", fontSize: "14px", color: "#666" }}>
						Elapsed time: {elapsedSeconds}s
					</p>
					<p
						style={{ margin: "0 0 15px 0", fontSize: "12px", color: "#856404" }}
					>
						Timeout in: {timeoutSeconds - elapsedSeconds}s
					</p>
					<button
						type="button"
						aria-label="Cancel matchmaking"
						onClick={handleCancel}
						style={{
							padding: "var(--padding-button)",
							backgroundColor: "var(--color-neutral)",
							color: "#fff",
							border: "none",
							borderRadius: "var(--radius-button)",
							cursor: "pointer",
						}}
					>
						Cancel
					</button>
				</div>
			)}

			{matchmakingStatus === "matched" && (
				<div
					style={{
						padding: "20px",
						marginBottom: "20px",
						backgroundColor: "var(--color-success-bg)",
						border: "1px solid var(--color-success)",
						borderRadius: "var(--radius-card)",
						textAlign: "center",
					}}
				>
					<h3 style={{ margin: 0, color: "var(--color-success-text)" }}>
						Match found!
					</h3>
					<p
						style={{
							margin: "5px 0 0 0",
							fontSize: "14px",
							color: "var(--color-success-text)",
						}}
					>
						Connecting to game...
					</p>
				</div>
			)}

			{matchmakingStatus === "timeout" && (
				<div
					style={{
						padding: "20px",
						marginBottom: "20px",
						backgroundColor: "var(--color-error-bg)",
						border: "1px solid var(--color-error-border)",
						borderRadius: "var(--radius-card)",
						textAlign: "center",
					}}
				>
					<h3 style={{ margin: 0, color: "#721c24" }}>Matchmaking timeout</h3>
					<p
						style={{ margin: "5px 0 0 0", fontSize: "14px", color: "#721c24" }}
					>
						No match found. Please try again.
					</p>
				</div>
			)}

			{(error || gameError) && (
				<div
					style={{
						padding: "15px",
						marginBottom: "20px",
						backgroundColor: "var(--color-error-bg)",
						color: "#721c24",
						border: "1px solid var(--color-error-border)",
						borderRadius: "var(--radius-button)",
					}}
				>
					{error || gameError}
				</div>
			)}

			{/* Game Types List */}
			{matchmakingStatus === "idle" && (
				<div>
					<h3 style={{ marginBottom: "15px" }}>Available Games</h3>
					{gameTypes.length === 0 ? (
						<p style={{ color: "#666" }}>Loading game types...</p>
					) : (
						<div style={{ display: "grid", gap: "15px" }}>
							{gameTypes.map((gameType) => (
								<div
									key={gameType.id}
									style={{
										padding: "20px",
										border: "1px solid #ddd",
										borderRadius: "8px",
										backgroundColor: "#fff",
										display: "flex",
										justifyContent: "space-between",
										alignItems: "center",
									}}
								>
									<div>
										<h4 style={{ margin: "0 0 5px 0" }}>{gameType.name}</h4>
										<p style={{ margin: 0, fontSize: "14px", color: "#666" }}>
											{gameType.player_count} players •{" "}
											{gameType.turn_time_limit}s per turn
										</p>
									</div>
									<button
										type="button"
										aria-label={`Play ${gameType.name}`}
										onClick={() => handlePlay(gameType.id)}
										style={{
											padding: "10px 24px",
											backgroundColor: "var(--color-success)",
											color: "#fff",
											border: "none",
											borderRadius: "var(--radius-button)",
											cursor: "pointer",
											fontSize: "16px",
											fontWeight: "bold",
										}}
									>
										Play
									</button>
								</div>
							))}
						</div>
					)}
				</div>
			)}
		</div>
	);
}
