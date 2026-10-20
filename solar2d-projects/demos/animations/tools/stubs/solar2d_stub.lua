-- Minimal Solar2D stand-in for running the demo's Lua outside the Simulator.

local stub = {}

stub.violations = {}
stub.sprites = {}
stub.imageSheets = {}
stub.images = {}
stub.defaults = {}
stub.scenesVisited = {}
stub.clock = 0

-- The demo root is two folders above this file, so system.pathForFile can hand real paths to io.open.
local stubSource = string.gsub( debug.getinfo( 1, "S" ).source, "^@", "" )
local stubDirectory = string.match( stubSource, "^(.*)/[^/]*$" ) or "."
stub.root = string.match( stubDirectory, "^(.*)/tools/stubs$" ) or ( stubDirectory .. "/../.." )

if stub.root == "" then
	stub.root = "."
end

local function fail( message )
	stub.violations[#stub.violations + 1] = message
end

local function resourcePath( name )
	return stub.root .. "/" .. name
end

-- Reads a PNG's IHDR so a missing or non-PNG file stops the run instead of drawing nothing.
local function readPngSize( name )
	local path = resourcePath( name )
	local file = io.open( path, "rb" )

	if not file then
		error( "image not found: " .. path, 3 )
	end

	local header = file:read( 24 )
	file:close()

	if not header or #header < 24 or string.sub( header, 2, 4 ) ~= "PNG" or string.sub( header, 13, 16 ) ~= "IHDR" then
		error( "not a PNG file: " .. path, 3 )
	end

	local function readU32( offset )
		local b1, b2, b3, b4 = string.byte( header, offset, offset + 3 )

		return ( ( b1 * 256 + b2 ) * 256 + b3 ) * 256 + b4
	end

	return readU32( 17 ), readU32( 21 )
end

--------------------------------------------------------------------------------------
-- Display objects

local function callListener( listener, event )
	if type( listener ) == "function" then
		return listener( event )
	end

	return listener[event.name]( listener, event )
end

local function removeFromParent( object )
	local parent = object.parent

	if not parent then
		return
	end

	for i = 1, parent.numChildren do
		if parent[i] == object then
			table.remove( parent, i )
			parent.numChildren = parent.numChildren - 1
			break
		end
	end

	object.parent = nil
end

local function newObject( kind )
	local object = {
		kind = kind,
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
		numChildren = 0,
		isRemoved = false,
		listeners = {},
	}

	function object:setFillColor( r, g, b, a )
		self.fillColor = { r, g, b, a or 1 }
	end

	function object:setStrokeColor( r, g, b, a )
		self.strokeColor = { r, g, b, a or 1 }
	end

	function object:insert( child )
		removeFromParent( child )
		self.numChildren = self.numChildren + 1
		self[self.numChildren] = child
		child.parent = self
	end

	function object:toFront()
		local parent = self.parent

		if parent then
			removeFromParent( self )
			parent:insert( self )
		end
	end

	function object:toBack()
		local parent = self.parent

		if parent then
			removeFromParent( self )
			table.insert( parent, 1, self )
			parent.numChildren = parent.numChildren + 1
			self.parent = parent
		end
	end

	function object:addEventListener( name, listener )
		self.listeners[name] = self.listeners[name] or {}
		table.insert( self.listeners[name], listener )
	end

	function object:removeEventListener( name, listener )
		local listeners = self.listeners[name] or {}

		for i = #listeners, 1, -1 do
			if listeners[i] == listener then
				table.remove( listeners, i )
			end
		end
	end

	function object:dispatchEvent( event )
		local listeners = self.listeners[event.name] or {}

		for i = 1, #listeners do
			callListener( listeners[i], event )
		end
	end

	function object:removeSelf()
		if self.isRemoved then
			fail( "removeSelf called twice on a " .. self.kind )
			return
		end

		for i = self.numChildren, 1, -1 do
			self[i]:removeSelf()
		end

		removeFromParent( self )
		self.isRemoved = true
		self:dispatchEvent({ name = "finalize", target = self })
	end

	return object
end

local function attach( parent, object )
	if parent then
		parent:insert( object )
	end

	return object
end

display = {
	contentWidth = 960,
	contentHeight = 640,
	contentCenterX = 480,
	contentCenterY = 320,
	actualContentWidth = 960,
	actualContentHeight = 640,
	screenOriginX = 0,
	screenOriginY = 0,
	safeScreenOriginX = 0,
	safeScreenOriginY = 0,
	safeActualContentWidth = 960,
	safeActualContentHeight = 640,
	HiddenStatusBar = "HiddenStatusBar",
}

local stage = newObject( "stage" )
stub.stage = stage

function stage:setFocus( object )
	stub.focus = object
end

function display.getCurrentStage()
	return stage
end

function display.setStatusBar( mode )
	stub.statusBar = mode
end

function display.setDefault( key, ... )
	stub.defaults[key] = { ... }
end

function display.newGroup()
	return attach( stage, newObject( "group" ) )
end

local function newShape( kind, parent, x, y, width, height )
	local object = newObject( kind )
	object.x, object.y, object.width, object.height = x, y, width, height

	return attach( parent or stage, object )
end

function display.newRect( parent, x, y, width, height )
	return newShape( "rect", parent, x, y, width, height )
end

function display.newRoundedRect( parent, x, y, width, height, cornerRadius )
	local object = newShape( "roundedRect", parent, x, y, width, height )
	object.cornerRadius = cornerRadius

	return object
end

-- Accepts ( [parent,] filename, [baseDir,] width, height ), the engine's overloads.
function display.newImageRect( ... )
	local args = { ... }
	local index = 1
	local parent

	if type( args[1] ) == "table" then
		parent = args[1]
		index = 2
	end

	local filename = args[index]
	index = index + 1

	if type( args[index] ) ~= "number" then
		index = index + 1
	end

	local object = newObject( "image" )
	object.filename = filename
	object.width, object.height = args[index], args[index + 1]
	object.imageWidth, object.imageHeight = readPngSize( filename )
	object.path = { x1 = 0, y1 = 0, x2 = 0, y2 = 0, x3 = 0, y3 = 0, x4 = 0, y4 = 0 }
	stub.images[#stub.images + 1] = object

	return attach( parent or stage, object )
end

local function checkFont( font )
	if font and font ~= native.systemFont and font ~= native.systemFontBold then
		local file = io.open( resourcePath( font ), "rb" )

		if file then
			file:close()
		else
			fail( "font not found: " .. tostring( font ) )
		end
	end
end

-- Accepts the params table form and ( parent, text, x, y, font, fontSize ).
-- A params width wraps the text into lines of that width, estimated from the character count.
function display.newText( ... )
	local params = ...

	if type( params ) ~= "table" or params.numChildren then
		local args = { ... }
		params = { parent = args[1], text = args[2], x = args[3], y = args[4], font = args[5], fontSize = args[6] }
	end

	checkFont( params.font )

	local object = newObject( "text" )
	object.x, object.y = params.x or 0, params.y or 0
	object.text = params.text or ""
	object.font = params.font
	object.size = params.fontSize or 12
	object.align = params.align
	object.width = #object.text * object.size * 0.52
	object.height = object.size * 1.25

	if params.width then
		local lines = math.max( 1, math.ceil( object.width / params.width ) )
		object.width = params.width
		object.height = object.height * lines
	end

	return attach( params.parent or stage, object )
end

function display.remove( object )
	if object and object.removeSelf then
		object:removeSelf()
	end
end

--------------------------------------------------------------------------------------
-- Image sheets and sprites

graphics = {}

function graphics.newImageSheet( filename, options )
	local imageWidth, imageHeight = readPngSize( filename )
	local columns = math.floor( imageWidth / options.width )
	local rows = math.floor( imageHeight / options.height )

	if columns * rows < options.numFrames then
		fail( filename .. " holds " .. columns * rows .. " frames, sheet options ask for " .. options.numFrames )
	end

	local sheet = { filename = filename, options = options }
	stub.imageSheets[#stub.imageSheets + 1] = sheet

	return sheet
end

-- Accepts ( [parent,] imageSheet, sequenceData ).
function display.newSprite( ... )
	local args = { ... }
	local parent, sheet, sequences = args[1], args[2], args[3]

	if not sequences then
		parent, sheet, sequences = nil, args[1], args[2]
	end

	local sprite = newObject( "sprite" )
	sprite.sheet = sheet
	sprite.sequences = sequences
	sprite.sequence = sequences[1].name
	sprite.isPlaying = false
	sprite.calls = {}

	for i = 1, #sequences do
		local sequence = sequences[i]
		local frames = sequence.frames

		if type( frames ) ~= "table" or #frames == 0 then
			fail( "sprite sequence " .. tostring( sequence.name ) .. " has no frames array" )
		else
			for j = 1, #frames do
				local frame = frames[j]
				local isIndex = type( frame ) == "number" and frame == math.floor( frame )

				if not isIndex or frame < 1 or frame > sheet.options.numFrames then
					local where = "sprite sequence " .. tostring( sequence.name ) .. " frame " .. j
					fail( where .. " is " .. tostring( frame ) .. ", not a sheet frame in 1.." .. sheet.options.numFrames )
				end
			end
		end
	end

	function sprite:setSequence( name )
		self.calls[#self.calls + 1] = "setSequence:" .. tostring( name )

		local found = false

		for i = 1, #self.sequences do
			if self.sequences[i].name == name then
				found = true
			end
		end

		if not found then
			fail( "setSequence with unknown sequence " .. tostring( name ) )
		end

		self.sequence = name
		self.isPlaying = false
	end

	function sprite:play()
		self.calls[#self.calls + 1] = "play"
		self.isPlaying = true
	end

	function sprite:pause()
		self.calls[#self.calls + 1] = "pause"
		self.isPlaying = false
	end

	stub.sprites[#stub.sprites + 1] = sprite

	return attach( parent or stage, sprite )
end

--------------------------------------------------------------------------------------
-- Touch dispatch

-- Walks front to back, collecting hit objects that listen for touches. A group counts
-- as hit when any of its children is, and comes after them, as the engine orders it.
local function collectHits( object, x, y, hits )
	if not object.isVisible and not object.isHitTestable then
		return false
	end

	local isHit = false

	if object.kind == "group" or object.kind == "stage" then
		local localX = ( x - object.x ) / object.xScale
		local localY = ( y - object.y ) / object.yScale

		for i = object.numChildren, 1, -1 do
			if collectHits( object[i], localX, localY, hits ) then
				isHit = true
			end
		end
	else
		local width = object.width * math.abs( object.xScale )
		local height = object.height * math.abs( object.yScale )
		local left = object.x - width * object.anchorX
		local top = object.y - height * object.anchorY

		isHit = x >= left and x <= left + width and y >= top and y <= top + height
	end

	if isHit and object.listeners["touch"] and #object.listeners["touch"] > 0 then
		hits[#hits + 1] = object
	end

	return isHit
end

-- Sends one touch phase at a content point; the first listener returning true stops it.
function stub.touchAt( x, y, phase )
	local hits = {}
	collectHits( stage, x, y, hits )

	for i = 1, #hits do
		local target = hits[i]
		local listeners = target.listeners["touch"]
		local event = { name = "touch", phase = phase or "began", target = target, x = x, y = y, xStart = x, yStart = y }

		for j = 1, #listeners do
			if callListener( listeners[j], event ) then
				return target
			end
		end
	end

	return nil
end

function stub.tapAt( x, y )
	local target = stub.touchAt( x, y, "began" )
	stub.touchAt( x, y, "ended" )

	return target
end

function stub.contentPosition( object )
	local x, y = object.x, object.y
	local parent = object.parent

	while parent do
		x = parent.x + parent.xScale * x
		y = parent.y + parent.yScale * y
		parent = parent.parent
	end

	return x, y
end

function stub.findObject( root, predicate )
	if predicate( root ) then
		return root
	end

	for i = 1, root.numChildren do
		local found = stub.findObject( root[i], predicate )

		if found then
			return found
		end
	end

	return nil
end

--------------------------------------------------------------------------------------
-- Timers, transitions, easing, native, system

local timers = {}

timer = {}

function timer.performWithDelay( delay, listener, iterations )
	local handle = { delay = delay, listener = listener, iterations = iterations or 1, count = 0 }
	timers[#timers + 1] = handle

	return handle
end

function timer.cancel( handle )
	for i = #timers, 1, -1 do
		if timers[i] == handle then
			table.remove( timers, i )
		end
	end
end

-- Fires every pending timer once, as if each one's delay had passed.
function stub.runTimers()
	local due = timers
	timers = {}

	for i = 1, #due do
		local handle = due[i]
		handle.count = handle.count + 1
		callListener( handle.listener, { name = "timer", source = handle, count = handle.count } )

		if handle.iterations <= 0 or handle.count < handle.iterations then
			timers[#timers + 1] = handle
		end
	end
end

function stub.pendingTimerCount()
	return #timers
end

transition = {}

function transition.to()
	return {}
end

function transition.cancel() end

easing = {}

native = {
	systemFont = "native.systemFont",
	systemFontBold = "native.systemFontBold",
}

function native.setProperty() end

system = {
	ResourceDirectory = { name = "ResourceDirectory" },
	DocumentsDirectory = { name = "DocumentsDirectory" },
	TemporaryDirectory = { name = "TemporaryDirectory" },
	CachesDirectory = { name = "CachesDirectory" },
}

function system.getInfo( key )
	if key == "platform" then
		return "linux"
	end

	return nil
end

function system.getTimer()
	return stub.clock
end

-- Only the resource directory maps to a real folder; the demo writes nothing.
function system.pathForFile( name, baseDir )
	if baseDir == nil or baseDir == system.ResourceDirectory then
		return resourcePath( name )
	end

	return nil
end

--------------------------------------------------------------------------------------
-- Runtime

local runtimeListeners = {}

Runtime = {}

function Runtime:addEventListener( name, listener )
	runtimeListeners[name] = runtimeListeners[name] or {}
	table.insert( runtimeListeners[name], listener )
end

function Runtime:removeEventListener( name, listener )
	local listeners = runtimeListeners[name] or {}

	for i = #listeners, 1, -1 do
		if listeners[i] == listener then
			table.remove( listeners, i )
		end
	end
end

-- Iterates a copy, since a listener may remove itself mid-dispatch.
function stub.fire( name, event )
	local listeners = {}
	local source = runtimeListeners[name] or {}

	for i = 1, #source do
		listeners[i] = source[i]
	end

	event = event or {}
	event.name = name

	for i = 1, #listeners do
		callListener( listeners[i], event )
	end
end

function stub.listenerCount( name )
	return #( runtimeListeners[name] or {} )
end

-- Moves the clock forward and sends one enterFrame at the new time.
function stub.advanceFrame( milliseconds )
	stub.clock = stub.clock + milliseconds
	stub.fire( "enterFrame", { time = stub.clock } )
end

--------------------------------------------------------------------------------------
-- Composer and json

local composer = {}

function composer.newScene()
	local scene = { view = display.newGroup(), sceneListeners = {} }

	function scene:addEventListener( name, listener )
		self.sceneListeners[name] = listener
	end

	return scene
end

function composer.gotoScene( name )
	stub.scenesVisited[#stub.scenesVisited + 1] = name
end

-- Sends a scene event through the listener the scene registered for it.
function stub.sceneEvent( scene, name, phase )
	local listener = scene.sceneListeners[name]

	if not listener then
		fail( "scene has no " .. name .. " listener" )
		return
	end

	callListener( listener, { name = name, phase = phase } )
end

package.preload["composer"] = function()
	return composer
end

package.preload["json"] = function()
	return dofile( stubDirectory .. "/json.lua" )
end

return stub
