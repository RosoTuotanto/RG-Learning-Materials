-- Both characters' animation data: the sprite sheet and its sequences, and the skeletal
-- package with its variant families. Must match what tools/build_character.py writes.

-- The animations both characters share, in button order.
local names = { "idle", "walk", "jump" }

return {
	names = names,

	-- Both characters are drawn at 64x72 and shown at this scale.
	scale = 4,

	sheet = {
		file = "assets/images/character-sheet.png",
		width = 64,
		height = 72,
		numFrames = 30,
	},

	-- Frame numbers are 1-based and row-major on the 8-column sheet, in the order of
	-- tools/art/sheet.json. Listing a frame twice holds it for two exposures. Times are in
	-- milliseconds for the whole sequence, and loopCount 0 loops forever.
	sequences = {
		idle = { frames = { 1, 1, 1, 1, 1, 2, 2, 3, 3, 4, 5, 6, 7, 7, 8, 8 }, time = 2400, loopCount = 0 },
		walk = { frames = { 9, 10, 11, 12, 13, 14, 15, 16 }, time = 960, loopCount = 0 },
		jump = { frames = { 17, 17, 17, 17, 18, 19, 19, 19, 20, 21, 22, 23, 23, 23, 24, 25, 26, 27, 27, 27, 28, 29, 29, 30 }, time = 1920, loopCount = 0 },
	},

	skeletal = {
		path = "assets/skeletal",
		-- Each family is authored as <name>_1 to <name>_<variants>.
		variants = 3,
		names = names,
	},
}
