-- Checks that no key, mouse or Runtime touch input changes a sample's state after hide "will".
-- Usage, from the demo root: lua5.1 tools/tests/all-samples-fade-input.lua [sample folder name ...]
-- With no names it checks all samples. Each sample runs twice in its own bounded process, once with input
-- during the fade and once without, and the two scene snapshots must match. Prints only failures and a count.

local lfs = require( "lfs" )

local SETTLE_FRAMES = 90
local TRANSITION_FRAMES = 6
local KEY_HOLD_FRAMES = 3
local CHILD_TIMEOUT = 60
local CHILD_MEMORY_KB = 1048576
local OUTPUT_LIMIT = 1000000

local STANDARD_KEYS = {
	"space", "enter", "e", "r", "z", "x", "tab", "leftShift",
	"up", "down", "left", "right", "w", "a", "s", "d",
	"1", "2", "3", "4",
}

local scriptPath = arg[0]

if string.sub( scriptPath, 1, 1 ) ~= "/" then
	scriptPath = lfs.currentdir() .. "/" .. scriptPath
end

local demoRoot = string.match( scriptPath, "^(.*)/tools/tests/[^/]*$" )
local harness = demoRoot .. "/tools/harness"

--------------------------------------------------------------------------------------
-- Child: one sample, one mode, prints its snapshot

