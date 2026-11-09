-- Walks every passage of a Weaver story with the sample's own vendored Weaver and checks every link target.
-- Usage, from the demo root: lua5.1 tools/harness/walk_story.lua <story.json> <sampleId>
-- sampleId "selftest" uses the course game's Weaver copy. Exit code 1 on failure.

local lfs = require( "lfs" )

local COURSE_WEAVER = "../../games/5-visual-novel/versio-9/scripts/spyricStoryWeaver.lua"
local STORY_NAME = "HarnessWalk"
local BUILT_IN_COMMANDS = { ["if"] = true, ["elseif"] = true, ["else"] = true, ["end"] = true, print = true, set = true, shuffle = true, link = true }
local RETURNED_ROWS = { text = true, link = true, print = true }

local storyPath, sampleId = arg[1], arg[2]

if not storyPath or not sampleId then
	print( "Usage: lua5.1 tools/harness/walk_story.lua <story.json> <sampleId>" )
	os.exit( 2 )
end

local scriptPath = arg[0]

if string.sub( scriptPath, 1, 1 ) ~= "/" then
	scriptPath = lfs.currentdir() .. "/" .. scriptPath
end

if string.sub( storyPath, 1, 1 ) ~= "/" then
	storyPath = lfs.currentdir() .. "/" .. storyPath
end

local harnessDirectory = string.match( scriptPath, "^(.*)/[^/]*$" )
local demoRoot = string.match( harnessDirectory, "^(.*)/tools/harness$" )

if not demoRoot or not lfs.chdir( demoRoot ) then
	print( "walk_story.lua must live in <demo root>/tools/harness/" )
	os.exit( 2 )
end

local temporaryRoot = os.tmpname()
os.remove( temporaryRoot )
temporaryRoot = demoRoot .. "/.scratch/tmp/" .. string.match( temporaryRoot, "([^/]+)$" )

local stub = dofile( harnessDirectory .. "/stub/solar2d.lua" )
stub.install( harnessDirectory, temporaryRoot )

local json = require( "json" )

--------------------------------------------------------------------------------------
-- Helpers

local failures = {}

