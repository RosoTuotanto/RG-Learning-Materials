-- The hour of the day, its band, and the clock text that shows them.

local dayClock = {}

--------------------------------------------------------------------------------------
-- Forward declarations & variables

local clockMethods = {}

--------------------------------------------------------------------------------------
-- Public functions

function clockMethods:getBand()
	local bands = self.time.bands
	local band = bands[1]

	for i = 2, #bands do
		if self.hour >= bands[i].from then
			band = bands[i]
		end
	end
	return band
end

function clockMethods:refresh()
	self.text.text = string.format( self.layout.format, self.hour, self:getBand().label )
end

function clockMethods:reset()
	self.hour = self.time.startHour
	self:refresh()
end

-- A trip or a conversation that would run past the end of the day stops at the end hour.
function clockMethods:advance( hours )
	self.hour = math.min( self.hour + hours, self.time.endHour )
	self:refresh()
end

function clockMethods:isOver()
	return self.hour >= self.time.endHour
end

-- Centred across the window's top edge, in the strip above the map.
function clockMethods:position()
	self.text.x = display.screenOriginX + display.actualContentWidth * 0.5
	self.text.y = display.screenOriginY + self.layout.y
end

-- params: parent, time (settings.time), layout (settings.clock), font.
function dayClock.new( params )
	local layout = params.layout

	local clock = setmetatable( {
		time = params.time,
		layout = layout,
		hour = params.time.startHour,
	}, { __index = clockMethods } )

	clock.text = display.newText( params.parent, "", 0, 0, params.font, layout.fontSize )
	clock.text:setFillColor( unpack( layout.colour ) )

	clock:refresh()
	clock:position()
	return clock
end

return dayClock
