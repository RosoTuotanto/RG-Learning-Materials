-- Self-test: removes the key listener in hide did but forgets the enterFrame one, so the harness must fail.

local composer = require( "composer" )

local scene = composer.newScene()

local function onFrame() end

local function onKey()
	return false
end

function scene:show( event )
	if event.phase == "did" then
		Runtime:addEventListener( "enterFrame", onFrame )
		Runtime:addEventListener( "key", onKey )
	end
end

function scene:hide( event )
	if event.phase == "did" then
		Runtime:removeEventListener( "key", onKey )
	end
end

scene:addEventListener( "show", scene )
scene:addEventListener( "hide", scene )

return scene
