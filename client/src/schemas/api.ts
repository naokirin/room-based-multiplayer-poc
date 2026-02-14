import { z } from "zod";

/**
 * Runtime validation for API responses (CODE_REVIEW Suggestion 12).
 * Ensures server response shape matches expected types.
 */

const UserSchema = z.object({
	id: z.string(),
	email: z.string(),
	display_name: z.string(),
	role: z.enum(["player", "admin"]).optional(),
	status: z.enum(["active", "frozen"]).optional(),
	created_at: z.string().optional(),
});

export const AuthResponseSchema = z.object({
	user: UserSchema,
	access_token: z.string(),
	expires_at: z.string(),
});

export const RefreshResponseSchema = z.object({
	access_token: z.string(),
	expires_at: z.string(),
});

export const ProfileResponseSchema = z.object({
	user: UserSchema,
});

export type AuthResponseParsed = z.infer<typeof AuthResponseSchema>;
export type RefreshResponseParsed = z.infer<typeof RefreshResponseSchema>;
export type ProfileResponseParsed = z.infer<typeof ProfileResponseSchema>;
