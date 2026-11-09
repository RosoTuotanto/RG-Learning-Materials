-- Suspect and clue cards on the corkboard, and the red strings that link a clue to a suspect.

local deductionBoard = {}

--------------------------------------------------------------------------------------
-- Forward declarations & variables

local boardMethods = {}

--------------------------------------------------------------------------------------
-- Private functions

-- Runs build with the nearest texture filter, so the pixel art it loads stays sharp.
local function withPixelFilter( build )
	display.setDefault( "magTextureFilter", "nearest" )
	display.setDefault( "minTextureFilter", "nearest" )

	build()

	display.setDefault( "magTextureFilter", "linear" )
	display.setDefault( "minTextureFilter", "linear" )
end

local function newString( board, x1, y1, x2, y2 )
	local layout = board.layout
	local line = display.newLine( board.stringLayer, x1, y1, x2, y2 )
	line.strokeWidth = layout.stringWidth
	line:setStrokeColor( unpack( layout.stringColour ) )
	return line
end

-- A nil suspectCard removes the clue's link.
local function setLink( board, clueCard, suspectCard )
	display.remove( clueCard.string )
	clueCard.string = nil
	board.links[clueCard.id] = nil

	if suspectCard then
		board.links[clueCard.id] = suspectCard.id
		clueCard.string = newString( board, clueCard.pinX, clueCard.pinY, suspectCard.pinX, suspectCard.pinY )
	end

	board.onChange( board )
end

local function suspectAt( board, x, y )
	for i = 1, #board.suspectCards do
		local card = board.suspectCards[i]
		local bounds = card.contentBounds

		if x >= bounds.xMin and x <= bounds.xMax and y >= bounds.yMin and y <= bounds.yMax then
			return card
		end
	end
	return nil
end

local function drawDragString( board, event )
	local card = board.dragCard
	local x, y = board.group:contentToLocal( event.x, event.y )

	display.remove( board.dragString )
	board.dragString = newString( board, card.pinX, card.pinY, x, y )
end

-- Pressing a clue picks up its string; releasing over a suspect pins it there, anywhere else drops it.
local function onClueTouch( event )
	local card = event.target
	local board = card.board
	local phase = event.phase

	if phase == "began" then
		if not board.isLinking then
			return false
		end

		display.getCurrentStage():setFocus( card )
		board.dragCard = card
		setLink( board, card, nil )
		drawDragString( board, event )

	elseif board.dragCard ~= card then
		return false

	elseif phase == "moved" then
		drawDragString( board, event )

	else
		local suspectCard = phase == "ended" and suspectAt( board, event.x, event.y )
		board:cancelDrag()

		if suspectCard then
			setLink( board, card, suspectCard )
		end
	end
	return true
end

-- Paper, shadow, name and pin shared by both kinds of card.
local function newCard( board, item, cardLayout )
	local layout = board.layout
	local card = display.newGroup()
	board.cardLayer:insert( card )
	card.x = item.x
	card.y = item.y
	card.id = item.id

	local shadow = display.newRect( card, layout.shadowOffset, layout.shadowOffset, cardLayout.width, cardLayout.height )
	shadow:setFillColor( unpack( layout.shadowColour ) )

	local paper = display.newRect( card, 0, 0, cardLayout.width, cardLayout.height )
	paper:setFillColor( unpack( layout.paperColour ) )

	local name = display.newText( card, item.name, 0, cardLayout.nameY, layout.font, cardLayout.nameSize )
	name:setFillColor( unpack( layout.inkColour ) )

	card.pinX = item.x
	card.pinY = item.y + cardLayout.pinY

	local pin = display.newCircle( board.pinLayer, card.pinX, card.pinY, layout.pinRadius )
	pin:setFillColor( unpack( layout.pinColour ) )
	return card
end

local function newSuspectCard( board, suspect )
	local layout = board.layout
	local cardLayout = layout.suspectCard
	local card = newCard( board, suspect, cardLayout )

	withPixelFilter( function()
		-- One image sheet frame cuts the head and shoulders out of the full portrait.
		local sheet = graphics.newImageSheet( layout.imageFolder .. suspect.id .. ".png", { frames = { layout.crop } } )
		local photo = display.newImageRect( card, sheet, 1, cardLayout.photoSize, cardLayout.photoSize )
		photo.y = cardLayout.photoY
	end )

	-- Idea: give each suspect a motive and an opportunity slot, and check what is pinned to each in accusation.judge.
	return card
end

local function newClueCard( board, clue )
	local layout = board.layout
	local card = newCard( board, clue, layout.clueCard )

	withPixelFilter( function()
		local sprite = display.newImageRect( card, layout.imageFolder .. clue.id .. ".png", clue.width, clue.height )
		sprite.y = layout.clueCard.spriteY
	end )

	card.board = board
	card:addEventListener( "touch", onClueTouch )
	return card
end

--------------------------------------------------------------------------------------
-- Public functions

function boardMethods:open()
	self.group.isVisible = true
	self.isLinking = true
	self.onChange( self )
end

-- Drops a string being dragged and releases the touch focus.
function boardMethods:cancelDrag()
	if self.dragCard then
		display.getCurrentStage():setFocus( nil )
		self.dragCard = nil
	end

	display.remove( self.dragString )
	self.dragString = nil
end

-- The board stays on screen behind the verdict but takes no more links.
function boardMethods:stopLinking()
	self:cancelDrag()
	self.isLinking = false
end

-- Returns the suspect id linked to each clue id.
function boardMethods:getLinks()
	return self.links
end

-- Returns the number of linked clues and the number of clues.
function boardMethods:getLinkCount()
	local count = 0

	for _ in pairs( self.links ) do
		count = count + 1
	end
	return count, #self.clueCards
end

-- Removes every string and hides the board.
function boardMethods:reset()
	self:stopLinking()

	for i = 1, #self.clueCards do
		local card = self.clueCards[i]
		display.remove( card.string )
		card.string = nil
	end

	self.links = {}
	self.group.isVisible = false
end

-- params: parent, layout (settings.board), onChange( board ). The board goes to the bottom of parent.
function deductionBoard.new( params )
	local layout = params.layout

	local board = setmetatable( {
		layout = layout,
		onChange = params.onChange,
		suspectCards = {},
		clueCards = {},
		links = {},
		isLinking = false,
	}, { __index = boardMethods } )

	board.group = display.newGroup()
	params.parent:insert( 1, board.group )

	board.cardLayer = display.newGroup()
	board.stringLayer = display.newGroup()
	board.pinLayer = display.newGroup()
	board.group:insert( board.cardLayer )
	board.group:insert( board.stringLayer )
	board.group:insert( board.pinLayer )

	for i = 1, #layout.suspects do
		board.suspectCards[i] = newSuspectCard( board, layout.suspects[i] )
	end

	for i = 1, #layout.clues do
		board.clueCards[i] = newClueCard( board, layout.clues[i] )
	end

	board.group.isVisible = false
	return board
end

return deductionBoard
