local imageFolder = "samples/platformer-classic/assets/images/"
local audioFolder = "samples/platformer-classic/assets/audio/"

local tileSize = 36
local characterSize = 48

return {
	font = {
		heading = "assets/fonts/roboto/Roboto-Bold.ttf",
		body = "assets/fonts/roboto/Roboto-Light.ttf",
	},

	keys = {
		left = { "a", "left" },
		right = { "d", "right" },
		jump = { "space", "w", "up" },
	},

	-- Every timer and transition carries this tag, so a restart or leaving the scene cancels them together.
	tag = "platformerClassic",

	-- Downward pull in metres per second squared; Box2D counts 30 content units per metre.
	gravity = 30,

	-- How far below the level's bottom edge the player falls before the level restarts.
	fallMargin = 100,

	-- Milliseconds "Level complete" stays on screen before the level restarts.
	completeDelay = 2000,

	-- The Tiled map, and the folder its tileset image path is relative to.
	map = { folder = "samples/platformer-classic/assets", file = "level.json" },

	-- Each sheet is drawn at displaySize content units per frame.
	sheets = {
		tiles = { path = imageFolder .. "tilemap.png", displaySize = tileSize, columns = 8, rows = 8 },
		characters = { path = imageFolder .. "characters.png", displaySize = characterSize, columns = 5, rows = 2 },
		walker = { path = imageFolder .. "walker.png", displaySize = characterSize, columns = 1, rows = 1 },
		walkerSquashed = { path = imageFolder .. "walkerSquashed.png", displaySize = characterSize, columns = 1, rows = 1 },
	},

	sounds = {
		jump = audioFolder .. "jump.wav",
		coin = audioFolder .. "coin.wav",
		stomp = audioFolder .. "stomp.wav",
		hurt = audioFolder .. "hurt.wav",
	},

	player = {
		sequence = { name = "run", frames = { 1, 2 }, time = 250 },
		hearts = 3,

		-- Which way the unmirrored art faces, and which way the player faces at the start: 1 right, -1 left.
		artFacing = -1,
		startDirection = 1,

		-- Content units per second.
		runSpeed = 220,

		density = 1,

		-- Upward impulse of a jump; with this density and gravity a full jump rises about four tiles.
		jumpImpulse = 26,

		-- Share of the upward speed kept when jump is let go early.
		jumpCut = 0.4,

		-- Upward impulse after stomping a walker.
		bounceImpulse = 18,

		-- Speeds in content units per second, and the milliseconds the keys stay ignored.
		knockback = { speed = 200, rise = 250, time = 250 },

		-- Milliseconds after a hit when walkers cannot hurt the player, and how fast the player blinks meanwhile.
		invulnerableTime = 1200,
		blinkTime = 100,
		blinkAlpha = 0.3,

		-- The collision shape; offsetY moves it down so its bottom meets the sprite's feet.
		body = { width = 32, height = 44, offsetY = 2, chamfer = 4 },

		-- The sensor along the bottom edge that tells whether the player stands on something.
		foot = { width = 26, height = 6 },
	},

	enemy = {
		-- Which way the unmirrored art faces: 1 right, -1 left.
		artFacing = 1,

		-- Content units per second, and -1 to start walking left.
		speed = 60,
		startDirection = -1,

		-- The body's top meets the top of the standing art, so a stomp lands on the visible head.
		body = { width = 28, height = 32, offsetY = 8 },

		-- How far below a walker's top the player's feet may be and still count as a stomp.
		stompTolerance = 16,

		-- Milliseconds a stomped walker takes to fade out.
		squashTime = 400,
	},

	block = {
		sequence = { name = "block", frames = { 9, 10 } },

		-- How far below the frame's centre the block's art is centred.
		artOffsetY = 2,

		-- How far above a block's bottom the player's head may be and still count as a bump from below.
		headTolerance = 10,

		-- The hop a bumped block makes, in content units and milliseconds each way.
		bumpHeight = 8,
		bumpTime = 80,
	},

	coin = {
		sequence = { name = "spin", frames = { 47, 48 }, time = 400 },
		radius = 12,

		-- How high a collected coin floats while it fades, and for how many milliseconds.
		flyHeight = 48,
		flyTime = 400,
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

	hud = {
		-- Distance from the actual top edge to the centre of the hearts and coin count.
		topOffset = 34,

		heartSequence = { name = "heart", frames = { 21, 23 } },
		heartSpacing = 40,

		-- Space between the hearts and the coin count, which sit either side of the screen centre.
		gap = 40,
		coinLabelGap = 8,
		coinLabelSize = 26,

		-- Distance from the actual bottom edge to the hint's centre, and the space between the hint and the edges of its background.
		hintOffset = 25,
		hintSize = 18,
		hintPadding = 6,

		messageSize = 48,
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
			background = { 0 },
			label = { 1 },
			track = { 1, 0.35 },
			fill = { 1 },
			knob = { 0.75 },
		},
	},

	colors = {
		sky = { 0.62, 0.83, 0.95 },
		text = { 0.12, 0.13, 0.18 },
		hintBackground = { 0 },
		hintText = { 1 },
	},

	text = {
		hint = "A/D or arrows to run, Space to jump, reach the flag",
		complete = "Level complete",
	},
}
