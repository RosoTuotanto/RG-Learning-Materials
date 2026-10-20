-- Checks scripts/demoState.lua under stock Lua 5.1. Run from anywhere: lua5.1 tools/verify_state.lua

local root = string.match( arg[0], "^(.*)/tools/[^/]*$" ) or "."
package.path = root .. "/?.lua;" .. package.path

local demoState = require( "scripts.demoState" )

local checks = 0
local failures = 0

local function check( condition, message )
	checks = checks + 1

	if not condition then
		failures = failures + 1
		print( "FAIL: " .. message )
	end
end

local function newState()
	return demoState.new({ variantCount = 3, animations = { "idle", "walk", "jump" } })
end

-- Defaults
local state = newState()
check( state:getStyle() == "sprite", "default style is sprite" )
check( not state:isSkeletal(), "default style is not skeletal" )
check( state:getAnimation() == "idle", "default animation is the first name" )
check( state:getVariant() == 1, "default variant is 1" )
check( state:getVariantCount() == 3, "variant count is kept" )
check( state:skeletalAnimationName() == "idle_1", "default skeletal name is idle_1" )

-- Toggling the style resets the variant both ways
state:advanceVariant()
check( state:toggleStyle() == "skeletal", "toggleStyle returns skeletal from sprite" )
check( state:isSkeletal(), "isSkeletal after one toggle" )
check( state:getVariant() == 1, "toggle to skeletal resets the variant" )

state:advanceVariant()
state:advanceVariant()
check( state:toggleStyle() == "sprite", "toggleStyle returns sprite from skeletal" )
check( state:getVariant() == 1, "toggle to sprite resets the variant" )

-- selectAnimation accepts only known names
state = newState()
state:advanceVariant()
check( state:selectAnimation( "walk" ) == true, "selectAnimation accepts walk" )
check( state:getAnimation() == "walk", "selectAnimation sets walk" )
check( state:getVariant() == 1, "selectAnimation resets the variant" )

state:advanceVariant()
check( state:selectAnimation( "run" ) == false, "selectAnimation rejects an unknown name" )
check( state:getAnimation() == "walk", "a rejected name leaves the animation alone" )
check( state:getVariant() == 2, "a rejected name leaves the variant alone" )
check( state:selectAnimation( nil ) == false, "selectAnimation rejects nil" )
check( state:selectAnimation( "Walk" ) == false, "selectAnimation is case-sensitive" )

-- advanceVariant wraps from the last variant back to 1
state = newState()
check( state:advanceVariant() == 2, "advanceVariant 1 to 2" )
check( state:advanceVariant() == 3, "advanceVariant 2 to 3" )
check( state:advanceVariant() == 1, "advanceVariant wraps 3 to 1" )
check( state:advanceVariant() == 2, "advanceVariant keeps cycling after the wrap" )

-- skeletalAnimationName follows animation and variant
state:selectAnimation( "jump" )
state:advanceVariant()
state:advanceVariant()
check( state:skeletalAnimationName() == "jump_3", "skeletalAnimationName is jump_3" )

-- Instances do not share state
local other = newState()
check( other:getAnimation() == "idle" and other:getVariant() == 1, "a new instance starts fresh" )
check( state:getAnimation() == "jump", "another instance leaves this one alone" )

print( checks .. " checks, " .. failures .. " failures" )

if failures > 0 then
	os.exit( 1 )
end
