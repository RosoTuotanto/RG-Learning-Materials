-- Plays top-down-stealth's real scene in the harness stub: the Tiled map's sight-blocking walls, start, door and guard patrols.
-- Usage, from the demo root: lua5.1 tools/tests/top-down-stealth-play.lua
local harnessDirectory = "tools/harness"
package.path = "./?.lua;" .. harnessDirectory .. "/?.lua;" .. package.path

local stub = dofile( harnessDirectory .. "/stub/solar2d.lua" )
stub.install( harnessDirectory, ".scratch/tmp/top-down-stealth-play" )

local settings = require( "samples.top-down-stealth.data.settings" )
local guard = require( "samples.top-down-stealth.classes.guard" )

local tileSize = 32

-- The string level's patrols, in tile column and row, that the map's guard lines must reproduce.
local oldWaypoints = {
	{ { 4, 12 }, { 20, 12 } },
	{ { 4, 4 }, { 12, 4 }, { 12, 6 }, { 4, 6 } },
	{ { 21, 7 }, { 15, 7 }, { 15, 4 }, { 21, 4 } },
}

local checks, failures = 0, 0

local function check( condition, message )
	checks = checks + 1

	if not condition then
		failures = failures + 1
		print( "FAIL top-down-stealth-play: " .. message )
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

local function findAll( group, test, list )
	list = list or {}

	if test( group ) then
		list[#list + 1] = group
	end

	for i = 1, ( group.numChildren or 0 ) do
		findAll( group[i], test, list )
	end

	return list
end

local function bodyElements( object )
	local internal = rawget( object, "_stub" )
	return internal and internal.body and internal.body.elements
end

local function tileCentre( column, row )
	return ( column - 0.5 ) * tileSize, ( row - 0.5 ) * tileSize
end

local function describe( route )
	local parts = {}
	for i = 1, #route do
		parts[i] = route[i].x .. "," .. route[i].y
	end

	return table.concat( parts, " " )
end

stub.call( dofile, "main.lua" )
local _, scene = stub.call( require, "samples.top-down-stealth.demo" )
stub.sceneEvent( scene, "create" )
stub.sceneEvent( scene, "show", "will" )
stub.sceneEvent( scene, "show", "did" )

--------------------------------------------------------------------------------------
-- The map

local map = find( scene.view, function( object ) return object.findObject ~= nil end )
check( map ~= nil, "the scene holds a ponytiled map" )

local walls = map:findLayer( "physics" )
check( walls.numChildren == 20, "the physics layer holds 20 wall rects, not " .. walls.numChildren )

local badWalls = 0
for i = 1, walls.numChildren do
	local wall = walls[i]
	local elements = bodyElements( wall )

	if not ( wall.blocksSight == true and wall.bodyType == "static" and elements and elements[1].friction == 0 ) then
		badWalls = badWalls + 1
	end
end
check( badWalls == 0, badWalls .. " wall rects lack blocksSight or a static body with friction 0" )

local start = map:findObject( "player" )
local startX, startY = tileCentre( 3, 14 )
check( start.x == startX and start.y == startY, "the player object sits on tile 3,14" )

local door = map:findObject( "door" )
local doorX, doorY = tileCentre( 19, 2 )
check( door.x == doorX and door.y == doorY, "the door object sits on tile 19,2" )

--------------------------------------------------------------------------------------
-- Guard patrols

local lines = map:findObjects( "guard" )
check( #lines == #oldWaypoints, "the map holds " .. #oldWaypoints .. " guard lines, not " .. #lines )

-- Every old patrol must match exactly one map line, point for point and in order.
local routes = {}
for i = 1, #lines do
	routes[i] = describe( guard.routeFromLine( lines[i] ) )
end

for i = 1, #oldWaypoints do
	local expected = {}
	for p = 1, #oldWaypoints[i] do
		local x, y = tileCentre( oldWaypoints[i][p][1], oldWaypoints[i][p][2] )
		expected[p] = { x = x, y = y }
	end

	local wanted = describe( expected )
	local matches = 0
	for j = 1, #routes do
		if routes[j] == wanted then
			matches = matches + 1
		end
	end
	check( matches == 1, "patrol " .. i .. " (" .. wanted .. ") matches " .. matches .. " guard lines; lines: " .. table.concat( routes, " | " ) )
end

-- Each guard starts its round on the first point of its own patrol.
local sentries = findAll( scene.view, function( object ) return object.alert ~= nil end )
check( #sentries == #oldWaypoints, "the scene holds " .. #oldWaypoints .. " guards, not " .. #sentries )

for i = 1, #oldWaypoints do
	local x, y = tileCentre( oldWaypoints[i][1][1], oldWaypoints[i][1][2] )
	local onStart = 0
	for j = 1, #sentries do
		if sentries[j].x == x and sentries[j].y == y then
			onStart = onStart + 1
		end
	end
	check( onStart == 1, "one guard starts on patrol " .. i .. "'s first point " .. x .. "," .. y .. ", not " .. onStart )
end

--------------------------------------------------------------------------------------
-- Vision against the map's walls

local hero = find( scene.view, function( object ) return object.placeAt ~= nil end )
check( hero.x == start.x and hero.y == start.y, "the hero starts on the map's player object" )

-- The crate at tile 7,5 stands between a guard on tile 4,4 facing right and a spot below and behind it.
local viewer = { x = 112, y = 112 }
check( not guard.canSee( viewer, 0, { x = 256, y = 170 }, settings.vision ), "the crate at 7,5 blocks the guard's sight" )
check( guard.canSee( viewer, 0, { x = 256, y = 112 }, settings.vision ), "the guard sees along the clear row 4" )

--------------------------------------------------------------------------------------
-- Escaping

hero:placeAt( door.x, door.y )
stub.step()

local label = find( scene.view, function( object ) return object.text == settings.text.escaped end )
check( label ~= nil and label.parent.isVisible, "standing on the door tile shows the escaped message" )

stub.sceneEvent( scene, "hide", "will" )
stub.sceneEvent( scene, "hide", "did" )

print( "top-down-stealth-play: " .. checks .. " checks, " .. failures .. " failures" )
os.exit( failures == 0 and 0 or 1 )
