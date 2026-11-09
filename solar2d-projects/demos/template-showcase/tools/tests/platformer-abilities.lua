-- Checks for platformer-abilities: the movement rules headless, rooms from the Tiled map, the ledge and the chasm against the
-- movement, landing without a bounce, facing, and a play-through of the real scene.
-- Usage, from the demo root: lua5.1 tools/tests/platformer-abilities.lua [--skip-reach]
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
stub.install( harnessDirectory, ".scratch/tmp/platformer-abilities" )

local json = require( "json" )
local movement = require( "samples.platformer-abilities.classes.movement" )
local rooms = require( "samples.platformer-abilities.classes.rooms" )
local settings = require( "samples.platformer-abilities.data.settings" )
local config = settings.player

local size = settings.sheets.tiles.displaySize
local characterSize = settings.sheets.characters.displaySize

local mapData = json.decodeFile( system.pathForFile( settings.map.folder .. "/" .. settings.map.file ) )

local mapProperties = {}
for i = 1, #mapData.properties do
	mapProperties[mapData.properties[i].name] = mapData.properties[i].value
end

local roomWidth = mapProperties.roomColumns * size
local roomHeight = mapProperties.roomRows * size

local layers = {}
for i = 1, #mapData.layers do
	layers[mapData.layers[i].name] = mapData.layers[i]
end

