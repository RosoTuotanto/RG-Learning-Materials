-- Lap timing: checkpoints must be crossed in order before the finish line counts a lap.

local laps = {}

--------------------------------------------------------------------------------------
-- Localised functions

local floor = math.floor

--------------------------------------------------------------------------------------
-- Public functions

-- Formats seconds as m:ss.cc.
function laps.formatTime( seconds )
	local hundredths = floor( seconds * 100 + 0.5 )
	local minutes = floor( hundredths / 6000 )
	local rest = hundredths - minutes * 6000

	return string.format( "%d:%02d.%02d", minutes, floor( rest / 100 ), rest % 100 )
end

-- Times are in seconds; last and best stay nil until a lap counts.
function laps.new( checkpointCount )
	local tracker = {
		current = 0,
		last = nil,
		best = nil,
		isTiming = false,
		nextCheckpoint = 1,
	}

	function tracker:update( deltaSeconds )
		if self.isTiming then
			self.current = self.current + deltaSeconds
		end
	end

	-- Returns "checkpoint" when index is the next checkpoint in order; any other crossing changes nothing.
	function tracker:crossCheckpoint( index )
		if self.isTiming and index == self.nextCheckpoint then
			self.nextCheckpoint = index + 1
			return "checkpoint"
		end

		return nil
	end

	-- Returns "lap" or "best" for a counted lap, "missed" when some but not all checkpoints were passed, otherwise "start".
	-- Every crossing starts the next lap, so a lap that does not count, or a recrossing backwards, still restarts the clock.
	function tracker:crossFinish()
		local result = "start"

		if self.isTiming and self.nextCheckpoint > checkpointCount then
			self.last = self.current
			result = "lap"

			if not self.best or self.current < self.best then
				-- Idea: keep the best lap between sessions with the template's save system.
				self.best = self.current
				result = "best"
			end

		elseif self.isTiming and self.nextCheckpoint > 1 then
			result = "missed"
		end

		self.isTiming = true
		self.current = 0
		self.nextCheckpoint = 1

		return result
	end

	return tracker
end

return laps
