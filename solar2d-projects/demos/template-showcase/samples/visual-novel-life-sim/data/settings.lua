local imageFolder = "samples/visual-novel-life-sim/assets/images/"

local font = {
	heading = "assets/fonts/roboto/Roboto-Bold.ttf",
	body = "assets/fonts/roboto/Roboto-Light.ttf",
}

local accentColour = { 0.9, 0.67, 0.1 }

-- Text colours of a gain and a loss, in option previews and beside the stat bars.
local gainColour = { 0.55, 0.9, 0.45 }
local lossColour = { 1, 0.55, 0.5 }

local keys = {
	confirm = { "space", "enter", "numPadEnter" },
	up = { "up", "w" },
	down = { "down", "s" },
	close = { "escape" },
}

local buttonStyle = {
	cornerRadius = 8,
	fontSize = 20,
	colour = { 0.15, 0.13, 0.13, 0.95 },
	selectedColour = { 0.55, 0.12, 0.1, 0.95 },
}

return {
	font = font,
	buttonStyle = buttonStyle,
	imageFolder = imageFolder,

	story = {
		-- Weaver keeps each story in a global named after it, so the name must be unique and a valid Lua identifier.
		name = "RosoNoirLifeSim",
		source = "samples/visual-novel-life-sim/data/story.json",
		firstPassage = "Opening",
		dayPassage = "Day",
		dayEndPassage = "DayEnd",
		paidEnding = "RentPaid",
		missedEnding = "RentMissed",
		wornOutEnding = "RentPaidWornOut",
	},

	calendar = {
		days = 7,
		actionsPerDay = 2,

		-- Money needed after the last day, and the Health the detective must stay above.
		rent = 80,
		healthFloor = 30,
	},

	-- Stats run from 0 to 100; ids match the <<stat, id, amount>> commands in the story.
	stats = {
		{ id = "money", icon = "iconMoney.png", start = 20 },
		{ id = "health", icon = "iconHealth.png", start = 70 },
		{ id = "happiness", icon = "iconHappiness.png", start = 40 },
		{ id = "social", icon = "iconSocial.png", start = 30 },
	},

	statRange = { min = 0, max = 100 },

	-- Relationships run from -100 to 100; image is the portrait file without ".png", shortName is used in option previews.
	relationships = {
		{ id = "secretary", name = "Secretary", shortName = "Secretary", image = "secretary", start = 30 },
		{ id = "briggs", name = "Commissioner Briggs", shortName = "Briggs", image = "commissioner", start = 0 },
		{ id = "jimmy", name = "Slippin' Jimmy", shortName = "Jimmy", image = "jimmy", start = 10 },
		{ id = "mae", name = "Mae", shortName = "Mae", image = "mae", start = 20 },
		{ id = "vivian", name = "Vivian Ash", shortName = "Vivian", image = "vivian", start = 0 },
	},

	relationRange = { min = -100, max = 100 },

	-- Each action opens its passage; labels are the button texts.
	actions = {
		{ label = "Take a case", passage = "TakeCase" },
		{ label = "Go to Mae's", passage = "GoToMaes" },
		{ label = "Rest", passage = "Rest" },
		{ label = "Visit the precinct", passage = "Precinct" },
		{ label = "Call on Vivian or Jimmy", passage = "CallOn" },
	},

	keys = keys,

	hint = {
		story = "Click or Space to continue",
		actions = "Pick two things to do today",
		lastAction = "Pick one more",
		y = 626,
		fontSize = 16,
		colour = { 1 },

		-- The solid box behind the hint, and the space between the hint and the box's edges.
		backgroundColour = { 0 },
		padding = 4,
	},

	hud = {
		-- Below the Back to Menu button, measured from the actual top-left screen edge.
		x = 12,
		y = 72,
		width = 244,
		height = 232,
		padding = 12,
		cornerRadius = 10,
		fillColour = { 0.08, 0.07, 0.07, 0.92 },

		dayFormat = "Day %d of %d",
		dayFontSize = 20,
		dayColour = accentColour,

		firstRowOffset = 56,
		rowSpacing = 34,
		iconSize = 32,
		barOffset = 40,
		barWidth = 112,
		barHeight = 12,
		trackColour = { 0.25, 0.22, 0.22 },
		barColour = accentColour,

		-- From the bar's right end: the value's right edge, and the left edge of the last choice's change.
		valueOffset = 36,
		changeOffset = 42,
		valueFontSize = 16,
		gainColour = gainColour,
		lossColour = lossColour,

		-- Milliseconds a bar takes to slide to its new value.
		barTime = 400,
		transitionTag = "lifeSimBars",

		buttonLabel = "Relationships",
		buttonOffset = 202,
		buttonHeight = 36,
		buttonFontSize = 16,
	},

	-- The row of changes drawn under an option's label, centred on the button.
	effectPreview = {
		labelOffset = -11,
		rowOffset = 16,
		fontSize = 16,
		iconSize = 18,

		-- Space after an icon or a name, and between two changes.
		iconGap = 4,
		itemGap = 16,

		gainColour = gainColour,
		lossColour = lossColour,
	},

	actionMenu = {
		x = 480,
		firstY = 150,
		width = 360,
		height = 50,
		gap = 12,
		fontSize = 22,

		-- Alpha of an action already used today.
		usedAlpha = 0.35,
	},

	relationshipsPanel = {
		backdropColour = { 0, 0.6 },
		x = 480,
		y = 320,
		width = 520,
		height = 440,
		cornerRadius = 12,
		fillColour = { 0.08, 0.07, 0.07, 0.96 },

		title = "Relationships",
		titleOffset = 36,
		titleSize = 26,
		titleColour = accentColour,

		-- The Close button sits at the title's height, this far in from the panel's right edge.
		closeLabel = "Close",
		closeWidth = 90,
		closeHeight = 32,
		closeInset = 16,
		closeFontSize = 18,

		firstRowOffset = 100,
		rowSpacing = 70,
		nameSize = 20,
		valueSize = 22,

		-- Head-and-shoulders rectangle cut from every 736x1024 portrait.
		crop = { x = 168, y = 64, width = 416, height = 416 },
		portraitSize = 64,
		portraitOffset = 56,
		textOffset = 104,
		valueInset = 32,

		-- The bar grows right from its centre for a positive value and left for a negative one.
		barWidth = 220,
		barHeight = 10,
		barOffset = 16,
		trackColour = { 0.25, 0.22, 0.22 },
		positiveColour = accentColour,
		negativeColour = { 0.75, 0.2, 0.18 },
	},

	playAgain = {
		label = "Play again",
		x = 480,
		y = 277,
		width = 240,
		height = 56,
		fontSize = 24,
	},

	player = {
		font = font,

		keys = keys,

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
			speakerColour = accentColour,
			bodySize = 22,

			-- Distance from the box's top edge to the first line of the spoken text.
			bodyOffset = 40,
		},

		choices = {
			-- Choice buttons stack downward from here, centred on the background.
			x = 480,
			y = 220,
			width = 420,
			height = 64,
			gap = 14,
			cornerRadius = 8,
			fontSize = 22,
			fillColour = { 0.15, 0.13, 0.13, 0.95 },
			selectedColour = { 0.55, 0.12, 0.1, 0.95 },
		},
	},
}
