-- A dialogue box at the bottom of the screen that plays one Weaver passage at a time.

local dialogueBox = {}

--------------------------------------------------------------------------------------
-- Libraries, classes, scripts, configs, etc.

local weaver = require( "samples.platformer-story.libs.spyricStoryWeaver" )

--------------------------------------------------------------------------------------
-- Public functions

-- params: parent, storyName, config (settings.dialogue), colors, font and commands ( name = function( row ) ).
function dialogueBox.new( params )
	local config = params.config
	local colors = params.colors

	local box = display.newGroup()
	params.parent:insert( box )
	box.isVisible = false

	local rows = {}
	local rowIndex = 1
	local choices = {}
	local selected = 1

	-- Oversized so a click anywhere advances the text, even after the window is resized.
	local sensor = display.newRect( box, 0, 0, display.actualContentWidth * 4, display.actualContentHeight * 4 )
	sensor.isVisible = false
	sensor.isHitTestable = true

	local panel = display.newRoundedRect( box, 0, 0, config.width, config.height, config.cornerRadius )
	panel:setFillColor( unpack( colors.panel ) )

	local left = -config.width * 0.5 + config.padding
	local top = -config.height * 0.5

	local speaker = display.newText( box, "", left, top + config.padding, params.font.heading, config.nameSize )
	speaker.anchorX, speaker.anchorY = 0, 0
	speaker:setFillColor( unpack( colors.speaker ) )

	local body = display.newText({
		parent = box,
		text = "",
		x = left,
		y = top + config.textOffset,
		width = config.width - config.padding * 2,
		font = params.font.body,
		fontSize = config.textSize,
	})
	body.anchorX, body.anchorY = 0, 0

	local function clearChoices()
		for i = #choices, 1, -1 do
			display.remove( choices[i] )
			choices[i] = nil
		end
	end

	local function highlight( index )
		selected = index

		for i = 1, #choices do
			choices[i].background:setFillColor( unpack( i == index and colors.choiceSelected or colors.choice ) )
		end
	end

	local function onChoiceTouch( event )
		if event.phase == "began" then
			box:choose( event.target.index )
		end

		return true
	end

	local function addChoice( row )
		local index = #choices + 1
		local choice = display.newGroup()
		box:insert( choice )
		choice.y = top + config.choicesOffset + ( index - 1 ) * ( config.choiceHeight + config.choiceGap )

		choice.background = display.newRoundedRect( choice, 0, 0, config.width - config.padding * 2, config.choiceHeight, config.choiceCornerRadius )
		display.newText( choice, row[2], 0, 0, params.font.heading, config.choiceSize )

		choice.index = index
		choice.target = row[3]
		choice:addEventListener( "touch", onChoiceTouch )
		choices[index] = choice
	end

	-- Runs commands up to the next line of text and shows it with the links right after it as choices; closes when the passage ends.
	local function showNext()
		clearChoices()

		while rows[rowIndex] do
			local row = rows[rowIndex]
			rowIndex = rowIndex + 1

			if row[1] == "text" then
				body.text = row[2]

				while rows[rowIndex] and rows[rowIndex][1] == "link" do
					addChoice( rows[rowIndex] )
					rowIndex = rowIndex + 1
				end

				if #choices > 0 then
					highlight( 1 )
				end

				return

			elseif params.commands[row[1]] then
				params.commands[row[1]]( row )

			else
				print( "dialogueBox: no handler for the <<" .. tostring( row[1] ) .. ">> command." )
			end
		end

		box:close()
	end

	local function play( passage )
		rows = weaver.getNode( passage, params.storyName )
		if not rows then
			error( "dialogueBox: passage \"" .. tostring( passage ) .. "\" could not be read from " .. params.storyName .. "." )
		end

		rowIndex = 1
		showNext()
	end

	local function onSensorTouch( event )
		if not box.isVisible then
			return false
		end

		if event.phase == "began" and #choices == 0 then
			showNext()
		end

		return true
	end

	sensor:addEventListener( "touch", onSensorTouch )

	-- Idea: show the speaker's portrait beside the text, like the visual novel template does.
	function box:open( passage, speakerName )
		speaker.text = speakerName
		self.isVisible = true
		play( passage )
	end

	function box:isOpen()
		return self.isVisible
	end

	local function moveSelection( step )
		if #choices > 0 then
			highlight( ( selected - 1 + step ) % #choices + 1 )
		end
	end

	-- Picks the highlighted choice, or shows the next line when there is nothing to choose.
	local function confirm()
		if #choices > 0 then
			box:choose( selected )
		else
			showNext()
		end
	end

	function box:choose( index )
		play( choices[index].target )
	end

	-- Takes this frame's dialogue key presses from the input controls.
	function box:handleInput( controls )
		if controls:takePress( "choiceUp" ) then
			moveSelection( -1 )

		elseif controls:takePress( "choiceDown" ) then
			moveSelection( 1 )

		elseif controls:takePress( "confirm" ) then
			confirm()
		end
	end

	function box:close()
		clearChoices()
		rows = {}
		self.isVisible = false
	end

	-- Call on resize: the box keeps to the actual bottom edge.
	function box:position()
		self.x = display.contentCenterX
		self.y = display.screenOriginY + display.actualContentHeight - config.bottomMargin - config.height * 0.5
		sensor.x, sensor.y = display.contentCenterX - self.x, display.contentCenterY - self.y
	end

	box:position()

	return box
end

return dialogueBox
