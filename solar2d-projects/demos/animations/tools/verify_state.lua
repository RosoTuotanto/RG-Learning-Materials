-- Checks scripts/demoState.lua under stock Lua 5.1. Run from anywhere: lua5.1 tools/verify_state.lua

local root = string.match( arg[0], "^(.*)/tools/[^/]*$" ) or "."
package.path = root .. "/?.lua;" .. package.path

local animations = require( "data.animations" )
local outfits = require( "data.outfits" )
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

local plays = animations.skeletal.plays

-- Fixed plays rather than the data's, so the multi-play path is covered whatever the demo uses.
local testPlays = { idle = 1, walk = 1, jump = 2 }

-- Fixed options too, with a three-option slot so the wrap is tested past two.
local testOutfits = {
	shirt = { "yellow", "red" },
	pants = { "blue", "grey" },
	hat = { "none", "cap", "beanie" },
}

local function newState()
	return demoState.new({
		animations = { "idle", "walk", "jump" },
		variantCount = 3,
		plays = testPlays,
		outfitOptions = testOutfits,
	})
end

-- Records plays until the current variant is done. Returns how many plays that took.
local function playsUntilDone( state )
	local count = 0

	repeat
		count = count + 1
	until state:recordPlay() or count > 10

	return count
end

-- The data the scene passes in
check( animations.skeletal.variants == 3, "data/animations.lua builds three variants of each animation" )

for i = 1, #animations.names do
	local name = animations.names[i]
	check( type( plays[name] ) == "number" and plays[name] >= 1, "every animation plays its variants at least once: " .. name )
end

