local imageFolder = "samples/visual-novel-deduction/assets/images/"

local font = {
	heading = "assets/fonts/roboto/Roboto-Bold.ttf",
	body = "assets/fonts/roboto/Roboto-Light.ttf",
}

return {
	font = font,

	story = {
		-- Weaver keeps each story in a global named after it, so the name must be unique and a valid Lua identifier.
		name = "RosoNoirDeduction",
		source = "samples/visual-novel-deduction/data/story.json",
		firstPassage = "Opening",

		-- The passage each accusation result plays.
		verdictPassages = {
			right = "VerdictRight",
			partlyRight = "VerdictPartlyRight",
			wrong = "VerdictWrong",
		},
	},

	case = {
		-- Linking this clue to its suspect turns a wrong accusation into a partly right one.
		keyClue = "clueTicket",

		-- The suspect each clue belongs to.
		solution = {
			clueTicket = "vivian",
			cluePhoto = "vivian",
			clueKey = "vivian",
			clueCard = "jimmy",
			clueBox = "jimmy",
			clueMatchbook = "mae",
		},
	},

	hint = {
		story = "Click or Space to continue",
		board = "Drag a clue to a suspect, then accuse",
		y = 626,
		fontSize = 16,
		colour = { 1 },

		-- The solid box behind the hint, and the space between the hint and the box's edges.
		backgroundColour = { 0 },
		padding = 4,
	},

	counter = {
		format = "Links %d/%d",

		-- Below the Back to Menu button, measured from the actual top-left screen edge.
		x = 12,
		y = 72,
		fontSize = 22,
		colour = { 0.9, 0.67, 0.1 },
	},

	buttonStyle = {
		colour = { 0.55, 0.12, 0.1 },
		cornerRadius = 10,
		fontSize = 24,
	},

	accuse = {
		label = "Accuse",

		-- Sits in the empty text box while the board is open.
		x = 480,
		y = 552,
		width = 200,
		height = 52,
	},

	playAgain = {
		label = "Play again",
		x = 480,
		y = 277,
		width = 240,
		height = 56,
	},

	board = {
		imageFolder = imageFolder,
		font = font.heading,

		paperColour = { 0.88 },
		inkColour = { 0.15 },
		shadowColour = { 0, 0.4 },
		shadowOffset = 3,

		pinRadius = 4,
		pinColour = { 0.8, 0.12, 0.1 },

		stringWidth = 3,
		stringColour = { 0.75, 0.1, 0.1, 0.9 },

		-- Offsets are from the card's centre; the pin is where a string attaches.
		suspectCard = {
			width = 124,
			height = 146,
			photoY = -9,
			photoSize = 104,
			nameY = 58,
			nameSize = 15,
			pinY = -67,
		},

		-- Head-and-shoulders crop; keep it a whole multiple of photoSize so the pixels stay sharp.
		crop = { x = 168, y = 64, width = 416, height = 416 },

		clueCard = {
			width = 108,
			height = 92,
			spriteY = -6,
			nameY = 31,
			nameSize = 14,
			pinY = -38,
		},

		-- Card centres on the cork, which spans x 159 to 805 and y 74 to 456.
		suspects = {
			{ id = "vivian", name = "Vivian Ash", x = 302, y = 157 },
			{ id = "jimmy", name = "Slippin' Jimmy", x = 482, y = 157 },
			{ id = "mae", name = "Mae", x = 662, y = 157 },
		},

		-- Width and height are the clue image size.
		clues = {
			{ id = "clueMatchbook", name = "Matchbook", width = 26, height = 34, x = 262, y = 290 },
			{ id = "cluePhoto", name = "Torn photo", width = 40, height = 44, x = 482, y = 290 },
			{ id = "clueCard", name = "Business card", width = 34, height = 22, x = 702, y = 290 },
			{ id = "clueKey", name = "Brass key", width = 32, height = 34, x = 262, y = 394 },
			{ id = "clueBox", name = "Velvet box", width = 30, height = 34, x = 482, y = 394 },
			{ id = "clueTicket", name = "Pawn ticket", width = 24, height = 38, x = 702, y = 394 },
		},
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
