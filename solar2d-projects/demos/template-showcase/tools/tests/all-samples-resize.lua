-- Resize check for one sample: the volume slider's panel keeps to the top-right corner and every hint sits on its background after a resize.
-- In the samples listed in EXPECTED, every scene object also either stays, follows a screen corner like the Back button, or refits the screen.
-- Usage, from the demo root: lua5.1 tools/tests/all-samples-resize.lua <sample folder name> | --list
-- Prints only failures and one summary line; exit code 1 on failure.

local lfs = require( "lfs" )

local sampleName = arg[1]
local harness = lfs.currentdir() .. "/tools/harness"
package.path = "./?.lua;" .. harness .. "/?.lua;" .. package.path

-- Minimum count of objects (descendants included) expected to follow each corner, and of full-screen rects.
local EXPECTED = {
	["top-down-stealth"] = { topRight = 1 },
	["visual-novel-endings"] = { cover = 2 },
	["visual-novel-hidden-object"] = { cover = 1, topLeft = 1 },
	["visual-novel-interrogation"] = { cover = 3, topLeft = 4 },
	["visual-novel-life-sim"] = { cover = 3, topLeft = 5 },
	["visual-novel-deduction"] = { cover = 1, topLeft = 1 },
}

-- run_all.sh asks for the samples this check covers, which is every sample.
if sampleName == "--list" then
	local names = {}

	for name in lfs.dir( "samples" ) do
		if lfs.attributes( "samples/" .. name .. "/demo.lua" ) then
			names[#names + 1] = name
		end
	end

	table.sort( names )
	print( table.concat( names, "\n" ) )
	os.exit( 0 )
end

local stub = dofile( harness .. "/stub/solar2d.lua" )
stub.install( harness, ".scratch/tmp/resize-" .. sampleName )
stub.call( dofile, "main.lua" )

local strings = require( "data.strings" )
require( "scripts.appOverlay" ).setBackVisible( true )

if not lfs.attributes( "samples/" .. tostring( sampleName ) .. "/demo.lua" ) then
	print( "FAIL no sample named " .. tostring( sampleName ) )
	os.exit( 1 )
end

local expected = EXPECTED[sampleName]
local settings = require( "samples." .. sampleName .. ".data.settings" )

local checks, failures = 0, 0

local function check( condition, message )
	checks = checks + 1
	if not condition then
		failures = failures + 1
		print( "FAIL " .. sampleName .. ": " .. message )
	end
end

local function near( a, b )
	return math.abs( a - b ) < 1e-6
end

local function walk( object, visit )
	visit( object )
	if object.numChildren then
		for i = 1, object.numChildren do
			walk( object[i], visit )
		end
	end
end

local function findBackButton()
	local found
	walk( stub.stage, function( object )
		if object.text == strings.back then
			found = object.parent
		end
	end )
	return found
end

local function isShown( object )
	while object do
		if not object.isVisible then
			return false
		end

		object = object.parent
	end

	return true
end

-- Every string the sample shows as a hint: the hint and goal lines, or the visual novels' hint table.
local function collectHintStrings()
	local found = {}

	local function add( value )
		if type( value ) == "string" then
			found[value] = true

		elseif type( value ) == "table" then
			for _, item in pairs( value ) do
				add( item )
			end
		end
	end

	if settings.text then
		add( settings.text.hint )
		add( settings.text.goal )
	end

	add( settings.hint )

	return found
end

local hintStrings = collectHintStrings()

-- Each shown hint must sit inside a rect drawn before it in the same group.
local function checkHints( root, when )
	local found = 0

	walk( root, function( object )
		if not ( hintStrings[rawget( object, "text" )] and isShown( object ) ) then
			return
		end

		found = found + 1

		local text = object.contentBounds
		local parent = object.parent
		local isCovered = false

		for i = 1, parent.numChildren do
			local sibling = parent[i]
			if sibling == object then
				break
			end

			local box = sibling.contentBounds
			if sibling.path and sibling.isVisible and box.xMin <= text.xMin and box.yMin <= text.yMin and box.xMax >= text.xMax and box.yMax >= text.yMax then
				isCovered = true
			end
		end

		check( isCovered, "hint \"" .. object.text .. "\" is not on a background " .. when )
	end )

	check( found > 0, "no shown hint found " .. when )
end

-- The panel is the slider group's first child, under the label and the track.
local function checkSlider( root, when )
	local style = settings.volumeSlider
	if not style then
		return
	end

	local panel
	walk( root, function( object )
		if rawget( object, "text" ) == style.label then
			panel = object.parent[1]
		end
	end )

	check( panel ~= nil, "volume slider not found " .. when )
	if not panel then
		return
	end

	local box = panel.contentBounds
	local right = display.screenOriginX + display.actualContentWidth - style.margin
	local top = display.screenOriginY + style.margin

	check( near( box.xMax, right ) and near( box.yMin, top ), "volume slider panel is not in the top-right corner " .. when )
end

local function snapshot( root )
	local states = {}
	walk( root, function( object )
		local x, y = object:localToContent( 0, 0 )
		states[#states + 1] = { object = object, x = x, y = y, width = rawget( object, "width" ), height = rawget( object, "height" ) }
	end )
	return states
end

local function setScreen( originX, originY, width, height )
	display.screenOriginX = originX
	display.screenOriginY = originY
	display.actualContentWidth = width
	display.actualContentHeight = height
	stub.fireRuntime( { name = "resize" } )
end

local function countResize()
	local count = 0
	local entries = stub.runtimeEntries()
	for i = 1, #entries do
		if entries[i].name == "resize" then
			count = count + 1
		end
	end
	return count
end

-- Negative control: the sample's own resize listeners are dropped, so the check must fail.
if arg[2] == "--drop-sample-resize" then
	local addEventListener = Runtime.addEventListener
	Runtime.addEventListener = function( self, name, listener )
		if name == "resize" and type( listener ) == "function" and string.find( debug.getinfo( listener, "S" ).short_src, "samples/", 1, true ) then
			return true
		end
		return addEventListener( self, name, listener )
	end
end

local scene = require( "samples." .. sampleName .. ".demo" )
local resizeListenersBefore = countResize()

stub.sceneEvent( scene, "create" )
stub.sceneEvent( scene, "show", "will" )
stub.sceneEvent( scene, "show", "did" )
for _ = 1, 30 do
	stub.step()
end

local back = findBackButton()
local backX, backY = back:localToContent( 0, 0 )
local before = snapshot( scene.view )

checkSlider( scene.view, "before a resize" )
checkHints( scene.view, "before a resize" )

-- The window grows by 80 x 60 around the content area, so the screen origin moves by -40, -30.
setScreen( -40, -30, 1040, 700 )

local movedBackX, movedBackY = back:localToContent( 0, 0 )
check( near( movedBackX - backX, -40 ) and near( movedBackY - backY, -30 ), "Back button did not move with the top-left corner" )

checkSlider( scene.view, "after a resize" )
checkHints( scene.view, "after a resize" )

local counts = { cover = 0, topLeft = 0, topRight = 0, bottomLeft = 0, bottomRight = 0, still = 0 }

-- Moving objects are sorted by the corner they follow only in the samples EXPECTED lists.
if expected then
	local corners = {
		topLeft = { -40, -30 },
		topRight = { 40, -30 },
		bottomLeft = { -40, 30 },
		bottomRight = { 40, 30 },
	}

	for i = 1, #before do
		local state = before[i]
		local x, y = state.object:localToContent( 0, 0 )
		local width, height = rawget( state.object, "width" ), rawget( state.object, "height" )

		if state.width == 960 and state.height == 640 then
			local fits = width == 1040 and height == 700 and near( x, 480 ) and near( y, 320 )
			local size = tostring( width ) .. " x " .. tostring( height )
			check( fits, "full-screen rect at " .. x .. ", " .. y .. " sized " .. size .. " does not cover the resized screen" )
			counts.cover = counts.cover + 1

		elseif near( x, state.x ) and near( y, state.y ) then
			counts.still = counts.still + 1

		else
			local corner
			for name, offset in pairs( corners ) do
				if near( x - state.x, offset[1] ) and near( y - state.y, offset[2] ) then
					corner = name
				end
			end

			check( corner ~= nil, "object moved by " .. ( x - state.x ) .. ", " .. ( y - state.y ) .. ", which follows no screen corner" )
			if corner then
				counts[corner] = counts[corner] + 1
			end
		end
	end

	for name, minimum in pairs( expected ) do
		check( counts[name] >= minimum, name .. " count " .. counts[name] .. " is below " .. minimum )
	end

	for name, count in pairs( counts ) do
		if name ~= "still" and count > 0 then
			check( expected[name] ~= nil, count .. " object(s) follow " .. name .. ", which this sample is not expected to use" )
		end
	end
end

stub.sceneEvent( scene, "hide", "will" )
stub.sceneEvent( scene, "hide", "did" )

check( countResize() == resizeListenersBefore, "resize listener count after hide is " .. countResize() .. ", before show it was " .. resizeListenersBefore )

local hidden = snapshot( scene.view )
setScreen( -100, -80, 1160, 800 )

for i = 1, #hidden do
	local state = hidden[i]
	local x, y = state.object:localToContent( 0, 0 )
	local unchanged = near( x, state.x ) and near( y, state.y )
		and rawget( state.object, "width" ) == state.width and rawget( state.object, "height" ) == state.height
	check( unchanged, "a resize after hide moved or resized an object at " .. state.x .. ", " .. state.y )
end

local summary = {}
if expected then
	for name, count in pairs( counts ) do
		summary[#summary + 1] = name .. " " .. count
	end
	table.sort( summary )
end

print( sampleName .. ": " .. checks .. " checks, " .. failures .. " failures" .. ( expected and " (" .. table.concat( summary, ", " ) .. ")" or "" ) )
os.execute( "rm -rf '.scratch/tmp/resize-" .. sampleName .. "'" )
os.exit( failures == 0 and 0 or 1 )
