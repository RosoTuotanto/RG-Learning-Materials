local loadsave = {}

local json = require( "json" )

-- Tallennetaan data tiedostoon JSON muodossa.
function loadsave.save( data, filename )
	-- Määritellään tiedoston polku.
	local path = system.pathForFile( filename, system.DocumentsDirectory )
	local file, errorString = io.open( path, "w" )

	if not file then
		print( "File error: " .. errorString )
		return false
	else
		-- Kirjoitetaan data tiedostoon JSON muodossa.
		file:write( json.prettify( json.encode( data ) ) )
		io.close( file )

		return true
	end
end

-- Luetaan JSON tiedosto ja palautetaan se Lua taulukkona.
function loadsave.load( filename )
	-- Määritellään tiedoston polku.
	local path = system.pathForFile( filename, system.DocumentsDirectory )
	local file, errorString = io.open( path, "r" )

	if not file then
		print( "File error: " .. errorString )
	else
		-- Luetaan tiedoston sisältö ja dekoodataan se Lua taulukoksi.
		local contents = file:read( "*a" )
		local data = json.decode( contents )
		io.close( file )

		return data
	end
end

return loadsave