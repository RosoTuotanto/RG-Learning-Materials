-- The skeletal character: a spriteloop package that plays each variant once and then
-- moves on to the next variant of the same animation.

local skeletalCharacter = {}

--------------------------------------------------------------------------------------
-- Libraries, classes, scripts, configs, etc.

local spriteloop = require( "libs.spriteloop" )
local animations = require( "data.animations" )

--------------------------------------------------------------------------------------
-- Public functions

-- params: parent, x, y, state (a demoState instance), onVariantChange( variant )
function skeletalCharacter.new( params )
	local state = params.state

	local rig = spriteloop.new( animations.skeletal.path, { autoplay = false } )
	params.parent:insert( rig )
	rig.x = params.x
	rig.y = params.y
	rig.xScale = animations.scale
	rig.yScale = animations.scale
	rig.isVisible = false

	local character = {}

	local switchTimer
	local isSwitchPending = false

	local playCurrent

	local function cancelSwitch()
		if switchTimer then
			timer.cancel( switchTimer )
			switchTimer = nil
		end

		isSwitchPending = false
	end

	local function switchVariant()
		switchTimer = nil

		if not isSwitchPending then
			return
		end

		isSwitchPending = false

		params.onVariantChange( state:advanceVariant() )
		playCurrent()
	end

	-- The runtime renders the old animation's frame index right after dispatching "complete",
	-- so the switch waits a frame to avoid drawing one wrong pose.
	local function onComplete()
		if isSwitchPending then
			return
		end

		isSwitchPending = true
		switchTimer = timer.performWithDelay( 1, switchVariant )
	end

	function playCurrent()
		rig:play( state:skeletalAnimationName(), { loop = false, onComplete = onComplete } )
	end

	-- Shows the character and plays the state's current animation and variant.
	function character.show()
		cancelSwitch()

		rig.isVisible = true
		playCurrent()
	end

	function character.hide()
		cancelSwitch()

		rig:pause()
		rig.isVisible = false
	end

	-- Removing the group also removes the runtime's own enterFrame listener.
	function character.destroy()
		cancelSwitch()

		display.remove( rig )
		rig = nil
	end

	return character
end

--------------------------------------------------------------------------------------

return skeletalCharacter
