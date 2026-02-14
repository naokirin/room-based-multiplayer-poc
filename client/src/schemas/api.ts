import { z } from "zod";

/**
 * Runtime validation for API responses.
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

const GameTypeSchema = z.object({
	id: z.string(),
	name: z.string(),
	player_count: z.number(),
	turn_time_limit: z.number(),
});

export const GameTypesResponseSchema = z.object({
	game_types: z.array(GameTypeSchema),
});

const MatchmakingQueuedSchema = z.object({
	status: z.literal("queued"),
	game_type_id: z.string(),
	queued_at: z.string(),
	timeout_seconds: z.number(),
});

const MatchmakingMatchedSchema = z.object({
	status: z.literal("matched"),
	room_id: z.string(),
	room_token: z.string(),
	ws_url: z.string(),
	game_type: GameTypeSchema.optional(),
});

export const MatchmakingJoinResponseSchema = z.union([
	MatchmakingQueuedSchema,
	MatchmakingMatchedSchema,
]);

export const MatchmakingStatusResponseSchema = z.object({
	status: z.enum(["queued", "matched", "timeout", "error"]),
	room_id: z.string().optional(),
	room_token: z.string().optional(),
	ws_url: z.string().optional(),
	queued_at: z.string().optional(),
	elapsed_seconds: z.number().optional(),
	message: z.string().optional(),
	can_rejoin_queue: z.boolean().optional(),
});

export const WsEndpointResponseSchema = z.object({
	ws_url: z.string(),
	node_name: z.string(),
	room_status: z.string(),
});

const AnnouncementSchema = z.object({
	id: z.string(),
	title: z.string(),
	body: z.string(),
	published_at: z.string(),
});

export const AnnouncementsResponseSchema = z.object({
	announcements: z.array(AnnouncementSchema),
});

export type AuthResponseParsed = z.infer<typeof AuthResponseSchema>;
export type RefreshResponseParsed = z.infer<typeof RefreshResponseSchema>;
export type ProfileResponseParsed = z.infer<typeof ProfileResponseSchema>;
export type GameTypesResponseParsed = z.infer<typeof GameTypesResponseSchema>;
export type MatchmakingJoinResponseParsed = z.infer<
	typeof MatchmakingJoinResponseSchema
>;
export type MatchmakingStatusResponseParsed = z.infer<
	typeof MatchmakingStatusResponseSchema
>;
export type WsEndpointResponseParsed = z.infer<typeof WsEndpointResponseSchema>;
export type AnnouncementsResponseParsed = z.infer<
	typeof AnnouncementsResponseSchema
>;
