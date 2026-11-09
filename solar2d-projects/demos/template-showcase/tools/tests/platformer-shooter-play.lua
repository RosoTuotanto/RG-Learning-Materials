-- Stub play test: turrets shoot a player in sight, clicks shoot turrets down through a moved camera, and clearing restarts.
-- Run from the demo root: lua5.1 tools/tests/platformer-shooter-play.lua

local lfs = require( "lfs" )

local demoRoot = lfs.currentdir()
local harnessDirectory = demoRoot .. "/tools/harness"
package.path = "./?.lua;" .. harnessDirectory .. "/?.lua;" .. package.path

local stub = dofile( harnessDirectory .. "/stub/solar2d.lua" )
stub.install( harnessDirectory, ".scratch/tmp/platformer-shooter-play" )
stub.call( dofile, "main.lua" )

local failures = 0
local function check( name, condition )
	if not condition then
		failures = failures + 1
		print( "FAIL " .. name )
	end
end

local scene = require( "samples.platformer-shooter.demo" )
stub.sceneEvent( scene, "create" )
stub.sceneEvent( scene, "show", "will" )
stub.sceneEvent( scene, "show", "did" )

local function walk( group, visit )
	for i = 1, group.numChildren or 0 do
		local child = group[i]
		visit( child )
		walk( child, visit )
	end
end

local function find()
	local found = { turrets = {}, bullets = 0 }
	walk( scene.view, function( object )
		if object.isGrounded then
			found.hero = object
		elseif object.isTurret then
			found.turrets[#found.turrets + 1] = object
		elseif object.expiresAt then
			found.bullets = found.bullets + 1
		elseif object.text == "Area cleared" and object.isVisible then
			found.cleared = true
		elseif object.text == "Defeated" and object.isVisible then
			found.defeated = true
		end
	end )
	return found
end

-- The stub reports contacts but does not push bodies apart, so the test holds the player where it stands.
local pin = nil

local function run( frames )
	for _ = 1, frames do
		stub.step()

		if pin and stub.isAlive( pin.hero ) then
			pin.hero.x, pin.hero.y = pin.x, pin.y
			pin.hero:setLinearVelocity( 0, 0 )
		end
	end
end

local function standAt( hero, x, y )
	pin = { hero = hero, x = x, y = y }
	hero.x, hero.y = x, y
	hero:setLinearVelocity( 0, 0 )
end

run( 30 )
local state = find()
local hero = state.hero
check( "five turrets", #state.turrets == 5 )
check( "no damage at the start", hero.hp == 5 )

-- Stand on the platform left of the upper-left turret, in its sight.
standAt( hero, 9.5 * 36, 10.5 * 36 - 6 )
local bulletsSeen = 0
for _ = 1, 240 do
	run( 1 )
	bulletsSeen = math.max( bulletsSeen, find().bullets )
end
check( "turret bullets fly (" .. bulletsSeen .. ")", bulletsSeen > 0 )
check( "a turret in sight hurts the player (hp " .. hero.hp .. ")", hero.hp < 5 )

-- Behind the cover wall on the ground, far turrets cannot reach.
hero.hp = 100
local cleared = 0
local turretsLeft = find().turrets
local stands = {}
for i = 1, #turretsLeft do
	stands[i] = { turretsLeft[i].x - 100, turretsLeft[i].y - 6 }
end

local cameraMoves = 0
local lastWorldX = hero.parent.x
for i = 1, #turretsLeft do
	local target = turretsLeft[i]
	standAt( hero, stands[i][1], stands[i][2] )
	run( 60 )

	if hero.parent.x ~= lastWorldX then
		cameraMoves = cameraMoves + 1
		lastWorldX = hero.parent.x
	end

	for _ = 1, 8 do
		if not stub.isAlive( target ) then
			break
		end

		hero.hp = 100
		local contentX, contentY = hero.parent:localToContent( target.x, target.y )
		stub.mouseAt( contentX, contentY, "move", false )
		stub.touchAt( contentX, contentY, "began" )
		stub.touchAt( contentX, contentY, "ended" )
		run( 20 )
	end

	if not stub.isAlive( target ) then
		cleared = cleared + 1
	end
end

check( "every turret shot down (" .. cleared .. "/5)", cleared == 5 )
check( "the camera moved between turrets (" .. cameraMoves .. ")", cameraMoves >= 2 )
check( "Area cleared shown", find().cleared )

pin = nil
run( 150 )
check( "level restarted with five turrets", #find().turrets == 5 and find().hero.hp == 5 )

-- One hit from a turret in sight defeats a player on 1 HP, and the level comes back.
hero = find().hero
hero.hp = 1
standAt( hero, 9.5 * 36, 10.5 * 36 - 6 )
local wasDefeated = false
for _ = 1, 240 do
	run( 1 )
	wasDefeated = wasDefeated or find().defeated == true
end
check( "Defeated shown", wasDefeated )
pin = nil
run( 150 )
check( "restarted after defeat", find().hero ~= hero and find().hero.hp == 5 )

stub.sceneEvent( scene, "hide", "will" )
stub.sceneEvent( scene, "hide", "did" )

for i = 1, #stub.errorOrder do
	print( "ERROR " .. stub.errorOrder[i] )
	failures = failures + 1
end

print( failures == 0 and "OK play test" or "FAILED play test" )
os.exit( failures == 0 and 0 or 1 )
