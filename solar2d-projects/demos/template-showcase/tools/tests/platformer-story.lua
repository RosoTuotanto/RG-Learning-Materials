-- Drives samples.platformer-story.demo under the harness stub with key and touch events.
-- Usage, from the demo root: lua5.1 tools/tests/platformer-story.lua pie|nopie
-- The stub resolves no contacts, so gravity is switched off and the player is moved between villagers directly.

local lfs = require( "lfs" )

local route = arg[1]
local demoRoot = lfs.currentdir()
local harnessDirectory = demoRoot .. "/tools/harness"
package.path = "./?.lua;" .. package.path

local temporaryRoot = ".scratch/tmp/platformer-story-" .. route
local stub = dofile( harnessDirectory .. "/stub/solar2d.lua" )
stub.install( harnessDirectory, temporaryRoot )

local failures = 0
local checks = 0

local function check( condition, message )
	checks = checks + 1
	if not condition then
		failures = failures + 1
		print( "FAIL " .. message )
	end
end

local function steps( count )
	for _ = 1, count do
		stub.step()
	end
end

local function press( keyName )
	stub.call( stub.key, keyName, "down", false )
	steps( 1 )
	stub.call( stub.key, keyName, "up", false )
	steps( 1 )
end

-- Every descendant of group, depth first.
local function each( group, visit )
	for i = 1, ( group.numChildren or 0 ) do
		local child = group[i]
		visit( child )
		each( child, visit )
	end
end

local function isShown( object, root )
	while object and object ~= root do
		if not object.isVisible then
			return false
		end
		object = object.parent
	end
	return true
end

stub.call( dofile, "main.lua" )
local _, scene = stub.call( require, "samples.platformer-story.demo" )
stub.sceneEvent( scene, "create" )
stub.sceneEvent( scene, "show", "will" )
stub.sceneEvent( scene, "show", "did" )
require( "physics" ).setGravity( 0, 0 )
steps( 2 )

local view = scene.view
local hero, deck, box, flag
local villagers = {}

local function findObjects()
	villagers = {}
	each( view, function( object )
		if object.isGrounded then
			hero = object
		elseif object.info then
			villagers[object.info.name] = object
		elseif object.lower then
			deck = object
		elseif object.handleInput then
			box = object
		elseif object.kind == "flag" then
			flag = object
		end
	end )
end

findObjects()

