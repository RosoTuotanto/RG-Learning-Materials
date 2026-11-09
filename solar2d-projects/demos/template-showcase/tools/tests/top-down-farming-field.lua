-- Headless checks of the farm rules and the hero's target tile. Run from the demo root; prints failures and a count.
local harnessDirectory = "./tools/harness"
package.path = "./?.lua;" .. harnessDirectory .. "/?.lua;" .. package.path

local stub = dofile( harnessDirectory .. "/stub/solar2d.lua" )
local temporaryRoot = ".scratch/tmp/top-down-farming-field"
stub.install( harnessDirectory, temporaryRoot )

local json = require( "json" )

local field = require( "samples.top-down-farming.classes.field" )
local mapGrid = require( "samples.top-down-farming.classes.mapGrid" )
local player = require( "samples.top-down-farming.classes.player" )
local ponytiled = require( "samples.top-down-farming.libs.ponytiled" )
local settings = require( "samples.top-down-farming.data.settings" )

local checkCount = 0
local failureCount = 0

local function check( condition, label )
	checkCount = checkCount + 1
	if not condition then
		failureCount = failureCount + 1
		print( "FAIL " .. label )
	end
end

-- Field rules on a two-tile field.
local farm = field.new( { { column = 1, row = 1 }, { column = 2, row = 1 } }, 3 )
local plot = farm:getPlot( 1, 1 )

check( farm:useTool( "seeds", 1, 1 ) == nil, "seeds on grass does nothing" )
check( farm:useTool( "water", 1, 1 ) == nil, "water on grass does nothing" )
check( farm:useTool( "hand", 1, 1 ) == nil, "hand on grass does nothing" )
check( farm:useTool( "hoe", 5, 5 ) == nil, "hoe outside the field does nothing" )
check( plot.state == "grass" and plot.stage == 0 and not plot.watered, "wrong tools leave the plot unchanged" )

check( farm:useTool( "hoe", 1, 1 ) == "till" and plot.state == "tilled", "hoe tills grass" )
check( farm:useTool( "hoe", 1, 1 ) == nil, "hoe on tilled soil does nothing" )
check( farm:useTool( "water", 1, 1 ) == nil and not plot.watered, "water on bare soil does nothing" )
check( farm:useTool( "hand", 1, 1 ) == nil, "hand on bare soil does nothing" )

check( farm:useTool( "seeds", 1, 1 ) == "plant" and plot.state == "planted" and plot.stage == 1, "seeds plant on tilled soil" )
check( farm:useTool( "seeds", 1, 1 ) == nil, "seeds on a planted tile do nothing" )
check( farm:useTool( "hand", 1, 1 ) == nil, "hand on an unripe crop does nothing" )

check( farm:useTool( "water", 1, 1 ) == "water" and plot.watered, "water marks a planted tile" )
check( farm:useTool( "water", 1, 1 ) == nil, "watering twice does nothing" )

farm:advanceDay()
check( farm.day == 2 and plot.stage == 2 and not plot.watered, "a watered crop grows one stage and dries overnight" )

farm:advanceDay()
check( farm.day == 3 and plot.stage == 2, "a dry crop does not grow" )

farm:useTool( "water", 1, 1 )
farm:advanceDay()
check( plot.stage == 3, "the crop ripens at the last stage" )

check( farm:useTool( "water", 1, 1 ) == nil, "water on a ripe crop does nothing" )
farm:advanceDay()
check( plot.stage == 3, "a ripe crop stays at the last stage" )

check( farm:useTool( "hand", 1, 1 ) == "harvest", "hand harvests a ripe crop" )
check( farm.harvestCount == 1 and plot.state == "tilled" and plot.stage == 0, "harvest counts and leaves tilled soil" )
check( farm:getPlot( 2, 1 ).state == "grass", "other plots are untouched" )

-- Three days from planting to ripe when watered every day.
local quick = field.new( { { column = 1, row = 1 } }, 3 )
quick:useTool( "hoe", 1, 1 )
quick:useTool( "seeds", 1, 1 )
for _ = 1, 2 do
	quick:useTool( "water", 1, 1 )
	quick:advanceDay()
end
check( quick.day == 3 and quick:useTool( "hand", 1, 1 ) == "harvest", "planted on day 1, harvested on day 3" )

-- Target tile for every facing, driven through the hero's own update.
local movement = { 0, 0 }
local fakeInput = {
	getMovement = function()
		return movement[1], movement[2]
	end,
}

require( "physics" ).start()

local mapData = json.decodeFile( system.pathForFile( settings.map.folder .. "/" .. settings.map.file ) )
local map = ponytiled.new( mapData, settings.map.folder )
local grid = mapGrid.new( map, mapData )

local hero = player.new({ parent = display.newGroup(), grid = grid, input = fakeInput, config = settings.player, column = 10, row = 10 })

local diagonal = math.sqrt( 0.5 )
local cases = {
	{ 0, 0, 10, 11, "start facing down" },
	{ 1, 0, 11, 10, "right" },
	{ -1, 0, 9, 10, "left" },
	{ 0, -1, 10, 9, "up" },
	{ 0, 1, 10, 11, "down" },
	{ diagonal, diagonal, 11, 11, "down-right" },
	{ -diagonal, diagonal, 9, 11, "down-left" },
	{ diagonal, -diagonal, 11, 9, "up-right" },
	{ -diagonal, -diagonal, 9, 9, "up-left" },
	{ 0, 0, 9, 9, "standing still keeps the last facing" },
}

for i = 1, #cases do
	local case = cases[i]
	movement[1], movement[2] = case[1], case[2]
	hero:update()

	-- Off-centre positions inside the tile still pick the neighbour.
	for _, offset in pairs( { -12, 0, 12 } ) do
		hero.x, hero.y = 304 + offset, 304 - offset
		local column, row = hero:getTargetTile()
		check( column == case[3] and row == case[4], "target " .. case[5] .. " offset " .. offset .. " got " .. column .. "," .. row )
	end
end

local bed = grid:findTiles( "bed" )[1]
check( bed.column == 4 and bed.row == 5, "bed object on tile 4,5" )
check( grid:getObjectType( bed.column, bed.row ) == "bed", "bed lookup by tile" )
check( grid:getObjectType( 1, 1 ) == nil, "no object on a wall tile" )

local plots = grid:findTiles( "field" )
check( #plots == 36, "field has 36 plots" )

-- The plots fill columns 13-18 of rows 5-10, each once.
local plotCount = {}
for i = 1, #plots do
	local key = plots[i].column .. "," .. plots[i].row
	plotCount[key] = ( plotCount[key] or 0 ) + 1
end

for row = 5, 10 do
	for column = 13, 18 do
		check( plotCount[column .. "," .. row] == 1, "plot at " .. column .. "," .. row )
	end
end

local start = grid:findTiles( "player" )[1]
check( start.column == 7 and start.row == 9, "start on tile 7,9" )

os.execute( "rm -rf '" .. temporaryRoot .. "'" )
print( checkCount .. " checks, " .. failureCount .. " failures" )
os.exit( failureCount == 0 and 0 or 1 )
