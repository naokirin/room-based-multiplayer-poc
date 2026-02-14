import { create } from "zustand";
import { api } from "../services/api";
import type { User } from "../types";
import { getErrorMessage } from "../utils/error";

interface AuthState {
	user: User | null;
	token: string | null;
	isAuthenticated: boolean;
	isLoading: boolean;
	error: string | null;
	/** True when profile/API failed due to network (server not reachable). User stays logged in from cache. */
	serverUnreachable: boolean;
}

interface AuthActions {
	login: (email: string, password: string) => Promise<void>;
	register: (
		email: string,
		password: string,
		displayName: string,
	) => Promise<void>;
	logout: () => void;
	refreshToken: () => Promise<void>;
	initializeFromStorage: () => Promise<void>;
	clearServerUnreachable: () => void;
	/** Retry profile fetch; clears serverUnreachable on success. */
	retryConnection: () => Promise<boolean>;
}

type AuthStore = AuthState & AuthActions;

const TOKEN_KEY = "auth_token";
const USER_KEY = "auth_user";
const REFRESH_INTERVAL = 50 * 60 * 1000; // 50 minutes

let refreshTimerId: number | null = null;

const clearRefreshTimer = () => {
	if (refreshTimerId !== null) {
		clearTimeout(refreshTimerId);
		refreshTimerId = null;
	}
};

const scheduleRefresh = (refreshFn: () => Promise<void>) => {
	clearRefreshTimer();
	refreshTimerId = window.setTimeout(() => {
		refreshFn().catch((err) => {
			console.error("Auto refresh failed:", err);
		});
	}, REFRESH_INTERVAL);
};

export const useAuthStore = create<AuthStore>((set, get) => ({
	// State
	user: null,
	token: null,
	isAuthenticated: false,
	isLoading: false,
	error: null,
	serverUnreachable: false,

	// Actions
	login: async (email: string, password: string) => {
		set({ isLoading: true, error: null });
		try {
			const response = await api.login(email, password);
			const { user, access_token } = response;

			// Store token in API client
			api.setToken(access_token);

			// Persist to localStorage
			localStorage.setItem(TOKEN_KEY, access_token);
			localStorage.setItem(USER_KEY, JSON.stringify(user));

			set({
				user,
				token: access_token,
				isAuthenticated: true,
				isLoading: false,
				error: null,
				serverUnreachable: false,
			});

			// Schedule auto-refresh
			scheduleRefresh(get().refreshToken);
		} catch (err: unknown) {
			set({
				isLoading: false,
				error: getErrorMessage(err, "Login failed"),
			});
			throw err;
		}
	},

	register: async (email: string, password: string, displayName: string) => {
		set({ isLoading: true, error: null });
		try {
			const response = await api.register(email, password, displayName);
			const { user, access_token } = response;

			// Store token in API client
			api.setToken(access_token);

			// Persist to localStorage
			localStorage.setItem(TOKEN_KEY, access_token);
			localStorage.setItem(USER_KEY, JSON.stringify(user));

			set({
				user,
				token: access_token,
				isAuthenticated: true,
				isLoading: false,
				error: null,
				serverUnreachable: false,
			});

			// Schedule auto-refresh
			scheduleRefresh(get().refreshToken);
		} catch (err: unknown) {
			set({
				isLoading: false,
				error: getErrorMessage(err, "Registration failed"),
			});
			throw err;
		}
	},

	logout: () => {
		// Clear refresh timer
		clearRefreshTimer();

		// Clear API client token
		api.setToken(null);

		// Clear localStorage
		localStorage.removeItem(TOKEN_KEY);
		localStorage.removeItem(USER_KEY);

		set({
			user: null,
			token: null,
			isAuthenticated: false,
			isLoading: false,
			error: null,
			serverUnreachable: false,
		});
	},

	clearServerUnreachable: () => set({ serverUnreachable: false }),

	retryConnection: async () => {
		const { token } = get();
		if (!token) return false;
		try {
			api.setToken(token);
			const { user: freshUser } = await api.getProfile();
			localStorage.setItem(USER_KEY, JSON.stringify(freshUser));
			set({ user: freshUser, serverUnreachable: false });
			scheduleRefresh(get().refreshToken);
			return true;
		} catch (err) {
			if (api.isNetworkError(err)) {
				set({ serverUnreachable: true });
			} else {
				get().logout();
			}
			return false;
		}
	},

	refreshToken: async () => {
		const { token } = get();
		if (!token) {
			return;
		}

		try {
			const response = await api.refresh();
			const { access_token } = response;

			// Update token in API client
			api.setToken(access_token);

			// Persist to localStorage
			localStorage.setItem(TOKEN_KEY, access_token);

			set({ token: access_token });

			// Schedule next refresh
			scheduleRefresh(get().refreshToken);
		} catch (err) {
			console.error("Token refresh failed:", err);
			// On refresh failure, logout
			get().logout();
		}
	},

	initializeFromStorage: async () => {
		const token = localStorage.getItem(TOKEN_KEY);
		const userJson = localStorage.getItem(USER_KEY);

		if (token && userJson) {
			try {
				const user = JSON.parse(userJson) as User;
				api.setToken(token);

				set({
					user,
					token,
					isAuthenticated: true,
				});

				// Verify token is still valid by fetching profile
				try {
					const { user: freshUser } = await api.getProfile();
					localStorage.setItem(USER_KEY, JSON.stringify(freshUser));
					set({ user: freshUser, serverUnreachable: false });

					// Schedule auto-refresh
					scheduleRefresh(get().refreshToken);
				} catch (err) {
					if (api.isNetworkError(err)) {
						// Server not reachable (e.g. API not running); keep user from cache, show banner
						console.warn("Server unreachable:", getErrorMessage(err));
						set({ serverUnreachable: true });
					} else {
						// Token invalid or other error, logout
						console.error("Token validation failed:", err);
						get().logout();
					}
				}
			} catch (err) {
				console.error("Failed to restore session:", err);
				get().logout();
			}
		}
	},
}));
