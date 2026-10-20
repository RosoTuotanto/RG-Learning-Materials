-- Ladataan Composer, jotta voimme käyttää sen funktioita.
local composer = require( "composer" )

-- Luodaan uusi scene-objekti.
local scene = composer.newScene()

--------------------------------------------------------------------------------------

function scene:show( event )
	local sceneGroup = self.view
	local phase = event.phase

	if ( phase == "did" ) then
		-- Ajetaan heti kun scene näkyy pelaajalle.

		composer.removeScene( "scenes.game" )

		composer.gotoScene( "scenes.game", { effect = "fade", time = 200, params = {
			level = event.params.level
		} } )
	end
end

--------------------------------------------------------------------------------------
-- Scene event -listenerit:
-- Voit valita mitä eventtejä haluat kuunnella. Jos et esimerkiksi koskaan
-- poista sceneä, niin silloin "destroy" ei välttämättä ole tarpeellinen.
--------------------------------------------------------------------------------------
scene:addEventListener( "show", scene )
--------------------------------------------------------------------------------------

-- Lopuksi palautetaan scene, jolloin tiedosto toimii Lua-moduulina.
return scene