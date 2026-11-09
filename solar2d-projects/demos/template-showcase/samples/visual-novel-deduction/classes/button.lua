local button = {}

--------------------------------------------------------------------------------------
-- Private functions

local function onTouch( event )
	if event.phase == "began" then
		event.target.onPress( event.target )
	end
	return true
end

--------------------------------------------------------------------------------------
-- Public functions

-- params: parent, x, y, width, height, style ( colour, cornerRadius, fontSize ), label, font, onPress( button ).
function button.new( params )
	local group = display.newGroup()
	params.parent:insert( group )
	group.x = params.x
	group.y = params.y

	local box = display.newRoundedRect( group, 0, 0, params.width, params.height, params.style.cornerRadius )
	box:setFillColor( unpack( params.style.colour ) )
	display.newText( group, params.label, 0, 0, params.font, params.style.fontSize )

	group.onPress = params.onPress
	group:addEventListener( "touch", onTouch )
	return group
end

return button
