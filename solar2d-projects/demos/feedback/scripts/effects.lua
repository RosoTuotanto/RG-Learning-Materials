-- Every feedback layer in the demo, in one file, so that they can be read side by side.
-- Nothing in here changes the fight. Each function checks whether its layer is switched
-- on for the current version and does nothing at all when it is not.

local effects = {}

--------------------------------------------------------------------------------------
-- Libraries, classes, scripts, configs, etc.

local layout = require( "data.layout" )
local versions = require( "data.versions" )
local rng = require( "scripts.rng" )

--------------------------------------------------------------------------------------
-- Forward declarations & variables

local tuning = versions.tuning
local palette = layout.palette

-- The layer flags of the version currently on screen. Set by the scene.
local layers = {}

-- Casings and muzzle flashes are drawn here, and the whole world group is what shakes.
local worldGroup
local effectGroup

local casings = {}

local hitStopRemaining = 0

local shakeElapsed = 0
local isShaking = false

local sounds = {}
local volume = tuning.sound.defaultVolume

--------------------------------------------------------------------------------------
-- Localised functions

local mathSin = math.sin
local mathCos = math.cos
local mathRad = math.rad
local mathPi = math.pi

--------------------------------------------------------------------------------------
-- Private functions

-- Version 5 replaces every linear transition with a tuned curve. With the layer off the
-- effects keep their size and duration, and only their timing changes.
local function curve( tunedEasing )
	return layers.easing and tunedEasing or easing.linear
end

-- Positional effects always animate back to a stored anchor. Relative offsets would let
-- rounding errors accumulate and drift the fighters sideways over a long loop.
local function returnToAnchor( target, anchorX, time, tunedEasing )
	transition.to( target, {
		time = time,
		x = anchorX,
		transition = curve( tunedEasing ),
	})
end

local function removeCasing( index )
	local casing = casings[index]

	display.remove( casing.object )
	casing.object = nil

	table.remove( casings, index )
end

--------------------------------------------------------------------------------------
-- Public functions

function effects.init( params )
	worldGroup = params.worldGroup
	effectGroup = params.effectGroup
end

function effects.setLayers( activeLayers )
	layers = activeLayers
end

-- 2. The target reacts, part one. A hard cut to a bright fill at the moment of contact.
-- Deliberately not a transition: this runs on the same frame as startHitStop, and a
-- transition created just before a pause is the one case the pause cannot cover.
function effects.flashStart( fighter )
	if not layers.targetFlash then
		return
	end

	transition.cancel( fighter.flashOverlay )

	fighter.flashOverlay.alpha = 1
end

-- 2. The target reacts, part two. The short fade back out, started once any hit stop
-- has finished. The overlay is a plain rect on top of the body, so this is an ordinary
-- alpha transition rather than a fill colour change.
function effects.flashRelease( fighter )
	if not layers.targetFlash then
		return
	end

	transition.to( fighter.flashOverlay, {
		time = tuning.flash.fadeTime,
		delay = tuning.flash.holdTime,
		alpha = 0,
		transition = curve( easing.outQuad ),
	})
end

-- 3. The target moves. Fast out, eased back. Force reads as displacement.
function effects.knockback( fighter )
	if not layers.knockback then
		return
	end

	local knockback = tuning.knockback

	transition.cancel( fighter.group )

	transition.to( fighter.group, {
		time = knockback.outTime,
		x = fighter.anchorX - knockback.distance * fighter.facing,
		transition = curve( knockback.outEasing ),
		onComplete = function()
			returnToAnchor( fighter.group, fighter.anchorX, knockback.returnTime, knockback.returnEasing )
		end,
	})
end

-- 4. The shooter reacts, part one. The gun kicks further back than the body does.
function effects.recoil( fighter )
	if not layers.recoil then
		return
	end

	local recoil = tuning.recoil

	transition.cancel( fighter.group )
	transition.cancel( fighter.gun )

	transition.to( fighter.group, {
		time = recoil.outTime,
		x = fighter.anchorX - recoil.bodyDistance * fighter.facing,
		transition = curve( recoil.outEasing ),
		onComplete = function()
			returnToAnchor( fighter.group, fighter.anchorX, recoil.returnTime, recoil.returnEasing )
		end,
	})

	transition.to( fighter.gun, {
		time = recoil.outTime,
		x = fighter.gunAnchorX - recoil.gunDistance * fighter.facing,
		transition = curve( recoil.outEasing ),
		onComplete = function()
			returnToAnchor( fighter.gun, fighter.gunAnchorX, recoil.returnTime, recoil.returnEasing )
		end,
	})
