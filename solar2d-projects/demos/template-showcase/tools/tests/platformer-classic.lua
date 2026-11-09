-- Checks for platformer-classic: the Tiled map's contents, landing without a bounce, jumping on landing, and facing.
-- Usage, from the demo root: lua5.1 tools/tests/platformer-classic.lua
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

local stub = dofile( harnessDirectory .. "/stub/solar2d.lua" )
stub.install( harnessDirectory, ".scratch/tmp/platformer-classic" )

local settings = require( "samples.platformer-classic.data.settings" )
local tileSize = settings.sheets.tiles.displaySize

-- Box2D counts 30 content units per metre and returns no bounce below 1 metre per second.
local unitsPerMetre = 30
local bounceThreshold = unitsPerMetre

stub.call( dofile, "main.lua" )
local _, scene = stub.call( require, "samples.platformer-classic.demo" )
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

local hero
local byKind = { enemy = {}, block = {}, coin = {}, flag = {} }
local solidBodies = {}

each( scene.view, function( object )
	if object.isGrounded then
		hero = object

	elseif object.kind and byKind[object.kind] then
		local list = byKind[object.kind]
		list[#list + 1] = object
	end

	local elements = bodyElements( object )
	if elements and object.bodyType == "static" and not elements[1].isSensor then
		solidBodies[#solidBodies + 1] = object
	end
end )

--------------------------------------------------------------------------------------
-- Map contents

check( hero ~= nil, "the map places the player" )

-- Before the first frame, so nothing has turned them yet.
check( hero.xScale == settings.player.startDirection * settings.player.artFacing, "the player spawns facing its start direction" )

for i = 1, #byKind.enemy do
	check( byKind.enemy[i].xScale == settings.enemy.startDirection * settings.enemy.artFacing, "walker " .. i .. " spawns facing its start direction" )
end

local expectedCounts = { enemy = 5, block = 5, coin = 16, flag = 1 }
for kind, count in pairs( expectedCounts ) do
	check( #byKind[kind] == count, "the map places " .. count .. " " .. kind .. " objects, found " .. #byKind[kind] )
end

-- Blocks on the same row with fewer than two free cells between them leave no gap the player can jump up through.
local blocksByRow = {}
for i = 1, #byKind.block do
	local box = byKind.block[i]
	local row = math.floor( ( box.y + settings.block.artOffsetY ) / tileSize )
	blocksByRow[row] = blocksByRow[row] or {}
	blocksByRow[row][#blocksByRow[row] + 1] = box.x
end

local narrowestGap = math.huge
for _, xs in pairs( blocksByRow ) do
	table.sort( xs )

	for i = 2, #xs do
		narrowestGap = math.min( narrowestGap, math.floor( ( xs[i] - xs[i - 1] ) / tileSize + 0.5 ) - 1 )
	end
end

check( narrowestGap >= 2, "neighbouring blocks have at least two free cells between them, narrowest gap " .. narrowestGap )

-- A coin between two blocks sits in the middle of their gap.
for row, xs in pairs( blocksByRow ) do
	for i = 2, #xs do
		for j = 1, #byKind.coin do
			local pickup = byKind.coin[j]
			local isBetween = pickup.x > xs[i - 1] and pickup.x < xs[i] and math.floor( pickup.y / tileSize ) == row

			if isBetween then
				check( pickup.x == ( xs[i - 1] + xs[i] ) * 0.5, "the coin between blocks at " .. xs[i - 1] .. " and " .. xs[i] .. " is centred" )
			end
		end
	end
end

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

--------------------------------------------------------------------------------------
-- Facing

-- The player art faces left and the walker art faces right when unmirrored.
check( settings.player.artFacing == -1, "settings record that the player art faces left" )
check( settings.enemy.artFacing == 1, "settings record that the walker art faces right" )

local function runAndFace( keyName, direction )
	holdKey( keyName, true )
	steps( 10 )
	holdKey( keyName, false )

	local vx = hero:getLinearVelocity()
	check( vx * direction > 0 and hero.xScale == direction * settings.player.artFacing, "the player faces its run direction " .. direction )
end

runAndFace( "d", 1 )
runAndFace( "a", -1 )

local walkerChecks = 0
for i = 1, #byKind.enemy do
	local walker = byKind.enemy[i]

	if bodyElements( walker ) then
		local vx = walker:getLinearVelocity()

		if vx ~= 0 then
			walkerChecks = walkerChecks + 1
			local direction = vx > 0 and 1 or -1
			check( walker.xScale == direction * settings.enemy.artFacing, "walker " .. i .. " faces its walking direction " .. direction )
		end
	end
end

check( walkerChecks > 0, "at least one walker is walking" )

-- The standing walker art's first opaque row is 16 of its 48, so its body starts 8 above the sprite's centre.
local walkerArtTop = 16 - settings.sheets.walker.displaySize * 0.5
for i = 1, #byKind.enemy do
	local walker = byKind.enemy[i]
	local elements = bodyElements( walker )

	if elements then
		check( elements[1].y1 == walkerArtTop and walker:getTopY() == walker.y + walkerArtTop, "walker " .. i .. " body top meets its art top" )
	end
end

stub.sceneEvent( scene, "hide", "will" )
stub.sceneEvent( scene, "hide", "did" )
stub.sceneEvent( scene, "destroy" )

for i = 1, #stub.errorOrder do
	failures = failures + 1
	print( "FAIL error: " .. stub.errorOrder[i].message )
end

print( ( failures == 0 and "OK " or "FAIL " ) .. ( checks - failures ) .. "/" .. checks .. " checks passed" )
os.exit( failures == 0 and 0 or 1 )
