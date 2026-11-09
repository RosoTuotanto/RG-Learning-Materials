local hud = {}

--------------------------------------------------------------------------------------
-- Libraries, classes, scripts, configs, etc.

local pixelFilter = require( "samples.platformer-puzzle.classes.pixelFilter" )

--------------------------------------------------------------------------------------
-- Private functions

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

--------------------------------------------------------------------------------------
-- Public functions

-- params: parent, settings and onPlayAgain.
function hud.new( params )
	local settings = params.settings
	local config = settings.hud
	local colors = settings.colors

	local view = display.newGroup()
	params.parent:insert( view )

	-- The room label and the carried key sit below the Back button, clear of both top corners.
	local corner = display.newGroup()
	view:insert( corner )

	local roomLabel = display.newText({
		parent = corner,
		text = "",
		x = 0,
		y = 0,
		font = settings.font.heading,
		fontSize = config.labelSize,
	})
	roomLabel.anchorX = 0
	roomLabel:setFillColor( unpack( colors.text ) )

	pixelFilter.begin()

	local keyIcon = display.newImageRect( corner, settings.images.key, config.keyIconSize, config.keyIconSize )
	keyIcon.anchorX = 0
	keyIcon.isVisible = false

	pixelFilter.finish()

	local hintBackground = display.newRect( view, 0, 0, 1, 1 )
	hintBackground:setFillColor( unpack( colors.hintBackground ) )

	local hints = {}
	for i = 1, #settings.text.hint do
		hints[i] = display.newText({
			parent = view,
			text = settings.text.hint[i],
			x = display.contentCenterX,
			y = 0,
			font = settings.font.body,
			fontSize = config.hintSize,
		})
		hints[i]:setFillColor( unpack( colors.hintText ) )
	end

	local message = display.newGroup()
	message.x, message.y = display.contentCenterX, display.contentCenterY
	message.isVisible = false
	view:insert( message )

	local solvedLabel = display.newText({
		parent = message,
		text = settings.text.solved,
		x = 0,
		y = 0,
		font = settings.font.heading,
		fontSize = config.messageSize,
	})
	solvedLabel:setFillColor( unpack( colors.text ) )

	local buttonConfig = config.button
	local button = display.newRoundedRect( message, 0, buttonConfig.offsetY, buttonConfig.width, buttonConfig.height, buttonConfig.cornerRadius )
	button:setFillColor( unpack( colors.button ) )

	local buttonLabel = display.newText({
		parent = message,
		text = settings.text.playAgain,
		x = 0,
		y = buttonConfig.offsetY,
		font = settings.font.heading,
		fontSize = buttonConfig.labelSize,
	})
	buttonLabel:setFillColor( unpack( colors.buttonLabel ) )

	-- Hidden objects get no touches, so the button only answers while the message shows.
	local function onButtonTouch( event )
		if event.phase == "began" then
			params.onPlayAgain()
		end

		return true
	end

	button:addEventListener( "touch", onButtonTouch )

	function view:setRoom( number )
		roomLabel.text = settings.text.room .. number
		keyIcon.x = roomLabel.width + config.keyIconGap
	end

	function view:showKey( isShown )
		keyIcon.isVisible = isShown
	end

	function view:showMessage( isShown )
		message.isVisible = isShown
	end

	-- Call on resize: the corner and the hints follow the actual screen edges.
	function view:position()
		corner.x = display.screenOriginX + config.left
		corner.y = display.screenOriginY + config.top

		local bottom = display.screenOriginY + display.actualContentHeight
		for i = 1, #hints do
			hints[i].y = bottom - config.hintOffsets[i]
		end

		fitBackground( hintBackground, hints, config.hintPadding )
	end

	view:position()

	return view
end

return hud
