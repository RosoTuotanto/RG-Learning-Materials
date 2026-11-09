local imageFolder = "samples/top-down-puzzle/assets/images/"

return {
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
		undo = { "z" },
		restart = { "r" },
	},

	board = {
		tileSize = 32,

		-- Milliseconds one step or push takes; a held key steps again as soon as the last step ends.
		stepTime = 150,

		-- Tint of a crate that covers a plate.
		crateOnPlate = { 0.65, 1, 0.6 },

		images = {
			floor = imageFolder .. "floor.png",
			wall = imageFolder .. "wall.png",
			plate = imageFolder .. "plate.png",
			crate = imageFolder .. "crate.png",
			doorClosed = imageFolder .. "door_closed.png",
			doorOpen = imageFolder .. "door_open.png",
			hero = imageFolder .. "hero.png",
		},
	},

	hud = {
		-- Distance from the actual screen edges to the app's back button, and its height.
		margin = 12,
		backHeight = 44,

		-- Space between the back button and the room counter below it.
		gap = 8,

		labelSize = 20,
		lineHeight = 26,

		-- The last hint line sits at hintY and earlier lines stack above it.
		hintY = 610,
		hintSize = 18,
		hintLineHeight = 24,

		-- Space between the hint lines and the edges of their background.
		hintPadding = 6,

		titleSize = 40,

		-- Distance from the screen centre to the finished title and to the restart button.
		titleOffset = -40,
		buttonOffset = 40,

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
		hint = {
			"Push crates onto every plate to open the door",
			"Arrows or WASD to move, Z to undo, R to restart",
		},

		room = "Room %d / %d",
		moves = "Moves: %d",
		finished = "All rooms solved",
		restartButton = "Play again",
	},
}
