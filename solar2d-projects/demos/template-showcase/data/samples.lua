-- The menu shows the columns left to right and each column's samples top to bottom in list order.

return {
	columns = { "visualNovel", "platformer", "topDown" },

	list = {
		{ id = "visual-novel-hidden-object", label = "Hidden Object", column = "visualNovel", module = "samples.visual-novel-hidden-object.demo" },
		{ id = "visual-novel-life-sim", label = "Life Sim", column = "visualNovel", module = "samples.visual-novel-life-sim.demo" },
		{ id = "visual-novel-interrogation", label = "Interrogation", column = "visualNovel", module = "samples.visual-novel-interrogation.demo" },
		{ id = "visual-novel-deduction", label = "Deduction Board", column = "visualNovel", module = "samples.visual-novel-deduction.demo" },
		{ id = "visual-novel-city-map", label = "City Map", column = "visualNovel", module = "samples.visual-novel-city-map.demo" },
		{ id = "visual-novel-endings", label = "Endings", column = "visualNovel", module = "samples.visual-novel-endings.demo" },

		{ id = "platformer-classic", label = "Classic", column = "platformer", module = "samples.platformer-classic.demo" },
		{ id = "platformer-shooter", label = "Shooter", column = "platformer", module = "samples.platformer-shooter.demo" },
		{ id = "platformer-story", label = "Story", column = "platformer", module = "samples.platformer-story.demo" },
		{ id = "platformer-puzzle", label = "Puzzle", column = "platformer", module = "samples.platformer-puzzle.demo" },
		{ id = "platformer-precision", label = "Precision", column = "platformer", module = "samples.platformer-precision.demo" },
		{ id = "platformer-abilities", label = "Abilities", column = "platformer", module = "samples.platformer-abilities.demo" },

		{ id = "top-down-combat", label = "Combat", column = "topDown", module = "samples.top-down-combat.demo" },
		{ id = "top-down-controls", label = "Controls", column = "topDown", module = "samples.top-down-controls.demo" },
		{ id = "top-down-stealth", label = "Stealth", column = "topDown", module = "samples.top-down-stealth.demo" },
		{ id = "top-down-farming", label = "Farming", column = "topDown", module = "samples.top-down-farming.demo" },
		{ id = "top-down-racing", label = "Racing", column = "topDown", module = "samples.top-down-racing.demo" },
		{ id = "top-down-puzzle", label = "Block Puzzle", column = "topDown", module = "samples.top-down-puzzle.demo" },
	},
}
