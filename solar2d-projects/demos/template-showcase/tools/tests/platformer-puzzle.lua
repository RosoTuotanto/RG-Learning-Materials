-- Stub test: switch press and hold sensors, doors that wait for a clear doorway, key pickup and exit, and restart restoring every object.
-- Run from the demo root: lua5.1 tools/tests/platformer-puzzle.lua

local lfs = require( "lfs" )

local demoRoot = lfs.currentdir()
local harnessDirectory = demoRoot .. "/tools/harness"
package.path = "./?.lua;" .. harnessDirectory .. "/?.lua;" .. package.path

local stub = dofile( harnessDirectory .. "/stub/solar2d.lua" )
stub.install( harnessDirectory, ".scratch/tmp/platformer-puzzle" )
stub.call( dofile, "main.lua" )

local settings = require( "samples.platformer-puzzle.data.settings" )

local failures = 0
local checks = 0
local function check( name, condition )
	checks = checks + 1
	if not condition then
		failures = failures + 1
		print( "FAIL " .. name )
	end
end

local soundCounts = {}
local soundNames = {}
local loadSound = audio.loadSound
audio.loadSound = function( path )
	local handle = loadSound( path )
	soundNames[handle] = path:match( "([%w]+)%.wav$" )
	return handle
end
local play = audio.play
audio.play = function( handle, options )
	local name = soundNames[handle] or "?"
	soundCounts[name] = ( soundCounts[name] or 0 ) + 1
	return play( handle, options )
end

local scene = require( "samples.platformer-puzzle.demo" )
stub.sceneEvent( scene, "create" )
stub.sceneEvent( scene, "show", "will" )
stub.sceneEvent( scene, "show", "did" )

-- Contacts come only from the fake events below.
local physics = require( "physics" )
physics.pause()

local function steps( count )
	for _ = 1, count do
		stub.step()
	end
end

local function framesFor( milliseconds )
	return math.ceil( milliseconds / ( 1000 / 60 ) ) + 2
end

local function walk( group, visit )
	for i = 1, group.numChildren or 0 do
		local child = group[i]
		visit( child )
		walk( child, visit )
	end
end

