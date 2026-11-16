local character = {}

-- Luodaan hahmo annettuun kohtaan. Laatikko on hahmon paikalla, kunnes kirjoitat tilalle oikean hahmon.
function character.new( x, y )
	local player = display.newRect( x, y, 48, 122 )
	player:setFillColor( 0.27, 0.56, 0.5 )

	return player
end

-- Vaihdetaan hahmo juoksemaan.
function character.run( player )

end

-- Vaihdetaan hahmo seisomaan.
function character.stand( player )

end

return character
