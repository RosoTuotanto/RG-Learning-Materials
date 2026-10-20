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
	local file = io.open( path, "r" )

	-- Tiedostoa ei ole olemassa (esim. peliä ei ole vielä tallennettu). Tämä ei ole
	-- virhe, joten palautetaan hiljaa nil ja kutsuja voi aloittaa puhtaalta pöydältä.
	if not file then
		return nil
	end

	-- Luetaan tiedoston sisältö ja suljetaan tiedosto.
	local contents = file:read( "*a" )
	io.close( file )

	-- Suojataan dekoodaus pcall:lla. Jos tiedosto on vioittunut, pcall nappaa virheen
	-- eikä peli kaadu, vaan palautetaan nil ja kerrotaan asiasta.
	local success, data = pcall( json.decode, contents )
	if not success or type( data ) ~= "table" then
		print( "WARNING: failed to read save file \"" .. filename .. "\"." )
		return nil
	end

	return data
end

-- Poistetaan tallennustiedosto. Uuden pelin aloitus käyttää tätä, jotta vanha
-- tallennus ei jää häiritsemään.
function loadsave.delete( filename )
	local path = system.pathForFile( filename, system.DocumentsDirectory )
	os.remove( path )
end

return loadsave
