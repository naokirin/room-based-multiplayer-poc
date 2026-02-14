import {
	AnnouncementsResponseSchema,
	AuthResponseSchema,
	GameTypesResponseSchema,
	MatchmakingJoinResponseSchema,
	MatchmakingStatusResponseSchema,
	ProfileResponseSchema,
	RefreshResponseSchema,
	WsEndpointResponseSchema,
} from "../schemas/api";
import type {
	ApiError,
	ApiRequestError,
	AuthResponse,
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
	 * Callers can check `api.isNetworkError(err)` to show a "server unreachable" message
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

	/** Instance helper for static isNetworkError (for callers using api singleton). */
	isNetworkError(
		err: unknown,
	): err is { isNetworkError: true; message: string } {
		return ApiClient.isNetworkError(err);
	}

	/**
	 * Low-level request. Returns unvalidated JSON; callers must parse with Zod
	 * (or otherwise validate) when the response shape must be trusted.
	 */
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
			const body = await response.json().catch(
				(): ApiError => ({
					error: "unknown",
					message: response.statusText,
				}),
			);
			const thrown: ApiRequestError = {
				status: response.status,
				error: body.error ?? "unknown",
				message: body.message ?? response.statusText,
			};
			if (body.retry_after != null) thrown.retry_after = body.retry_after;
			throw thrown;
		}

		return response.json();
	}

	// Auth (with runtime validation)
	async register(
		email: string,
		password: string,
		displayName: string,
	): Promise<AuthResponse> {
		const data = await this.request<unknown>("/auth/register", {
			method: "POST",
			body: JSON.stringify({
				user: { email, password, display_name: displayName },
			}),
		});
		return AuthResponseSchema.parse(data);
	}

	async login(email: string, password: string): Promise<AuthResponse> {
		const data = await this.request<unknown>("/auth/login", {
			method: "POST",
			body: JSON.stringify({ email, password }),
		});
		return AuthResponseSchema.parse(data);
	}

	async refresh(): Promise<RefreshResponse> {
		const data = await this.request<unknown>("/auth/refresh", {
			method: "POST",
		});
		return RefreshResponseSchema.parse(data);
	}

	async getProfile(): Promise<{ user: User }> {
		const data = await this.request<unknown>("/profile");
		return ProfileResponseSchema.parse(data);
	}

	// Game types (with runtime validation)
	async getGameTypes() {
		const data = await this.request<unknown>("/game_types");
		return GameTypesResponseSchema.parse(data);
	}

	// Matchmaking (with runtime validation)
	async joinMatchmaking(gameTypeId: string) {
		const data = await this.request<unknown>("/matchmaking/join", {
			method: "POST",
			body: JSON.stringify({ game_type_id: gameTypeId }),
		});
		return MatchmakingJoinResponseSchema.parse(data);
	}

	async getMatchmakingStatus() {
		const data = await this.request<unknown>("/matchmaking/status");
		return MatchmakingStatusResponseSchema.parse(data);
	}

	async cancelMatchmaking(): Promise<{ status: string }> {
		return this.request<{ status: string }>("/matchmaking/cancel", {
			method: "DELETE",
		});
	}

	// Rooms (with runtime validation)
	async getWsEndpoint(roomId: string) {
		const data = await this.request<unknown>(`/rooms/${roomId}/ws_endpoint`);
		return WsEndpointResponseSchema.parse(data);
	}

	// Announcements (with runtime validation)
	async getAnnouncements() {
		const data = await this.request<unknown>("/announcements");
		return AnnouncementsResponseSchema.parse(data);
	}
}

export const api = new ApiClient();
