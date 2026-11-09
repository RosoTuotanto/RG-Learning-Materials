-- Checks the Tiled map, grid movement, input buffering and free movement of top-down-controls under the Solar2D stub.
-- Usage, from the demo root: lua5.1 tools/tests/top-down-controls.lua

package.path = "./?.lua;" .. package.path

local stub = dofile( "tools/harness/stub/solar2d.lua" )
stub.install( "tools/harness", ".scratch/tmp/top-down-controls" )

-- Steps run only when the test finishes them, so each check sees the hero on a known tile.
local pending

transition = {
	to = function( target, params )
		pending = { target = target, params = params }
		return pending
	end,

	cancel = function()
		pending = nil
	end,
}

local json = require( "json" )
local physics = require( "physics" )

local ponytiled = require( "samples.top-down-controls.libs.ponytiled" )
local input = require( "samples.top-down-controls.classes.input" )
local mapGrid = require( "samples.top-down-controls.classes.mapGrid" )
local player = require( "samples.top-down-controls.classes.player" )
local settings = require( "samples.top-down-controls.data.settings" )

physics.start()
physics.setGravity( 0, 0 )

local world = display.newGroup()
local mapData = json.decodeFile( system.pathForFile( settings.map.folder .. "/" .. settings.map.file ) )
local map = ponytiled.new( mapData, settings.map.folder )
world:insert( map )

local grid = mapGrid.new( map, mapData )
local start = map:findObject( "player" )
local startColumn, startRow = grid:worldToTile( start.x, start.y )

local controls = input.new( settings.keys )
controls:start()

local hero = player.new({ parent = world, grid = grid, input = controls, config = settings.player, column = startColumn, row = startRow })

local checks, failures = 0, 0

local function check( condition, message )
	checks = checks + 1

	if not condition then
		failures = failures + 1
		print( "FAIL " .. message )
	end
end

local function key( name, phase )
	Runtime:dispatchEvent({ name = "key", keyName = name, phase = phase })
end

-- Completes the running step transition at once.
local function finish()
	local step = pending
	pending = nil
	step.target.x, step.target.y = step.params.x, step.params.y
	step.params.onComplete()
end

local function checkTile( label, column, row )
	check( hero.column == column and hero.row == row, label .. ": expected " .. column .. "," .. row .. ", got " .. hero.column .. "," .. hero.row )
end

-- The map.
check( startColumn == 7 and startRow == 8, "the player object marks tile 7,8, got " .. startColumn .. "," .. startRow )
check( grid.columnCount == 19 and grid.rowCount == 16 and grid.width == 608 and grid.height == 512, "the map is 19x16 tiles of 32" )

local walls = map:findLayer( "physics" )
local staticWalls = 0
for i = 1, walls.numChildren do
	if walls[i].bodyType == "static" then
		staticWalls = staticWalls + 1
	end
end
check( walls.numChildren > 0 and staticWalls == walls.numChildren and not walls.isVisible, "every wall rect is a static body on a hidden layer" )

local walkableCount = 0
for row = 1, grid.rowCount do
	for column = 1, grid.columnCount do
		walkableCount = walkableCount + ( grid:isWalkable( column, row ) and 1 or 0 )
	end
end
check( walkableCount == 187, "187 walkable tiles, got " .. walkableCount )

check( not grid:isWalkable( 0, 0 ) and not grid:isWalkable( 50, 3 ) and not grid:isWalkable( 20, 3 ), "tiles outside the map are not walkable" )
check( not grid:isWalkable( 1, 1 ) and grid:isWalkable( 2, 3 ) and not grid:isWalkable( 5, 6 ), "wall, floor and rock tiles" )

local column, row = grid:worldToTile( 47.9, 16 )
check( column == 2 and row == 1, "worldToTile rounds into the containing tile" )

-- Free movement: diagonal input is normalised and drives the body at the configured speed.
key( "d", "down" )
key( "w", "down" )
local moveX, moveY = controls:getMovement()
check( math.abs( moveX - math.sqrt( 0.5 ) ) < 1e-9 and math.abs( moveY + math.sqrt( 0.5 ) ) < 1e-9, "diagonal movement is normalised" )

hero:update()
local velocityX, velocityY = hero:getLinearVelocity()
local speed = settings.player.speed
check( math.abs( velocityX - moveX * speed ) < 1e-6 and math.abs( velocityY - moveY * speed ) < 1e-6, "free movement sets the velocity" )
key( "d", "up" )
key( "w", "up" )

-- Grid movement.
hero:setMode( "grid" )
checkTile( "switching to grid snaps onto the start tile", 7, 8 )

key( "right", "down" )
hero:update()
checkTile( "step right", 8, 8 )

finish()
checkTile( "held key continues", 9, 8 )

key( "right", "up" )
key( "w", "down" )
key( "w", "up" )
finish()
checkTile( "tap during a step is buffered", 9, 7 )

finish()
checkTile( "stops after the buffered step", 9, 7 )

hero:update()
checkTile( "idle without input", 9, 7 )

key( "s", "down" )
hero:update()
finish()
key( "s", "up" )
finish()
key( "d", "down" )
hero:update()
checkTile( "blocked by the pine at 10,9", 9, 9 )

hero:update()
check( not pending, "no step starts into a blocked tile" )
key( "d", "up" )

print( "top-down-controls: " .. ( checks - failures ) .. "/" .. checks .. " checks passed" )
os.exit( failures == 0 and 0 or 1 )
