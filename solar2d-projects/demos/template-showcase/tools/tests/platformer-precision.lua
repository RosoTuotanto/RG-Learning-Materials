-- Checks for platformer-precision: the movement rules with a fake clock, the final dash challenge's timing window, and in
-- the running scene the Tiled map's contents, landing without a bounce, jumping on landing, and facing.
-- Usage, from the demo root: lua5.1 tools/tests/platformer-precision.lua
local lfs = require( "lfs" )

local demoRoot = lfs.currentdir()
local harnessDirectory = demoRoot .. "/tools/harness"
package.path = "./?.lua;" .. package.path

local movement = require( "samples.platformer-precision.classes.movement" )
local settings = require( "samples.platformer-precision.data.settings" )
local config = settings.player

local failures, checks = 0, 0
local function check( name, condition )
	checks = checks + 1
	if not condition then
		failures = failures + 1
		print( "FAIL " .. name )
	end
end

local function newFrame( overrides )
	local frame = {
		now = 0, isGrounded = false, wallSide = 0, runDirection = 0, aimY = 0,
		isJumpHeld = false, isJumpPressed = false, isDashPressed = false, vx = 0, vy = 0,
	}
	for key, value in pairs( overrides or {} ) do
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

-- Coyote time
do
	local mover = movement.new( config )
	step( mover, { now = 0, isGrounded = true } )
	local inside = step( mover, { now = config.coyoteTime - 10, isJumpPressed = true, isJumpHeld = true, vy = 50 } )
	check( "coyote jump inside window", inside.event == "jump" and inside.impulseY == -config.jumpImpulse and inside.vy == 0 )

	mover = movement.new( config )
	step( mover, { now = 0, isGrounded = true } )
	local after = step( mover, { now = config.coyoteTime + 10, isJumpPressed = true, isJumpHeld = true, vy = 50 } )
	check( "coyote jump refused after window", after.event == nil and after.impulseY == 0 )

	mover = movement.new( config )
	step( mover, { now = 0, isGrounded = true, isJumpPressed = true, isJumpHeld = true } )
	local second = step( mover, { now = 16, isGrounded = true, isJumpPressed = true, isJumpHeld = true, vy = -500 } )
	check( "no second jump from the same ground contact", second.event == nil )
end

-- Jump buffering
do
	local mover = movement.new( config )
	step( mover, { now = 0, isJumpPressed = true, isJumpHeld = true, vy = 200 } )
	local landed = step( mover, { now = config.jumpBufferTime - 20, isGrounded = true, isJumpHeld = true, vy = 0 } )
	check( "buffered jump fires on landing", landed.event == "jump" )

	mover = movement.new( config )
	step( mover, { now = 0, isJumpPressed = true, isJumpHeld = true, vy = 200 } )
	local late = step( mover, { now = config.jumpBufferTime + 20, isGrounded = true, isJumpHeld = true, vy = 0 } )
	check( "buffered jump expires", late.event == nil )
end

-- Jump cut
do
	local mover = movement.new( config )
	step( mover, { now = 0, isGrounded = true, isJumpPressed = true, isJumpHeld = true } )
	local held = step( mover, { now = 16, isJumpHeld = true, vy = -400 } )
	check( "held jump keeps rising speed", held.vy == -400 )
	local released = step( mover, { now = 32, isJumpHeld = false, vy = -380 } )
	check( "released jump is cut", math.abs( released.vy - ( -380 * config.jumpCut ) ) < 1e-9 )
	local later = step( mover, { now = 48, isJumpHeld = false, vy = -100 } )
	check( "jump is cut only once", later.vy == -100 )
end

-- Wall slide
do
	local mover = movement.new( config )
	local sliding = step( mover, { now = 1000, wallSide = 1, runDirection = 1, vy = 400 } )
	check( "wall slide caps fall speed", sliding.vy == config.wallSlideSpeed )
	local notPressing = step( mover, { now = 1016, wallSide = 1, runDirection = 0, vy = 400 } )
	check( "no slide without pressing into the wall", notPressing.vy == 400 )
	local away = step( mover, { now = 1032, wallSide = 1, runDirection = -1, vy = 400 } )
	check( "no slide pressing away", away.vy == 400 )
	local slow = step( mover, { now = 1048, wallSide = -1, runDirection = -1, vy = 50 } )
	check( "slow fall untouched", slow.vy == 50 )
	local grounded = step( mover, { now = 1064, isGrounded = true, wallSide = 1, runDirection = 1, vy = 400 } )
	check( "no slide on ground", grounded.vy == 400 )
