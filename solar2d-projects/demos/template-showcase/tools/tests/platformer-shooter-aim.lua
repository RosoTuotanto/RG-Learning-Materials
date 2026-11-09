-- Stub test: gun aim, flip and tip, turret barrel and line of sight stay right in world space whatever the camera offset.
-- Run from the demo root: lua5.1 tools/tests/platformer-shooter-aim.lua

local rayCalls = {}
local rayHits = nil
package.loaded.physics = {
	addBody = function() return true end,
	rayCast = function( x1, y1, x2, y2, behaviour )
		rayCalls[#rayCalls + 1] = { x1, y1, x2, y2, behaviour }
		return rayHits
	end,
}

local now = 0
_G.system = { getTimer = function() return now end }
_G.display = {
	newImageRect = function( _, _, width, height )
		local object = { x = 0, y = 0, width = width, height = height, rotation = 0, xScale = 1, yScale = 1, anchorX = 0.5, anchorY = 0.5 }
		function object:setFillColor() end
		return object
	end,
	remove = function() end,
}

local settings = require( "samples.platformer-shooter.data.settings" )
local gun = require( "samples.platformer-shooter.classes.gun" )
local turret = require( "samples.platformer-shooter.classes.turret" )


local failures = 0
local checks = 0
local function check( name, condition )
	checks = checks + 1
	if not condition then
		failures = failures + 1
		print( "FAIL " .. name )
	end
end

local function near( a, b, tolerance )
	return math.abs( a - b ) < ( tolerance or 1e-9 )
end

-- A Solar2D group's contentToLocal for an unscaled, unrotated group whose parent sits at the stage origin.
local function newWorldGroup( x, y )
	local group = { x = x, y = y }
	function group:contentToLocal( contentX, contentY )
		return contentX - self.x, contentY - self.y
	end
	return group
end

-- Independent of gun.lua: where an image-local point (from the top-left) lands, the way Solar2D places it.
local function imagePointToWorld( object, pointX, pointY )
	local localX = ( pointX - object.anchorX * object.width ) * object.xScale
	local localY = ( pointY - object.anchorY * object.height ) * object.yScale
	local angle = math.rad( object.rotation )
	return object.x + localX * math.cos( angle ) - localY * math.sin( angle ), object.y + localX * math.sin( angle ) + localY * math.cos( angle )
end

local config = settings.gun
local hero = { x = 1180, y = 700, facing = 1 }
local weapon = gun.new({ parent = {}, config = config })

-- Aims as demo.lua does: cursor to world through the world group, then the gun; the player's facing comes from running, not from the aim.
local function aimThrough( group, cursorX, cursorY )
	local aimX, aimY = group:contentToLocal( cursorX, cursorY )
	weapon:aimAt( hero, aimX, aimY )
	local tipX, tipY = weapon:getTip()
	return { heading = weapon.heading, flip = weapon.yScale, tipX = tipX, tipY = tipY, gripX = weapon.x, gripY = weapon.y }
end

local unmoved = newWorldGroup( 0, 0 )
local moved = newWorldGroup( -720, -150 )

-- Targets on both sides of the player, aimed at while it faces right and while it faces left.
local targets = { { 1400, 560 }, { 900, 760 }, { 1180, 400 }, { 1000, 700 }, { 1300, 900 } }
for index = 1, #targets * 2 do
	local i = ( index - 1 ) % #targets + 1
	hero.facing = index > #targets and -1 or 1
	local worldX, worldY = targets[i][1], targets[i][2]
	local first = aimThrough( unmoved, worldX + unmoved.x, worldY + unmoved.y )
	local second = aimThrough( moved, worldX + moved.x, worldY + moved.y )

	for _, key in pairs( { "heading", "flip", "tipX", "tipY" } ) do
		check( "target " .. i .. " " .. key .. " same with the camera moved", near( first[key], second[key] ) )
	end

	-- The gun is never upside down: flipped exactly when it points left.
	check( "target " .. i .. " flip matches the aim side", ( math.cos( math.rad( second.heading ) ) < 0 ) == ( second.flip == -1 ) )

	-- The art's tip point, placed through anchor, flip and rotation, is where bullets start.
	local artTipX, artTipY = imagePointToWorld( weapon, config.tip.x, config.tip.y )
	check( "target " .. i .. " tip matches the drawn tip", near( artTipX, second.tipX ) and near( artTipY, second.tipY ) )

	-- The grip point of the art sits on the player's hand.
	local artGripX, artGripY = imagePointToWorld( weapon, config.grip.x, config.grip.y )
	check( "target " .. i .. " grip on the hand", near( artGripX, hero.x + config.hand.x * hero.facing ) and near( artGripY, hero.y + config.hand.y ) )

	-- The gun points at the target.
	local expected = math.deg( math.atan2( worldY - second.gripY, worldX - second.gripX ) )
	check( "target " .. i .. " heading points at the target", near( expected, second.heading ) )
end

-- Treating the content-space cursor as a world point aims somewhere else once the camera has moved.
local worldX, worldY = 1400, 560
local right = aimThrough( moved, worldX + moved.x, worldY + moved.y )
weapon:aimAt( hero, worldX + moved.x, worldY + moved.y )
check( "raw content cursor aims wrong", math.abs( weapon.heading - right.heading ) > 30 )

-- Turret: barrel joint on the hub, heading toward the player, muzzle along the barrel, sight ray in world points.
local fired = {}
local spotX, spotY = 1062, 522
local base = turret.new({ parent = {}, x = spotX, y = spotY, filter = settings.filters.turret, config = settings.turret, onFire = function( x, y, heading )
	fired[#fired + 1] = { x = x, y = y, heading = heading }
end })

local barrelConfig = settings.turret.barrel
local hubX, hubY = spotX + settings.turret.hub.x, spotY + settings.turret.hub.y

-- The art's hub (9, 7 in 1x pixels, doubled) measured from the base's top-left lands on the hub point.
check( "hub point matches the base art", near( spotX - settings.turret.size * 0.5 + 18, hubX ) and near( spotY - settings.turret.size * 0.5 + 14, hubY ) )

rayCalls = {}
now = 0
local playerX, playerY = 1250, 610
base:update( playerX, playerY )
check( "sight ray uses world points", #rayCalls == 1
	and near( rayCalls[1][1], hubX ) and near( rayCalls[1][2], hubY ) and near( rayCalls[1][3], playerX ) and near( rayCalls[1][4], playerY ) )
check( "no shot before the sight delay", #fired == 0 )

now = settings.turret.sightDelay
base:update( playerX, playerY )
check( "shot after the sight delay", #fired == 1 )

local expectedHeading = math.deg( math.atan2( playerY - hubY, playerX - hubX ) )
local muzzleX = hubX + math.cos( math.rad( expectedHeading ) ) * settings.turret.muzzleOffset
local muzzleY = hubY + math.sin( math.rad( expectedHeading ) ) * settings.turret.muzzleOffset
check( "muzzle along the barrel", fired[1] and near( fired[1].heading, expectedHeading ) and near( fired[1].x, muzzleX ) and near( fired[1].y, muzzleY ) )

-- The barrel's joint point lands on the hub at any rotation.
local barrelProbe = display.newImageRect( nil, nil, barrelConfig.width, barrelConfig.height )
barrelProbe.anchorX, barrelProbe.anchorY = barrelConfig.joint.x / barrelConfig.width, barrelConfig.joint.y / barrelConfig.height
barrelProbe.x, barrelProbe.y, barrelProbe.rotation = hubX, hubY, 137
local jointX, jointY = imagePointToWorld( barrelProbe, barrelConfig.joint.x, barrelConfig.joint.y )
check( "barrel joint stays on the hub", near( jointX, hubX ) and near( jointY, hubY ) )

-- A wall on the ray blocks sight; the player and other turrets do not.
rayHits = { { object = { isGround = true, isTurret = true } }, { object = {} } }
check( "turrets and the player do not block sight", turret.canSee( hubX, hubY, playerX, playerY, settings.turret.range ) )
rayHits = { { object = { isGround = true } } }
check( "a wall blocks sight", not turret.canSee( hubX, hubY, playerX, playerY, settings.turret.range ) )
rayHits = nil
rayCalls = {}
check( "out of range needs no ray", not turret.canSee( hubX, hubY, hubX + settings.turret.range + 1, hubY, settings.turret.range ) and #rayCalls == 0 )

print( ( failures == 0 and "OK " or "FAILED " ) .. ( checks - failures ) .. "/" .. checks .. " checks" )
os.exit( failures == 0 and 0 or 1 )
