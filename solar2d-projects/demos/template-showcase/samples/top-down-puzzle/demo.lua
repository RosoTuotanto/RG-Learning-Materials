-- Grid puzzle rooms: push crates onto every plate to open the door to the next room.

--------------------------------------------------------------------------------------
-- Libraries, classes, scripts, configs, etc.

local composer = require( "composer" )

local settings = require( "samples.top-down-puzzle.data.settings" )
local roomData = require( "samples.top-down-puzzle.data.rooms" )

local input = require( "samples.top-down-puzzle.classes.input" )
local puzzle = require( "samples.top-down-puzzle.classes.puzzle" )
local board = require( "samples.top-down-puzzle.classes.board" )

--------------------------------------------------------------------------------------
-- Forward declarations & variables

local controls
local world
local room
local view

local hud
local roomLabel
local movesLabel
local finishedGroup

local roomIndex = 1
local isFinished = false

-- Cleared while the scene is hidden or fading, so no step or room change runs then.
local isActive = false

local advance

--------------------------------------------------------------------------------------
-- Functions

local function updateHud()
	roomLabel.text = string.format( settings.text.room, roomIndex, #roomData.rooms )
	movesLabel.text = string.format( settings.text.moves, room:getMoveCount() )
end

-- The labels follow the app's back button, which sits at the actual screen corner.
local function positionHud()
	local style = settings.hud

	hud.x = display.screenOriginX + style.margin
	hud.y = display.screenOriginY + style.margin + style.backHeight + style.gap
end

local function loadRoom( index )
	if view then
		view:cancel()
		display.remove( view )
		view = nil
	end

	controls:clearPressed()

	roomIndex = index
	isFinished = index > #roomData.rooms
	hud.isVisible = not isFinished
	finishedGroup.isVisible = isFinished

	if isFinished then
		-- Idea: add a level select that saves the best move count of each room with the template's save system.
		return
	end

	room = puzzle.new( roomData.rooms[index], roomData.symbols )

	display.setDefault( "magTextureFilter", "nearest" )
	display.setDefault( "minTextureFilter", "nearest" )

	view = board.new( world, room, settings.board )

	display.setDefault( "magTextureFilter", "linear" )
	display.setDefault( "minTextureFilter", "linear" )

	view.x = display.contentCenterX - view.boardWidth * 0.5
	view.y = display.contentCenterY - view.boardHeight * 0.5

	updateHud()
end

-- A press made during the previous step goes first, then a key still held keeps stepping.
local function tryStep()
	local directionX, directionY = controls:takePressedDirection()
	if directionX == 0 and directionY == 0 then
		directionX, directionY = controls:getHeldDirection()
	end

	if directionX == 0 and directionY == 0 then
		return
	end

	view:face( directionX )

	local step = room:move( directionX, directionY )
	if not step then
		return
	end

	updateHud()
	view:animateStep( step, advance )
end

-- Leaves through the open door when the hero stands in it, otherwise takes the next step.
function advance()
	if room:isExited() then
		loadRoom( roomIndex + 1 )

	else
		tryStep()
	end
end

local function onAction( action )
	if isFinished then
		return
	end

	if action == "undo" then
		room:undo()

	elseif action == "restart" then
		room:restart()

	else
		return
	end

	-- Snapping cancels the step in progress, so it can never finish after the room went back.
	view:sync()
	updateHud()
end

local function onEnterFrame()
	if isActive and not isFinished and not view.isMoving then
		advance()
	end
end

local function onRestartTouch( event )
	if event.phase == "began" then
		loadRoom( 1 )
	end

	return true
end

local function newText( parent, text, x, y, font, fontSize, color )
	local label = display.newText({
		parent = parent,
		text = text,
		x = x,
		y = y,
		font = font,
		fontSize = fontSize,
	})
	label:setFillColor( unpack( color ) )

	return label
end

-- Fits a background around the centre-anchored lines' actual size, plus padding on every side.
local function fitBackground( background, lines, padding )
	local left, top = math.huge, math.huge
	local right, bottom = -math.huge, -math.huge

	for i = 1, #lines do
		local line = lines[i]
		local halfWidth, halfHeight = line.width * 0.5, line.height * 0.5

		left, right = math.min( left, line.x - halfWidth ), math.max( right, line.x + halfWidth )
		top, bottom = math.min( top, line.y - halfHeight ), math.max( bottom, line.y + halfHeight )
	end

	background.x, background.y = ( left + right ) * 0.5, ( top + bottom ) * 0.5
	background.width = right - left + padding * 2
	background.height = bottom - top + padding * 2
end

local function newRestartButton( parent )
	local style = settings.hud.button

	local button = display.newGroup()
	parent:insert( button )
	button.y = settings.hud.buttonOffset

	local background = display.newRoundedRect( button, 0, 0, style.width, style.height, style.cornerRadius )
	background:setFillColor( unpack( settings.colors.buttonFill ) )
	background:setStrokeColor( unpack( settings.colors.buttonBorder ) )
	background.strokeWidth = style.strokeWidth

	newText( button, settings.text.restartButton, 0, 0, settings.font.heading, style.fontSize, settings.colors.text )

	button:addEventListener( "touch", onRestartTouch )

	return button
end

--------------------------------------------------------------------------------------
-- Scene functions

local scene = composer.newScene()

function scene:create( event )
	local sceneGroup = self.view
	local style = settings.hud

	world = display.newGroup()
	sceneGroup:insert( world )

	hud = display.newGroup()
	sceneGroup:insert( hud )

	roomLabel = newText( hud, "", 0, 0, settings.font.heading, style.labelSize, settings.colors.text )
	movesLabel = newText( hud, "", 0, style.lineHeight, settings.font.body, style.labelSize, settings.colors.text )
	roomLabel.anchorX, roomLabel.anchorY = 0, 0
	movesLabel.anchorX, movesLabel.anchorY = 0, 0

	local hintBackground = display.newRect( sceneGroup, 0, 0, 1, 1 )
	hintBackground:setFillColor( unpack( settings.colors.hintBackground ) )

	local hintLines = {}
	for i = 1, #settings.text.hint do
		local y = style.hintY - ( #settings.text.hint - i ) * style.hintLineHeight
		hintLines[i] = newText( sceneGroup, settings.text.hint[i], display.contentCenterX, y, settings.font.body, style.hintSize, settings.colors.hintText )
	end

	fitBackground( hintBackground, hintLines, style.hintPadding )

	finishedGroup = display.newGroup()
	sceneGroup:insert( finishedGroup )
	finishedGroup.x, finishedGroup.y = display.contentCenterX, display.contentCenterY

	newText( finishedGroup, settings.text.finished, 0, style.titleOffset, settings.font.heading, style.titleSize, settings.colors.text )
	newRestartButton( finishedGroup )

	controls = input.new( settings.keys, onAction )

	positionHud()
	loadRoom( 1 )
end

function scene:show( event )
	local phase = event.phase

	if phase == "did" then
		isActive = true
		controls:start()
		Runtime:addEventListener( "enterFrame", onEnterFrame )
		Runtime:addEventListener( "resize", positionHud )
		positionHud()
	end
end

function scene:hide( event )
	local phase = event.phase

	if phase == "will" then
		-- Snapping can leave the hero standing in the open door; the cleared flag keeps that from loading the next room during the fade.
		isActive = false
		controls:stop()

		if view then
			view:sync()
		end

	elseif phase == "did" then
		Runtime:removeEventListener( "enterFrame", onEnterFrame )
		Runtime:removeEventListener( "resize", positionHud )
	end
end

function scene:destroy( event )
	controls = nil
	world = nil
	room = nil
	view = nil

	hud = nil
	finishedGroup = nil
end

--------------------------------------------------------------------------------------

scene:addEventListener( "create", scene )
scene:addEventListener( "show", scene )
scene:addEventListener( "hide", scene )
scene:addEventListener( "destroy", scene )

return scene
