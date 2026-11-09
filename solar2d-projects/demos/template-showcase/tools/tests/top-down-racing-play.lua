-- Plays top-down-racing's real scene in the harness stub: road width along the centre line, a full-throttle steering bot
-- lap, and every sound landing in a frame where the player sees something happen.
-- Usage, from the demo root: lua5.1 tools/tests/top-down-racing-play.lua [MAP_FOLDER]
-- MAP_FOLDER loads another conversion of the track (its level.json and images/tileset.png) in place of the sample's map.
local harnessDirectory = "tools/harness"
package.path = "./?.lua;" .. harnessDirectory .. "/?.lua;" .. package.path

local stub = dofile( harnessDirectory .. "/stub/solar2d.lua" )
stub.install( harnessDirectory, ".scratch/tmp/top-down-racing-play" )

local json = require( "json" )
local settings = require( "samples.top-down-racing.data.settings" )
local mapGrid = require( "samples.top-down-racing.classes.mapGrid" )

if arg[1] then
	settings.map.folder = arg[1]
end

-- The string track the map replaced had a road three tiles wide everywhere.
local oldRoadWidth = 3 * 32

-- Road runs no longer than this many tiles cross a straight; longer runs follow one.
local maxCrossingTiles = 10

-- How far ahead along the centre line the bot aims, in centre-line points (one per tile on a straight).
local lookahead = 4

-- Heading error in degrees the bot accepts before it steers.
local steerDeadband = 2

local lapFrameLimit = 60 * 90

local checks, failures = 0, 0

local function check( condition, message )
	checks = checks + 1

	if not condition then
		failures = failures + 1
		print( "FAIL top-down-racing-play: " .. message )
	end
end

local function find( group, test )
	if test( group ) then
		return group
	end

	for i = 1, ( group.numChildren or 0 ) do
		local found = find( group[i], test )
		if found then
			return found
		end
	end
end

local function distance( ax, ay, bx, by )
	return math.sqrt( ( ax - bx ) ^ 2 + ( ay - by ) ^ 2 )
end

--------------------------------------------------------------------------------------
-- Sounds are recorded with the frame they start in.

local played = {}
local stubPlay = audio.play

