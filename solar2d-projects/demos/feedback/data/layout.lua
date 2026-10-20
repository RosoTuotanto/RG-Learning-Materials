-- Positions, sizes, fonts and colours for everything on screen.
-- The content area is authored as 640x960 in config.lua, which the engine swaps
-- to 960x640 for this landscape build, so every coordinate below is in that space.

return {
	font = {
		heading = "assets/fonts/roboto/Roboto-Bold.ttf",
		body = "assets/fonts/roboto/Roboto-Light.ttf",
	},

	-- The line both fighters stand on, and that ejected casings bounce off.
	floorY = 404,
	floorHeight = 6,

	fighter = {
		-- Distance between the two fighters is what the bullet has to cross.
		oneX = 250,
		twoX = 710,

		bodyWidth = 100,
		bodyHeight = 116,

		-- The gun is an L: a barrel pointing at the opponent and a grip hanging down at
		-- the back. The back of it sits inside the body so the two read as one figure
		-- rather than as a box with a stick next to it.
		gunBarrelLength = 58,
		gunBarrelThickness = 16,
		gunGripWidth = 16,
		gunGripDrop = 26,
		gunOverlap = 20,
		-- Vertical offset of the barrel from the middle of the body.
		gunOffsetY = -6,

		healthY = 250,
		healthWidth = 190,
		healthHeight = 22,
		healthGap = 5,
	},

	bullet = {
		width = 22,
		height = 8,
	},

	caption = {
		titleY = 54,
		-- The top of the caption block rather than its middle, so a caption that wraps
		-- to two lines starts at the same height as one that does not.
		textY = 82,
		titleSize = 32,
		textSize = 22,
		-- Captions wrap inside this width so they stay clear of the screen edges.
		width = 820,
	},

	ui = {
		-- Both rows are placed relative to the bottom of the visible screen, so a
		-- taller-than-expected viewport keeps them on screen instead of off it.
		bottomMargin = 46,
		-- Sized so the slider and its hint sit centred in the band between the floor
		-- line and the top of the version buttons.
		rowGap = 106,

		buttonHeight = 68,
		buttonGap = 12,

		versionWidth = 84,
		versionSize = 34,

		cornerRadius = 8,

		-- The two corner buttons, reset on the left and language on the right, clear of
		-- the centred caption. Both are square and identical so the pair reads as one row.
		-- Neither carries text: Roboto has no circular-arrow glyph, and a flag says which
		-- language is showing faster than a two-letter code does.
		corner = {
			size = 52,
			marginX = 24,
			marginY = 22,

			-- The restart arrow, drawn rather than typed.
			iconRadius = 15,
			iconStroke = 4,
			iconHead = 11,
			-- Degrees of the circle the arrow covers, and where the opening it leaves is
			-- centred. Zero points right and the angle grows clockwise, so the default
			-- puts the gap low on the right with the head coming down into it.
			iconSweep = 280,
			iconGapAngle = 30,

			flagWidth = 40,
			flagBorder = 2,
			-- Height as a fraction of width, from each flag's own official proportions:
			-- 11:18 for Finland and 1:2 for the Union Jack. They are different shapes and
			-- are not forced to match.
			flagRatio = {
				fi = 11 / 18,
				en = 1 / 2,
			},
		},

		-- The volume slider sits where the version buttons' second row used to be. The
		-- track stays centred whatever the language, so switching language does not
		-- move the thing the pointer is on.
		slider = {
			width = 300,
			trackHeight = 10,
			knobWidth = 22,
			knobHeight = 38,
			labelGap = 22,
			valueGap = 18,
			labelSize = 22,
			hintSize = 18,
			hintOffsetY = 36,
		},
	},

	palette = {
		background = { 0.09, 0.10, 0.12 },
		floor = { 0.22, 0.24, 0.28 },

		fighterOne = { 0.36, 0.62, 0.90 },
		fighterTwo = { 0.92, 0.52, 0.30 },

		gun = { 0.75, 0.78, 0.84 },
		bullet = { 1, 0.93, 0.65 },
		muzzleFlash = { 1, 0.85, 0.35 },
		casing = { 0.85, 0.72, 0.35 },

		healthEmpty = { 0.20, 0.21, 0.24 },

		text = { 0.94, 0.95, 0.97 },
		textMuted = { 0.68, 0.71, 0.76 },

		buttonFill = { 0.16, 0.17, 0.21 },
		buttonActiveFill = { 0.30, 0.55, 0.85 },
		buttonBorder = { 0.34, 0.36, 0.42 },

		sliderTrack = { 0.20, 0.21, 0.25 },
		sliderFill = { 0.30, 0.55, 0.85 },
		sliderKnob = { 0.86, 0.88, 0.92 },
	},
}
