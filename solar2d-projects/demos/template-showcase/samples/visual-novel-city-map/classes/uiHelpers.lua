local uiHelpers = {}

--------------------------------------------------------------------------------------
-- Public functions

-- Runs build with the nearest texture filter, so the pixel art it loads stays sharp.
function uiHelpers.withPixelFilter( build )
	display.setDefault( "magTextureFilter", "nearest" )
	display.setDefault( "minTextureFilter", "nearest" )

	build()

	display.setDefault( "magTextureFilter", "linear" )
	display.setDefault( "minTextureFilter", "linear" )
end

return uiHelpers
