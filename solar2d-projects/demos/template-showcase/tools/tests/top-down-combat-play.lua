-- Plays top-down-combat's real scene in the harness stub: the Tiled map and its wall bodies, and the melee enemies' swords.
-- Usage, from the demo root: lua5.1 tools/tests/top-down-combat-play.lua
local harnessDirectory = "tools/harness"
package.path = "./?.lua;" .. harnessDirectory .. "/?.lua;" .. package.path

local stub = dofile( harnessDirectory .. "/stub/solar2d.lua" )
stub.install( harnessDirectory, ".scratch/tmp/top-down-combat-play" )

local settings = require( "samples.top-down-combat.data.settings" )

local checks, failures = 0, 0

local function check( condition, message )
	checks = checks + 1

	if not condition then
		failures = failures + 1
		print( "FAIL top-down-combat-play: " .. message )
	end
end

local function find( group, test )
	if test( group ) then
		return group
	end

	for i = 1, ( group.numChildren or 0 ) do
		local found = find( group[i], test )
		if found then
			return found
		end
	end
end

local function findAll( group, test, list )
	list = list or {}

	if test( group ) then
		list[#list + 1] = group
	end

	for i = 1, ( group.numChildren or 0 ) do
		findAll( group[i], test, list )
	end

	return list
end

local function bodyElements( object )
	local internal = rawget( object, "_stub" )
	return internal and internal.body and internal.body.elements
end

stub.call( dofile, "main.lua" )
local _, scene = stub.call( require, "samples.top-down-combat.demo" )
stub.sceneEvent( scene, "create" )
stub.sceneEvent( scene, "show", "will" )
stub.sceneEvent( scene, "show", "did" )

--------------------------------------------------------------------------------------
-- The map

local map = find( scene.view, function( object ) return object.findObject ~= nil end )
check( map ~= nil, "the scene holds a ponytiled map" )

local walls = map:findLayer( "physics" )
check( walls.numChildren == 31, "the physics layer holds 31 wall rects, not " .. walls.numChildren )

local wallFilter = settings.filters.wall
local badWalls = 0
for i = 1, walls.numChildren do
	local wall = walls[i]
	local elements = bodyElements( wall )
	local element = elements and elements[1]

	local isGood = wall.kind == "wall" and wall.bodyType == "static" and element ~= nil and element.friction == settings.wallBody.friction
		and element.filter ~= nil and element.filter.categoryBits == wallFilter.categoryBits and element.filter.maskBits == wallFilter.maskBits

	if not isGood then
		badWalls = badWalls + 1
	end
end
check( badWalls == 0, badWalls .. " wall rects lack kind \"wall\" or a static body with the wall friction and filter" )

local hero = find( scene.view, function( object ) return object.tryShoot ~= nil end )
local start = map:findObject( "player" )
check( hero.x == start.x and hero.y == start.y, "the hero starts on the map's player object" )
check( #map:findObjects( "spawn" ) == 8, "the map holds 8 spawn points" )

--------------------------------------------------------------------------------------
-- Melee swords

local foes = findAll( scene.view, function( object ) return object.kind == "enemy" and object.weaponPivot ~= nil end )
check( #foes == 2, "the first wave brings 2 melee enemies, not " .. #foes )

local swing = settings.enemies.melee.swing

local function frameTime()
	local before = stub.clock
	stub.step()
	return stub.clock - before
end

-- Walking toward the hero from the spawn points.
local startX, startY = foes[1].x, foes[1].y
local frameMs = frameTime()
for _ = 1, 9 do
	stub.step()

	for i = 1, #foes do
		check( not foes[i].weaponPivot.isVisible, "melee enemy " .. i .. " hides its sword while walking (frame " .. stub.frame .. ")" )
	end
end
check( foes[1].x ~= startX or foes[1].y ~= startY, "the first melee enemy walks" )

-- Holds the enemy next to the hero until its swing starts; returns false if it never does.
local function startSwing( foe )
	for _ = 1, 120 do
		foe.x, foe.y = hero.x - swing.startDistance * 0.75, hero.y
		stub.step()

		if foe.weaponPivot.isVisible then
			return true
		end
	end

	return false
end

local first, second = foes[1], foes[2]
second.x, second.y = hero.x + 600, hero.y

check( startSwing( first ), "the sword shows when the wind-up begins" )

local shownFrames = 0
while first.weaponPivot.isVisible and shownFrames < 200 do
	stub.step()
	shownFrames = shownFrames + 1
end

local expectedFrames = math.ceil( ( swing.windupTime + swing.sweepTime ) / frameMs )
check( math.abs( shownFrames - expectedFrames ) <= 1,
	"the sword shows through the wind-up and sweep, " .. shownFrames .. " frames instead of about " .. expectedFrames )

stub.step()
check( not first.weaponPivot.isVisible, "the sword stays hidden after the attack ends" )

-- Killed during the wind-up.
first.x, first.y = hero.x + 600, hero.y + 200
check( startSwing( second ), "the second enemy starts a swing" )
stub.step()

-- A removed object reads every property as nil in the stub, so the sword is read as the enemy is removed.
local removeObject = display.remove
local isShownAtRemoval

function display.remove( object )
	if rawequal( object, second ) then
		isShownAtRemoval = second.weaponPivot.isVisible
	end

	return removeObject( object )
end

second:takeHit( settings.enemies.melee.hp, hero.x, hero.y )
display.remove = removeObject

check( isShownAtRemoval == false, "the sword hides when the enemy dies mid-attack" )

-- The scene hides mid-attack.
check( startSwing( first ), "the first enemy swings again" )
stub.step()
stub.sceneEvent( scene, "hide", "will" )
check( not first.weaponPivot.isVisible, "the sword hides when the scene hides mid-attack" )
stub.sceneEvent( scene, "hide", "did" )

print( "top-down-combat-play: " .. checks .. " checks, " .. failures .. " failures" )
os.exit( failures == 0 and 0 or 1 )
