-- App shell check: a menu press shows the loading scene, which opens the sample only after a drawn frame; Back returns to the menu;
-- the disclaimer shows only on the menu and no menu content overlaps it at 960x640 or after a resize.
-- Usage, from the demo root: lua5.1 tools/tests/app-shell.lua
-- Prints only failures and one summary line; exit code 1 on failure.

local lfs = require( "lfs" )

local harness = lfs.currentdir() .. "/tools/harness"
package.path = "./?.lua;" .. harness .. "/?.lua;" .. package.path

local SAMPLE_LABEL = "Combat"
local SAMPLE_MODULE = "samples.top-down-combat.demo"
local FRAME_LIMIT = 120
local TEMPORARY_ROOT = ".scratch/tmp/app-shell"

local stub = dofile( harness .. "/stub/solar2d.lua" )
stub.install( harness, TEMPORARY_ROOT )

local checks, failures = 0, 0

local function check( condition, message )
	checks = checks + 1

	if not condition then
		failures = failures + 1
		print( "FAIL app-shell: " .. message )
	end
end

--------------------------------------------------------------------------------------
-- A small composer: the stub only records scene changes, and this check needs them carried out.

local composer = require( "composer" )

local scenes = {}
local currentName
local pendingFinish
local log = {}

local function sceneOf( name )
	if not scenes[name] then
		scenes[name] = require( name )
	end

	return scenes[name]
end

