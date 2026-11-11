-- Coordinates are in the 960x640 landscape content area (config.lua authors it as 640x960).

return {
	-- Scaled-up pixel art stays sharp only with nearest-neighbour filtering; text and buttons do not.
	textureFilter = {
		pixelArt = "nearest",
		ui = "linear",
	},

	font = {
		heading = "assets/fonts/roboto/Roboto-Bold.ttf",
		body = "assets/fonts/roboto/Roboto-Light.ttf",
	},

	heading = {
		y = 39,
		size = 32,
	},

	caption = {
		y = 78,
		size = 24,
	},

	-- The line the character stands on. Its top edge is where the feet go.
	floor = {
		y = 440,
		height = 6,
		width = 520,
	},

	-- How many unscaled pixels each character's frame centre sits above the floor line; tools/check_assets.py checks them.
	character = {
		spriteFeetOffset = 36,
		skeletalFeetOffset = 44,
	},

	ui = {
		-- Placed relative to the bottom of the visible screen, so a taller-than-expected
		-- viewport keeps the buttons on screen instead of off it.
		bottomMargin = 25,

		buttonWidth = 150,
		buttonHeight = 68,
		buttonGap = 16,
		fontSize = 32,

		styleButtonWidth = 260,
		styleButtonHeight = 92,
		styleButtonFontSize = 22,

		-- Between the style button and the animation panel.
		styleButtonGap = 40,

		cornerRadius = 8,
	},

	-- The panel behind the animation buttons. Offsets are measured from the panel's top edge to the centre of the title and of the button row.
	animationPanel = {
		paddingX = 18,
		height = 134,

		titleOffset = 26,
		titleSize = 20,

		buttonsOffset = 82,

		cornerRadius = 12,
	},

	-- The panel of outfit buttons on the right edge of the visible screen, shown while the skeletal character shows.
	-- Its title, corner radius and colours match the animation panel's. Offsets are measured from the panel's top edge.
	outfitPanel = {
		rightMargin = 25,

		-- How far above the floor line's top edge the panel's bottom edge sits.
		floorOffset = 0,

		paddingX = 12,
		paddingBottom = 18,

		-- To the centre of the top button.
		buttonsOffset = 72,

		buttonWidth = 150,
		buttonHeight = 48,
		buttonGap = 10,
		fontSize = 20,
	},

	palette = {
		background = { 0.09, 0.10, 0.12 },
		floor = { 0.22, 0.24, 0.28 },

		text = { 0.94, 0.95, 0.97 },
		textMuted = { 0.68, 0.71, 0.76 },

		panelFill = { 0.12, 0.13, 0.16 },
		panelBorder = { 0.26, 0.28, 0.33 },

		buttonFill = { 0.16, 0.17, 0.21 },
		buttonActiveFill = { 0.30, 0.55, 0.85 },
		buttonBorder = { 0.34, 0.36, 0.42 },
	},
}
