-- Farm rules on plain tables: each field tile is a plot with a state, a growth stage and a watered flag.

local field = {}

--------------------------------------------------------------------------------------
-- Private functions

local function tileKey( column, row )
	return column .. "," .. row
end

--------------------------------------------------------------------------------------
-- Public functions

-- tiles lists the field's tiles as tables with column and row; stageCount is the growth stage a crop ripens at.
function field.new( tiles, stageCount )
	local farm = {
		day = 1,
		harvestCount = 0,
	}

	-- state is "grass", "tilled" or "planted"; stage counts up from 1 while planted.
	local plots = {}
	for i = 1, #tiles do
		plots[tileKey( tiles[i].column, tiles[i].row )] = { state = "grass", stage = 0, watered = false }
	end

	-- Returns the plot at the tile, or nil when the tile is not part of the field.
	function farm:getPlot( column, row )
		return plots[tileKey( column, row )]
	end

	-- Calls onPlot( plot, column, row ) for every plot.
	function farm:eachPlot( onPlot )
		for i = 1, #tiles do
			onPlot( self:getPlot( tiles[i].column, tiles[i].row ), tiles[i].column, tiles[i].row )
		end
	end

	-- Uses a tool on a tile; returns what happened ("till", "plant", "water" or "harvest"), or nil if nothing did.
	function farm:useTool( tool, column, row )
		local plot = self:getPlot( column, row )
		if not plot then
			return nil
		end

		if tool == "hoe" and plot.state == "grass" then
			plot.state = "tilled"

			return "till"

		elseif tool == "seeds" and plot.state == "tilled" then
			plot.state = "planted"
			plot.stage = 1

			return "plant"

		elseif tool == "water" and plot.state == "planted" and plot.stage < stageCount and not plot.watered then
			plot.watered = true

			return "water"

		elseif tool == "hand" and plot.state == "planted" and plot.stage == stageCount then
			plot.state = "tilled"
			plot.stage = 0
			plot.watered = false
			self.harvestCount = self.harvestCount + 1

			-- Idea: sell the harvest in a shop that buys crops and sells new seeds.
			return "harvest"
		end

		return nil
	end

	-- Sleeping ends the day: every watered crop grows one stage, then every plot dries.
	function farm:advanceDay()
		self.day = self.day + 1

		-- Idea: add seasons that change which crops grow, or crops that need more days.
		self:eachPlot( function( plot )
			if plot.watered then
				plot.stage = plot.stage + 1
			end

			plot.watered = false
		end )
	end

	return farm
end

return field
