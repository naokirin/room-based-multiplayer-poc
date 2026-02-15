import {
	Application,
	Container,
	type FederatedPointerEvent,
	Text,
	TextStyle,
} from "pixi.js";
import type { LastPlayedCard } from "../stores/gameStore";
import type { Card, GameState } from "../types";
import { createCard } from "./CardRenderer";
import { createPlayerInfoPanel } from "./PlayerInfoPanel";

interface RendererOptions {
	width?: number;
	height?: number;
}

export class GameRenderer {
	private app: Application;
	private containerRef: HTMLElement;
	private stage: Container | null = null;
	private cardClickCallback: ((cardId: string) => void) | null = null;
	private initialized = false;
	private destroyed = false;
	private pendingState: {
		gameState: GameState | null;
		myHand: Card[];
		isMyTurn: boolean;
		myUserId: string;
		lastPlayedCard?: LastPlayedCard;
	} | null = null;

	constructor(container: HTMLElement, options: RendererOptions = {}) {
		this.containerRef = container;
		const width = options.width || 800;
		const height = options.height || 600;

		// Create PixiJS Application
		this.app = new Application();

		// Initialize the app asynchronously. autoStart: false so the ticker does not
		// run until our stage is attached (avoids updateLocalTransform on null).
		this.app
			.init({
				width,
				height,
				backgroundColor: 0x1a1a2e,
				antialias: true,
				autoStart: false,
			})
			.then(() => {
				// Skip if already destroyed (e.g. unmount before init completed)
				if (this.destroyed) return;

				const canvas = this.app?.canvas;
				const stage = this.app?.stage;
				if (!canvas || !stage) return;

				container.appendChild(canvas);

				this.stage = new Container();
				stage.addChild(this.stage);
				this.initialized = true;

				// Start ticker only after our stage is in the scene graph
				const app = this.app as Application & { start?: () => void };
				app.start?.();

				// Render any state that arrived before initialization completed
				if (this.pendingState) {
					const { gameState, myHand, isMyTurn, myUserId, lastPlayedCard } =
						this.pendingState;
					this.pendingState = null;
					this.updateState(
						gameState,
						myHand,
						isMyTurn,
						myUserId,
						lastPlayedCard,
					);
				}
			});
	}

	updateState(
		gameState: GameState | null,
		myHand: Card[],
		isMyTurn: boolean,
		myUserId: string,
		lastPlayedCard?: LastPlayedCard,
	): void {
		// Buffer state if not yet initialized; will render when init completes
		if (!this.initialized || !this.stage) {
			this.pendingState = {
				gameState,
				myHand,
				isMyTurn,
				myUserId,
				lastPlayedCard,
			};
			return;
		}

		// Clear previous render
		this.stage.removeChildren();

		if (!gameState) {
			this.renderWaitingMessage();
			return;
		}

		const players = gameState.players;
		const myPlayer = players[myUserId];
		const opponentIds = Object.keys(players).filter((id) => id !== myUserId);
		const opponentId = opponentIds[0]; // For 2-player game
		const opponentPlayer = opponentId ? players[opponentId] : null;

		if (opponentPlayer) {
			this.stage.addChild(
				createPlayerInfoPanel(opponentPlayer, { y: 20, showHandAsBacks: true }),
			);
		}

		// Render turn indicator (center-top)
		this.renderTurnIndicator(isMyTurn, gameState.turn_number);

		// Render played card in center (both players see who played what)
		if (lastPlayedCard) {
			this.renderPlayedCardCenter(lastPlayedCard);
		}

		if (myPlayer) {
			this.stage.addChild(
				createPlayerInfoPanel(myPlayer, {
					y: this.app.screen.height - 200,
					showHandAsBacks: false,
				}),
			);
			this.renderMyHand(myHand, isMyTurn);
		}
	}

	private renderWaitingMessage(): void {
		if (!this.stage) return;

		const style = new TextStyle({
			fontFamily: "Arial",
			fontSize: 32,
			fill: 0xffffff,
			align: "center",
		});

		const text = new Text({
			text: "Waiting for game to start...",
			style,
		});

		text.x = this.app.screen.width / 2;
		text.y = this.app.screen.height / 2;
		text.anchor.set(0.5);

		this.stage.addChild(text);
	}