local function fail( message )
	failures[#failures + 1] = message
end

local function finish()
	os.execute( "rm -rf '" .. temporaryRoot .. "'" )

	for i = 1, #failures do
		print( "FAIL " .. failures[i] )
	end

	os.exit( #failures == 0 and 0 or 1 )
end

local function isDataPassage( passage )
	local tags = string.gsub( passage.tags or "", "%s+", "" )

	for tag in string.gmatch( tags, "[^,]+" ) do
		if tag == "option" or tag == "options" or tag == "comment" or tag == "comments" then
			return true
		end
	end

	return false
end

-- Link targets written in a body, read the way Weaver reads [[text|target]], [[text->target]], [[target<-text]] and [[target]].
local function staticLinkTargets( body )
	local targets = {}

	for inner in string.gmatch( body, "%[%[(.-)%]%]" ) do
		local bar = string.find( inner, "|", 1, true )
		local arrow = string.find( inner, "->", 1, true )
		local backArrow = string.find( inner, "<-", 1, true )

		if bar then
			targets[#targets + 1] = string.sub( inner, bar + 1 )
		elseif arrow then
			targets[#targets + 1] = string.sub( inner, arrow + 2 )
		elseif backArrow then
			targets[#targets + 1] = string.sub( inner, 1, backArrow - 1 )
		else
			targets[#targets + 1] = inner
		end
	end

	for target in string.gmatch( body, "<<%s*link[^>]-\"(.-)\"" ) do
		targets[#targets + 1] = target
	end

	return targets
end

local function staticCommands( body, found )
	for name in string.gmatch( body, "<<%s*([^,%s>]+)" ) do
		if not BUILT_IN_COMMANDS[name] then
			found[name] = true
		end
	end
end

--------------------------------------------------------------------------------------
-- Load the story and Weaver

local weaverPath = "samples/" .. sampleId .. "/libs/spyricStoryWeaver.lua"

if sampleId == "selftest" then
	weaverPath = COURSE_WEAVER
end

local weaverFile = io.open( weaverPath, "r" )

if not weaverFile then
	fail( "no vendored Weaver at " .. weaverPath )
	finish()
end

weaverFile:close()

local storyFile = io.open( storyPath, "r" )

if not storyFile then
	fail( "cannot open story " .. storyPath )
	finish()
end

local passages, _, decodeMessage = json.decode( storyFile:read( "*a" ) )
storyFile:close()

if type( passages ) ~= "table" then
	fail( "story is not valid JSON: " .. tostring( decodeMessage ) )
	finish()
end

-- The story path may sit outside the demo root, so Weaver gets it as an absolute path.
local resourcePathForFile = system.pathForFile

rawset( system, "pathForFile", function( name, baseDirectory )
	if name == storyPath then
		return storyPath
	end

	return resourcePathForFile( name, baseDirectory )
end )

local loaded, weaver = stub.call( dofile, weaverPath )

if not loaded then
	fail( "Weaver failed to load" )
end

local titles = {}

for i = 1, #passages do
	local passage = passages[i]

	if type( passage.title ) ~= "string" or type( passage.body ) ~= "string" then
		fail( "passage " .. i .. " has no title or body" )
	elseif titles[passage.title] then
		fail( "passage title \"" .. passage.title .. "\" is used twice" )
	else
		titles[passage.title] = passage
	end
end

if loaded then
	local initialised = stub.call( weaver.initStory, { name = STORY_NAME, source = storyPath } )

	if not initialised or not _G["WEAVERx" .. STORY_NAME] then
		fail( "weaver.initStory failed for " .. storyPath )
		loaded = false
	end
end

--------------------------------------------------------------------------------------
-- Walk

local runtimeCommands = {}
local staticOnly = {}
local visited, linkCount = 0, 0
local reportedLinks = {}

for i = 1, #passages do
	local passage = passages[i]

	if type( passage.title ) == "string" and type( passage.body ) == "string" and not isDataPassage( passage ) then
		local targets = staticLinkTargets( passage.body )

		for j = 1, #targets do
			local target = targets[j]
			linkCount = linkCount + 1

			if not titles[target] then
				if string.find( target, "[%$_]" ) then
					print( "WARN \"" .. passage.title .. "\" links to \"" .. target .. "\", which may be a variable" )
				else
					fail( "\"" .. passage.title .. "\" links to missing passage \"" .. target .. "\"" )
					reportedLinks[passage.title .. "\n" .. target] = true
				end
			end
		end

		staticCommands( passage.body, staticOnly )

		if loaded then
			local ok, line = stub.call( weaver.getNode, passage.title, STORY_NAME )

			if not ok or line == false or line == nil then
				fail( "getNode( \"" .. passage.title .. "\" ) returned " .. tostring( line ) )
			else
				visited = visited + 1

				for j = 1, #line do
					local row = line[j]

					if type( row ) == "table" and type( row[1] ) == "string" then
						if row[1] == "link" then
							if not titles[row[3]] and not reportedLinks[passage.title .. "\n" .. tostring( row[3] )] then
								fail( "\"" .. passage.title .. "\" returned a link to missing passage \"" .. tostring( row[3] ) .. "\"" )
							end

						elseif not RETURNED_ROWS[row[1]] then
							runtimeCommands[row[1]] = true
						end
					end
				end
			end
		end
	end
end

for i = 1, #stub.errorOrder do
	fail( "Lua error: " .. stub.errorOrder[i].traceback )
end

--------------------------------------------------------------------------------------
-- Report

local function sortedNames( set, exclude )
	local names = {}

	for name in pairs( set ) do
		if not ( exclude and exclude[name] ) then
			names[#names + 1] = name
		end
	end

	table.sort( names )

	return table.concat( names, ", " )
end

print( "Walked " .. visited .. " passages, checked " .. linkCount .. " links" )
print( "Custom commands: " .. sortedNames( runtimeCommands ) )

local unseen = sortedNames( staticOnly, runtimeCommands )

if unseen ~= "" then
	print( "Custom commands found only by scanning the passage text: " .. unseen )
end

if #failures == 0 then
	print( "OK " .. storyPath )
end

finish()
