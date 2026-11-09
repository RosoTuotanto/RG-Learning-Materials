local imageFolder = "samples/visual-novel-hidden-object/assets/images/"

local font = {
	heading = "assets/fonts/roboto/Roboto-Bold.ttf",
	body = "assets/fonts/roboto/Roboto-Light.ttf",
}

-- The text box and the clue strip share this rectangle; the strip covers the box during the search.
local bottomPanel = { x = 480, y = 552, width = 780, height = 116, cornerRadius = 10 }

return {
	font = font,

	story = {
		-- Weaver keeps each story in a global named after it, so the name must be unique and a valid Lua identifier.
		name = "RosoNoirHiddenObject",
		source = "samples/visual-novel-hidden-object/data/story.json",
		firstPassage = "Opening",

		-- Played after the last clue's remark; each clue's remark is the passage named after its id.
		closingPassage = "Closing",
	},

	hint = {
		story = "Click or Space to continue",
		search = "Search the office: click anything that doesn't belong",
		y = 626,
		fontSize = 16,
		colour = { 1 },

		-- The solid box behind the hint, and the space between the hint and the box's edges.
		backgroundColour = { 0 },
		padding = 4,
	},

	search = {
		office = imageFolder .. "office_interior_nophone.png",
		clueFolder = imageFolder,

		-- The office and clue images are exported at this many image pixels per drawn pixel and shown one content unit per image pixel.
		exportScale = 2,

		-- Top-left corner of each clue in drawn office pixels; width and height are the image size.
		clues = {
			{ id = "clueMatchbook", x = 57, y = 174, width = 26, height = 34 },
			{ id = "cluePhoto", x = 86, y = 86, width = 40, height = 44 },
			{ id = "clueKey", x = 38, y = 113, width = 32, height = 34 },
			{ id = "clueTicket", x = 292, y = 105, width = 24, height = 38 },
			{ id = "clueCard", x = 138, y = 150, width = 34, height = 22 },
			{ id = "clueBox", x = 168, y = 208, width = 30, height = 34 },
		},

		-- Office areas drawn again over the clues, in drawn office pixels: the wall portrait and the typewriter body.
		covers = {
			{ x = 92, y = 67, width = 25, height = 34 },
			{ x = 146, y = 148, width = 31, height = 11 },
		},

		-- Extra content units around each clue that still count as a click on it.
		hitPadding = 14,

		flightTime = 350,
		transitionTag = "hiddenObjectClue",
	},

	strip = {
		panel = bottomPanel,
		colour = { 0.08, 0.07, 0.07 },

		slotSpacing = 112,
		slotWidth = 92,
		slotHeight = 84,
		slotCornerRadius = 8,
		slotColour = { 0.16, 0.14, 0.14 },
	},

	counter = {
		format = "Clues %d/%d",

		-- Below the Back to Menu button, measured from the actual top-left screen edge.
		x = 12,
		y = 72,
		fontSize = 22,
		colour = { 0.9, 0.67, 0.1 },
	},

	playAgain = {
		label = "Play again",
		x = 480,
		y = 277,
		width = 240,
		height = 56,
		cornerRadius = 11,
		colour = { 0.55, 0.12, 0.1 },
		fontSize = 24,
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
			x = bottomPanel.x,
			y = bottomPanel.y,
			width = bottomPanel.width,
			height = bottomPanel.height,
			cornerRadius = bottomPanel.cornerRadius,
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
