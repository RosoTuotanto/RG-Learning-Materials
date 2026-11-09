local imageFolder = "samples/top-down-combat/assets/images/"
local audioFolder = "samples/top-down-combat/assets/audio/"

return {
	font = {
		heading = "assets/fonts/roboto/Roboto-Bold.ttf",
		body = "assets/fonts/roboto/Roboto-Light.ttf",
	},

	-- Every timer this sample starts, so leaving or resetting the room cancels them in one call.
	tag = "topDownCombat",

	-- Longest step one frame may take, in milliseconds, so a stalled frame never teleports anything.
	maxFrameTime = 100,

	map = { folder = "samples/top-down-combat/assets", file = "level.json" },

	-- Friction and bounce stay 0 so fighters slide along walls instead of sticking or rebounding.
	fighterBody = { density = 1, friction = 0, bounce = 0 },
	wallBody = { friction = 0 },

	-- Every key name that triggers each action.
	keys = {
		up = { "w", "up" },
		down = { "s", "down" },
		left = { "a", "left" },
		right = { "d", "right" },
	},

	sounds = {
		shoot = audioFolder .. "shoot.wav",
		hit = audioFolder .. "hit.wav",
		hurt = audioFolder .. "hurt.wav",
		swing = audioFolder .. "swing.wav",
	},

	-- Box2D only lets two bodies touch when each one's maskBits include the other's categoryBits.
	filters = {
		-- Walls stop everything.
		wall = { categoryBits = 1, maskBits = 30 },

		-- The hero touches walls, enemies and enemy arrows.
		hero = { categoryBits = 2, maskBits = 21 },

		-- Enemies touch walls, the hero, each other and the hero's arrows.
		enemy = { categoryBits = 4, maskBits = 15 },

		heroArrow = { categoryBits = 8, maskBits = 5 },
		enemyArrow = { categoryBits = 16, maskBits = 3 },
	},

	player = {
		image = imageFolder .. "hero.png",
		size = 32,

		-- Collision circle radius, under half a tile so the hero fits through one-tile gaps.
		bodyRadius = 12,

		-- Content units per second.
		speed = 170,

		maxHp = 10,

		-- Milliseconds between two shots.
		shotCooldown = 300,

		-- offset is the bow's distance from the hero's centre, along the aim.
		weapon = { image = imageFolder .. "heroBow.png", width = 10, height = 30, anchorX = 0.5, offset = 14 },
	},

	arrows = {
		image = imageFolder .. "arrow.png",
		width = 32,
		height = 10,

		-- How far in front of the shooter's centre an arrow appears.
		muzzleOffset = 18,

		-- speed in content units per second, lifetime in milliseconds.
		-- Sensors get no continuous collision, so speed over 60 must stay below the 24-unit body width or an arrow can skip a target.
		hero = { filter = "heroArrow", speed = 640, damage = 1, lifetime = 900 },
		enemy = { filter = "enemyArrow", speed = 280, damage = 1, lifetime = 2200 },
	},

	-- Every hit tints the sprite and pushes the body away from the hit for a moment (milliseconds, content units per second).
	reactions = {
		hero = { flashTime = 160, knockbackTime = 120, knockbackSpeed = 260 },
		enemy = { flashTime = 120, knockbackTime = 100, knockbackSpeed = 240 },
	},

	enemies = {
		melee = {
			image = imageFolder .. "orcMelee.png",
			size = 32,
			bodyRadius = 12,
			speed = 95,
			hp = 3,
			damage = 2,

			-- Milliseconds of rest after a swing, and before the first one.
			attackCooldown = 700,

			-- The sword's hilt sits offset units from the enemy's centre.
			weapon = { image = imageFolder .. "orcSword.png", width = 26, height = 10, anchorX = 0, offset = 6 },

			swing = {
				-- Distance between centres at which the enemy stops and starts a swing.
				startDistance = 40,

				-- Hits the hero whose centre is this close, which is the sword tip plus the hero's body radius.
				reach = 44,

				-- Degrees on each side of the direction the swing aims at.
				halfArc = 65,

				-- Milliseconds raising the sword, then sweeping it across the arc.
				windupTime = 250,
				sweepTime = 180,

				-- Point of the sweep, from 0 to 1, where the arc is checked for the hero.
				strikeAt = 0.5,
			},
		},

		ranged = {
			image = imageFolder .. "orcArcher.png",
			size = 32,
			bodyRadius = 12,
			speed = 80,
			hp = 2,

			attackCooldown = 1600,

			-- Distance from the hero the archer walks toward, and how far off it may drift before moving.
			keepDistance = 230,
			distanceSlack = 40,

			-- Longest distance the archer shoots from.
			shotRange = 380,

			weapon = { image = imageFolder .. "orcBow.png", width = 10, height = 30, anchorX = 0.5, offset = 14 },
		},
	},

	waves = {
		-- Milliseconds between clearing a wave and the next one arriving.
		delay = 1500,

		-- Played in order, and the last one repeats.
		list = {
			{ melee = 2 },
			{ melee = 2, ranged = 1 },
			{ melee = 3, ranged = 2 },
		},
	},

	-- Milliseconds the defeat message stays before the room resets.
	defeatTime = 1600,

	camera = {
		-- How far the hero may move from the screen centre before the camera follows.
		padding = 24,

		-- Higher values make the camera trail the hero more.
		smoothing = 0.1,
	},

	hud = {
		-- Distance from the actual screen top to the middle of the HP bar.
		top = 22,

		-- Narrow enough that the bar ends left of the volume slider in the top-right corner.
		barWidth = 190,
		barHeight = 16,

		labelSize = 18,

		-- Space between the HP bar and the wave label under it.
		labelGap = 4,

		messageSize = 48,
		messagePadding = 24,

		-- Distance from the actual screen bottom to the hint line, and the space between the hint and the edges of its background.
		hintBottom = 24,
		hintSize = 18,
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
		text = { 0.96 },

		hitFlash = { 1, 0.35, 0.35 },

		barBack = { 0, 0.55 },
		barFill = { 0.86, 0.22, 0.2 },

		messageBack = { 0, 0.6 },
		hintBackground = { 0 },
	},

	text = {
		hint = "WASD or arrows to move, mouse to aim, click to shoot",
		wave = "Wave ",
		defeated = "Defeated",
	},
}
