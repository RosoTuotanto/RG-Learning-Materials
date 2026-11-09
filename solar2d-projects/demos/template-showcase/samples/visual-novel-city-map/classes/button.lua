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

function button.setSelected( target, isSelected )
	local style = target.style
	target.box:setFillColor( unpack( isSelected and style.selectedColour or style.colour ) )
end

-- params: parent, x, y, width, height, style, onPress( button ), and optionally label, font, isSelected.
function button.new( params )
	local group = display.newGroup()
	params.parent:insert( group )
	group.x = params.x
	group.y = params.y

	group.style = params.style
	group.box = display.newRoundedRect( group, 0, 0, params.width, params.height, params.style.cornerRadius )
	button.setSelected( group, params.isSelected )

	if params.label then
		group.label = display.newText( group, params.label, 0, 0, params.font, params.fontSize or params.style.fontSize )
	end

	group.onPress = params.onPress
	group:addEventListener( "touch", onTouch )
	return group
end

return button