-- Texts the player can see in the dialogue box, joined with " | ".
local function boxText()
	local parts = {}
	each( box, function( object )
		if type( object.text ) == "string" and object.text ~= "" and isShown( object, view ) then
			parts[#parts + 1] = object.text
		end
	end )
	return table.concat( parts, " | " )
end

local function has( text )
	return string.find( boxText(), text, 1, true ) ~= nil
end

local function walkTo( name )
	local person = villagers[name]
	hero.x, hero.y = person.x - 40, person.y
	hero:setLinearVelocity( 0, 0 )
	steps( 3 )
	check( person.prompt.isVisible, name .. ": Talk prompt shown when in reach" )
end

local function bridgeBodyCount()
	local count = 0
	for i = 1, #stub.world.bodies do
		local body = stub.world.bodies[i]
		if body.isGround and body.width == 9 * 36 then
			count = count + 1
		end
	end
	return count
end

-- Tilda asks for the favour.
walkTo( "Tilda" )
press( "e" )
check( box.isVisible, "Tilda: E opens the dialogue" )
check( not villagers.Tilda.prompt.isVisible, "Tilda: prompt hides while talking" )
check( has( "Tilda" ) and has( "Bram forgot his lunch again." ), "Tilda: first line, got " .. boxText() )

-- Movement keys do nothing while talking.
stub.call( stub.key, "d", "down", false )
steps( 10 )
local vx = hero:getLinearVelocity()
check( vx == 0, "talking: player ignores movement, vx " .. tostring( vx ) )
stub.call( stub.key, "d", "up", false )

press( "enter" )
check( has( "Would you take him this pie?" ) and has( "Take the pie to Bram" ) and has( "Not right now" ), "Tilda: choices shown, got " .. boxText() )

if route == "pie" then
	-- Clicks the first choice.
	local choice
	each( box, function( object )
		if object.index == 1 and object.target then
			choice = object
		end
	end )
	local bounds = choice.contentBounds
	local x, y = ( bounds.xMin + bounds.xMax ) * 0.5, ( bounds.yMin + bounds.yMax ) * 0.5
	stub.call( stub.touchAt, x, y, "began" )
	stub.call( stub.touchAt, x, y, "ended" )
	steps( 1 )
	check( has( "Bless you. Don't eat it on the way." ), "Tilda: pie reply, got " .. boxText() )
	press( "e" )
else
	press( "down" )
	press( "enter" )
	check( has( "It won't stay warm forever." ), "Tilda: not now reply, got " .. boxText() )

	-- A click anywhere advances a line without choices.
	stub.call( stub.touchAt, 480, 300, "began" )
	stub.call( stub.touchAt, 480, 300, "ended" )
	steps( 1 )
end

check( not box.isVisible, "Tilda: dialogue closed" )
steps( 2 )
check( not box.isVisible, "Tilda: the closing key does not reopen the dialogue" )

-- Pip, opened with Up, which must not also jump.
walkTo( "Pip" )
press( "up" )
local _, vy = hero:getLinearVelocity()
check( box.isVisible and vy == 0, "Pip: Up opens the dialogue without a jump, vy " .. tostring( vy ) )
check( has( "Bram's been grumpy since breakfast." ), "Pip: line before the bridge, got " .. boxText() )
press( "enter" )

-- Bram.
walkTo( "Bram" )
press( "e" )

if route == "pie" then
	check( has( "Is that Tilda's pie? Why didn't you say so!" ), "Bram: pie line, got " .. boxText() )
	press( "enter" )
	check( has( "Stand back. Bridge coming down. Mind your toes." ), "Bram: bridge line, got " .. boxText() )
	press( "enter" )
	steps( 120 )
	check( deck.rotation == 0, "bridge: deck lowered, rotation " .. tostring( deck.rotation ) )
	check( bridgeBodyCount() == 1, "bridge: one static walkway body, found " .. bridgeBodyCount() )

	walkTo( "Bram" )
	press( "e" )
	check( has( "Best bridge keeper in the valley. When fed." ), "Bram: afterwards, got " .. boxText() )
	press( "enter" )

	walkTo( "Pip" )
	press( "e" )
	check( has( "You got Bram his pie? Now he'll nap till supper." ), "Pip: after the bridge, got " .. boxText() )
	press( "enter" )

	walkTo( "Tilda" )
	press( "e" )
	check( has( "I heard the bridge. He liked the pie then." ), "Tilda: after the bridge, got " .. boxText() )
	press( "enter" )

	-- The flag past the river.
	hero.x, hero.y = flag.x, flag.y
	steps( 3 )
	local closing = false
	each( view, function( object )
		if object.text == "You crossed the river!" and isShown( object, view ) then
			closing = true
		end
	end )
	check( closing, "flag: closing line shown" )

	steps( 200 )
	findObjects()
	check( deck.rotation == 90 and bridgeBodyCount() == 0, "restart: bridge raised again" )
	check( math.abs( hero.x - 2.5 * 36 ) < 1, "restart: player back at the start, x " .. tostring( hero.x ) )
else
	check( has( "The bridge stays up. I don't lower bridges on an empty stomach." ), "Bram: refusal, got " .. boxText() )
	press( "enter" )
	steps( 120 )
	check( deck.rotation == 90 and bridgeBodyCount() == 0, "bridge: stays raised" )

	-- Falling into the river puts the player back on the respawn spot.
	hero.x, hero.y = deck.x - 100, 18 * 36 + 200
	steps( 2 )
	check( math.abs( hero.x - 29.5 * 36 ) < 1, "river: respawned, x " .. tostring( hero.x ) )
end

stub.sceneEvent( scene, "hide", "will" )
stub.sceneEvent( scene, "hide", "did" )
stub.sceneEvent( scene, "destroy" )
check( _G["WEAVERxRosoVillage"] == nil, "destroy: Weaver cache cleared" )

os.execute( "rm -rf '" .. temporaryRoot .. "'" )

for i = 1, #stub.errorOrder do
	failures = failures + 1
	print( "ERROR " .. stub.errorOrder[i].traceback )
end

print( ( failures == 0 and "OK " or "FAIL " ) .. route .. ": " .. checks .. " checks, " .. failures .. " failures" )
os.exit( failures == 0 and 0 or 1 )