end

-- Wall jump direction and input lock
do
	local mover = movement.new( config )
	local jump = step( mover, { now = 1000, wallSide = 1, runDirection = 1, isJumpPressed = true, isJumpHeld = true, vy = 100 } )
	check( "wall jump pushes away from a right wall",
		jump.event == "jump" and jump.impulseX == -config.wallJump.impulseX and jump.impulseY == -config.wallJump.impulseY )
	check( "wall jump faces away", jump.facing == -1 and jump.vx == 0 and jump.vy == 0 )
	local locked = step( mover, { now = 1000 + config.wallJump.lockTime - 10, runDirection = 1, isJumpHeld = true, vx = -270, vy = -300 } )
	check( "input ignored during lock", locked.vx == -270 and locked.facing == -1 )
	local free = step( mover, { now = 1000 + config.wallJump.lockTime + 10, runDirection = 1, isJumpHeld = true, vx = -270, vy = -200 } )
	check( "input returns after lock", free.vx == config.runSpeed and free.facing == 1 )

	mover = movement.new( config )
	local left = step( mover, { now = 1000, wallSide = -1, isJumpPressed = true, isJumpHeld = true } )
	check( "wall jump pushes away from a left wall", left.impulseX == config.wallJump.impulseX and left.facing == 1 )
end

-- Dash direction
do
	local speed = config.dash.speed
	local function dashWith( runDirection, aimY, facingFirst )
		local mover = movement.new( config )
		if facingFirst then
			step( mover, { now = 0, isGrounded = true, runDirection = facingFirst } )
		end
		return step( mover, { now = 100, runDirection = runDirection, aimY = aimY, isDashPressed = true } )
	end

	local right = dashWith( 1, 0 )
	check( "dash right", right.event == "dash" and right.vx == speed and right.vy == 0 and right.gravityScale == 0 )
	local diagonal = dashWith( -1, -1 )
	local length = math.sqrt( diagonal.vx * diagonal.vx + diagonal.vy * diagonal.vy )
	check( "diagonal dash normalized", math.abs( length - speed ) < 1e-9 and diagonal.vx < 0 and diagonal.vy < 0 and math.abs( diagonal.vx - diagonal.vy ) < 1e-9 )
	local down = dashWith( 0, 1 )
	check( "dash straight down", down.vx == 0 and down.vy == speed )
	local noKeysRight = dashWith( 0, 0 )
	check( "no keys dashes the default facing", noKeysRight.vx == speed and noKeysRight.vy == 0 )
	local noKeysLeft = dashWith( 0, 0, -1 )
	check( "no keys dashes the facing direction", noKeysLeft.vx == -speed and noKeysLeft.vy == 0 )
end

-- Dash duration, one dash per air time, refresh
do
	local mover = movement.new( config )
	step( mover, { now = 0, runDirection = 1, isDashPressed = true } )
	local during = step( mover, { now = config.dash.time - 10, runDirection = -1, vx = 1, vy = 1 } )
	check( "dash holds velocity and ignores input", during.vx == config.dash.speed and during.gravityScale == 0 )
	local ended = step( mover, { now = config.dash.time + 10, runDirection = 0, vx = 600, vy = 0 } )
	check( "dash ends and gravity returns", ended.gravityScale == 1 )
	check( "dash end keeps part of its sideways speed", math.abs( ended.vx - config.dash.speed * config.dash.endFactor ) < 1e-9 )
	local again = step( mover, { now = config.dash.time + 30, runDirection = 1, isDashPressed = true } )
	check( "second dash refused in the same air time", again.event == nil and again.gravityScale == 1 )

	step( mover, { now = 500, isGrounded = true } )
	local afterLanding = step( mover, { now = 520, runDirection = 1, isDashPressed = true } )
	check( "dash refreshed by landing", afterLanding.event == "dash" )

	mover = movement.new( config )
	step( mover, { now = 0, runDirection = 1, isDashPressed = true } )
	step( mover, { now = config.dash.time + 10 } )
	step( mover, { now = config.dash.time + 30, wallSide = 1 } )
	local afterWall = step( mover, { now = config.dash.time + 50, runDirection = -1, isDashPressed = true } )
	check( "dash refreshed by wall contact", afterWall.event == "dash" and afterWall.vx == -config.dash.speed )

	mover = movement.new( config )
	step( mover, { now = 0, isGrounded = true, runDirection = 1, isDashPressed = true } )
	local midDash = step( mover, { now = 50, isGrounded = true, runDirection = 1, isDashPressed = true } )
	check( "no refresh while dashing", midDash.event == nil )
