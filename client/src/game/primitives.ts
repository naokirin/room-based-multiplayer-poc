import { Container, Graphics, Text, TextStyle } from "pixi.js";

/**
 * Create an HP bar with background, colored fill, and "current / max" label.
 * PixiJS v8: only Container may have children; bar and label are siblings in the container.
 */
export function createHPBar(
	currentHP: number,
	maxHP: number,
	width: number,
	height: number,
): Container {
	const container = new Container();
	const bar = new Graphics();

	bar.rect(0, 0, width, height);
	bar.fill(0x333333);

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

/**
 * Create a card-back graphic (face-down card with "?" in the center).
 */
export function createCardBack(width: number, height: number): Container {
	const container = new Container();
	const bg = new Graphics();
	const radius = 4;
	bg.roundRect(0, 0, width, height, radius);
	bg.fill(0x2d3748);
	bg.stroke({ width: 1.5, color: 0x4a5568 });
	container.addChild(bg);

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
