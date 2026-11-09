-- Draws the farm's plots: soil once tilled, darker while watered, and the crop image for its stage.

local fieldView = {}

--------------------------------------------------------------------------------------
-- Localised functions

local huge = math.huge
local max = math.max
local min = math.min

--------------------------------------------------------------------------------------
-- Private functions

-- Outlines the rectangle the field's tiles cover, so the tillable area reads before anything is tilled.
local function newEdge( parent, farm, grid, config, color )
	local left, top, right, bottom = huge, huge, -huge, -huge

	farm:eachPlot( function( _, column, row )
		left = min( left, column )
		top = min( top, row )
		right = max( right, column )
		bottom = max( bottom, row )
	end )

	local size = grid.tileSize
	local width = ( right - left + 1 ) * size
	local height = ( bottom - top + 1 ) * size

	local edge = display.newRect( parent, ( left - 1 ) * size + width * 0.5, ( top - 1 ) * size + height * 0.5, width, height )
	edge:setFillColor( 0, 0 )
	edge:setStrokeColor( unpack( color ) )
	edge.strokeWidth = config.edgeWidth
end

--------------------------------------------------------------------------------------
-- Public functions

-- params: parent, farm (classes/field), grid (classes/mapGrid), config (settings.field), colors (settings.colors).
-- Create it while the nearest texture filter is set: every crop image is made up front, since a texture loaded later would be smoothed.
function fieldView.new( params )
	local farm = params.farm
	local grid = params.grid
	local config = params.config
	local colors = params.colors

	local view = display.newGroup()
	params.parent:insert( view )

	newEdge( view, farm, grid, config, colors.fieldEdge )

	local size = grid.tileSize
	local images = {}

	farm:eachPlot( function( plot, column, row )
		local x, y = grid:tileToWorld( column, row )

		local soil = display.newImageRect( view, config.soilImage, size, size )
		soil.x, soil.y = x, y

		local crops = {}
		for stage = 1, #config.cropImages do
			crops[stage] = display.newImageRect( view, config.cropImages[stage], size, size )
			crops[stage].x, crops[stage].y = x, y
		end

		images[plot] = { soil = soil, crops = crops }
	end )

	function view:refreshPlot( plot )
		local plotImages = images[plot]

		plotImages.soil.isVisible = plot.state ~= "grass"

		if plot.watered then
			plotImages.soil:setFillColor( unpack( colors.wateredSoil ) )
		else
			plotImages.soil:setFillColor( 1 )
		end

		for stage = 1, #plotImages.crops do
			plotImages.crops[stage].isVisible = plot.state == "planted" and plot.stage == stage
		end
	end

	function view:refreshAll()
		farm:eachPlot( function( plot )
			self:refreshPlot( plot )
		end )
	end

	view:refreshAll()

	return view
end

return fieldView