	private renderTurnIndicator(isMyTurn: boolean, turnNumber: number): void {
		if (!this.stage) return;

		const container = new Container();
		container.y = 100;

		const style = new TextStyle({
			fontFamily: "Arial",
			fontSize: 24,
			fill: isMyTurn ? 0x28a745 : 0xffc107,
			fontWeight: "bold",
		});

		const text = new Text({
			text: isMyTurn ? "YOUR TURN" : "OPPONENT'S TURN",
			style,
		});

		text.x = this.app.screen.width / 2;
		text.anchor.set(0.5);
		container.addChild(text);

		const turnStyle = new TextStyle({
			fontFamily: "Arial",
			fontSize: 16,
			fill: 0xaaaaaa,
		});

		const turnText = new Text({
			text: `Turn ${turnNumber}`,
			style: turnStyle,
		});

		turnText.x = this.app.screen.width / 2;
		turnText.y = 30;
		turnText.anchor.set(0.5);
		container.addChild(turnText);

		this.stage.addChild(container);
	}

	private renderPlayedCardCenter(last: LastPlayedCard): void {
		if (!this.stage) return;

		const centerX = this.app.screen.width / 2;
		const container = new Container();
		container.y = 155;

		const labelStyle = new TextStyle({
			fontFamily: "Arial",
			fontSize: 18,
			fill: 0xe0e0e0,
			align: "center",
		});
		const labelText = new Text({
			text: `${last.actorDisplayName} が 「${last.card.name}」 を出しました`,
			style: labelStyle,
		});
		labelText.x = centerX;
		labelText.anchor.set(0.5, 0);
		container.addChild(labelText);

		const cardWidth = 100;
		const cardHeight = 130;
		const cardGraphic = createCard(last.card, cardWidth, cardHeight, false);
		cardGraphic.x = centerX - cardWidth / 2;
		cardGraphic.y = 28;
		container.addChild(cardGraphic);

		this.stage.addChild(container);
	}

	private renderMyHand(cards: Card[], isMyTurn: boolean): void {
		if (!this.stage) return;

		const container = new Container();
		container.y = this.app.screen.height - 150;

		const cardWidth = 80;
		const cardHeight = 100;
		const cardSpacing = 10;
		const totalWidth = cards.length * (cardWidth + cardSpacing) - cardSpacing;
		const startX = (this.app.screen.width - totalWidth) / 2;

		cards.forEach((card, index) => {
			const cardGraphic = createCard(card, cardWidth, cardHeight, isMyTurn);
			cardGraphic.x = startX + index * (cardWidth + cardSpacing);

			if (isMyTurn) {
				cardGraphic.eventMode = "static";
				cardGraphic.cursor = "pointer";

				cardGraphic.on("pointerdown", (event: FederatedPointerEvent) => {
					event.stopPropagation();
					if (this.cardClickCallback) {
						this.cardClickCallback(card.id);
					}
				});

				// Hover effect
				cardGraphic.on("pointerover", () => {
					cardGraphic.y = -10;
				});

				cardGraphic.on("pointerout", () => {
					cardGraphic.y = 0;
				});
			}

			container.addChild(cardGraphic);
		});

		this.stage.addChild(container);
	}

	onCardClick(callback: (cardId: string) => void): void {
		this.cardClickCallback = callback;
	}

	/**
	 * Teardown for PixiJS v8. Uses app.stop?() and app._cancelResize as workarounds
	 * for clean shutdown (avoids updateLocalTransform on null). Re-verify with future
	 * Pixi versions if upgrade breaks unmount. (CODE_REVIEW Suggestion 11)
	 */
	destroy(): void {
		this.destroyed = true;

		// Stop ticker first so no render() runs during/after destroy (avoids updateLocalTransform on null)
		const app = this.app as Application & {
			_cancelResize?: () => void;
			stop?: () => void;
		};
		try {
			app.stop?.();
		} catch {
			// Ignore
		}

		try {
			if (typeof app?._cancelResize !== "function") {
				app._cancelResize = () => {};
			}
			this.app.destroy(true, {
				children: true,
				texture: true,
				textureSource: true,
			});
		} catch {
			// Remove canvas from DOM when destroy throws (e.g. half-initialized app)
			try {
				const canvas = this.containerRef?.querySelector?.("canvas");
				if (canvas?.parentElement) {
					canvas.parentElement.removeChild(canvas);
				}
			} catch {
				// Ignore cleanup errors
			}
		}
	}
}