local function find()
	local found = { switches = {}, doors = {}, crates = {}, texts = {} }
	walk( scene.view, function( object )
		if object.kind == "player" then
			found.hero = object
		elseif object.kind == "crate" then
			found.crates[#found.crates + 1] = object
		elseif object.kind == "key" then
			found.key = object
		elseif object.kind == "exit" then
			found.exit = object
		elseif object.upImage then
			found.switches[#found.switches + 1] = object
		elseif object.doorwayContacts then
			found.doors[#found.doors + 1] = object
		elseif object.text then
			found.texts[object.text] = object
		end
	end )
	table.sort( found.switches, function( a, b ) return a.x < b.x end )
	table.sort( found.doors, function( a, b ) return a.x < b.x end )
	table.sort( found.crates, function( a, b ) return a.x < b.x end )
	return found
end

local function hasBody( object )
	return rawget( object, "_stub" ).body ~= nil
end

local function collide( target, other, phase, selfElement, otherElement )
	target:dispatchEvent({
		name = "collision", phase = phase, target = target, other = other,
		selfElement = selfElement, otherElement = otherElement,
	})
end

local function isPressed( switch )
	return switch.isVisible and not switch.upImage.isVisible
end

local function isOpen( door )
	return door.isOpen and not door.isBodyActive and door.openImage.isVisible and not door.isVisible
end

local function isClosed( door )
	return not door.isOpen and door.isBodyActive and not door.openImage.isVisible and door.isVisible
end

local closeFrames = framesFor( settings.puzzle.door.closeDelay )

--------------------------------------------------------------------------------------
-- Room 1: contact counting and doors

local room = find()
local hero, crate, switch, door = room.hero, room.crates[1], room.switches[1], room.doors[1]
check( "room 1 has one switch, door and crate", #room.switches == 1 and #room.doors == 1 and #room.crates == 1 )
check( "room 1 label", room.texts["Room 1"] ~= nil )
check( "switch starts released, door closed", not isPressed( switch ) and isClosed( door ) )

collide( switch, crate, "began", 2, 1 )
check( "crate presses switch", isPressed( switch ) and switch.pressContacts == 1 )
check( "door body unchanged inside the handler", door.isBodyActive == true )
check( "raised plate unchanged inside the handler", switch.upImage.isBodyActive == true )
steps( 2 )
check( "door opens a frame later", isOpen( door ) )
check( "raised plate's body goes a frame later", switch.upImage.isBodyActive == false )

collide( switch, hero, "began", 2, 1 )
collide( switch, hero, "began", 2, 2 )
collide( switch, crate, "began", 1, 1 )
check( "hero body counts, foot sensor and plate do not", switch.pressContacts == 2 )

collide( switch, crate, "ended", 2, 1 )
steps( closeFrames )
check( "one body left: still pressed, door open", isPressed( switch ) and isOpen( door ) )

collide( door.openImage, hero, "began", 2, 1 )
collide( door.openImage, hero, "began", 1, 1 )
check( "hero in doorway counted once", door.doorwayContacts == 1 )

collide( switch, hero, "ended", 2, 1 )
check( "last body leaves: released", not isPressed( switch ) and switch.pressContacts == 0 )
steps( 2 )
check( "raised plate's body returns a frame later", switch.upImage.isBodyActive == true )
steps( closeFrames * 3 )
check( "door waits while the doorway is occupied", isOpen( door ) )

collide( door.openImage, hero, "ended", 2, 1 )
steps( 2 )
check( "door waits out closeDelay", isOpen( door ) )
steps( closeFrames )
check( "door closes once clear", isClosed( door ) )

collide( switch, crate, "began", 2, 1 )
collide( switch, crate, "ended", 2, 1 )
collide( switch, crate, "began", 2, 1 )
steps( closeFrames )
check( "quick release and press keeps door open", isOpen( door ) )

-- The hold sensor along the pressed plate keeps a press going but never starts one.
collide( switch, crate, "began", 3, 1 )
collide( switch, crate, "ended", 2, 1 )
steps( closeFrames )
check( "hold sensor keeps the press after the press sensor ends", isPressed( switch ) and isOpen( door ) )
collide( switch, crate, "ended", 3, 1 )
steps( closeFrames )
check( "leaving the hold sensor releases", not isPressed( switch ) and isClosed( door ) )
collide( switch, crate, "began", 3, 1 )
steps( closeFrames )
check( "hold sensor alone does not press", not isPressed( switch ) and isClosed( door ) and switch.holdContacts == 1 )
collide( switch, crate, "ended", 3, 1 )
collide( switch, crate, "began", 2, 1 )
steps( 2 )

--------------------------------------------------------------------------------------
-- Room 1: key and exit

collide( hero, room.exit, "began", 1, 1 )
steps( 2 )
check( "exit stays shut without the key", room.exit.isVisible )

local keyStart = { x = room.key.x }
collide( hero, room.key, "began", 1, 1 )
collide( hero, room.key, "began", 1, 1 )
check( "key body kept inside the handler", hasBody( room.key ) )
steps( 2 )
check( "key body removed a frame later", not hasBody( room.key ) )
check( "hud key icon shown", ( function()
	local shown = false
	walk( scene.view, function( object )
		if object.isVisible and object.anchorX == 0 and object.width == settings.hud.keyIconSize and object.kind == nil and not object.text then
			shown = true
		end
	end )
	return shown
end )() )
hero.x, hero.y = hero.x + 30, hero.y - 5
steps( 2 )
check( "key rides above the hero", room.key.x == hero.x and room.key.y == hero.y + settings.puzzle.key.carriedOffsetY and room.key.x ~= keyStart.x )
check( "one key sound for two touches", soundCounts.key == 1 )

collide( hero, room.exit, "began", 1, 1 )
check( "exit opens", not room.exit.isVisible )
steps( framesFor( settings.nextRoomDelay ) + 5 )

--------------------------------------------------------------------------------------
-- Room 2: links and restart

room = find()
check( "room 2 built", #room.switches == 2 and #room.doors == 2 and #room.crates == 2 and room.texts["Room 2"] ~= nil )

local starts = {}
for i = 1, #room.crates do
	starts[i] = { x = room.crates[i].x, y = room.crates[i].y }
end
local heroStart = { x = room.hero.x, y = room.hero.y }
local keyStart2 = { x = room.key.x, y = room.key.y }

collide( room.switches[1], room.crates[1], "began", 2, 1 )
steps( 2 )
check( "switch a opens door A only", isOpen( room.doors[1] ) and isClosed( room.doors[2] ) )
collide( room.switches[2], room.crates[2], "began", 2, 1 )
steps( 2 )
check( "switch b opens door B", isOpen( room.doors[2] ) )

collide( room.hero, room.key, "began", 1, 1 )
steps( 2 )
room.crates[1].x = room.crates[1].x + 50
room.hero.x = room.hero.x + 100

stub.key( "r", "down" )
stub.key( "r", "up" )
steps( 2 )

local fresh = find()
check( "restart rebuilt the room", fresh.hero ~= room.hero and fresh.texts["Room 2"] ~= nil )
check( "restart: switches released",
	#fresh.switches == 2 and not isPressed( fresh.switches[1] ) and not isPressed( fresh.switches[2] ) and fresh.switches[1].pressContacts == 0 )
check( "restart: doors closed", #fresh.doors == 2 and isClosed( fresh.doors[1] ) and isClosed( fresh.doors[2] ) )
check( "restart: hero at start", fresh.hero.x == heroStart.x and fresh.hero.y == heroStart.y )
check( "restart: key back with its body",
	hasBody( fresh.key ) and fresh.key.x == keyStart2.x and math.abs( fresh.key.y - keyStart2.y ) <= settings.puzzle.key.bobHeight )
for i = 1, #fresh.crates do
	check( "restart: crate " .. i .. " at start", fresh.crates[i].x == starts[i].x and fresh.crates[i].y == starts[i].y )
end
check( "restart: old room gone", not stub.isAlive( room.hero ) and not stub.isAlive( room.crates[1] ) )

--------------------------------------------------------------------------------------
-- Room 2: solve and play again

room = fresh
collide( room.hero, room.key, "began", 1, 1 )
steps( 2 )
collide( room.hero, room.exit, "began", 1, 1 )
steps( 3 )

local button
walk( scene.view, function( object )
	if object.path and object.path.radius and object.width == settings.hud.button.width then
		button = object
	end
end )
check( "Solved shows", room.texts["Solved"] ~= nil and room.texts["Solved"].parent.isVisible )
check( "play again button found", button ~= nil )
if button then
	stub.touchObject( button, button.x, button.y, "began" )
	steps( 2 )
end
room = find()
check( "play again returns to room 1", room.texts["Room 1"] ~= nil and #room.switches == 1 and not room.texts["Solved"].parent.isVisible )

stub.sceneEvent( scene, "hide", "will" )
stub.sceneEvent( scene, "hide", "did" )
steps( 30 )
stub.sceneEvent( scene, "destroy" )
check( "no timers left after hide", stub.pendingTimerCount() == 0 )
check( "no transitions left after hide", stub.activeTransitionCount() == 0 )

for i = 1, #stub.errorOrder do
	failures = failures + 1
	print( "ERROR " .. stub.errorOrder[i] )
end

print( string.format( "%d checks, %d failures; sounds switch %d door %d key %d",
	checks, failures, soundCounts.switch or 0, soundCounts.door or 0, soundCounts.key or 0 ) )
os.exit( failures == 0 and 0 or 1 )
