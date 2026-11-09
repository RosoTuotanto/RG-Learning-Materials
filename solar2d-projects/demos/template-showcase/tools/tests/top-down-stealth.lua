-- Stub test for guard.canSee: run from the demo root with lua5.1 tools/tests/top-down-stealth.lua

local rayHits = nil
local rayCalls = 0
local rayArguments = {}

package.loaded["physics"] = {
	rayCast = function( ... )
		rayCalls = rayCalls + 1
		rayArguments = { ... }
		return rayHits
	end,
}

local guard = require( "samples.top-down-stealth.classes.guard" )

local vision = { range = 170, halfAngle = 32 }

-- World-group positions; localToContent adds a world offset, so a content-space ray would show up in the checks below.
local function at( x, y )
	return { x = x, y = y, localToContent = function( _, offsetX, offsetY ) return x + 112 + offsetX, y + 64 + offsetY end }
end

local failures = 0
local function check( name, actual, expected )
	if actual ~= expected then
		failures = failures + 1
		print( "FAIL " .. name .. ": expected " .. tostring( expected ) .. ", got " .. tostring( actual ) )
	end
end

local viewer = at( 100, 100 )
local wall = { object = { blocksSight = true } }
local target = { object = {} }

rayHits = nil
check( "in range and angle, no hits", guard.canSee( viewer, 0, at( 250, 120 ), vision ), true )

rayHits = { target }
check( "only the target hit", guard.canSee( viewer, 0, at( 250, 120 ), vision ), true )

rayHits = { target, wall }
check( "wall hit before the target", guard.canSee( viewer, 0, at( 250, 120 ), vision ), false )

rayHits = nil
check( "outside the angle", guard.canSee( viewer, 0, at( 150, 160 ), vision ), false )
check( "behind the guard", guard.canSee( viewer, 0, at( 40, 100 ), vision ), false )
check( "too far", guard.canSee( viewer, 0, at( 280, 100 ), vision ), false )
check( "just inside the range", guard.canSee( viewer, 0, at( 269, 100 ), vision ), true )

check( "facing wraps past 360", guard.canSee( viewer, 350, at( 200, 105 ), vision ), true )
check( "facing left, target across -180", guard.canSee( viewer, 180, at( 0, 95 ), vision ), true )
check( "facing down", guard.canSee( viewer, 90, at( 110, 220 ), vision ), true )
check( "facing up, target below", guard.canSee( viewer, -90, at( 110, 220 ), vision ), false )

check( "ray starts at the viewer's world x", rayArguments[1], 100 )
check( "ray starts at the viewer's world y", rayArguments[2], 100 )
check( "ray ends at the target's world x", rayArguments[3], 110 )
check( "ray ends at the target's world y", rayArguments[4], 220 )

local callsBefore = rayCalls
check( "outside cone skips the ray", guard.canSee( viewer, 0, at( 100, 250 ), vision ), false )
check( "ray count unchanged", rayCalls, callsBefore )

print( failures == 0 and "vision: all 17 checks passed" or ( "vision: " .. failures .. " failures" ) )
os.exit( failures == 0 and 0 or 1 )
