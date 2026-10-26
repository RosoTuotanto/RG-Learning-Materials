-- Positions, sizes, fonts and colours, in the 960x640 landscape space that config.lua's 640x960 becomes.

return {
	font = {
		heading = "assets/fonts/roboto/Roboto-Bold.ttf",
		body = "assets/fonts/roboto/Roboto-Light.ttf",
	},

	caption = {
		titleY = 54,
		-- The top of the caption block, so captions of any length start at the same height.
		textY = 82,
		titleSize = 32,
		textSize = 22,
		-- Captions wrap inside this width to stay clear of the screen edges and the language button.
		width = 760,
	},

	instruction = {
		-- Distance from the top of the version buttons up to the middle of the line, which keeps it
		-- below version 9's fully grown circle.
		gap = 36,
		size = 22,
	},

	ui = {
		-- Distance from the bottom of the content area to the bottom of the version buttons.
		bottomMargin = 46,

		buttonWidth = 200,
		buttonHeight = 68,
		buttonGap = 16,
		labelSize = 28,
		cornerRadius = 8,
		strokeWidth = 2,

		-- The language button in the top right corner.
		corner = {
			size = 52,
			marginX = 24,
			marginY = 22,

			flagWidth = 40,
			flagBorder = 2,
			-- Height as a fraction of width, from each flag's official proportions.
			flagRatio = {
				fi = 11 / 18,
				en = 1 / 2,
			},
		},
	},

	palette = {
		background = { 0.09, 0.10, 0.12 },

		text = { 0.94, 0.95, 0.97 },
		textMuted = { 0.68, 0.71, 0.76 },

		buttonFill = { 0.16, 0.17, 0.21 },
		buttonActiveFill = { 0.30, 0.55, 0.85 },
		buttonBorder = { 0.34, 0.36, 0.42 },
	},
}
