local uiHelpers = {}

--------------------------------------------------------------------------------------
-- Public functions

-- Touch listener for panels, so a click on them never reaches the story underneath.
function uiHelpers.blockTouch()
	return true
end

-- Runs build with the nearest texture filter, so the pixel art it loads stays sharp.
function uiHelpers.withPixelFilter( build )
	display.setDefault( "magTextureFilter", "nearest" )
	display.setDefault( "minTextureFilter", "nearest" )

	build()

	display.setDefault( "magTextureFilter", "linear" )
	display.setDefault( "minTextureFilter", "linear" )
end

-- Writes a change as "+20" or "-10" in the gain or loss colour; a zero change leaves the text empty.
function uiHelpers.setChangeText( textObject, amount, colours )
	if amount == 0 then
		textObject.text = ""
		return
	end

	textObject.text = string.format( "%+d", amount )
	textObject:setFillColor( unpack( amount > 0 and colours.gainColour or colours.lossColour ) )
end

return uiHelpers