function audio.play( handle, options )
	played[#played + 1] = { frame = stub.frame, name = tostring( handle.filename ):match( "([^/]+)%.wav$" ) }

	return stubPlay( handle, options )
end

stub.call( dofile, "main.lua" )
local _, scene = stub.call( require, "samples.top-down-racing.demo" )
stub.sceneEvent( scene, "create" )
stub.sceneEvent( scene, "show", "will" )
stub.sceneEvent( scene, "show", "did" )

local map = find( scene.view, function( object ) return object.findObject ~= nil end )
local racer = find( scene.view, function( object ) return object.getSpeedInto ~= nil end )
local lastLabel = find( scene.view, function( object )
	return type( object.text ) == "string" and object.text:sub( 1, #settings.text.last ) == settings.text.last
end )
check( map and racer and lastLabel, "the scene holds the map, the car and the last-lap label" )

local mapData = json.decodeFile( system.pathForFile( settings.map.folder .. "/" .. settings.map.file ) )
local grid = mapGrid.new( map, mapData )
local size = grid.tileSize
local walls = map:findLayer( "physics" )

--------------------------------------------------------------------------------------
-- Centre line: the middle of every road run that crosses a straight, chained in driving order.

local points = {}

local function addCrossings( isRow )
	local lineCount = isRow and grid.rowCount or grid.columnCount
	local cellCount = isRow and grid.columnCount or grid.rowCount

	for line = 1, lineCount do
		local runStart = nil

		for index = 1, cellCount + 1 do
			local column, row = index, line
			if not isRow then
				column, row = line, index
			end

			local isTrack = index <= cellCount and grid:isTrackAt( grid:tileToWorld( column, row ) )

			if isTrack and not runStart then
				runStart = index

			elseif not isTrack and runStart then
				local length = index - runStart

				if length <= maxCrossingTiles then
					local middle = ( runStart - 1 + index - 1 ) * 0.5 * size
					local across = ( line - 0.5 ) * size

					if isRow then
						points[#points + 1] = { x = middle, y = across, width = length * size }
					else
						points[#points + 1] = { x = across, y = middle, width = length * size }
					end
				end

				runStart = nil
			end
		end
	end
end

addCrossings( true )
addCrossings( false )

local start = map:findObject( "start" )
local route = {}
local used = {}

-- The car starts facing +x, so after the point nearest the start the route only looks right until it has left the start.
local current = nil
for _ = 1, #points do
	local fromX, fromY = start.x, start.y
	if current then
		fromX, fromY = current.x, current.y
	end

	local best, bestDistance = nil, math.huge
	for i = 1, #points do
		local gap = distance( fromX, fromY, points[i].x, points[i].y )
		local isAhead = #route ~= 1 or points[i].x > current.x

		if not used[i] and isAhead and gap < bestDistance then
			best, bestDistance = i, gap
		end
	end

	used[best] = true
	current = points[best]
	route[#route + 1] = current
end

local longestStep = 0
for i = 1, #route do
	local nextPoint = route[i % #route + 1]
	longestStep = math.max( longestStep, distance( route[i].x, route[i].y, nextPoint.x, nextPoint.y ) )
end
check( longestStep < 6 * size, "the centre line closes into one loop (longest step " .. longestStep / size .. " tiles)" )

local narrowest = math.huge
for i = 1, #route do
	narrowest = math.min( narrowest, route[i].width )
end
check( narrowest >= oldRoadWidth * 1.5, "the road is at least 50% wider than " .. oldRoadWidth .. " everywhere (narrowest " .. narrowest .. ")" )

--------------------------------------------------------------------------------------
-- What the player sees each frame: the HUD's texts and colours other than the running lap clock, which changes every
-- frame, and whether the car touches a drawn tree or rock.

local hudTexts = {}
local function collectTexts( group )
	for i = 1, group.numChildren do
		local child = group[i]

		if child.numChildren then
			collectTexts( child )

		elseif type( child.text ) == "string" and child.text:sub( 1, #settings.text.lap ) ~= settings.text.lap then
			hudTexts[#hudTexts + 1] = child
		end
	end
end

for i = 1, scene.view.numChildren do
	if not find( scene.view[i], function( object ) return object == map end ) then
		collectTexts( scene.view[i] )
	end
end

local function hudState()
	local parts = {}

	for i = 1, #hudTexts do
		local color = rawget( hudTexts[i], "_stub" ).fillColor or {}
		parts[#parts + 1] = hudTexts[i].text .. "|" .. table.concat( color, "," )
	end

	return table.concat( parts, "\n" )
end

local function touchesWall()
	local halfWidth, halfHeight = racer.contentWidth * 0.5, racer.contentHeight * 0.5

	for i = 1, walls.numChildren do
		local wall = walls[i]

		if math.abs( racer.x - wall.x ) <= halfWidth + wall.width * 0.5 and math.abs( racer.y - wall.y ) <= halfHeight + wall.height * 0.5 then
			return true
		end
	end

	return false
end

local wallContacts = 0
racer:addEventListener( "collision", function( event )
	if event.phase == "began" and not ( event.other.checkpointIndex or event.other.isFinish ) then
		wallContacts = wallContacts + 1
	end
end )

local unseenSounds = 0
local previousHud = hudState()

-- One frame, then every sound started in it must show as a HUD change or a wall contact in the same frame.
local function step()
	local firstSound = #played + 1
	stub.step()

	local hud = hudState()
	local isSeen = hud ~= previousHud or touchesWall()
	previousHud = hud

	for i = firstSound, #played do
		if not isSeen then
			unseenSounds = unseenSounds + 1
			print( "FAIL top-down-racing-play: sound " .. played[i].name .. " in frame " .. played[i].frame .. " with nothing seen" )
		end
	end
end

--------------------------------------------------------------------------------------
-- The bot holds the accelerator and steers toward a point a few tiles ahead on the centre line.

local heldKeys = {}
local function holdKey( keyName, isHeld )
	if heldKeys[keyName] ~= isHeld then
		heldKeys[keyName] = isHeld
		stub.key( keyName, isHeld and "down" or "up" )
	end
end

holdKey( "up", true )

local progress = 1
local offRoadFrames = 0
local lapFrames = nil

for frame = 1, lapFrameLimit do
	local nearest, nearestDistance = progress, math.huge
	for offset = 0, 8 do
		local index = ( progress + offset - 1 ) % #route + 1
		local gap = distance( racer.x, racer.y, route[index].x, route[index].y )

		if gap < nearestDistance then
			nearest, nearestDistance = index, gap
		end
	end
	progress = nearest

	local target = route[( progress + lookahead - 1 ) % #route + 1]
	local heading = math.deg( math.atan2( target.y - racer.y, target.x - racer.x ) )
	local headingError = ( heading - racer.rotation + 540 ) % 360 - 180

	holdKey( "right", headingError > steerDeadband )
	holdKey( "left", headingError < -steerDeadband )

	step()

	if not grid:isTrackAt( racer.x, racer.y ) then
		offRoadFrames = offRoadFrames + 1
	end

	if lastLabel.text ~= settings.text.last .. settings.text.noTime then
		lapFrames = frame
		break
	end
end

holdKey( "left", false )
holdKey( "right", false )

check( lapFrames ~= nil, "the full-throttle bot counts a lap within " .. lapFrameLimit .. " frames" )
check( wallContacts == 0, "the bot's lap touches no tree or rock (" .. wallContacts .. " contacts)" )
check( offRoadFrames == 0, "the bot's lap stays on the road (" .. offRoadFrames .. " frames off it)" )

local lapSounds = 0
for i = 1, #played do
	if played[i].name == "lap" then
		lapSounds = lapSounds + 1
	end
end
check( lapSounds == 1, "the counted lap plays the lap sound once (" .. lapSounds .. ")" )
check( #played == lapSounds, "the clean lap plays no other sound (" .. #played .. " sounds)" )

--------------------------------------------------------------------------------------
-- A crash into an isolated rock plays the bump sound while the car touches it.

local rock = nil
for i = 1, walls.numChildren do
	local wall = walls[i]
	local column, row = grid:worldToTile( wall.x, wall.y )

	if math.abs( wall.width - size ) < 1e-6 and math.abs( wall.height - size ) < 1e-6 and not ( grid:isSolid( column - 1, row )
		or grid:isSolid( column + 1, row ) or grid:isSolid( column, row - 1 ) or grid:isSolid( column, row + 1 ) ) then
		rock = wall
		break
	end
end
check( rock ~= nil, "the map has an isolated rock" )

local soundsBefore = #played
racer.x, racer.y, racer.rotation = rock.x - 3 * size, rock.y, 0
racer:setLinearVelocity( 300, 0 )
racer.angularVelocity = 0

for _ = 1, 30 do
	step()
end

local bumps = 0
for i = soundsBefore + 1, #played do
	if played[i].name == "bump" then
		bumps = bumps + 1
	end
end
check( bumps == 1, "driving into the rock plays the bump sound once (" .. bumps .. ")" )
check( unseenSounds == 0, "every sound lands in a frame where the HUD changes or the car touches a wall (" .. unseenSounds .. " unseen)" )

holdKey( "up", false )
stub.sceneEvent( scene, "hide", "will" )
stub.sceneEvent( scene, "hide", "did" )

print( checks .. " checks, " .. failures .. " failures" )
os.exit( failures == 0 and 0 or 1 )
