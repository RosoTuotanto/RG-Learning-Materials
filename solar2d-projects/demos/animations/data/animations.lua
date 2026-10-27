-- The sprite sheet and its sequences, and the skeletal variants tools/build_character.py builds.

-- The animations both characters share, in button order.
local names = { "idle", "walk", "jump" }

return {
	names = names,

	-- The sprite frames are 80x80 and the skeletal canvas 80x96; both are shown at this scale.
	scale = 4,

	sheet = {
		file = "assets/images/character-sheet.png",
		width = 80,
		height = 80,
		numFrames = 44,

		-- The row of each frame that the drawn feet rest on.
		feetRow = 76,
	},

	-- Frame numbers are 1-based and row-major on the sheet, each sequence spanning its frame tag
	-- in character-sheet.json. One listing is one 1000/12 ms exposure, so a frame listed three
	-- times holds for its three-exposure duration. Times are in milliseconds for the whole
	-- sequence, and loopCount 0 loops forever.
	sequences = {
		idle = {
			frames = {
				1, 1, 1, 1, 1, 1, 2, 2, 3, 3, 3, 3, 3, 4, 4, 5, 6, 7, 8, 8,
				8, 8, 9, 10, 11, 11, 11, 11, 11, 11, 11, 12, 12, 12, 12, 12, 12, 13, 14,
			},
			time = 3248,
			loopCount = 0,
		},

		walk = { frames = { 15, 16, 17, 18, 19, 20, 21, 22, 23, 24, 25, 26 }, time = 996, loopCount = 0 },

		jump = {
			frames = {
				27, 27, 28, 29, 30, 30, 30, 31, 32, 33, 34, 34, 35, 35, 35, 36, 36, 36, 37, 38,
				39, 40, 40, 41, 42, 43, 44, 44,
			},
			time = 2331,
			loopCount = 0,
		},
	},

	skeletal = {
		path = "assets/skeletal",
		names = names,

		-- Each animation is built as <name>_1 to <name>_<variants>.
		variants = 3,

		-- How many times each variant plays before the next one starts.
		plays = { idle = 1, walk = 1, jump = 1 },
	},
}
