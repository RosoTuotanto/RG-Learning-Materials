-- Every piece of text the demo puts on screen.

return {
	-- Keyed by demoState style.
	heading = {
		sprite = "Now showing: frame-by-frame animation",
		skeletal = "Now showing: skeletal animation",
	},

	-- Filled with the animation name.
	captionFormat = "Playing: %s animation",
	-- Filled with the captionFormat text, the current variant and the variant count.
	skeletalCaptionFormat = "%s (variant %d/%d)",

	styleButtonLabel = "Switch animation style",

	animationPanelTitle = "Select animation sequence",

	-- Keyed by animation name, so the button order comes from data/animations.lua.
	buttonLabel = {
		idle = "idle",
		walk = "walk",
		jump = "jump",
	},
}
