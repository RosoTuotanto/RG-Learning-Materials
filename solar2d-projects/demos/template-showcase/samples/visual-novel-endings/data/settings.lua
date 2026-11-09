local imageFolder = "samples/visual-novel-endings/assets/images/"

local font = {
	heading = "assets/fonts/roboto/Roboto-Bold.ttf",
	body = "assets/fonts/roboto/Roboto-Light.ttf",
}

return {
	font = font,

	story = {
		-- Weaver keeps each story in a global named after it, so the name must be unique and a valid Lua identifier.
		name = "RosoNoirEndings",
		source = "samples/visual-novel-endings/data/story.json",
		firstPassage = "Opening",
	},

	-- Found endings are stored in this file in the documents directory.
	saveFile = "visualNovelEndings.json",

	hint = {
		text = "Click or Space to continue",
		y = 626,
		fontSize = 16,
		colour = { 1 },

		-- The solid box behind the hint, and the space between the hint and the box's edges.
		backgroundColour = { 0 },
		padding = 4,
	},

	endings = {
		{ id = "pawnTicket", title = "The Pawn Ticket" },
		{ id = "paidInFull", title = "Paid in Full" },
		{ id = "closedByNine", title = "Closed by Nine" },
	},

	endingsScreen = {
		backdropColour = { 0.05, 0.04, 0.04, 0.96 },

		title = "Endings",
		titleY = 160,
		titleSize = 40,

		unknownTitle = "???",
		listY = 250,
		rowSpacing = 52,
		rowSize = 28,
		foundColour = { 0.9, 0.67, 0.1 },
		unknownColour = { 0.45 },

		playAgain = "Play again",
		buttonY = 470,
		buttonWidth = 240,
		buttonHeight = 56,
		buttonCornerRadius = 11,
		buttonColour = { 0.55, 0.12, 0.1 },
		buttonTextSize = 24,
	},

	player = {
		font = font,

		keys = {
			confirm = { "space", "enter", "numPadEnter" },
			up = { "up", "w" },
			down = { "down", "s" },
		},

		-- Every background is drawn at this rectangle; characters stand on its bottom edge.
		background = { x = 480, y = 277, width = 710, height = 466 },

		characterFolder = imageFolder,
		characterWidth = 736,
		characterHeight = 1024,
		characterScale = 0.35,

		textBox = {
			x = 480,
			y = 552,
			width = 780,
			height = 116,
			cornerRadius = 10,
			fillColour = { 0.08, 0.07, 0.07, 0.92 },
			padding = 24,
			speakerSize = 20,
			speakerColour = { 0.9, 0.67, 0.1 },
			bodySize = 22,

			-- Distance from the box's top edge to the first line of the spoken text.
			bodyOffset = 40,
		},

		choices = {
			-- Choice buttons stack downward from here, centred on the background.
			x = 480,
			y = 220,
			width = 420,
			height = 50,
			gap = 14,
			cornerRadius = 8,
			fontSize = 22,
			fillColour = { 0.15, 0.13, 0.13, 0.95 },
			selectedColour = { 0.55, 0.12, 0.1, 0.95 },
		},
	},
}
