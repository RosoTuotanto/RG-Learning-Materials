local pixelFilter = {}

--------------------------------------------------------------------------------------
-- Public functions

-- Textures loaded between begin and finish keep hard pixel edges when scaled.
function pixelFilter.begin()
	display.setDefault( "magTextureFilter", "nearest" )
	display.setDefault( "minTextureFilter", "nearest" )
end

function pixelFilter.finish()
	display.setDefault( "magTextureFilter", "linear" )
	display.setDefault( "minTextureFilter", "linear" )
end

return pixelFilter