end

-- Sideways carry after a dash, then control returns
do
	local mover = movement.new( config )
	local carried = config.dash.speed * config.dash.endFactor
	step( mover, { now = 0, runDirection = 1, isDashPressed = true } )
	local ending = step( mover, { now = config.dash.time, runDirection = 0, vx = config.dash.speed } )
	check( "carry starts when the dash ends with no key held", math.abs( ending.vx - carried ) < 1e-9 )
	local carrying = step( mover, { now = config.dash.time + config.dash.carryTime - 10, runDirection = -1, vx = carried } )
	check( "carry ignores keys during the lock", carrying.vx == carried )
	local released = step( mover, { now = config.dash.time + config.dash.carryTime + 10, runDirection = 0, vx = carried } )
	check( "control returns after the carry", released.vx == 0 )
	local steered = step( mover, { now = config.dash.time + config.dash.carryTime + 30, runDirection = -1, vx = 0 } )
	check( "keys steer again after the carry", steered.vx == -config.runSpeed and steered.facing == -1 )
end

-- Respawn reset
do
	local mover = movement.new( config )
	step( mover, { now = 0, runDirection = -1, isDashPressed = true } )
	step( mover, { now = 10, isJumpPressed = true, isJumpHeld = true } )
	mover:reset()
	local after = step( mover, { now = 20, vy = 300, isJumpHeld = true } )
	check( "respawn ends the dash", after.gravityScale == 1 and after.vy == 300 )
	check( "respawn clears the buffered jump", after.event == nil )
	check( "respawn faces right", after.facing == 1 )
	local coyote = step( mover, { now = 30, isJumpPressed = true, isJumpHeld = true } )
	check( "respawn clears coyote time", coyote.event == nil )
	local dash = step( mover, { now = 40, isDashPressed = true } )
	check( "respawn gives the dash back", dash.event == "dash" and dash.vx == config.dash.speed )

	mover = movement.new( config )
	step( mover, { now = 0, wallSide = 1, isJumpPressed = true, isJumpHeld = true } )
	mover:reset()
	local unlocked = step( mover, { now = 10, runDirection = 1, vx = -200 } )
	check( "respawn clears the wall jump lock", unlocked.vx == config.runSpeed )
end

-- Facing
do
	local mover = movement.new( config )
	local first = step( mover, { now = 0, isGrounded = true } )
	check( "the player starts facing its start direction", first.facing == config.startDirection )

	local dashLeft = step( mover, { now = 16, runDirection = -1, isDashPressed = true } )
	check( "a dash pressed with left turns the player left", dashLeft.event == "dash" and dashLeft.vx < 0 and dashLeft.facing == -1 )

	mover = movement.new( config )
	step( mover, { now = 0, isGrounded = true, runDirection = -1 } )
	local upRight = step( mover, { now = 16, runDirection = 1, aimY = -1, isDashPressed = true } )
	check( "a diagonal dash turns the player its sideways way", upRight.vx > 0 and upRight.facing == 1 )
end

--------------------------------------------------------------------------------------
-- The final dash challenge

-- A jump and dash must not need tight timing (user, item 16), and a jump alone must still fall short.
do
	local dash = dofile( "tools/tests/support/platformer-precision-dash.lua" )
	local course = dash.fromMap( "samples/platformer-precision/assets/level.json" )
	local tileSize = settings.sheets.tiles.displaySize

	for distance = 0, tileSize, tileSize / 4 do
		local window = dash.measure( course, distance )
		check( "dashing " .. distance .. " before the spikes leaves a jump window of at least 400 ms, found " .. window, window >= 400 )

		local plainWindow = dash.measure( course, distance, true )
		check( "a jump without a dash clears the spikes for under 100 ms of presses, found " .. plainWindow, plainWindow < 100 )
	end
end

--------------------------------------------------------------------------------------
-- The running scene

