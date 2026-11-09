local imageFolder = "samples/platformer-puzzle/assets/images/"
local audioFolder = "samples/platformer-puzzle/assets/audio/"

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
		restart = { "r" },
	},

	-- Every timer and transition carries this tag, so a restart or leaving the scene cancels them together.
	tag = "platformerPuzzle",

	-- Downward pull in metres per second squared; Box2D counts 30 content units per metre.
	gravity = 30,

	-- Milliseconds between opening the exit and the next room appearing.
	nextRoomDelay = 800,

	-- Distance from the content area's top edge to the room's top edge; the room is centred sideways.
	roomTop = 108,

	-- One Tiled map per room, in play order, and the folder their tileset image path is relative to.
	map = { folder = "samples/platformer-puzzle/assets", rooms = { "room1.json", "room2.json" } },

	-- Each sheet is drawn at displaySize content units per frame.
	sheets = {
		characters = { path = imageFolder .. "characters.png", displaySize = characterSize, columns = 5, rows = 2 },
	},

	-- Doors and the exit are one tile wide and two tall; everything else fills one tile.
	images = {
		crate = imageFolder .. "crate.png",
		switchUp = imageFolder .. "switchUp.png",
		switchDown = imageFolder .. "switchDown.png",
		doorClosed = imageFolder .. "doorClosed.png",
		doorOpen = imageFolder .. "doorOpen.png",
		key = imageFolder .. "key.png",
		exitDoor = imageFolder .. "exitDoor.png",
		exitDoorOpen = imageFolder .. "exitDoorOpen.png",
	},

	sounds = {
		switch = audioFolder .. "switch.wav",
		door = audioFolder .. "door.wav",
		key = audioFolder .. "key.wav",
	},

	player = {
		-- time is the milliseconds one pass through the frames takes.
		sequence = { name = "run", frames = { 1, 2 }, time = 250 },

		-- Which way the unmirrored art faces, and which way the player faces at the start: 1 right, -1 left.
		artFacing = -1,
		startDirection = 1,

		-- Content units per second, running freely and while pushing a crate; the pushed crate moves at pushSpeed too.
		runSpeed = 220,
		pushSpeed = 50,

		-- How far a crate's centre may sit above or below the player's centre and still count as pushed rather than stood on;
		-- a crate stacked on the pushed one sits about 30 above the player's centre and must stay out of reach.
		pushReach = 24,

		density = 1,

		-- Upward impulse of a jump; with this density and gravity a full jump lifts the feet a little over two tiles.
		jumpImpulse = 22,

		-- Share of the upward speed kept when jump is let go early.
		jumpCut = 0.4,

		-- The collision shape; offsetY moves it down so its bottom meets the sprite's feet.
		body = { width = 32, height = 44, offsetY = 2, chamfer = 4 },

		-- The sensor along the bottom edge that tells whether the player stands on something.
		foot = { width = 26, height = 6 },
	},

	puzzle = {
		-- High density keeps a bumped crate from flying; high friction stops it within a few units once the push ends.
		-- chamfer cuts its corners at 45 degrees, so they slide past tile edges and lie flat on a switch's ramps.
		crate = { density = 4, friction = 1, chamfer = 4 },

		switch = {
			-- Collision outlines in the art's pixels, clockwise from the left toe, with the floor at y 18; pixelSize content units per art pixel.
			raisedOutline = { 0, 18, 7, 11, 11, 11, 18, 18 },
			pressedOutline = { 0, 18, 4, 14, 14, 14, 18, 18 },
			pixelSize = 2,

			-- Low enough that a pushed crate rides up a ramp, high enough that a crate left on the plate stays put.
			friction = 0.2,

			-- Sensor boxes in the switch's body coordinates (origin at the frame's centre): half width, top and bottom edge.
			-- pressSensor covers the raised plate's flat top, which a crate on a ramp reaches only in its last few units of climb;
			-- holdSensor lies along the pressed plate's top and keeps a press going.
			pressSensor = { halfWidth = 4, top = 2, bottom = 9 },
			holdSensor = { halfWidth = 9.5, top = 7, bottom = 9.5 },
		},

		-- The open art keeps its lower gateHeight units clear; the doorway sensor is narrower than the door, so standing against a closed door is not standing in it.
		-- closeDelay is the milliseconds a door stays open after its switches are released.
		door = { gateHeight = 48, doorwayWidth = 28, closeDelay = 150 },

		-- The key bobs bobHeight units up and back every bobTime milliseconds; carried, its centre sits carriedOffsetY units from the player's.
		key = { sensorWidth = 28, sensorHeight = 20, bobHeight = 4, bobTime = 600, carriedOffsetY = -36 },
	},

	hud = {
		-- Distance from the actual left and top edges to the room label, below the Back button.
		left = 20,
		top = 84,
		labelSize = 22,

		keyIconSize = 36,
		keyIconGap = 8,

		-- Distances from the actual bottom edge to the centres of the two hint lines, and the space between the hints and the edges of their background.
		hintOffsets = { 52, 25 },
		hintSize = 18,
		hintPadding = 6,

		messageSize = 48,

		-- The Play again button's size, corner radius and distance below the message's centre.
		button = { width = 180, height = 52, cornerRadius = 10, offsetY = 70, labelSize = 24 },
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
			background = { 0.12, 0.13, 0.18 },
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
		button = { 0.12, 0.13, 0.18 },
		buttonLabel = { 1 },
	},

	text = {
		hint = { "A/D or arrows to move, Space to jump, R to restart", "Get the key to the exit" },
		room = "Room ",
		solved = "Solved",
		playAgain = "Play again",
	},
}
