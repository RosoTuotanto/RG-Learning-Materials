-- The skeletal character's outfit buttons and the package images and skin each choice shows.
-- tools/check_assets.py checks every name here against the manifest.

return {
	-- The buttons, top to bottom. Each one steps through its options in this order, and the
	-- first option is the outfit as drawn.
	slots = { "shirt", "pants", "flowers" },

	options = {
		shirt = { "yellow", "red" },
		pants = { "blue", "grey" },
		flowers = { "none", "held" },
	},

	-- Buttons that show the active fill while their option is not the first one.
	highlighted = {
		flowers = true,
	},

	-- Per part, the manifest variant it shows while every option a rule names is chosen.
	-- A part with no matching rule shows its own image; at most one rule per part matches.
	parts = {
		torso = {
			{ shirt = "red", pants = "blue", variant = "torso_red_shirt" },
			{ shirt = "yellow", pants = "grey", variant = "torso_grey_pants" },
			{ shirt = "red", pants = "grey", variant = "torso_red_shirt_grey_pants" },
		},

		arm_near_upper = {
			{ shirt = "red", variant = "arm_near_upper_red_shirt" },
		},

		arm_far_upper = {
			{ shirt = "red", variant = "arm_far_upper_red_shirt" },
		},

		leg_near_upper = {
			{ pants = "grey", variant = "leg_near_upper_grey_pants" },
		},

		leg_near_lower = {
			{ pants = "grey", variant = "leg_near_lower_grey_pants" },
		},

		leg_far_upper = {
			{ pants = "grey", variant = "leg_far_upper_grey_pants" },
		},

		leg_far_lower = {
			{ pants = "grey", variant = "leg_far_lower_grey_pants" },
		},
	},

	-- The package skin, matched the same way. The bouquet skin shows the bouquet and holds the near hand in a fist.
	skins = {
		{ flowers = "held", skin = "bouquet" },
	},

	defaultSkin = "default",
}
