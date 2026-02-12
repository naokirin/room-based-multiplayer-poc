import { useEffect, useState } from "react";
import { useAuthStore } from "./stores/authStore";
import { useGameStore } from "./stores/gameStore";
import { useLobbyStore } from "./stores/lobbyStore";
import { Auth } from "./components/Auth";
import { Lobby } from "./components/Lobby";
import { Game } from "./components/Game";

type Screen = "auth" | "lobby" | "game";

function App() {
  const [screen, setScreen] = useState<Screen>("auth");

  const { isAuthenticated, initializeFromStorage } = useAuthStore();
  const { matchmakingStatus, currentMatch, clearMatch } = useLobbyStore();
  const { status: gameStatus, joinRoom } = useGameStore();

  // Initialize auth from localStorage on mount
  useEffect(() => {
    initializeFromStorage();
  }, [initializeFromStorage]);

  // Screen routing logic
  useEffect(() => {
    if (!isAuthenticated) {
      setScreen("auth");
      return;
    }

    // If we have an active game or matched
    if (gameStatus !== "waiting" || matchmakingStatus === "matched") {
      setScreen("game");

      // Auto-join room when matched
      if (matchmakingStatus === "matched" && currentMatch) {
        joinRoom(
          currentMatch.room_id,
          currentMatch.room_token,
          currentMatch.ws_url
        );
        clearMatch();
      }
      return;
    }

    // Otherwise show lobby
    setScreen("lobby");
  }, [
    isAuthenticated,
    matchmakingStatus,
    currentMatch,
    gameStatus,
    joinRoom,
    clearMatch,
  ]);

  return (
    <div
      style={{
        minHeight: "100vh",
        backgroundColor: screen === "game" ? "#0f0f23" : "#f5f5f5",
      }}
    >
      {screen === "auth" && <Auth />}
      {screen === "lobby" && <Lobby />}
      {screen === "game" && <Game />}
    </div>
  );
}

export default App;
