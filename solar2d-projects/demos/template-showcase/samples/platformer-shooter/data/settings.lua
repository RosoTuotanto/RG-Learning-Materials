local imageFolder = "samples/platformer-shooter/assets/images/"
local audioFolder = "samples/platformer-shooter/assets/audio/"

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
	tag = "platformerShooter",

	-- Downward pull in metres per second squared; Box2D counts 30 content units per metre.
	gravity = 30,

	-- Milliseconds "Defeated" or "Area cleared" stays on screen before the level restarts.
	messageTime = 2000,

	-- The Tiled map, and the folder its tileset image path is relative to.
	map = { folder = "samples/platformer-shooter/assets", file = "level.json" },

	-- Each sheet is drawn at displaySize content units per frame.
	sheets = {
		characters = { path = imageFolder .. "characters.png", displaySize = characterSize, columns = 5, rows = 2 },
	},

	sounds = {
		shoot = audioFolder .. "shoot.wav",
		turretShot = audioFolder .. "turretShot.wav",
		hit = audioFolder .. "hit.wav",
	},

	filters = {
		-- Level walls have no filter, so they are category 1 and touch everything.

		-- The player touches walls, turrets and turret bullets.
		player = { categoryBits = 2, maskBits = 21 },

		-- Turrets touch the player and the player's bullets.
		turret = { categoryBits = 4, maskBits = 10 },

		-- The player's bullets touch walls and turrets.
		playerBullet = { categoryBits = 8, maskBits = 5 },

		-- Turret bullets touch walls and the player.
		turretBullet = { categoryBits = 16, maskBits = 3 },
	},

	player = {
		sequence = { name = "run", frames = { 1, 2 }, time = 250 },
		hp = 5,

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

		-- Speeds in content units per second, and the milliseconds the keys stay ignored.
		knockback = { speed = 160, rise = 180, time = 180 },

		-- Milliseconds the player stays tinted after a hit.
		flashTime = 150,
		flashColor = { 1, 0.35, 0.35 },

		-- The collision shape; offsetY moves it down so its bottom meets the sprite's feet.
		body = { width = 32, height = 44, offsetY = 2, chamfer = 4 },

		-- The sensor along the bottom edge that tells whether the player stands on something.
		foot = { width = 26, height = 6 },
	},

	gun = {
		image = imageFolder .. "gun.png",
		width = 28,
		height = 20,

		-- Points in content units from the image's top-left: the grip it turns around and the tip bullets leave from.
		grip = { x = 8, y = 12 },
		tip = { x = 24, y = 8 },

		-- Where the grip sits from the player's centre when facing right; facing left mirrors x.
		hand = { x = 10, y = 10 },

		-- Milliseconds between shots.
		cooldown = 250,
	},

	turret = {
		image = imageFolder .. "turret.png",
		size = tileSize,
		hp = 3,

		body = { width = 32, height = 36 },

		-- The barrel's ball joint sits on this point, measured from the base's centre.
		hub = { x = 0, y = -4 },

		barrel = {
			image = imageFolder .. "turretBarrel.png",
			width = 32,
			height = 16,

			-- The ball joint the barrel turns around, in content units from the image's top-left.
			joint = { x = 8, y = 8 },
		},

		-- Rotation in degrees while the player is out of sight.
		restHeading = 180,

		-- How far from the hub the turret sees and shoots, in content units.
		range = 430,

		-- Distance from the hub to where its bullets appear, just past the barrel's end.
		muzzleOffset = 26,

		-- Milliseconds before the first shot once the player comes into sight, and between shots after that.
		sightDelay = 600,
		fireInterval = 1400,

		flashTime = 120,
		flashColor = { 1, 0.45, 0.45 },
	},

	bullets = {
		-- Speeds in content units per second, lifetimes in milliseconds.
		player = { image = imageFolder .. "bullet.png", width = 14, height = 8, speed = 720, damage = 1, lifetime = 1200, filter = "playerBullet" },
		turret = { image = imageFolder .. "turretBullet.png", width = 12, height = 12, speed = 280, damage = 1, lifetime = 3000, filter = "turretBullet" },
	},

	-- The camera's target parameters: how far the player may move from the screen centre before the camera follows.
	camera = {
		paddingLeft = 40,
		paddingRight = 40,
		paddingUp = 60,
		paddingDown = 60,

		-- Higher values make the camera trail the player more.
		smoothing = 0.1,
	},

	hud = {
		-- The health panel sits centred at the top: its distance from the actual top edge, and the space between its edges and its contents.
		hpTop = 12,
		hpPadding = 8,

		labelSize = 20,
		labelGap = 10,
		barWidth = 150,
		barHeight = 16,

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
		hpPanel = { 0 },
		hpText = { 1 },
		hpBack = { 1, 0.35 },
		hpFill = { 0.86, 0.24, 0.24 },
	},

	text = {
		hint = { "A/D or arrows to move, Space to jump, mouse to aim, click to shoot", "Destroy every turret" },
		hp = "HP",
		defeated = "Defeated",
		cleared = "Area cleared",
	},
}
