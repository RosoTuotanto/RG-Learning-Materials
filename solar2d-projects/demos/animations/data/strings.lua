-- Every piece of text the demo puts on screen.

return {
	-- Keyed by demoState style.
	heading = {
		sprite = "Frame-by-frame",
		skeletal = "Skeletal",
	},

	-- Filled with the animation name.
	captionFormat = "Playing: %s animation",
	-- Filled with the captionFormat text, the current variant and the variant count.
	skeletalCaptionFormat = "%s (variant %d/%d)",

	-- Keyed by demoState style.
	description = {
		sprite = "Slower to make and harder to change, since every frame is drawn by hand. "
			.. "In return the artist controls every pixel, effects like motion lines and dust are part of the drawing, "
			.. "and it is light to run in games.",

		skeletal = "Much faster to adjust and easy to vary, since every animation reuses the same parts. "
			.. "In return it is heavier to run in games, and rotated pixel art can almost never stay pixel-perfect.",
	},

	styleButtonLabel = "change style",

	-- Keyed by animation name, so the button order comes from data/animations.lua.
	buttonLabel = {
		idle = "idle",
		walk = "walk",
		jump = "jump",
	},
}
