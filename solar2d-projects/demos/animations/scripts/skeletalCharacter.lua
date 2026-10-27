-- The skeletal character: a spriteloop package that loops each variant of the selected
-- animation a set number of times and then moves on to the next variant.

local skeletalCharacter = {}

--------------------------------------------------------------------------------------
-- Libraries, classes, scripts, configs, etc.

local spriteloop = require( "libs.spriteloop" )
local animations = require( "data.animations" )

--------------------------------------------------------------------------------------
-- Private functions

-- Every image the package can show, each path once, including the swap images the runtime
-- only loads on their first swap. Paths are built the way spriteloop builds them.
local function listPackageImages( skeletalPackage )
	local images = {}
	local isListed = {}
	local sources = { skeletalPackage.parts, skeletalPackage.variants }

	for sourceIndex = 1, #sources do
		local entries = sources[sourceIndex]

		for entryIndex = 1, #entries do
			local asset = entries[entryIndex].asset

			if asset ~= "" then
				local filename = skeletalPackage.assetBasePath .. "/" .. asset

				if not isListed[filename] then
					isListed[filename] = true
					images[#images + 1] = filename
				end
			end
		end
	end

	return images
end

-- The engine caches a loaded image by its path and keeps the filter it was loaded with, but
-- drops it once nothing uses it. Holding a texture for every image keeps each one at the
-- filter in effect now, so a later swap reuses it instead of loading it again. The engine
-- hands back one texture per file, so each path is held exactly once.
local function holdPackageImages( skeletalPackage )
	local filenames = listPackageImages( skeletalPackage )
	local textures = {}

	for i = 1, #filenames do
		local texture = graphics.newTexture({ type = "image", filename = filenames[i], baseDir = skeletalPackage.assetBaseDir })
		texture:preload()
		textures[i] = texture
	end

	return textures
end

--------------------------------------------------------------------------------------
-- Public functions

-- params: parent, x, y, state (a demoState instance), onVariantChange( variant ).
-- Call it with the pixel-art texture filter set: every image the rig uses is loaded here.
function skeletalCharacter.new( params )
	local state = params.state

	-- spriteloop caches the loaded package, so new below reuses it instead of decoding the manifest again.
	local skeletalPackage = assert( spriteloop.loadPackage( animations.skeletal.path ) )
	local textures = holdPackageImages( skeletalPackage )

	local rig = spriteloop.new( animations.skeletal.path, { autoplay = false } )
	params.parent:insert( rig )
	rig.x = params.x
	rig.y = params.y
	rig.xScale = animations.scale
	rig.yScale = animations.scale
	rig.isVisible = false

	local character = {}

	local playCurrent

	-- The runtime dispatches "loop" before it draws the frame, and draws from whichever animation
	-- is current then, so a variant started here shows its own first frame on this very frame.
	local function onLoop()
		if state:recordPlay() then
			params.onVariantChange( state:advanceVariant() )
			playCurrent()
		end
	end

	-- The package loops every variant, so plays are counted on each loop instead of on completion.
	function playCurrent()
		state:restartVariant()
		rig:play( state:skeletalAnimationName(), { onLoop = onLoop } )
	end

	-- Shows the character and plays the state's current animation and variant from the start.
	function character.show()
		rig.isVisible = true
		playCurrent()
	end

	function character.hide()
		rig:pause()
		rig.isVisible = false
	end

	-- Removing the group also removes the runtime's own enterFrame listener.
	function character.destroy()
		display.remove( rig )
		rig = nil

		for i = 1, #textures do
			textures[i]:releaseSelf()
		end

		textures = nil
	end

	return character
end

--------------------------------------------------------------------------------------

return skeletalCharacter