local function collectKeys( settings )
	local found = {}
	local seen = {}

	local function addKey( name )
		if not seen[name] then
			seen[name] = true
			found[#found + 1] = name
		end
	end

	local function walkKeys( value )
		if type( value ) == "string" then
			addKey( value )

		elseif type( value ) == "table" then
			for _, child in pairs( value ) do
				walkKeys( child )
			end
		end
	end

	local function walk( value, depth )
		if type( value ) ~= "table" or depth > 4 then
			return
		end

		for key, child in pairs( value ) do
			if key == "keys" or key == "bindings" then
				walkKeys( child )
			else
				walk( child, depth + 1 )
			end
		end
	end

	walk( settings, 0 )

	for i = 1, #STANDARD_KEYS do
		addKey( STANDARD_KEYS[i] )
	end

	-- Escape belongs to the overlay's Back handling, not to the sample.
	local keys = {}

	for i = 1, #found do
		if found[i] ~= "escape" then
			keys[#keys + 1] = found[i]
		end
	end

	table.sort( keys )

	return keys
end

local function formatNumber( value )
	if type( value ) ~= "number" then
		return tostring( value )
	end

	return string.format( "%.3f", value )
end

local function snapshot( stub, scene, lines )
	local function walk( object, path )
		local internal = rawget( object, "_stub" )
		local parts = {
			path,
			formatNumber( object.x ), formatNumber( object.y ), formatNumber( object.rotation ),
			formatNumber( object.xScale ), formatNumber( object.yScale ), formatNumber( object.alpha ),
			tostring( object.isVisible ), tostring( object.text ),
		}

		if internal and internal.fillColor then
			for i = 1, #internal.fillColor do
				parts[#parts + 1] = formatNumber( internal.fillColor[i] )
			end
		end

		if object.getLinearVelocity then
			local velocityX, velocityY = object:getLinearVelocity()
			parts[#parts + 1] = "v=" .. formatNumber( velocityX ) .. "," .. formatNumber( velocityY )
		end

		local childCount = object.numChildren

		if childCount then
			parts[#parts + 1] = "children=" .. childCount
		end

		lines[#lines + 1] = table.concat( parts, " " )

		for i = 1, childCount or 0 do
			walk( object[i], path .. "." .. i )
		end
	end

	walk( scene.view, "view" )

	for i = 1, #stub.sceneChanges do
		local change = stub.sceneChanges[i]
		lines[#lines + 1] = "sceneChange " .. change.kind .. " " .. change.name
	end

	lines[#lines + 1] = "transitions " .. stub.activeTransitionCount()
	lines[#lines + 1] = "timers " .. stub.pendingTimerCount()
	lines[#lines + 1] = "audioChannels " .. #stub.activeChannels()
end

local function runChild( sampleName, withInput )
	lfs.chdir( demoRoot )
	package.path = "./?.lua;" .. harness .. "/?.lua;" .. package.path

	-- Both runs must draw the same random numbers, so the seed main.lua sets from the clock is ignored.
	local randomSeed = math.randomseed
	randomSeed( 1 )
	math.randomseed = function() end

	local stub = dofile( harness .. "/stub/solar2d.lua" )
	stub.install( harness, ".scratch/tmp/fade-input-" .. sampleName .. ( withInput and "-input" or "-quiet" ) )
	stub.call( dofile, "main.lua" )
	stub.call( function()
		require( "scripts.appOverlay" ).setBackVisible( true )
	end )

	local moduleName = "samples." .. sampleName .. ".demo"
	local _, scene = stub.call( require, moduleName )
	local _, settings = stub.call( require, "samples." .. sampleName .. ".data.settings" )

	local function frames( count )
		for _ = 1, count do
			stub.step()
		end
	end

	stub.previousSceneName = stub.currentSceneName
	stub.currentSceneName = moduleName
	stub.sceneEvent( scene, "create" )
	stub.sceneEvent( scene, "show", "will" )
	frames( TRANSITION_FRAMES )
	stub.sceneEvent( scene, "show", "did" )
	frames( SETTLE_FRAMES )

	stub.sceneEvent( scene, "hide", "will" )

	local keys = collectKeys( settings )
	local left, top = display.screenOriginX, display.screenOriginY
	local width, height = display.actualContentWidth, display.actualContentHeight
	local points = { { 0.5, 0.5 }, { 0.3, 0.7 }, { 0.7, 0.3 } }

	for i = 1, #keys do
		if withInput then
			stub.call( stub.key, keys[i], "down", false )
		end

		frames( KEY_HOLD_FRAMES )

		if withInput then
			stub.call( stub.key, keys[i], "up", false )
		end

		frames( 1 )
	end

	for i = 1, #points do
		local x, y = left + width * points[i][1], top + height * points[i][2]

		if withInput then
			local phases = { "began", "ended" }

			for phaseIndex = 1, #phases do
				stub.call( stub.fireRuntime, { name = "touch", phase = phases[phaseIndex], x = x, y = y, xStart = x, yStart = y, id = "fadeTouch", time = stub.clock } )
			end

			stub.call( stub.mouseAt, x, y, "move", false )
			stub.call( stub.mouseAt, x, y, "down", true )
			stub.call( stub.mouseAt, x, y, "up", false )
		end

		frames( 1 )
	end

	frames( TRANSITION_FRAMES )

	local lines = {}
	snapshot( stub, scene, lines )
	stub.sceneEvent( scene, "hide", "did" )
	os.execute( "rm -rf '.scratch/tmp/fade-input-" .. sampleName .. ( withInput and "-input" or "-quiet" ) .. "'" )

	for i = 1, #stub.errorOrder do
		print( "ERROR " .. stub.errorOrder[i].traceback )
	end

	print( "KEYS " .. #keys )

	for i = 1, #lines do
		print( lines[i] )
	end
end

--------------------------------------------------------------------------------------
-- Driver: runs both modes per sample and compares

local function runMode( sampleName, mode )
	local command = "bash -c 'ulimit -v " .. CHILD_MEMORY_KB .. "; exec timeout " .. CHILD_TIMEOUT
		.. " lua5.1 \"" .. scriptPath .. "\" --child " .. sampleName .. " " .. mode .. "' 2>&1 | tail -c " .. OUTPUT_LIMIT
	local handle = io.popen( command )
	local lines = {}

	for line in handle:lines() do
		lines[#lines + 1] = line
	end

	handle:close()

	return lines
end

local function checkSample( sampleName )
	local quiet = runMode( sampleName, "quiet" )
	local input = runMode( sampleName, "input" )
	local problems = {}

	local runs = { quiet, input }

	for runIndex = 1, #runs do
		local run = runs[runIndex]

		for i = 1, #run do
			if string.sub( run[i], 1, 5 ) == "ERROR" then
				problems[#problems + 1] = run[i]
			end
		end
	end

	if #quiet < 3 or #input < 3 then
		problems[#problems + 1] = "child run produced no snapshot (" .. #quiet .. "/" .. #input .. " lines)"
	end

	local differences = 0

	for i = 1, math.max( #quiet, #input ) do
		if quiet[i] ~= input[i] then
			differences = differences + 1

			if differences <= 3 then
				problems[#problems + 1] = "state changed: without input [" .. tostring( quiet[i] ) .. "] with input [" .. tostring( input[i] ) .. "]"
			end
		end
	end

	if differences > 3 then
		problems[#problems + 1] = "... " .. differences .. " differing snapshot lines in total"
	end

	return problems
end

if arg[1] == "--child" then
	runChild( arg[2], arg[3] == "input" )
	os.exit( 0 )
end

local samples = {}

if #arg > 0 then
	for i = 1, #arg do
		samples[#samples + 1] = arg[i]
	end
else
	for name in lfs.dir( demoRoot .. "/samples" ) do
		if string.sub( name, 1, 1 ) ~= "." then
			samples[#samples + 1] = name
		end
	end

	table.sort( samples )
end

local failed = 0

for i = 1, #samples do
	local problems = checkSample( samples[i] )

	if #problems > 0 then
		failed = failed + 1
		print( "FAIL " .. samples[i] )

		for j = 1, #problems do
			print( "  " .. problems[j] )
		end
	end
end

print( ( #samples - failed ) .. "/" .. #samples .. " samples ignore input after hide will" )
os.exit( failed > 0 and 1 or 0 )
