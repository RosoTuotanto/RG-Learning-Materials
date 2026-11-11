-- Runs the real scene, spriteloop runtime and skeletal package against the Solar2D stub.
-- Run from anywhere: lua5.1 tools/verify_scene.lua

local root = string.match( arg[0], "^(.*)/tools/[^/]*$" ) or "."
package.path = root .. "/?.lua;" .. root .. "/tools/stubs/?.lua;" .. package.path

local stub = require( "solar2d_stub" )

local json = require( "json" )
local animations = require( "data.animations" )
local layout = require( "data.layout" )
local strings = require( "data.strings" )
local outfits = require( "data.outfits" )

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
local panelTitle = findText( strings.animationPanelTitle )

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
check( panelTitle ~= nil, "the animation panel carries its title" )
check( sameColor( findButton( "idle" ).background.fillColor, layout.palette.buttonActiveFill ), "the idle button is highlighted" )

-- The buttons are the style button and one per animation, nothing else.
local buttonIds = {}

stub.findObject( view, function( object )
	if object.kind == "group" and object.id ~= nil then
		buttonIds[#buttonIds + 1] = object.id
	end

	return false
end )

local buttonCount = #animations.names + 1 + #outfits.slots
check( #buttonIds == buttonCount, "the only buttons are the style, animation and outfit buttons, got " .. table.concat( buttonIds, "," ) )

local outfitIds = { "shirt", "pants", "flowers" }

-- The label each outfit button shows per option, written out apart from data/strings.lua.
local expectedOutfitLabels = {
	shirt = { yellow = "shirt: yellow", red = "shirt: red" },
	pants = { blue = "pants: blue", grey = "pants: grey" },
	flowers = { none = "hold nothing", held = "hold flowers" },
}

local function checkOutfitLabels( shirt, pants, isHolding, what )
	local options = { shirt = shirt, pants = pants, flowers = isHolding and "held" or "none" }

	for i = 1, #outfitIds do
		local id = outfitIds[i]
		local button = findButton( id )
		local expected = expectedOutfitLabels[id][options[id]]

		local shown = tostring( button and button.label.text )
		check( shown == expected, "the " .. id .. " button reads " .. expected .. " " .. what .. ", got " .. shown )
	end
end

for slot, labels in pairs( expectedOutfitLabels ) do
	for option, label in pairs( labels ) do
		check( strings.outfitButtonLabel[slot][option] == label, "the " .. slot .. " label for " .. option .. " reads " .. label )
	end
end

checkOutfitLabels( "yellow", "blue", false, "at creation" )

local outfitTitle = findText( "Customize" )
check( outfitTitle ~= nil and strings.outfitPanelTitle == "Customize", "the outfit panel carries the Customize title" )

for i = 1, #outfitIds do
	local button = findButton( outfitIds[i] )
	check( button ~= nil and not button.parent.isVisible, "the " .. outfitIds[i] .. " button is hidden while frame-by-frame shows" )
end

check( outfitTitle ~= nil and outfitTitle.parent == findButton( "shirt" ).parent, "the outfit title is in the outfit panel, hidden with the buttons" )

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

local panelBackground = stub.findObject( view, function( object )
	return object.kind == "roundedRect" and sameColor( object.fillColor, layout.palette.panelFill )
end )

local styleX, styleY = stub.contentPosition( styleButton )
local idleX, idleY = stub.contentPosition( idleButton )
local jumpX = stub.contentPosition( jumpButton )
local panelX, panelY = stub.contentPosition( panelBackground )
local _, titleY = stub.contentPosition( panelTitle )
local walkX = stub.contentPosition( walkButton )

local styleWidth = styleButton.background.width
local buttonWidth = idleButton.background.width
local buttonGap = ( walkX - buttonWidth * 0.5 ) - ( idleX + buttonWidth * 0.5 )
local panelLeft = panelX - panelBackground.width * 0.5
local panelRight = panelX + panelBackground.width * 0.5
local panelTop = panelY - panelBackground.height * 0.5
local panelBottom = panelY + panelBackground.height * 0.5
local styleLeft = styleX - styleWidth * 0.5
local styleRight = styleX + styleWidth * 0.5
local styleTop = styleY - styleButton.background.height * 0.5
local styleBottom = styleY + styleButton.background.height * 0.5

local floorBottom = floorLine.y + floorLine.height * 0.5

check( styleButton.label.text == "Switch animation style", "the style button reads Switch animation style" )
check( styleWidth > buttonWidth and styleButton.background.height > idleButton.background.height, "the style button is larger than the animation buttons" )
check( styleButton.label.size < idleButton.label.size, "the style button label is smaller than the animation button labels" )
check( styleButton.label.width <= styleWidth, "the style button label fits inside the button" )
check( styleRight < panelLeft, "the style button sits left of the animation panel" )
check( math.abs( ( panelLeft - styleRight ) - layout.ui.styleButtonGap ) < 0.001, "the style button and the panel are one style gap apart" )
check( buttonGap > 0, "the animation buttons do not touch" )
check( math.abs( ( styleLeft + panelRight ) * 0.5 - display.contentCenterX ) < 0.001, "the style button and the panel are centred horizontally as a row" )
check( styleY == panelY, "the style button and the panel share a centre line" )
check( idleButton.y == walkButton.y and walkButton.y == jumpButton.y, "the animation buttons share one centre line inside the panel" )
check( math.abs( panelBottom + layout.ui.bottomMargin - display.contentHeight ) < 0.001, "the bottom margin applies to the panel" )
check( panelTop > floorBottom, "the panel sits below the floor" )
check( styleTop > floorBottom and styleBottom <= panelBottom, "the style button sits below the floor and within the panel's height" )

check( panelTitle.font == layout.font.heading and panelTitle.size == layout.animationPanel.titleSize, "the panel title uses the layout font and size" )
check( sameColor( panelTitle.fillColor, layout.palette.textMuted ), "the panel title uses the muted colour" )
check( math.abs( stub.contentPosition( panelTitle ) - panelX ) < 0.001, "the panel title is centred on the panel" )
check( titleY < idleY - idleButton.background.height * 0.5, "the panel title sits above the animation buttons" )
check( titleY > panelTop, "the panel title sits inside the panel" )
check( idleX - buttonWidth * 0.5 >= panelLeft and jumpX + buttonWidth * 0.5 <= panelRight, "the animation buttons sit inside the panel" )
check( idleY + idleButton.background.height * 0.5 <= panelBottom, "the animation buttons end above the panel's bottom edge" )

for _, id in ipairs( { "idle", "walk", "jump" } ) do
	check( stub.contentPosition( findButton( id ) ) >= panelLeft, "the " .. id .. " button is not left of the panel" )
end

local shirtButton = findButton( "shirt" )
local pantsButton = findButton( "pants" )
local flowersButton = findButton( "flowers" )
local outfitPanel = shirtButton.parent
local outfitSettings = layout.outfitPanel

local outfitBackground = stub.findObject( outfitPanel, function( object )
	return object.kind == "roundedRect" and sameColor( object.fillColor, layout.palette.panelFill )
end )

local shirtX, shirtY = stub.contentPosition( shirtButton )
local pantsX, pantsY = stub.contentPosition( pantsButton )
local flowersX, flowersY = stub.contentPosition( flowersButton )
local outfitTitleX, outfitTitleY = stub.contentPosition( outfitTitle )
local outfitPanelX, outfitPanelY = stub.contentPosition( outfitBackground )
local outfitWidth = shirtButton.background.width
local outfitHeight = shirtButton.background.height
local outfitPanelWidth = outfitBackground.width
local outfitPanelLeft = outfitPanelX - outfitPanelWidth * 0.5
local outfitPanelRight = outfitPanelX + outfitPanelWidth * 0.5
local outfitPanelTop = outfitPanelY - outfitBackground.height * 0.5
local outfitPanelBottom = outfitPanelY + outfitBackground.height * 0.5
local floorTop = floorLine.y - floorLine.height * 0.5
local floorRight = floorLine.x + floorLine.width * 0.5
local _, captionY = stub.contentPosition( caption )

-- The skeletal canvas, centred on the character, bounds every pose the rig draws.
local characterRight = stub.contentPosition( rig ) + manifest.canvas.width * animations.scale * 0.5

check( shirtX == pantsX and pantsX == flowersX and shirtX == outfitPanelX, "the outfit buttons share one column, centred in the panel" )
check( shirtY < pantsY and pantsY < flowersY, "the outfit buttons stack shirt, pants, flowers from the top" )

local isOneGapApart = math.abs( ( pantsY - shirtY ) - ( outfitHeight + outfitSettings.buttonGap ) ) < 0.001
check( isOneGapApart and math.abs( ( flowersY - pantsY ) - ( pantsY - shirtY ) ) < 0.001, "the outfit buttons are one gap apart" )

check( outfitBackground ~= nil and outfitBackground.parent == outfitPanel, "the outfit panel has its own background" )
check( sameColor( outfitBackground.strokeColor, layout.palette.panelBorder ), "the outfit panel shares the animation panel's border" )
check( outfitBackground.cornerRadius == panelBackground.cornerRadius, "the outfit panel shares the animation panel's corner radius" )
check( math.abs( outfitPanelRight + outfitSettings.rightMargin - display.contentWidth ) < 0.001, "the outfit panel keeps its margin from the right edge" )
check( outfitPanelLeft > floorRight and outfitPanelLeft > characterRight, "the outfit panel sits right of the floor and the character" )
check( math.abs( outfitPanelBottom + outfitSettings.floorOffset - floorTop ) < 0.001, "the outfit panel ends its floor offset above the floor line" )
check( outfitPanelBottom < panelTop and outfitPanelTop > captionY + layout.caption.size, "the outfit panel sits between the caption and the bottom panel" )

check( outfitTitle.font == panelTitle.font and outfitTitle.size == panelTitle.size, "the outfit title uses the animation panel title's font and size" )
check( sameColor( outfitTitle.fillColor, layout.palette.textMuted ), "the outfit title uses the muted colour" )
check( math.abs( outfitTitleX - outfitPanelX ) < 0.001, "the outfit title is centred on the panel" )
check( outfitTitleY - outfitPanelTop == titleY - panelTop, "the outfit title sits as far below the panel top as the animation panel title" )
check( outfitTitleY + outfitTitle.size * 0.5 < shirtY - outfitHeight * 0.5, "the outfit title sits above the outfit buttons" )

local outfitButtonsLeft = shirtX - outfitWidth * 0.5
local outfitButtonsRight = shirtX + outfitWidth * 0.5
local isInsidePanel = outfitButtonsLeft > outfitPanelLeft and outfitButtonsRight < outfitPanelRight
check( isInsidePanel and flowersY + outfitHeight * 0.5 < outfitPanelBottom, "the outfit buttons sit inside the panel" )

local shirtBackground = shirtButton.background
local hasLayoutSize = shirtBackground.width == outfitSettings.buttonWidth and outfitHeight == outfitSettings.buttonHeight
check( hasLayoutSize and shirtButton.label.size == outfitSettings.fontSize, "the outfit buttons use the layout size and font size" )
check( shirtButton.label.size < idleButton.label.size, "the outfit labels are smaller than the animation button labels" )

-- The stub estimates text width from the character count, which overestimates Roboto Bold at these sizes.
local longestLabel = 0

for _, labels in pairs( strings.outfitButtonLabel ) do
	for _, label in pairs( labels ) do
		longestLabel = math.max( longestLabel, #label * outfitSettings.fontSize * 0.52 )
	end
end

check( longestLabel < outfitWidth, "the longest outfit label fits inside its button" )
check( #strings.outfitPanelTitle * outfitTitle.size * 0.52 < outfitPanelWidth, "the outfit title fits inside its panel" )

local hasButtonLook = sameColor( shirtBackground.strokeColor, layout.palette.buttonBorder )
hasButtonLook = hasButtonLook and sameColor( shirtBackground.fillColor, layout.palette.buttonFill )
check( hasButtonLook, "the outfit buttons share the button fill and border" )

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
check( sameColor( walkButton.background.fillColor, layout.palette.buttonActiveFill ), "the walk button stays highlighted across the style change" )
checkStyleButtonPlain()

-- Called after every frame the checks below play, when set.
local afterFrame

local function playFrames( count )
	for _ = 1, count do
		stub.advanceFrame( frameMs )

		if afterFrame then
			afterFrame()
		end
	end
end

-- Plays frames until the skeletal character starts another animation. Returns the seconds it took.
local function playUntilSwitch()
	local startClock = stub.clock
	local playing = rig._currentAnimation

	for _ = 1, maxFramesPerSwitch do
		stub.advanceFrame( frameMs )

		if afterFrame then
			afterFrame()
		end

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
	-- Less whatever the variant has already played, when frames ran before this call.
	local expectedSeconds = plays * playing.frameCount / playing.fps - rig._elapsedTime
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

--------------------------------------------------------------------------------------
-- Outfit

local function partImage( name )
	return animations.skeletal.path .. "/parts/" .. name .. ".png"
end

-- What each recoloured part shows per shirt and trousers, written out apart from data/outfits.lua.
local recolours = {
	torso = { ["red/blue"] = "torso_red_shirt", ["yellow/grey"] = "torso_grey_pants", ["red/grey"] = "torso_red_shirt_grey_pants" },
	arm_near_upper = { ["red/blue"] = "arm_near_upper_red_shirt", ["red/grey"] = "arm_near_upper_red_shirt" },
	arm_far_upper = { ["red/blue"] = "arm_far_upper_red_shirt", ["red/grey"] = "arm_far_upper_red_shirt" },
	leg_near_upper = { ["yellow/grey"] = "leg_near_upper_grey_pants", ["red/grey"] = "leg_near_upper_grey_pants" },
	leg_near_lower = { ["yellow/grey"] = "leg_near_lower_grey_pants", ["red/grey"] = "leg_near_lower_grey_pants" },
	leg_far_upper = { ["yellow/grey"] = "leg_far_upper_grey_pants", ["red/grey"] = "leg_far_upper_grey_pants" },
	leg_far_lower = { ["yellow/grey"] = "leg_far_lower_grey_pants", ["red/grey"] = "leg_far_lower_grey_pants" },
}

local recolouredParts = { "torso", "arm_near_upper", "arm_far_upper", "leg_near_upper", "leg_near_lower", "leg_far_upper", "leg_far_lower" }

-- The image the near hand's state in the current frame names, read from the manifest.
local function handStateImage()
	local frame = rig._currentAnimation.frames[rig._currentFrameIndex + 1]

	return partImage( "hand_near_" .. frame.partsMap.hand_near.state )
end

local function childIndex( object )
	for i = 1, rig.numChildren do
		if rig[i] == object then
			return i
		end
	end

	return nil
end

-- Every mismatch between what the rig draws and the outfit, or an empty list.
local function outfitMismatches( shirt, pants, isHolding )
	local mismatches = {}
	local key = shirt .. "/" .. pants

	for i = 1, #recolouredParts do
		local partId = recolouredParts[i]
		local expected = partImage( recolours[partId][key] or partId )
		local shown = rig._partObjects[partId].filename

		if shown ~= expected then
			mismatches[#mismatches + 1] = partId .. " shows " .. tostring( shown ) .. ", expected " .. expected
		end
	end

	local bouquet = rig._partObjects.bouquet
	local hand = rig._partObjects.hand_near
	local isBouquetShown = bouquet ~= nil and bouquet.isVisible

	if isBouquetShown ~= isHolding then
		mismatches[#mismatches + 1] = "the bouquet is " .. ( isBouquetShown and "shown" or "hidden" )
	end

	local expectedHand = isHolding and partImage( "hand_near_fist" ) or handStateImage()

	if hand.filename ~= expectedHand then
		mismatches[#mismatches + 1] = "hand_near shows " .. tostring( hand.filename ) .. ", expected " .. expectedHand
	end

	if isHolding and childIndex( bouquet ) ~= childIndex( hand ) - 1 then
		mismatches[#mismatches + 1] = "the bouquet is not drawn directly behind hand_near"
	end

	return mismatches
end

local function checkOutfit( shirt, pants, isHolding, what )
	local mismatches = outfitMismatches( shirt, pants, isHolding )
	check( #mismatches == 0, what .. ": " .. table.concat( mismatches, "; " ) )
end

checkOutfit( "yellow", "blue", false, "the skeletal character starts in the drawn outfit" )
check( rig._partObjects.bouquet == nil or not rig._partObjects.bouquet.isVisible, "the bouquet starts hidden" )

-- Every combination in turn, one press apart: shirt, pants, shirt, flowers, shirt, pants, shirt.
local outfitPresses = {
	{ "shirt", "red", "blue", false },
	{ "pants", "red", "grey", false },
	{ "shirt", "yellow", "grey", false },
	{ "flowers", "yellow", "grey", true },
	{ "shirt", "red", "grey", true },
	{ "pants", "red", "blue", true },
	{ "shirt", "yellow", "blue", true },
}

for i = 1, #outfitPresses do
	local press = outfitPresses[i]
	local what = "after pressing " .. press[1] .. " (" .. press[2] .. " shirt, " .. press[3] .. " trousers, " .. ( press[4] and "bouquet" or "no bouquet" ) .. ")"

	playFrames( 7 )

	local animationBefore = rig._currentAnimation
	local elapsedBefore = rig._elapsedTime
	local frameBefore = rig._currentFrameIndex
	local captionBefore = caption.text

	check( pressButton( press[1] ) == findButton( press[1] ), "the " .. press[1] .. " button receives its press" )
	checkOutfit( press[2], press[3], press[4], what )
	checkOutfitLabels( press[2], press[3], press[4], what )

	local isUnchanged = rig._currentAnimation == animationBefore and rig._elapsedTime == elapsedBefore and rig._currentFrameIndex == frameBefore
	check( isUnchanged and rig._isPlaying, "the animation carries on without a restart " .. what )
	check( caption.text == captionBefore and heading.text == strings.heading.skeletal, "the caption and heading stay " .. what )

	local flowersFill = press[4] and layout.palette.buttonActiveFill or layout.palette.buttonFill
	check( sameColor( flowersButton.background.fillColor, flowersFill ), "the flowers button is " .. ( press[4] and "active" or "plain" ) .. " " .. what )

	local isShirtPlain = sameColor( shirtButton.background.fillColor, layout.palette.buttonFill )
	local arePlain = isShirtPlain and sameColor( pantsButton.background.fillColor, layout.palette.buttonFill )
	check( arePlain, "the shirt and pants buttons stay plain " .. what )
	check( sameColor( walkButton.background.fillColor, layout.palette.buttonActiveFill ), "the walk button stays highlighted " .. what )
	check( outfitPanel.isVisible and rig.isVisible and not sprite.isVisible, "an outfit press does not change the style " .. what )
	check( stub.pendingTimerCount() == 0, "an outfit press needs no timer " .. what )
end

pressButton( "shirt" )
pressButton( "pants" )
checkOutfit( "red", "grey", true, "red shirt, grey trousers and the bouquet" )

-- From here every frame drawn checks the outfit, until the bouquet is put down again.
local outfitFramesChecked = 0
local outfitFrameFailure

function afterFrame()
	if not rig._isPlaying then
		return
	end

	outfitFramesChecked = outfitFramesChecked + 1

	local mismatches = outfitMismatches( "red", "grey", true )

	if #mismatches > 0 and not outfitFrameFailure then
		outfitFrameFailure = rig._currentAnimation.name .. " frame " .. rig._currentFrameIndex .. ": " .. table.concat( mismatches, "; " )
	end
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

afterFrame = nil
check( outfitFramesChecked > 1000, "the outfit is checked on every frame of every variant, " .. outfitFramesChecked .. " frames" )
check( outfitFrameFailure == nil, "the outfit and the fist hold on every frame: " .. tostring( outfitFrameFailure ) )
check( caption.text == captionFor( "idle", 1 ), "the variant cycling and captions run as before with the outfit changed" )

pressButton( "flowers" )
checkOutfit( "red", "grey", false, "the bouquet put down again" )
check( sameColor( flowersButton.background.fillColor, layout.palette.buttonFill ), "the flowers button is plain once the bouquet is put down" )
playFrames( 60 )
checkOutfit( "red", "grey", false, "the near hand follows its frame states again without the bouquet" )

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
	checkTapIgnored( panelX, panelTop + layout.animationPanel.titleOffset, "the panel title" .. suffix )
	checkTapIgnored( panelX, floorBottom + ( panelTop - floorBottom ) * 0.5, "the gap above the panel" .. suffix )
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
checkStyleButtonPlain()

checkTapsIgnored( " in sprite style" )

check( not outfitPanel.isVisible, "the outfit panel, its title and its buttons hide while frame-by-frame shows" )

for i = 1, #outfitIds do
	local x, y = stub.contentPosition( findButton( outfitIds[i] ) )
	checkTapIgnored( x, y, "the hidden " .. outfitIds[i] .. " button" )
end

playFrames( 400 )
check( stub.pendingTimerCount() == 0, "the paused skeletal character schedules no switch" )

-- Switching style starts the skeletal side again from variant 1.
pressButton( "style" )
check( rig._currentAnimation.name == "jump_1" and rig._elapsedTime == 0, "a style change starts the skeletal side from jump_1" )
check( caption.text == captionFor( "jump", 1 ), "the caption reads variant 1 after a style change" )
check( outfitPanel.isVisible, "the outfit panel shows again with the skeletal character" )
checkOutfit( "red", "grey", false, "the outfit survives a trip to frame-by-frame and back" )
checkOutfitLabels( "red", "grey", false, "after a trip to frame-by-frame and back" )
check( pressButton( "flowers" ) == flowersButton, "the flowers button works again after a style change" )
checkOutfit( "red", "grey", true, "the bouquet back in hand after a style change" )
checkOutfitLabels( "red", "grey", true, "with the bouquet back in hand" )
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
local _, resizedPanelY = stub.contentPosition( panelBackground )
local resizedBottom = resizedStyleY + layout.animationPanel.height * 0.5

check( math.abs( resizedBottom + layout.ui.bottomMargin - 680 ) < 0.001, "a resize keeps the row on the bottom of the visible screen" )
check( resizedPanelY == resizedStyleY, "a resize keeps the row on one centre line" )

display.screenOriginY = 0
display.actualContentHeight = 640
stub.fire( "resize" )

-- A 16:9 window shows 640 * 16 / 9 content units across, extending past each side edge.
local wideWidth = 640 * 16 / 9
display.screenOriginX = ( display.contentWidth - wideWidth ) * 0.5
display.actualContentWidth = wideWidth
stub.fire( "resize" )

local wideShirtX, wideShirtY = stub.contentPosition( shirtButton )
local widePanelX = stub.contentPosition( outfitBackground )
local wideRight = display.contentWidth - display.screenOriginX
local wideGap = wideRight - ( widePanelX + outfitPanelWidth * 0.5 )
local _, wideRowY = stub.contentPosition( panelBackground )
check( math.abs( wideGap - outfitSettings.rightMargin ) < 0.001, "a wider window keeps the outfit panel on the visible right edge" )
check( wideShirtY == shirtY and wideShirtX == widePanelX, "a wider window keeps the outfit panel at its height, buttons centred" )
local isWideClear = widePanelX - outfitPanelWidth * 0.5 > floorRight and wideRowY == panelY
check( isWideClear, "a wider window keeps the outfit panel clear of the floor and the bottom panel" )

display.screenOriginX = 0
display.actualContentWidth = 960
stub.fire( "resize" )
check( stub.contentPosition( shirtButton ) == shirtX, "the outfit panel returns after the window narrows back" )

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