-- The outfit data the scene passes in
for i = 1, #outfits.slots do
	local slot = outfits.slots[i]
	local options = outfits.options[slot]
	check( type( options ) == "table" and #options >= 2, "data/outfits.lua gives the " .. slot .. " slot at least two options" )
end

check( table.concat( outfits.slots, "," ) == "shirt,pants,flowers", "the outfit buttons are shirt, pants and flowers, top to bottom" )
check( table.concat( outfits.options.shirt, "," ) == "yellow,red", "the shirt starts yellow and swaps to red" )
check( table.concat( outfits.options.pants, "," ) == "blue,grey", "the trousers start blue and swap to grey" )
check( outfits.options.flowers[1] == "none" and #outfits.options.flowers == 2, "the bouquet starts hidden and toggles" )
local highlighted = outfits.highlighted
check( highlighted.flowers == true and not highlighted.shirt and not highlighted.pants, "only the flowers button shows an active state" )

-- Defaults
local state = newState()
check( state:getStyle() == "sprite", "default style is sprite" )
check( not state:isSkeletal(), "default style is not skeletal" )
check( state:getAnimation() == "idle", "default animation is the first name" )
check( state:getVariant() == 1, "default variant is 1" )
check( state:getVariantCount() == 3, "the variant count comes from params" )
check( state:skeletalAnimationName() == "idle_1", "default skeletal name is idle_1" )

-- Each variant plays its animation's number of times, then the next one starts
state:selectAnimation( "walk" )
check( playsUntilDone( state ) == testPlays.walk, "a walk variant is done after " .. testPlays.walk .. " play" )

state:selectAnimation( "jump" )
check( playsUntilDone( state ) == testPlays.jump, "a jump variant is done after " .. testPlays.jump .. " plays" )
check( state:getVariant() == 1, "recording plays does not move to the next variant on its own" )

state = newState()
state:selectAnimation( "jump" )
check( state:recordPlay() == false, "the first of two jump plays leaves the variant running" )
check( state:advanceVariant() == 2, "advanceVariant moves to variant 2" )
check( state:recordPlay() == false, "advancing counts the next variant's plays from zero" )
check( state:recordPlay() == true, "the second play of jump_2 finishes it" )

-- restartVariant counts the current variant's plays from zero again
state = newState()
state:selectAnimation( "jump" )
state:recordPlay()
state:restartVariant()
check( state:recordPlay() == false and state:getVariant() == 1, "a restart forgets the plays already counted" )

-- The variants wrap from the last back to 1
state = newState()
state:selectAnimation( "walk" )
check( state:advanceVariant() == 2, "advanceVariant 1 -> 2" )
check( state:skeletalAnimationName() == "walk_2", "variant 2 composes walk_2" )
check( state:advanceVariant() == 3, "advanceVariant 2 -> 3" )
check( state:advanceVariant() == 1, "advanceVariant wraps 3 -> 1" )
check( state:skeletalAnimationName() == "walk_1", "the wrap composes walk_1" )

-- A whole cycle through the variants, plays included
state = newState()
state:selectAnimation( "jump" )
local names = {}

for i = 1, 7 do
	names[i] = state:skeletalAnimationName()

	if state:recordPlay() then
		state:advanceVariant()
	end
end

check( table.concat( names, "," ) == "jump_1,jump_1,jump_2,jump_2,jump_3,jump_3,jump_1", "jump cycles 1, 2, 3 and back, each played twice" )

-- Selecting an animation starts from variant 1 with no plays counted
state = newState()
state:selectAnimation( "jump" )
state:advanceVariant()
state:recordPlay()
check( state:selectAnimation( "walk" ) == true, "selectAnimation accepts walk" )
check( state:getAnimation() == "walk" and state:getVariant() == 1, "selecting walk resets the variant to 1" )
state:selectAnimation( "jump" )
check( state:recordPlay() == false, "selecting an animation forgets the plays already counted" )

state:advanceVariant()
state:selectAnimation( "jump" )
check( state:getVariant() == 1, "selecting the playing animation again also resets the variant" )

-- selectAnimation accepts only known names
state = newState()
state:advanceVariant()
check( state:selectAnimation( "run" ) == false, "selectAnimation rejects an unknown name" )
check( state:getAnimation() == "idle" and state:getVariant() == 2, "a rejected name leaves the animation and variant alone" )
check( state:selectAnimation( nil ) == false, "selectAnimation rejects nil" )
check( state:selectAnimation( "Walk" ) == false, "selectAnimation is case-sensitive" )

-- Toggling the style keeps the animation and starts from variant 1
state = newState()
state:selectAnimation( "jump" )
check( state:toggleStyle() == "skeletal", "toggleStyle returns skeletal from sprite" )
check( state:isSkeletal(), "isSkeletal after one toggle" )
state:advanceVariant()
state:recordPlay()
check( state:toggleStyle() == "sprite", "toggleStyle returns sprite from skeletal" )
check( state:getAnimation() == "jump", "a style toggle keeps the animation" )
check( state:getVariant() == 1, "a style toggle resets the variant to 1" )
state:toggleStyle()
check( state:recordPlay() == false, "a style toggle forgets the plays already counted" )

-- Outfit defaults and toggles
state = newState()
check( state:getOutfitOption( "shirt" ) == "yellow" and state:getOutfitOption( "pants" ) == "blue", "the outfit starts on each slot's first option" )
check( state:getOutfitOption( "hat" ) == "none" and not state:isOutfitChanged( "hat" ), "a slot on its first option is unchanged" )
check( state:toggleOutfit( "shirt" ) == "red" and state:isOutfitChanged( "shirt" ), "toggling the shirt swaps it to red" )
check( state:toggleOutfit( "shirt" ) == "yellow" and not state:isOutfitChanged( "shirt" ), "toggling the shirt again swaps it back" )
check( state:getOutfitOption( "pants" ) == "blue", "toggling the shirt leaves the trousers alone" )
check( state:toggleOutfit( "hat" ) == "cap" and state:toggleOutfit( "hat" ) == "beanie", "a three-option slot steps through its options" )
check( state:toggleOutfit( "hat" ) == "none", "a three-option slot wraps back to its first option" )
check( state:toggleOutfit( "scarf" ) == nil, "an unknown slot is rejected" )
check( state:getOutfitOption( "scarf" ) == nil and not state:isOutfitChanged( "scarf" ), "a rejected slot adds nothing to the outfit" )

-- Outfit toggles leave the animation alone, and the outfit survives every animation change
state = newState()
state:toggleStyle()
state:selectAnimation( "jump" )
state:advanceVariant()
state:recordPlay()
state:toggleOutfit( "shirt" )
state:toggleOutfit( "pants" )
check( state:getAnimation() == "jump" and state:getVariant() == 2, "an outfit toggle keeps the animation and variant" )
check( state:recordPlay() == true, "an outfit toggle keeps the plays already counted" )
check( state:isSkeletal(), "an outfit toggle keeps the style" )

state:advanceVariant()
state:selectAnimation( "walk" )
state:toggleStyle()
state:toggleStyle()
state:restartVariant()
check( state:getOutfitOption( "shirt" ) == "red" and state:getOutfitOption( "pants" ) == "grey", "the outfit survives variant, animation and style changes" )

-- Instances do not share state
state = newState()
state:selectAnimation( "walk" )
state:advanceVariant()
local other = newState()
check( other:getAnimation() == "idle" and other:getVariant() == 1, "a new instance starts fresh" )
check( state:getVariant() == 2, "each instance keeps its own variant" )

state:toggleOutfit( "shirt" )
check( newState():getOutfitOption( "shirt" ) == "yellow", "a new instance starts on the default outfit" )
check( testOutfits.shirt[1] == "yellow", "toggling never reorders the options passed in" )

print( checks .. " checks, " .. failures .. " failures" )

if failures > 0 then
	os.exit( 1 )
end
