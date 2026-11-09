-- Coordinates are in the 960x640 landscape content area (config.lua authors it as 640x960).

return {
	font = {
		heading = "assets/fonts/roboto/Roboto-Bold.ttf",
		body = "assets/fonts/roboto/Roboto-Light.ttf",
	},

	-- Used both when the menu opens a sample and when the back button returns to the menu.
	sceneTransition = {
		effect = "fade",
		time = 200,
	},

	-- Top edge of the heading.
	heading = {
		y = 32,
		size = 30,
	},

	-- Top edge of the paragraph, which wraps to three lines at this width.
	paragraph = {
		y = 80,
		size = 18,
		width = 820,
	},

	-- The last button's bottom edge must stay above the menu's disclaimer box at the 960x640 content size.
	columns = {
		x = { 200, 480, 760 },
		titleY = 196,
		titleSize = 24,

		-- Centre of each column's first button, and the distance between button centres.
		firstButtonY = 246,
		buttonSpacing = 54,
	},

	button = {
		width = 240,
		height = 44,
		fontSize = 20,
		cornerRadius = 8,
		strokeWidth = 2,
	},

	-- The menu's disclaimer box, centred at the bottom of the actual screen.
	disclaimer = {
		-- Distance from the actual bottom screen edge to the box.
		margin = 12,

		size = 18,
		linePitch = 23,
		padding = 11,
	},

	overlay = {
		-- Distance from the actual screen edges to the back button.
		margin = 12,

		backWidth = 160,
		backHeight = 44,
		backFontSize = 18,
	},

	loading = {
		size = 28,

		-- enterFrame events the loading screen waits through before it opens the sample.
		waitFrames = 2,
	},

	palette = {
		background = { 0.09, 0.10, 0.12 },

		text = { 0.94, 0.95, 0.97 },
		textMuted = { 0.68, 0.71, 0.76 },

		buttonFill = { 0.16, 0.17, 0.21 },
		buttonActiveFill = { 0.30, 0.55, 0.85 },
		buttonBorder = { 0.34, 0.36, 0.42 },

		disclaimerFill = 0,
	},
}
