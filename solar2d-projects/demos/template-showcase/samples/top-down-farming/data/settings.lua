local imageFolder = "samples/top-down-farming/assets/images/"
local audioFolder = "samples/top-down-farming/assets/audio/"

return {
	map = { folder = "samples/top-down-farming/assets", file = "level.json" },

	font = {
		heading = "assets/fonts/roboto/Roboto-Bold.ttf",
		body = "assets/fonts/roboto/Roboto-Light.ttf",
	},

	-- Every key name that triggers each action.
	keys = {
		up = { "w", "up" },
		down = { "s", "down" },
		left = { "a", "left" },
		right = { "d", "right" },
		use = { "space", "e" },

		tool1 = { "1" },
		tool2 = { "2" },
		tool3 = { "3" },
		tool4 = { "4" },
	},

	-- Tool bar slots from left to right; action is the key binding that selects the slot.
	tools = {
		{ name = "hoe", action = "tool1", image = imageFolder .. "toolHoe.png" },
		{ name = "seeds", action = "tool2", image = imageFolder .. "toolSeeds.png" },
		{ name = "water", action = "tool3", image = imageFolder .. "toolWater.png" },
		{ name = "hand", action = "tool4", image = imageFolder .. "toolHand.png" },
	},

	player = {
		image = imageFolder .. "hero.png",
		size = 32,

		-- Collision circle radius in content units.
		bodyRadius = 12,

		-- Content units per second.
		speed = 160,

		-- Facing at the start, as a tile step; down looks at the tile below the hero.
		startFacingX = 0,
		startFacingY = 1,
	},

	field = {
		soilImage = imageFolder .. "soil.png",

		-- One image per growth stage; the crop is ripe at the last one.
		cropImages = {
			imageFolder .. "crop1.png",
			imageFolder .. "crop2.png",
			imageFolder .. "crop3.png",
		},

		-- The faint outline around the tiles the hoe can till.
		edgeWidth = 2,
	},

	-- Outline around the tile in front of the hero.
	target = {
		strokeWidth = 2,

		-- Distance the outline sits inside the tile edges.
		inset = 2,
	},

	sleep = {
		-- Milliseconds to fade to black, to stay black, and to fade back.
		fadeOutTime = 400,
		darkTime = 300,
		fadeInTime = 400,
	},

	hud = {
		-- Distance from the top of the content area to the top of the farm.
		worldY = 72,

		-- Distance from the actual screen edges to the app's back button, and its height.
		margin = 12,
		backHeight = 44,

		-- Space between the back button and the day count below it.
		gap = 10,

		labelSize = 20,
		lineSpacing = 28,

		-- Centre heights of the two hint lines, and the space between them and the edges of their background.
		hintY = 512,
		goalY = 535,
		hintSize = 18,
		hintPadding = 6,
	},

	toolBar = {
		-- Centre height of the slots.
		y = 594,

		slotSize = 52,
		gap = 10,
		iconSize = 32,
		cornerRadius = 8,
		strokeWidth = 2,
		selectedStrokeWidth = 3,

		-- The key number in each slot's top-left corner.
		numberSize = 12,
		numberInset = 8,
	},

	sounds = {
		dig = audioFolder .. "dig.wav",
		water = audioFolder .. "water.wav",
		harvest = audioFolder .. "harvest.wav",
	},

	-- The sound each tool result plays; planting is shown by the sprout alone.
	toolSounds = {
		till = "dig",
		water = "water",
		harvest = "harvest",
	},

	volumeSlider = {
		label = "Volume",
		labelSize = 18,
		labelGap = 10,

		-- Distance from the actual screen edges to the panel, and the space between the panel's edges and its contents.
		margin = 12,
		padding = 8,

		width = 120,
		trackHeight = 6,
		knobWidth = 14,
		knobHeight = 26,
		knobCornerRadius = 4,

		colors = {
			background = { 0.16, 0.17, 0.21 },
			label = { 1 },
			track = { 1, 0.35 },
			fill = { 1 },
			knob = { 0.75 },
		},
	},

	colors = {
		text = { 0.94, 0.95, 0.97 },
		textMuted = { 0.68, 0.71, 0.76 },
		hintBackground = { 0 },
		hintText = { 1 },

		buttonFill = { 0.16, 0.17, 0.21 },
		buttonBorder = { 0.34, 0.36, 0.42 },
		selected = { 1, 0.82, 0.3 },

		target = { 1, 0.95, 0.6, 0.9 },
		fieldEdge = { 0.35, 0.22, 0.1, 0.35 },

		-- Multiplies the soil image, so watered soil reads darker.
		wateredSoil = { 0.55, 0.45, 0.45 },

		sleep = { 0 },
	},

	text = {
		hint = "WASD or arrows to move, 1-4 to pick a tool, Space to use it",
		goal = "Grow and harvest crops; sleep in the bed to end the day",

		-- string.format patterns for the HUD counts.
		day = "Day %d",
		harvest = "Harvested: %d",
	},
}
