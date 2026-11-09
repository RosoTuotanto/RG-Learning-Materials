-- Stub test for top-down-racing: lap logic, time formatting, grip impulse maths, and the map's track and wall lookups.
-- Run from the demo root: lua5.1 tools/tests/top-down-racing.lua
local harnessDirectory = "tools/harness"
local temporaryRoot = ".scratch/tmp/top-down-racing"

package.path = "./?.lua;" .. package.path

local stub = dofile( harnessDirectory .. "/stub/solar2d.lua" )
stub.install( harnessDirectory, temporaryRoot )

local laps = require( "samples.top-down-racing.classes.laps" )
local car = require( "samples.top-down-racing.classes.car" )
local mapGrid = require( "samples.top-down-racing.classes.mapGrid" )
local ponytiled = require( "samples.top-down-racing.libs.ponytiled" )
local settings = require( "samples.top-down-racing.data.settings" )
local json = require( "json" )

local failures = 0
local checks = 0
local function check( name, condition )
	checks = checks + 1
	if not condition then
		failures = failures + 1
		print( "FAIL " .. name )
	end
end

local function near( a, b, tolerance )
	return math.abs( a - b ) < ( tolerance or 1e-9 )
end

-- Time formatting
check( "format zero", laps.formatTime( 0 ) == "0:00.00" )
check( "format 61.234", laps.formatTime( 61.234 ) == "1:01.23" )
check( "format rounds up to the next second", laps.formatTime( 59.996 ) == "1:00.00" )
check( "format 125.5", laps.formatTime( 125.5 ) == "2:05.50" )

-- Laps: checkpoints in order count a lap
local tracker = laps.new( 4 )
check( "checkpoint before the start is ignored", tracker:crossCheckpoint( 1 ) == nil )
tracker:update( 5 )
check( "no time before the start", tracker.current == 0 )
check( "first finish starts", tracker:crossFinish() == "start" )

local function driveLap( order, seconds )
	for i = 1, #order do
		tracker:crossCheckpoint( order[i] )
	end
	tracker:update( seconds )
	return tracker:crossFinish()
end

check( "ordered lap is best", driveLap( { 1, 2, 3, 4 }, 30 ) == "best" )
check( "last after first lap", tracker.last == 30 and tracker.best == 30 and tracker.current == 0 )
check( "slower lap is lap", driveLap( { 1, 2, 3, 4 }, 35 ) == "lap" )
check( "last updates, best stays", tracker.last == 35 and tracker.best == 30 )
check( "faster lap is best", driveLap( { 1, 2, 3, 4 }, 28.5 ) == "best" )
check( "best improves", tracker.last == 28.5 and tracker.best == 28.5 )

-- Laps: skipping or reversing one does not count
check( "skipped checkpoint is missed", driveLap( { 1, 2, 4 }, 20 ) == "missed" )
check( "missed lap leaves times", tracker.last == 28.5 and tracker.best == 28.5 and tracker.current == 0 )
check( "out of order is missed", driveLap( { 1, 3, 2, 4 }, 20 ) == "missed" )
check( "reversed loop is missed", driveLap( { 4, 3, 2, 1 }, 20 ) == "missed" )
check( "crossing one twice still counts", driveLap( { 1, 1, 2, 3, 3, 4 }, 40 ) == "lap" )
check( "out-of-order crossing returns nil", tracker:crossCheckpoint( 3 ) == nil )
check( "next checkpoint stays 1", tracker.nextCheckpoint == 1 )

-- Laps: recrossing the finish backwards with no checkpoint passed restarts, never reports missed
tracker:update( 3 )
check( "backwards recross is a start", tracker:crossFinish() == "start" )
check( "backwards recross keeps times", tracker.last == 40 and tracker.best == 28.5 and tracker.current == 0 )
check( "second recross is a start", tracker:crossFinish() == "start" )
check( "lap still counts after recrossing", driveLap( { 1, 2, 3, 4 }, 26 ) == "best" and tracker.best == 26 )
tracker:crossCheckpoint( 1 )
check( "one checkpoint then finish is missed", tracker:crossFinish() == "missed" )

-- Grip impulse: removes the grip share of sideways velocity and leaves forward velocity alone
local mass, scale = 0.5, settings.pixelsPerMeter
local function afterGrip( velocityX, velocityY, rotation, grip )
	local impulseX, impulseY = car.getGripImpulse( velocityX, velocityY, rotation, grip, mass, scale )
	return velocityX + impulseX / mass * scale, velocityY + impulseY / mass * scale
