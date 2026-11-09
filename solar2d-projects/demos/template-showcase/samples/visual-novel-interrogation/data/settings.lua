local imageFolder = "samples/visual-novel-interrogation/assets/images/"

local font = {
	heading = "assets/fonts/roboto/Roboto-Bold.ttf",
	body = "assets/fonts/roboto/Roboto-Light.ttf",
}

-- The story player and the evidence panel share these.
local upKeys = { "up", "w" }
local downKeys = { "down", "s" }
local confirmKeys = { "space", "enter", "numPadEnter" }

-- Shared by every button so they match the story player's choice buttons.
local buttonStyle = {
	cornerRadius = 8,
	fontSize = 20,
	colour = { 0.15, 0.13, 0.13, 0.95 },
	selectedColour = { 0.55, 0.12, 0.1, 0.95 },
}

return {
	font = font,
	buttonStyle = buttonStyle,

	story = {
		-- Weaver keeps each story in a global named after it, so the name must be unique and a valid Lua identifier.
		name = "RosoNoirInterrogation",
		source = "samples/visual-novel-interrogation/data/story.json",
		firstPassage = "Opening",
		-- Plays once every statement is broken.
		breakthrough = "Breakthrough",
	},

	-- brokenBy names the clue that breaks the statement; wrong plays for any other clue, broken for that one.
	statements = {
		{ passage = "Statement1", press = "Press1", wrong = "Wrong1", broken = "Broken1", brokenBy = "clueTicket" },
		{ passage = "Statement2", press = "Press2", wrong = "Wrong2", broken = "Broken2", brokenBy = "clueKey" },
		{ passage = "Statement3", press = "Press3", wrong = "Wrong3", broken = "Broken3", brokenBy = "cluePhoto" },
	},

	clues = {
		{
			id = "clueKey",
			name = "Brass key",
			description = "The only key to Vivian Ash's display case, brass with a velvet tassel. Found in a coat pocket in this office.",
			width = 32,
			height = 34,
		},

		{
			id = "cluePhoto",
			name = "Torn photo",
			description = "Vivian Ash on her front steps yesterday. A bank's notice of sale is nailed to her front door.",
			width = 40,
			height = 44,
		},

		{
			id = "clueTicket",
			name = "Pawn ticket",
			description = "Kessler Loans. One red stone, pawned by Mrs. V. Ash yesterday at 9:40 in the morning.",
			width = 24,
			height = 38,
		},
	},

	clueFolder = imageFolder,

	-- The clue shown between the two characters while it is being presented, at this multiple of its size.
	presentedClue = { x = 480, y = 300, scale = 2 },

	keys = {
		previous = { "left", "a" },
		next = { "right", "d" },
		press = { "p" },
		present = { "e" },
	},

	panelKeys = {
		up = upKeys,
		down = downKeys,
		confirm = confirmKeys,
		close = { "escape" },
	},

	hint = {
		story = "Click or Space to continue",
		testimony = "Press a statement to hear more. Present evidence that proves it wrong.",
		y = 626,
		fontSize = 16,
		colour = { 1 },

		-- The solid box behind the hint, and the space between the hint and the box's edges.
		backgroundColour = { 0 },
		padding = 4,
	},

	testimony = {
		-- One button per action, left to right; the action names match the keys table.
		buttons = {
			{ action = "previous", label = "Previous" },
			{ action = "press", label = "Press" },
			{ action = "present", label = "Present", isPrimary = true },
			{ action = "next", label = "Next" },
		},

		y = 462,
		buttonWidth = 150,
		buttonHeight = 44,
		gap = 12,

		-- Statement number in the text box's top-right corner.
		counterFormat = "%d / %d",
		counterX = 846,
		counterY = 506,
		counterSize = 18,
		counterColour = { 0.6 },
	},

	-- One mark per statement, filled when that statement is broken.
	contradictions = {
		label = "Contradictions",

		-- Under the Back to Menu button, measured from the actual top-left screen edge.
		x = 14,
		labelY = 72,
		labelSize = 16,
		markY = 100,
		radius = 10,
		spacing = 28,
		foundColour = { 0.75, 0.14, 0.11 },
		openColour = { 0.22 },
		strokeColour = { 0.85, 0.75, 0.6 },
		strokeWidth = 2,

		-- A newly filled mark shrinks from this scale back to its size.
		popScale = 1.8,
		popTime = 300,
		transitionTag = "interrogationMarks",
	},

	evidencePanel = {
		title = "Evidence",
		backdropColour = { 0, 0.6 },
		x = 480,
		-- Ends above the testimony buttons, so a second click on Present cannot land on a row.
		y = 252,
		width = 640,
		height = 360,
		cornerRadius = 12,
		fillColour = { 0.08, 0.07, 0.07, 0.96 },
		titleOffset = 30,
		titleSize = 28,
		titleColour = { 0.9, 0.67, 0.1 },

		-- Rows stack downward from the first row's centre, measured from the panel's top edge.
		firstRowOffset = 108,
		rowSpacing = 94,
		rowWidth = 600,
		rowHeight = 86,
		spriteOffset = -260,
		nameOffset = -220,
		nameSize = 20,

		-- The name sits this far above the row's centre; the description starts this far below it and wraps at descriptionWidth.
		nameY = -24,
		descriptionY = -8,
		descriptionWidth = 490,
		descriptionSize = 16,
		descriptionColour = { 0.8 },

		-- The Close button sits at the title's height, this far in from the panel's right edge.
		closeLabel = "Close",
		closeWidth = 90,
		closeHeight = 32,
		closeInset = 16,
	},

	endButton = {
		label = "Play again",
		x = 480,
		y = 462,
		width = 240,
		height = 56,
		fontSize = 24,
	},

	player = {
		font = font,

		keys = {
			confirm = confirmKeys,
			up = upKeys,
			down = downKeys,
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
			cornerRadius = buttonStyle.cornerRadius,
			fontSize = 22,
			fillColour = buttonStyle.colour,
			selectedColour = buttonStyle.selectedColour,
		},
	},
}