end

-- 4. The shooter reacts, part two. A bright shape at the barrel for a couple of frames.
function effects.muzzleFlash( x, y )
	if not layers.muzzleFlash then
		return
	end

	local muzzle = tuning.muzzleFlash
	local radius = muzzle.radius

	-- The vertices are written around their own centre, because newPolygon re-centres
	-- the shape on its bounding box instead of treating them as offsets from (x, y).
	local flash = display.newPolygon( effectGroup, x, y, {
		radius, 0,
		radius * 0.3, radius * 0.3,
		0, radius,
		-radius * 0.3, radius * 0.3,
		-radius, 0,
		-radius * 0.3, -radius * 0.3,
		0, -radius,
		radius * 0.3, -radius * 0.3,
	})
	flash:setFillColor( palette.muzzleFlash[1], palette.muzzleFlash[2], palette.muzzleFlash[3] )
	flash.xScale = muzzle.startScale
	flash.yScale = muzzle.startScale

	transition.to( flash, {
		time = muzzle.time,
		alpha = 0,
		xScale = muzzle.endScale,
		yScale = muzzle.endScale,
		transition = curve( muzzle.easing ),
		onComplete = function()
			display.remove( flash )
		end,
	})
end

-- 4. The shooter reacts, part three. Manual velocity, gravity and spin. The physics
-- engine would be a large dependency for one parabola, and it would cost determinism.
function effects.ejectCasing( x, y, facing )
	if not layers.casing then
		return
	end

	local settings = tuning.casing

	local casing = display.newRect( effectGroup, x, y, settings.width, settings.height )
	casing:setFillColor( palette.casing[1], palette.casing[2], palette.casing[3] )

	local speed = settings.speedMin + rng.random() * ( settings.speedMax - settings.speedMin )
	local angle = mathRad( settings.angleMin + rng.random() * ( settings.angleMax - settings.angleMin ) )

	casings[#casings + 1] = {
		object = casing,
		-- Up and backwards, away from the direction the fighter is facing.
		velocityX = -mathCos( angle ) * speed * facing,
		velocityY = -mathSin( angle ) * speed,
		spin = rng.random( settings.spinMin, settings.spinMax ) * facing,
		life = settings.lifetime,
		bounces = 0,
	}
end

-- 5. Anticipation. The gun dips and the body compresses before the shot. Slow in, and
-- then the shot itself provides the fast out.
function effects.anticipate( fighter )
	if not layers.anticipation then
		return
	end

	local anticipation = tuning.anticipation

	transition.cancel( fighter.body )
	transition.cancel( fighter.gun )

	transition.to( fighter.gun, {
		time = anticipation.leadTime,
		y = fighter.gunAnchorY + anticipation.gunDip,
		transition = curve( anticipation.easing ),
	})

	transition.to( fighter.body, {
		time = anticipation.leadTime,
		xScale = anticipation.squashX,
		yScale = anticipation.squashY,
		transition = curve( anticipation.easing ),
	})
end

-- The fast out. Called on every shot, so a fighter cannot be left mid-dip when the
-- anticipation layer is switched off between one shot and the next.
function effects.releaseAnticipation( fighter )
	transition.cancel( fighter.body )

	fighter.gun.y = fighter.gunAnchorY
	fighter.body.xScale = 1
	fighter.body.yScale = 1
end

-- 5. Hit stop. The whole scene holds still on impact. The countdown runs on the scene's
-- own frame listener rather than on a timer, because timer.pauseAll would freeze the
-- very timer that is supposed to end the freeze.
function effects.startHitStop()
	if not layers.hitStop or hitStopRemaining > 0 then
		return
	end

	hitStopRemaining = tuning.hitStop.time

	-- pauseAll, not pause(), which a stray transition.ignoreEmptyReference would turn
	-- into a silent no-op. Never call this from inside a transition callback: pause
	-- cannot reach the tweens the transition library is in the middle of iterating.
	transition.pauseAll()
	timer.pauseAll()
end

function effects.isHitStopped()
	return hitStopRemaining > 0
end

-- Returns true for as long as the scene should stay frozen.
function effects.updateHitStop( deltaTime )
	if hitStopRemaining <= 0 then
		return false
	end

	hitStopRemaining = hitStopRemaining - deltaTime

	if hitStopRemaining > 0 then
		return true
	end

	hitStopRemaining = 0

	transition.resumeAll()
	timer.resumeAll()

	return false
