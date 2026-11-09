local imageFolder = "samples/visual-novel-city-map/assets/images/"

local font = {
	heading = "assets/fonts/roboto/Roboto-Bold.ttf",
	body = "assets/fonts/roboto/Roboto-Light.ttf",
}

local buttonStyle = {
	cornerRadius = 8,
	fontSize = 20,
	colour = { 0.15, 0.13, 0.13, 0.95 },
	selectedColour = { 0.55, 0.12, 0.1, 0.95 },
}

local time = {
	-- Hours on a 24-hour clock; reaching the end hour sends the detective back to the office for the ending.
	startHour = 9,
	endHour = 21,
	travelHours = 1,
	talkHours = 2,

	startLocation = "office",
	endLocation = "office",

	-- Each band lasts from its own hour until the next band starts; the story branches on the id.
	bands = {
		{ id = "morning", label = "Morning", from = 9 },
		{ id = "afternoon", label = "Afternoon", from = 12 },
		{ id = "evening", label = "Evening", from = 17 },
	},
}

return {
	font = font,
	buttonStyle = buttonStyle,
	time = time,

	story = {
		-- Weaver keeps each story in a global named after it, so the name must be unique and a valid Lua identifier.
		name = "RosoNoirCityMap",
		source = "samples/visual-novel-city-map/data/story.json",
		firstPassage = "Opening",
		endingPassage = "Ending",
	},

	clock = {
		format = "%d:00 %s",

		-- Distance from the actual top screen edge to the clock's middle; it must stay inside the strip above the map.
		y = 22,
		fontSize = 22,
		colour = { 0.9, 0.67, 0.1 },
	},

	hint = {
		story = "Click or Space to continue",
		map = string.format( "Click a place to go there. Hours per trip: %d, per talk: %d", time.travelHours, time.talkHours ),
		y = 626,
		fontSize = 16,
		colour = { 1 },

		-- The solid box behind the hint, and the space between the hint and the box's edges.
		backgroundColour = { 0 },
		padding = 4,
	},

	playAgain = {
		label = "Play again",
		x = 480,
		y = 277,
		width = 240,
		height = 56,
		fontSize = 24,
	},

	map = {
		image = imageFolder .. "city_map.png",

		-- Spot positions and radii are in the map image's own pixels; the map is scaled to fill the background area.
		pixelWidth = 710,
		clickRadius = 22,

		markerRadius = 29,
		markerStrokeWidth = 4,
		markerColour = { 0.75, 0.1, 0.1 },

		-- Space between a spot's click circle and its label.
		labelGap = 8,
		labelPadding = 6,
		labelFontSize = 18,
		labelColour = { 0.95, 0.92, 0.85 },
		labelBackColour = { 0.08, 0.07, 0.07, 0.85 },
		labelCornerRadius = 4,

		-- Idea: add a spot that only appears once a flag is set, such as Kessler Loans after the pawn ticket.
		spots = {
			{ id = "office", label = "Office", passage = "Office", x = 200, y = 378, labelSide = "left" },
			{ id = "street", label = "Street", passage = "Street", x = 200, y = 280, labelSide = "left" },
			{ id = "bar", label = "Bar", passage = "Bar", x = 424, y = 390, labelSide = "right" },
			{ id = "precinct", label = "Precinct", passage = "Precinct", x = 602, y = 138, labelSide = "left" },
		},
	},

	player = {
		font = font,

		keys = {
			confirm = { "space", "enter", "numPadEnter" },
			up = { "up", "w" },
			down = { "down", "s" },
		},

		-- Every background and the map are drawn at this rectangle; characters stand on its bottom edge.
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
