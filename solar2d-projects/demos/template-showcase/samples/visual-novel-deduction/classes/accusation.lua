local accusation = {}

--------------------------------------------------------------------------------------
-- Public functions

-- links holds a suspect id by clue id; case is settings.case. Returns "right", "partlyRight" or "wrong".
function accusation.judge( links, case )
	local solution = case.solution

	if links[case.keyClue] ~= solution[case.keyClue] then
		return "wrong"
	end

	for clueId, suspectId in pairs( solution ) do
		if links[clueId] ~= suspectId then
			return "partlyRight"
		end
	end

	return "right"
end

return accusation
