-- Stub test: aim and swing maths give the same result in world space whatever the camera offset.
-- Run from the demo root: lua5.1 tools/tests/top-down-combat.lua
package.loaded.physics = {}
local combat = require( "samples.top-down-combat.classes.combat" )

local failures = 0
local function check( name, condition )
	if not condition then
		failures = failures + 1
		print( "FAIL " .. name )
	end
end

local function near( a, b )
	return math.abs( a - b ) < 1e-9
end

-- A Solar2D group's contentToLocal for an unscaled, unrotated group whose parent sits at the stage origin.
local function newWorldGroup( x, y )
	local group = { x = x, y = y }
	function group:contentToLocal( contentX, contentY )
		return contentX - self.x, contentY - self.y
	end
	return group
end

local heroX, heroY = 1180, 760
local aimWorldX, aimWorldY = 1300, 650

local unmoved = newWorldGroup( 0, 0 )
local moved = newWorldGroup( -720, -430 )

-- The cursor sits wherever the world point appears on screen for each camera position.
local cursorUnmovedX, cursorUnmovedY = aimWorldX + unmoved.x, aimWorldY + unmoved.y
local cursorMovedX, cursorMovedY = aimWorldX + moved.x, aimWorldY + moved.y

local worldX1, worldY1 = unmoved:contentToLocal( cursorUnmovedX, cursorUnmovedY )
local worldX2, worldY2 = moved:contentToLocal( cursorMovedX, cursorMovedY )
check( "cursor converts to the same world point", near( worldX1, worldX2 ) and near( worldY1, worldY2 ) )

local heading1 = combat.headingTo( heroX, heroY, worldX1, worldY1 )
local heading2 = combat.headingTo( heroX, heroY, worldX2, worldY2 )
check( "aim heading matches across camera offsets", near( heading1, heading2 ) )
check( "aim heading points up-right", heading1 < 0 and heading1 > -90 )

-- Using the raw screen point with a moved camera aims somewhere else, which the conversion prevents.
local rawHeading = combat.headingTo( heroX, heroY, cursorMovedX, cursorMovedY )
check( "raw screen point would aim wrong", not near( rawHeading, heading1 ) )

-- An arrow fired along the heading travels toward the world aim point.
local directionX, directionY = combat.direction( heading2 )
local length = math.sqrt( ( aimWorldX - heroX ) ^ 2 + ( aimWorldY - heroY ) ^ 2 )
check( "arrow direction reaches the aim point", near( heroX + directionX * length, aimWorldX ) and near( heroY + directionY * length, aimWorldY ) )

-- Swing arc: an orc at a world point swings toward the hero; results only depend on world positions.
local orcX, orcY = 1150, 760
local swingHeading = combat.headingTo( orcX, orcY, heroX, heroY )
check( "hero straight ahead is hit", combat.isInArc( orcX, orcY, swingHeading, 65, 44, heroX, heroY ) )
check( "hero behind the orc is missed", not combat.isInArc( orcX, orcY, swingHeading, 65, 44, orcX - 30, orcY ) )
check( "hero out of reach is missed", not combat.isInArc( orcX, orcY, swingHeading, 65, 44, orcX + 50, orcY ) )
check( "hero at 60 degrees inside arc",
	combat.isInArc( orcX, orcY, swingHeading, 65, 44, orcX + 40 * math.cos( math.rad( 60 ) ), orcY + 40 * math.sin( math.rad( 60 ) ) ) )
check( "hero at 70 degrees outside arc",
	not combat.isInArc( orcX, orcY, swingHeading, 65, 44, orcX + 40 * math.cos( math.rad( 70 ) ), orcY + 40 * math.sin( math.rad( 70 ) ) ) )
check( "arc wraps across 180 degrees", combat.isInArc( 0, 0, 175, 20, 50, -30, 5 ) )

-- Shifting the whole world by any camera offset changes nothing, because nothing reads screen positions.
local shiftX, shiftY = moved.x, moved.y
check( "swing result unchanged by offset", combat.isInArc( orcX + shiftX, orcY + shiftY, swingHeading, 65, 44, heroX + shiftX, heroY + shiftY ) )

check( "angleDifference wraps", near( combat.angleDifference( 170, -170 ), 20 ) and near( combat.angleDifference( -170, 170 ), -20 ) )

print( failures == 0 and "aim_test: all checks passed" or ( "aim_test: " .. failures .. " failures" ) )
os.exit( failures == 0 and 0 or 1 )
