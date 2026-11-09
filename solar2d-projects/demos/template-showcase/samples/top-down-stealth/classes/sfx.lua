local sfx = {}

--------------------------------------------------------------------------------------
-- Public functions

-- paths maps each sound name to its file.
function sfx.new( paths )
	local sounds = {}

	local handles = {}
	for name, path in pairs( paths ) do
		handles[name] = audio.loadSound( path )
	end

	-- Every channel a sound has played on, so stopAll can stop them all.
	local playedChannels = {}

	function sounds:play( name )
		local channel = audio.play( handles[name] )
		if channel > 0 then
			playedChannels[channel] = true
		end
	end

	function sounds:stopAll()
		for channel in pairs( playedChannels ) do
			audio.stop( channel )
		end

		playedChannels = {}
	end

	-- Stops every sound first, because a playing sound cannot be disposed.
	function sounds:dispose()
		self:stopAll()

		for name, handle in pairs( handles ) do
			audio.dispose( handle )
			handles[name] = nil
		end
	end

	return sounds
end

return sfx
