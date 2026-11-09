-- platformer-puzzle played under a Box2D-style contact solver: the Tiled rooms, facing, landing without a bounce and
-- jumping on the first grounded frame, a crate pushed onto room 1's switch staying there for 10 s, and both rooms solved.
-- Usage, from the demo root: lua5.1 tools/tests/platformer-puzzle-play.lua
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

	return condition
end

local stub = dofile( harnessDirectory .. "/stub/solar2d.lua" )
stub.install( harnessDirectory, ".scratch/tmp/platformer-puzzle-play" )

local simulation = dofile( "tools/tests/support/platformer-puzzle-physics.lua" ).install( stub )

local settings = require( "samples.platformer-puzzle.data.settings" )
local unitsPerMetre = 30
local framesPerSecond = 60

stub.call( dofile, "main.lua" )
local _, scene = stub.call( require, "samples.platformer-puzzle.demo" )
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

local room

local function findRoom()
	room = { crates = {}, switches = {}, doors = {}, texts = {}, ground = 0 }

	each( scene.view, function( object )
		if object.kind == "player" then
			room.hero = object
		elseif object.kind == "crate" then
			room.crates[#room.crates + 1] = object
		elseif object.kind == "key" then
			room.key = object
		elseif object.kind == "exit" then
			room.exit = object
		elseif object.upImage then
			room.switches[#room.switches + 1] = object
		elseif object.doorwayContacts then
			room.doors[#room.doors + 1] = object
		elseif object.text then
			room.texts[object.text] = object
		elseif object.type == "ground" and bodyElements( object ) then
			room.ground = room.ground + 1
		end
	end )

	local function byX( a, b )
		return a.x < b.x
	end

	table.sort( room.crates, byX )
	table.sort( room.switches, byX )
	table.sort( room.doors, byX )

	return room
end

local function isRoomLabel( number )
	return room.texts[settings.text.room .. number] ~= nil
end

--------------------------------------------------------------------------------------
-- Input

local heldDirection

local function holdKey( keyName, isDown )
	stub.call( stub.key, keyName, isDown and "down" or "up", false )
end

local function setDirection( direction )
	local keyName = direction < 0 and "left" or direction > 0 and "right" or nil
	if heldDirection and heldDirection ~= keyName then
		holdKey( heldDirection, false )
	end
	if keyName and keyName ~= heldDirection then
		holdKey( keyName, true )
	end
	heldDirection = keyName
end

local jumpFramesLeft = 0

local function startJump()
	holdKey( "space", true )
	jumpFramesLeft = 20
end

local stillFrames = 0

local function step()
	simulation.step()

	-- The next room replaces the whole world.
	if not stub.isAlive( room.hero ) then
		findRoom()
	end

	if jumpFramesLeft > 0 then
		jumpFramesLeft = jumpFramesLeft - 1
		if jumpFramesLeft == 0 then
			holdKey( "space", false )
		end
	end

	local vx, vy = room.hero:getLinearVelocity()
	stillFrames = ( math.abs( vx ) < 5 and math.abs( vy ) < 1 ) and stillFrames + 1 or 0
end

local function steps( count )
	for _ = 1, count do
		step()
	end
end

-- Holds a direction until isDone() is true, jumping whenever the player stands blocked unless canJump is false;
-- returns false if time runs out.
local function moveUntil( direction, isDone, seconds, canJump )
	stillFrames = 0
	setDirection( direction )

	for _ = 1, seconds * framesPerSecond do
		if isDone() then
			setDirection( 0 )
			return true
		end

		if canJump ~= false and stillFrames >= 4 and jumpFramesLeft == 0 then
			startJump()
			stillFrames = 0
		end

		step()
	end

	setDirection( 0 )
	return false
end

local function moveTo( x, seconds )
	local direction = x > room.hero.x and 1 or -1

	return moveUntil( direction, function()
		return ( room.hero.x - x ) * direction >= 0
	end, seconds or 10 )
end

local function waitUntilStill( seconds )
	for _ = 1, seconds * framesPerSecond do
		local _, vy = room.hero:getLinearVelocity()
		if math.abs( vy ) < 1 and stillFrames >= 2 then
			return true
		end
		step()
	end
	return false
end

local function feetY()
	return room.hero.y + settings.player.body.offsetY + settings.player.body.height * 0.5
end

local function isOnPlate( crate, switch )
	return math.abs( crate.x - switch.x ) < 24 and math.abs( ( crate.y + 18 ) - ( switch.y + 10 ) ) < 1.5
end

--------------------------------------------------------------------------------------
-- The Tiled rooms

findRoom()
check( isRoomLabel( 1 ), "room 1 shows its label" )
check( #room.crates == 1 and #room.switches == 1 and #room.doors == 1 and room.key and room.exit,
	"room 1 builds its crate, switch, door, key and exit from the map" )
check( room.ground > 0, "room 1's ground bodies come from the map's physics layer" )
check( room.doors[1].switches[1] == room.switches[1], "room 1's door opens with its switch" )

--------------------------------------------------------------------------------------
-- Bounce and facing

do
	local bouncy = {}
	each( scene.view, function( object )
		local elements = bodyElements( object )
		for i = 1, #( elements or {} ) do
			if not elements[i].isSensor and elements[i].bounce ~= 0 then
				bouncy[#bouncy + 1] = tostring( object.kind or object.type ) .. " at " .. object.x .. ", " .. object.y
			end
		end
	end )
	check( #bouncy == 0, "every solid body has bounce 0: " .. table.concat( bouncy, "; " ) )
end

local hero = room.hero
check( hero.xScale == settings.player.startDirection * settings.player.artFacing, "the player spawns facing its start direction" )
check( settings.player.artFacing == -1, "settings record that the player art faces left" )

steps( 30 )
check( waitUntilStill( 2 ), "the player settles on the ground at the start" )

local startX = hero.x
for direction = -1, 1, 2 do
	setDirection( direction )
	steps( 6 )
	local vx = hero:getLinearVelocity()
	check( vx * direction > 0 and hero.xScale == direction * settings.player.artFacing, "the player faces its run direction " .. direction )
	setDirection( 0 )
	steps( 6 )
end
moveTo( startX, 2 )
waitUntilStill( 1 )

--------------------------------------------------------------------------------------
-- Landing and jumping

-- A jump sets the upward speed to exactly this, so a rise from a bounce never passes for a jump.
local function hasJustJumped()
	local _, vy = hero:getLinearVelocity()
	local launchSpeed = settings.player.jumpImpulse / hero.mass * unitsPerMetre

	return math.abs( vy + launchSpeed ) < 0.001
end

do
	local floorY = feetY()
	startJump()

	local hasRisen, hasLanded = false, false
	for _ = 1, 120 do
		step()
		hasRisen = hasRisen or feetY() < floorY - 20
		if hasRisen and feetY() > floorY - 1 then
			hasLanded = true
			break
		end
	end
	check( hasLanded, "a jump lands again" )

	local highestRise = 0
	for _ = 1, 60 do
		step()
		local _, vy = hero:getLinearVelocity()
		highestRise = math.max( highestRise, -vy )
	end
	check( highestRise < 1, "no upward speed after landing, found " .. highestRise )
end

-- A press that arrives during the landing frame's physics step, before that frame's update, jumps at once.
do
	local isArmed = true
	local function pressOnLanding( event )
		if isArmed and event.phase == "began" and event.selfElement == 2 and event.other.isGround then
			isArmed = false
			holdKey( "space", true )
		end
	end

	holdKey( "space", true )
	steps( 2 )
	holdKey( "space", false )
	steps( 10 )
	hero:addEventListener( "collision", pressOnLanding )

	local isLandingJump = false
	for _ = 1, 240 do
		step()
		if not isArmed then
			isLandingJump = hasJustJumped()
			holdKey( "space", false )
			break
		end
	end

	hero:removeEventListener( "collision", pressOnLanding )
	check( isLandingJump, "a jump pressed on the landing frame fires" )
	waitUntilStill( 3 )
end

--------------------------------------------------------------------------------------
-- Room 1: the crate goes off the ledge onto the switch and stays there for 10 s; then key and exit.

do
	local crate, switch, door = room.crates[1], room.switches[1], room.doors[1]

	check( moveUntil( 1, function() return switch.isPressed end, 8 ), "room 1: pushing the crate off the ledge presses the switch" )
	steps( framesPerSecond )

	local settledX = crate.x
	local isAlwaysHeld = true
	for _ = 1, 10 * framesPerSecond do
		step()
		isAlwaysHeld = isAlwaysHeld and switch.isPressed and door.isOpen
	end
	check( isAlwaysHeld and isOnPlate( crate, switch ), "room 1: the crate stays on the switch for 10 s and the door stays open" )
	check( math.abs( crate.x - settledX ) < 0.5, "room 1: the crate does not creep, moved " .. ( crate.x - settledX ) )

	check( moveTo( room.key.x + 20, 12 ), "room 1: the player reaches the key" )
	steps( 5 )
	check( room.key.x == hero.x, "room 1: the player carries the key" )

	check( moveUntil( -1, function() return not room.exit.isVisible end, 15 ), "room 1: the player takes the key to the exit" )
	steps( math.ceil( settings.nextRoomDelay / 1000 * framesPerSecond ) + 5 )
end

--------------------------------------------------------------------------------------
-- Room 2: crate a off the low wall onto switch a, crate b off the step onto switch b, then key and exit.

hero = room.hero

local function isBlocked()
	return stillFrames >= 4
end

if check( isRoomLabel( 2 ) and #room.crates == 2 and #room.switches == 2 and #room.doors == 2, "room 2 builds two crates, switches and doors" ) then
	local switchA, switchB = room.switches[1], room.switches[2]
	local crateA, crateB = room.crates[1], room.crates[2]
	local tileSize = 36

	-- Onto the low wall behind crate a, then push it off the far side.
	waitUntilStill( 2 )
	local wallTop = crateA.y + tileSize * 0.5
	check( moveUntil( 1, isBlocked, 3, false ), "room 2: the player walks up to the low wall" )
	startJump()
	check( moveUntil( 1, function() return feetY() <= wallTop + 1 and hero.x > crateA.x - tileSize end, 2, false ), "room 2: the player climbs the low wall" )
	waitUntilStill( 2 )
	check( moveUntil( 1, function() return switchA.isPressed and isOnPlate( crateA, switchA ) end, 8, false ), "room 2: crate a lands on switch a" )
	steps( framesPerSecond )
	check( room.doors[1].isOpen, "room 2: door A opens" )

	-- Over crate a and through door A, then onto switch b at the foot of the two-tile step.
	check( moveTo( room.doors[1].x + tileSize, 10 ), "room 2: the player gets through door A" )
	check( moveUntil( 1, isBlocked, 3, false ), "room 2: the player walks up to the step" )

	-- Up the step, stopping short of crate b; then straight up, and over the crate once clear of its top.
	local stepTop = crateB.y + tileSize * 0.5
	startJump()
	check( moveUntil( 1, function() return feetY() <= stepTop + 1 and hero.x > crateB.x - tileSize - 10 end, 2, false ), "room 2: the player climbs the step" )
	waitUntilStill( 2 )

	startJump()
	for _ = 1, framesPerSecond do
		if feetY() < crateB.y - tileSize * 0.5 - 6 then
			break
		end
		step()
	end
	check( moveUntil( 1, function() return hero.x > crateB.x + tileSize + 2 end, 2, false ), "room 2: the player jumps over crate b" )
	waitUntilStill( 2 )

	-- The player lets go once the crate drops off the step, as walking after it would knock it off the switch.
	check( moveUntil( -1, function()
		local _, vy = crateB:getLinearVelocity()
		return vy > 30
	end, 8, false ), "room 2: the player pushes crate b off the step" )
	steps( framesPerSecond )
	check( switchB.isPressed and isOnPlate( crateB, switchB ), "room 2: crate b lands on switch b" )
	check( room.doors[2].isOpen, "room 2: door B opens" )

	check( moveTo( room.key.x + 20, 12 ), "room 2: the player reaches the key" )
	steps( 5 )
	check( room.key.x == hero.x, "room 2: the player carries the key" )

	check( moveUntil( -1, function() return not room.exit.isVisible end, 20 ), "room 2: the player takes the key to the exit" )
	steps( 5 )
	check( isOnPlate( crateA, switchA ) and isOnPlate( crateB, switchB ), "room 2: both crates are still on their switches" )
end

check( room.texts[settings.text.solved].parent.isVisible, "the puzzle is solved" )

stub.sceneEvent( scene, "hide", "will" )
stub.sceneEvent( scene, "hide", "did" )
stub.step()
stub.sceneEvent( scene, "destroy" )

for i = 1, #stub.errorOrder do
	failures = failures + 1
	print( "ERROR " .. stub.errorOrder[i] )
end

print( string.format( "%d checks, %d failures", checks, failures ) )
os.exit( failures == 0 and 0 or 1 )
