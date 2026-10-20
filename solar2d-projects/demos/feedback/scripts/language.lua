-- Which of the two string sets the demo is showing.
--
-- Finnish is the default everywhere. On an HTML5 build the hosting page decides instead:
-- the lesson site keeps its English tree under /en/, so a page path containing that
-- segment starts the demo in English. The button in the corner overrides either result.

local language = {}

--------------------------------------------------------------------------------------
-- Libraries, classes, scripts, configs, etc.

local strings = require( "data.strings" )

--------------------------------------------------------------------------------------
-- Forward declarations & variables

local DEFAULT_CODE = "fi"
local ENGLISH_PATH = "/en/"

local currentCode = DEFAULT_CODE

--------------------------------------------------------------------------------------
-- Private functions

-- Returns the language the hosting page implies, or nil when there is nothing to go on.
-- Only an actual HTML5 build has a page: in the Simulator system.getInfo( "platform" )
-- reports the skin's operating system, so the plugin is never even loaded there.
local function detectFromPage()
	if system.getInfo( "platform" ) ~= "html5" then
		return nil
	end

	local isLoaded, plugin = pcall( require, "plugin.pageUrl" )

	if not isLoaded or type( plugin ) ~= "table" or type( plugin.getPageUrl ) ~= "function" then
		print( "WARNING: feedback-demo: plugin_pageUrl.js did not load, defaulting to " .. DEFAULT_CODE .. "." )
		return nil
	end

	local url = plugin.getPageUrl()

	if type( url ) ~= "string" then
		print( "WARNING: feedback-demo: plugin_pageUrl.js returned no page URL, defaulting to " .. DEFAULT_CODE .. "." )
		return nil
	end

	if string.find( string.lower( url ), ENGLISH_PATH, 1, true ) then
		return "en"
	end

	return nil
end

--------------------------------------------------------------------------------------
-- Public functions

function language.init()
	currentCode = detectFromPage() or DEFAULT_CODE

	return currentCode
end

function language.get()
	return currentCode
end

function language.toggle()
	currentCode = currentCode == "fi" and "en" or "fi"

	return currentCode
end

-- The string table of the language in use.
function language.strings()
	return strings[currentCode]
end

--------------------------------------------------------------------------------------

return language
