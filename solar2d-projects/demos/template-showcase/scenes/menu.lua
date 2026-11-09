--------------------------------------------------------------------------------------
-- Libraries, classes, scripts, configs, etc.

local composer = require( "composer" )
local layout = require( "data.layout" )
local strings = require( "data.strings" )
local samples = require( "data.samples" )
local screen = require( "scripts.screen" )
local ui = require( "scripts.ui" )
local appOverlay = require( "scripts.appOverlay" )

--------------------------------------------------------------------------------------
-- Forward declarations & variables

local palette = layout.palette
local columnSettings = layout.columns
local disclaimerSettings = layout.disclaimer

local disclaimer

--------------------------------------------------------------------------------------
-- Functions

local function newSampleButton( parent, sample, x, y )
	ui.newButton({
		parent = parent,
		x = x,
		y = y,
		label = sample.label,
		onPress = function()
			composer.gotoScene( "scenes.loading", { params = { module = sample.module } } )
		end,
	})
end

local function newColumns( parent )
	local columnIndex = {}
	local rowCount = {}

	for i = 1, #samples.columns do
		local column = samples.columns[i]
		columnIndex[column] = i
		rowCount[column] = 0

		local title = display.newText({
			parent = parent,
			text = strings.columns[column],
			x = columnSettings.x[i],
			y = columnSettings.titleY,
			font = layout.font.heading,
			fontSize = columnSettings.titleSize,
		})
		ui.setColor( title, palette.text )
	end

	for i = 1, #samples.list do
		local sample = samples.list[i]
		local column = sample.column
		local y = columnSettings.firstButtonY + rowCount[column] * columnSettings.buttonSpacing

		newSampleButton( parent, sample, columnSettings.x[columnIndex[column]], y )
		rowCount[column] = rowCount[column] + 1
	end
end

-- The disclaimer's origin is the bottom centre of its box, so it can be pinned straight to the bottom screen edge.
local function newDisclaimer( parent )
	local group = display.newGroup()
	parent:insert( group )

	local padding = disclaimerSettings.padding
	local linePitch = disclaimerSettings.linePitch
	local lines = strings.disclaimer
	local boxHeight = linePitch * #lines + padding * 2
	local textWidth = 0

	for i = 1, #lines do
		local text = display.newText({
			parent = group,
			text = lines[i],
			x = 0,
			y = padding - boxHeight + linePitch * ( i - 0.5 ),
			font = layout.font.body,
			fontSize = disclaimerSettings.size,
		})

		textWidth = math.max( textWidth, text.contentWidth )
	end

	local box = display.newRect( group, 0, -boxHeight * 0.5, textWidth + padding * 2, boxHeight )
	box:setFillColor( palette.disclaimerFill )
	box:toBack()

	return group
end

-- Also the resize listener: screen.lua registers its own resize listener first, so its edges are already refreshed here.
local function positionDisclaimer()
	disclaimer.x = screen.centerX
	disclaimer.y = screen.maxY - disclaimerSettings.margin
end

--------------------------------------------------------------------------------------
-- Scene functions

local scene = composer.newScene()

function scene:create( event )
	local sceneGroup = self.view

	local heading = display.newText({
		parent = sceneGroup,
		text = strings.heading,
		x = screen.centerX,
		y = layout.heading.y,
		font = layout.font.heading,
		fontSize = layout.heading.size,
	})
	heading.anchorY = 0
	ui.setColor( heading, palette.text )

	local paragraph = display.newText({
		parent = sceneGroup,
		text = strings.paragraph,
		x = screen.centerX,
		y = layout.paragraph.y,
		width = layout.paragraph.width,
		font = layout.font.body,
		fontSize = layout.paragraph.size,
		align = "center",
	})
	paragraph.anchorY = 0
	ui.setColor( paragraph, palette.textMuted )

	newColumns( sceneGroup )

	disclaimer = newDisclaimer( sceneGroup )
end

function scene:show( event )
	local phase = event.phase

	if phase == "will" then
		appOverlay.setBackVisible( false )
		positionDisclaimer()
		Runtime:addEventListener( "resize", positionDisclaimer )

	elseif phase == "did" then
		-- Removing the sample just left makes every visit start fresh, with nothing carried over.
		local previousScene = composer.getSceneName( "previous" )

		if previousScene then
			composer.removeScene( previousScene )
		end
	end
end

function scene:hide( event )
	if event.phase == "did" then
		Runtime:removeEventListener( "resize", positionDisclaimer )
	end
end

--------------------------------------------------------------------------------------

scene:addEventListener( "create", scene )
scene:addEventListener( "show", scene )
scene:addEventListener( "hide", scene )

return scene
