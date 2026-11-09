local imageFolder = "samples/platformer-abilities/assets/images/"
local audioFolder = "samples/platformer-abilities/assets/audio/"

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
		jump = { "space" },
		dash = { "leftShift", "rightShift", "x" },
	},

	-- Every timer and transition carries this tag, so a restart or leaving the scene cancels them together.
	tag = "platformerAbilities",

	-- Downward pull in metres per second squared; Box2D counts 30 content units per metre.
	gravity = 30,

	-- Content units the player's centre must be past a room edge before the camera moves to that room; more than half the sprite's width.
	roomMargin = 30,

	-- How far below the level's bottom edge the player falls before respawning.
	fallMargin = 100,

	-- Milliseconds "You found everything" stays on screen before the level restarts.
	completeDelay = 3000,

	map = { folder = "samples/platformer-abilities/assets", file = "level.json" },

	-- Each sheet is drawn at displaySize content units per frame.
	sheets = {
		tiles = { path = imageFolder .. "tilemap.png", displaySize = tileSize, columns = 8, rows = 8 },
		characters = { path = imageFolder .. "characters.png", displaySize = characterSize, columns = 5, rows = 2 },
	},

	sounds = {
		jump = audioFolder .. "jump.wav",
		dash = audioFolder .. "dash.wav",
		pickup = audioFolder .. "pickup.wav",
	},

	player = {
		-- time is the milliseconds one pass through the frames takes.
		sequence = { name = "run", frames = { 1, 2 }, time = 250 },

		-- Which way the unmirrored art faces, and which way the player faces at the start: 1 right, -1 left.
		artFacing = -1,
		startDirection = 1,

		-- Content units per second.
		runSpeed = 230,

		density = 1,

		-- Upward impulses of a jump from the ground and of the double jump; with this density and gravity a jump from the ground rises four tiles.
		jumpImpulse = 26,
		airJumpImpulse = 26,

		-- Share of the upward speed kept when jump is let go early; lower makes short hops shorter.
		jumpCut = 0.4,

		-- Milliseconds after running off a ledge during which a jump from the ground still works.
		coyoteTime = 100,

		-- Milliseconds a jump pressed in the air is remembered, so it fires on landing.
		jumpBufferTime = 120,

		-- Dash speed in content units per second, its length in milliseconds, the share of its speed kept when it ends,
		-- and the milliseconds that kept speed carries the player before left and right steer again.
		dash = { speed = 720, time = 220, endFactor = 0.35, carryTime = 80 },

		-- The collision shape; offsetY moves it down so its bottom meets the sprite's feet.
		body = { width = 32, height = 44, offsetY = 2, chamfer = 4 },

		-- The sensor along the bottom edge that tells whether the player stands on something.
		foot = { width = 26, height = 6 },
	},

	pickup = {
		-- Content units the pickups float up and down, and the milliseconds one float up and back down takes.
		bobHeight = 6,
		bobTime = 1800,
	},

	-- Each ability's pickup is an object of the same type on the map's "game" layer, with its image and the message it shows.
	abilities = {
		doubleJump = { image = imageFolder .. "pickupDoubleJump.png", message = "Double jump: press Space in the air" },
		dash = { image = imageFolder .. "pickupDash.png", message = "Dash: press Shift or X" },
	},

	-- Order of the ability icons in the HUD, left to right.
	abilityOrder = { "doubleJump", "dash" },

	goal = {
		-- time is the milliseconds one pass through the frames takes.
		sequence = { name = "wave", frames = { 7, 15 }, time = 500 },
	},

	camera = {
		-- Higher values make the camera glide to the next room more slowly.
		smoothing = 0.12,

		-- Larger than any room, so a room change always glides instead of jumping part of the way.
		maxDistance = 4000,
	},

	hud = {
		-- The ability panel's distance from the actual left edge and from the actual top edge; below the Back button.
		left = 20,
		top = 76,

		-- Space around and between the ability icons on their panel.
		padding = 8,
		cornerRadius = 8,

		-- Opacity of an ability icon until its pickup is collected.
		dimAlpha = 0.3,

		-- How much an icon grows when its ability is collected, and for how many milliseconds.
		popScale = 1.35,
		popTime = 160,

		-- Distance from the actual bottom edge to the centre of the hint panel, and the gap around its text.
		hintOffset = 40,
		hintPadding = 10,
		hintSize = 18,

		-- Distance between the hint lines as a multiple of hintSize.
		hintLineHeight = 1.3,

		-- Distance of the message above the screen centre, its size, and the gap around its text.
		messageOffset = 150,
		messageSize = 30,
		messagePadding = 16,

		-- Milliseconds a pickup message stays fully shown, then fades out.
		messageTime = 2500,
		messageFadeTime = 400,
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
			background = { 0.1, 0.11, 0.16 },
			label = { 1 },
			track = { 1, 0.35 },
			fill = { 1 },
			knob = { 0.75 },
		},
	},

	colors = {
		sky = { 0.62, 0.83, 0.95 },
		panel = { 0.1, 0.11, 0.16, 0.8 },
		hintBackground = { 0 },
		text = { 1 },
	},

	text = {
		hint = { "A/D or arrows to move, Space to jump", "Explore and find every ability" },
		complete = "You found everything",
	},
}
