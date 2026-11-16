display.setStatusBar( display.HiddenStatusBar )

-- Valitaan, kumpi hahmomoduuli on käytössä. Vaihda tähän "scripts.skeletal", kun kokeilet skeletal-animaatiota.
local character = require( "scripts.frameByFrame" )

display.setDefault( "background", 0.17, 0.2, 0.25 )

-- Maan yläreuna, jonka päällä hahmon jalat seisovat.
local groundY = 500

local ground = display.newRect( display.contentCenterX, groundY, display.actualContentWidth, display.actualContentHeight )
ground.anchorY = 0
ground:setFillColor( 0.12, 0.14, 0.17 )

-- Hahmon kuvan keskikohta on 61 pikseliä jalkojen yläpuolella.
local player = character.new( display.contentCenterX, groundY - 61 )

-- Juoksuanimaatiossa jalka siirtyy 12 pikseliä jokaisen 70 millisekunnin framen aikana.
-- Kun hahmo liikkuu samaa vauhtia, sen jalat eivät liu'u maata pitkin.
local speed = 12 / 70

local leftDown = false
local rightDown = false

-- Suunta on -1 vasemmalle, 1 oikealle ja 0, kun hahmo seisoo.
local direction = 0

local function onKeyEvent( event )
	local isDown = ( event.phase == "down" )

	if event.keyName == "left" then
		leftDown = isDown
	elseif event.keyName == "right" then
		rightDown = isDown
	end

	local newDirection = 0

	if rightDown then
		newDirection = newDirection + 1
	end

	if leftDown then
		newDirection = newDirection - 1
	end

	-- Animaatio vaihdetaan vain, kun hahmo lähtee liikkeelle tai pysähtyy.
	if newDirection ~= 0 and direction == 0 then
		character.run( player )
	elseif newDirection == 0 and direction ~= 0 then
		character.stand( player )
	end

	-- Flipataan hahmo katsomaan kulkusuuntaansa.
	if newDirection ~= 0 then
		player.xScale = newDirection
	end

	direction = newDirection
end

Runtime:addEventListener( "key", onKeyEvent )

local previousTime = system.getTimer()

local function onEnterFrame( event )
	-- Liike lasketaan kuluneen ajan mukaan, joten vauhti pysyy samana frame ratesta riippumatta.
	local deltaTime = event.time - previousTime
	previousTime = event.time

	player.x = player.x + direction * speed * deltaTime

	-- Pidetään hahmo ruudun sisällä.
	local left = display.screenOriginX + 64
	local right = display.screenOriginX + display.actualContentWidth - 64
	player.x = math.max( left, math.min( right, player.x ) )
end

Runtime:addEventListener( "enterFrame", onEnterFrame )
