-- A drawbridge over the river that stands raised until the story lowers it.

local bridge = {}

--------------------------------------------------------------------------------------
-- Libraries, classes, scripts, configs, etc.

local physics = require( "physics" )

--------------------------------------------------------------------------------------
-- Public functions

-- params: parent, area (the map's centred bridge rect, one tile high), size, tag and config (settings.bridge).
function bridge.new( params )
	local config = params.config
	local area = params.area
	local size = params.size

	-- The deck turns around the top corner it shares with the far bank.
	local deck = display.newGroup()
	params.parent:insert( deck )
	deck.x = area.x + area.width * 0.5
	deck.y = area.y - area.height * 0.5
	deck.rotation = config.raisedRotation

	local plankCount = math.floor( area.width / size + 0.5 )
	for i = 1, plankCount do
		local plank = display.newImageRect( deck, config.image, size, size )
		plank.x = ( i - 0.5 ) * size - area.width
		plank.y = size * 0.5
	end

	-- Bodies cannot go on a rotating group, so one plain rectangle carries the lowered deck.
	local function addBody()
		local walkway = display.newRect( params.parent, area.x, area.y, area.width, area.height )
		walkway.isVisible = false
		walkway.isGround = true
		physics.addBody( walkway, "static", config.surface )
	end

	function deck:lower()
		transition.to( self, {
			rotation = 0,
			time = config.lowerTime,
			transition = easing[config.easing],
			tag = params.tag,
			onComplete = addBody,
		} )
	end

	return deck
end

return bridge
