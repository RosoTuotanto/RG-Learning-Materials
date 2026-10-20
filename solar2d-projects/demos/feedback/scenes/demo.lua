-- The demo itself: the fight, the loop, and the switching between versions.
-- The mechanic lives here and never changes. Every version runs this same code and
-- differs only in which feedback layers the effects module is allowed to run.

--------------------------------------------------------------------------------------
-- Libraries, classes, scripts, configs, etc.

local composer = require( "composer" )
local layout = require( "data.layout" )
local fightData = require( "data.fight" )
local versions = require( "data.versions" )
local fighter = require( "scripts.fighter" )
local effects = require( "scripts.effects" )
local ui = require( "scripts.ui" )
local language = require( "scripts.language" )
local screen = require( "scripts.screen" )
local rng = require( "scripts.rng" )

--------------------------------------------------------------------------------------
-- Forward declarations & variables

local palette = layout.palette
local tuning = versions.tuning

local worldGroup
local bulletGroup
local effectGroup

local fighters = {}
local bullets = {}

-- The authored beats with this loop's jitter applied. Rebuilt on every restart.
local schedule = {}

-- How many times the fight has looped since the step was selected, and the only thing
-- that makes one loop differ from the last.
local runIndex = 0

-- Milliseconds into the current run of the fight.
local fightTime = 0
local lastFrameTime

-- Cursors into the schedule: one for the shots, one for the anticipation that leads them.
local beatIndex = 1
local anticipationIndex = 1

local isFightOver = false
local restartRemaining = 0

-- Fighters that have been hit and are waiting for any hit stop to finish before reacting.
local pendingHits = {}

local currentVersion = 1

--------------------------------------------------------------------------------------
-- Functions

-- Versions are cumulative, so a version's layer set is every addition up to and
-- including its own, minus anything a version along the way took back off.
local function buildLayers( versionIndex )
	local layers = {}

	for i = 1, versionIndex do
		local adds = versions.adds[i]

		for j = 1, #adds do
			layers[adds[j]] = true
		end

		local removes = versions.removes[i]

		for j = 1, #removes do
			layers[removes[j]] = nil
		end
	end

	return layers
end

-- The authored beats are the fight and never change: same order, same shooters, same
-- outcome. Only the moment each one lands moves, by up to beatVariance either way, and
-- it is redrawn on every loop so no two runs of a step are timed alike.
--
-- Independent offsets on fixed base times rather than jittered gaps, because the two
-- cursors in update() walk the schedule in order and a drifting gap could reorder it.
local function buildSchedule()
	local beats = fightData.beats
	local variance = fightData.beatVariance

	for i = 1, #beats do
		schedule[i] = {
			time = beats[i].time + ( rng.random() * 2 - 1 ) * variance,
			shooter = beats[i].shooter,
		}
	end
end

local function removeBullet( index )
	display.remove( bullets[index].object )
	bullets[index].object = nil

	table.remove( bullets, index )
end

local function startFight()
	for i = #bullets, 1, -1 do
		removeBullet( i )
	end

	effects.reset()

	-- Seeded here rather than inside effects.reset, because the loop counter that varies
	-- the timing belongs to the fight, and the schedule has to be drawn after the seed
	-- is set. Everything random in the demo comes off this one stream.
	rng.randomseed( fightData.randomSeed + runIndex )
	buildSchedule()

	for i = 1, #fighters do
		fighters[i]:reset()
	end

	fightTime = 0
	lastFrameTime = nil
	beatIndex = 1
	anticipationIndex = 1
	isFightOver = false
	restartRemaining = 0

	for i = #pendingHits, 1, -1 do
		pendingHits[i] = nil
	end
end

local function fireShot( shooterIndex )
	local shooter = fighters[shooterIndex]
	local target = fighters[shooterIndex == 1 and 2 or 1]

	shooter:fire()

	local muzzleX, muzzleY = shooter:getMuzzlePosition()

	local bullet = display.newRect( bulletGroup, muzzleX, muzzleY, layout.bullet.width, layout.bullet.height )
	bullet:setFillColor( palette.bullet[1], palette.bullet[2], palette.bullet[3] )

	bullets[#bullets + 1] = {
		object = bullet,
		target = target,
		direction = shooter.facing,
	}
end