local function logEntry( kind, name )
	log[#log + 1] = { kind = kind, name = name, frame = stub.frame, current = currentName }
end

function composer.gotoScene( name, options )
	options = options or {}

	local params = options.params
	local isNew = scenes[name] == nil
	local scene = sceneOf( name )
	local previousName = currentName
	local previous = previousName and scenes[previousName]

	if isNew then
		logEntry( "create", name )
		stub.sceneEvent( scene, "create", nil, params )
	end

	if previous then
		stub.sceneEvent( previous, "hide", "will", params )
	end

	scene.view.isVisible = true
	stub.sceneEvent( scene, "show", "will", params )

	currentName = name
	stub.previousSceneName = previousName
	stub.currentSceneName = name

	local function finish()
		if previous then
			previous.view.isVisible = false
			stub.sceneEvent( previous, "hide", "did", params )
		end

		logEntry( "shown", name )
		stub.sceneEvent( scene, "show", "did", params )
	end

	if options.effect then
		pendingFinish = { clock = stub.clock + ( options.time or 0 ), run = finish }
	else
		finish()
	end
end

function composer.removeScene( name )
	local scene = scenes[name]

	if not scene then
		return
	end

	if stub.sceneHasListener( scene, "destroy" ) then
		stub.sceneEvent( scene, "destroy" )
	end

	display.remove( scene.view )
	scenes[name] = nil
	package.loaded[name] = nil
	logEntry( "removed", name )
end

local function step()
	stub.step()

	if pendingFinish and stub.clock >= pendingFinish.clock then
		local finish = pendingFinish.run
		pendingFinish = nil
		stub.call( finish )
	end
end

local function stepUntil( condition )
	for _ = 1, FRAME_LIMIT do
		if condition() then
			return true
		end

		step()
	end

	return condition()
end

--------------------------------------------------------------------------------------
-- Display helpers

local function walk( object, visit )
	visit( object )

	if object.numChildren then
		for i = 1, object.numChildren do
			walk( object[i], visit )
		end
	end
end

local function isShown( object )
	local node = object

	while node do
		if not node.isVisible or node.alpha <= 0 then
			return false
		end

		node = rawget( node, "parent" )
	end

	return true
end

local function findText( root, text )
	local found

	walk( root, function( object )
		if not found and object.text == text then
			found = object
		end
	end )

	return found
end

local function overlaps( a, b )
	return a.xMin < b.xMax and b.xMin < a.xMax and a.yMin < b.yMax and b.yMin < a.yMax
end

local function press( button )
	local x, y = button:localToContent( 0, 0 )
	stub.touchObject( button, x, y, "began" )
	stub.touchObject( button, x, y, "ended", x, y )
end

local function setScreen( originX, originY, width, height )
	display.screenOriginX = originX
	display.screenOriginY = originY
	display.actualContentWidth = width
	display.actualContentHeight = height
	stub.fireRuntime( { name = "resize" } )
end

--------------------------------------------------------------------------------------
-- Menu and disclaimer

stub.call( dofile, "main.lua" )

local strings = require( "data.strings" )
local layout = require( "data.layout" )

stepUntil( function()
	return pendingFinish == nil
end )

check( currentName == "scenes.menu", "main.lua does not open the menu" )

local menu = scenes["scenes.menu"]
local disclaimerLine = menu and findText( menu.view, strings.disclaimer[1] )
check( disclaimerLine ~= nil, "the menu has no disclaimer" )

local disclaimer = disclaimerLine and disclaimerLine.parent

local function checkMenuLayout( when )
	local disclaimerBounds = disclaimer.contentBounds
	local margin = layout.disclaimer.margin
	local centerX = ( disclaimerBounds.xMin + disclaimerBounds.xMax ) * 0.5
	local bottom = display.screenOriginY + display.actualContentHeight

	check( isShown( disclaimer ), "the disclaimer is not shown on the menu " .. when )
	check( math.abs( centerX - display.contentCenterX ) < 1e-6, "the disclaimer is not centred " .. when )
	check( math.abs( disclaimerBounds.yMax - ( bottom - margin ) ) < 1e-6, "the disclaimer is not at the bottom edge " .. when )

	for i = 1, menu.view.numChildren do
		local object = menu.view[i]

		if object ~= disclaimer then
			local bounds = object.contentBounds
			local label = object.text or ( object.numChildren and object.numChildren > 0 and object[object.numChildren].text ) or "object"
			check( not overlaps( bounds, disclaimerBounds ), "\"" .. tostring( label ) .. "\" overlaps the disclaimer " .. when )
		end
	end
end

if disclaimer then
	checkMenuLayout( "at 960x640" )

	setScreen( 0, -240, 960, 1120 )
	checkMenuLayout( "in a tall window" )

	setScreen( -320, 0, 1600, 640 )
	checkMenuLayout( "in a wide window" )

	setScreen( 0, 0, 960, 640 )
	checkMenuLayout( "back at 960x640" )
end

--------------------------------------------------------------------------------------
-- Menu press, loading scene and sample

local backLabel = findText( stub.stage, strings.back )
local backButton = backLabel and backLabel.parent
check( backButton ~= nil and not isShown( backButton ), "the Back button is missing or shown on the menu" )

local sampleLabel = menu and findText( menu.view, SAMPLE_LABEL )
check( sampleLabel ~= nil, "the menu has no " .. SAMPLE_LABEL .. " button" )

local loadingAtCreate = {}

if sampleLabel then
	local sampleScene = require( SAMPLE_MODULE )

	-- Function listeners run before the scene's own table listener, so this sees the screen as it was when create began.
	local function onSampleCreate()
		local loading = scenes["scenes.loading"]
		loadingAtCreate.frame = stub.frame
		loadingAtCreate.isCurrent = currentName == "scenes.loading"
		loadingAtCreate.isShown = loading ~= nil and isShown( loading.view ) and findText( loading.view, strings.loading ) ~= nil
		loadingAtCreate.backShown = backButton ~= nil and isShown( backButton )
	end

	sampleScene:addEventListener( "create", onSampleCreate )

	local pressFrame = stub.frame
	stub.call( press, sampleLabel.parent )

	check( currentName == "scenes.loading", "the press does not go straight to the loading scene" )
	check( stub.frame == pressFrame, "the loading scene does not appear in the frame of the press" )
	check( scenes[SAMPLE_MODULE] == nil, "the sample is created in the frame of the press" )

	local loading = scenes["scenes.loading"]

	if loading then
		check( #stub.touchables( loading.view ) == 0, "something on the loading screen listens for touches" )
		check( not isShown( backButton ), "the Back button shows on the loading screen" )
		check( not isShown( menu.view ), "the menu still shows under the loading screen" )
	end

	local opened = stepUntil( function()
		return currentName == SAMPLE_MODULE and pendingFinish == nil
	end )

	check( opened, "the sample did not open within " .. FRAME_LIMIT .. " frames" )

	local loadingShownFrame

	for i = 1, #log do
		if log[i].kind == "shown" and log[i].name == "scenes.loading" then
			loadingShownFrame = log[i].frame
		end
	end

	check( loadingAtCreate.frame ~= nil, "the sample's create never ran" )

	if loadingAtCreate.frame and loadingShownFrame then
		check( loadingAtCreate.isCurrent and loadingAtCreate.isShown, "the loading scene is not on screen when the sample's create runs" )
		check( not loadingAtCreate.backShown, "the Back button shows while the sample is created" )
		check( loadingAtCreate.frame - loadingShownFrame >= 1, "the sample is created before a frame has passed on the loading screen" )
	end

	if opened then
		check( isShown( backButton ), "the Back button is hidden in the sample" )

		local shownDisclaimer = false

		walk( stub.stage, function( object )
			for i = 1, #strings.disclaimer do
				if object.text == strings.disclaimer[i] and isShown( object ) then
					shownDisclaimer = true
				end
			end
		end )

		check( not shownDisclaimer, "the disclaimer shows in the sample" )
		check( findText( scenes[SAMPLE_MODULE].view, strings.disclaimer[1] ) == nil, "the sample view holds a disclaimer" )

		local loadingListeners = 0
		local entries = stub.runtimeEntries()

		for i = 1, #entries do
			local listener = entries[i].listener

			if type( listener ) == "function" and string.find( debug.getinfo( listener, "S" ).short_src, "scenes/loading.lua", 1, true ) then
				loadingListeners = loadingListeners + 1
			end
		end

		check( loadingListeners == 0, "the loading scene leaves " .. loadingListeners .. " Runtime listener(s) behind" )

		----------------------------------------------------------------------------------
		-- Back to the menu

		for _ = 1, 30 do
			step()
		end

		stub.call( press, backButton )

		local returned = stepUntil( function()
			return currentName == "scenes.menu" and pendingFinish == nil
		end )

		check( returned, "Back does not return to the menu" )
		check( scenes[SAMPLE_MODULE] == nil, "the sample is not removed after Back" )
		check( not isShown( backButton ), "the Back button still shows on the menu" )
		check( isShown( menu.view ) and isShown( disclaimer ), "the menu or its disclaimer is hidden after Back" )
	end
end

--------------------------------------------------------------------------------------
-- Report

for i = 1, #stub.errorOrder do
	failures = failures + 1
	print( "FAIL app-shell: ERROR " .. stub.errorOrder[i].traceback )
end

os.execute( "rm -rf '" .. TEMPORARY_ROOT .. "'" )

print( "app-shell: " .. ( checks - failures ) .. "/" .. checks .. " checks passed" )

if failures > 0 then
	os.exit( 1 )
end
