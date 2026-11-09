local imageFolder = "samples/top-down-stealth/assets/images/"
local audioFolder = "samples/top-down-stealth/assets/audio/"

return {
	map = { folder = "samples/top-down-stealth/assets", file = "level.json" },

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
	},

	player = {
		image = imageFolder .. "hero.png",
		size = 32,

		-- Collision circle radius, under half a tile so the hero fits through one-tile gaps.
		bodyRadius = 12,

		-- Content units per second.
		speed = 150,
	},

	guard = {
		image = imageFolder .. "guard.png",
		size = 32,
		bodyRadius = 12,

		-- Walking speed in content units per second.
		speed = 70,

		-- Degrees per second the guard and its cone turn toward the next waypoint.
		turnSpeed = 220,

		-- Milliseconds a guard stands at each waypoint before walking on.
		waitTime = 700,

		-- The "!" shown when the guard spots the hero, its height above the guard, the scale it pops in from and its pop-in time in milliseconds.
		alertText = "!",
		alertSize = 34,
		alertOffsetY = -34,
		alertStartScale = 0.2,
		alertPopTime = 250,
	},

	vision = {
		-- How far a guard sees, in content units.
		range = 170,

		-- Degrees from the facing direction to either edge of the cone; must stay under 90.
		halfAngle = 32,

		-- Straight edges along the cone's curved end; more looks rounder.
		arcSegments = 12,
	},

	timing = {
		-- Longest step a single frame may take, in seconds, so a stalled frame never teleports a guard.
		maxFrameTime = 0.1,

		-- Milliseconds the room holds still after the hero is spotted or escapes, before it restarts.
		caughtPause = 1200,
		escapedPause = 1800,
	},

	hud = {
		hintY = 610,
		hintSize = 18,

		-- Space between the hint and the edges of its background.
		hintPadding = 6,

		messageSize = 34,

		-- Space between the escape message and the edges of its backing box.
		messagePadding = 18,
		messageCornerRadius = 10,
	},

	colors = {
		text = { 0.94, 0.95, 0.97 },
		hintBackground = { 0 },
		hintText = { 1 },

		cone = { 1, 0.9, 0.35, 0.28 },
		coneAlert = { 1, 0.2, 0.15, 0.45 },
		alert = { 1, 0.25, 0.2 },

		messageFill = { 0.1, 0.11, 0.14, 0.9 },
	},

	text = {
		hint = "WASD or arrows to move. Reach the door unseen.",
		escaped = "You got out unseen!",
	},

	sounds = {
		spotted = audioFolder .. "spotted.wav",
		escaped = audioFolder .. "escaped.wav",
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
			background = { 0.1, 0.11, 0.14 },
			label = { 1 },
			track = { 1, 0.35 },
			fill = { 1 },
			knob = { 0.75 },
		},
	},
}
