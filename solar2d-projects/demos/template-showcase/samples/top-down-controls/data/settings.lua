return {
	font = {
		heading = "assets/fonts/roboto/Roboto-Bold.ttf",
		body = "assets/fonts/roboto/Roboto-Light.ttf",
	},

	map = { folder = "samples/top-down-controls/assets", file = "level.json" },

	-- Every key name that triggers each action.
	keys = {
		up = { "w", "up" },
		down = { "s", "down" },
		left = { "a", "left" },
		right = { "d", "right" },
		switchMode = { "tab" },
	},

	player = {
		image = "samples/top-down-controls/assets/images/hero.png",
		size = 32,

		-- Collision circle radius, under half a tile so the hero fits through one-tile gaps.
		bodyRadius = 12,

		-- Free mode speed in content units per second.
		speed = 160,

		-- Milliseconds one grid step takes.
		stepTime = 150,
	},

	-- The faint lines shown in grid mode.
	grid = {
		color = { 1, 0.18 },
		width = 1,
	},

	hud = {
		labelY = 32,
		labelSize = 22,

		hintY = 610,
		hintSize = 18,

		-- Space between the hint and the edges of its background.
		hintPadding = 6,

		-- Distance from the actual screen edges to the app's back button, and its height.
		margin = 12,
		backHeight = 44,

		-- Space between the back button and the switch button below it.
		gap = 8,

		button = {
			width = 160,
			height = 44,
			cornerRadius = 8,
			strokeWidth = 2,
			fontSize = 18,
		},
	},

	colors = {
		text = { 0.94, 0.95, 0.97 },
		hintBackground = { 0 },
		hintText = { 1 },

		buttonFill = { 0.16, 0.17, 0.21 },
		buttonBorder = { 0.34, 0.36, 0.42 },
	},

	text = {
		hint = "WASD or arrows to move, Tab to switch controls",
		switchButton = "Switch controls",

		modes = {
			free = "Free movement",
			grid = "Grid movement",
		},
	},
}
