-- "Lepakko": leijuu paikallaan idle-tilassa ja hyökkää pelaajan kimppuun attack-tilassa.

local enemy = {}

local physics = require( "physics" )

----------------------------------------------------------------------------------

-- Lepakko käyttää samoja suunnan kertovia ääniä kuin opetuspelin hattuvihollinen.
local sfx = {
	left = audio.loadSound( "assets/audio/sfx/hatLeft.wav" ),
	right = audio.loadSound( "assets/audio/sfx/hatRight.wav" ),
	center = audio.loadSound( "assets/audio/sfx/hatCenter.wav" ),
}

local sheet = graphics.newImageSheet( "assets/images/characters/characters.png", {
	width = 24,
	height = 24,
	numFrames = 10
} )


-- Framet 3-5 ovat lepakon siivenlyönti, joka toistuu jatkuvasti.
local animation = {
	{
		name = "fly",
		start = 3,
		count = 3,
		time = 300,
		loopCount = 0,
		loopDirection = "forward"
	}
}

----------------------------------------------------------------------------------

local aiConfig = {
	-- Alle tämän etäisyyden lepakko vaihtaa idle-tilasta attack-tilaan.
	attackRadius = 100,
	-- Yli tämän etäisyyden lepakko palaa attack-tilasta idle-tilaan.
	-- Isompi kuin attackRadius, jotta tila ei vaihtele edestakaisin rajalla.
	leaveRadius = 170,
	-- Hyökkäysnopeus pikseleinä sekunnissa.
	attackSpeed = 120,
	-- Leijunnan pystyliikkeen nopeus ja voimakkuus.
	hoverSpeed = 0.08,
	hoverVelocity = 40,
	-- Kuinka monen framen välein suunnan kertova ääni soitetaan hyökätessä.
	sfxInterval = 70,
	-- Etäisyys, jolla hyökkäysääni on hiljaisimmillaan (puolet täydestä äänenvoimakkuudesta).
	soundMaxDistance = 170,
}

-- Soitetaan suunnan ja etäisyyden mukaan panoroitu ääni (sama logiikka kuin hatussa).
local function playSFX( dx, distance )
	local maxDistance = aiConfig.soundMaxDistance
	local minDistance = 20

	local volumeMultiplier = 1 - (math.max( math.min( distance, maxDistance ), minDistance ) - minDistance) / (maxDistance - minDistance) * 0.5
	local whichSFX

	local xDistance = math.abs( dx )
	if xDistance < 20 then
		whichSFX = sfx.center

	-- Jos dx on positiivinen, niin lepakko on pelaajan vasemmalla puolella.
	elseif dx > 0 then
		whichSFX = sfx.left

	-- Muuten lepakko on pelaajan oikealla puolella.
	else
		whichSFX = sfx.right

	end

	local availableChannel = audio.findFreeChannel( 2 ) -- 1. kanava on varattu musiikille
	local channelVolume = audio.getVolume( { channel = availableChannel } )

	audio.setVolume( channelVolume*volumeMultiplier, { channel = availableChannel } )

	audio.play( whichSFX, {
		channel = availableChannel,
		onComplete = function()
			audio.setVolume( channelVolume, { channel = availableChannel } )
		end
	} )
end

----------------------------------------------------------------------------------

function enemy.new( parent, reference )
	-- Otetaan talteen lepakon alkuperäinen sijainti kartalla.
	local x, y, id = reference.x, reference.y, reference.id
	display.remove( reference )

	local character = display.newSprite( parent, sheet, animation )
	character.x, character.y = x, y
	character.id = id
	character.isEnemy = true

	-- Kinemaattinen sensori, jotta lepakkoa voi liikuttaa fysiikoilla.
	physics.addBody( character, "kinematic", {
		isSensor = true,
	} )

	-- Käynnistetään jatkuvasti toistuva siivenlyöntianimaatio.
	character:setSequence( "fly" )
	character:play()

	-- AI-tilat:
	character.aiActive = false
	character.playerRef = nil
	character.state = "idle"
	character.hoverPhase = 0
	character.sfxTimer = 0

	-- Huom! updateAI rekisteröidään enterFrame-listeneriksi, jolloin self olisi event.
	-- Siksi viitataan hahmoon character-muuttujan kautta, kuten hattuvihollisessakin.
	function character:updateAI()
		-- Kuollutta pelaajaa ei enää jahdata, vaan palataan idle-tilaan.
		if character.playerRef.isDead then
			character.state = "idle"
			character:setLinearVelocity( 0, 0 )
			return
		end

		local dx = character.playerRef.x - character.x
		local dy = character.playerRef.y - character.y
		local distance = math.sqrt( dx*dx + dy*dy )

		if character.state == "idle" then
			-- Leijutaan paikallaan pystysuunnassa siniaallon mukaan.
			character.hoverPhase = character.hoverPhase + aiConfig.hoverSpeed
			character:setLinearVelocity( 0, math.sin( character.hoverPhase )*aiConfig.hoverVelocity )

			-- Pelaaja tuli tarpeeksi lähelle, hyökätään.
			if distance < aiConfig.attackRadius then
				character.state = "attack"
				playSFX( dx, distance )
				character.sfxTimer = aiConfig.sfxInterval
			end

		else
			-- Pelaaja pakeni tarpeeksi kauas, palataan idle-tilaan.
			if distance > aiConfig.leaveRadius then
				character.state = "idle"
				character:setLinearVelocity( 0, 0 )
			else
				-- Liikutaan suoraan pelaajaa kohti.
				if distance > 0 then
					character:setLinearVelocity(
						dx/distance*aiConfig.attackSpeed,
						dy/distance*aiConfig.attackSpeed
					)
				end

				-- Käännetään lepakko pelaajaa kohti.
				if dx ~= 0 then
					character.xScale = dx > 0 and 1 or -1
				end

				-- Soitetaan suunnan kertova ääni säännöllisin väliajoin hyökätessä.
				character.sfxTimer = character.sfxTimer - 1
				if character.sfxTimer <= 0 then
					playSFX( dx, distance )
					character.sfxTimer = aiConfig.sfxInterval
				end
			end
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
