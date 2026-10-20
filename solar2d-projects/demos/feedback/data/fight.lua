-- The exchange itself. Every version plays this exact fight, which is the only
-- reason the versions can be compared: the mechanic never changes, only the feedback.

return {
	-- Shot times in milliseconds from the start of the loop. Strict alternation, so
	-- fighter one fires five shots and fighter two four, and fighter two goes down.
	-- Change a time here and every version changes with it.
	--
	-- These are the base times, not the times the shots are actually fired at. Every
	-- beat is moved by up to beatVariance either way on every loop.
	beats = {
		{ time = 700, shooter = 1 },
		{ time = 1500, shooter = 2 },
		{ time = 2300, shooter = 1 },
		{ time = 3100, shooter = 2 },
		{ time = 3900, shooter = 1 },
		{ time = 4700, shooter = 2 },
		{ time = 5500, shooter = 1 },
		{ time = 6300, shooter = 2 },
		{ time = 7100, shooter = 1 },
	},

	-- Hits needed to empty a health bar. Must match the number of shots the winner fires.
	healthSteps = 5,

	-- Content units per second. The muzzle-to-target gap is 322 units with the current
	-- layout, so a bullet is in the air for a little over a third of a second.
	bulletSpeed = 900,

	-- How long the finished fight is left on screen before the loop restarts.
	resetDelay = 1800,

	-- How far either way each beat is moved, in milliseconds, redrawn on every loop.
	-- A metronomic exchange stops being worth watching after one loop; this is enough
	-- variation to make the next shot something you wait for.
	--
	-- Do not raise this above 200. The beats are 800 ms apart and a bullet is in the air
	-- for 358 ms, so a wider window would close the gap below the flight time and let a
	-- fighter return fire before the incoming bullet has landed, which inverts the cause
	-- and effect the demo exists to show.
	beatVariance = 200,

	-- Beat times, casing spin and casing velocity are the random values in the demo, and
	-- they all come from scripts/rng.lua rather than math.random. The seed is the base
	-- one plus the loop counter, and the counter is reset whenever a step is selected or
	-- restarted, so every loop differs while the first loop of every step is identical.
	randomSeed = 20260801,
}