local function objectsOfType( typeName )
	local found = {}
	local objects = layers.game.objects

	for i = 1, #objects do
		if objects[i].type == typeName then
			found[#found + 1] = objects[i]
		end
	end

	return found
end

--------------------------------------------------------------------------------------
-- Movement rules

local function newFrame( overrides )
	local frame = { now = 0, isGrounded = false, runDirection = 0, isJumpHeld = false, isJumpPressed = false, isDashPressed = false, vx = 0, vy = 0 }
	for key, value in pairs( overrides ) do
		frame[key] = value
	end
	return frame
end

local function step( mover, overrides )
	local result = mover:update( newFrame( overrides ) )
	local copy = {}
	for key, value in pairs( result ) do
		copy[key] = value
	end
	return copy
end

do
	local mover = movement.new( config )
	step( mover, { now = 0, isGrounded = true } )
	local air = step( mover, { now = 500, isJumpPressed = true, isJumpHeld = true, vy = 100 } )
	check( air.event == nil and air.impulseY == 0, "double jump refused without the ability" )

	local dash = step( mover, { now = 520, isDashPressed = true } )
	check( dash.event == nil and dash.gravityScale == 1, "dash refused without the ability" )

	local ground = step( mover, { now = 600, isGrounded = true, isJumpPressed = true, isJumpHeld = true } )
	check( ground.event == "jump" and ground.impulseY == -config.jumpImpulse, "ground jump works without abilities" )
end

do
	local mover = movement.new( config )
	mover.abilities.doubleJump = true
	step( mover, { now = 0, isGrounded = true } )

	local first = step( mover, { now = 500, isJumpPressed = true, isJumpHeld = true, vy = 100 } )
	check( first.event == "jump" and first.impulseY == -config.airJumpImpulse and first.vy == 0, "double jump allowed once in the air" )

	step( mover, { now = 520, vy = 50 } )
	local second = step( mover, { now = 540, isJumpPressed = true, isJumpHeld = true, vy = 60 } )
	check( second.event == nil, "second air jump refused" )

	step( mover, { now = 700, isGrounded = true } )
	step( mover, { now = 900 } )
	local refreshed = step( mover, { now = 1100, isJumpPressed = true, isJumpHeld = true, vy = 80 } )
	check( refreshed.event == "jump" and refreshed.impulseY == -config.airJumpImpulse, "double jump refreshed on landing" )

	-- With the air jump spent, a press just before landing is buffered and fires as the ground jump.
	local bufferMover = movement.new( config )
	bufferMover.abilities.doubleJump = true
	step( bufferMover, { now = 0, isGrounded = true } )
	step( bufferMover, { now = 500, isJumpPressed = true, isJumpHeld = true, vy = 100 } )
	step( bufferMover, { now = 520, vy = 50 } )
	local early = step( bufferMover, { now = 800, isJumpPressed = true, isJumpHeld = true, vy = 200 } )
	check( early.event == nil, "press with the air jump spent does nothing in the air" )
	local landing = step( bufferMover, { now = 800 + config.jumpBufferTime - 20, isGrounded = true, isJumpHeld = true } )
	check( landing.event == "jump" and landing.impulseY == -config.jumpImpulse, "buffered press fires as the ground jump on landing" )
	step( bufferMover, { now = 1100, isJumpHeld = false, vy = 10 } )
	local airAgain = step( bufferMover, { now = 1200, isJumpPressed = true, isJumpHeld = true, vy = 10 } )
	check( airAgain.impulseY == -config.airJumpImpulse, "air jump available after the buffered ground jump" )

	-- A jump inside coyote time is the ground jump and leaves the air jump unused.
	local coyoteMover = movement.new( config )
	coyoteMover.abilities.doubleJump = true
	step( coyoteMover, { now = 0, isGrounded = true } )
	local coyote = step( coyoteMover, { now = config.coyoteTime - 10, isJumpPressed = true, isJumpHeld = true } )
	check( coyote.impulseY == -config.jumpImpulse, "coyote jump is the ground jump" )
	step( coyoteMover, { now = 200, isJumpHeld = false, vy = 10 } )
	local after = step( coyoteMover, { now = 300, isJumpPressed = true, isJumpHeld = true, vy = 10 } )
	check( after.impulseY == -config.airJumpImpulse, "air jump still available after a coyote jump" )
end

do
	local mover = movement.new( config )
	mover.abilities.dash = true
	step( mover, { now = 0, isGrounded = true, runDirection = -1 } )

	local dash = step( mover, { now = 500, isDashPressed = true } )
	check( dash.event == "dash" and dash.vx == -config.dash.speed and dash.vy == 0 and dash.gravityScale == 0, "dash goes horizontally in the facing direction" )

	local ending = step( mover, { now = 500 + config.dash.time + 1, vy = 0 } )
	check( ending.vx == -config.dash.speed * config.dash.endFactor and ending.gravityScale == 1, "dash ends with the carried speed" )

	local again = step( mover, { now = 900, isDashPressed = true, vy = 100 } )
	check( again.event == nil, "only one dash per air time" )

	step( mover, { now = 1000, isGrounded = true } )
	local refreshed = step( mover, { now = 1200, isDashPressed = true, vy = 100 } )
	check( refreshed.event == "dash", "dash refreshed on landing" )
end

do
	local mover = movement.new( config )
	mover.abilities.dash = true
	step( mover, { now = 0, isGrounded = true, runDirection = -1 } )
	local turned = step( mover, { now = 100, isGrounded = true, runDirection = 1, isDashPressed = true } )
	check( turned.vx == config.dash.speed, "dash pressed with the opposite direction goes that way, vx " .. turned.vx )

	-- During the carry after a ground dash the held direction still decides the next dash.
	local carryStart = 100 + config.dash.time + 1
	step( mover, { now = carryStart, isGrounded = true, runDirection = -1 } )
	local inCarry = step( mover, { now = carryStart + 20, isGrounded = true, runDirection = -1, isDashPressed = true } )
	check( inCarry.vx == -config.dash.speed, "dash inside the carry lock follows the held direction, vx " .. inCarry.vx )
end

-- Facing
do
	local mover = movement.new( config )
	local first = step( mover, { now = 0, isGrounded = true } )
	check( first.facing == config.startDirection, "the player starts facing its start direction" )

	mover.abilities.dash = true
	local dashLeft = step( mover, { now = 16, isGrounded = true, runDirection = -1, isDashPressed = true } )
	check( dashLeft.event == "dash" and dashLeft.vx < 0 and dashLeft.facing == -1, "a dash pressed with left turns the player left" )

	mover:reset()
	local reset = step( mover, { now = 1000 } )
	check( reset.facing == config.startDirection, "a reset faces the start direction" )
end

--------------------------------------------------------------------------------------
-- Rooms from world positions

do
	local map = rooms.new( mapData, settings.roomMargin )

	check( mapData.width == 4 * mapProperties.roomColumns and mapData.height == mapProperties.roomRows, "the map is four rooms side by side" )
	check( map:indexAt( 10, 10 ) == 1 and map:indexAt( roomWidth - 1, 300 ) == 1, "room 1 positions" )
	check( map:indexAt( roomWidth, 300 ) == 2 and map:indexAt( roomWidth * 3.5, 300 ) == 4, "rooms 2 and 4 positions" )
	check( map:indexAt( roomWidth * 2.5, roomHeight + 500 ) == 3, "below the level counts as the room above" )
	check( map:indexAt( -50, -50 ) == 1 and map:indexAt( roomWidth * 9, 0 ) == 4, "outside the level clamps to the nearest room" )

	local margin = settings.roomMargin
	local edgeMap = rooms.new( mapData, margin )
	local edge = 2 * roomWidth
	local stays = true
	local current = 2
	for i = 1, 20 do
		current = edgeMap:indexFrom( current, edge + ( i % 2 == 0 and 1 or -1 ) * ( margin - 1 ), 300 )
		stays = stays and current == 2
	end
	check( stays, "wobbling across the room 2/3 edge inside the margin stays in room 2" )
	check( edgeMap:indexFrom( 2, edge + margin + 1, 300 ) == 3, "past the margin switches to room 3" )
	check( edgeMap:indexFrom( 3, edge - margin + 1, 300 ) == 3, "back inside the margin stays in room 3" )
	check( margin > settings.sheets.characters.displaySize * 0.5, "margin keeps the whole sprite in the new room" )

	local x, y = map:centerOf( 3 )
	check( x == roomWidth * 2.5 and y == roomHeight * 0.5, "room 3 centre" )
end

--------------------------------------------------------------------------------------
-- The map against the movement: room 2's ledge needs the double jump, room 3's chasm the double jump and the dash.

if arg[1] ~= "--skip-reach" then
	local reach = dofile( demoRoot .. "/tools/tests/support/platformer-abilities-reach.lua" )
	local levelGrid = layers.level

	local function isSolid( column, row )
		return levelGrid.data[( row - 1 ) * levelGrid.width + column] ~= 0
	end

	-- Entries stand on the bottom edge of their tile, so the ledge is the drop from room 3's entry to room 2's.
	local roomMap = rooms.new( mapData, settings.roomMargin )
	local entryFeet = {}
	local entries = objectsOfType( "entry" )
	for i = 1, #entries do
		entryFeet[roomMap:indexAt( entries[i].x, entries[i].y )] = entries[i].y + characterSize * 0.5
	end
	local ledgeHeight = entryFeet[2] - entryFeet[3]

	-- The chasm is the open run in room 3 of the floor row under the dash pickup's tile.
	local floorRow = math.floor( objectsOfType( "dash" )[1].y / size ) + 2
	local firstColumn = 2 * mapProperties.roomColumns + 1
	local pitStart, pitEnd
	for column = firstColumn, firstColumn + mapProperties.roomColumns - 1 do
		if not isSolid( column, floorRow ) then
			pitStart = pitStart or column
			pitEnd = column
		end
	end
	local gapWidth = ( pitEnd - pitStart + 1 ) * size

	local ceilingRow = floorRow - 1
	while ceilingRow > 1 and not isSolid( pitStart, ceilingRow ) do
		ceilingRow = ceilingRow - 1
	end
	local clearance = ( floorRow - 1 - ceilingRow ) * size

	local heights = reach.heights()
	local margin = size * 0.5
	check( heights.singleJump + margin < ledgeHeight, "ledge out of reach of a single jump" )
	check( heights.doubleJump > ledgeHeight + margin, "ledge in reach of a double jump" )

	-- One ability alone must fall short even of a chasm half a tile narrower.
	local runUp = 4 * size
	local withoutDash, withoutAirJump = reach.crossesWithOneAbility( gapWidth - margin, clearance, runUp )
	check( not withoutDash, "chasm out of reach without the dash" )
	check( not withoutAirJump, "chasm out of reach without the double jump" )

	-- Showcase challenges pass without tight timing: after a jump at the edge, any dash press across minDashRange
	-- leaves at least minJumpWindow for the double jump.
	local minJumpWindow, minDashRange = 400, 500
	local crossing = reach.crossingWindows( gapWidth, clearance, runUp, minJumpWindow )
	print( string.format( "ledge %d (single jump %.1f, double jump %.1f); chasm %d with %d free above: "
		.. "widest double jump window %.0f ms, dashes with a %d ms window span %.0f ms",
		ledgeHeight, heights.singleJump, heights.doubleJump, gapWidth, clearance, crossing.widestWindow, minJumpWindow, crossing.dashRange ) )
	check( crossing.dashRange >= minDashRange, "dashes with a " .. minJumpWindow .. " ms double jump window span at least " .. minDashRange .. " ms" )
end

--------------------------------------------------------------------------------------
-- Play-through of the real scene. The stub resolves no contacts, so after the landing checks gravity is off and the
-- player is moved between spots.

local function steps( count )
	for _ = 1, count do
		stub.step()
	end
end

local function press( keyName )
	stub.call( stub.key, keyName, "down", false )
	steps( 1 )
	stub.call( stub.key, keyName, "up", false )
end

local function each( group, visit )
	for i = 1, ( group.numChildren or 0 ) do
		local child = group[i]
		visit( child )
		each( child, visit )
	end
end

stub.call( dofile, "main.lua" )
local _, scene = stub.call( require, "samples.platformer-abilities.demo" )
local camera = require( "samples.platformer-abilities.libs.camera" )
stub.sceneEvent( scene, "create" )
stub.sceneEvent( scene, "show", "will" )
stub.sceneEvent( scene, "show", "did" )

local view = scene.view
local hero, goal, messageText
local spots, icons = {}, {}

local function findObjects()
	spots, icons = {}, {}
	each( view, function( object )
		local internal = rawget( object, "_stub" )
		local filename = internal and internal.filename or ""

		if object.grant then
			hero = object
		elseif object.kind == "goal" then
			goal = object
		elseif object.kind == "pickup" then
			spots[object.ability] = object
		elseif filename:find( "pickup" ) then
			icons[#icons + 1] = object
		elseif object.text ~= nil and object.size == settings.hud.messageSize then
			messageText = object
		end
	end )
end

findObjects()

-- Before the first frame, so nothing has turned the player yet.
check( hero.xScale == config.startDirection * config.artFacing, "the player spawns facing its start direction" )
check( config.artFacing == -1, "settings record that the player art faces left" )

local function bodyElements( object )
	local internal = rawget( object, "_stub" )
	return internal and internal.body and internal.body.elements
end

local solidBodies = {}
local bouncyElements = 0

each( view, function( object )
	local elements = bodyElements( object )
	if not elements then
		return
	end

	for i = 1, #elements do
		if elements[i].bounce ~= 0 then
			bouncyElements = bouncyElements + 1
		end
	end

	if object.bodyType == "static" and not elements[1].isSensor then
		solidBodies[#solidBodies + 1] = object
	end
end )

check( #solidBodies > 0, "the map has ground bodies" )
check( bouncyElements == 0, "no body element bounces, found " .. bouncyElements )

-- Landing and jumping in room 1, with gravity on.
do
	-- Box2D counts 30 content units per metre and returns no bounce below 1 metre per second.
	local unitsPerMetre = 30
	local bounceThreshold = unitsPerMetre

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
		local launchSpeed = config.jumpImpulse / hero.mass * unitsPerMetre

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

	local function landedSteps( count )
		for _ = 1, count do
			stepFrame()
		end
	end

	local function holdKey( keyName, isDown )
		stub.call( stub.key, keyName, isDown and "down" or "up", false )
	end

	-- Steps until the player lands; returns false if it never does.
	local function untilLanding()
		for _ = 1, 240 do
			if stepFrame() then
				return true
			end
		end

		return false
	end

	-- Jumps with the key held the whole way and steps until the player lands.
	local function fullJump()
		holdKey( "space", true )
		stepFrame()
		local landed = untilLanding()
		holdKey( "space", false )

		return landed
	end

	landedSteps( 30 )

	check( fullJump(), "a full jump lands again" )

	local highestRise = 0
	for _ = 1, 60 do
		stepFrame()

		local _, vy = hero:getLinearVelocity()
		highestRise = math.max( highestRise, -vy )
	end

	check( highestRise <= 0, "no upward speed after landing from a full jump, found " .. highestRise )

	-- A press that arrives during the landing frame's physics step, before that frame's update.
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

	untilLanding()
	landedSteps( 30 )

	local framesAfterLanding = { 1, 2, 4, 8, 16 }
	for i = 1, #framesAfterLanding do
		local delay = framesAfterLanding[i]
		fullJump()
		landedSteps( delay )

		holdKey( "space", true )
		stepFrame()
		holdKey( "space", false )

		check( hasJustJumped(), "a jump pressed " .. delay .. " frames after landing fires" )

		untilLanding()
		landedSteps( 30 )
	end

	local function runAndFace( keyName, direction )
		holdKey( keyName, true )
		landedSteps( 10 )
		holdKey( keyName, false )

		local vx = hero:getLinearVelocity()
		check( vx * direction > 0 and hero.xScale == direction * config.artFacing, "the player faces its run direction " .. direction )
	end

	runAndFace( "d", 1 )
	runAndFace( "a", -1 )
	landedSteps( 2 )
end

require( "physics" ).setGravity( 0, 0 )
steps( 2 )

local function isMessageShown( text )
	local group = messageText.parent
	return group.isVisible and group.alpha > 0 and messageText.text == text
end

local function velocity()
	local vx, vy = hero:getLinearVelocity()
	return vx, vy
end

-- Places the player in open air inside the given room, still.
local function placeInAir( x, y )
	hero.x, hero.y = x, y
	hero:setLinearVelocity( 0, 0 )
	steps( 12 )
end

local function cameraSettledOn( index )
	local x = camera.getPosition().x
	return math.abs( x - ( index - 0.5 ) * roomWidth ) < 1
end

local function walkAcross( index )
	placeInAir( index * roomWidth - 20, roomHeight * 0.5 )
	stub.call( stub.key, "d", "down", false )
	steps( 20 )
	stub.call( stub.key, "d", "up", false )
	steps( 4 )
	check( not cameraSettledOn( index ) and not cameraSettledOn( index + 1 ), "camera is between rooms " .. index .. " and " .. ( index + 1 ) .. " while gliding" )
	steps( 60 )
	check( cameraSettledOn( index + 1 ), "camera settles on room " .. ( index + 1 ) .. ", x " .. camera.getPosition().x )
end

check( cameraSettledOn( 1 ), "camera starts on room 1" )
check( #icons == 2 and icons[1].alpha < 1 and icons[2].alpha < 1, "both HUD icons dim at the start" )

-- Room 1: nothing works in the air before the pickups.
placeInAir( 300, 300 )
press( "space" )
local _, vy = velocity()
check( vy == 0, "no air jump before the pickup, vy " .. vy )
press( "x" )
local vx = velocity()
check( vx == 0, "no dash before the pickup, vx " .. vx )

local jumpPickup = spots.doubleJump
hero.x, hero.y = jumpPickup.x, jumpPickup.y
steps( 3 )
check( not stub.isAlive( jumpPickup ), "double jump pickup removed" )
check( icons[1].alpha == 1 and icons[2].alpha < 1, "double jump icon lit" )
check( isMessageShown( settings.abilities.doubleJump.message ), "double jump message shown" )

local channels = stub.activeChannels()
check( #channels > 0 and channels[#channels].filename:find( "pickup.wav" ), "pickup sound played" )

placeInAir( 400, 300 )
press( "space" )
_, vy = velocity()
check( vy < 0, "air jump works after the pickup, vy " .. vy )
hero:setLinearVelocity( 0, 0 )
press( "space" )
_, vy = velocity()
check( vy == 0, "only one air jump, vy " .. vy )

steps( math.ceil( ( settings.hud.messageTime + settings.hud.messageFadeTime ) / 1000 * 60 ) + 5 )
check( messageText.parent.alpha == 0, "pickup message fades out" )

walkAcross( 1 )
walkAcross( 2 )

-- Room 3: the dash. The air above the dash pickup is open up to the room's top.
local dashPickup = spots.dash
local shaftX = dashPickup.x
hero.x, hero.y = dashPickup.x, dashPickup.y
steps( 3 )
check( not stub.isAlive( dashPickup ) and icons[2].alpha == 1, "dash pickup removed and its icon lit" )
check( isMessageShown( settings.abilities.dash.message ), "dash message shown" )

-- The dash checks run in room 2's open air, where the stub cannot run the dash into a wall that would count as landing.
local airX = roomWidth + 4 * size
placeInAir( airX, 300 )
stub.call( stub.key, "a", "down", false )
steps( 3 )
stub.call( stub.key, "a", "up", false )
stub.call( stub.key, "d", "down", false )
press( "x" )
stub.call( stub.key, "d", "up", false )
vx = velocity()
check( vx == config.dash.speed, "dash works after the pickup, vx " .. vx )
check( hero.xScale == config.artFacing, "a dash to the right turns the player right" )
steps( 30 )
placeInAir( airX, 300 )
press( "x" )
vx = velocity()
check( vx ~= config.dash.speed, "second dash in the air refused, vx " .. vx )

placeInAir( shaftX, 400 )
steps( 60 )

-- Falling out of room 3 respawns at its entry with both abilities kept.
hero.y = roomHeight + settings.fallMargin + 50
steps( 2 )
local entry
local entries = objectsOfType( "entry" )
for i = 1, #entries do
	if entries[i].x > 2 * roomWidth and entries[i].x < 3 * roomWidth then
		entry = entries[i]
	end
end
check( math.abs( hero.x - entry.x ) < 1 and hero.y < roomHeight, "respawn at room 3's entry, x " .. hero.x .. " y " .. hero.y )
check( hero.xScale == config.startDirection * config.artFacing, "a respawn faces the start direction" )
check( cameraSettledOn( 3 ), "camera stays on room 3 after the respawn" )
placeInAir( shaftX, 400 )
press( "space" )
_, vy = velocity()
check( vy < 0, "double jump kept after the respawn" )

walkAcross( 3 )

-- Room 4: the goal.
hero.x, hero.y = goal.x, goal.y
steps( 3 )
check( isMessageShown( settings.text.complete ), "\"You found everything\" shown" )
steps( math.ceil( settings.completeDelay / 1000 * 60 ) + 5 )

findObjects()
check( spots.doubleJump and spots.dash and icons[1].alpha < 1 and icons[2].alpha < 1, "restart brings back the pickups and dims the icons" )
check( cameraSettledOn( 1 ) and hero.x < roomWidth, "restart starts in room 1" )
check( not messageText.parent.isVisible, "restart hides the message" )

placeInAir( 300, 300 )
press( "space" )
_, vy = velocity()
check( vy == 0, "restart clears the double jump, vy " .. vy )
press( "x" )
vx = velocity()
check( vx == 0, "restart clears the dash, vx " .. vx )

stub.sceneEvent( scene, "hide", "will" )
stub.sceneEvent( scene, "hide", "did" )
steps( 5 )
stub.sceneEvent( scene, "destroy" )

for i = 1, #stub.errorOrder do
	failures = failures + 1
	print( "ERROR " .. stub.errorOrder[i] )
end

print( string.format( "%d checks, %d failures", checks, failures ) )
os.exit( failures == 0 and 0 or 1 )
