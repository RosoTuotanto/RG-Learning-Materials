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
	hero.speed = 160

	-- Tehdään hahmosta dynaaminen fysiikkaobjekti, jotta seinät pysäyttävät sen.
	-- Pyöreä fysiikkaobjekti liukuu seinien kulmia pitkin luontevasti.
	physics.addBody( hero, "dynamic", { radius = 12, density = 1, friction = 0, bounce = 0 } )
	-- Estetään hahmoa pyörähtämästä, kun se törmää seinään.
	hero.isFixedRotation = true

	-- Liikutetaan hahmoa ohjaimelta saadulla suuntavektorilla. Suuntavektori
	-- on jo normalisoitu, joten kerromme sen vain hahmon nopeudella.
	function hero:move( directionX, directionY )
		self.directionX = directionX
		self.directionY = directionY
		self:setLinearVelocity( directionX * self.speed, directionY * self.speed )
	end

	-- Pysäytetään hahmo kokonaan.
	function hero:stop()
		self.directionX = 0
		self.directionY = 0
		self:setLinearVelocity( 0, 0 )
	end

	-- Kevyt liikkeen tuntu ilman kävelyanimaation frameja: hahmo kääntyy
	-- vaakasuunnassa liikkeen mukaan ja pomppii kahden asennon välillä.
	local bobHeight = 3
	local bobInterval = 6
	local bobCounter = 0
	local isBobbingUp = false

	local function animate()
		local directionX = hero.directionX or 0
		local directionY = hero.directionY or 0
		local isMoving = directionX ~= 0 or directionY ~= 0

		-- Flipataan hahmo katsomaan liikkeen suuntaan vaakatasossa.
		-- Pystysuora liike säilyttää edellisen katsomissuunnan.
		if directionX < 0 then
			hero.sprite.xScale = -1
		elseif directionX > 0 then
			hero.sprite.xScale = 1
		end

		if isMoving then
			-- Vaihdetaan pompun asentoa tasaisin väliajoin.
			bobCounter = bobCounter + 1
			if bobCounter >= bobInterval then
				bobCounter = 0
				isBobbingUp = not isBobbingUp
				hero.sprite.y = isBobbingUp and -bobHeight or 0
			end
		else
			-- Paikallaan hahmo palautetaan perusasentoon.
			bobCounter = 0
			isBobbingUp = false
			hero.sprite.y = 0
		end
	end
	Runtime:addEventListener( "enterFrame", animate )

	-- Siivotaan enterFrame-listener, kun hahmo poistetaan.
	function hero:finalize()
		Runtime:removeEventListener( "enterFrame", animate )
	end
	hero:addEventListener( "finalize" )

	return hero
end

--------------------------------------------------------------------------------------

return M
