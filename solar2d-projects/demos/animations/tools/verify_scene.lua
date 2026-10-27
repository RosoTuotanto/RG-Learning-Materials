-- Runs the real scene, spriteloop runtime and skeletal package against the Solar2D stub.
-- Run from anywhere: lua5.1 tools/verify_scene.lua

local root = string.match( arg[0], "^(.*)/tools/[^/]*$" ) or "."
package.path = root .. "/?.lua;" .. root .. "/tools/stubs/?.lua;" .. package.path

local stub = require( "solar2d_stub" )

local json = require( "json" )
local animations = require( "data.animations" )
local layout = require( "data.layout" )
local strings = require( "data.strings" )

local frameMs = 16

-- Comfortably past the longest wait for a switch, the plays of the longest variant.
local maxFramesPerSwitch = 600

local pixelArtFilter = layout.textureFilter.pixelArt .. "/" .. layout.textureFilter.pixelArt

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

-- The buttons are the style button and one per animation, nothing else.
local buttonIds = {}

stub.findObject( view, function( object )
	if object.kind == "group" and object.id ~= nil then
		buttonIds[#buttonIds + 1] = object.id
	end

	return false
end )

check( #buttonIds == #animations.names + 1, "the only buttons are the style button and the animation buttons, got " .. table.concat( buttonIds, "," ) )

--------------------------------------------------------------------------------------
-- Swap images

-- Every image the package can show, read from the manifest apart from the app's own reading.
local manifestFile = assert( io.open( root .. "/" .. animations.skeletal.path .. "/manifest.json", "rb" ) )
local manifest = json.decode( manifestFile:read( "*a" ) )
manifestFile:close()

local packageImages = {}
local variantImages = {}

for i = 1, #manifest.parts do
	if manifest.parts[i].asset then
		packageImages[#packageImages + 1] = animations.skeletal.path .. "/" .. manifest.parts[i].asset
	end
end

for i = 1, #manifest.variants do
	local filename = animations.skeletal.path .. "/" .. manifest.variants[i].asset
	packageImages[#packageImages + 1] = filename
	variantImages[#variantImages + 1] = filename
end

local function findTexture( filename )
	for i = 1, #stub.textures do
		if stub.textures[i].filename == filename then
			return stub.textures[i]
		end
	end

	return nil
end

check( #variantImages > 0, "the package has swap images" )
-- A part's default image can also be one of its swap images, so the list repeats some paths.
local distinctImages = {}
local distinctCount = 0

for i = 1, #packageImages do
	if not distinctImages[packageImages[i]] then
		distinctImages[packageImages[i]] = true
		distinctCount = distinctCount + 1
	end
end

check( distinctCount < #packageImages, "the manifest names some images both as a part and as a swap image" )
check( #stub.textures == distinctCount, "one texture is held per distinct package image, got " .. #stub.textures .. " for " .. distinctCount )

for i = 1, #packageImages do
	local texture = findTexture( packageImages[i] )
	local what = "the texture for " .. packageImages[i]

	check( texture ~= nil, what .. " is created" )

	if texture then
		check( texture.baseDir == system.ResourceDirectory, what .. " is read from the resource directory" )
		check( texture.filter == pixelArtFilter, what .. " loads under the pixel-art filter, got " .. texture.filter )
		check( texture.isPreloaded, what .. " is preloaded" )
		check( not texture.isReleased, what .. " is held while the scene exists" )
	end
end

-- Every load of a package image, by the rig or by the textures, so far and after the cycles below.
local function checkPackageLoads( when )
	local fills = {}
	local fillCount = 0

	for i = 1, #stub.imageLoads do
		local imageLoad = stub.imageLoads[i]

		if string.find( imageLoad.filename, "^" .. animations.skeletal.path .. "/" ) then
			local what = imageLoad.filename .. " gets the pixel-art filter " .. when .. " (" .. imageLoad.source .. ")"
			check( imageLoad.filter == pixelArtFilter, what .. ", got " .. imageLoad.filter )

			if imageLoad.source == "fill" then
				fills[imageLoad.filename] = true
				fillCount = fillCount + 1
			end
		end
	end

	return fills, fillCount
end

checkPackageLoads( "at creation" )

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
check( stub.pendingTimerCount() == 0, "the sprite side schedules no timers" )

--------------------------------------------------------------------------------------
-- Skeletal style

check( pressButton( "style" ) == styleButton, "the style button receives its press" )

check( rig.isVisible, "the style button shows the skeletal character" )
check( not sprite.isVisible and not sprite.isPlaying, "the style button hides and pauses the sprite" )
check( rig._currentAnimation and rig._currentAnimation.name == "walk_1", "the skeletal character plays walk_1" )
check( rig._isPlaying and rig._elapsedTime == 0, "walk_1 plays from its start" )
check( caption.text == captionFor( "walk", 1 ), "the caption reads walk variant 1" )
check( caption.text == "Playing: walk animation (variant 1/3)", "the caption reads exactly as specified" )
check( heading.text == strings.heading.skeletal, "the heading reads the skeletal style" )
check( description.text == strings.description.skeletal, "the description explains the skeletal style" )
check( sameColor( walkButton.background.fillColor, layout.palette.buttonActiveFill ), "the walk button stays highlighted across the style change" )
checkStyleButtonPlain()

local function playFrames( count )
	for _ = 1, count do
		stub.advanceFrame( frameMs )
	end
end

-- Plays frames until the skeletal character starts another animation. Returns the seconds it took.
local function playUntilSwitch()
	local startClock = stub.clock
	local playing = rig._currentAnimation

	for _ = 1, maxFramesPerSwitch do
		stub.advanceFrame( frameMs )

		if rig._currentAnimation ~= playing then
			return ( stub.clock - startClock ) / 1000
		end
	end

	return nil
end

-- Plays the current variant out and checks the switch to the expected one.
local function finishVariant( animationName, expectedVariant )
	local playing = rig._currentAnimation
	local plays = animations.skeletal.plays[animationName]
	local expectedSeconds = plays * playing.frameCount / playing.fps
	local expectedName = animationName .. "_" .. expectedVariant

	local seconds = playUntilSwitch()
	local isOnTime = seconds ~= nil and seconds >= expectedSeconds and seconds - expectedSeconds < frameMs / 1000
	check( isOnTime, playing.name .. " loops " .. plays .. " time(s), " .. expectedSeconds .. " s, before the switch, took " .. tostring( seconds ) )

	-- The switch happens inside the loop callback, so the frame drawn after it is the new variant's start.
	check( rig._currentAnimation.name == expectedName, "the switch plays " .. expectedName .. ", got " .. tostring( rig._currentAnimation.name ) )
	check( rig._isPlaying and rig._elapsedTime == 0, expectedName .. " plays from its start" )
	check( rig._currentFrameIndex == 0, expectedName .. " shows its first frame on the switch frame" )
	check( caption.text == captionFor( animationName, expectedVariant ), "the caption reads variant " .. expectedVariant .. " for " .. expectedName )
	check( stub.pendingTimerCount() == 0, "the switch to " .. expectedName .. " needs no timer" )
end

finishVariant( "walk", 2 )
check( caption.text == "Playing: walk animation (variant 2/3)", "the variant 2 caption reads exactly as specified" )
finishVariant( "walk", 3 )
finishVariant( "walk", 1 )
finishVariant( "walk", 2 )

-- A press partway through a variant starts the new animation at once.
playFrames( 30 )
check( pressButton( "jump" ) == findButton( "jump" ), "the jump button receives its press" )
check( rig.isVisible, "a button press does not toggle the style" )
check( not sprite.isVisible, "a button press does not show the sprite" )
check( rig._currentAnimation.name == "jump_1" and rig._isPlaying and rig._elapsedTime == 0, "jump plays jump_1 from its start" )
check( caption.text == captionFor( "jump", 1 ), "the caption resets to jump variant 1 on a new animation" )

finishVariant( "jump", 2 )
finishVariant( "jump", 3 )
finishVariant( "jump", 1 )

-- The same animation pressed again starts over from variant 1.
finishVariant( "jump", 2 )
playFrames( 20 )
pressButton( "jump" )
check( rig._currentAnimation.name == "jump_1" and rig._elapsedTime == 0, "pressing jump on jump_2 starts again from jump_1" )
check( caption.text == captionFor( "jump", 1 ), "the caption resets to variant 1 on the same animation" )

pressButton( "idle" )
check( rig._currentAnimation.name == "idle_1", "idle plays idle_1" )
finishVariant( "idle", 2 )
finishVariant( "idle", 3 )
finishVariant( "idle", 1 )

-- Every variant has played, so every swap image the package uses has been shown.
local fills, fillCount = checkPackageLoads( "after every variant played" )
check( fillCount > 0, "the variants swap images during play" )

for i = 1, #variantImages do
	local wasShown = fills[variantImages[i]] == true

	for imageIndex = 1, #stub.images do
		wasShown = wasShown or stub.images[imageIndex].filename == variantImages[i]
	end

	check( wasShown, "the swap image " .. variantImages[i] .. " is shown during the cycles" )
end

-- Taps outside the buttons reach nothing and change nothing, in either style.
local function checkTapIgnored( x, y, what )
	local wasSkeletal = rig.isVisible
	local headingBefore = heading.text
	local captionBefore = caption.text
	local animationBefore = rig._currentAnimation.name
	local spriteBefore = sprite.sequence

	check( stub.tapAt( x, y ) == nil, "a tap on " .. what .. " reaches no listener" )
	check( rig.isVisible == wasSkeletal and sprite.isVisible ~= wasSkeletal, "a tap on " .. what .. " does not toggle the style" )
	check( heading.text == headingBefore and caption.text == captionBefore, "a tap on " .. what .. " leaves the heading and caption alone" )
	check( rig._currentAnimation.name == animationBefore and sprite.sequence == spriteBefore, "a tap on " .. what .. " changes no animation" )
end

local floorX, floorY = stub.contentPosition( floorLine )
local characterX, characterY = stub.contentPosition( sprite )

local function checkTapsIgnored( suffix )
	-- An empty spot left of the character, above the floor and below the caption.
	checkTapIgnored( 100, 250, "the background" .. suffix )
	checkTapIgnored( floorX, floorY, "the floor line" .. suffix )
	checkTapIgnored( characterX, characterY, "the character" .. suffix )
	checkTapIgnored( styleX, ( floorBottom + styleTop ) * 0.5, "the description" .. suffix )
end

checkTapsIgnored( "" )

--------------------------------------------------------------------------------------
-- Back to sprite style

finishVariant( "idle", 2 )
pressButton( "jump" )
finishVariant( "jump", 2 )
pressButton( "style" )

check( sprite.isVisible and sprite.isPlaying, "a second style press shows the sprite again" )
check( sprite.sequence == "jump", "the sprite plays the selected jump sequence" )
check( not rig.isVisible and not rig._isPlaying, "the skeletal character is hidden and paused" )
check( caption.text == spriteCaption( "jump" ), "the caption names the jump animation without a variant" )
check( heading.text == strings.heading.sprite, "the heading is back to the sprite style" )
check( description.text == strings.description.sprite, "the description is back to the sprite style" )
checkStyleButtonPlain()

checkTapsIgnored( " in sprite style" )

playFrames( 400 )
check( stub.pendingTimerCount() == 0, "the paused skeletal character schedules no switch" )

-- Switching style starts the skeletal side again from variant 1.
pressButton( "style" )
check( rig._currentAnimation.name == "jump_1" and rig._elapsedTime == 0, "a style change starts the skeletal side from jump_1" )
check( caption.text == captionFor( "jump", 1 ), "the caption reads variant 1 after a style change" )
finishVariant( "jump", 2 )

-- A style change partway through a variant pauses the skeletal side where it is.
playFrames( 10 )
pressButton( "style" )
check( not rig._isPlaying and rig._currentAnimation.name == "jump_2", "a style change pauses the skeletal variant" )
check( caption.text == spriteCaption( "jump" ), "the sprite caption shows no variant" )

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
-- Show again, then hide partway through a variant

stub.sceneEvent( scene, "show", "will" )
stub.sceneEvent( scene, "show", "did" )

check( sprite.isVisible and sprite.isPlaying and sprite.sequence == "jump", "showing the scene again plays the selected sprite sequence" )

pressButton( "style" )
check( rig.isVisible and rig._currentAnimation.name == "jump_1" and rig._isPlaying, "the style button works after a re-show" )

-- Partway through jump_1's last play, so a switch would come soon if hiding did not pause it.
local jumpLoop = rig._currentAnimation.frameCount / rig._currentAnimation.fps
local jumpPlays = animations.skeletal.plays.jump
playFrames( math.ceil( ( jumpPlays - 0.5 ) * jumpLoop * 1000 / frameMs ) )
check( rig._currentAnimation.name == "jump_1", "jump_1 is still on its last play" )

stub.sceneEvent( scene, "hide", "will" )
stub.sceneEvent( scene, "hide", "did" )

playFrames( 400 )

check( rig._currentAnimation.name == "jump_1" and not rig._isPlaying, "the hidden skeletal character does not advance to the next variant" )
check( caption.text == captionFor( "jump", 1 ), "the caption stays on variant 1 while hidden" )

stub.sceneEvent( scene, "show", "will" )
stub.sceneEvent( scene, "show", "did" )

check( rig.isVisible and rig._currentAnimation.name == "jump_1" and rig._isPlaying, "showing the scene again plays the selected skeletal animation" )
check( rig._elapsedTime == 0, "a re-show starts the variant from its start" )
check( not sprite.isVisible, "the sprite stays hidden on a skeletal re-show" )

-- A re-show counts the variant's plays from zero, so jump_1 plays in full again before the switch.
finishVariant( "jump", 2 )

stub.sceneEvent( scene, "hide", "will" )
stub.sceneEvent( scene, "hide", "did" )

stub.sceneEvent( scene, "destroy" )

check( stub.pendingTimerCount() == 0, "no timer is pending after destroy" )
check( stub.listenerCount( "enterFrame" ) == baselineEnterFrame, "destroy removes the spriteloop enterFrame listener" )
check( stub.listenerCount( "resize" ) == baselineResize, "destroy removes the ui resize listener" )
check( sprite.isRemoved and rig.isRemoved, "destroy removes both characters" )
check( findText( strings.heading.skeletal ) == nil and findText( strings.styleButtonLabel ) == nil, "destroy removes the ui" )

local allReleased = #stub.textures > 0

for i = 1, #stub.textures do
	allReleased = allReleased and stub.textures[i].isReleased
end

check( allReleased, "destroy releases every held package texture" )

for i = 1, #stub.violations do
	check( false, "stub: " .. stub.violations[i] )
end

print( checks .. " checks, " .. failures .. " failures" )

if failures > 0 then
	os.exit( 1 )
end
