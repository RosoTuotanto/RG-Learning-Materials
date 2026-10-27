-- The demo itself: one character, shown either as a sprite sheet or as a skeletal rig,
-- with the style and the animation picked from the buttons.

--------------------------------------------------------------------------------------
-- Libraries, classes, scripts, configs, etc.

local composer = require( "composer" )
local layout = require( "data.layout" )
local animations = require( "data.animations" )
local demoState = require( "scripts.demoState" )
local spriteCharacter = require( "scripts.spriteCharacter" )
local skeletalCharacter = require( "scripts.skeletalCharacter" )
local ui = require( "scripts.ui" )
local screen = require( "scripts.screen" )

--------------------------------------------------------------------------------------
-- Forward declarations & variables

local palette = layout.palette
local textureFilter = layout.textureFilter

local state
local spriteVersion
local skeletalVersion

--------------------------------------------------------------------------------------
-- Functions

local function setTextureFilter( filter )
	display.setDefault( "magTextureFilter", filter )
	display.setDefault( "minTextureFilter", filter )
end

-- Only the active style's character is visible and playing, from the start of its animation.
-- The hidden one is paused.
local function showActiveCharacter()
	if state:isSkeletal() then
		spriteVersion.hide()
		skeletalVersion.show()
	else
		skeletalVersion.hide()
		spriteVersion.show( state:getAnimation() )
	end

	ui.refresh( state )
end

local function selectAnimation( name )
	if state:selectAnimation( name ) then
		showActiveCharacter()
	end
end

local function onVariantChange()
	ui.refresh( state )
end

local function changeStyle()
	state:toggleStyle()
	showActiveCharacter()
end

--------------------------------------------------------------------------------------
-- Scene functions

local scene = composer.newScene()

function scene:create( event )
	local sceneGroup = self.view

	state = demoState.new({
		animations = animations.names,
		variantCount = animations.skeletal.variants,
		plays = animations.skeletal.plays,
	})

	local floorSettings = layout.floor
	local floor = display.newRect( sceneGroup, screen.centerX, floorSettings.y, floorSettings.width, floorSettings.height )
	floor:setFillColor( palette.floor[1], palette.floor[2], palette.floor[3] )

	-- Both characters are centred horizontally, each placed so its feet rest on top of the floor.
	local floorTop = floorSettings.y - floorSettings.height * 0.5

	-- Filters apply to textures loaded after they are set, and both characters load every image they use in new.
	setTextureFilter( textureFilter.pixelArt )

	spriteVersion = spriteCharacter.new({
		parent = sceneGroup,
		x = screen.centerX,
		y = floorTop - layout.character.spriteFeetOffset * animations.scale,
	})

	skeletalVersion = skeletalCharacter.new({
		parent = sceneGroup,
		x = screen.centerX,
		y = floorTop - layout.character.skeletalFeetOffset * animations.scale,
		state = state,
		onVariantChange = onVariantChange,
	})

	setTextureFilter( textureFilter.ui )

	ui.create({
		parent = sceneGroup,
		names = animations.names,
		onSelect = selectAnimation,
		onStyleChange = changeStyle,
	})
end

function scene:show( event )
	local phase = event.phase

	if phase == "did" then
		showActiveCharacter()
	end
end

function scene:hide( event )
	local phase = event.phase

	if phase == "will" then
		spriteVersion.hide()
		skeletalVersion.hide()
	end
end

function scene:destroy( event )
	spriteVersion.destroy()
	skeletalVersion.destroy()
	ui.destroy()

	spriteVersion = nil
	skeletalVersion = nil
	state = nil
end

--------------------------------------------------------------------------------------

scene:addEventListener( "create", scene )
scene:addEventListener( "show", scene )
scene:addEventListener( "hide", scene )
scene:addEventListener( "destroy", scene )

return scene