end

local grip, driftGrip = settings.car.grip, settings.car.driftGrip
local velocityX, velocityY = afterGrip( 300, 100, 0, grip )
check( "heading +x keeps forward speed", near( velocityX, 300 ) )
check( "heading +x removes grip share of sideways", near( velocityY, 100 * ( 1 - grip ) ) )

local _, driftVelocityY = afterGrip( 300, 100, 0, driftGrip )
check( "handbrake removes less", near( driftVelocityY, 100 * ( 1 - driftGrip ) ) and driftVelocityY > 100 * ( 1 - grip ) )

velocityX, velocityY = afterGrip( 50, 200, 90, grip )
check( "heading +y keeps forward speed", near( velocityY, 200 ) )
check( "heading +y removes sideways", near( velocityX, 50 * ( 1 - grip ) ) )

velocityX, velocityY = afterGrip( 100, 100, 45, grip )
check( "diagonal heading pure forward unchanged", near( velocityX, 100 ) and near( velocityY, 100 ) )

-- Track lookup in world coordinates while the camera has moved the world group
local physics = require( "physics" )
physics.start()

local world = display.newGroup()
local mapData = json.decodeFile( system.pathForFile( settings.map.folder .. "/" .. settings.map.file ) )
local map = ponytiled.new( mapData, settings.map.folder )
world:insert( map )

local grid = mapGrid.new( map, mapData )
local size = grid.tileSize
local walls = map:findLayer( "physics" )

local start = map:findObject( "start" )
local racer = display.newRect( world, start.x, start.y, 10, 10 )

world.x, world.y = -1500, -900
check( "start tile is track with the world moved", grid:isTrackAt( racer.x, racer.y ) )

local contentX, contentY = racer:localToContent( 0, 0 )
check( "content position differs from world position", not near( contentX, racer.x, 1 ) )
local localX, localY = world:contentToLocal( contentX, contentY )
check( "contentToLocal gets back to world", near( localX, racer.x, 1e-6 ) and near( localY, racer.y, 1e-6 ) )

racer.x, racer.y = grid:tileToWorld( 20, 20 )
check( "infield is grass", not grid:isTrackAt( racer.x, racer.y ) )

racer.x, racer.y = grid:tileToWorld( 10, 40 )
check( "left straight is track", grid:isTrackAt( racer.x, racer.y ) )
check( "outside the map is not track", not grid:isTrackAt( -10, -10 ) and not grid:isTrackAt( grid.width + 5, 10 ) )

-- The checkpoint and finish rects lie on the track, and the checkpoints are numbered 1 to 4 once each
local function onTrackEverywhere( rect )
	for x = rect.x - rect.width * 0.5 + size * 0.5, rect.x + rect.width * 0.5, size do
		for y = rect.y - rect.height * 0.5 + size * 0.5, rect.y + rect.height * 0.5, size do
			if not grid:isTrackAt( x, y ) then
				return false
			end
		end
	end

	return true
end

local finish = map:findObject( "finish" )
check( "finish on track", finish and onTrackEverywhere( finish ) )

local gates = map:listTypes( "checkpoint" )
local orders = {}
for i = 1, #gates do
	check( "checkpoint " .. tostring( gates[i].order ) .. " on track", onTrackEverywhere( gates[i] ) )
	orders[gates[i].order] = ( orders[gates[i].order] or 0 ) + 1
