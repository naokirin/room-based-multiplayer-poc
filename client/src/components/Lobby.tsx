import { useEffect, useState } from "react";
import { useLobbyStore } from "../stores/lobbyStore";
import { useAuthStore } from "../stores/authStore";

export function Lobby() {
  const {
    gameTypes,
    matchmakingStatus,
    queuedAt,
    error,
    fetchGameTypes,
    joinQueue,
    cancelQueue,
  } = useLobbyStore();

  const { user, logout } = useAuthStore();

  const [elapsedSeconds, setElapsedSeconds] = useState(0);
  const TIMEOUT_SECONDS = 60;

  useEffect(() => {
    fetchGameTypes();
  }, [fetchGameTypes]);

  // Update elapsed time when queued and auto-cancel on timeout
  useEffect(() => {
    if (matchmakingStatus === "queued" && queuedAt) {
      const startTime = new Date(queuedAt).getTime();
      const interval = setInterval(() => {
        const elapsed = Math.floor((Date.now() - startTime) / 1000);
        setElapsedSeconds(elapsed);

        // Auto-cancel when timeout is reached
        if (elapsed >= TIMEOUT_SECONDS) {
          clearInterval(interval);
          cancelQueue();
        }
      }, 1000);

      return () => clearInterval(interval);
    }
    setElapsedSeconds(0);
  }, [matchmakingStatus, queuedAt, cancelQueue]);

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
          onClick={handleLogout}
          style={{
            padding: "8px 16px",
            backgroundColor: "#dc3545",
            color: "#fff",
            border: "none",
            borderRadius: "4px",
            cursor: "pointer",
          }}
        >
          Logout
        </button>
      </div>

      {/* Matchmaking Status */}
      {matchmakingStatus === "queued" && (
        <div
          style={{
            padding: "20px",
            marginBottom: "20px",
            backgroundColor: "#fff3cd",
            border: "1px solid #ffc107",
            borderRadius: "8px",
            textAlign: "center",
          }}
        >
          <h3 style={{ margin: "0 0 10px 0" }}>Searching for match...</h3>
          <p style={{ margin: "0 0 5px 0", fontSize: "14px", color: "#666" }}>
            Elapsed time: {elapsedSeconds}s
          </p>
          <p style={{ margin: "0 0 15px 0", fontSize: "12px", color: "#856404" }}>
            Timeout in: {TIMEOUT_SECONDS - elapsedSeconds}s
          </p>
          <button
            type="button"
            onClick={handleCancel}
            style={{
              padding: "8px 20px",
              backgroundColor: "#6c757d",
              color: "#fff",
              border: "none",
              borderRadius: "4px",
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
            backgroundColor: "#d4edda",
            border: "1px solid #28a745",
            borderRadius: "8px",
            textAlign: "center",
          }}
        >
          <h3 style={{ margin: 0, color: "#155724" }}>Match found!</h3>
          <p style={{ margin: "5px 0 0 0", fontSize: "14px", color: "#155724" }}>
            Connecting to game...
          </p>
        </div>
      )}

      {matchmakingStatus === "timeout" && (
        <div
          style={{
            padding: "20px",
            marginBottom: "20px",
            backgroundColor: "#f8d7da",
            border: "1px solid #dc3545",
            borderRadius: "8px",
            textAlign: "center",
          }}
        >
          <h3 style={{ margin: 0, color: "#721c24" }}>Matchmaking timeout</h3>
          <p style={{ margin: "5px 0 0 0", fontSize: "14px", color: "#721c24" }}>
            No match found. Please try again.
          </p>
        </div>
      )}

      {error && (
        <div
          style={{
            padding: "15px",
            marginBottom: "20px",
            backgroundColor: "#f8d7da",
            color: "#721c24",
            border: "1px solid #dc3545",
            borderRadius: "4px",
          }}
        >
          {error}
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
                      {gameType.player_count} players • {gameType.turn_time_limit}s
                      per turn
                    </p>
                  </div>
                  <button
                    type="button"
                    onClick={() => handlePlay(gameType.id)}
                    style={{
                      padding: "10px 24px",
                      backgroundColor: "#28a745",
                      color: "#fff",
                      border: "none",
                      borderRadius: "4px",
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
