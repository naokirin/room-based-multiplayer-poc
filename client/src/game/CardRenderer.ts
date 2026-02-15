import { Container, Graphics, Text, TextStyle } from "pixi.js";
import type { Card } from "../types";

/**
 * Effect display helpers for card rendering. Exported for reuse (e.g. tooltips).
 */
export function getEffectShortName(effect: string): string {
	switch (effect) {
		case "deal_damage":
			return "Damage";
		case "heal":
			return "Heal";
		case "draw_card":
			return "Draw";
		case "discard_opponent":
			return "Discard";
		case "reshuffle_hand":
			return "Reshuffle";
		default:
			return effect;
	}
}

export function getEffectShortLabel(effect: string): string {
	switch (effect) {
		case "deal_damage":
			return "⚔";
		case "heal":
			return "❤";
		case "draw_card":
			return "📄";
		case "discard_opponent":
			return "✂";
		case "reshuffle_hand":
			return "🔀";
		default:
			return "?";
	}
}

export function getEffectDisplay(effect: string): string {
	switch (effect) {
		case "deal_damage":
			return "⚔️ Damage";
		case "heal":
			return "❤️ Heal";
		case "draw_card":
			return "📄 Draw";
		case "discard_opponent":
			return "✂️ Discard";
		case "reshuffle_hand":
			return "🔀 Reshuffle";
		default:
			return effect;
	}
}

export function getEffectColor(effect: string): number {
	switch (effect) {
		case "deal_damage":
			return 0xff6b6b;
		case "heal":
			return 0x51cf66;
		case "draw_card":
			return 0x4dabf7;
		case "discard_opponent":
			return 0xda77f2;
		case "reshuffle_hand":
			return 0xffd43b;
		default:
			return 0xffffff;
	}
}

/**
 * Create a PixiJS Container representing a single card (face-up).
 */
export function createCard(
	card: Card,
	width: number,
	height: number,
	interactive: boolean,
): Container {
	const container = new Container();

	// Card background
	const bg = new Graphics();
	bg.rect(0, 0, width, height);
	bg.fill(interactive ? 0x4a5568 : 0x2d3748);
	bg.stroke({ width: 2, color: interactive ? 0x63b3ed : 0x4a5568 });
	container.addChild(bg);

	// Card name
	const nameStyle = new TextStyle({
		fontFamily: "Arial",
		fontSize: 12,
		fill: 0xffffff,
		fontWeight: "bold",
		align: "center",
		wordWrap: true,
		wordWrapWidth: width - 10,
	});

	const nameText = new Text({
		text: card.name,
		style: nameStyle,
	});
	nameText.x = width / 2;
	nameText.y = 8;
	nameText.anchor.set(0.5, 0);
	container.addChild(nameText);

	const effects: Array<{ effect: string; value: number }> =
		card.effects && card.effects.length >= 1
			? card.effects
			: [{ effect: card.effect, value: card.value ?? 0 }];
	const isComposite = effects.length > 1;

	if (isComposite) {
		const rowHeight = (height - 28) / effects.length;
		const labelFontSize = 11;
		const valueFontSize = 18;

		for (let i = 0; i < effects.length; i++) {
			const e = effects[i];
			const yBase = 26 + i * rowHeight;
			const labelStyle = new TextStyle({
				fontFamily: "Arial",
				fontSize: labelFontSize,
				fill: 0xe0e0e0,
				align: "left",
			});
			const labelText = new Text({
				text: `${getEffectShortLabel(e.effect)} ${getEffectShortName(e.effect)}`,
				style: labelStyle,
			});
			labelText.x = 6;
			labelText.y = yBase;
			labelText.anchor.set(0, 0);
			container.addChild(labelText);

			const valueStyle = new TextStyle({
				fontFamily: "Arial",
				fontSize: valueFontSize,
				fill: getEffectColor(e.effect),
				fontWeight: "bold",
				align: "right",
			});
			const valueStr = e.effect === "reshuffle_hand" ? "—" : e.value.toString();
			const valueText = new Text({
				text: valueStr,
				style: valueStyle,
			});
			valueText.x = width - 6;
			valueText.y = yBase + rowHeight / 2 - valueFontSize / 2;
			valueText.anchor.set(1, 0.5);
			container.addChild(valueText);
		}
	} else {
		const effectStyle = new TextStyle({
			fontFamily: "Arial",
			fontSize: 12,
			fill: 0xe0e0e0,
			align: "center",
		});
		const effectLabel = new Text({
			text: getEffectDisplay(card.effect),
			style: effectStyle,
		});
		effectLabel.x = width / 2;
		effectLabel.y = height / 2 - 22;
		effectLabel.anchor.set(0.5, 0.5);
		container.addChild(effectLabel);

		const valueStyle = new TextStyle({
			fontFamily: "Arial",
			fontSize: 24,
			fill: getEffectColor(card.effect),
			fontWeight: "bold",
		});
		const valueStr =
			card.effect === "reshuffle_hand"
				? "—"
				: (card.value != null ? card.value : 0).toString();
		const valueText = new Text({
			text: valueStr,
			style: valueStyle,
		});
		valueText.x = width / 2;
		valueText.y = height - 22;
		valueText.anchor.set(0.5, 0.5);
		container.addChild(valueText);
	}

	return container;
}
