-- Self-test: uses the stubbed APIs the samples rely on and checks the stub's own behaviour; the harness must print OK.

local composer = require( "composer" )
local physics = require( "physics" )
local json = require( "json" )

local scene = composer.newScene()

local worldGroup
local player
local hero
local floor
local frameCount = 0
local checks = {}
local tapTimer
local loopTransition
local musicChannel
local beepSound
local touchPhases = {}

local function check( condition, message )
	if not condition then
		error( "selftest check failed: " .. message, 2 )
	end
end

local function onFrame()
	frameCount = frameCount + 1
	worldGroup.x = -player.x + display.contentCenterX
end

local function onKey( event )
	checks.keys = ( checks.keys or 0 ) + 1

	return event.keyName == "space"
end

local function onMouse( event )
	local x, y = worldGroup:contentToLocal( event.x, event.y )
	checks.mouse = x ~= nil and y ~= nil
end

local function onPlayerCollision( event )
	if event.phase == "began" and event.other == floor then
		checks.landed = true
		check( not pcall( physics.addBody, display.newRect( worldGroup, 0, 0, 4, 4 ), "static" ), "addBody inside a collision must fail" )
	end
end

local function onHeroTouch( event )
	touchPhases[#touchPhases + 1] = event.phase

	if event.phase == "began" then
		display.getCurrentStage():setFocus( event.target )

	elseif event.phase == "ended" then
		display.getCurrentStage():setFocus( nil )
	end

	return true
end

function scene:create( event )
	local sceneGroup = self.view

	worldGroup = display.newGroup()
	sceneGroup:insert( worldGroup )

	local container = display.newContainer( sceneGroup, 200, 100 )
	container.x, container.y = 480, 320

	local line = display.newLine( container, 0, 0, 10, 10 )
	line:append( 20, 0, 30, 10 )
	line:setStrokeColor( 1, 0, 0 )
	line.strokeWidth = 2
	check( line.width == 30, "line width follows appended points" )

	local polygon = display.newPolygon( sceneGroup, 100, 100, { 0, -10, 10, 10, -10, 10 } )
	polygon:setFillColor( 0.5 )

	local label = display.newText({
		parent = sceneGroup, text = "Hello", x = 480, y = 600, width = 300,
		font = "assets/fonts/roboto/Roboto-Bold.ttf", fontSize = 20, align = "center",
	})
	label.text = "Changed"
	check( label.width == 300, "wrapped text keeps its width" )

	local embossed = display.newEmbossedText( sceneGroup, "Emboss", 480, 560, native.systemFont, 18 )
	embossed:setEmbossColor({ highlight = { r = 1, g = 1, b = 1 }, shadow = { r = 0, g = 0, b = 0 } })

	display.setDefault( "magTextureFilter", "nearest" )
	local sheet = graphics.newImageSheet( "../animations/assets/images/character-sheet.png", { width = 1, height = 1, numFrames = 4 } )
	local sprite = display.newSprite( sceneGroup, sheet, { { name = "idle", frames = { 1, 2 }, time = 200 }, { name = "run", start = 1, count = 4, time = 300 } } )
	sprite:setSequence( "run" )
	sprite:play()
	display.newImageRect( sceneGroup, sheet, 3, 32, 32 )
	display.newImageRect( sceneGroup, "samples/selftest/assets/images/missing.png", 32, 32 )
	display.setDefault( "magTextureFilter", "linear" )

	hero = display.newCircle( worldGroup, 300, 200, 20 )
	hero:addEventListener( "touch", onHeroTouch )

	local rounded = display.newRoundedRect( sceneGroup, 800, 500, 120, 40, 8 )
	rounded.fill = { type = "gradient", color1 = { 1, 0, 0 }, color2 = { 0, 0, 1 } }
	rounded.fill.effect = "filter.blur"
	rounded.fill.effect.size = 4

	player = display.newRect( worldGroup, 480, 100, 32, 48 )
	floor = display.newRect( worldGroup, 480, 400, 2000, 20 )

	worldGroup.x = -100
	local localX = worldGroup:contentToLocal( 0, 0 )
	check( localX == 100, "contentToLocal undoes the group offset" )

	beepSound = audio.loadSound( "samples/selftest/assets/audio/missing.wav" )

	local path = system.pathForFile( "selftest.json", system.DocumentsDirectory )
	local file = io.open( path, "w" )
	file:write( json.encode({ found = { "a", "b" }, count = 2, nested = { flag = true } }) )
	file:close()

	file = io.open( path, "r" )
	local data = json.decode( file:read( "*a" ) )
	file:close()
	check( data.count == 2 and data.found[2] == "b" and data.nested.flag == true, "json round trip through Documents" )
	check( system.pathForFile( "no-such-file.txt" ) == nil, "missing resource path is nil" )
	check( table.indexOf( { "x", "y" }, "y" ) == 2, "table.indexOf" )
end

function scene:show( event )
	if event.phase == "did" then
		physics.start()
		physics.setGravity( 0, 9.8 )
		physics.addBody( floor, "static" )
		physics.addBody( player, "dynamic", { density = 1 }, { box = { halfWidth = 10, halfHeight = 4, y = 24 }, isSensor = true } )
		player.isFixedRotation = true
		player:addEventListener( "collision", onPlayerCollision )
		player:applyLinearImpulse( 0.5, 0 )

		local hits = physics.rayCast( 480, 0, 480, 500, "sorted" )
		check( hits and hits[1].object == player, "rayCast hits the player first" )
		check( physics.queryRegion( 0, 390, 960, 410 ) ~= nil, "queryRegion finds the floor" )

		Runtime:addEventListener( "enterFrame", onFrame )
		Runtime:addEventListener( "key", onKey )
		Runtime:addEventListener( "mouse", onMouse )

		tapTimer = timer.performWithDelay( 100, function( timerEvent )
			checks.timerCount = timerEvent.count
		end, 0 )

		transition.to( hero, { time = 300, x = 400, transition = easing.outQuad, onComplete = function()
			checks.transitionDone = true
		end } )

		loopTransition = transition.to( hero, { time = 200, alpha = 0.5, iterations = -1 } )

		musicChannel = audio.play( beepSound, { loops = -1 } )
		audio.play( beepSound, { onComplete = function( audioEvent )
			checks.audioDone = audioEvent.completed
		end } )
	end
end

function scene:hide( event )
	if event.phase == "will" then
		timer.cancel( tapTimer )
		transition.cancel( loopTransition )
		audio.stop( musicChannel )
		physics.pause()

	elseif event.phase == "did" then
		Runtime:removeEventListener( "enterFrame", onFrame )
		Runtime:removeEventListener( "key", onKey )
		Runtime:removeEventListener( "mouse", onMouse )

		check( frameCount > 0, "enterFrame ran" )
		check( checks.keys and checks.keys > 0, "key events arrived" )
		check( checks.mouse, "mouse events arrived" )
		check( checks.landed, "the player's collision with the floor began" )
		check( checks.timerCount and checks.timerCount > 10, "the repeating timer fired" )
		check( checks.transitionDone, "transition onComplete fired" )
		check( checks.audioDone == true, "audio onComplete fired" )
		check( #touchPhases >= 4, "the touch pass reached the hero" )
	end
end

function scene:destroy()
	worldGroup, player, hero, floor = nil, nil, nil, nil
end

scene:addEventListener( "create", scene )
scene:addEventListener( "show", scene )
scene:addEventListener( "hide", scene )
scene:addEventListener( "destroy", scene )

return scene
