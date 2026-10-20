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
		y = 54,
		size = 32,
	},

	caption = {
		y = 96,
		size = 24,
	},

	-- The line the character stands on. Its top edge is where the feet go.
	floor = {
		y = 420,
		height = 6,
		width = 520,
	},

	-- The art's feet rest on row 68 of the 72-pixel frame, so the frame centre sits this
	-- many unscaled pixels above the floor line: 68 - 72 / 2.
	character = {
		feetOffset = 32,
	},

	-- Centred between the floor's bottom edge (423) and the style button's top edge (510)
	-- on the 640-tall content area.
	description = {
		y = 466,
		size = 18,
		width = 720,
	},

	ui = {
		-- Placed relative to the bottom of the visible screen, so a taller-than-expected
		-- viewport keeps the buttons on screen instead of off it.
		bottomMargin = 46,

		buttonWidth = 150,
		buttonHeight = 68,
		buttonGap = 16,
		fontSize = 32,

		styleButtonWidth = 220,
		styleButtonHeight = 84,
		styleButtonGap = 48,

		cornerRadius = 8,
	},

	palette = {
		background = { 0.09, 0.10, 0.12 },
		floor = { 0.22, 0.24, 0.28 },

		text = { 0.94, 0.95, 0.97 },
		textMuted = { 0.68, 0.71, 0.76 },

		buttonFill = { 0.16, 0.17, 0.21 },
		buttonActiveFill = { 0.30, 0.55, 0.85 },
		buttonBorder = { 0.34, 0.36, 0.42 },
	},
}
