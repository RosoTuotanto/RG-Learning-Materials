-- The frame-by-frame character: a sprite sheet played one named sequence per animation.

local spriteCharacter = {}

--------------------------------------------------------------------------------------
-- Libraries, classes, scripts, configs, etc.

local animations = require( "data.animations" )

--------------------------------------------------------------------------------------
-- Private functions

-- display.newSprite takes an array of sequences, each carrying its own name.
local function buildSequences()
	local sequences = {}

	for i = 1, #animations.names do
		local name = animations.names[i]
		local source = animations.sequences[name]

		sequences[i] = {
			name = name,
			frames = source.frames,
			time = source.time,
			loopCount = source.loopCount,
		}
	end

	return sequences
end

--------------------------------------------------------------------------------------
-- Public functions

-- params: parent, x, y
function spriteCharacter.new( params )
	local sheetData = animations.sheet

	local imageSheet = graphics.newImageSheet( sheetData.file, {
		width = sheetData.width,
		height = sheetData.height,
		numFrames = sheetData.numFrames,
	})

	local sprite = display.newSprite( params.parent, imageSheet, buildSequences() )
	sprite.x = params.x
	sprite.y = params.y
	sprite.xScale = animations.scale
	sprite.yScale = animations.scale
	sprite.isVisible = false

	local character = {}

	-- Shows the character and loops the named animation from its first frame.
	function character.show( animation )
		sprite.isVisible = true
		sprite:setSequence( animation )
		sprite:play()
	end

	function character.hide()
		sprite:pause()
		sprite.isVisible = false
	end

	function character.destroy()
		display.remove( sprite )
		sprite = nil
	end

	return character
end

--------------------------------------------------------------------------------------

return spriteCharacter
