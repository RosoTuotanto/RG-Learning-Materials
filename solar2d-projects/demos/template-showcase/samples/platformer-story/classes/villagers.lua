local villagers = {}

--------------------------------------------------------------------------------------
-- Private functions

local function newVillager( params, info, spot )
	local config = params.config

	local person = display.newImageRect( params.parent, info.image, params.size, params.size )
	person.x, person.y = spot.x, spot.y
	person.info = info

	-- direction 1 faces right, -1 left, whichever way the art itself faces.
	function person:face( direction )
		self.xScale = direction * info.artFacing
	end

	person:face( info.direction )

	local prompt = display.newGroup()
	params.parent:insert( prompt )
	prompt.x = person.x
	prompt.y = person.y - params.size * 0.5 - config.promptOffset
	prompt.isVisible = false
	person.prompt = prompt

	local label = display.newText( prompt, params.promptText, 0, 0, params.font, config.promptSize )
	local backing = display.newRoundedRect( prompt, 0, 0, label.width + config.promptPaddingX * 2, config.promptHeight, config.promptCornerRadius )
	backing:setFillColor( unpack( params.colors.prompt ) )
	label:toFront()

	return person
end

--------------------------------------------------------------------------------------
-- Public functions

-- params: parent, map, size, list (settings.villagers), config (settings.talk), colors, font and promptText.
function villagers.new( params )
	local config = params.config
	local crowd = {}

	for i = 1, #params.list do
		local info = params.list[i]
		local spot = params.map:findObject( info.name, "villager" )
		crowd[i] = newVillager( params, info, spot )
	end

	-- Turns everyone back to their own direction after a talk and shows the Talk prompt over the first villager in reach, which it returns.
	function crowd:update( hero )
		local nearby = nil

		for i = 1, #self do
			local person = self[i]
			person:face( person.info.direction )

			local isInReach = math.abs( hero.x - person.x ) <= config.reachX and math.abs( hero.y - person.y ) <= config.reachY
			if not nearby and isInReach then
				nearby = person
			end

			person.prompt.isVisible = person == nearby
		end

		return nearby
	end

	return crowd
end

return villagers
