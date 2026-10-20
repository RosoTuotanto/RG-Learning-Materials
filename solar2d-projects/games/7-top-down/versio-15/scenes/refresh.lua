-- Refresh-scene kenttien vaihtoon. Poistaa game-scenen ja avaa sen heti uudelleen,
-- jolloin scene:create ajetaan alusta ja uusi kartta rakentuu puhtaalta pöydältä.
-- Emme voi ladata game-sceneä suoraan itsensä päälle, joten teemme sen tämän
-- refresh-scenen kautta.

-- Ladataan Composer, jotta voimme käyttää sen funktioita.
local composer = require( "composer" )

-- Luodaan uusi scene-objekti.
local scene = composer.newScene()

--------------------------------------------------------------------------------------

-- show: kutsutaan kun scene on luotu mutta ei vielä näytetty.
function scene:show( event )
	local phase = event.phase

	if ( phase == "will" ) then
		-- Poistetaan vanha game-scene, jotta se rakennetaan kokonaan uudelleen.
		composer.removeScene( "scenes.game" )

	elseif ( phase == "did" ) then
		-- Palataan game-sceneen ja välitetään siirtymän tiedot eteenpäin.
		composer.gotoScene( "scenes.game", { params = event.params } )

	end
end

--------------------------------------------------------------------------------------

scene:addEventListener( "show", scene )

-- Lopuksi palautetaan scene, jolloin tiedosto toimii Lua-moduulina.
return scene
