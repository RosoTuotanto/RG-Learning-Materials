-- "Vihainen laatikko": putoaa pelaajan päälle ja pysähtyy ensimmäiseen tasoon.

local enemy = {}

local physics = require( "physics" )

----------------------------------------------------------------------------------

-- Laatikko käyttää olemassa olevaa hurt-ääntä pudotessaan.
local sfxDrop = audio.loadSound( "assets/audio/sfx/hurt.wav" )

local sheet = graphics.newImageSheet( "assets/images/characters/characters.png", {
	width = 24,
	height = 24,
	numFrames = 10
} )


-- Frame 9 = hymyilevä laatikko, frame 10 = irvistävä laatikko.
local animation = {
	{
		name = "smile",
		start = 9,
		count = 1
	},
	{
		name = "grimace",
		start = 10,
		count = 1
	}
}

----------------------------------------------------------------------------------

local aiConfig = {
	-- Kuinka leveältä alueelta laatikon alapuolelta pudotus laukeaa.
	triggerWidth = 24,
	-- Pelaaja voi laukaista pudotuksen myös olemalla tarpeeksi lähellä sivusta.
	triggerRadius = 44,
	-- Pudotusnopeus pikseleinä sekunnissa.
	dropSpeed = 600,
	-- Kuinka pitkälle alaspäin etsimme tasoa raycastilla.
	rayLength = 600,
	-- Kuinka lähelle tasoa laatikon täytyy tulla, että se napsahtaa paikalleen.
	stopDistance = 20
}

-- Etsitään raycastilla lähin fyysinen taso tai kentän reuna laatikon alapuolelta.
local function findGroundBelow( character )
	local startX = character.x
	local startY = character.y + character.height*0.5
	local endX = startX
	local endY = startY + aiConfig.rayLength

	local hits = physics.rayCast( startX, startY, endX, endY, "sorted" )
	if hits then
		for i = 1, #hits do
			local hit = hits[i]
			local id = hit.object.id
			if id == "platform" or id == "levelBorder" then
				return hit.position.y
			end
		end
	end

	return nil
end

----------------------------------------------------------------------------------

function enemy.new( parent, reference )
	-- Otetaan talteen laatikon alkuperäinen sijainti kartalla.
	local x, y, id = reference.x, reference.y, reference.id
	display.remove( reference )

	local character = display.newSprite( parent, sheet, animation )
	character.x, character.y = x, y
	character.id = id
	character.isEnemy = true

	-- Kinemaattinen sensori, jotta laatikkoa voi liikuttaa mutta se ei tönäise pelaajaa.
	physics.addBody( character, "kinematic", {
		isSensor = true,
	} )

	character:setSequence( "smile" )

	-- AI-tilat:
	character.aiActive = false
	character.playerRef = nil
	character.hasDropped = false
	character.landed = false

	-- Huom! updateAI rekisteröidään enterFrame-listeneriksi, jolloin self olisi event.
	-- Siksi viitataan hahmoon character-muuttujan kautta, kuten hattuvihollisessakin.
	function character:updateAI()
		if character.landed then
			return
		end

		if not character.hasDropped then
			local dx = character.playerRef.x - character.x
			local dy = character.playerRef.y - character.y

			-- Pelaaja on laatikon alapuolella ja vaakasuunnassa riittävän kohdalla,
			-- tai muuten vain riittävän lähellä laatikkoa.
			local isBelow = math.abs( dx ) < aiConfig.triggerWidth and dy > 0
			local isClose = (dx*dx + dy*dy) < aiConfig.triggerRadius^2

			if isBelow or isClose then
				character.hasDropped = true
				character:setSequence( "grimace" )
				audio.play( sfxDrop, {
					channel = audio.findFreeChannel( 2 ),
				})
			end

			return
		end

		-- Laatikko putoaa, kunnes se saavuttaa alapuolisen tason.
		local groundY = findGroundBelow( character )
		if groundY and (groundY - (character.y + character.height*0.5)) <= aiConfig.stopDistance then
			character.y = groundY - character.height*0.5
			character:setLinearVelocity( 0, 0 )
			character.landed = true
		else
			character:setLinearVelocity( 0, aiConfig.dropSpeed )
		end
	end

	function character:startAI( player )
		if self.aiActive then
			print( "AI is already running" )
			return
		end

		self.playerRef = player
		self.aiActive = true
		Runtime:addEventListener( "enterFrame", character.updateAI )
	end

	function character:stopAI( fromFinalize )
		if not self.aiActive then
			if not fromFinalize then
				print( "AI is not running" )
			end
			return
		end

		self.aiActive = false
		Runtime:removeEventListener( "enterFrame", character.updateAI )
	end

	-- Jos hahmo tuhotaan, niin varmistetaan, että sen tekoäly pysähtyy.
	function character:finalize()
		self:stopAI( true )
	end

	character:addEventListener( "finalize" )

	return character
end

return enemy