-- Bullets are the mechanic, not a feedback layer, so they behave identically in every
-- version. Contact is measured against the target's anchor rather than its current
-- position, so a knocked-back target cannot change where the next bullet lands.
local function updateBullets( deltaTime )
	local seconds = deltaTime / 1000
	local halfBody = layout.fighter.bodyWidth * 0.5

	for i = #bullets, 1, -1 do
		local bullet = bullets[i]
		local direction = bullet.direction

		bullet.object.x = bullet.object.x + fightData.bulletSpeed * direction * seconds

		local contactX = bullet.target.anchorX - halfBody * direction

		if ( bullet.object.x - contactX ) * direction >= 0 then
			local target = bullet.target

			removeBullet( i )

			-- The health step is the mechanic and happens at the moment of contact in
			-- every version. Everything else waits for the hit stop to finish.
			target:registerHit()

			-- Started before any transition is created this frame. A pause cannot reach
			-- tweens that the transition library is already iterating over, and a tween
			-- created earlier in the same frame is exactly what puts it in that state.
			effects.startHitStop()

			-- A queue rather than a single slot. The shots are close enough together for
			-- two bullets to share the air, and a dropped entry would leave a fighter
			-- flashed white for good, since its fade out is what never gets started.
			pendingHits[#pendingHits + 1] = target

			if target:isDefeated() then
				isFightOver = true
				restartRemaining = fightData.resetDelay
			end
		end
	end
end

local function update( event )
	local deltaTime = 0

	if lastFrameTime then
		deltaTime = event.time - lastFrameTime
	end

	lastFrameTime = event.time

	-- The hit stop freezes the fight clock, the bullets, the casings and the shake by
	-- holding this whole function, and the paused transitions cover everything else.
	if effects.updateHitStop( deltaTime ) then
		return
	end

	while #pendingHits > 0 do
		local target = table.remove( pendingHits, 1 )
		target:react()
	end

	updateBullets( deltaTime )

	if isFightOver then
		restartRemaining = restartRemaining - deltaTime

		if restartRemaining <= 0 then
			runIndex = runIndex + 1
			startFight()
		end
	else
		fightTime = fightTime + deltaTime

		while anticipationIndex <= #schedule and fightTime >= schedule[anticipationIndex].time - tuning.anticipation.leadTime do
			effects.anticipate( fighters[schedule[anticipationIndex].shooter] )
			anticipationIndex = anticipationIndex + 1
		end

		while beatIndex <= #schedule and fightTime >= schedule[beatIndex].time do
			fireShot( schedule[beatIndex].shooter )
			beatIndex = beatIndex + 1
		end
	end

	effects.update( deltaTime )
end

-- Also the reset button, which restarts the step it is already on. Selecting a step puts
-- the loop counter back to zero, so the first loop of every step is timed identically
-- and the comparison between two steps stays a comparison of one thing.
local function showVersion( index )
	currentVersion = index
	runIndex = 0

	effects.setLayers( buildLayers( index ) )
	ui.setVersion( index )

	startFight()
end

local function toggleLanguage()
	language.toggle()
	ui.refreshText()
end

--------------------------------------------------------------------------------------
-- Scene functions

local scene = composer.newScene()

function scene:create( event )
	local sceneGroup = self.view

	-- Only the world shakes. Putting the controls in a separate group keeps them still.
	worldGroup = display.newGroup()
	sceneGroup:insert( worldGroup )

	local uiGroup = display.newGroup()
	sceneGroup:insert( uiGroup )

	-- Twice the screen width, so that the screen shake cannot pull its ends into view.
	local floor = display.newRect( worldGroup, screen.centerX, layout.floorY, screen.width * 2, layout.floorHeight )
	floor:setFillColor( palette.floor[1], palette.floor[2], palette.floor[3] )

	fighters[1] = fighter.new({
		parent = worldGroup,
		index = 1,
		x = layout.fighter.oneX,
		facing = 1,
		color = palette.fighterOne,
	})

	fighters[2] = fighter.new({
		parent = worldGroup,
		index = 2,
		x = layout.fighter.twoX,
		facing = -1,
		color = palette.fighterTwo,
	})

	bulletGroup = display.newGroup()
	worldGroup:insert( bulletGroup )

	effectGroup = display.newGroup()
	worldGroup:insert( effectGroup )

	effects.init({
		worldGroup = worldGroup,
		effectGroup = effectGroup,
	})
	effects.loadSounds()

	-- Finnish unless the hosting page says otherwise, before any text is created.
	language.init()

	ui.create({
		parent = uiGroup,
		callbacks = {
			onVersion = showVersion,
			onVolume = effects.setVolume,
			onLanguage = toggleLanguage,
			onReset = function()
				showVersion( currentVersion )
			end,
		},
	})

	effects.setLayers( buildLayers( currentVersion ) )
	ui.setVolume( effects.getVolume() )
	ui.setVersion( currentVersion )
end

function scene:show( event )
	local phase = event.phase

	if phase == "will" then
		Runtime:addEventListener( "enterFrame", update )

	elseif phase == "did" then
		startFight()
	end
end

function scene:hide( event )
	local phase = event.phase

	if phase == "will" then
		effects.reset()

	elseif phase == "did" then
		Runtime:removeEventListener( "enterFrame", update )
	end
end

function scene:destroy( event )
	for i = #bullets, 1, -1 do
		removeBullet( i )
	end

	for i = 1, #fighters do
		fighters[i]:destroy()
		fighters[i] = nil
	end

	effects.destroy()
	ui.destroy()

	worldGroup = nil
	bulletGroup = nil
	effectGroup = nil
	pendingHits = {}
	schedule = {}
end

--------------------------------------------------------------------------------------

scene:addEventListener( "create", scene )
scene:addEventListener( "show", scene )
scene:addEventListener( "hide", scene )
scene:addEventListener( "destroy", scene )

return scene