end

-- 5. Screen shake. A decaying oscillation rather than random offsets, so that two
-- versions of the same fight shake in exactly the same way.
function effects.shake()
	if not layers.screenShake then
		return
	end

	shakeElapsed = 0
	isShaking = true
end

-- 6. Sound. One shot timbre and one impact timbre per fighter, so that the ear alone
-- tells you who fired and who was hit.
function effects.loadSounds()
	sounds.shotOne = audio.loadSound( "assets/audio/shot_one.wav" )
	sounds.shotTwo = audio.loadSound( "assets/audio/shot_two.wav" )
	sounds.impactOne = audio.loadSound( "assets/audio/impact_one.wav" )
	sounds.impactTwo = audio.loadSound( "assets/audio/impact_two.wav" )
	sounds.casing = audio.loadSound( "assets/audio/casing.wav" )

	audio.setVolume( volume )
end

function effects.playSound( name )
	if not layers.sound or volume <= 0 then
		return
	end

	local sound = sounds[name]

	if not sound then
		print( "WARNING: feedback-demo: missing sound \"" .. tostring( name ) .. "\"." )
		return
	end

	audio.play( sound, { channel = audio.findFreeChannel() } )
end

-- Takes 0 to 1. The slider is the only caller.
function effects.setVolume( value )
	volume = value
	audio.setVolume( volume )
end

function effects.getVolume()
	return volume
end

--------------------------------------------------------------------------------------

-- Steps the effects that run on their own clock instead of on a transition. The scene
-- does not call this while a hit stop is running, which is what freezes them.
function effects.update( deltaTime )
	local seconds = deltaTime / 1000
	local settings = tuning.casing
	local restingY = layout.floorY - settings.height * 0.5

	for i = #casings, 1, -1 do
		local casing = casings[i]
		local object = casing.object

		casing.velocityY = casing.velocityY + settings.gravity * seconds

		object.x = object.x + casing.velocityX * seconds
		object.y = object.y + casing.velocityY * seconds
		object.rotation = object.rotation + casing.spin * seconds

		if object.y >= restingY and casing.velocityY > 0 then
			object.y = restingY
			casing.velocityY = -casing.velocityY * settings.bounceDamping
			casing.velocityX = casing.velocityX * settings.bounceDamping
			casing.spin = casing.spin * settings.bounceDamping
			casing.bounces = casing.bounces + 1

			-- Its own layer rather than part of "sound", because version 7 drops this one
			-- and keeps the rest.
			if layers.casingSound and casing.bounces <= settings.bounceSoundLimit then
				effects.playSound( "casing" )
			end
		end

		casing.life = casing.life - deltaTime

		if casing.life <= settings.fadeTime then
			object.alpha = casing.life / settings.fadeTime
		end

		if casing.life <= 0 then
			removeCasing( i )
		end
	end

	if isShaking then
		local shake = tuning.screenShake

		shakeElapsed = shakeElapsed + deltaTime

		if shakeElapsed >= shake.time then
			isShaking = false
			worldGroup.x = 0
			worldGroup.y = 0
		else
			local decay = 1 - shakeElapsed / shake.time
			local elapsedSeconds = shakeElapsed / 1000

			worldGroup.x = mathSin( elapsedSeconds * shake.frequencyX * 2 * mathPi ) * shake.magnitude * decay
			worldGroup.y = mathCos( elapsedSeconds * shake.frequencyY * 2 * mathPi ) * shake.magnitude * decay
		end
	end
end

-- Puts the effect layer back to its starting state. Called on every version switch and
-- on every restart of the fight, so a switch made mid-freeze can never leave it frozen.
function effects.reset()
	transition.cancelAll()
	transition.resumeAll()
	timer.resumeAll()

	hitStopRemaining = 0

	isShaking = false
	shakeElapsed = 0

	if worldGroup then
		worldGroup.x = 0
		worldGroup.y = 0
	end

	for i = #casings, 1, -1 do
		removeCasing( i )
	end

	-- Muzzle flashes outlive their transitions when a version is switched mid-flight.
	if effectGroup then
		for i = effectGroup.numChildren, 1, -1 do
			display.remove( effectGroup[i] )
		end
	end
end

function effects.destroy()
	effects.reset()

	audio.stop()

	for name in pairs( sounds ) do
		audio.dispose( sounds[name] )
		sounds[name] = nil
	end

	worldGroup = nil
	effectGroup = nil
end

--------------------------------------------------------------------------------------

return effects