end
check( "four checkpoints", #gates == 4 )
for order = 1, 4 do
	check( "checkpoint order " .. order .. " once", orders[order] == 1 )
end

-- Driving sanity under the stub's physics step: top speed on dirt, slow on grass, steering needs speed
physics.setGravity( 0, 0 )
local held = {}
local fakeControls = {
	isHeld = function( _, action ) return held[action] == true end,
	getAxis = function( _, negative, positive ) return ( held[positive] and 1 or 0 ) - ( held[negative] and 1 or 0 ) end,
}
local testCar = car.new({ parent = world, x = start.x, y = start.y, controls = fakeControls, config = settings.car, pixelsPerMeter = scale })

local function speedOf( body )
	local vx, vy = body:getLinearVelocity()
	return math.sqrt( vx * vx + vy * vy )
end

local function run( frames, isOnTrack )
	for _ = 1, frames do
		testCar:drive( isOnTrack )
		stub.step()
	end
end

held.right = true
run( 30, true )
check( "no turning in place", near( testCar.rotation, 0, 1e-6 ) )
held.right = nil

held.accelerate = true
run( 180, true )
local dirtSpeed = speedOf( testCar )
check( "dirt top speed near maxSpeed (" .. dirtSpeed .. ")", dirtSpeed > 350 and dirtSpeed < 440 )

held.right = true
run( 30, true )
check( "steering turns right at speed (" .. testCar.rotation .. ")", testCar.rotation > 20 )
held.right = nil

run( 180, false )
local grassSpeed = speedOf( testCar )
check( "grass speed is low (" .. grassSpeed .. ")", grassSpeed < 130 )
held.accelerate = nil

held.brake = true
run( 240, true )
local vx, vy = testCar:getLinearVelocity()
local angle = math.rad( testCar.rotation )
local forwardSpeed = vx * math.cos( angle ) + vy * math.sin( angle )
check( "brake then reverse slowly (" .. forwardSpeed .. ")", forwardSpeed < -50 and forwardSpeed > -settings.car.maxReverseSpeed - 10 )

-- Bump speed: only the speed into an open face of the wall tile nearest the car counts
local function place( x, y, rotation, speedX, speedY )
	testCar.x, testCar.y, testCar.rotation = x, y, rotation
	testCar:setLinearVelocity( speedX, speedY )
end

local function wallCovering( column, row )
	local x, y = grid:tileToWorld( column, row )

	for i = 1, walls.numChildren do
		local wall = walls[i]
		if math.abs( x - wall.x ) < wall.width * 0.5 and math.abs( y - wall.y ) < wall.height * 0.5 then
			return wall
		end
	end
end

-- Top border: row 2 is pine trunks with grass below, merged into one rect with its neighbours.
local borderX, borderY = grid:tileToWorld( 10, 2 )
local border = wallCovering( 10, 2 )
check( "border tile solid", grid:isSolid( 10, 2 ) and grid:isSolid( 9, 2 ) and not grid:isSolid( 10, 3 ) )
check( "border rect spans several tiles", border and border.width > size * 2 )

local nearestColumn, nearestRow = grid:getNearestWallTile( border, borderX - 30, borderY + 24.1 )
check( "nearest border tile is the one above the car", nearestColumn == 9 and nearestRow == 2 )

place( borderX - 30, borderY + 24.1, 0, 200, 0 )
check( "scraping along the border is quiet", testCar:getSpeedInto( border, grid ) < settings.bumpSpeed )

place( borderX - 30, borderY + 24.1, -10, 200, -35 )
check( "angled scrape is quiet", testCar:getSpeedInto( border, grid ) < settings.bumpSpeed )

place( borderX, borderY + 27.5, -90, 0, -200 )
check( "driving straight into the border bumps", near( testCar:getSpeedInto( border, grid ), 200 ) )

place( borderX, borderY + 27.5, 90, 0, 150 )
check( "driving away is negative", testCar:getSpeedInto( border, grid ) < 0 )

-- An isolated rock: hits from the side and from below both count.
local rock = nil
for i = 1, walls.numChildren do
	local wall = walls[i]
	local column, row = grid:worldToTile( wall.x, wall.y )

	if near( wall.width, size ) and near( wall.height, size ) and not ( grid:isSolid( column - 1, row ) or grid:isSolid( column + 1, row )
		or grid:isSolid( column, row - 1 ) or grid:isSolid( column, row + 1 ) ) then
		rock = wall
		break
	end
end
check( "found an isolated rock", rock ~= nil )

place( rock.x - 29.5, rock.y, 0, 200, 0 )
check( "head-on into a rock from the left", near( testCar:getSpeedInto( rock, grid ), 200 ) )

place( rock.x + 4, rock.y + 25.5, -90, 0, -180 )
check( "head-on into a rock from below", near( testCar:getSpeedInto( rock, grid ), 180 ) )

place( rock.x - 10, rock.y + 25.5, 0, 200, -10 )
check( "grazing a rock's bottom face is quiet", testCar:getSpeedInto( rock, grid ) < settings.bumpSpeed )

os.execute( "rm -rf '" .. temporaryRoot .. "'" )
print( checks .. " checks, " .. failures .. " failures" )
os.exit( failures == 0 and 0 or 1 )
