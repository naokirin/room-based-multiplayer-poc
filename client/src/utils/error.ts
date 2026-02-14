/**
 * Extract a user-facing error message from unknown thrown values.
 * Used by stores and components for consistent error handling (CODE_REVIEW Warning 1).
 */
export function getErrorMessage(
	err: unknown,
	fallback = "An error occurred",
): string {
	if (err instanceof Error) {
		return err.message || fallback;
	}
	if (typeof err === "object" && err !== null && "message" in err) {
		const msg = (err as { message?: unknown }).message;
		if (typeof msg === "string") return msg;
	}
	return fallback;
}
