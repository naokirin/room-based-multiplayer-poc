import {
  Application,
  Container,
  Graphics,
  Text,
  TextStyle,
  FederatedPointerEvent,
} from "pixi.js";
import type { GameState, Card, PlayerState } from "../types";
import { MAX_HP } from "../types";

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
          const { gameState, myHand, isMyTurn, myUserId } = this.pendingState;
          this.pendingState = null;
          this.updateState(gameState, myHand, isMyTurn, myUserId);
        }
      });
  }

  updateState(
    gameState: GameState | null,
    myHand: Card[],
    isMyTurn: boolean,
    myUserId: string
  ): void {
    // Buffer state if not yet initialized; will render when init completes
    if (!this.initialized || !this.stage) {
      this.pendingState = { gameState, myHand, isMyTurn, myUserId };
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
    const hpBar = this.createHPBar(player.hp, MAX_HP, 200, 20);
    hpBar.x = 20;
    hpBar.y = 35;
    container.addChild(hpBar);

    // Opponent hand: show hand_count as card backs (face-down cards)
    const handCardWidth = 28;
    const handCardHeight = 36;
    const handCardOverlap = 10; // 重なって見えるオフセット
    const maxHandCardsVisible = 10; // 表示する最大枚数（それ以上は数字で補足）
    const handCount = Math.min(player.hand_count, maxHandCardsVisible);
    const handStartX = 240;
    const handY = 32;

    for (let i = 0; i < handCount; i++) {
      const cardBack = this.createCardBack(handCardWidth, handCardHeight);
      cardBack.x = handStartX + i * (handCardWidth - handCardOverlap);
      cardBack.y = handY;
      container.addChild(cardBack);
    }

    // 手札が max を超える場合は「+N」を表示
    if (player.hand_count > maxHandCardsVisible) {
      const extraStyle = new TextStyle({
        fontFamily: "Arial",
        fontSize: 12,
        fill: 0xcccccc,
      });
      const extraText = new Text({
        text: `+${player.hand_count - maxHandCardsVisible}`,
        style: extraStyle,
      });
      extraText.x =
        handStartX +
        handCount * (handCardWidth - handCardOverlap) +
        handCardWidth / 2;
      extraText.y = handY + handCardHeight / 2;
      extraText.anchor.set(0.5, 0.5);
      container.addChild(extraText);
    }

    // Deck count (right of hand cards)
    const handVisualWidth =
      handCount * (handCardWidth - handCardOverlap) + handCardWidth;
    const deckLabelX =
      handStartX +
      handVisualWidth +
      (player.hand_count > maxHandCardsVisible ? 24 : 12);
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

    this.stage.addChild(container);
  }

  /** 相手の手札枚数用の「カード裏」見た目（中身は見せない） */
  private createCardBack(width: number, height: number): Container {
    const container = new Container();
    const bg = new Graphics();
    // 角を少し丸くしたカード裏
    const radius = 4;
    bg.roundRect(0, 0, width, height, radius);
    bg.fill(0x2d3748);
    bg.stroke({ width: 1.5, color: 0x4a5568 });
    container.addChild(bg);
    // 中央に「？」マークで裏向きであることを示す
    const backStyle = new TextStyle({
      fontFamily: "Arial",
      fontSize: 14,
      fill: 0x718096,
    });
    const backText = new Text({
      text: "?",
      style: backStyle,
    });
    backText.x = width / 2;
    backText.y = height / 2;
    backText.anchor.set(0.5, 0.5);
    container.addChild(backText);
    return container;
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
    const hpBar = this.createHPBar(player.hp, MAX_HP, 200, 20);
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
  ): Container {
    // PixiJS v8: Only Container may have children. Use Container for bar + label.
    const container = new Container();
    const bar = new Graphics();

    // Background
    bar.rect(0, 0, width, height);
    bar.fill(0x333333);

    // HP fill
    const hpPercent = currentHP / maxHP;
    const fillWidth = width * hpPercent;

    let fillColor = 0x28a745; // Green
    if (hpPercent <= 0.25) {
      fillColor = 0xdc3545; // Red
    } else if (hpPercent <= 0.5) {
      fillColor = 0xffc107; // Yellow
    }

    bar.rect(0, 0, fillWidth, height);
    bar.fill(fillColor);
    container.addChild(bar);

    // HP text (sibling of bar, not child of Graphics)
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
    nameText.y = 8;
    nameText.anchor.set(0.5, 0);
    container.addChild(nameText);

    const effects: Array<{ effect: string; value: number }> =
      card.effects && card.effects.length >= 1
        ? card.effects
        : [{ effect: card.effect, value: card.value ?? 0 }];
    const isComposite = effects.length > 1;

    if (isComposite) {
      // Composite: each effect as a row with icon + large value
      const rowHeight = (height - 28) / effects.length;
      const labelFontSize = 11;
      const valueFontSize = 18;

      effects.forEach((e, i) => {
        const yBase = 26 + i * rowHeight;
        const labelStyle = new TextStyle({
          fontFamily: "Arial",
          fontSize: labelFontSize,
          fill: 0xe0e0e0,
          align: "left",
        });
        const labelText = new Text({
          text: `${this.getEffectShortLabel(e.effect)} ${this.getEffectShortName(e.effect)}`,
          style: labelStyle,
        });
        labelText.x = 6;
        labelText.y = yBase;
        labelText.anchor.set(0, 0);
        container.addChild(labelText);

        const valueStyle = new TextStyle({
          fontFamily: "Arial",
          fontSize: valueFontSize,
          fill: this.getEffectColor(e.effect),
          fontWeight: "bold",
          align: "right",
        });
        const valueStr =
          e.effect === "reshuffle_hand" ? "—" : e.value.toString();
        const valueText = new Text({
          text: valueStr,
          style: valueStyle,
        });
        valueText.x = width - 6;
        valueText.y = yBase + rowHeight / 2 - valueFontSize / 2;
        valueText.anchor.set(1, 0.5);
        container.addChild(valueText);
      });
    } else {
      // Single effect: one effect label + one large value
      const effectStyle = new TextStyle({
        fontFamily: "Arial",
        fontSize: 12,
        fill: 0xe0e0e0,
        align: "center",
      });
      const effectLabel = new Text({
        text: this.getEffectDisplay(card.effect),
        style: effectStyle,
      });
      effectLabel.x = width / 2;
      effectLabel.y = height / 2 - 22;
      effectLabel.anchor.set(0.5, 0.5);
      container.addChild(effectLabel);

      const valueStyle = new TextStyle({
        fontFamily: "Arial",
        fontSize: 24,
        fill: this.getEffectColor(card.effect),
        fontWeight: "bold",
      });
      const valueStr =
        card.effect === "reshuffle_hand" ? "—" : (card.value != null ? card.value : 0).toString();
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

  private getEffectShortName(effect: string): string {
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

  private getEffectShortLabel(effect: string): string {
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

  private getEffectDisplay(effect: string): string {
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

  private getEffectColor(effect: string): number {
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

  onCardClick(callback: (cardId: string) => void): void {
    this.cardClickCallback = callback;
  }

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
        baseTexture: true,
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
