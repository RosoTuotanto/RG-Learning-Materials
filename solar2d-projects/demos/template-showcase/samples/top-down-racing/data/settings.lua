local imageFolder = "samples/top-down-racing/assets/images/"
local audioFolder = "samples/top-down-racing/assets/audio/"

return {
	font = {
		heading = "assets/fonts/roboto/Roboto-Bold.ttf",
		body = "assets/fonts/roboto/Roboto-Light.ttf",
	},

	-- Longest step one frame may take, in milliseconds, so a stalled frame never throws the car across the map.
	maxFrameTime = 100,

	-- The trees and rocks get their friction and a little bounce from the map's wall rects, so a crash pushes the car back.
	map = { folder = "samples/top-down-racing/assets", file = "level.json" },

	-- Solar2D's default physics scale, which this sample never changes; forces and impulses are divided by it.
	pixelsPerMeter = 30,

	keys = {
		accelerate = { "w", "up" },
		brake = { "s", "down" },
		left = { "a", "left" },
		right = { "d", "right" },
		handbrake = { "space" },
	},

	sounds = {
		lap = audioFolder .. "lap.wav",
		bump = audioFolder .. "bump.wav",
	},

	car = {
		image = imageFolder .. "car.png",
		width = 32,
		height = 20,

		-- The collision box sits a little inside the drawn car, so near misses look like misses.
		bodyWidth = 28,
		bodyHeight = 16,
		body = { density = 1, friction = 0.3, bounce = 0.3 },

		-- Speeds in content units per second, accelerations in content units per second squared.
		acceleration = 300,
		maxSpeed = 420,
		braking = 600,
		reverseAcceleration = 160,
		maxReverseSpeed = 110,

		-- Below this forward speed, holding brake starts reversing.
		reverseBelowSpeed = 20,

		-- Share of the sideways velocity removed each frame: higher grips harder, the handbrake value lets the car slide.
		grip = 0.85,
		driftGrip = 0.06,

		-- Degrees per second at full steering, reached from fullTurnSpeed upwards; slower cars turn less.
		turnRate = 200,
		fullTurnSpeed = 180,

		-- Linear damping on dirt and on grass; the grass value is what makes leaving the track slow.
		trackDamping = 0.3,
		grassDamping = 3,
	},

	-- Slowest speed into a tree or rock, in content units per second, that plays the bump sound, and the shortest time between two bumps in milliseconds.
	bumpSpeed = 120,
	bumpCooldown = 400,

	finishLine = {
		squareSize = 8,
		lightColor = { 0.95 },
		darkColor = { 0.12 },
	},

	camera = {
		-- How far the car may move from the screen centre before the camera follows.
		padding = 16,

		-- Higher values make the camera trail the car more.
		smoothing = 0.08,
	},

	hud = {
		-- Distance from the actual screen edges to the app's back button, and its height.
		margin = 12,
		backHeight = 44,

		-- Space between the back button and the lap times below it.
		gap = 12,

		labelSize = 20,
		lineHeight = 26,

		-- Milliseconds the message line stays up.
		messageTime = 2500,

		-- Milliseconds the last and best times stay lit after a counted lap.
		highlightTime = 1500,

		hintSize = 18,
		hintLineHeight = 24,

		-- Distance from the actual screen bottom to the middle of the last hint line.
		hintBottom = 24,

		-- Space between the hint lines and the edges of their background.
		hintPadding = 6,
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
		text = { 0.98 },
		message = { 1, 0.86, 0.35 },
		lapHighlight = { 0.45, 1, 0.45 },
		hintBackground = { 0 },
	},

	text = {
		lap = "Lap ",
		last = "Last ",
		best = "Best ",
		noTime = "-:--.--",
		missed = "Missed a checkpoint, lap not counted",

		hint = {
			"Up/W to drive, Left/A and Right/D to steer, Space to drift",
			"Drive full laps and set a best lap",
		},
	},
}
