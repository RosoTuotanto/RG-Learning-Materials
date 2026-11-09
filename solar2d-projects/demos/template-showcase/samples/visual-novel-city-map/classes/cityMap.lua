-- The city map: a click target and a label for each spot, and a ring on the detective's location.

local cityMap = {}

--------------------------------------------------------------------------------------
-- Libraries, classes, scripts, configs, etc.

local uiHelpers = require( "samples.visual-novel-city-map.classes.uiHelpers" )

--------------------------------------------------------------------------------------
-- Forward declarations & variables

local mapMethods = {}

--------------------------------------------------------------------------------------
-- Private functions

-- Spots only answer while the map is open, so a click during a passage never starts a trip.
local function onSpotTouch( event )
	local target = event.target

	if event.phase == "began" and target.map.isOpen then
		target.map.onPick( target.spot )
	end
	return true
end

local function newLabel( map, spot, x, y )
	local layout = map.layout
	local offset = map.clickRadius + layout.labelGap
	local isLeft = spot.labelSide == "left"

	local label = display.newText( map.group, spot.label, 0, y, map.font, layout.labelFontSize )
	label:setFillColor( unpack( layout.labelColour ) )
	label.anchorX = isLeft and 1 or 0
	label.x = isLeft and x - offset or x + offset

	local padding = layout.labelPadding
	local centreX = isLeft and label.x - label.width * 0.5 or label.x + label.width * 0.5
	local back = display.newRoundedRect( map.group, centreX, y, label.width + padding * 2, label.height + padding, layout.labelCornerRadius )
	back:setFillColor( unpack( layout.labelBackColour ) )
	label:toFront()
end

local function newSpot( map, spot, left, top )
	local x = left + spot.x * map.scale
	local y = top + spot.y * map.scale

	local target = display.newCircle( map.group, x, y, map.clickRadius )
	target.isVisible = false
	target.isHitTestable = true
	target.map = map
	target.spot = spot
	target:addEventListener( "touch", onSpotTouch )

	newLabel( map, spot, x, y )
	map.targets[spot.id] = target
end

--------------------------------------------------------------------------------------
-- Public functions

function mapMethods:open( locationId )
	local target = self.targets[locationId]
	self.marker.x = target.x
	self.marker.y = target.y

	self.group.isVisible = true
	self.isOpen = true
end

function mapMethods:close()
	self.group.isVisible = false
	self.isOpen = false
end

-- params: parent, layout (settings.map), area (the background rectangle), font, onPick( spot ).
function cityMap.new( params )
	local layout = params.layout
	local area = params.area
	local scale = area.width / layout.pixelWidth

	local map = setmetatable( {
		layout = layout,
		font = params.font,
		onPick = params.onPick,
		scale = scale,
		clickRadius = layout.clickRadius * scale,
		targets = {},
		isOpen = false,
	}, { __index = mapMethods } )

	map.group = display.newGroup()
	params.parent:insert( map.group )

	local image

	uiHelpers.withPixelFilter( function()
		image = display.newImageRect( map.group, layout.image, area.width, area.height )
	end )

	image.x = area.x
	image.y = area.y

	map.marker = display.newCircle( map.group, 0, 0, layout.markerRadius * scale )
	map.marker:setFillColor( 0, 0 )
	map.marker.strokeWidth = layout.markerStrokeWidth
	map.marker:setStrokeColor( unpack( layout.markerColour ) )

	local left = area.x - area.width * 0.5
	local top = area.y - area.height * 0.5

	for i = 1, #layout.spots do
		newSpot( map, layout.spots[i], left, top )
	end

	map:close()
	return map
end

return cityMap
