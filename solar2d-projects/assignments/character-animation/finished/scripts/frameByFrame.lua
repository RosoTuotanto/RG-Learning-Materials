local character = {}

-- Seisova hahmo on yksi 128x128 kuva ja juoksu kahdeksan 128x128 framea rivissä.
local idleSheet = graphics.newImageSheet( "assets/images/idle.png", {
	width = 128,
	height = 128,
	numFrames = 1
} )

local runSheet = graphics.newImageSheet( "assets/images/run-sheet.png", {
	width = 128,
	height = 128,
	numFrames = 8
} )

-- Kumpikin animaatio kertoo, mistä kuvasta sen framet otetaan.
local animations = {
	{
		name = "idle",
		sheet = idleSheet,
		start = 1,
		count = 1
	},
	{
		name = "run",
		sheet = runSheet,
		start = 1,
		count = 8,
		-- 8 framea, 70 millisekuntia kukin.
		time = 560
	}
}

-- Luodaan hahmo annettuun kohtaan.
function character.new( x, y )
	local player = display.newSprite( idleSheet, animations )
	player.x = x
	player.y = y

	player:setSequence( "idle" )
	player:play()

	return player
end

-- Vaihdetaan hahmo juoksemaan.
function character.run( player )
	player:setSequence( "run" )
	player:play()
end

-- Vaihdetaan hahmo seisomaan.
function character.stand( player )
	player:setSequence( "idle" )
	player:play()
end

return character
