-- Checks for platformer-shooter: the Tiled map's contents, no bounce on any body, jumping on landing, facing, and the health panel's place.
-- Usage, from the demo root: lua5.1 tools/tests/platformer-shooter.lua
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

local function near( a, b, tolerance )
	return math.abs( a - b ) < ( tolerance or 1e-6 )
end

local stub = dofile( harnessDirectory .. "/stub/solar2d.lua" )
stub.install( harnessDirectory, ".scratch/tmp/platformer-shooter" )

local settings = require( "samples.platformer-shooter.data.settings" )

-- The character sheet's player art faces left when unmirrored.
local playerArtFacing = -1

-- Box2D counts 30 content units per metre and returns no bounce below 1 metre per second.
local unitsPerMetre = 30
local bounceThreshold = unitsPerMetre

stub.call( dofile, "main.lua" )
local strings = require( "data.strings" )
require( "scripts.appOverlay" ).setBackVisible( true )

local _, scene = stub.call( require, "samples.platformer-shooter.demo" )
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

local hero, weapon
local turrets = {}
local solidBodies = {}

local function collect()
	hero, weapon = nil, nil
	turrets, solidBodies = {}, {}

	each( scene.view, function( object )
		if object.isGrounded then
			hero = object

		elseif object.aimAt then
			weapon = object

		elseif object.isTurret then
			turrets[#turrets + 1] = object
		end

		local elements = bodyElements( object )
		if elements and object.bodyType == "static" and not elements[1].isSensor then
			solidBodies[#solidBodies + 1] = object
		end
	end )
end

collect()

--------------------------------------------------------------------------------------
-- Map contents

check( hero ~= nil and weapon ~= nil, "the map places the player with its gun" )
check( #turrets == 5, "the map places 5 turrets, found " .. #turrets )

-- The old string level stood the player on row 20, column 3, and each turret in the centre of its tile.
local tileSize = settings.turret.size
local startY = 20 * tileSize - settings.sheets.characters.displaySize * 0.5
check( near( hero.x, 2.5 * tileSize ) and near( hero.y, startY ), "the player starts where the old level put it" )

local expectedTurrets = { { 30, 10 }, { 12, 11 }, { 51, 11 }, { 42, 14 }, { 28, 16 } }
for i = 1, #expectedTurrets do
	local x, y = ( expectedTurrets[i][1] - 0.5 ) * tileSize, ( expectedTurrets[i][2] - 0.5 ) * tileSize
	local isFound = false

	for j = 1, #turrets do
		isFound = isFound or ( near( turrets[j].x, x ) and near( turrets[j].y, y ) )
	end

	check( isFound, "a turret stands in the centre of column " .. expectedTurrets[i][1] .. ", row " .. expectedTurrets[i][2] )
end

-- Before the first frame, so nothing has turned the player yet.
check( settings.player.artFacing == playerArtFacing, "settings record that the player art faces left" )
local startDirection = settings.player.startDirection
check( startDirection ~= nil and hero.xScale == startDirection * playerArtFacing, "the player spawns facing its start direction" )

--------------------------------------------------------------------------------------
-- No bounce

local function holdKey( keyName, isDown )
	stub.call( stub.key, keyName, isDown and "down" or "up", false )
end

-- One shot of the player's own, so a player bullet is among the bodies checked.
local heroContentX, heroContentY = hero:localToContent( 0, 0 )
stub.touchAt( heroContentX + 200, heroContentY, "began" )
stub.touchAt( heroContentX + 200, heroContentY, "ended" )
stub.step()

local bodyCount, bouncyCount = 0, 0
each( scene.view, function( object )
	local elements = bodyElements( object )

	if elements then
		bodyCount = bodyCount + 1

		for i = 1, #elements do
			if elements[i].bounce ~= 0 then
				bouncyCount = bouncyCount + 1
				break
			end
		end
	end
end )

check( bodyCount >= 16 and bouncyCount == 0, "every body has bounce 0, found " .. bouncyCount .. " of " .. bodyCount .. " bouncing" )

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

-- The cursor sits on the far side of the run, so a player that faced its aim would face the wrong way.
local function runAndFace( keyName, direction )
	local x, y = hero:localToContent( 0, 0 )
	local cursorX = x - direction * 300
	stub.mouseAt( cursorX, y, "move", false )

	holdKey( keyName, true )
	steps( 10 )
	holdKey( keyName, false )

	local vx = hero:getLinearVelocity()
	check( vx * direction > 0 and hero.xScale == direction * playerArtFacing and hero.facing == direction, "the player faces its run direction " .. direction )

	-- The gun still points at the cursor, through the world group whatever the camera did.
	local aimX, aimY = hero.parent:contentToLocal( cursorX, y )
	local expected = math.deg( math.atan2( aimY - weapon.y, aimX - weapon.x ) )
	check( near( weapon.heading, expected, 1e-3 ), "the gun aims at the cursor behind the player running " .. direction )

	steps( 30 )
	check( hero.xScale == direction * playerArtFacing, "the player keeps facing " .. direction .. " after stopping" )
end

runAndFace( "d", 1 )
runAndFace( "a", -1 )

--------------------------------------------------------------------------------------
-- Health panel

local function findByText( text )
	local found
	each( stub.stage, function( object )
		if rawget( object, "text" ) == text then
			found = object
		end
	end )
	return found
end

local function overlaps( a, b )
	return a.xMin < b.xMax and b.xMin < a.xMax and a.yMin < b.yMax and b.yMin < a.yMax
end

local function contains( outer, inner )
	return outer.xMin <= inner.xMin and outer.yMin <= inner.yMin and outer.xMax >= inner.xMax and outer.yMax >= inner.yMax
end

-- The panel's background is the first child of the group that holds the HP label and the bar.
local function checkHealthPanel( when )
	local label = findByText( settings.text.hp )
	local panel = label and label.parent
	local background = panel and panel[1]

	check( background ~= nil and background ~= label and background.path ~= nil, "the health panel has a background rect " .. when )
	if not background or not background.path then
		return
	end

	local box = background.contentBounds
	local centreX = display.screenOriginX + display.actualContentWidth * 0.5

	local top = settings.hud.hpTop and display.screenOriginY + settings.hud.hpTop
	local isPlaced = near( ( box.xMin + box.xMax ) * 0.5, centreX ) and top ~= nil and near( box.yMin, top )
	check( isPlaced, "the health panel is centred at the top of the screen " .. when )

	for i = 2, panel.numChildren do
		check( contains( box, panel[i].contentBounds ), "health panel child " .. i .. " sits on the background " .. when )
	end

	local back = findByText( strings.back ).parent
	check( not overlaps( box, back.contentBounds ), "the health panel clears the Back button " .. when )

	local slider = findByText( settings.volumeSlider.label ).parent[1]
	check( not overlaps( box, slider.contentBounds ), "the health panel clears the volume slider " .. when )
end

checkHealthPanel( "before a resize" )

-- The window grows by 80 x 60 around the content area, so the screen origin moves by -40, -30.
display.screenOriginX, display.screenOriginY = -40, -30
display.actualContentWidth, display.actualContentHeight = 1040, 700
stub.fireRuntime( { name = "resize" } )

checkHealthPanel( "after a resize" )

stub.sceneEvent( scene, "hide", "will" )
stub.sceneEvent( scene, "hide", "did" )
stub.sceneEvent( scene, "destroy" )

for i = 1, #stub.errorOrder do
	failures = failures + 1
	print( "FAIL error: " .. stub.errorOrder[i].message )
end

print( ( failures == 0 and "OK " or "FAIL " ) .. ( checks - failures ) .. "/" .. checks .. " checks passed" )
os.exit( failures == 0 and 0 or 1 )
