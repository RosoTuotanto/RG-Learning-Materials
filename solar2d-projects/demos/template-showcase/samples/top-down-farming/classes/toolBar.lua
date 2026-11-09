-- A row of tool slots; the selected slot gets a highlighted border, and touching a slot picks it.

local toolBar = {}

--------------------------------------------------------------------------------------
-- Public functions

-- params: parent, tools (settings.tools), style (settings.toolBar), colors, font, onSelect( index ).
-- Create it while the nearest texture filter is set, so the pixel art icons stay sharp.
function toolBar.new( params )
	local style = params.style
	local colors = params.colors
	local tools = params.tools

	local bar = display.newGroup()
	params.parent:insert( bar )

	bar.x = display.contentCenterX
	bar.y = style.y

	local step = style.slotSize + style.gap
	local firstX = -( #tools - 1 ) * step * 0.5
	local halfSlot = style.slotSize * 0.5

	local borders = {}

	for i = 1, #tools do
		local slot = display.newGroup()
		bar:insert( slot )
		slot.x = firstX + ( i - 1 ) * step

		local border = display.newRoundedRect( slot, 0, 0, style.slotSize, style.slotSize, style.cornerRadius )
		border:setFillColor( unpack( colors.buttonFill ) )
		borders[i] = border

		display.newImageRect( slot, tools[i].image, style.iconSize, style.iconSize )

		local number = display.newText({
			parent = slot,
			text = tostring( i ),
			x = -halfSlot + style.numberInset,
			y = -halfSlot + style.numberInset,
			font = params.font,
			fontSize = style.numberSize,
		})
		number:setFillColor( unpack( colors.textMuted ) )

		slot:addEventListener( "touch", function( event )
			if event.phase == "began" then
				params.onSelect( i )
			end

			return true
		end )
	end

	function bar:select( index )
		for i = 1, #borders do
			local isSelected = i == index

			borders[i]:setStrokeColor( unpack( isSelected and colors.selected or colors.buttonBorder ) )
			borders[i].strokeWidth = isSelected and style.selectedStrokeWidth or style.strokeWidth
		end
	end

	return bar
end

return toolBar
