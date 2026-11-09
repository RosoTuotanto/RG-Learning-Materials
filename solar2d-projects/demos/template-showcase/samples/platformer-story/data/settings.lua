local imageFolder = "samples/platformer-story/assets/images/"

local tileSize = 36
local characterSize = 48

return {
	font = {
		heading = "assets/fonts/roboto/Roboto-Bold.ttf",
		body = "assets/fonts/roboto/Roboto-Light.ttf",
	},

	-- Up both jumps and talks; near a villager it only opens the dialogue.
	keys = {
		left = { "a", "left" },
		right = { "d", "right" },
		jump = { "space", "w", "up" },
		talk = { "e", "up" },
		choiceUp = { "up" },
		choiceDown = { "down" },
		confirm = { "enter", "e" },
	},

	-- Every timer and transition carries this tag, so a restart or leaving the scene cancels them together.
	tag = "platformerStory",

	-- Downward pull in metres per second squared; Box2D counts 30 content units per metre.
	gravity = 30,

	-- How far below the level's bottom edge the player falls before landing back on the respawn spot.
	fallMargin = 100,

	-- Milliseconds the closing line stays on screen before the village starts over.
	completeDelay = 3000,

	-- The Tiled map, and the folder its tileset image path is relative to.
	map = { folder = "samples/platformer-story/assets", file = "level.json" },

	-- Each sheet is drawn at displaySize content units per frame.
	sheets = {
		tiles = { path = imageFolder .. "tilemap.png", displaySize = tileSize, columns = 8, rows = 8 },
		characters = { path = imageFolder .. "characters.png", displaySize = characterSize, columns = 5, rows = 2 },
	},

	story = {
		name = "RosoVillage",
		source = "samples/platformer-story/data/story.json",
	},

	-- name is also the name of the villager's object in the map, and passage the story passage talking to them opens.
	-- artFacing is the way the unmirrored art faces and direction the way the villager faces when not talking: 1 right, -1 left.
	villagers = {
		{ name = "Tilda", passage = "Tilda", image = imageFolder .. "npcBaker.png", artFacing = 1, direction = -1 },
		{ name = "Pip", passage = "Pip", image = imageFolder .. "npcKid.png", artFacing = 1, direction = -1 },
		{ name = "Bram", passage = "Bram", image = imageFolder .. "npcElder.png", artFacing = 1, direction = -1 },
	},

	talk = {
		-- How close the player has to stand, sideways and up or down, for the Talk prompt to appear.
		reachX = 64,
		reachY = 30,

		-- Gap between a villager's head and the prompt's centre.
		promptOffset = 18,

		promptSize = 18,
		promptPaddingX = 10,
		promptHeight = 26,
		promptCornerRadius = 6,
	},

	bridge = {
		image = imageFolder .. "bridge.png",

		-- Degrees the deck stands turned up around its far-bank end before it is lowered.
		raisedRotation = 90,

		-- Milliseconds the deck takes to swing down, and the easing it lands with.
		lowerTime = 1400,
		easing = "outBounce",

		-- The lowered deck's surface: the ground's friction and no bounce, so landing on it never lifts the player.
		surface = { friction = 0.3, bounce = 0 },
	},

	player = {
		sequence = { name = "run", frames = { 1, 2 }, time = 250 },

		-- Which way the unmirrored art faces, and which way the player faces at the start: 1 right, -1 left.
		artFacing = -1,
		startDirection = 1,

		-- Content units per second.
		runSpeed = 220,

		density = 1,

		-- Upward impulse of a jump; a full jump must not clear the river.
		jumpImpulse = 26,

		-- Share of the upward speed kept when jump is let go early.
		jumpCut = 0.4,

		-- The collision shape; offsetY moves it down so its bottom meets the sprite's feet.
		body = { width = 32, height = 44, offsetY = 2, chamfer = 4 },

		-- The sensor along the bottom edge that tells whether the player stands on something.
		foot = { width = 26, height = 6 },
	},

	flag = {
		sequence = { name = "wave", frames = { 7, 15 }, time = 500 },
	},

	camera = {
		-- How far the player may move either way from the screen centre before the camera follows.
		padding = 40,

		-- Higher values make the camera trail the player more.
		smoothing = 0.1,
	},

	dialogue = {
		width = 760,
		height = 170,

		-- Distance from the actual bottom edge to the box's bottom edge; the box stays below the characters' feet.
		bottomMargin = 10,

		padding = 20,
		cornerRadius = 10,

		nameSize = 22,
		textSize = 22,

		-- Distance from the box's top edge to the top of the passage text.
		textOffset = 46,

		-- Distance from the box's top edge to the first choice's centre, and the rows below it.
		choicesOffset = 98,
		choiceHeight = 32,
		choiceGap = 6,
		choiceSize = 20,
		choiceCornerRadius = 6,
	},

	hud = {
		-- Distance from the actual bottom edge to the centre of the lower hint line, and the gap up to the goal line.
		hintOffset = 24,
		hintLineGap = 26,
		hintSize = 18,

		-- Space between the hint lines and the edges of their background.
		hintPadding = 6,

		messageSize = 44,
	},

	colors = {
		sky = { 0.62, 0.83, 0.95 },
		water = { 0.25, 0.55, 0.85 },
		text = { 0.12, 0.13, 0.18 },
		prompt = { 0.12, 0.13, 0.18, 0.85 },
		hintBackground = { 0 },
		hintText = { 1 },
		panel = { 0.12, 0.13, 0.18, 0.92 },
		speaker = { 1, 0.78, 0.35 },
		choice = { 1, 0.12 },
		choiceSelected = { 0.85, 0.45, 0.2 },
	},

	text = {
		hint = "A/D or arrows to move, Space to jump, E to talk",
		goal = "Find a way across the river",
		talk = "Talk",
		complete = "You crossed the river!",
	},
}
