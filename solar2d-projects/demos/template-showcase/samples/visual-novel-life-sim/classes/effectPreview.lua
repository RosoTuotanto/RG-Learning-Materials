-- Shows on an option button what its target passage's <<stat>> and <<relation>> rows will change, read from the story file itself.

local effectPreview = {}

--------------------------------------------------------------------------------------
-- Libraries, classes, scripts, configs, etc.

local json = require( "json" )
local uiHelpers = require( "samples.visual-novel-life-sim.classes.uiHelpers" )

--------------------------------------------------------------------------------------
-- Forward declarations & variables

-- Commands after which the rest of a passage never runs: Weaver's own jump and this sample's handlers that call jumpTo.
local leavingCommands = { jump = true, endAction = true, nextDay = true }

--------------------------------------------------------------------------------------
-- Private functions

local function trim( text )
	return ( string.match( text, "^%s*(.-)%s*$" ) )
end

-- Splits a command row the way Weaver does: the words between commas, without surrounding spaces.
local function splitCommand( command )
	local parts = {}

	for part in string.gmatch( command, "[^,]+" ) do
		parts[#parts + 1] = trim( part )
	end
	return parts
end

-- Lists a passage's stat and relation changes in story order, or returns nil when it has none.
local function readPassage( passage, knownIds )
	local effects
	local hasCondition = false
	local hasLeft = false

	for line in string.gmatch( passage.body .. "\n", "(.-)\n" ) do
		local command = string.match( line, "^%s*<<(.-)>>" )

		if command then
			local parts = splitCommand( command )
			local kind = parts[1] or ""

			-- The same whole-word test Weaver uses, so <<if($x)>> counts too.
			if string.find( kind, "^if%f[^%w_]" ) then
				hasCondition = true

			elseif leavingCommands[kind] then
				hasLeft = true

			elseif knownIds[kind] then
				local id = parts[2]
				local amount = tonumber( parts[3] )

				if not knownIds[kind][id] or not amount then
					error( "effectPreview: \"" .. passage.title .. "\" has an unreadable row <<" .. command .. ">>." )
				end

				-- Rows after the passage is left run later or never, so no preview could promise them.
				if hasLeft then
					error( "effectPreview: \"" .. passage.title .. "\" changes stats after leaving the passage, which a preview cannot show." )
				end

				effects = effects or {}
				effects[#effects + 1] = { kind = kind, id = id, amount = amount }
			end
		end
	end

	-- A change inside <<if>> may or may not happen, so no preview could promise it.
	if effects and hasCondition then
		error( "effectPreview: \"" .. passage.title .. "\" changes stats inside <<if>>, which a preview cannot show." )
	end
	return effects
end

--------------------------------------------------------------------------------------
-- Public functions

-- Returns { [passageName] = { { kind = "stat" or "relation", id, amount }, ... } } for every passage that changes something.
function effectPreview.readStory( source, stats, relationships )
	local knownIds = { stat = {}, relation = {} }

	for i = 1, #stats do
		knownIds.stat[stats[i].id] = true
	end

	for i = 1, #relationships do
		knownIds.relation[relationships[i].id] = true
	end

	local path = system.pathForFile( source, system.ResourceDirectory )
	local file = path and io.open( path, "r" )
	if not file then
		error( "effectPreview: \"" .. source .. "\" could not be read." )
	end

	local passages = json.decode( file:read( "*a" ) )
	file:close()

	local effectsByPassage = {}
	for i = 1, #passages do
		effectsByPassage[passages[i].title] = readPassage( passages[i], knownIds )
	end
	return effectsByPassage
end

-- What the rows would change from the current values, applied one by one with the same limits as the handlers.
local function projectChanges( effects, current, ranges )
	local values = {
		stat = setmetatable( {}, { __index = current.stat } ),
		relation = setmetatable( {}, { __index = current.relation } ),
	}

	for i = 1, #effects do
		local effect = effects[i]
		local range = ranges[effect.kind]
		values[effect.kind][effect.id] = math.min( math.max( values[effect.kind][effect.id] + effect.amount, range.min ), range.max )
	end

	local changes = { stat = {}, relation = {} }
	for kind, changed in pairs( values ) do
		for id, value in pairs( changed ) do
			changes[kind][id] = value - current[kind][id]
		end
	end
	return changes
end

-- params: layout (settings.effectPreview), stats, relationships, ranges ( stat, relation ), imageFolder, font.
-- current holds the values the changes start from ( stat = { [id] = value }, relation = { [id] = value } ).
-- Calling it again replaces the earlier preview; nothing is drawn when no value would change.
function effectPreview.attach( button, effects, current, params )
	display.remove( button.previewRow )
	button.previewRow = nil
	button.label.y = 0

	if not effects then
		return
	end

	local layout = params.layout
	local changes = projectChanges( effects, current, params.ranges )
	local items = {}

	for i = 1, #params.stats do
		local stat = params.stats[i]
		local amount = changes.stat[stat.id] or 0

		if amount ~= 0 then
			items[#items + 1] = { icon = stat.icon, amount = amount }
		end
	end

	for i = 1, #params.relationships do
		local relationship = params.relationships[i]
		local amount = changes.relation[relationship.id] or 0

		if amount ~= 0 then
			items[#items + 1] = { name = relationship.shortName, amount = amount }
		end
	end

	if #items == 0 then
		return
	end

	local row = display.newGroup()
	button:insert( row )
	button.previewRow = row
	row.y = layout.rowOffset
	button.label.y = layout.labelOffset

	local x = 0
	for i = 1, #items do
		local item = items[i]

		if item.icon then
			uiHelpers.withPixelFilter( function()
				local icon = display.newImageRect( row, params.imageFolder .. item.icon, layout.iconSize, layout.iconSize )
				icon.x = x + layout.iconSize * 0.5
			end )
			x = x + layout.iconSize + layout.iconGap

		else
			local name = display.newText( row, item.name, x, 0, params.font, layout.fontSize )
			name.anchorX = 0
			x = x + name.width + layout.iconGap
		end

		local amount = display.newText( row, "", x, 0, params.font, layout.fontSize )
		amount.anchorX = 0
		uiHelpers.setChangeText( amount, item.amount, layout )
		x = x + amount.width + layout.itemGap
	end

	row.x = -( x - layout.itemGap ) * 0.5
end

return effectPreview
