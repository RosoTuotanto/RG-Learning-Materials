-- Solar2D engine stand-in for the template-showcase smoke harness, run under stock Lua 5.1.
-- Library tables raise an error on any field they do not stub, so a missing stub shows up by name.

local stub = {}

--------------------------------------------------------------------------------------
-- Forward declarations & variables

local FRAME_MS = 1000 / 60
local PIXELS_PER_METER = 30
local CHANNEL_COUNT = 32

-- The engine gives a params table without bounce a bounce of 0, and a body added with no params table at all 0.5.
local implicitElementBounce = 0.5

-- The engine gives a params table without friction a friction of 0, and a body added with no params table at all 0.3.
local implicitElementFriction = 0.3

local harnessDirectory
local runtimeState
local currentStage
local objectMetatable
local world
local channels = {}

stub.clock = 0
stub.frame = 0
stub.errorOrder = {}
stub.errorsByMessage = {}
stub.warnings = {}
stub.warningSeen = {}
stub.sceneChanges = {}
stub.records = {}
stub.defaults = {}
stub.focus = nil

--------------------------------------------------------------------------------------
-- Error and warning collection

function stub.recordError( message, traceback )
	local entry = stub.errorsByMessage[message]

	if entry then
		entry.count = entry.count + 1
		return
	end

	entry = { message = message, traceback = traceback or message, count = 1 }
	stub.errorsByMessage[message] = entry
	stub.errorOrder[#stub.errorOrder + 1] = entry
end

function stub.warn( message )
	if not stub.warningSeen[message] then
		stub.warningSeen[message] = true
		stub.warnings[#stub.warnings + 1] = message
	end
end

local function errorHandler( message )
	return { message = tostring( message ), traceback = debug.traceback( tostring( message ), 2 ) }
end

-- Runs func, recording any error with its traceback; returns ok and func's first result.
function stub.call( func, ... )
	local args = { ... }
	local count = select( "#", ... )
	local ok, result = xpcall( function()
		return func( unpack( args, 1, count ) )
	end, errorHandler )

	if not ok then
		stub.recordError( result.message, result.traceback )
		return false
	end

	return true, result
end

local function strict( name, library, getters, allowNil )
	return setmetatable( library, {
		__index = function( _, key )
			if getters and getters[key] then
				return getters[key]()
			end

			if allowNil and allowNil[key] then
				return nil
			end

			error( "Solar2D stub: " .. name .. "." .. tostring( key ) .. " is not stubbed", 2 )
		end,
	} )
end

-- Numeric strings pass, as they do through the engine's luaL_checknumber.
local function checkNumber( caller, position, value )
	if type( value ) ~= "number" and not ( type( value ) == "string" and tonumber( value ) ) then
		error( "bad argument #" .. position .. " to '" .. caller .. "' (number expected, got " .. type( value ) .. ")", 3 )
	end
end

--------------------------------------------------------------------------------------
-- Files

local function fileExists( path )
	local file = path and io.open( path, "rb" )

	if file then
		file:close()
		return true
	end

	return false
end

-- Reads a PNG's IHDR; returns nil for a missing or non-PNG file.
local function readPngSize( path )
	local file = io.open( path, "rb" )

	if not file then
		return nil
	end

	local header = file:read( 24 )
	file:close()

	if not header or #header < 24 or string.sub( header, 2, 4 ) ~= "PNG" or string.sub( header, 13, 16 ) ~= "IHDR" then
		return nil
	end

	local function readU32( offset )
		local b1, b2, b3, b4 = string.byte( header, offset, offset + 3 )

		return ( ( b1 * 256 + b2 ) * 256 + b3 ) * 256 + b4
	end

	return readU32( 17 ), readU32( 21 )
end

-- Length of a PCM WAV in milliseconds, or nil when the file is not one.
local function readWavDuration( path )
	local file = io.open( path, "rb" )

	if not file then
		return nil
	end

	local data = file:read( 4096 ) or ""
	file:close()

	if string.sub( data, 1, 4 ) ~= "RIFF" or string.sub( data, 9, 12 ) ~= "WAVE" then
		return nil
	end

	local function readU32( offset )
		local b1, b2, b3, b4 = string.byte( data, offset, offset + 3 )

		return ( ( b4 * 256 + b3 ) * 256 + b2 ) * 256 + b1
	end

	local position = 13
	local byteRate

	while position + 8 <= #data do
		local chunkId = string.sub( data, position, position + 3 )
		local chunkSize = readU32( position + 4 )

		if chunkId == "fmt " then
			byteRate = readU32( position + 16 )

		elseif chunkId == "data" then
			if byteRate and byteRate > 0 then
				return chunkSize / byteRate * 1000
			end

			return nil
		end

		position = position + 8 + chunkSize + chunkSize % 2
	end

	return nil
end

local function newDirectory( name )
	return { name = name, isDirectory = true }
end

local function isDirectory( value )
	return type( value ) == "table" and rawget( value, "isDirectory" ) == true
end

local function resolvePath( name, baseDirectory )
	baseDirectory = baseDirectory or system.ResourceDirectory

	if baseDirectory == system.ResourceDirectory then
		return name
	end

	return stub.directoryPaths[baseDirectory.name] .. "/" .. name
end

local function checkAsset( kind, filename, baseDirectory )
	if type( filename ) ~= "string" then
		error( kind .. " filename must be a string, got " .. type( filename ), 3 )
	end

	local path = resolvePath( filename, baseDirectory )

	if not fileExists( path ) then
		stub.warn( "missing " .. kind .. ": " .. filename )
		return nil
	end

	return path
end

--------------------------------------------------------------------------------------
-- Event dispatch, following the engine's EventDispatcher

local function newDispatcherState()
	return { functions = {}, tables = {} }
end

local function listenerKind( listener )
	local listenerType = type( listener )

	if listenerType == "function" then
		return "functions"

	elseif listenerType == "table" then
		return "tables"
	end

	return nil
end

local function addListener( state, owner, name, listener )
	if listener == nil and type( owner ) == "table" and rawget( owner, name ) then
		listener = owner
	end

	local kind = listenerKind( listener )

	if type( name ) ~= "string" then
		error( "addEventListener: event name must be a string, got " .. type( name ), 3 )
	end

	if not kind then
		error( "addEventListener: the \"" .. name .. "\" listener is " .. type( listener ) .. ", not a function or a table", 3 )
	end

	state[kind][name] = state[kind][name] or {}
	table.insert( state[kind][name], listener )

	return true
end

local function removeListener( state, owner, name, listener )
	if listener == nil and type( owner ) == "table" and rawget( owner, name ) then
		listener = owner
	end

	local kind = listenerKind( listener )
	local array = kind and state[kind][name]

	if array then
		for i = 1, #array do
			if rawequal( array[i], listener ) then
				table.remove( array, i )

				if #array == 0 then
					state[kind][name] = nil
				end

				return true
			end
		end
	end

	return nil
end

local function hasListener( state, name, listener )
	local kind = listenerKind( listener )
	local array = kind and state[kind][name]

	if array then
		for i = 1, #array do
			if rawequal( array[i], listener ) then
				return true
			end
		end
	end

	return false
end

local function hasAnyListener( state, name )
	return state.functions[name] ~= nil or state.tables[name] ~= nil
end

local function copyArray( array )
	local copy = {}

	for i = 1, #( array or {} ) do
		copy[i] = array[i]
	end

	return copy
end

-- Function listeners run before table listeners, each only while still registered.
local function dispatch( state, event )
	local name = event.name
	local handled = false
	local functions = copyArray( state.functions[name] )

	for i = 1, #functions do
		if hasListener( state, name, functions[i] ) then
			local ok, result = stub.call( functions[i], event )
			handled = ( ok and result ) or handled
		end
	end

	local tables = copyArray( state.tables[name] )

	for i = 1, #tables do
		local listener = tables[i]

		if hasListener( state, name, listener ) then
			local method = listener[name]

			if type( method ) == "function" then
				local ok, result = stub.call( method, listener, event )
				handled = ( ok and result ) or handled
			end
		end
	end

	return handled and true or false
end

--------------------------------------------------------------------------------------
-- Runtime

runtimeState = newDispatcherState()

Runtime = {}

function Runtime:addEventListener( name, listener )
	return addListener( runtimeState, self, name, listener )
end

function Runtime:removeEventListener( name, listener )
	return removeListener( runtimeState, self, name, listener )
end

function Runtime:hasEventListener( name, listener )
	return hasListener( runtimeState, name, listener )
end

function Runtime:dispatchEvent( event )
	return dispatch( runtimeState, event )
end

function Runtime.verifyListener( listener, name )
	local listenerType = type( listener )

	if listenerType == "function" then
		return listener

	elseif listenerType == "table" and type( listener[name] ) == "function" then
		return listener
	end

	return nil
end

function Runtime.callListener( listener, name, ... )
	local listenerType = type( listener )

	if listenerType == "function" then
		return listener( ... )

	elseif listenerType == "table" then
		return listener[name]( listener, ... )
	end
end

strict( "Runtime", Runtime )

-- Every registered Runtime listener as { name, listener }.
function stub.runtimeEntries()
	local entries = {}
	local kinds = { "functions", "tables" }

	for k = 1, #kinds do
		for name, array in pairs( runtimeState[kinds[k]] ) do
			for i = 1, #array do
				entries[#entries + 1] = { name = name, listener = array[i] }
			end
		end
	end

	return entries
end

function stub.fireRuntime( event )
	return dispatch( runtimeState, event )
end

--------------------------------------------------------------------------------------
-- Display object internals

-- Fields the engine proxies; they read nil once an object is removed.
local ENGINE_KEYS = {
	"x", "y", "width", "height", "alpha", "rotation", "xScale", "yScale", "anchorX", "anchorY",
	"isVisible", "isHitTestable", "strokeWidth", "numChildren", "parent", "text", "size",
	"anchorChildren", "blendMode", "align", "font", "frame", "numFrames", "sequence", "isPlaying",
	"timeScale", "isHitTestMasked", "maskX", "maskY", "maskScaleX", "maskScaleY", "maskRotation",
}

local BODY_KEYS = {
	"bodyType", "isAwake", "isBodyActive", "isBullet", "isSleepingAllowed", "isFixedRotation",
	"angularVelocity", "linearDamping", "angularDamping", "isSensor", "gravityScale", "mass",
}

local commonMethods = {}
local groupMethods = {}
local bodyMethods = {}
local getters = {}

local function isAlive( object )
	return type( object ) == "table" and getmetatable( object ) == objectMetatable
end

stub.isAlive = isAlive

local function internalOf( object )
	return rawget( object, "_stub" )
end

local function isGroup( value )
	return isAlive( value ) and internalOf( value ).isGroup == true
end

local function newFillTable( paint )
	return setmetatable( { type = paint and paint.type or "paint" }, {
		__index = function( fill, key )
			if key == "effect" then
				return rawget( fill, "_effect" )
			end

			return paint and paint[key]
		end,

		__newindex = function( fill, key, value )
			if key == "effect" then
				rawset( fill, "_effect", value and { name = value } or nil )
				return
			end

			rawset( fill, key, value )
		end,
	} )
end

local function objectIndex( object, key )
	local internal = rawget( object, "_stub" )
	local method = internal.methods[key] or commonMethods[key]

	if method then
		return method
	end

	if internal.body and bodyMethods[key] then
		return bodyMethods[key]
	end

	local getter = getters[key]

	if getter then
		return getter( object, internal )
	end

	return nil
end

local function objectNewIndex( object, key, value )
	local internal = rawget( object, "_stub" )

	if key == "fill" then
		if type( value ) == "table" and value.type == "image" then
			if value.sheet then
				if type( value.frame ) ~= "number" or value.frame < 1 or value.frame > value.sheet.frameCount then
					error( "image fill frame " .. tostring( value.frame ) .. " is outside its sheet's 1.." .. value.sheet.frameCount, 2 )
				end
			else
				checkAsset( "image", value.filename, value.baseDir )
			end
		end

		internal.fill = newFillTable( value )
		return

	elseif key == "stroke" or key == "path" then
		internal[key] = value
		return
	end

	rawset( object, key, value )
end

objectMetatable = { __index = objectIndex, __newindex = objectNewIndex }

local function removeFromParent( object )
	local parent = rawget( object, "parent" )

	if not parent then
		return
	end

	for i = 1, parent.numChildren do
		if rawequal( parent[i], object ) then
			table.remove( parent, i )
			rawset( parent, "numChildren", parent.numChildren - 1 )
			break
		end
	end

	rawset( object, "parent", nil )
end

local function insertChild( group, child, index )
	if not isGroup( group ) then
		error( "insert: the parent is not a display group", 3 )
	end

	if not isAlive( child ) then
		error( "insert: the child is not a live display object", 3 )
	end

	local node = group

	while node do
		if rawequal( node, child ) then
			error( "insert: a group cannot be inserted into itself or its own children", 3 )
		end

		node = rawget( node, "parent" )
	end

	removeFromParent( child )

	local count = group.numChildren

	if type( index ) ~= "number" or index > count + 1 then
		index = count + 1
	elseif index < 1 then
		index = 1
	end

	table.insert( group, index, child )
	rawset( group, "numChildren", count + 1 )
	rawset( child, "parent", group )
end

local function newObject( kind, parent, methods )
	local object = {
		x = 0,
		y = 0,
		width = 0,
		height = 0,
		alpha = 1,
		rotation = 0,
		xScale = 1,
		yScale = 1,
		anchorX = 0.5,
		anchorY = 0.5,
		isVisible = true,
		isHitTestable = false,
		strokeWidth = 0,
	}

	object._stub = { kind = kind, methods = methods or {}, dispatcher = newDispatcherState() }
	setmetatable( object, objectMetatable )

	if parent ~= false then
		insertChild( parent or currentStage, object )
	end

	return object
end

local function newGroupObject( kind, parent )
	local group = newObject( kind, false, groupMethods )
	rawset( group, "width", nil )
	rawset( group, "height", nil )
	rawset( group, "numChildren", 0 )
	rawset( group, "anchorChildren", false )
	internalOf( group ).isGroup = true

	if parent ~= false then
		insertChild( parent or currentStage, group )
	end

	return group
end

local function destroy( object )
	local internal = internalOf( object )

	if internal.isGroup then
		for i = object.numChildren, 1, -1 do
			destroy( object[i] )
		end
	end

	if internal.body then
		stub.removeBodyInternal( object )
	end

	removeFromParent( object )

	if rawequal( stub.focus, object ) then
		stub.focus = nil
	end

	dispatch( internal.dispatcher, { name = "finalize", target = object } )

	for i = 1, #ENGINE_KEYS do
		rawset( object, ENGINE_KEYS[i], nil )
	end

	rawset( object, "_stub", nil )
	setmetatable( object, nil )
end

--------------------------------------------------------------------------------------
-- Transforms and bounds

local function toParent( object, x, y )
	local scaledX, scaledY = x * object.xScale, y * object.yScale
	local rotation = object.rotation

	if rotation ~= 0 then
		local radians = math.rad( rotation )
		local cosine, sine = math.cos( radians ), math.sin( radians )
		scaledX, scaledY = scaledX * cosine - scaledY * sine, scaledX * sine + scaledY * cosine
	end

	return object.x + scaledX, object.y + scaledY
end

local function fromParent( object, x, y )
	local dx, dy = x - object.x, y - object.y
	local rotation = object.rotation

	if rotation ~= 0 then
		local radians = math.rad( -rotation )
		local cosine, sine = math.cos( radians ), math.sin( radians )
		dx, dy = dx * cosine - dy * sine, dx * sine + dy * cosine
	end

	if object.xScale == 0 or object.yScale == 0 then
		return nil
	end

	return dx / object.xScale, dy / object.yScale
end

local function localToContentPoint( object, x, y )
	local node = object

	while node do
		x, y = toParent( node, x, y )
		node = rawget( node, "parent" )
	end

	return x, y
end

local function contentToLocalPoint( object, x, y )
	local chain = {}
	local node = object

	while node do
		table.insert( chain, 1, node )
		node = rawget( node, "parent" )
	end

	for i = 1, #chain do
		x, y = fromParent( chain[i], x, y )

		if not x then
			return 0, 0
		end
	end

	return x, y
end

local localBox

local function boxInParent( object )
	local x1, y1, x2, y2 = localBox( object )

	if not x1 then
		return nil
	end

	local corners = { { x1, y1 }, { x2, y1 }, { x2, y2 }, { x1, y2 } }
	local xMin, yMin, xMax, yMax = math.huge, math.huge, -math.huge, -math.huge

	for i = 1, 4 do
		local x, y = toParent( object, corners[i][1], corners[i][2] )
		xMin, yMin = math.min( xMin, x ), math.min( yMin, y )
		xMax, yMax = math.max( xMax, x ), math.max( yMax, y )
	end

	return xMin, yMin, xMax, yMax
end

-- The object's extent in its own coordinates, before its own transform.
function localBox( object )
	local internal = internalOf( object )

	if internal.isGroup and not internal.isContainer then
		local xMin, yMin, xMax, yMax

		for i = 1, object.numChildren do
			local x1, y1, x2, y2 = boxInParent( object[i] )

			if x1 then
				xMin = xMin and math.min( xMin, x1 ) or x1
				yMin = yMin and math.min( yMin, y1 ) or y1
				xMax = xMax and math.max( xMax, x2 ) or x2
				yMax = yMax and math.max( yMax, y2 ) or y2
			end
		end

		return xMin, yMin, xMax, yMax
	end

	if internal.points then
		local xMin, yMin, xMax, yMax = 0, 0, 0, 0
		local points = internal.points

		for i = 1, #points, 2 do
			xMin, xMax = math.min( xMin, points[i] ), math.max( xMax, points[i] )
			yMin, yMax = math.min( yMin, points[i + 1] ), math.max( yMax, points[i + 1] )
		end

		return xMin, yMin, xMax, yMax
	end

	local width, height = object.width or 0, object.height or 0

	return -width * object.anchorX, -height * object.anchorY, width * ( 1 - object.anchorX ), height * ( 1 - object.anchorY )
end

local function contentBounds( object )
	local x1, y1, x2, y2 = localBox( object )

	if not x1 then
		local x, y = localToContentPoint( object, 0, 0 )
		return { xMin = x, yMin = y, xMax = x, yMax = y }
	end

	local corners = { { x1, y1 }, { x2, y1 }, { x2, y2 }, { x1, y2 } }
	local bounds = { xMin = math.huge, yMin = math.huge, xMax = -math.huge, yMax = -math.huge }

	for i = 1, 4 do
		local x, y = localToContentPoint( object, corners[i][1], corners[i][2] )
		bounds.xMin, bounds.yMin = math.min( bounds.xMin, x ), math.min( bounds.yMin, y )
		bounds.xMax, bounds.yMax = math.max( bounds.xMax, x ), math.max( bounds.yMax, y )
	end

	return bounds
end

stub.contentBounds = contentBounds

function getters.contentBounds( object )
	return contentBounds( object )
end

function getters.contentWidth( object )
	local bounds = contentBounds( object )

	return bounds.xMax - bounds.xMin
end

function getters.contentHeight( object )
	local bounds = contentBounds( object )

	return bounds.yMax - bounds.yMin
end

function getters.width( object, internal )
	if internal.isText then
		return internal.wrapWidth or #tostring( rawget( object, "text" ) or "" ) * ( rawget( object, "size" ) or 12 ) * 0.5
	end

	local x1, _, x2 = localBox( object )

	return x1 and ( x2 - x1 ) or 0
end

function getters.height( object, internal )
	if internal.isText then
		local text = tostring( rawget( object, "text" ) or "" )
		local size = rawget( object, "size" ) or 12
		local _, newlines = string.gsub( text, "\n", "" )
		local lines = newlines + 1

		if internal.wrapWidth and internal.wrapWidth > 0 then
			lines = math.max( lines, math.ceil( #text * size * 0.5 / internal.wrapWidth ) )
		end

		return internal.fixedHeight or lines * size * 1.2
	end

	local _, y1, _, y2 = localBox( object )

	return y1 and ( y2 - y1 ) or 0
end

function getters.fill( _, internal )
	internal.fill = internal.fill or newFillTable( nil )

	return internal.fill
end

function getters.stroke( _, internal )
	internal.stroke = internal.stroke or newFillTable( nil )

	return internal.stroke
end

function getters.path( _, internal )
	internal.path = internal.path or {}

	return internal.path
end

--------------------------------------------------------------------------------------
-- Display object methods

local function checkColor( caller, ... )
	local first = ...

	if type( first ) == "table" and first.type == "gradient" then
		return
	end

	local count = select( "#", ... )

	if type( first ) ~= "number" then
		error( caller .. " expects numbers or a gradient table, got " .. type( first ), 3 )
	end

	for i = 2, count do
		local value = select( i, ... )

		if value ~= nil and type( value ) ~= "number" then
			error( caller .. " argument " .. i .. " is a " .. type( value ) .. ", not a number", 3 )
		end
	end
end

function commonMethods:setFillColor( ... )
	checkColor( "setFillColor", ... )
	internalOf( self ).fillColor = { ... }
end

function commonMethods:setStrokeColor( ... )
	checkColor( "setStrokeColor", ... )
	internalOf( self ).strokeColor = { ... }
end

function commonMethods:toFront()
	local parent = rawget( self, "parent" )

	if parent then
		insertChild( parent, self )
	end
end

function commonMethods:toBack()
	local parent = rawget( self, "parent" )

	if parent then
		insertChild( parent, self, 1 )
	end
end

function commonMethods:removeSelf()
	if rawequal( self, currentStage ) then
		error( "the stage cannot be removed", 2 )
	end

	destroy( self )
end

function commonMethods:addEventListener( name, listener )
	return addListener( internalOf( self ).dispatcher, self, name, listener )
end

function commonMethods:removeEventListener( name, listener )
	return removeListener( internalOf( self ).dispatcher, self, name, listener )
end

function commonMethods:dispatchEvent( event )
	event.target = event.target or self

	return dispatch( internalOf( self ).dispatcher, event )
end

function commonMethods:contentToLocal( x, y )
	checkNumber( "contentToLocal", 1, x )
	checkNumber( "contentToLocal", 2, y )

	return contentToLocalPoint( self, x, y )
end

function commonMethods:localToContent( x, y )
	checkNumber( "localToContent", 1, x )
	checkNumber( "localToContent", 2, y )

	return localToContentPoint( self, x, y )
end

function commonMethods:rotate( degrees )
	checkNumber( "rotate", 1, degrees )
	self.rotation = self.rotation + degrees
end

function commonMethods:translate( dx, dy )
	checkNumber( "translate", 1, dx )
	checkNumber( "translate", 2, dy )
	self.x, self.y = self.x + dx, self.y + dy
end

function commonMethods:scale( sx, sy )
	checkNumber( "scale", 1, sx )
	checkNumber( "scale", 2, sy )
	self.xScale, self.yScale = self.xScale * sx, self.yScale * sy
end

function commonMethods:setMask( mask )
	internalOf( self ).mask = mask
end

-- Accepts ( [index,] child [, resetTransform] ).
function groupMethods:insert( ... )
	local first, second = ...

	if type( first ) == "number" then
		insertChild( self, second, first )
		return
	end

	insertChild( self, first )
end

-- The engine removes and destroys the child, like child:removeSelf().
function groupMethods:remove( indexOrChild )
	local child = indexOrChild

	if type( indexOrChild ) == "number" then
		child = self[indexOrChild]
	end

	if isAlive( child ) and rawequal( rawget( child, "parent" ), self ) then
		destroy( child )
	end
end

--------------------------------------------------------------------------------------
-- display

local function splitParent( args, count, plainCount )
	if isGroup( args[1] ) then
		return args[1], 2
	end

	if args[1] == nil and count > plainCount then
		return nil, 2
	end

	return nil, 1
end

display = {
	contentWidth = 960,
	contentHeight = 640,
	contentCenterX = 480,
	contentCenterY = 320,
	actualContentWidth = 960,
	actualContentHeight = 640,
	viewableContentWidth = 960,
	viewableContentHeight = 640,
	screenOriginX = 0,
	screenOriginY = 0,
	safeScreenOriginX = 0,
	safeScreenOriginY = 0,
	safeActualContentWidth = 960,
	safeActualContentHeight = 640,
	contentScaleX = 1,
	contentScaleY = 1,
	pixelWidth = 640,
	pixelHeight = 960,
	topStatusBarContentHeight = 0,
	fps = 60,
	HiddenStatusBar = "HiddenStatusBar",
	DefaultStatusBar = "DefaultStatusBar",
	TranslucentStatusBar = "TranslucentStatusBar",
	DarkStatusBar = "DarkStatusBar",
}

currentStage = newGroupObject( "stage", false )
stub.stage = currentStage

function currentStage:setFocus( object )
	if object ~= nil and not isAlive( object ) then
		error( "setFocus: the object is not a live display object", 2 )
	end

	stub.focus = object
end

function display.getCurrentStage()
	return currentStage
end

function display.setStatusBar( mode )
	stub.statusBar = mode
end

function display.setDefault( key, ... )
	stub.defaults[key] = { ... }
end

function display.getDefault( key )
	local values = stub.defaults[key]

	if values then
		return unpack( values )
	end

	return nil
end

function display.remove( object )
	if object and object.removeSelf then
		object:removeSelf()
	end
end

function display.newGroup()
	return newGroupObject( "group" )
end

function display.newContainer( ... )
	local args = { ... }
	local parent, index = splitParent( args, select( "#", ... ), 2 )
	local width, height = args[index], args[index + 1]
	checkNumber( "newContainer", index, width )
	checkNumber( "newContainer", index + 1, height )

	local container = newGroupObject( "container", parent )
	rawset( container, "width", width )
	rawset( container, "height", height )
	rawset( container, "anchorChildren", true )
	internalOf( container ).isContainer = true

	return container
end

local function newShape( caller, kind, args, count, numberCount )
	local parent, index = splitParent( args, count, numberCount )

	for i = 0, numberCount - 1 do
		checkNumber( caller, index + i, args[index + i] )
	end

	local object = newObject( kind, parent )
	object.x, object.y = args[index], args[index + 1]

	return object, index
end

function display.newRect( ... )
	local args = { ... }
	local object, index = newShape( "newRect", "rect", args, select( "#", ... ), 4 )
	object.width, object.height = args[index + 2], args[index + 3]
	object.path = { x1 = 0, y1 = 0, x2 = 0, y2 = 0, x3 = 0, y3 = 0, x4 = 0, y4 = 0 }

	return object
end

function display.newRoundedRect( ... )
	local args = { ... }
	local object, index = newShape( "newRoundedRect", "roundedRect", args, select( "#", ... ), 5 )
	object.width, object.height = args[index + 2], args[index + 3]
	object.path = { width = object.width, height = object.height, radius = args[index + 4] }

	return object
end

function display.newCircle( ... )
	local args = { ... }
	local object, index = newShape( "newCircle", "circle", args, select( "#", ... ), 3 )
	local radius = args[index + 2]
	object.width, object.height = radius * 2, radius * 2
	object.path = { radius = radius }

	return object
end

local lineMethods = {}

function lineMethods:append( ... )
	local count = select( "#", ... )

	if count == 0 or count % 2 ~= 0 then
		error( "line:append expects x, y pairs", 2 )
	end

	local points = internalOf( self ).points

	for i = 1, count do
		local value = select( i, ... )
		checkNumber( "append", i, value )
		points[#points + 1] = value - ( i % 2 == 1 and internalOf( self ).originX or internalOf( self ).originY )
	end
end

function display.newLine( ... )
	local args = { ... }
	local count = select( "#", ... )
	local parent, index = splitParent( args, count, 4 )

	if count - index + 1 < 4 then
		error( "display.newLine needs at least two points", 2 )
	end

	local line = newObject( "line", parent, lineMethods )
	local internal = internalOf( line )
	internal.originX, internal.originY = args[index], args[index + 1]
	internal.points = {}
	rawset( line, "width", nil )
	rawset( line, "height", nil )
	line.x, line.y = args[index], args[index + 1]
	line.anchorX, line.anchorY = 0, 0
	line.strokeWidth = 1

	for i = index, count do
		checkNumber( "newLine", i, args[i] )
		internal.points[#internal.points + 1] = args[i] - ( ( i - index ) % 2 == 0 and internal.originX or internal.originY )
	end

	return line
end

function display.newPolygon( ... )
	local args = { ... }
	local count = select( "#", ... )
	local parent, index = splitParent( args, count, 3 )
	local x, y, vertices = args[index], args[index + 1], args[index + 2]
	checkNumber( "newPolygon", index, x )
	checkNumber( "newPolygon", index + 1, y )

	if type( vertices ) ~= "table" or #vertices < 6 or #vertices % 2 ~= 0 then
		error( "display.newPolygon needs a vertex table of at least three x, y pairs", 2 )
	end

	local xMin, yMin, xMax, yMax = math.huge, math.huge, -math.huge, -math.huge

	for i = 1, #vertices, 2 do
		xMin, xMax = math.min( xMin, vertices[i] ), math.max( xMax, vertices[i] )
		yMin, yMax = math.min( yMin, vertices[i + 1] ), math.max( yMax, vertices[i + 1] )
	end

	local polygon = newObject( "polygon", parent )
	polygon.x, polygon.y = x, y
	polygon.width, polygon.height = xMax - xMin, yMax - yMin

	return polygon
end

local function checkFont( font )
	if font == nil or font == native.systemFont or font == native.systemFontBold then
		return
	end

	if type( font ) ~= "string" then
		error( "font must be a string or a native font, got " .. type( font ), 4 )
	end

	if not fileExists( font ) then
		stub.warn( "missing font: " .. font )
	end
end

local embossedMethods = {}

function embossedMethods:setEmbossColor( color )
	if type( color ) ~= "table" then
		error( "setEmbossColor expects a table with highlight and shadow", 2 )
	end
end

-- Accepts the params table and ( [parent,] text, x, y, [width, height,] font, fontSize ).
local function newTextObject( kind, methods, ... )
	local params = ...

	if type( params ) ~= "table" or isAlive( params ) then
		local args = { ... }
		local index = isGroup( args[1] ) and 2 or 1
		params = { parent = isGroup( args[1] ) and args[1] or nil, text = args[index], x = args[index + 1], y = args[index + 2] }

		if type( args[index + 3] ) == "number" then
			params.width, params.height = args[index + 3], args[index + 4]
			params.font, params.fontSize = args[index + 5], args[index + 6]
		else
			params.font, params.fontSize = args[index + 3], args[index + 4]
		end
	end

	if params.parent ~= nil and not isGroup( params.parent ) then
		error( "display.newText: params.parent is not a display group", 3 )
	end

	if params.text ~= nil and type( params.text ) ~= "string" and type( params.text ) ~= "number" then
		error( "display.newText: text must be a string or a number, got " .. type( params.text ), 3 )
	end

	checkFont( params.font )

	local text = newObject( kind, params.parent, methods )
	local internal = internalOf( text )
	internal.isText = true
	internal.wrapWidth = params.width
	internal.fixedHeight = params.height ~= 0 and params.height or nil
	rawset( text, "width", nil )
	rawset( text, "height", nil )
	text.x, text.y = params.x or 0, params.y or 0
	text.text = tostring( params.text or "" )
	text.size = params.fontSize or 12
	text.font = params.font
	text.align = params.align

	return text
end

function display.newText( ... )
	return newTextObject( "text", nil, ... )
end

function display.newEmbossedText( ... )
	return newTextObject( "embossedText", embossedMethods, ... )
end

--------------------------------------------------------------------------------------
-- Images, image sheets and sprites

local function isSheet( value )
	return type( value ) == "table" and rawget( value, "isImageSheet" ) == true
end

local function checkFrame( caller, sheet, frame )
	if type( frame ) ~= "number" or frame < 1 or frame > sheet.frameCount or frame ~= math.floor( frame ) then
		error( caller .. ": frame " .. tostring( frame ) .. " is not in the sheet's 1.." .. sheet.frameCount, 3 )
	end
end

local function sheetFrameSize( sheet, frame )
	local frames = sheet.options.frames

	if frames and frames[frame] then
		return frames[frame].width, frames[frame].height
	end

	return sheet.options.width or 0, sheet.options.height or 0
end

-- Accepts ( [parent,] filename, [baseDir,] [x, y] ) and ( [parent,] imageSheet, frameIndex, [x, y] ).
function display.newImage( ... )
	local args = { ... }
	local index = 1
	local parent

	if isGroup( args[1] ) then
		parent, index = args[1], 2
	end

	local image = newObject( "image", parent )
	local internal = internalOf( image )

	if isSheet( args[index] ) then
		local sheet, frame = args[index], args[index + 1]
		checkFrame( "display.newImage", sheet, frame )
		image.width, image.height = sheetFrameSize( sheet, frame )
		internal.sheet, internal.frame = sheet, frame
		index = index + 2
	else
		local filename = args[index]
		local baseDirectory
		index = index + 1

		if isDirectory( args[index] ) then
			baseDirectory = args[index]
			index = index + 1
		end

		local path = checkAsset( "image", filename, baseDirectory )
		local width, height

		if path then
			width, height = readPngSize( path )
		end

		image.width, image.height = width or 32, height or 32
		internal.filename = filename
	end

	if type( args[index] ) == "number" then
		image.x, image.y = args[index], args[index + 1] or 0
	end

	return image
end

-- Accepts ( [parent,] filename, [baseDir,] width, height ) and ( [parent,] imageSheet, frameIndex, width, height ).
function display.newImageRect( ... )
	local args = { ... }
	local index = 1
	local parent

	if isGroup( args[1] ) then
		parent, index = args[1], 2
	end

	local source = args[index]
	local internalData = {}

	if isSheet( source ) then
		checkFrame( "display.newImageRect", source, args[index + 1] )
		internalData.sheet, internalData.frame = source, args[index + 1]
		index = index + 2
	else
		local baseDirectory

		if isDirectory( args[index + 1] ) then
			baseDirectory = args[index + 1]
			index = index + 1
		end

		checkAsset( "image", source, baseDirectory )
		internalData.filename = source
		index = index + 1
	end

	checkNumber( "newImageRect", index, args[index] )
	checkNumber( "newImageRect", index + 1, args[index + 1] )

	local image = newObject( "imageRect", parent )
	image.width, image.height = args[index], args[index + 1]
	image.path = { x1 = 0, y1 = 0, x2 = 0, y2 = 0, x3 = 0, y3 = 0, x4 = 0, y4 = 0 }

	for key, value in pairs( internalData ) do
		internalOf( image )[key] = value
	end

	return image
end

graphics = {}

-- Accepts ( filename, [baseDir,] options ).
function graphics.newImageSheet( filename, ... )
	local baseDirectory, options = ...

	if not isDirectory( baseDirectory ) then
		options = baseDirectory
		baseDirectory = nil
	end

	if type( options ) ~= "table" then
		error( "graphics.newImageSheet: options table missing", 2 )
	end

	local frameCount

	if options.frames then
		frameCount = #options.frames

		for i = 1, frameCount do
			local frame = options.frames[i]

			if type( frame.x ) ~= "number" or type( frame.y ) ~= "number" or type( frame.width ) ~= "number" or type( frame.height ) ~= "number" then
				error( "graphics.newImageSheet: frame " .. i .. " needs numeric x, y, width and height", 2 )
			end
		end
	else
		if type( options.width ) ~= "number" or type( options.height ) ~= "number" or type( options.numFrames ) ~= "number" then
			error( "graphics.newImageSheet: options need width, height and numFrames, or frames", 2 )
		end

		frameCount = options.numFrames
	end

	local path = checkAsset( "image sheet", filename, baseDirectory )

	if path and not options.frames then
		local imageWidth, imageHeight = readPngSize( path )

		if imageWidth then
			imageWidth = options.sheetContentWidth or imageWidth
			imageHeight = options.sheetContentHeight or imageHeight

			local capacity = math.floor( imageWidth / options.width ) * math.floor( imageHeight / options.height )

			if capacity < frameCount then
				error( "graphics.newImageSheet: " .. filename .. " holds " .. capacity .. " frames, options ask for " .. frameCount, 2 )
			end
		end
	end

	return { isImageSheet = true, filename = filename, options = options, frameCount = frameCount }
end

function graphics.newOutline( coarseness, filename, baseDirectory )
	checkNumber( "graphics.newOutline", 1, coarseness )

	local path = checkAsset( "image", filename, baseDirectory )
	local width, height = 32, 32

	if path then
		width, height = readPngSize( path )
		width, height = width or 32, height or 32
	end

	local halfWidth, halfHeight = width * 0.5, height * 0.5

	return { -halfWidth, -halfHeight, halfWidth, -halfHeight, halfWidth, halfHeight, -halfWidth, halfHeight }
end

function graphics.newMask( filename, baseDirectory )
	checkAsset( "mask", filename, baseDirectory )

	return { filename = filename }
end

function graphics.newTexture( params )
	if type( params ) ~= "table" or params.type ~= "image" then
		error( "Solar2D stub: graphics.newTexture only stubs type \"image\"", 2 )
	end

	checkAsset( "image", params.filename, params.baseDir )

	local texture = { filename = params.filename, baseDir = params.baseDir, type = "image" }

	function texture:preload() end

	function texture:releaseSelf()
		self.preload = nil
		self.releaseSelf = nil
	end

	return texture
end

function graphics.defineEffect( effect )
	if type( effect ) ~= "table" then
		error( "graphics.defineEffect expects a table", 2 )
	end
end

local spriteMethods = {}

local function findSequence( sprite, name )
	local sequences = internalOf( sprite ).sequences

	for i = 1, #sequences do
		if sequences[i].name == name then
			return sequences[i]
		end
	end

	return nil
end

function spriteMethods:play()
	self.isPlaying = true
end

function spriteMethods:pause()
	self.isPlaying = false
end

function spriteMethods:setSequence( name )
	local sequence

	if name == nil then
		sequence = internalOf( self ).sequences[1]
	else
		sequence = findSequence( self, name )
	end

	if not sequence then
		error( "sprite:setSequence: no sequence named " .. tostring( name ), 2 )
	end

	self.sequence = sequence.name
	self.frame = 1
	self.numFrames = sequence.frames and #sequence.frames or sequence.count or 1
	self.isPlaying = false
end

function spriteMethods:setFrame( frame )
	if type( frame ) ~= "number" or frame < 1 or frame > ( self.numFrames or 1 ) then
		error( "sprite:setFrame: frame " .. tostring( frame ) .. " is not in 1.." .. tostring( self.numFrames ), 2 )
	end

	self.frame = frame
end

-- Accepts ( [parent,] imageSheet, sequenceData ).
function display.newSprite( ... )
	local args = { ... }
	local index = 1
	local parent

	if isGroup( args[1] ) then
		parent, index = args[1], 2
	end

	local sheet, sequenceData = args[index], args[index + 1]

	if not isSheet( sheet ) then
		error( "display.newSprite: argument " .. index .. " is not an image sheet", 2 )
	end

	if type( sequenceData ) ~= "table" then
		error( "display.newSprite: sequence data missing", 2 )
	end

	local sequences = sequenceData

	if sequenceData.name or sequenceData.frames or sequenceData.start then
		sequences = { sequenceData }
	end

	for i = 1, #sequences do
		local sequence = sequences[i]
		local label = "display.newSprite: sequence " .. tostring( sequence.name or i )

		if sequence.frames then
			for j = 1, #sequence.frames do
				local frame = sequence.frames[j]

				if type( frame ) ~= "number" or frame < 1 or frame > sheet.frameCount then
					error( label .. " frame " .. j .. " is " .. tostring( frame ) .. ", not in the sheet's 1.." .. sheet.frameCount, 2 )
				end
			end

		elseif type( sequence.start ) == "number" then
			local last = sequence.start + ( sequence.count or 1 ) - 1

			if sequence.start < 1 or last > sheet.frameCount then
				error( label .. " covers frames " .. sequence.start .. ".." .. last .. ", the sheet has 1.." .. sheet.frameCount, 2 )
			end
		else
			error( label .. " needs frames or start", 2 )
		end
	end

	local sprite = newObject( "sprite", parent, spriteMethods )
	internalOf( sprite ).sequences = sequences
	internalOf( sprite ).sheet = sheet
	sprite.width, sprite.height = sheetFrameSize( sheet, 1 )
	sprite.timeScale = 1
	sprite:setSequence( nil )

	return sprite
end

strict( "display", display, nil, { imageSuffix = true } )
strict( "graphics", graphics )

--------------------------------------------------------------------------------------
-- Input delivery

local function isShown( object )
	local node = object

	while node do
		local visible = node.isVisible and node.alpha > 0

		if not visible and not node.isHitTestable then
			return false
		end

		node = rawget( node, "parent" )
	end

	return true
end

-- Front-to-back list of objects under a content point that listen for the event; groups follow their children.
local function collectHits( object, x, y, name, hits )
	local visible = object.isVisible and object.alpha > 0

	if not visible and not object.isHitTestable then
		return false
	end

	local localX, localY = fromParent( object, x, y )

	if not localX then
		return false
	end

	local internal = internalOf( object )
	local isHit = false

	if internal.isGroup then
		for i = object.numChildren, 1, -1 do
			if collectHits( object[i], localX, localY, name, hits ) then
				isHit = true
			end
		end
	else
		local x1, y1, x2, y2 = localBox( object )
		isHit = x1 ~= nil and localX >= x1 and localX <= x2 and localY >= y1 and localY <= y2
	end

	if isHit and hasAnyListener( internal.dispatcher, name ) then
		hits[#hits + 1] = object
	end

	return isHit
end

local function newTouchEvent( phase, x, y, xStart, yStart )
	return { name = "touch", phase = phase, x = x, y = y, xStart = xStart or x, yStart = yStart or y, id = "harnessTouch", time = stub.clock }
end

local function dispatchToObject( object, event )
	if not isAlive( object ) then
		return false
	end

	event.target = object

	return dispatch( internalOf( object ).dispatcher, event )
end

-- One touch phase at a content point: the focused object, else hit objects front to back, else Runtime.
function stub.touchAt( x, y, phase, xStart, yStart )
	local event = newTouchEvent( phase, x, y, xStart, yStart )

	if stub.focus and isAlive( stub.focus ) then
		return dispatchToObject( stub.focus, event )
	end

	local hits = {}
	collectHits( currentStage, x, y, "touch", hits )

	for i = 1, #hits do
		if dispatchToObject( hits[i], newTouchEvent( phase, x, y, xStart, yStart ) ) then
			return true
		end
	end

	return dispatch( runtimeState, newTouchEvent( phase, x, y, xStart, yStart ) )
end

-- One touch phase aimed at one object, as if the finger landed on it; focus still wins.
function stub.touchObject( object, x, y, phase, xStart, yStart )
	if stub.focus and isAlive( stub.focus ) then
		return dispatchToObject( stub.focus, newTouchEvent( phase, x, y, xStart, yStart ) )
	end

	return dispatchToObject( object, newTouchEvent( phase, x, y, xStart, yStart ) )
end

function stub.mouseAt( x, y, mouseType, isPrimaryButtonDown )
	local function newEvent()
		return {
			name = "mouse",
			type = mouseType,
			x = x,
			y = y,
			time = stub.clock,
			isPrimaryButtonDown = isPrimaryButtonDown == true,
			isSecondaryButtonDown = false,
			isMiddleButtonDown = false,
			scrollX = 0,
			scrollY = 0,
		}
	end

	local hits = {}
	collectHits( currentStage, x, y, "mouse", hits )

	for i = 1, #hits do
		if dispatchToObject( hits[i], newEvent() ) then
			return true
		end
	end

	return dispatch( runtimeState, newEvent() )
end

function stub.key( keyName, phase, isShiftDown )
	return dispatch( runtimeState, {
		name = "key",
		phase = phase,
		keyName = keyName,
		descriptor = keyName,
		nativeKeyCode = 0,
		isShiftDown = isShiftDown == true,
		isAltDown = false,
		isCtrlDown = false,
		isCommandDown = false,
	} )
end

-- Live, shown objects under root that listen for touches, front to back.
function stub.touchables( root )
	local found = {}

	local function walk( object )
		local internal = internalOf( object )

		if internal.isGroup then
			for i = object.numChildren, 1, -1 do
				walk( object[i] )
			end
		end

		if hasAnyListener( internal.dispatcher, "touch" ) and isShown( object ) then
			found[#found + 1] = object
		end
	end

	walk( root )

	return found
end

function stub.isDescendant( object, root )
	local node = isAlive( object ) and object or nil

	while node do
		if rawequal( node, root ) then
			return true
		end

		node = rawget( node, "parent" )
	end

	return false
end

--------------------------------------------------------------------------------------
-- Physics

world = { state = "stopped", gravityX = 0, gravityY = 9.8, bodies = {}, contacts = {}, isLocked = false, nextElementId = 0 }
stub.world = world

local physics = {}

local function requireWorld( caller )
	if world.state == "stopped" then
		error( "physics.start() must be called before " .. caller, 3 )
	end
end

local function requireUnlocked( caller )
	if world.isLocked then
		error( caller .. " cannot be called when the world is locked and in the middle of number crunching, such as during a collision event", 3 )
	end
end

local function polygonArea( shape )
	local sum = 0
	local count = #shape / 2

	for i = 1, count do
		local nextIndex = i % count + 1
		sum = sum + shape[i * 2 - 1] * shape[nextIndex * 2] - shape[nextIndex * 2 - 1] * shape[i * 2]
	end

	return sum * 0.5
end

-- Solar2D shapes hold 3 to 8 vertices, convex and clockwise on screen.
local function validateShape( shape )
	if type( shape ) ~= "table" or #shape % 2 ~= 0 then
		error( "physics.addBody: shape must be a flat list of x, y pairs", 4 )
	end

	local count = #shape / 2

	if count < 3 or count > 8 then
		error( "physics.addBody: shape has " .. count .. " vertices, Box2D takes 3 to 8", 4 )
	end

	for i = 1, #shape do
		if type( shape[i] ) ~= "number" then
			error( "physics.addBody: shape entry " .. i .. " is not a number", 4 )
		end
	end

	if polygonArea( shape ) <= 0 then
		error( "physics.addBody: shape vertices must run clockwise on screen", 4 )
	end

	for i = 1, count do
		local x1, y1 = shape[i * 2 - 1], shape[i * 2]
		local secondIndex, thirdIndex = i % count + 1, ( i + 1 ) % count + 1
		local x2, y2 = shape[secondIndex * 2 - 1], shape[secondIndex * 2]
		local x3, y3 = shape[thirdIndex * 2 - 1], shape[thirdIndex * 2]
		local cross = ( x2 - x1 ) * ( y3 - y2 ) - ( y2 - y1 ) * ( x3 - x2 )

		if cross < 0 then
			error( "physics.addBody: shape is not convex", 4 )
		end
	end
end

local function boundsOfPoints( points )
	local xMin, yMin, xMax, yMax = math.huge, math.huge, -math.huge, -math.huge

	for i = 1, #points, 2 do
		xMin, xMax = math.min( xMin, points[i] ), math.max( xMax, points[i] )
		yMin, yMax = math.min( yMin, points[i + 1] ), math.max( yMax, points[i + 1] )
	end

	return xMin, yMin, xMax, yMax
end

local function newElement( object, params )
	world.nextElementId = world.nextElementId + 1

	local element = { id = world.nextElementId, isSensor = params.isSensor == true, filter = params.filter, bounce = params.bounce or 0 }

	-- Kept so checks can compare bodies.
	element.friction = params.friction or 0

	local density = params.density or 1

	if params.radius then
		checkNumber( "physics.addBody radius", 1, params.radius )
		local radius = params.radius
		element.x1, element.y1, element.x2, element.y2 = -radius, -radius, radius, radius
		element.area = math.pi * radius * radius

	elseif params.box then
		local box = params.box
		checkNumber( "physics.addBody box.halfWidth", 1, box.halfWidth )
		checkNumber( "physics.addBody box.halfHeight", 1, box.halfHeight )
		local x, y = box.x or 0, box.y or 0
		element.x1, element.y1 = x - box.halfWidth, y - box.halfHeight
		element.x2, element.y2 = x + box.halfWidth, y + box.halfHeight
		element.area = 4 * box.halfWidth * box.halfHeight

	elseif params.shape then
		validateShape( params.shape )
		element.x1, element.y1, element.x2, element.y2 = boundsOfPoints( params.shape )
		element.area = polygonArea( params.shape )

	elseif params.chain then
		local points = params.chain
		element.x1, element.y1, element.x2, element.y2 = boundsOfPoints( points )
		element.area = 0

		-- A chain collides along its edges only, so it keeps each edge as a zero-thickness box.
		element.segments = {}
		local count = #points / 2
		local lastIndex = params.connectFirstAndLastChainVertex and count or count - 1

		for i = 1, lastIndex do
			local nextIndex = i % count + 1
			local x1, y1, x2, y2 = points[i * 2 - 1], points[i * 2], points[nextIndex * 2 - 1], points[nextIndex * 2]
			element.segments[i] = { math.min( x1, x2 ), math.min( y1, y2 ), math.max( x1, x2 ), math.max( y1, y2 ) }
		end

	elseif params.outline then
		local points = params.outline
		element.x1, element.y1, element.x2, element.y2 = boundsOfPoints( points )
		element.area = ( element.x2 - element.x1 ) * ( element.y2 - element.y1 )

	else
		local width, height = object.width or 0, object.height or 0
		element.x1, element.y1 = -width * 0.5, -height * 0.5
		element.x2, element.y2 = width * 0.5, height * 0.5
		element.area = width * height
	end

	element.mass = density * element.area / ( PIXELS_PER_METER * PIXELS_PER_METER )

	return element
end

function physics.start()
	world.state = "running"
end

function physics.pause()
	requireWorld( "physics.pause()" )
	world.state = "paused"
end

function physics.stop()
	requireWorld( "physics.stop()" )
	requireUnlocked( "physics.stop()" )
	stub.records.physicsStop = ( stub.records.physicsStop or 0 ) + 1

	local bodies = copyArray( world.bodies )

	for i = 1, #bodies do
		stub.removeBodyInternal( bodies[i] )
	end

	world.state = "stopped"
end

function physics.setGravity( gravityX, gravityY )
	checkNumber( "physics.setGravity", 1, gravityX )
	checkNumber( "physics.setGravity", 2, gravityY )
	world.gravityX, world.gravityY = gravityX, gravityY
end

function physics.getGravity()
	return world.gravityX, world.gravityY
end

function physics.setDrawMode( mode )
	if mode ~= "normal" and mode ~= "debug" and mode ~= "hybrid" then
		error( "physics.setDrawMode: unknown mode " .. tostring( mode ), 2 )
	end
end

function physics.setScale( scale )
	checkNumber( "physics.setScale", 1, scale )
	stub.records.physicsSetScale = true
end

function physics.setVelocityIterations() end

function physics.setPositionIterations() end

function physics.setContinuous() end

function physics.setTimeStep() end

function physics.setAverageCollisionPositions() end

function physics.setReportCollisionsInContentCoordinates() end

-- Accepts ( object, [bodyType,] [params, ...] ).
function physics.addBody( object, ... )
	requireWorld( "physics.addBody()" )
	requireUnlocked( "physics.addBody()" )

	if not isAlive( object ) then
		error( "physics.addBody: the object is not a live display object", 2 )
	end

	local internal = internalOf( object )

	if internal.body then
		error( "physics.addBody: the object already has a body", 2 )
	end

	local args = { ... }
	local count = select( "#", ... )
	local bodyType = "dynamic"
	local index = 1

	if type( args[1] ) == "string" then
		bodyType = args[1]
		index = 2
	end

	if bodyType ~= "static" and bodyType ~= "dynamic" and bodyType ~= "kinematic" then
		error( "physics.addBody: unknown body type " .. tostring( bodyType ), 2 )
	end

	local elements = {}

	for i = index, count do
		if type( args[i] ) ~= "table" then
			error( "physics.addBody: argument " .. ( i + 1 ) .. " is not a params table", 2 )
		end

		elements[#elements + 1] = newElement( object, args[i] )
	end

	if #elements == 0 then
		elements[1] = newElement( object, { bounce = implicitElementBounce, friction = implicitElementFriction } )
	end

	local mass = 0

	for i = 1, #elements do
		mass = mass + elements[i].mass
	end

	internal.body = { elements = elements, vx = 0, vy = 0, forceX = 0, forceY = 0 }
	world.bodies[#world.bodies + 1] = object

	rawset( object, "bodyType", bodyType )
	rawset( object, "isAwake", true )
	rawset( object, "isBodyActive", true )
	rawset( object, "isBullet", false )
	rawset( object, "isSleepingAllowed", true )
	rawset( object, "isFixedRotation", false )
	rawset( object, "angularVelocity", 0 )
	rawset( object, "linearDamping", 0 )
	rawset( object, "angularDamping", 0 )
	rawset( object, "isSensor", false )
	rawset( object, "gravityScale", 1 )
	rawset( object, "mass", math.max( mass, 0.01 ) )

	return true
end

function stub.removeBodyInternal( object )
	local internal = rawget( object, "_stub" )

	if not internal or not internal.body then
		return false
	end

	internal.body = nil

	for i = #world.bodies, 1, -1 do
		if rawequal( world.bodies[i], object ) then
			table.remove( world.bodies, i )
		end
	end

	for key, contact in pairs( world.contacts ) do
		if rawequal( contact.objectA, object ) or rawequal( contact.objectB, object ) then
			world.contacts[key] = nil
		end
	end

	for i = 1, #BODY_KEYS do
		rawset( object, BODY_KEYS[i], nil )
	end

	return true
end

function physics.removeBody( object )
	requireWorld( "physics.removeBody()" )

	if not isAlive( object ) then
		error( "physics.removeBody: the object is not a live display object", 2 )
	end

	return stub.removeBodyInternal( object )
end

local function elementBox( object, element )
	return object.x + element.x1, object.y + element.y1, object.x + element.x2, object.y + element.y2
end

-- An element's collision boxes in world coordinates as { x1, y1, x2, y2 } lists: one box, or one per chain edge.
local function elementBoxes( object, element )
	if not element.segments then
		return { { elementBox( object, element ) } }
	end

	local boxes = {}

	for i = 1, #element.segments do
		local segment = element.segments[i]
		boxes[i] = { object.x + segment[1], object.y + segment[2], object.x + segment[3], object.y + segment[4] }
	end

	return boxes
end

-- The horizontal top edges of a body's solid elements in world coordinates, as { left, right, y, element } lists, for
-- tests that land bodies on ground the stub does not resolve. A box gives its top, a chain each horizontal edge.
function stub.topEdges( object )
	local edges = {}
	local internal = internalOf( object )

	-- A removed body has no edges left.
	local elements = internal and internal.body and internal.body.elements or {}

	for i = 1, #elements do
		local element = elements[i]

		if not element.isSensor then
			local boxes = elementBoxes( object, element )

			for j = 1, #boxes do
				local box = boxes[j]

				if not element.segments or box[2] == box[4] then
					edges[#edges + 1] = { left = box[1], right = box[3], y = box[2], element = element }
				end
			end
		end
	end

	return edges
end

local function segmentBoxHit( x1, y1, x2, y2, boxX1, boxY1, boxX2, boxY2 )
	if x1 >= boxX1 and x1 <= boxX2 and y1 >= boxY1 and y1 <= boxY2 then
		return nil
	end

	local enter, leave = 0, 1
	local normalX, normalY = 0, 0
	local deltas = { { x2 - x1, x1, boxX1, boxX2 }, { y2 - y1, y1, boxY1, boxY2 } }

	for axis = 1, 2 do
		local delta, start, low, high = deltas[axis][1], deltas[axis][2], deltas[axis][3], deltas[axis][4]

		if delta == 0 then
			if start < low or start > high then
				return nil
			end
		else
			local near, far = ( low - start ) / delta, ( high - start ) / delta
			local sign = -1

			if near > far then
				near, far = far, near
				sign = 1
			end

			if near > enter then
				enter = near
				normalX, normalY = axis == 1 and sign or 0, axis == 2 and sign or 0
			end

			leave = math.min( leave, far )

			if enter > leave then
				return nil
			end
		end
	end

	return enter, normalX, normalY
end

-- Segment against body boxes; behaviour "closest" (default), "any", "unsorted" or "sorted".
function physics.rayCast( x1, y1, x2, y2, behaviour )
	requireWorld( "physics.rayCast()" )

	local coordinates = { x1, y1, x2, y2 }

	for i = 1, 4 do
		checkNumber( "physics.rayCast", i, coordinates[i] )
	end

	local hits = {}

	for i = 1, #world.bodies do
		local object = world.bodies[i]
		local body = internalOf( object ).body

		for j = 1, #body.elements do
			local element = body.elements[j]

			if not element.isSensor and not object.isSensor then
				local boxes = elementBoxes( object, element )

				for k = 1, #boxes do
					local box = boxes[k]
					local fraction, normalX, normalY = segmentBoxHit( x1, y1, x2, y2, box[1], box[2], box[3], box[4] )

					if fraction then
						hits[#hits + 1] = {
							object = object,
							position = { x = x1 + ( x2 - x1 ) * fraction, y = y1 + ( y2 - y1 ) * fraction },
							normal = { x = normalX, y = normalY },
							fraction = fraction,
						}
					end
				end
			end
		end
	end

	if #hits == 0 then
		return nil
	end

	if behaviour == "any" or behaviour == "unsorted" then
		return behaviour == "any" and { hits[1] } or hits
	end

	table.sort( hits, function( a, b )
		return a.fraction < b.fraction
	end )

	if behaviour == "sorted" then
		return hits
	end

	return { hits[1] }
end

function physics.queryRegion( x1, y1, x2, y2 )
	requireWorld( "physics.queryRegion()" )

	local found = {}

	for i = 1, #world.bodies do
		local object = world.bodies[i]
		local elements = internalOf( object ).body.elements

		local isFound = false

		for j = 1, #elements do
			local boxes = elementBoxes( object, elements[j] )

			for k = 1, #boxes do
				local box = boxes[k]
				isFound = isFound or ( box[1] <= x2 and box[3] >= x1 and box[2] <= y2 and box[4] >= y1 )
			end
		end

		if isFound then
			found[#found + 1] = object
		end
	end

	return #found > 0 and found or nil
end

function physics.newJoint( jointType, objectA, objectB )
	requireWorld( "physics.newJoint()" )
	requireUnlocked( "physics.newJoint()" )

	if type( jointType ) ~= "string" or not isAlive( objectA ) then
		error( "physics.newJoint: needs a joint type and a body", 2 )
	end

	local joint = { jointType = jointType, bodyA = objectA, bodyB = objectB }

	function joint:removeSelf() end

	return joint
end

function bodyMethods:setLinearVelocity( vx, vy )
	checkNumber( "setLinearVelocity", 1, vx )
	checkNumber( "setLinearVelocity", 2, vy )

	local body = internalOf( self ).body
	body.vx, body.vy = vx, vy
end

function bodyMethods:getLinearVelocity()
	local body = internalOf( self ).body

	return body.vx, body.vy
end

function bodyMethods:applyLinearImpulse( impulseX, impulseY )
	checkNumber( "applyLinearImpulse", 1, impulseX )
	checkNumber( "applyLinearImpulse", 2, impulseY )

	if self.bodyType == "dynamic" then
		local body = internalOf( self ).body
		body.vx = body.vx + impulseX / self.mass * PIXELS_PER_METER
		body.vy = body.vy + impulseY / self.mass * PIXELS_PER_METER
	end
end

function bodyMethods:applyForce( forceX, forceY )
	checkNumber( "applyForce", 1, forceX )
	checkNumber( "applyForce", 2, forceY )

	local body = internalOf( self ).body
	body.forceX, body.forceY = body.forceX + forceX, body.forceY + forceY
end

function bodyMethods:applyTorque( torque )
	checkNumber( "applyTorque", 1, torque )
end

function bodyMethods:applyAngularImpulse( impulse )
	checkNumber( "applyAngularImpulse", 1, impulse )
end

function bodyMethods:resetMassData() end

function bodyMethods:getMassWorldCenter()
	return self.x, self.y
end

function bodyMethods:getMassLocalCenter()
	return 0, 0
end

function bodyMethods:getWorldVector( x, y )
	local radians = math.rad( self.rotation )

	return x * math.cos( radians ) - y * math.sin( radians ), x * math.sin( radians ) + y * math.cos( radians )
end

function bodyMethods:getInertia()
	return self.mass
end

function bodyMethods:getLinearVelocityFromWorldPoint()
	return self:getLinearVelocity()
end

function bodyMethods:getLinearVelocityFromLocalPoint()
	return self:getLinearVelocity()
end

-- Bitwise AND of two 16-bit masks without a bit library.
local function bitAnd( a, b )
	local result, bitValue = 0, 1

	for _ = 1, 16 do
		if a % 2 == 1 and b % 2 == 1 then
			result = result + bitValue
		end

		a, b, bitValue = math.floor( a / 2 ), math.floor( b / 2 ), bitValue * 2
	end

	return result
end

local function shouldCollide( elementA, elementB )
	local filterA, filterB = elementA.filter or {}, elementB.filter or {}

	if filterA.groupIndex and filterA.groupIndex ~= 0 and filterA.groupIndex == filterB.groupIndex then
		return filterA.groupIndex > 0
	end

	local categoryA, maskA = filterA.categoryBits or 1, filterA.maskBits or 65535
	local categoryB, maskB = filterB.categoryBits or 1, filterB.maskBits or 65535

	return bitAnd( categoryA, maskB ) ~= 0 and bitAnd( categoryB, maskA ) ~= 0
end

local function isSensorElement( object, element )
	return element.isSensor or object.isSensor == true
end

local function sendCollision( name, phase, contact )
	local objectA, objectB = contact.objectA, contact.objectB
	local x, y = contact.x, contact.y
	local contactData = { isEnabled = true, isTouching = true, bounce = 0, friction = 0 }

	if isAlive( objectA ) then
		dispatch( internalOf( objectA ).dispatcher, {
			name = name, phase = phase, target = objectA, other = objectB, x = x, y = y, contact = contactData,
			selfElement = contact.indexA, otherElement = contact.indexB,
		} )
	end

	if isAlive( objectB ) then
		dispatch( internalOf( objectB ).dispatcher, {
			name = name, phase = phase, target = objectB, other = objectA, x = x, y = y, contact = contactData,
			selfElement = contact.indexB, otherElement = contact.indexA,
		} )
	end

	dispatch( runtimeState, {
		name = name, phase = phase, object1 = objectA, object2 = objectB, x = x, y = y, contact = contactData,
		element1 = contact.indexA, element2 = contact.indexB,
	} )
end

-- The first of the boxes that overlaps the given one, or nil.
local function overlappingBox( x1, y1, x2, y2, boxes )
	for i = 1, #boxes do
		local box = boxes[i]

		if x1 < box[3] and x2 > box[1] and y1 < box[4] and y2 > box[2] then
			return box[1], box[2], box[3], box[4]
		end
	end

	return nil
end

-- Box overlaps stand in for Box2D contacts: began, ended and preCollision fire, nothing is resolved.
local function updateContacts()
	local current = {}
	local bodies = world.bodies

	for i = 1, #bodies do
		local objectA = bodies[i]

		if objectA.bodyType == "dynamic" and objectA.isBodyActive then
			local elementsA = internalOf( objectA ).body.elements

			for j = 1, #bodies do
				local objectB = bodies[j]
				local isPairOwner = objectB.bodyType ~= "dynamic" or j > i

				if j ~= i and isPairOwner and objectB.isBodyActive then
					local elementsB = internalOf( objectB ).body.elements

					for a = 1, #elementsA do
						local ax1, ay1, ax2, ay2 = elementBox( objectA, elementsA[a] )

						for b = 1, #elementsB do
							local bx1, by1, bx2, by2 = overlappingBox( ax1, ay1, ax2, ay2, elementBoxes( objectB, elementsB[b] ) )

							if bx1 and shouldCollide( elementsA[a], elementsB[b] ) then
								current[elementsA[a].id .. ":" .. elementsB[b].id] = {
									objectA = objectA,
									objectB = objectB,
									indexA = a,
									indexB = b,
									isSensor = isSensorElement( objectA, elementsA[a] ) or isSensorElement( objectB, elementsB[b] ),
									x = ( math.max( ax1, bx1 ) + math.min( ax2, bx2 ) ) * 0.5,
									y = ( math.max( ay1, by1 ) + math.min( ay2, by2 ) ) * 0.5,
								}
							end
						end
					end
				end
			end
		end
	end

	local began, ended = {}, {}

	for key, contact in pairs( current ) do
		if not world.contacts[key] then
			began[#began + 1] = { key = key, contact = contact }
		end
	end

	for key, contact in pairs( world.contacts ) do
		if not current[key] then
			ended[#ended + 1] = { key = key, contact = contact }
		end
	end

	local function byKey( a, b )
		return a.key < b.key
	end

	table.sort( began, byKey )
	table.sort( ended, byKey )
	world.contacts = current
	world.isLocked = true

	for i = 1, #ended do
		sendCollision( "collision", "ended", ended[i].contact )
	end

	for i = 1, #began do
		local contact = began[i].contact

		if not contact.isSensor then
			sendCollision( "preCollision", nil, contact )
		end

		sendCollision( "collision", "began", contact )
	end

	world.isLocked = false
end

local function stepPhysics( seconds )
	if world.state ~= "running" then
		return
	end

	local bodies = copyArray( world.bodies )

	for i = 1, #bodies do
		local object = bodies[i]
		local internal = rawget( object, "_stub" )
		local body = internal and internal.body

		if body and object.isBodyActive then
			if object.bodyType == "dynamic" then
				local gravityScale = object.gravityScale or 1
				body.vx = body.vx + ( world.gravityX * PIXELS_PER_METER * gravityScale + body.forceX / object.mass * PIXELS_PER_METER ) * seconds
				body.vy = body.vy + ( world.gravityY * PIXELS_PER_METER * gravityScale + body.forceY / object.mass * PIXELS_PER_METER ) * seconds
				body.forceX, body.forceY = 0, 0

				local damping = 1 / ( 1 + seconds * ( object.linearDamping or 0 ) )
				body.vx, body.vy = body.vx * damping, body.vy * damping
			end

			if object.bodyType ~= "static" then
				object.x = object.x + body.vx * seconds
				object.y = object.y + body.vy * seconds

				if not object.isFixedRotation then
					object.rotation = object.rotation + ( object.angularVelocity or 0 ) * seconds
				end
			end
		end
	end

	updateContacts()
end

strict( "physics", physics )

--------------------------------------------------------------------------------------
-- Audio

local audio = {}
local masterVolume = 1
local reservedChannels = 0
local channelVolumes = {}

local function isSoundHandle( value )
	return type( value ) == "table" and rawget( value, "isSoundHandle" ) == true
end

local function loadAudio( kind, filename, baseDirectory )
	local path = checkAsset( "sound", filename, baseDirectory )
	local duration = path and readWavDuration( path ) or 1000

	return { isSoundHandle = true, kind = kind, filename = filename, duration = duration }
end

function audio.loadSound( filename, baseDirectory )
	return loadAudio( "sound", filename, baseDirectory )
end

function audio.loadStream( filename, baseDirectory )
	return loadAudio( "stream", filename, baseDirectory )
end

local function finishChannel( channel, completed )
	local state = channels[channel]

	if not state then
		return
	end

	channels[channel] = nil

	if state.onComplete then
		stub.call( state.onComplete, { name = "audio", channel = channel, handle = state.handle, completed = completed, phase = "stopped" } )
	end
end

local function freeChannel( start )
	for channel = math.max( start or 1, reservedChannels + 1 ), CHANNEL_COUNT do
		if not channels[channel] then
			return channel
		end
	end

	return 0
end

function audio.play( handle, options )
	if not isSoundHandle( handle ) then
		error( "audio.play: the handle is " .. type( handle ) .. ", not a loaded sound", 2 )
	end

	if handle.isDisposed then
		error( "audio.play: the sound " .. tostring( handle.filename ) .. " was already disposed", 2 )
	end

	options = options or {}

	local channel = options.channel

	if channel and channel ~= 0 then
		if channels[channel] then
			return 0
		end
	else
		channel = freeChannel( 1 )

		if channel == 0 then
			return 0
		end
	end

	local loops = options.loops or 0
	local endTime

	if loops >= 0 then
		local length = handle.duration * ( loops + 1 )

		if options.duration then
			length = math.min( length, options.duration )
		end

		endTime = stub.clock + length
	end

	channels[channel] = { handle = handle, endTime = endTime, onComplete = options.onComplete, startFrame = stub.frame }

	return channel
end

local function forChannels( channel, action )
	local count = 0

	for i = 1, CHANNEL_COUNT do
		if ( channel == nil or channel == 0 or channel == i ) and channels[i] then
			action( i )
			count = count + 1
		end
	end

	return count
end

function audio.stop( channel )
	return forChannels( channel, function( i )
		finishChannel( i, false )
	end )
end

function audio.pause( channel )
	return forChannels( channel, function( i )
		local state = channels[i]

		if not state.pausedAt then
			state.pausedAt = stub.clock
		end
	end )
end

function audio.resume( channel )
	return forChannels( channel, function( i )
		local state = channels[i]

		if state.pausedAt then
			if state.endTime then
				state.endTime = state.endTime + stub.clock - state.pausedAt
			end

			state.pausedAt = nil
		end
	end )
end

function audio.rewind()
	return true
end

function audio.seek()
	return true
end

function audio.fade( options )
	if type( options ) ~= "table" then
		error( "audio.fade expects an options table", 2 )
	end

	return forChannels( options.channel, function() end )
end

function audio.fadeOut( options )
	if type( options ) ~= "table" then
		error( "audio.fadeOut expects an options table", 2 )
	end

	return forChannels( options.channel, function( i )
		channels[i].endTime = stub.clock + ( options.time or 1000 )
	end )
end

function audio.dispose( handle )
	if not isSoundHandle( handle ) then
		error( "audio.dispose: the handle is " .. type( handle ) .. ", not a loaded sound", 2 )
	end

	for i = 1, CHANNEL_COUNT do
		if channels[i] and channels[i].handle == handle then
			stub.warn( "audio.dispose on " .. tostring( handle.filename ) .. " while it still plays on channel " .. i )
		end
	end

	handle.isDisposed = true
end

function audio.setVolume( volume, options )
	checkNumber( "audio.setVolume", 1, volume )

	local channel = options and options.channel

	if channel and channel ~= 0 then
		channelVolumes[channel] = volume
	else
		masterVolume = volume
	end

	return true
end

function audio.getVolume( options )
	local channel = options and options.channel

	if channel and channel ~= 0 then
		return channelVolumes[channel] or 1
	end

	return masterVolume
end

function audio.setMaxVolume()
	return true
end

function audio.setMinVolume()
	return true
end

function audio.getMaxVolume()
	return 1
end

function audio.getMinVolume()
	return 0
end

function audio.reserveChannels( count )
	checkNumber( "audio.reserveChannels", 1, count )
	reservedChannels = math.max( 0, math.min( count, CHANNEL_COUNT ) )

	return reservedChannels
end

function audio.findFreeChannel( start )
	return freeChannel( start )
end

function audio.isChannelActive( channel )
	return channels[channel] ~= nil
end

function audio.isChannelPlaying( channel )
	return channels[channel] ~= nil and channels[channel].pausedAt == nil
end

function audio.isChannelPaused( channel )
	return channels[channel] ~= nil and channels[channel].pausedAt ~= nil
end

function audio.getDuration( handle )
	return isSoundHandle( handle ) and handle.duration or 0
end

local function usedChannelCount( fromChannel )
	local count = 0

	for i = fromChannel, CHANNEL_COUNT do
		if channels[i] then
			count = count + 1
		end
	end

	return count
end

strict( "audio", audio, {
	totalChannels = function()
		return CHANNEL_COUNT
	end,

	reservedChannels = function()
		return reservedChannels
	end,

	usedChannels = function()
		return usedChannelCount( 1 )
	end,

	freeChannels = function()
		return CHANNEL_COUNT - usedChannelCount( 1 )
	end,

	unreservedUsedChannels = function()
		return usedChannelCount( reservedChannels + 1 )
	end,

	unreservedFreeChannels = function()
		return CHANNEL_COUNT - reservedChannels - usedChannelCount( reservedChannels + 1 )
	end,
} )

local function stepAudio()
	for i = 1, CHANNEL_COUNT do
		local state = channels[i]

		if state and state.endTime and not state.pausedAt and state.endTime <= stub.clock then
			finishChannel( i, true )
		end
	end
end

-- Channels still active, as { channel, filename, startFrame }.
function stub.activeChannels()
	local active = {}

	for i = 1, CHANNEL_COUNT do
		if channels[i] then
			active[#active + 1] = { channel = i, filename = channels[i].handle.filename, startFrame = channels[i].startFrame }
		end
	end

	return active
end

--------------------------------------------------------------------------------------
-- system and native

system = {
	ResourceDirectory = newDirectory( "ResourceDirectory" ),
	DocumentsDirectory = newDirectory( "DocumentsDirectory" ),
	TemporaryDirectory = newDirectory( "TemporaryDirectory" ),
	CachesDirectory = newDirectory( "CachesDirectory" ),
	ApplicationSupportDirectory = newDirectory( "ApplicationSupportDirectory" ),
}

local systemInfo = {
	platform = "win32",
	platformName = "Win",
	environment = "simulator",
	model = "Harness",
	deviceID = "harness",
	appName = "Template Showcase",
	appVersionString = "1.0",
	build = "2025.3721",
	architectureInfo = "x86_64",
	language = "en",
}

function system.getTimer()
	return stub.clock
end

function system.getInfo( key )
	return systemInfo[key]
end

-- A missing resource file gives nil, like the engine; writable folders map to the run's temp folder.
function system.pathForFile( name, baseDirectory )
	baseDirectory = baseDirectory or system.ResourceDirectory

	if not isDirectory( baseDirectory ) then
		error( "system.pathForFile: argument 2 is not a system directory", 2 )
	end

	if baseDirectory == system.ResourceDirectory then
		if name == nil or name == "" then
			return "."
		end

		return fileExists( name ) and name or nil
	end

	local folder = stub.directoryPaths[baseDirectory.name]

	if name == nil or name == "" then
		return folder
	end

	return folder .. "/" .. name
end

function system.activate() end

function system.deactivate() end

function system.setIdleTimer() end

function system.vibrate() end

function system.openURL( url )
	stub.records.openURL = url

	return true
end

native = {
	systemFont = "native.systemFont",
	systemFontBold = "native.systemFontBold",
}

local nativeProperties = {}

function native.setProperty( key, value )
	nativeProperties[key] = value
end

function native.getProperty( key )
	return nativeProperties[key]
end

function native.newFont( name )
	return name
end

function native.getFontNames()
	return {}
end

function native.setKeyboardFocus() end

function native.showAlert( title, message )
	stub.records.alert = tostring( title ) .. ": " .. tostring( message )

	return {}
end

function native.requestExit()
	stub.records.requestExit = true
end

strict( "system", system )
strict( "native", native )

--------------------------------------------------------------------------------------
-- Standard library additions the engine makes

table.indexOf = function( t, object )
	if type( t ) == "table" then
		for i = 1, #t do
			if object == t[i] then
				return i
			end
		end
	end

	return nil
end

-- Copies only the array part, stopping at the first hole, like the engine's table.copy.
table.copy = function( ... )
	local result = {}
	local sources = { ... }

	for s = 1, select( "#", ... ) do
		local source = sources[s]

		if type( source ) == "table" then
			for i = 1, #source do
				if source[i] == nil then
					break
				end

				result[#result + 1] = source[i]
			end
		end
	end

	return result
end

math.round = function( number )
	return math.floor( number + 0.5 )
end

function string.starts( text, prefix )
	return string.sub( text, 1, string.len( prefix ) ) == prefix
end

function string.ends( text, suffix )
	return suffix == "" or string.sub( text, -string.len( suffix ) ) == suffix
end

--------------------------------------------------------------------------------------
-- Composer

local composer = {
	recycleOnSceneChange = false,
	recycleOnLowMemory = true,
	isDebug = false,
}

local composerVariables = {}
local sceneMethods = {}
local sceneMetatable = { __index = sceneMethods }

stub.currentSceneName = nil
stub.previousSceneName = nil

function sceneMethods:addEventListener( name, listener )
	return addListener( rawget( self, "_dispatcher" ), self, name, listener )
end

function sceneMethods:removeEventListener( name, listener )
	return removeListener( rawget( self, "_dispatcher" ), self, name, listener )
end

function sceneMethods:dispatchEvent( event )
	return dispatch( rawget( self, "_dispatcher" ), event )
end

function stub.isScene( value )
	return type( value ) == "table" and getmetatable( value ) == sceneMetatable
end

function stub.sceneHasListener( scene, name )
	return hasAnyListener( rawget( scene, "_dispatcher" ), name )
end

local function moduleExists( name )
	local relative = string.gsub( name, "%.", "/" )

	for pattern in string.gmatch( package.path, "[^;]+" ) do
		if fileExists( ( string.gsub( pattern, "%?", relative ) ) ) then
			return true
		end
	end

	return false
end

stub.moduleExists = moduleExists

function composer.newScene()
	local scene = { _dispatcher = newDispatcherState() }
	scene.view = newGroupObject( "group", composer.stage )

	return setmetatable( scene, sceneMetatable )
end

local function recordSceneChange( kind, name, options )
	if type( name ) ~= "string" then
		error( "composer." .. kind .. ": scene name must be a string, got " .. type( name ), 3 )
	end

	if ( kind == "gotoScene" or kind == "showOverlay" ) and not moduleExists( name ) then
		error( "composer." .. kind .. ": no module " .. name, 3 )
	end

	local caller = debug.getinfo( 3, "Sl" )
	local where = caller and ( caller.short_src .. ":" .. tostring( caller.currentline ) ) or "?"
	stub.sceneChanges[#stub.sceneChanges + 1] = { kind = kind, name = name, options = options, caller = where, frame = stub.frame }
end

function composer.gotoScene( name, options )
	recordSceneChange( "gotoScene", name, options )
end

function composer.showOverlay( name, options )
	recordSceneChange( "showOverlay", name, options )
end

function composer.hideOverlay() end

function composer.removeScene( name )
	recordSceneChange( "removeScene", name )
end

function composer.removeHidden() end

function composer.loadScene( name )
	recordSceneChange( "loadScene", name )
end

function composer.getSceneName( kind )
	if kind == "current" then
		return stub.currentSceneName

	elseif kind == "previous" then
		return stub.previousSceneName

	elseif kind == "overlay" then
		return nil
	end

	error( "composer.getSceneName: unknown kind " .. tostring( kind ), 2 )
end

function composer.getScene( name )
	local scene = package.loaded[name]

	return stub.isScene( scene ) and scene or nil
end

function composer.setVariable( key, value )
	composerVariables[key] = value
end

function composer.getVariable( key )
	return composerVariables[key]
end

function stub.sceneEvent( scene, name, phase, params )
	return dispatch( rawget( scene, "_dispatcher" ), { name = name, phase = phase, params = params } )
end

--------------------------------------------------------------------------------------
-- Frames and install

function stub.step()
	stub.frame = stub.frame + 1
	stub.clock = stub.clock + FRAME_MS
	stub.call( stepPhysics, FRAME_MS / 1000 )
	stub.call( stepAudio )
	dispatch( runtimeState, { name = "enterFrame", time = stub.clock, frame = stub.frame } )
end

function stub.physicsState()
	return world.state
end

-- Timers not yet fired or cancelled, and transitions still running.
function stub.pendingTimerCount()
	local count = 0
	local lists = { timer._runlist, timer._pausedTimers }

	for l = 1, #lists do
		local list = lists[l] or {}

		for i = 1, #list do
			if not list[i]._cancelled and not list[i]._expired then
				count = count + 1
			end
		end
	end

	return count
end

function stub.activeTransitionCount()
	local count = 0
	local list = transition._transitionTable or {}

	for i = 1, #list do
		if not list[i]._cancelled then
			count = count + 1
		end
	end

	return count
end

function stub.isLibraryListener( listener )
	return rawequal( listener, timer ) or rawequal( listener, transition )
end

function stub.install( directory, temporaryRoot )
	harnessDirectory = directory
	stub.directoryPaths = {
		DocumentsDirectory = temporaryRoot .. "/Documents",
		TemporaryDirectory = temporaryRoot .. "/Temporary",
		CachesDirectory = temporaryRoot .. "/Caches",
		ApplicationSupportDirectory = temporaryRoot .. "/ApplicationSupport",
	}

	for _, path in pairs( stub.directoryPaths ) do
		os.execute( "mkdir -p '" .. path .. "'" )
	end

	package.preload["CoronaLibrary"] = function()
		return {
			new = function( _, library )
				return library
			end,
		}
	end

	easing = dofile( harnessDirectory .. "/engine/easing.lua" )
	timer = dofile( harnessDirectory .. "/engine/timer.lua" )
	transition = dofile( harnessDirectory .. "/engine/transition.lua" )

	package.preload["composer"] = function()
		composer.stage = newGroupObject( "group" )
		strict( "composer", composer )

		return composer
	end

	package.preload["physics"] = function()
		return physics
	end

	package.preload["json"] = function()
		return dofile( harnessDirectory .. "/stub/json.lua" )
	end

	stub.audio = audio
	_G.audio = audio
end

return stub
