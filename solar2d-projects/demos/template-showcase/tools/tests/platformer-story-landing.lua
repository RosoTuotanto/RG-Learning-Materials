-- Checks for platformer-story: the Tiled map's contents, landing without a bounce, jumping on landing, and facing.
-- Usage, from the demo root: lua5.1 tools/tests/platformer-story-landing.lua
local lfs = require( "lfs" )

local demoRoot = lfs.currentdir()
local harnessDirectory = demoRoot .. "/tools/harness"
package.path = "./?.lua;" .. package.path

local failures, checks = 0, 0

local function check( condition, message )
	checks = checks + 1
	if not condition then
		failures = failures + 1
		print( "FAIL " .. message )
	end
end

local temporaryRoot = ".scratch/tmp/platformer-story-landing"
local stub = dofile( harnessDirectory .. "/stub/solar2d.lua" )
stub.install( harnessDirectory, temporaryRoot )

local settings = require( "samples.platformer-story.data.settings" )
local tileSize = settings.sheets.tiles.displaySize

-- Box2D counts 30 content units per metre and returns no bounce below 1 metre per second.
local unitsPerMetre = 30
local bounceThreshold = unitsPerMetre

stub.call( dofile, "main.lua" )
local _, scene = stub.call( require, "samples.platformer-story.demo" )
stub.sceneEvent( scene, "create" )
stub.sceneEvent( scene, "show", "will" )
stub.sceneEvent( scene, "show", "did" )

--------------------------------------------------------------------------------------
-- Scene objects

local function each( group, visit )
	for i = 1, ( group.numChildren or 0 ) do
		local child = group[i]
		visit( child )
		each( child, visit )
	end
end

local function bodyElements( object )
	local internal = rawget( object, "_stub" )
	return internal and internal.body and internal.body.elements
end

local hero, deck
local villagers = {}
local mapObjects = {}
local solidBodies = {}

