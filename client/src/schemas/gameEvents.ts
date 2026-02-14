import { z } from "zod";

/**
 * Runtime validation for WebSocket game event payloads from the game server.
 * Use safeParse in handlers; on failure log and skip state update.
 */

const CardEffectSchema = z.object({
	effect: z.string(),
	value: z.number().optional(),
});

const ServerCardSchema = z.object({
	id: z.string(),
	name: z.string(),
	effects: z.array(CardEffectSchema).optional(),
});

const PlayerStateSchema = z.object({
	display_name: z.string(),
	connected: z.boolean(),
	hp: z.number(),
	hand_count: z.number(),
	deck_count: z.number(),
});

/** game:started payload */
export const GameStartedPayloadSchema = z.object({
	current_turn: z.string(),
	your_hand: z.array(ServerCardSchema).optional(),
	your_hp: z.number().optional(),
	your_deck_count: z.number().optional(),
	your_display_name: z.string().optional(),
	opponent_id: z.string().optional(),
	opponent_display_name: z.string().optional(),
	opponent_hp: z.number().optional(),
	opponent_hand_count: z.number().optional(),
	opponent_deck_count: z.number().optional(),
	turn_number: z.number().optional(),
	turn_time_remaining: z.number().optional(),
});

/** game:action_applied payload */
const CardPlayedEffectSchema = z
	.object({
		type: z.string(),
		player_id: z.string().optional(),
		card: ServerCardSchema.optional(),
	})
	.passthrough();

export const ActionAppliedPayloadSchema = z.object({
	actor_id: z.string(),
	effects: z.array(CardPlayedEffectSchema).optional(),
	players: z.record(z.string(), PlayerStateSchema),
});

/** game:hand_updated payload */
export const HandUpdatedPayloadSchema = z.object({
	hand: z.array(ServerCardSchema),
	deck_count: z.number().optional(),
});

/** game:turn_changed payload */
export const TurnChangedPayloadSchema = z.object({
	current_turn: z.string(),
	turn_number: z.number(),
	turn_time_remaining: z.number().optional(),
	drawn_card: ServerCardSchema.optional(),
});

/** game:ended payload */
export const GameEndedPayloadSchema = z.object({
	winner_id: z.string().nullable(),
	reason: z.string(),
});

/** game:aborted payload */
export const GameAbortedPayloadSchema = z.object({
	reason: z.string(),
});

/** player:reconnect_token or join response reconnect_token */
export const ReconnectTokenPayloadSchema = z.object({
	reconnect_token: z.string(),
});

export type GameStartedPayload = z.infer<typeof GameStartedPayloadSchema>;
export type ActionAppliedPayload = z.infer<typeof ActionAppliedPayloadSchema>;
export type HandUpdatedPayload = z.infer<typeof HandUpdatedPayloadSchema>;
export type TurnChangedPayload = z.infer<typeof TurnChangedPayloadSchema>;
export type GameEndedPayload = z.infer<typeof GameEndedPayloadSchema>;
export type GameAbortedPayload = z.infer<typeof GameAbortedPayloadSchema>;
export type ReconnectTokenPayload = z.infer<typeof ReconnectTokenPayloadSchema>;
