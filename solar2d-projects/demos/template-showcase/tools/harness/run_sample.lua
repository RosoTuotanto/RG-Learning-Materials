-- Smoke-runs one composer scene of the template-showcase demo under the Solar2D stub.
-- Usage, from the demo root: lua5.1 tools/harness/run_sample.lua <module> [--frames N] [--verbose]
-- Prints OK <module>, or FAIL with every error and every Runtime listener left behind; exit code 1 on failure.

local lfs = require( "lfs" )

--------------------------------------------------------------------------------------
-- Arguments and paths

local BASE_FRAMES = 300
local TRANSITION_FRAMES = 6
local AFTER_HIDE_FRAMES = 30
local AFTER_DESTROY_FRAMES = 30
local OBJECT_PASS_LIMIT = 80

local moduleName
local frameCount = BASE_FRAMES
local isVerbose = false

do
	local i = 1

	while arg[i] do
		if arg[i] == "--frames" then
			frameCount = tonumber( arg[i + 1] )
			i = i + 2

		elseif arg[i] == "--verbose" then
			isVerbose = true
			i = i + 1

		else
			moduleName = arg[i]
			i = i + 1
		end
	end
end

if not moduleName or not frameCount or frameCount < 1 then
	print( "Usage: lua5.1 tools/harness/run_sample.lua <module> [--frames N] [--verbose]" )
	os.exit( 2 )
end

local scriptPath = arg[0]

if string.sub( scriptPath, 1, 1 ) ~= "/" then
	scriptPath = lfs.currentdir() .. "/" .. scriptPath
end

local harnessDirectory = string.match( scriptPath, "^(.*)/[^/]*$" )
local demoRoot = string.match( harnessDirectory, "^(.*)/tools/harness$" )

if not demoRoot or not lfs.chdir( demoRoot ) then
	print( "run_sample.lua must live in <demo root>/tools/harness/" )
	os.exit( 2 )
end

package.path = "./?.lua;" .. harnessDirectory .. "/?.lua;" .. package.path

local temporaryRoot = os.tmpname()
os.remove( temporaryRoot )
temporaryRoot = demoRoot .. "/.scratch/tmp/" .. string.match( temporaryRoot, "([^/]+)$" )

local stub = dofile( harnessDirectory .. "/stub/solar2d.lua" )
stub.install( harnessDirectory, temporaryRoot )

--------------------------------------------------------------------------------------
-- Listener bookkeeping

local function describeListener( listener )
	if type( listener ) == "function" then
		local info = debug.getinfo( listener, "S" )

		return "function at " .. info.short_src .. ":" .. info.linedefined
	end

	return "table listener " .. tostring( listener )
end

local function snapshotRuntime()
	local counts = {}
	local entries = stub.runtimeEntries()

	for i = 1, #entries do
		local entry = entries[i]
		counts[entry.name] = counts[entry.name] or {}
		counts[entry.name][entry.listener] = ( counts[entry.name][entry.listener] or 0 ) + 1
	end

	return counts
end

