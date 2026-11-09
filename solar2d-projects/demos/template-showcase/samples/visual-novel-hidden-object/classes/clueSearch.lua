-- The clues hidden in the office, the office pieces drawn over them, and the strip that collects the found ones.

local clueSearch = {}

--------------------------------------------------------------------------------------
-- Forward declarations & variables

local searchMethods = {}

--------------------------------------------------------------------------------------
-- Private functions

local function slotX( strip, index, count )
	return strip.panel.x + ( index - ( count + 1 ) * 0.5 ) * strip.slotSpacing
end

local function onLanded( sprite )
	local search = sprite.search
	search.onFound( sprite.clue )
end

local function onHitTouch( event )
	local hitArea = event.target
	local search = hitArea.search

	-- While a passage plays, the touch falls through to the story player.
	if event.phase ~= "began" or not search.isActive then
		return false
	end

	local sprite = hitArea.sprite
	search.isActive = false
	search.foundCount = search.foundCount + 1
	hitArea.isHitTestable = false

	-- The strip sits above the covers, so the clue leaves its hiding place in front of them.
	search.stripGroup:insert( sprite )
	transition.to( sprite, {
		x = slotX( search.strip, search.foundCount, #search.hitAreas ),
		y = search.strip.panel.y,
		time = search.layout.flightTime,
		transition = easing.outQuad,
		tag = search.layout.transitionTag,
		onComplete = onLanded,
	})
	return true
end

-- Keeps clicks on the strip from reaching the clues and the story underneath.
local function blockTouch()
	return true
end

local function newStrip( search, parent )
	local strip = search.strip
	local panel = strip.panel
	local group = display.newGroup()
	parent:insert( group )

	local box = display.newRoundedRect( group, panel.x, panel.y, panel.width, panel.height, panel.cornerRadius )
	box:setFillColor( unpack( strip.colour ) )
	box:addEventListener( "touch", blockTouch )

	local count = #search.layout.clues

	for i = 1, count do
		local slot = display.newRoundedRect( group, slotX( strip, i, count ), panel.y, strip.slotWidth, strip.slotHeight, strip.slotCornerRadius )
		slot:setFillColor( unpack( strip.slotColour ) )
	end

	return group
end

--------------------------------------------------------------------------------------
-- Public functions

-- Puts every clue back in its hiding place with the strip hidden and clicks ignored.
function searchMethods:reset()
	for i = 1, #self.hitAreas do
		local hitArea = self.hitAreas[i]
		local sprite = hitArea.sprite

		self.spriteLayer:insert( sprite )
		sprite.x = sprite.homeX
		sprite.y = sprite.homeY
		hitArea.isHitTestable = true
	end

	self.foundCount = 0
	self.isActive = false
	self.stripGroup.isVisible = false
end

-- An active search takes clicks on the clues and shows the strip in place of the text box.
function searchMethods:setActive( isActive )
	self.isActive = isActive
	self.stripGroup.isVisible = isActive
end

function searchMethods:isComplete()
	return self.foundCount == #self.hitAreas
end

-- params: parent, roomParent, layout (settings.search), strip (settings.strip), background (settings.player.background), onFound( clue ).
-- Clues and covers go to the bottom of roomParent; hit areas and the strip go to parent.
function clueSearch.new( params )
	local layout = params.layout
	local background = params.background
	local scale = layout.exportScale
	local left = background.x - background.width * 0.5
	local top = background.y - background.height * 0.5
	local stripTop = params.strip.panel.y - params.strip.panel.height * 0.5

	local search = setmetatable( {
		layout = layout,
		strip = params.strip,
		onFound = params.onFound,
		hitAreas = {},
		foundCount = 0,
		isActive = false,
	}, { __index = searchMethods } )

	search.group = display.newGroup()
	params.parent:insert( search.group )

	local room = display.newGroup()
	params.roomParent:insert( 1, room )

	search.spriteLayer = display.newGroup()
	room:insert( search.spriteLayer )

	display.setDefault( "magTextureFilter", "nearest" )
	display.setDefault( "minTextureFilter", "nearest" )

	local frames = {}

	for i = 1, #layout.covers do
		local cover = layout.covers[i]
		frames[i] = { x = cover.x * scale, y = cover.y * scale, width = cover.width * scale, height = cover.height * scale }
	end

	-- Covers are cut from the office image itself, so a hidden clue sits behind the furniture without editing any art.
	local officeSheet = graphics.newImageSheet( layout.office, { frames = frames } )

	for i = 1, #frames do
		local frame = frames[i]
		local cover = display.newImageRect( room, officeSheet, i, frame.width, frame.height )
		cover.anchorX = 0
		cover.anchorY = 0
		cover.x = left + frame.x
		cover.y = top + frame.y
	end

	for i = 1, #layout.clues do
		local clue = layout.clues[i]
		local sprite = display.newImageRect( search.spriteLayer, layout.clueFolder .. clue.id .. ".png", clue.width, clue.height )
		sprite.homeX = left + clue.x * scale + clue.width * 0.5
		sprite.homeY = top + clue.y * scale + clue.height * 0.5
		sprite.clue = clue
		sprite.search = search

		local padding = layout.hitPadding
		local hitTop = sprite.homeY - clue.height * 0.5 - padding
		local hitBottom = math.min( sprite.homeY + clue.height * 0.5 + padding, stripTop )
		local hitArea = display.newRect( search.group, sprite.homeX, ( hitTop + hitBottom ) * 0.5, clue.width + padding * 2, hitBottom - hitTop )
		hitArea.isVisible = false
		hitArea.sprite = sprite
		hitArea.search = search
		hitArea:addEventListener( "touch", onHitTouch )
		search.hitAreas[i] = hitArea
	end

	display.setDefault( "magTextureFilter", "linear" )
	display.setDefault( "minTextureFilter", "linear" )

	search.stripGroup = newStrip( search, search.group )
	search:reset()
	return search
end

return clueSearch