local stub = dofile( harnessDirectory .. "/stub/solar2d.lua" )
stub.install( harnessDirectory, ".scratch/tmp/platformer-precision" )

local tileSize = settings.sheets.tiles.displaySize

-- Box2D counts 30 content units per metre and returns no bounce below 1 metre per second.
local unitsPerMetre = 30
local bounceThreshold = unitsPerMetre

stub.call( dofile, "main.lua" )
local _, scene = stub.call( require, "samples.platformer-precision.demo" )
stub.sceneEvent( scene, "create" )
stub.sceneEvent( scene, "show", "will" )
stub.sceneEvent( scene, "show", "did" )

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
local byKind = { spike = {}, checkpoint = {}, flag = {} }
local solidBodies = {}
local bouncyElements = 0

each( scene.view, function( object )
	if object.respawn then
		hero = object

	elseif object.kind and byKind[object.kind] then
		local list = byKind[object.kind]
		list[#list + 1] = object
	end

	local elements = bodyElements( object )
	if elements then
		for i = 1, #elements do
			if elements[i].bounce ~= 0 then
				bouncyElements = bouncyElements + 1
			end
		end

		if object.bodyType == "static" and not elements[1].isSensor then
			solidBodies[#solidBodies + 1] = object
		end
	end
end )

-- Map contents

check( "the map places the player", hero ~= nil )

-- Before the first frame, so nothing has turned the player yet.
check( "the player spawns facing its start direction", hero.xScale == config.startDirection * config.artFacing )

local expectedCounts = { spike = 18, checkpoint = 2, flag = 1 }
for kind, count in pairs( expectedCounts ) do
	check( "the map places " .. count .. " " .. kind .. " objects, found " .. #byKind[kind], #byKind[kind] == count )
end

for i = 1, #byKind.checkpoint do
	local flag = byKind.checkpoint[i]
	local spawn = flag.spawn
	check( "checkpoint " .. i .. " respawns the player standing in its own tile",
		spawn ~= nil and spawn.x == flag.x and spawn.y == flag.y + ( tileSize - settings.sheets.characters.displaySize ) * 0.5 )
end

check( "the map has ground bodies", #solidBodies > 0 )
check( "no body element bounces, found " .. bouncyElements, bouncyElements == 0 )

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

local function steps( count )
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

steps( 30 )

do
	local landed = fullJump()
	check( "a full jump lands again", landed )

	local highestRise = 0
	for _ = 1, 60 do
		stepFrame()

		local _, vy = hero:getLinearVelocity()
		highestRise = math.max( highestRise, -vy )
	end

	check( "no upward speed after landing from a full jump, found " .. highestRise, highestRise <= 0 )
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
	check( "a jump pressed on the landing frame fires", isLandingJump )

	untilLanding()
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

	check( "a jump pressed " .. delay .. " frames after landing fires", hasJustJumped() )

	untilLanding()
	steps( 30 )
end

-- Facing

check( "settings record that the player art faces left", config.artFacing == -1 )

local function runAndFace( keyName, direction )
	holdKey( keyName, true )
	steps( 10 )
	holdKey( keyName, false )

	local vx = hero:getLinearVelocity()
	check( "the player faces its run direction " .. direction, vx * direction > 0 and hero.xScale == direction * config.artFacing )
end

runAndFace( "d", 1 )
runAndFace( "a", -1 )

-- A dash pressed with right held, starting from facing left.
holdKey( "d", true )
holdKey( "x", true )
stepFrame()
holdKey( "x", false )
holdKey( "d", false )
local dashSpeed = hero:getLinearVelocity()
check( "a dash to the right turns the player right", dashSpeed > 0 and hero.xScale == config.artFacing )
untilLanding()
steps( 30 )

runAndFace( "a", -1 )
hero:respawn( hero.x, hero.y )
check( "a respawn faces the start direction", hero.xScale == config.startDirection * config.artFacing )

stub.sceneEvent( scene, "hide", "will" )
stub.sceneEvent( scene, "hide", "did" )
stub.sceneEvent( scene, "destroy" )

for i = 1, #stub.errorOrder do
	failures = failures + 1
	print( "FAIL error: " .. stub.errorOrder[i].message )
end

print( ( failures == 0 and "OK " or "FAIL " ) .. ( checks - failures ) .. "/" .. checks .. " checks passed" )
os.exit( failures == 0 and 0 or 1 )