-- Runtime listeners registered now that were not registered in the snapshot.
local function listenersSince( snapshot )
	local remaining = {}

	for name, listeners in pairs( snapshot ) do
		remaining[name] = {}

		for listener, count in pairs( listeners ) do
			remaining[name][listener] = count
		end
	end

	local added = {}
	local entries = stub.runtimeEntries()

	for i = 1, #entries do
		local entry = entries[i]
		local counts = remaining[entry.name]

		if not stub.isLibraryListener( entry.listener ) then
			if counts and ( counts[entry.listener] or 0 ) > 0 then
				counts[entry.listener] = counts[entry.listener] - 1
			else
				added[#added + 1] = entry
			end
		end
	end

	return added
end

--------------------------------------------------------------------------------------
-- Input script, written for 300 frames and scaled to the requested count

local schedule = {}
local heldKeys = {}
local pointerDown = false

local function at( frame )
	return math.max( 1, math.min( frameCount, math.floor( frame * frameCount / BASE_FRAMES + 0.5 ) ) )
end

local function addAction( frame, action )
	schedule[frame] = schedule[frame] or {}
	table.insert( schedule[frame], action )
end

local function isShiftHeld()
	return heldKeys["leftShift"] == true
end

local function pressKey( keyName, downFrame, upFrame )
	addAction( at( downFrame ), function()
		heldKeys[keyName] = true
		stub.key( keyName, "down", isShiftHeld() )
	end )

	addAction( math.max( at( upFrame ), at( downFrame ) ), function()
		heldKeys[keyName] = nil
		stub.key( keyName, "up", isShiftHeld() )
	end )
end

local keyScript = {
	{ "d", 10, 40 },
	{ "w", 20, 60 },
	{ "right", 60, 90 },
	{ "up", 70, 100 },
	{ "space", 80, 95 },
	{ "leftShift", 100, 104 },
	{ "x", 102, 104 },
	{ "a", 105, 140 },
	{ "left", 110, 130 },
	{ "tab", 120, 122 },
	{ "s", 140, 170 },
	{ "down", 150, 160 },
	{ "e", 175, 177 },
	{ "tab", 180, 182 },
	{ "z", 185, 187 },
	{ "r", 190, 192 },
	{ "1", 194, 196 },
	{ "2", 198, 200 },
	{ "3", 202, 204 },
	{ "4", 206, 208 },
	{ "up", 210, 212 },
	{ "down", 214, 216 },
	{ "enter", 218, 220 },
	{ "space", 224, 226 },
	{ "w", 230, 250 },
	{ "space", 245, 262 },
	{ "d", 252, 280 },
	{ "r", 265, 267 },
	{ "escape", 285, 287 },
}

for i = 1, #keyScript do
	pressKey( keyScript[i][1], keyScript[i][2], keyScript[i][3] )
end

local width, height = display.actualContentWidth, display.actualContentHeight
local left, top = display.screenOriginX, display.screenOriginY

local function screenPoint( fractionX, fractionY )
	return left + width * fractionX, top + height * fractionY
end

-- The mouse sweeps the whole screen for the entire run.
for frame = 1, frameCount, 2 do
	addAction( frame, function()
		local progress = frame * BASE_FRAMES / frameCount
		local x, y = screenPoint( 0.5 + 0.45 * math.sin( progress * 0.07 ), 0.5 + 0.4 * math.sin( progress * 0.11 ) )
		stub.mouseAt( x, y, pointerDown and "drag" or "move", pointerDown )
	end )
end

local function touchPhase( x, y, phase, xStart, yStart )
	if phase == "began" then
		pointerDown = true
		stub.mouseAt( x, y, "down", true )

	elseif phase == "ended" then
		pointerDown = false
		stub.mouseAt( x, y, "up", false )
	end

	stub.touchAt( x, y, phase, xStart, yStart )
end

-- Drags with matching start and end points are taps.
local function drag( startFrame, endFrame, fromX, fromY, toX, toY )
	local x1, y1 = screenPoint( fromX, fromY )
	local x2, y2 = screenPoint( toX, toY )
	local first, last = at( startFrame ), math.max( at( endFrame ), at( startFrame ) )

	addAction( first, function()
		touchPhase( x1, y1, "began" )
	end )

	for frame = first + 1, last - 1 do
		addAction( frame, function()
			local progress = ( frame - first ) / ( last - first )
			touchPhase( x1 + ( x2 - x1 ) * progress, y1 + ( y2 - y1 ) * progress, "moved", x1, y1 )
		end )
	end

	addAction( last, function()
		touchPhase( x2, y2, "ended", x1, y1 )
	end )
end

local tapScript = {
	{ 30, 0.5, 0.5 },
	{ 50, 0.75, 0.6 },
	{ 75, 0.3, 0.7 },
	{ 125, 0.5, 0.85 },
	{ 135, 0.62, 0.4 },
	{ 200, 0.2, 0.5 },
	{ 235, 0.5, 0.5 },
	{ 255, 0.85, 0.75 },
	{ 270, 0.4, 0.3 },
}

for i = 1, #tapScript do
	local tap = tapScript[i]
	drag( tap[1], tap[1] + 2, tap[2], tap[3], tap[2], tap[3] )
end

drag( 150, 166, 0.3, 0.5, 0.7, 0.55 )
drag( 238, 250, 0.95, 0.95, 0.85, 0.95 )

local scene
local touchedCount = 0

-- Every touchable object in the scene gets a press, a drag and a release at its own position.
local function touchEveryObject()
	if not scene or not stub.isAlive( scene.view ) then
		return
	end

	local objects = stub.touchables( scene.view )

	for i = 1, math.min( #objects, OBJECT_PASS_LIMIT ) do
		local object = objects[i]

		if stub.isDescendant( object, scene.view ) then
			local bounds = stub.contentBounds( object )
			local x, y = ( bounds.xMin + bounds.xMax ) * 0.5, ( bounds.yMin + bounds.yMax ) * 0.5

			touchedCount = touchedCount + 1
			stub.touchObject( object, x, y, "began" )
			stub.touchObject( object, x + 24, y + 12, "moved", x, y )
			stub.touchObject( object, x + 48, y + 24, "moved", x, y )
			stub.touchObject( object, x + 48, y + 24, "ended", x, y )
			stub.focus = nil
		end
	end
end

addAction( at( 160 ), touchEveryObject )
addAction( at( 275 ), touchEveryObject )

addAction( at( 145 ), function()
	stub.fireRuntime( { name = "resize" } )
end )

--------------------------------------------------------------------------------------
-- Run

local failures = {}

local function fail( message )
	failures[#failures + 1] = message
end

local function runFrames( count )
	for _ = 1, count do
		stub.step()
	end
end

local function runScriptedFrames()
	for frame = 1, frameCount do
		local actions = schedule[frame] or {}

		for i = 1, #actions do
			stub.call( actions[i] )
		end

		stub.step()
	end
end

local function reportListeners( added, when )
	for i = 1, #added do
		fail( "LEAK Runtime \"" .. added[i].name .. "\" listener (" .. describeListener( added[i].listener ) .. ") still registered " .. when )
	end
end

local function sceneEvent( name, phase )
	if stub.sceneHasListener( scene, name ) then
		stub.sceneEvent( scene, name, phase )
	end
end

stub.call( dofile, "main.lua" )

if moduleName ~= "scenes.menu" then
	stub.call( function()
		require( "scripts.appOverlay" ).setBackVisible( true )
	end )
end

local loaded, result = stub.call( require, moduleName )

if loaded and not stub.isScene( result ) then
	fail( moduleName .. " does not return a composer scene" )
	loaded = false
end

if loaded then
	scene = result
	stub.previousSceneName = stub.currentSceneName
	stub.currentSceneName = moduleName

	local beforeCreate = snapshotRuntime()
	sceneEvent( "create" )

	local beforeShow = snapshotRuntime()
	sceneEvent( "show", "will" )
	runFrames( TRANSITION_FRAMES )
	sceneEvent( "show", "did" )

	local timersBefore = stub.pendingTimerCount()
	runScriptedFrames()

	for keyName in pairs( heldKeys ) do
		stub.call( stub.key, keyName, "up", false )
	end

	sceneEvent( "hide", "will" )
	runFrames( TRANSITION_FRAMES )
	sceneEvent( "hide", "did" )

	local afterHide = listenersSince( beforeShow )
	reportListeners( afterHide, "after hide did" )

	if stub.pendingTimerCount() > timersBefore then
		stub.warn( stub.pendingTimerCount() .. " timer(s) still pending after hide did" )
	end

	if stub.activeTransitionCount() > 0 then
		stub.warn( stub.activeTransitionCount() .. " transition(s) still running after hide did" )
	end

	local channels = stub.activeChannels()

	for i = 1, #channels do
		stub.warn( "audio channel " .. channels[i].channel .. " (" .. tostring( channels[i].filename ) .. ") still playing after hide did" )
	end

	if stub.physicsState() == "running" then
		stub.warn( "physics still running after hide did; pause it in hide will" )
	end

	if stub.records.physicsStop then
		stub.warn( "physics.stop() was called; the sample contract asks for physics.pause()" )
	end

	if stub.records.physicsSetScale then
		stub.warn( "physics.setScale() was called; the sample contract leaves the scale at its default" )
	end

	if stub.isAlive( scene.view ) then
		scene.view.isVisible = false
	end

	runFrames( AFTER_HIDE_FRAMES )

	sceneEvent( "destroy" )

	if stub.isAlive( scene.view ) then
		display.remove( scene.view )
	end

	scene.view = nil
	runFrames( AFTER_DESTROY_FRAMES )

	local reported = {}

	for i = 1, #afterHide do
		reported[afterHide[i].listener] = true
	end

	local afterDestroy = listenersSince( beforeCreate )
	local unreported = {}

	for i = 1, #afterDestroy do
		if not reported[afterDestroy[i].listener] then
			unreported[#unreported + 1] = afterDestroy[i]
		end
	end

	reportListeners( unreported, "after destroy" )
end

--------------------------------------------------------------------------------------
-- Report

os.execute( "rm -rf '" .. temporaryRoot .. "'" )

for i = 1, #stub.warnings do
	print( "WARN " .. stub.warnings[i] )
end

if isVerbose then
	for i = 1, #stub.sceneChanges do
		local change = stub.sceneChanges[i]
		print( "INFO composer." .. change.kind .. "( \"" .. change.name .. "\" ) from " .. change.caller .. " at frame " .. change.frame )
	end

	print( "INFO " .. touchedCount .. " object touch sequences, " .. #stub.world.bodies .. " physics bodies left, " .. stub.frame .. " frames" )
end

if #stub.errorOrder == 0 and #failures == 0 then
	print( "OK " .. moduleName )
	os.exit( 0 )
end

print( "FAIL " .. moduleName )

for i = 1, #failures do
	print( failures[i] )
end

for i = 1, #stub.errorOrder do
	local entry = stub.errorOrder[i]
	local times = entry.count > 1 and ( " (x" .. entry.count .. ")" ) or ""
	print( "ERROR" .. times .. " " .. entry.traceback )
end

os.exit( 1 )
