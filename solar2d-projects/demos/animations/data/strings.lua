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
		sprite = "Every frame is drawn by hand, so the artist controls every pixel and can draw anything. "
			.. "That takes time and skill, and any later change means drawing the frames again.",

		skeletal = "Parts drawn once are moved between keyframes. It looks less hand-crafted, but it is quick to animate "
			.. "and extend, and a change is a few edited numbers instead of new drawings.",
	},

	styleButtonLabel = "change style",

	-- Keyed by animation name, so the button order comes from data/animations.lua.
	buttonLabel = {
		idle = "idle",
		walk = "walk",
		jump = "jump",
	},
}
