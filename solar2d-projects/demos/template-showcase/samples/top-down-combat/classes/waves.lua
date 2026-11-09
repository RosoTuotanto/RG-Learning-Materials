-- Spawns enemies in waves at the spawn points farthest from the hero and updates them every frame.

local waves = {}

--------------------------------------------------------------------------------------
-- Libraries, classes, scripts, configs, etc.

local combat = require( "samples.top-down-combat.classes.combat" )
local enemy = require( "samples.top-down-combat.classes.enemy" )

--------------------------------------------------------------------------------------
-- Localised functions

local min = math.min

--------------------------------------------------------------------------------------
-- Public functions

-- params: parent (the world group), spawnPoints (world x, y tables), hero, projectiles, settings (data/settings.lua),
-- onWave( number ), and onAttack( role ) and onHit() for sounds.
function waves.new( params )
	local settings = params.settings
	local hero = params.hero

	local spawner = {}

	local enemies = {}
	local waveNumber = 0
	local delayLeft = 0

	local function onDeath( foe )
		params.onHit()

		enemies[foe] = nil
		display.remove( foe )

		if next( enemies ) == nil then
			delayLeft = settings.waves.delay
		end
	end

	local function spawnEnemy( role, point )
		local foe = enemy.new({
			parent = params.parent,
			x = point.x,
			y = point.y,
			role = role,
			config = settings.enemies[role],
			filter = settings.filters.enemy,
			body = settings.fighterBody,
			target = hero,
			projectiles = params.projectiles,
			reaction = settings.reactions.enemy,
			flashColor = settings.colors.hitFlash,
			onAttack = params.onAttack,
			onHit = params.onHit,
			onDeath = onDeath,
		})

		enemies[foe] = true
	end

	function spawner:spawnNext()
		waveNumber = waveNumber + 1
		params.onWave( waveNumber )

		local list = settings.waves.list
		local wave = list[min( waveNumber, #list )]

		local points = {}
		for i = 1, #params.spawnPoints do
			local point = params.spawnPoints[i]
			points[i] = { x = point.x, y = point.y, distance = combat.distanceSquared( hero.x, hero.y, point.x, point.y ) }
		end

		table.sort( points, function( first, second ) return first.distance > second.distance end )

		local count = 0
		local roles = { "melee", "ranged" }
		for i = 1, #roles do
			for _ = 1, wave[roles[i]] or 0 do
				spawnEnemy( roles[i], points[count % #points + 1] )
				count = count + 1
			end
		end
	end

	-- deltaTime is in milliseconds.
	function spawner:update( deltaTime )
		for foe in pairs( enemies ) do
			foe:update( deltaTime )
		end

		if delayLeft > 0 then
			delayLeft = delayLeft - deltaTime

			if delayLeft <= 0 then
				self:spawnNext()
			end
		end
	end

	function spawner:stopAttacks()
		for foe in pairs( enemies ) do
			foe:stopAttack()
		end
	end

	return spawner
end

return waves
