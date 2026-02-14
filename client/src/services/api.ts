import type {
	Announcement,
	AuthResponse,
	GameType,
	MatchmakingMatchedResponse,
	MatchmakingQueuedResponse,
	MatchmakingStatusResponse,
	RefreshResponse,
	User,
} from "../types";

const API_BASE_URL =
	import.meta.env.VITE_API_URL || "http://localhost:3001/api/v1";

class ApiClient {
	private accessToken: string | null = null;

	setToken(token: string | null) {
		this.accessToken = token;
	}

	getToken(): string | null {
		return this.accessToken;
	}

	/**
	 * Thrown when the request could not reach the server (e.g. connection refused/reset).
	 * Callers can check `err.isNetworkError` to show a "server unreachable" message
	 * instead of treating as auth failure.
	 */
	static isNetworkError(
		err: unknown,
	): err is { isNetworkError: true; message: string } {
		return (
			typeof err === "object" &&
			err !== null &&
			"isNetworkError" in err &&
			(err as { isNetworkError?: boolean }).isNetworkError === true
		);
	}

	private async request<T>(
		path: string,
		options: RequestInit = {},
	): Promise<T> {
		const headers: Record<string, string> = {
			"Content-Type": "application/json",
			...((options.headers as Record<string, string>) || {}),
		};

		if (this.accessToken) {
			headers.Authorization = `Bearer ${this.accessToken}`;
		}

		let response: Response;
		try {
			response = await fetch(`${API_BASE_URL}${path}`, {
				...options,
				headers,
			});
		} catch (e) {
			throw {
				isNetworkError: true,
				message: "Cannot reach server. Please check that the API is running.",
				cause: e,
			};
		}

		if (!response.ok) {
			const error = await response.json().catch(() => ({
				error: "unknown",
				message: response.statusText,
			}));
			throw { status: response.status, ...error };
		}

		return response.json();
	}

	// Auth
	async register(
		email: string,
		password: string,
		displayName: string,
	): Promise<AuthResponse> {
		return this.request<AuthResponse>("/auth/register", {
			method: "POST",
			body: JSON.stringify({
				user: { email, password, display_name: displayName },
			}),
		});
	}

	async login(email: string, password: string): Promise<AuthResponse> {
		return this.request<AuthResponse>("/auth/login", {
			method: "POST",
			body: JSON.stringify({ email, password }),
		});
	}

	async refresh(): Promise<RefreshResponse> {
		return this.request<RefreshResponse>("/auth/refresh", {
			method: "POST",
		});
	}

	async getProfile(): Promise<{ user: User }> {
		return this.request<{ user: User }>("/profile");
	}

	// Game types
	async getGameTypes(): Promise<{ game_types: GameType[] }> {
		return this.request<{ game_types: GameType[] }>("/game_types");
	}

	// Matchmaking
	async joinMatchmaking(
		gameTypeId: string,
	): Promise<MatchmakingQueuedResponse | MatchmakingMatchedResponse> {
		return this.request("/matchmaking/join", {
			method: "POST",
			body: JSON.stringify({ game_type_id: gameTypeId }),
		});
	}

	async getMatchmakingStatus(): Promise<MatchmakingStatusResponse> {
		return this.request<MatchmakingStatusResponse>("/matchmaking/status");
	}

	async cancelMatchmaking(): Promise<{ status: string }> {
		return this.request<{ status: string }>("/matchmaking/cancel", {
			method: "DELETE",
		});
	}

	// Rooms
	async getWsEndpoint(
		roomId: string,
	): Promise<{ ws_url: string; node_name: string; room_status: string }> {
		return this.request(`/rooms/${roomId}/ws_endpoint`);
	}

	// Announcements
	async getAnnouncements(): Promise<{ announcements: Announcement[] }> {
		return this.request<{ announcements: Announcement[] }>("/announcements");
	}
}

export const api = new ApiClient();
