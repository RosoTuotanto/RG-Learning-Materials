local imageFolder = "samples/platformer-precision/assets/images/"
local audioFolder = "samples/platformer-precision/assets/audio/"

local tileSize = 36
local characterSize = 48

return {
	font = {
		heading = "assets/fonts/roboto/Roboto-Bold.ttf",
		body = "assets/fonts/roboto/Roboto-Light.ttf",
	},

	-- Up and down only aim the dash.
	keys = {
		left = { "a", "left" },
		right = { "d", "right" },
		up = { "w", "up" },
		down = { "s", "down" },
		jump = { "space" },
		dash = { "leftShift", "rightShift", "x" },
	},

	-- Every timer and transition carries this tag, so a restart or leaving the scene cancels them together.
	tag = "platformerPrecision",

	-- Downward pull in metres per second squared; Box2D counts 30 content units per metre.
	gravity = 30,

	-- How far below the level's bottom edge the player falls before respawning.
	fallMargin = 100,

	-- Milliseconds "Course complete" stays on screen before the course restarts.
	completeDelay = 2500,

	-- The Tiled map, and the folder its tileset image path is relative to.
	map = { folder = "samples/platformer-precision/assets", file = "level.json" },

	-- Each sheet is drawn at displaySize content units per frame.
	sheets = {
		tiles = { path = imageFolder .. "tilemap.png", displaySize = tileSize, columns = 8, rows = 8 },
		characters = { path = imageFolder .. "characters.png", displaySize = characterSize, columns = 5, rows = 2 },
	},

	sounds = {
		jump = audioFolder .. "jump.wav",
		dash = audioFolder .. "dash.wav",
		spike = audioFolder .. "spike.wav",
	},

	player = {
		-- time is the milliseconds one pass through the frames takes.
		sequence = { name = "run", frames = { 1, 2 }, time = 250 },

		-- Which way the unmirrored art faces, and which way the player faces at the start and after a respawn: 1 right, -1 left.
		artFacing = -1,
		startDirection = 1,

		-- Content units per second.
		runSpeed = 230,

		density = 1,

		-- Upward impulse of a jump; with this density and gravity a full jump rises four tiles.
		jumpImpulse = 26,

		-- Share of the upward speed kept when jump is let go early; lower makes short hops shorter.
		jumpCut = 0.4,

		-- Milliseconds after running off a ledge during which a jump still works.
		coyoteTime = 100,

		-- Milliseconds a jump pressed in the air is remembered, so it fires on landing or touching a wall.
		jumpBufferTime = 120,

		-- Fastest fall in content units per second while pressing into a wall in the air.
		wallSlideSpeed = 110,

		-- Impulses away from the wall and upwards, and the milliseconds left and right are ignored afterwards.
		wallJump = { impulseX = 14, impulseY = 22, lockTime = 160 },

		-- Dash speed in content units per second, its length in milliseconds, the share of its speed kept when it ends,
		-- and the milliseconds that kept speed carries the player before left and right steer again.
		dash = { speed = 680, time = 160, endFactor = 0.35, carryTime = 80 },

		-- The collision shape; offsetY moves it down so its bottom meets the sprite's feet.
		body = { width = 32, height = 44, offsetY = 2, chamfer = 4 },

		-- The sensor along the bottom edge that tells whether the player stands on something.
		foot = { width = 26, height = 6 },

		-- The sensors on both sides that tell whether the player touches a wall; shorter than the body so floors and ceilings never count.
		wallSensor = { width = 6, height = 28 },
	},

	spike = {
		-- Share of the tile's height, from its bottom edge, that hurts; the art's points fill about that much.
		hurtHeight = 0.4,
	},

	checkpoint = {
		-- time is the milliseconds one pass through the frames takes.
		sequence = { name = "wave", frames = { 7, 15 }, time = 500 },

		-- Effect that greys out a checkpoint until it is touched.
		unlitEffect = "filter.grayscale",

		-- How much a checkpoint grows when lit, and for how many milliseconds.
		popScale = 1.3,
		popTime = 150,
	},

	camera = {
		-- How far the player may move either way from the screen centre before the camera follows.
		padding = 40,

		-- Higher values make the camera trail the player more.
		smoothing = 0.1,
	},

	hud = {
		-- Distance from the actual left edge to the death count and time, and from the actual top edge to each line; below the Back button.
		left = 20,
		deathsOffset = 84,
		timeOffset = 112,
		labelSize = 22,

		-- Distances from the actual bottom edge to the centres of the two hint lines, and the space between the hints and the edges of their background.
		hintOffsets = { 52, 25 },
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
		hint = { "Arrows or WASD to move and aim, Space to jump, Shift or X to dash", "Reach the end flag" },
		deaths = "Deaths: ",
		time = "Time: ",
		complete = "Course complete",
	},
}
