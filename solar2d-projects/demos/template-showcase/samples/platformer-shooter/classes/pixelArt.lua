local pixelArt = {}

--------------------------------------------------------------------------------------
-- Public functions

-- A texture keeps the filter it was loaded with, so pixel art is created with nearest filtering on and switched back after.
function pixelArt.setFilter( isOn )
	local filter = isOn and "nearest" or "linear"

	display.setDefault( "magTextureFilter", filter )
	display.setDefault( "minTextureFilter", filter )
end

-- Frames come out at displaySize content units, whatever the pixel size of the image.
function pixelArt.newSheet( config )
	local size = config.displaySize

	pixelArt.setFilter( true )

	local sheet = graphics.newImageSheet( config.path, {
		width = size,
		height = size,
		numFrames = config.columns * config.rows,
		sheetContentWidth = config.columns * size,
		sheetContentHeight = config.rows * size,
	} )

	pixelArt.setFilter( false )

	return sheet
end

return pixelArt
