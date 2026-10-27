-- What the demo is showing: the animation style, the selected animation and the skeletal
-- variant. Pure Lua with no display calls, so it runs under stock Lua 5.1.

local demoState = {}

--------------------------------------------------------------------------------------
-- Forward declarations & variables

local stateMethods = {}
local stateMetatable = { __index = stateMethods }

local spriteStyle = "sprite"
local skeletalStyle = "skeletal"

--------------------------------------------------------------------------------------
-- Public functions

-- params: animations (the animation names; the first is the default), variantCount,
-- plays (keyed by animation name, how many times each variant plays before the next)
function demoState.new( params )
	local state = {
		animations = params.animations,
		variantCount = params.variantCount,
		plays = params.plays,

		style = spriteStyle,
		animation = params.animations[1],
		variant = 1,
		playsDone = 0,
	}

	return setmetatable( state, stateMetatable )
end

-- Switches between the two styles and starts the newly shown one from variant 1.
-- Returns the new style.
function stateMethods:toggleStyle()
	if self.style == spriteStyle then
		self.style = skeletalStyle
	else
		self.style = spriteStyle
	end

	self.variant = 1
	self.playsDone = 0

	return self.style
end

-- Returns false and changes nothing when the name is not one of the animations.
function stateMethods:selectAnimation( name )
	for i = 1, #self.animations do
		if self.animations[i] == name then
			self.animation = name
			self.variant = 1
			self.playsDone = 0

			return true
		end
	end

	return false
end

-- Counts one finished play of the current variant from its start. Returns true once the
-- variant has played as many times as data/animations.lua asks for.
function stateMethods:recordPlay()
	self.playsDone = self.playsDone + 1

	return self.playsDone >= self.plays[self.animation]
end

-- The current variant plays again from its start, so its plays are counted from zero.
function stateMethods:restartVariant()
	self.playsDone = 0
end

-- Moves to the next skeletal variant, wrapping from the last back to 1.
function stateMethods:advanceVariant()
	self.variant = self.variant % self.variantCount + 1
	self.playsDone = 0

	return self.variant
end

function stateMethods:getStyle()
	return self.style
end

function stateMethods:isSkeletal()
	return self.style == skeletalStyle
end

function stateMethods:getAnimation()
	return self.animation
end

function stateMethods:getVariant()
	return self.variant
end

function stateMethods:getVariantCount()
	return self.variantCount
end

-- The skeletal package names each variant <animation>_<variant>, for example "walk_2".
function stateMethods:skeletalAnimationName()
	return self.animation .. "_" .. self.variant
end

--------------------------------------------------------------------------------------

return demoState
