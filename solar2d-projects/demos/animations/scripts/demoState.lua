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

-- params: variantCount, animations (the animation names; the first is the default)
function demoState.new( params )
	local state = {
		variantCount = params.variantCount,
		animations = params.animations,

		style = spriteStyle,
		animation = params.animations[1],
		variant = 1,
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

	return self.style
end

-- Returns false and changes nothing when the name is not one of the animations.
function stateMethods:selectAnimation( name )
	for i = 1, #self.animations do
		if self.animations[i] == name then
			self.animation = name
			self.variant = 1

			return true
		end
	end

	return false
end

-- Moves to the next skeletal variant, wrapping from the last back to 1.
function stateMethods:advanceVariant()
	self.variant = self.variant % self.variantCount + 1

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
