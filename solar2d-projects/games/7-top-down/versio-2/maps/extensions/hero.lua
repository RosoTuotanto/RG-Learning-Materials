-- Pelaajahahmon extension ponytiled-kartalle.
-- ponytiled kutsuu M.new-funktiota jokaiselle kartan "hero"-tyyppiselle objektille
-- ja korvaa alkuperäisen Tiled-objektin tämän funktion palauttamalla objektilla.

local M = {}

--------------------------------------------------------------------------------------

function M.new( instance )
	-- Otetaan talteen sijainti ja layer, joihin ponytiled asetti hahmon.
	local parentLayer = instance.parent
	local x, y = instance.x, instance.y

	-- Poistetaan Tiledin luoma placeholder-objekti. Rakennamme tilalle oman.
	display.remove( instance )

	-- Ladataan hahmojen image sheet. Frame 1 on pelaajahahmo.
	local sheetOptions = {
		width = 32,
		height = 32,
		numFrames = 6,
		sheetContentWidth = 192,
		sheetContentHeight = 32,
	}
	local characterSheet = graphics.newImageSheet( "maps/characters.png", sheetOptions )

	-- Rakennetaan hahmo omaan ryhmäänsä. Ryhmän sisällä oleva sprite voidaan
	-- myöhemmin esimerkiksi flipata tai pompauttaa liikkeen tuntua varten.
	local hero = display.newGroup()
	hero.sprite = display.newImageRect( hero, characterSheet, 1, 32, 32 )
	parentLayer:insert( hero )
	hero.x, hero.y = x, y

	hero.name = "hero"
	hero.type = "hero"
	hero.speed = 120

	-- Tehdään hahmosta dynaaminen fysiikkaobjekti, jotta seinät pysäyttävät sen.
	-- Pyöreä fysiikkaobjekti liukuu seinien kulmia pitkin luontevasti.
	physics.addBody( hero, "dynamic", { radius = 12, density = 1, friction = 0, bounce = 0 } )
	-- Estetään hahmoa pyörähtämästä, kun se törmää seinään.
	hero.isFixedRotation = true

	return hero
end

--------------------------------------------------------------------------------------

return M
