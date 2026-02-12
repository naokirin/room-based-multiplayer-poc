import {
  Application,
  Container,
  Graphics,
  Text,
  TextStyle,
  FederatedPointerEvent,
} from "pixi.js";
import type { GameState, Card, PlayerState } from "../types";

interface RendererOptions {
  width?: number;
  height?: number;
}

export class GameRenderer {
  private app: Application;
  private stage: Container | null = null;
  private cardClickCallback: ((cardId: string) => void) | null = null;
  private initialized = false;

  constructor(container: HTMLElement, options: RendererOptions = {}) {
    const width = options.width || 800;
    const height = options.height || 600;

    // Create PixiJS Application
    this.app = new Application();

    // Initialize the app asynchronously
    this.app
      .init({
        width,
        height,
        backgroundColor: 0x1a1a2e,
        antialias: true,
      })
      .then(() => {
        // Append canvas to container
        container.appendChild(this.app.canvas);

        // Create stage after app is initialized
        this.stage = new Container();
        this.app.stage.addChild(this.stage);
        this.initialized = true;
      });
  }

  updateState(
    gameState: GameState | null,
    myHand: Card[],
    isMyTurn: boolean,
    myUserId: string
  ): void {
    // Wait for initialization
    if (!this.initialized || !this.stage) {
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

    // Render opponent info (top)
    if (opponentPlayer) {
      this.renderOpponentInfo(opponentPlayer, 0);
    }

    // Render turn indicator (center-top)
    this.renderTurnIndicator(isMyTurn, gameState.turn_number);

    // Render my info and hand (bottom)
    if (myPlayer) {
      this.renderMyInfo(myPlayer);
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

  private renderOpponentInfo(player: PlayerState, yOffset: number): void {
    if (!this.stage) return;

    const container = new Container();
    container.y = yOffset + 20;

    // Name
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

    // HP Bar
    const hpBar = this.createHPBar(player.hp, 100, 200, 20);
    hpBar.x = 20;
    hpBar.y = 35;
    container.addChild(hpBar);

    // Card count
    const cardCountStyle = new TextStyle({
      fontFamily: "Arial",
      fontSize: 14,
      fill: 0xaaaaaa,
    });

    const cardCountText = new Text({
      text: `Hand: ${player.hand_count} | Deck: ${player.deck_count}`,
      style: cardCountStyle,
    });
    cardCountText.x = 240;
    cardCountText.y = 35;
    container.addChild(cardCountText);

    this.stage.addChild(container);
  }

  private renderMyInfo(player: PlayerState): void {
    if (!this.stage) return;

    const container = new Container();
    container.y = this.app.screen.height - 200;

    // Name
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

    // HP Bar
    const hpBar = this.createHPBar(player.hp, 100, 200, 20);
    hpBar.x = 20;
    hpBar.y = 35;
    container.addChild(hpBar);

    // Deck count
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

    this.stage.addChild(container);
  }

  private createHPBar(
    currentHP: number,
    maxHP: number,
    width: number,
    height: number
  ): Graphics {
    const container = new Graphics();

    // Background
    container.rect(0, 0, width, height);
    container.fill(0x333333);

    // HP fill
    const hpPercent = currentHP / maxHP;
    const fillWidth = width * hpPercent;

    let fillColor = 0x28a745; // Green
    if (hpPercent <= 0.25) {
      fillColor = 0xdc3545; // Red
    } else if (hpPercent <= 0.5) {
      fillColor = 0xffc107; // Yellow
    }

    container.rect(0, 0, fillWidth, height);
    container.fill(fillColor);

    // HP text
    const hpStyle = new TextStyle({
      fontFamily: "Arial",
      fontSize: 14,
      fill: 0xffffff,
      fontWeight: "bold",
    });

    const hpText = new Text({
      text: `${currentHP} / ${maxHP}`,
      style: hpStyle,
    });
    hpText.x = width / 2 - hpText.width / 2;
    hpText.y = height / 2 - hpText.height / 2;
    container.addChild(hpText);

    return container;
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
      const cardGraphic = this.createCard(card, cardWidth, cardHeight, isMyTurn);
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

  private createCard(
    card: Card,
    width: number,
    height: number,
    interactive: boolean
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
    nameText.y = 10;
    nameText.anchor.set(0.5, 0);
    container.addChild(nameText);

    // Effect icon/text
    const effectStyle = new TextStyle({
      fontFamily: "Arial",
      fontSize: 10,
      fill: 0xaaaaaa,
      align: "center",
    });

    const effectText = new Text({
      text: this.getEffectDisplay(card.effect),
      style: effectStyle,
    });
    effectText.x = width / 2;
    effectText.y = height / 2 - 5;
    effectText.anchor.set(0.5);
    container.addChild(effectText);

    // Value
    const valueStyle = new TextStyle({
      fontFamily: "Arial",
      fontSize: 20,
      fill: this.getEffectColor(card.effect),
      fontWeight: "bold",
    });

    const valueText = new Text({
      text: card.value.toString(),
      style: valueStyle,
    });
    valueText.x = width / 2;
    valueText.y = height - 25;
    valueText.anchor.set(0.5);
    container.addChild(valueText);

    return container;
  }

  private getEffectDisplay(effect: string): string {
    switch (effect) {
      case "deal_damage":
        return "⚔️ Damage";
      case "heal":
        return "❤️ Heal";
      case "draw_card":
        return "📄 Draw";
      default:
        return effect;
    }
  }

  private getEffectColor(effect: string): number {
    switch (effect) {
      case "deal_damage":
        return 0xff6b6b;
      case "heal":
        return 0x51cf66;
      case "draw_card":
        return 0x4dabf7;
      default:
        return 0xffffff;
    }
  }

  onCardClick(callback: (cardId: string) => void): void {
    this.cardClickCallback = callback;
  }

  destroy(): void {
    this.app.destroy(true, { children: true, texture: true, baseTexture: true });
  }
}
