-- Self-test: enterFrame raises an error, so the harness must fail with a traceback.

local composer = require( "composer" )

local scene = composer.newScene()

local function onFrame( event )
	if event.frame > 20 then
		error( "selftest: deliberate error in enterFrame" )
	end
end

function scene:show( event )
	if event.phase == "did" then
		Runtime:addEventListener( "enterFrame", onFrame )
	end
end

function scene:hide( event )
	if event.phase == "did" then
		Runtime:removeEventListener( "enterFrame", onFrame )
	end
end

scene:addEventListener( "show", scene )
scene:addEventListener( "hide", scene )

return scene
