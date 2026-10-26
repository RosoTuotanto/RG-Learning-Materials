local function touchButton( event )
	-- Kosketus alkaa, niin kasvata ympyrää 25%.
	if event.phase == "began" then
		event.target:scale( 1.25, 1.25 )

	-- Kosketus loppuu, niin palauta ympyrä alkuperäiseen kokoonsa.
	elseif event.phase == "ended" then
		event.target:scale( 0.8, 0.8 )

	end

	return true
end

local button = display.newCircle( display.contentCenterX, display.contentCenterY, 60 )
button:addEventListener( "touch", touchButton )

return button
