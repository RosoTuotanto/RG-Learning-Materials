-- Runs the real scene, spriteloop runtime and skeletal package against the Solar2D stub.
-- Run from anywhere: lua5.1 tools/verify_scene.lua

local root = string.match( arg[0], "^(.*)/tools/[^/]*$" ) or "."
package.path = root .. "/?.lua;" .. root .. "/tools/stubs/?.lua;" .. package.path

local stub = require( "solar2d_stub" )

local animations = require( "data.animations" )
local layout = require( "data.layout" )
local strings = require( "data.strings" )

local frameMs = 16

-- Comfortably past the longest variant: walk_3's 33 frames at 12 fps take under 3 seconds.
local maxFramesPerVariant = 240

local checks = 0
local failures = 0

local function check( condition, message )
	checks = checks + 1

	if not condition then
		failures = failures + 1
		print( "FAIL: " .. message )
	end
end

local function sameColor( a, b )
	return a ~= nil and a[1] == b[1] and a[2] == b[2] and a[3] == b[3]
end

--------------------------------------------------------------------------------------
-- main.lua

dofile( root .. "/main.lua" )

check( stub.scenesVisited[1] == "scenes.demo", "main.lua goes to scenes.demo" )
check( stub.statusBar == display.HiddenStatusBar, "main.lua hides the status bar" )
check( stub.defaults["background"] and #stub.defaults["background"] == 3, "main.lua sets the background colour" )

--------------------------------------------------------------------------------------
-- Create and show

local scene = require( "scenes.demo" )
local baselineEnterFrame = stub.listenerCount( "enterFrame" )
local baselineResize = stub.listenerCount( "resize" )

-- Records the mag and min filter defaults in effect whenever a textured object is created.
local filtersAtCreation = {}

local function trackFilters( kind, owner, name )
	local create = owner[name]

	owner[name] = function( ... )
		local mag = stub.defaults["magTextureFilter"] or {}
		local min = stub.defaults["minTextureFilter"] or {}
		local seen = filtersAtCreation[kind] or {}
		seen[#seen + 1] = tostring( mag[1] ) .. "/" .. tostring( min[1] )
		filtersAtCreation[kind] = seen

		return create( ... )
	end
end

local function allCreatedUnder( kind, filter )
	local seen = filtersAtCreation[kind]

	if not seen then
		return false
	end

	for i = 1, #seen do
		if seen[i] ~= filter .. "/" .. filter then
			return false
		end
	end

	return true
end

trackFilters( "sheet", graphics, "newImageSheet" )
trackFilters( "image", display, "newImageRect" )
trackFilters( "text", display, "newText" )

stub.sceneEvent( scene, "create" )
stub.sceneEvent( scene, "show", "will" )
stub.sceneEvent( scene, "show", "did" )

local view = scene.view
local sprite = stub.sprites[1]

local rig = stub.findObject( view, function( object )
	return object._package ~= nil
end )

local function findText( text )
	return stub.findObject( view, function( object )
		return object.kind == "text" and object.text == text
	end )
end

local function findButton( id )
	return stub.findObject( view, function( object )
		return object.kind == "group" and object.id == id
	end )
end

local function spriteCaption( name )
	return string.format( strings.captionFormat, name )
end

local function captionFor( name, variant )
	return string.format( strings.skeletalCaptionFormat, spriteCaption( name ), variant, animations.skeletal.variants )
end

local heading = findText( strings.heading.sprite )
local caption = findText( spriteCaption( "idle" ) )
local description = findText( strings.description.sprite )

check( #stub.sprites == 1, "exactly one sprite is created" )
check( stub.imageSheets[1] and stub.imageSheets[1].filename == animations.sheet.file, "the sprite sheet is loaded from data.animations" )
check( rig ~= nil, "the spriteloop group is in the scene" )
check( stub.listenerCount( "enterFrame" ) == baselineEnterFrame + 1, "the spriteloop instance adds one enterFrame listener" )
check( #stub.images > 0, "the skeletal package creates part images" )
check( allCreatedUnder( "sheet", layout.textureFilter.pixelArt ), "the sprite sheet loads under the pixel-art filter" )
check( allCreatedUnder( "image", layout.textureFilter.pixelArt ), "every part image loads under the pixel-art filter" )
check( allCreatedUnder( "text", layout.textureFilter.ui ), "every text object is created under the ui filter" )

for i = 1, #stub.images do
	local filename = stub.images[i].filename
	check( string.find( filename, "^assets/skeletal/parts/" ) ~= nil, "part image path is inside the package: " .. tostring( filename ) )
end

check( sprite.isVisible and sprite.isPlaying, "the sprite character is shown and playing" )
check( sprite.sequence == "idle", "the sprite starts on idle" )
check( not rig.isVisible, "the skeletal character starts hidden" )
check( heading ~= nil, "the heading reads the sprite style" )
check( caption ~= nil, "the caption names the idle animation" )
check( description ~= nil, "the description explains the sprite style" )
check( sameColor( findButton( "idle" ).background.fillColor, layout.palette.buttonActiveFill ), "the idle button is highlighted" )

--------------------------------------------------------------------------------------
-- Layout

local floorLine = stub.findObject( view, function( object )
	return object.kind == "rect" and sameColor( object.fillColor, layout.palette.floor )
end )

local styleButton = findButton( "style" )
local idleButton = findButton( "idle" )
local walkButton = findButton( "walk" )
local jumpButton = findButton( "jump" )

local styleX, styleY = stub.contentPosition( styleButton )
local idleX, idleY = stub.contentPosition( idleButton )
local walkX = stub.contentPosition( walkButton )
local jumpX = stub.contentPosition( jumpButton )

local styleWidth = styleButton.background.width
local buttonWidth = idleButton.background.width
local styleGap = ( idleX - buttonWidth * 0.5 ) - ( styleX + styleWidth * 0.5 )
local buttonGap = ( walkX - buttonWidth * 0.5 ) - ( idleX + buttonWidth * 0.5 )
local rowLeft = styleX - styleWidth * 0.5
local rowRight = jumpX + jumpButton.background.width * 0.5
local styleTop = styleY - styleButton.background.height * 0.5
local styleBottom = styleY + styleButton.background.height * 0.5

-- The stub sizes text only when it is created, so each description is measured on a throwaway copy.
local function measureDescription( text )
	local copy = display.newText({
		text = text,
		x = description.x,
		y = description.y,
		width = description.width,
		font = description.font,
		fontSize = description.size,
		align = description.align,
	})
	local top = copy.y - copy.height * 0.5
	local bottom = copy.y + copy.height * 0.5
	display.remove( copy )

	return top, bottom
end
local floorBottom = floorLine.y + floorLine.height * 0.5

check( styleButton.label.text == strings.styleButtonLabel, "the style button reads change style" )
check( styleWidth > buttonWidth and styleButton.background.height > idleButton.background.height, "the style button is larger than the animation buttons" )
check( styleX < idleX, "the style button sits left of idle" )
check( styleGap > buttonGap and buttonGap > 0, "the style button's gap is larger than the gaps between animation buttons" )
check( math.abs( ( rowLeft + rowRight ) * 0.5 - display.contentCenterX ) < 0.001, "the button row is centred horizontally" )
check( styleY == idleY, "the style button and the animation buttons share a centre line" )
check( math.abs( styleBottom + layout.ui.bottomMargin - display.contentHeight ) < 0.001, "the bottom margin applies to the taller style button" )

check( description.align == "center" and description.width == layout.description.width, "the description wraps centred at the layout width" )
check( description.font == layout.font.body and description.size == layout.description.size, "the description uses the body font at the layout size" )
check( math.abs( description.y - ( floorBottom + styleTop ) * 0.5 ) <= 2, "the description sits midway between the floor and the style button" )
local styleNames = { "sprite", "skeletal" }

for i = 1, #styleNames do
	local top, bottom = measureDescription( strings.description[styleNames[i]] )
	check( top > floorBottom and bottom < styleTop, "the " .. styleNames[i] .. " description fits between the floor and the style button" )
end
check( sameColor( description.fillColor, layout.palette.textMuted ), "the description uses the muted colour" )

local function pressButton( id )
	local x, y = stub.contentPosition( findButton( id ) )

	return stub.tapAt( x, y )
end

local function checkStyleButtonPlain()
	check( sameColor( styleButton.background.fillColor, layout.palette.buttonFill ), "the style button is never highlighted" )
end

checkStyleButtonPlain()

--------------------------------------------------------------------------------------
-- Sprite style

check( pressButton( "walk" ) == findButton( "walk" ), "the walk button receives its press" )
check( sprite.sequence == "walk" and sprite.isPlaying, "walk plays the walk sequence" )
check( sameColor( findButton( "walk" ).background.fillColor, layout.palette.buttonActiveFill ), "the walk button is highlighted" )
check( sameColor( findButton( "idle" ).background.fillColor, layout.palette.buttonFill ), "the idle button is no longer highlighted" )
check( caption.text == spriteCaption( "walk" ), "the caption names the walk animation" )
check( heading.text == strings.heading.sprite, "the sprite heading stays after a button press" )
check( description.text == strings.description.sprite, "the sprite description stays after a button press" )

--------------------------------------------------------------------------------------
-- Skeletal style

check( pressButton( "style" ) == styleButton, "the style button receives its press" )

check( rig.isVisible, "the style button shows the skeletal character" )
check( not sprite.isVisible and not sprite.isPlaying, "the style button hides and pauses the sprite" )
check( rig._currentAnimation and rig._currentAnimation.name == "walk_1", "the skeletal character plays walk_1" )
check( rig._isPlaying, "the skeletal animation is playing" )
check( caption.text == captionFor( "walk", 1 ), "the caption reads walk variant 1" )
check( caption.text == "Playing: walk animation (variant 1/3)", "the caption reads exactly as specified" )
check( heading.text == strings.heading.skeletal, "the heading reads the skeletal style" )
check( description.text == strings.description.skeletal, "the description explains the skeletal style" )
check( sameColor( walkButton.background.fillColor, layout.palette.buttonActiveFill ), "the walk button stays highlighted across the style change" )
checkStyleButtonPlain()

-- Plays frames until the runtime's non-looping animation completes. Returns the seconds it took.
local function playUntilComplete()
	local startClock = stub.clock

	for _ = 1, maxFramesPerVariant do
		stub.advanceFrame( frameMs )

		if not rig._isPlaying then
			return ( stub.clock - startClock ) / 1000
		end
	end

	return nil
end

local function finishVariant( expectedName, expectedVariant )
	local seconds = playUntilComplete()
	check( seconds ~= nil, "the variant before " .. expectedName .. " completes" )

	check( stub.pendingTimerCount() == 1, "completing a variant schedules one switch" )

	stub.runTimers()
	check( rig._currentAnimation.name == expectedName, "the switch plays " .. expectedName .. ", got " .. tostring( rig._currentAnimation.name ) )
	check( rig._isPlaying, expectedName .. " is playing" )
	local expectedCaption = captionFor( string.match( expectedName, "^(.-)_" ), expectedVariant )
	check( caption.text == expectedCaption, "the caption reads variant " .. expectedVariant .. " for " .. expectedName )

	return seconds
end

-- The runtime completes a one-shot animation on reaching its last frame, so walk_1 takes
-- one frame less than its length, give or take one stub frame.
local walk = rig._currentAnimation
local walkExpected = ( walk.frameCount - 1 ) / walk.fps
local walkSeconds = finishVariant( "walk_2", 2 )
local walkOnTime = walkSeconds and math.abs( walkSeconds - walkExpected ) <= frameMs / 1000
check( walkOnTime, "walk_1 completes after " .. walkExpected .. " s, took " .. tostring( walkSeconds ) )

finishVariant( "walk_3", 3 )
finishVariant( "walk_1", 1 )
finishVariant( "walk_2", 2 )

-- A press while a switch is pending must cancel it, or the next variant would replace jump_1.
playUntilComplete()
check( stub.pendingTimerCount() == 1, "walk_2 completing leaves a switch pending" )

check( pressButton( "jump" ) == findButton( "jump" ), "the jump button receives its press" )
check( rig.isVisible, "a button press does not toggle the style" )
check( not sprite.isVisible, "a button press does not show the sprite" )
check( rig._currentAnimation.name == "jump_1" and rig._isPlaying, "jump plays jump_1" )
check( caption.text == captionFor( "jump", 1 ), "the caption resets to jump variant 1 on a new animation" )
check( stub.pendingTimerCount() == 0, "the press cancels the pending switch" )

stub.runTimers()
check( rig._currentAnimation.name == "jump_1", "no stale switch fires after the press" )

-- Taps outside the buttons reach nothing and change nothing, in either style.
local function checkTapIgnored( x, y, what )
	local wasSkeletal = rig.isVisible
	local headingBefore = heading.text

	check( stub.tapAt( x, y ) == nil, "a tap on " .. what .. " reaches no listener" )
	check( rig.isVisible == wasSkeletal and sprite.isVisible ~= wasSkeletal, "a tap on " .. what .. " does not toggle the style" )
	check( heading.text == headingBefore, "a tap on " .. what .. " leaves the heading alone" )
end

local floorX, floorY = stub.contentPosition( floorLine )
local characterX, characterY = stub.contentPosition( sprite )

-- An empty spot left of the character, above the floor and below the caption.
checkTapIgnored( 100, 250, "the background" )
checkTapIgnored( floorX, floorY, "the floor line" )
checkTapIgnored( characterX, characterY, "the character" )

--------------------------------------------------------------------------------------
-- Back to sprite style

pressButton( "style" )

check( sprite.isVisible and sprite.isPlaying, "a second style press shows the sprite again" )
check( sprite.sequence == "jump", "the sprite plays the selected jump sequence" )
check( not rig.isVisible and not rig._isPlaying, "the skeletal character is hidden and paused" )
check( caption.text == spriteCaption( "jump" ), "the caption names the jump animation without a variant" )
check( heading.text == strings.heading.sprite, "the heading is back to the sprite style" )
check( description.text == strings.description.sprite, "the description is back to the sprite style" )
checkStyleButtonPlain()

checkTapIgnored( 100, 250, "the background in sprite style" )
checkTapIgnored( floorX, floorY, "the floor line in sprite style" )
checkTapIgnored( characterX, characterY, "the character in sprite style" )

--------------------------------------------------------------------------------------
-- Resize

-- An HTML5 window grown 80 px taller extends the visible screen 40 px past each content edge.
display.screenOriginY = -40
display.actualContentHeight = 720
stub.fire( "resize" )

local _, resizedStyleY = stub.contentPosition( styleButton )
local _, resizedIdleY = stub.contentPosition( idleButton )
local resizedBottom = resizedStyleY + styleButton.background.height * 0.5

check( math.abs( resizedBottom + layout.ui.bottomMargin - 680 ) < 0.001, "a resize keeps the row on the bottom of the visible screen" )
check( resizedIdleY == resizedStyleY, "a resize keeps the row on one centre line" )

display.screenOriginY = 0
display.actualContentHeight = 640
stub.fire( "resize" )

local restoredX, restoredY = stub.contentPosition( styleButton )
check( restoredX == styleX and restoredY == styleY, "the row returns after the window shrinks back" )

--------------------------------------------------------------------------------------
-- Hide and destroy

stub.sceneEvent( scene, "hide", "will" )
stub.sceneEvent( scene, "hide", "did" )

check( not sprite.isPlaying, "hiding the scene pauses the sprite" )

--------------------------------------------------------------------------------------
-- Show again, then hide with a variant switch pending

stub.sceneEvent( scene, "show", "will" )
stub.sceneEvent( scene, "show", "did" )

check( sprite.isVisible and sprite.isPlaying and sprite.sequence == "jump", "showing the scene again plays the selected sprite sequence" )

pressButton( "style" )
check( rig.isVisible and rig._currentAnimation.name == "jump_1" and rig._isPlaying, "the style button works after a re-show" )

check( playUntilComplete() ~= nil, "jump_1 completes after a re-show" )
check( stub.pendingTimerCount() == 1, "jump_1 completing leaves a switch pending" )

stub.sceneEvent( scene, "hide", "will" )
stub.sceneEvent( scene, "hide", "did" )

check( stub.pendingTimerCount() == 0, "hiding the scene cancels the pending switch" )

stub.runTimers()

for _ = 1, 10 do
	stub.advanceFrame( frameMs )
end

check( rig._currentAnimation.name == "jump_1" and not rig._isPlaying, "the hidden skeletal character does not advance to the next variant" )
check( caption.text == captionFor( "jump", 1 ), "the caption stays on variant 1 while hidden" )

stub.sceneEvent( scene, "show", "will" )
stub.sceneEvent( scene, "show", "did" )

check( rig.isVisible and rig._currentAnimation.name == "jump_1" and rig._isPlaying, "showing the scene again plays the selected skeletal animation" )
check( not sprite.isVisible, "the sprite stays hidden on a skeletal re-show" )

stub.sceneEvent( scene, "hide", "will" )
stub.sceneEvent( scene, "hide", "did" )

stub.sceneEvent( scene, "destroy" )

check( stub.pendingTimerCount() == 0, "no timer is pending after destroy" )
check( stub.listenerCount( "enterFrame" ) == baselineEnterFrame, "destroy removes the spriteloop enterFrame listener" )
check( stub.listenerCount( "resize" ) == baselineResize, "destroy removes the ui resize listener" )
check( sprite.isRemoved and rig.isRemoved, "destroy removes both characters" )
check( findText( strings.heading.skeletal ) == nil and findText( strings.styleButtonLabel ) == nil, "destroy removes the ui" )

for i = 1, #stub.violations do
	check( false, "stub: " .. stub.violations[i] )
end

print( checks .. " checks, " .. failures .. " failures" )

if failures > 0 then
	os.exit( 1 )
end
