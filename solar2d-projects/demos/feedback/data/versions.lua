-- Which feedback layers each version switches on, and every value those layers use.
-- Versions are cumulative: version 4 runs everything versions 1 to 3 turned on, plus
-- its own additions. Nothing in here changes the mechanic. Retuning the demo means
-- editing this file and nothing else.

return {
	-- One entry per version, listing only what that version adds on top of the last.
	adds = {
		{},
		{ "targetFlash" },
		{ "knockback" },
		{ "recoil", "muzzleFlash", "casing" },
		{ "anticipation", "easing", "hitStop", "screenShake" },
		{ "sound", "casingSound" },
		{},
	},

	-- What a version takes back off, applied after its own additions. Cumulative in the
	-- same way, so a layer dropped here stays off for every version after it.
	--
	-- Version 7 is version 6 minus the casing ping, which is the point of it: the casing
	-- sound is a real addition that makes the result worse, and the only way anyone finds
	-- that out is by adding it and listening.
	removes = {
		{},
		{},
		{},
		{},
		{},
		{},
		{ "casingSound" },
	},

	tuning = {
		-- The target fills bright the instant it is hit, then fades back. The hard cut
		-- in and soft fade out is what makes the moment of contact readable; try a
		-- symmetric fade and it stops reading as an impact.
		flash = {
			color = { 1, 1, 1 },
			holdTime = 30,
			fadeTime = 70,
		},

		-- The target is shoved away from the shooter and eased back to its anchor.
		knockback = {
			distance = 14,
			outTime = 60,
			returnTime = 190,
			outEasing = easing.outQuad,
			returnEasing = easing.outCubic,
		},

		-- The shooter kicks backwards. The gun travels further than the body.
		recoil = {
			bodyDistance = 12,
			gunDistance = 26,
			outTime = 40,
			returnTime = 200,
			outEasing = easing.outQuad,
			returnEasing = easing.outCubic,
		},

		-- A bright shape at the barrel for a couple of frames, with a scale pop.
		muzzleFlash = {
			radius = 26,
			time = 70,
			startScale = 0.6,
			endScale = 1.4,
			easing = easing.outQuad,
		},

		-- Ejected casings are thrown up and backwards, fall under gravity and bounce once
		-- or twice off the floor. Manual velocity and gravity, not the physics engine:
		-- one parabola is not worth a physics dependency and it would cost determinism.
		casing = {
			width = 11,
			height = 5,
			speedMin = 170,
			speedMax = 240,
			-- Degrees measured from the muzzle, up and back over the shooter.
			angleMin = 55,
			angleMax = 80,
			gravity = 1400,
			spinMin = 340,
			spinMax = 760,
			bounceDamping = 0.38,
			lifetime = 1800,
			fadeTime = 300,
			-- A casing bounces several times with less and less energy. Only the first
			-- couple of bounces get a sound, or the fight ends up sounding like rain.
			bounceSoundLimit = 2,
		},

		-- The gun dips and the body compresses before the shot, then snaps. Slow in,
		-- fast out. This is the layer that tells the viewer a shot is coming.
		anticipation = {
			leadTime = 260,
			gunDip = 9,
			squashX = 1.07,
			squashY = 0.93,
			easing = easing.inQuad,
		},

		-- The whole scene holds still on impact. Short: at 60 fps this is 3 to 5 frames.
		hitStop = {
			time = 60,
		},

		-- Small, short and decaying, and deliberately not a full-screen strobe. This is
		-- the most arguable effect in the set, which makes it worth arguing about.
		screenShake = {
			magnitude = 5,
			time = 220,
			-- Oscillations per second, different per axis so the motion is not a diagonal line.
			frequencyX = 31,
			frequencyY = 23,
		},

		-- Nothing before version 6 plays anything, so the demo stays silent until someone
		-- steps all the way through to it. The slider covers the rest.
		sound = {
			defaultVolume = 0.5,
		},
	},
}
