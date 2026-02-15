import { Container, Text, TextStyle } from "pixi.js";
import type { PlayerState } from "../types";
import { MAX_HP } from "../types";
import { createCardBack, createHPBar } from "./primitives";

const HAND_CARD_WIDTH = 28;
const HAND_CARD_HEIGHT = 36;
const HAND_CARD_OVERLAP = 10;
const MAX_HAND_CARDS_VISIBLE = 10;

/**
 * Create a panel for one player: name, HP bar, optional hand as card backs, deck count.
 */
export function createPlayerInfoPanel(
	player: PlayerState,
	options: {
		y: number;
		showHandAsBacks: boolean;
	},
): Container {
	const container = new Container();
	container.y = options.y;

	const nameStyle = new TextStyle({
		fontFamily: "Arial",
		fontSize: 18,
		fill: 0xffffff,
	});

	const nameText = new Text({
		text: player.display_name,
		style: nameStyle,
	});
	nameText.x = 20;
	nameText.y = 10;
	container.addChild(nameText);

	const hpBar = createHPBar(player.hp, MAX_HP, 200, 20);
	hpBar.x = 20;
	hpBar.y = 35;
	container.addChild(hpBar);

	if (options.showHandAsBacks) {
		const handCount = Math.min(player.hand_count, MAX_HAND_CARDS_VISIBLE);
		const handStartX = 240;
		const handY = 32;

		for (let i = 0; i < handCount; i++) {
			const cardBack = createCardBack(HAND_CARD_WIDTH, HAND_CARD_HEIGHT);
			cardBack.x = handStartX + i * (HAND_CARD_WIDTH - HAND_CARD_OVERLAP);
			cardBack.y = handY;
			container.addChild(cardBack);
		}

		if (player.hand_count > MAX_HAND_CARDS_VISIBLE) {
			const extraStyle = new TextStyle({
				fontFamily: "Arial",
				fontSize: 12,
				fill: 0xcccccc,
			});
			const extraText = new Text({
				text: `+${player.hand_count - MAX_HAND_CARDS_VISIBLE}`,
				style: extraStyle,
			});
			extraText.x =
				handStartX +
				handCount * (HAND_CARD_WIDTH - HAND_CARD_OVERLAP) +
				HAND_CARD_WIDTH / 2;
			extraText.y = handY + HAND_CARD_HEIGHT / 2;
			extraText.anchor.set(0.5, 0.5);
			container.addChild(extraText);
		}

		const handVisualWidth =
			handCount * (HAND_CARD_WIDTH - HAND_CARD_OVERLAP) + HAND_CARD_WIDTH;
		const deckLabelX =
			handStartX +
			handVisualWidth +
			(player.hand_count > MAX_HAND_CARDS_VISIBLE ? 24 : 12);
		const deckCountStyle = new TextStyle({
			fontFamily: "Arial",
			fontSize: 14,
			fill: 0xaaaaaa,
		});
		const deckCountText = new Text({
			text: `Deck: ${player.deck_count}`,
			style: deckCountStyle,
		});
		deckCountText.x = deckLabelX;
		deckCountText.y = 35;
		container.addChild(deckCountText);
	} else {
		const deckCountStyle = new TextStyle({
			fontFamily: "Arial",
			fontSize: 14,
			fill: 0xaaaaaa,
		});
		const deckCountText = new Text({
			text: `Deck: ${player.deck_count}`,
			style: deckCountStyle,
		});
		deckCountText.x = 240;
		deckCountText.y = 35;
		container.addChild(deckCountText);
	}

	return container;
}