local function findObjects()
	solidBodies = {}

	each( scene.view, function( object )
		if object.isGrounded then
			hero = object

		elseif object.info then
			villagers[object.info.name] = object

		elseif object.lower then
			deck = object

		elseif object.type and object.name then
			mapObjects[object.type] = mapObjects[object.type] or {}
			mapObjects[object.type][#mapObjects[object.type] + 1] = object
		end

		local elements = bodyElements( object )
		if elements and object.bodyType == "static" and not elements[1].isSensor then
			solidBodies[#solidBodies + 1] = object
		end
	end )
end

findObjects()

--------------------------------------------------------------------------------------
-- Map contents

check( hero ~= nil, "the map places the player" )

-- Before the first frame, so nothing has turned them yet.
check( hero.xScale == settings.player.startDirection * settings.player.artFacing, "the player spawns facing its start direction" )

for i = 1, #settings.villagers do
	local info = settings.villagers[i]
	local person = villagers[info.name]
	check( person ~= nil, "the map places villager " .. info.name )
	check( person and person.xScale == info.direction * info.artFacing, info.name .. " spawns facing their direction" )
end

local expectedCounts = { player = 1, respawn = 1, villager = 3, bridge = 1, river = 1, flag = 1 }
for typeName, count in pairs( expectedCounts ) do
	local found = mapObjects[typeName] and #mapObjects[typeName] or 0
	check( found == count, "the map holds " .. count .. " " .. typeName .. " objects, found " .. found )
end

local bridgeArea = mapObjects.bridge and mapObjects.bridge[1]
local riverArea = mapObjects.river and mapObjects.river[1]

local isBridgeShaped = bridgeArea and bridgeArea.width == 9 * tileSize and bridgeArea.height == tileSize
check( isBridgeShaped and not bridgeArea.isVisible, "the bridge is a hidden rect nine tiles wide" )
local isUnderBridge = riverArea and riverArea.width == bridgeArea.width and riverArea.x == bridgeArea.x
check( isUnderBridge and riverArea.isVisible, "the river is a visible rect under the bridge" )
check( riverArea and riverArea.y - riverArea.height * 0.5 == bridgeArea.y + bridgeArea.height * 0.5, "the river starts right below the bridge deck" )

--------------------------------------------------------------------------------------
-- Landing and jumping

-- The stub moves bodies but resolves no contacts, so this lands the player on solid static bodies as Box2D would: the
-- larger bounce of the two elements returns that share of the landing speed, and nothing below the threshold bounces.
local function resolveLanding( previousFeetY )
	local heroElement = bodyElements( hero )[1]
	local left, right = hero.x + heroElement.x1, hero.x + heroElement.x2
	local feetY = hero.y + heroElement.y2

	for i = 1, #solidBodies do
		local edges = stub.topEdges( solidBodies[i] )

		for j = 1, #edges do
			local edge = edges[j]

			if left < edge.right and right > edge.left and previousFeetY <= edge.y + 0.01 and feetY > edge.y then
				hero.y = hero.y - ( feetY - edge.y )

				local vx, vy = hero:getLinearVelocity()
				if vy > 0 then
					local returned = vy * math.max( heroElement.bounce, edge.element.bounce )
					hero:setLinearVelocity( vx, returned > bounceThreshold and -returned or 0 )
				end

				return true
			end
		end
	end

	return false
end

-- A jump sets the upward speed to exactly this, so a rise from a bounce never passes for a jump.
local function hasJustJumped()
	local _, vy = hero:getLinearVelocity()
	local launchSpeed = settings.player.jumpImpulse / hero.mass * unitsPerMetre

	return math.abs( vy + launchSpeed ) < 0.001
end

local function feetY()
	return hero.y + bodyElements( hero )[1].y2
end

-- Steps one frame and returns whether the player landed on something during it.
local function stepFrame()
	local previous = feetY()
	stub.step()
	return resolveLanding( previous )
end

local function steps( count )
	for _ = 1, count do
		stepFrame()
	end
end

local function holdKey( keyName, isDown )
	stub.call( stub.key, keyName, isDown and "down" or "up", false )
end

local function press( keyName )
	holdKey( keyName, true )
	stepFrame()
	holdKey( keyName, false )
	stepFrame()
end

-- Jumps from the ground with the key held the whole way and steps until the player lands; returns false if it never does.
local function fullJump()
	for _ = 1, 240 do
		if hero:isGrounded() then
			break
		end

		stepFrame()
	end

	holdKey( "space", true )
	stepFrame()

	for _ = 1, 240 do
		if stepFrame() then
			holdKey( "space", false )
			return true
		end
	end

	holdKey( "space", false )
	return false
end

steps( 30 )
check( hero:isGrounded(), "the player stands on the ground at the start" )

do
	local landed = fullJump()
	check( landed, "a full jump lands again" )

	local highestRise, isAlwaysGrounded = 0, true
	for _ = 1, 60 do
		stepFrame()

		local _, vy = hero:getLinearVelocity()
		highestRise = math.max( highestRise, -vy )
		isAlwaysGrounded = isAlwaysGrounded and hero:isGrounded()
	end

	check( highestRise <= 0, "no upward speed after landing from a full jump, found " .. highestRise )
	check( isAlwaysGrounded, "the player stays grounded after landing" )
end

-- A press that arrives during the landing frame's physics step, before that frame's update.
do
	local isArmed = true
	local function pressOnLanding( event )
		if isArmed and event.phase == "began" and event.selfElement == 2 and event.other.isGround then
			isArmed = false
			holdKey( "space", true )
		end
	end

	holdKey( "space", true )
	stepFrame()
	holdKey( "space", false )
	hero:addEventListener( "collision", pressOnLanding )

	local isLandingJump = false
	for _ = 1, 240 do
		local previous = feetY()
		stub.step()

		if not isArmed then
			isLandingJump = hasJustJumped()
			holdKey( "space", false )
			resolveLanding( previous )
			break
		end

		resolveLanding( previous )
	end

	hero:removeEventListener( "collision", pressOnLanding )
	check( isLandingJump, "a jump pressed on the landing frame fires" )

	for _ = 1, 240 do
		if stepFrame() then
			break
		end
	end
	steps( 30 )
end

local framesAfterLanding = { 1, 2, 4, 8, 16 }
for i = 1, #framesAfterLanding do
	local delay = framesAfterLanding[i]
	fullJump()
	steps( delay )

	holdKey( "space", true )
	stepFrame()
	holdKey( "space", false )

	check( hasJustJumped(), "a jump pressed " .. delay .. " frames after landing fires" )

	for _ = 1, 240 do
		if stepFrame() then
			break
		end
	end
	steps( 30 )
end

-- The lowered bridge adds the last body; no solid element anywhere bounces.
deck:lower()
steps( 120 )
findObjects()

local bouncyCount, elementCount = 0, 0
for i = 1, #stub.world.bodies do
	local elements = bodyElements( stub.world.bodies[i] ) or {}

	for j = 1, #elements do
		if not elements[j].isSensor then
			elementCount = elementCount + 1

			if elements[j].bounce ~= 0 then
				bouncyCount = bouncyCount + 1
			end
		end
	end
end

check( elementCount > 0 and bouncyCount == 0, "every solid body element has bounce 0, " .. bouncyCount .. " of " .. elementCount .. " do not" )

--------------------------------------------------------------------------------------
-- Facing

-- The player art faces left and the villager art faces right when unmirrored.
check( settings.player.artFacing == -1, "settings record that the player art faces left" )

for i = 1, #settings.villagers do
	check( settings.villagers[i].artFacing == 1, "settings record that " .. settings.villagers[i].name .. "'s art faces right" )
end

local function runAndFace( keyName, direction )
	holdKey( keyName, true )
	steps( 10 )
	holdKey( keyName, false )

	local vx = hero:getLinearVelocity()
	check( vx * direction > 0 and hero.xScale == direction * settings.player.artFacing, "the player faces its run direction " .. direction )
end

runAndFace( "d", 1 )
runAndFace( "a", -1 )

-- Standing in reach on Tilda's right without talking leaves her facing her own direction; talking turns her to the player.
local tilda = villagers.Tilda
local tildaInfo = tilda.info
check( tildaInfo.direction == -1, "Tilda's direction faces away from a player on her right" )

hero.x, hero.y = tilda.x + 40, tilda.y
hero:setLinearVelocity( 0, 0 )
steps( 3 )
check( tilda.prompt.isVisible and tilda.xScale == tildaInfo.direction * tildaInfo.artFacing, "Tilda faces her own direction until the player talks" )

press( "e" )
check( tilda.xScale == tildaInfo.artFacing, "Tilda faces the player on her right while talking" )

stub.sceneEvent( scene, "hide", "will" )
stub.sceneEvent( scene, "hide", "did" )
stub.sceneEvent( scene, "destroy" )

os.execute( "rm -rf '" .. temporaryRoot .. "'" )

for i = 1, #stub.errorOrder do
	failures = failures + 1
	print( "FAIL error: " .. stub.errorOrder[i].message )
end

print( ( failures == 0 and "OK " or "FAIL " ) .. ( checks - failures ) .. "/" .. checks .. " checks passed" )
os.exit( failures == 0 and 0 or 1 )
