# Kurssin 2 harjoitusten vastaukset: Pelinkehityksen alkeet

Kurssin Pelinkehityksen alkeet oppitunneilla on pieniä harjoituksia, joissa kokeillaan juuri opittua asiaa käytännössä. Tälle sivulle on koottu näiden harjoitusten vastaukset oppitunneittain. Nämä ovat eri asia kuin kurssin kotitehtävät: kotitehtävät ja niiden mallivastaukset löytyvät [kotitehtävien sivulta](../README.md).

Tee jokainen harjoitus aina ensin itse ja katso vastausta vasta sen jälkeen. Ohjelmointitehtäviin on lähes aina useampi kuin yksi oikea ratkaisu, joten oma ratkaisusi voi olla aivan yhtä oikea, vaikka se näyttäisi erilaiselta kuin alla oleva.

## print() ja type()

Oppitunti: <https://www.rosogames.fi/lms/2-pelinkehityksen-alkeet/lessons/print-type/>

### 1. Muuttujien tyypit

Tässä harjoituksessa ei tarvitse kirjoittaa mitään lisäkoodia. Tarkoituksena on vain tarkastella, mitä arvoja neljä `print`-funktiokutsua tuottavat.

```lua
-- "local" tarkoittaa, että muuttuja on paikallinen, ei globaali.
-- Palaamme paikallisten ja globaalien muuttujien eroon myöhemmin.
local variableA = "awesome text"
local variableB = 123
local variableC = true

print(variableA, type(variableA)) -- "awesome text"   "string"
print(variableB, type(variableB)) -- 123              "number"
print(variableC, type(variableC)) -- true             "boolean"
print(variableD, type(variableD)) -- nil              "nil"
```

Ensimmäinen `print` tulostaa `variableA`-muuttujan arvon (`"awesome text"`) ja `type()` palauttaa sen tyypin (`"string"`). Toinen tulostaa `variableB`-muuttujan arvon (`123`) ja tyypin (`"number"`). Kolmas tulostaa `variableC`-muuttujan arvon (`true`) ja tyypin (`"boolean"`). Neljäs tulostaa `variableD`-muuttujan arvon (`nil`), koska muuttujaa ei ole määritelty, ja `type()` palauttaa tyypiksi `"nil"`.

### 2. Taulukon tulostaminen

Tulosta tyhjä taulukko ja sen tyyppi.

```lua
local myTable = {}

-- Tulosta myTable ja sen tyyppi
print(myTable, type(myTable)) -- table: 04CB7D28   "table"
```

Tällä kertaa `myTable`-muuttujan tulostus ei anna selkeää arvoa, vaan jotain tämän kaltaista: `table: 04CB7D28`. Tarkka merkkijono voi vaihdella, sillä `print()` näyttää vain taulukon muistiviittauksen, ei sen sisältöä. Tämä johtuu siitä, että Lua käsittelee taulukot (ja funktiot) viittauksina tietokoneen muistiin.

`type()`-funktio sen sijaan palauttaa odotetusti muuttujan tyypin tekstimuodossa: `"table"`. Taulukoiden sisältöön ja niiden käsittelyyn perehdymme tarkemmin myöhemmissä oppitunneissa.

## number

Oppitunti: <https://www.rosogames.fi/lms/2-pelinkehityksen-alkeet/lessons/number/>

### 1. Laskutoimituksia

Tee muutama laskutoimitus (vähennys, kertolasku ja kaksi jakolaskua) ja tulosta niiden tulokset.

```lua
local miinus = 1951 - 5920
print( miinus ) -- -3969

local kerto = 183 * 7
print( kerto ) -- 1281

local jako1 = 60 / 5
print( jako1 ) -- 12

local jako2 = 61 / 3
print( jako2 ) -- 20.3333333333...
```

Aina kun suoritat Luassa laskuoperaatioita, niin tulos on aina samaa `number`-tyyppiä. Kokonaisluvuilla tehdyt yhteen-, vähennys- ja kertolaskut ovat tarkkoja: esimerkiksi `2 + 3` on täsmälleen 5 ja `2 * 5` on täsmälleen 10. Desimaaliluvut sen sijaan tallentuvat likiarvoina, joten juuri niiden yhtäsuuruutta ei kannata vertailla suoraan.

### 2. Numeroita vai ei?

Muunna kaksi tekstimuuttujaa numeroiksi `tonumber()`-funktiolla ja tulosta tulokset.

```lua
-- Kaksi teksti muuttujaa:
local myText1 = "0xff"
local myText2 = "12a"

-- Kirjoita koodisi alapuolelle:
local myNumber1 = tonumber( myText1 )
local myNumber2 = tonumber( myText2 )

print( myNumber1, myNumber2 )  -- 255, nil
```

Tuloksena `myNumber1` saa arvon `255`, koska merkkijono `"0xff"` on heksadesimaaliluku, jonka desimaalivastine on 255.

Sen sijaan `myNumber2` saa arvon `nil`, koska merkkijono `"12a"` ei ole kelvollinen numero, eikä sitä voi muuntaa numeeriseen muotoon.

Tämä harjoitus ja sen vastaus ovat vain pieni käytännön esimerkki numeroista Luassa. Sinun ei tarvitse huolehtia kymmenpotenssimuotoihin tai heksadesimaalilukuihin törmäämisestä Roso Gamesin yhteydessä.

Miksi näin tapahtuu?

- `tonumber()` yrittää muuntaa annetun arvon numeroksi.
- Jos muunnos onnistuu, palautetaan numeerinen arvo.
- Jos muunnos epäonnistuu, palautetaan `nil`.

Tämä tekee `tonumber()`-funktiosta erittäin hyödyllisen työkalun, kun halutaan varmistaa, että käsiteltävä arvo on varmasti numeerinen. Esimerkiksi käyttäjän syötteet tulevat usein tekstimuodossa, ja tällöin `tonumber()` voi muuntaa ne numeroiksi tai palauttaa `nil`, jos syöte ei ole kelvollinen.

`tonumber()` on tärkeä työkalu, kun käsitellään käyttäjän syötteitä tai epävarmoja arvoja. Se varmistaa, että ohjelma ei kaadu virheellisten syötteiden vuoksi, vaan palauttaa `nil`, jos arvoa ei voi muuntaa numeroksi. Tämä mahdollistaa virheiden hallinnan ja tekee ohjelmasta luotettavamman.

## string

Oppitunti: <https://www.rosogames.fi/lms/2-pelinkehityksen-alkeet/lessons/string/>

### 1. Tekstin muuttaminen isoiksi kirjaimiksi

Etsi Solar2D:n dokumentaatiosta oikea `string`-kirjaston funktio ja muuta merkkijonon kaikki kirjaimet isoiksi.

```lua
local myText = "Tampere on suomen lätkä kapitaali!"

-- Sinun koodisi:
local myCapitalText = string.upper(myText)
print(myCapitalText) -- "TAMPERE ON SUOMEN LäTKä KAPITAALI!"
```

Tämän harjoituksen tarkoituksena oli tutustua Solar2D:n dokumentaatioon ja oppia hakemaan tietoa sen sisältä. Dokumentaatiosta löytyy ohjeita useiden erilaisten `string`-kirjaston funktioiden käyttöön. Tässä tapauksessa halusimme muuntaa kaikki `myText`-muuttujan sisältämät kirjaimet isoiksi ja se onnistui `string.upper()`-funktion avulla.

Tulostuksessa näkyy kuitenkin, että kaikki kirjaimet eivät muuttuneet isoiksi: `"TAMPERE ON SUOMEN LäTKä KAPITAALI!"`. Tämä johtuu siitä, että ääkköset (`ä`, `ö`, `å`) eivät ole tavallisia alfanumeerisia merkkejä. Luan ja monien muiden ohjelmointikielten sisäänrakennetut funktiot eivät välttämättä osaa käsitellä erikoismerkkejä oikein. Näiden kanssa joudutaan usein turvautumaan UTF-8-yhteensopiviin kirjastoihin ja funktioihin. Vielä muistutuksena: tutustumme pluginien, eli lisäosien asentamiseen Solar2D:ssä myöhemmin, eli sinun ei tarvitse vielä huolehtia UTF-8:sta tai muista plugineista.

### 2. Tekstin yhdistäminen

Luo kaksi string-muuttujaa, esim. `firstName` ja `lastName`. Yhdistä ne yhdeksi muuttujaksi `fullName` siten, että välissä on välilyönti. Tulosta lopputulos.

```lua
local firstName = "Matti"
local lastName = "Meikäläinen"

local fullName = firstName .. " " .. lastName
print(fullName) -- "Matti Meikäläinen"
```

### 3. Tekstin pituus

Luo string-muuttuja, jossa on jokin lause. Käytä `string.len()`-funktiota ja tulosta, kuinka monta merkkiä lauseessa on.

```lua
local sentence = "Ohjelmointi on hauskaa!"
print(string.len(sentence)) -- 23 (huomaa, että ääkköset voivat laskea useampana tavuna)
```

### 4. Rivinvaihdot

Luo string, jossa on kaksi lausetta. Lisää niiden väliin rivinvaihto käyttämällä `\n`-erikoismerkkiä. Tulosta lopputulos ja tarkista, että teksti tulostuu kahdelle eri riville.

```lua
local myText = "Ensimmäinen lause.\nToinen lause."
print(myText)
-- Tulostaa:
-- Ensimmäinen lause.
-- Toinen lause.
```

### 5. Sanan etsiminen

Etsi lauseesta sana `"todella"` ja katso, mitä `string.find()` palauttaa. Kokeile myös etsiä sanaa `"vaikeaa"`.

```lua
local sentence = "Ohjelmointi on todella hauskaa!"

-- Etsitään sana "todella"
local startIndex, endIndex = string.find(sentence, "todella")
print(startIndex, endIndex) -- 16   22

-- Etsitään sana "vaikeaa"
local startIndex2, endIndex2 = string.find(sentence, "vaikeaa")
print(startIndex2, endIndex2) -- nil   nil
```

Tässä ratkaisussa `"todella"` löytyy kohdasta 16-22, mutta sanaa `"vaikeaa"` ei löydy, joten funktio palauttaa `nil`.

Näiden harjoitusten avulla opit käyttämään Luan `string`-kirjaston perusfunktioita:

- Tekstiä voi muuttaa isoiksi tai pieniksi kirjaimiksi, yhdistellä, mitata sen pituutta ja lisätä erikoismerkkejä kuten rivinvaihtoja.
- Teksti (tai merkkijonot) saattavat sisältää erikoismerkkejä ja niitä voi myös käsitellä erilaisten mallien (patterns) kautta.
- Nämä taidot ovat hyödyllisiä lähes kaikessa ohjelmoinnissa, sillä tekstin käsittely on yksi yleisimmistä tehtävistä.

## function

Oppitunti: <https://www.rosogames.fi/lms/2-pelinkehityksen-alkeet/lessons/function/>

### 1. Kolmen luvun kertominen

Luo funktio, joka ottaa kolme lukua parametreina, kertoo ne keskenään ja palauttaa tuloksen.

```lua
local function multiplyNumbers(number1, number2, number3)
	return number1 * number2 * number3
end

local result = multiplyNumbers(2, 15, 11)
print(result) -- 330
```

Funktio palauttaa arvon `330`, koska 2 * 15 * 11 = 330. Voit kokeilla myös suorittaa funktiota eri numeroilla.

### 2. Tervehdysfunktio

Luo funktio, joka ottaa nimen parametrina ja tulostaa tervehdyksen.

```lua
local function greet(name)
	print("Hei, " .. name .. "!")
end

greet("Matti") -- Hei, Matti!
greet("Liisa") -- Hei, Liisa!
```

Funktio yhdistää annetun nimen merkkijonoon ja tulostaa sen.

### 3. Funktio ilman parametreja

Luo funktio, joka lisää joka kutsulla yhden huutomerkin viestin perään ja tulostaa viestin. Kutsu funktiota viisi kertaa.

```lua
local message = "Hello World!"

local function helloWorld()
	message = message .. "!"
	print( message )
end

helloWorld() -- Hello World!!
helloWorld() -- Hello World!!!
helloWorld() -- Hello World!!!!
helloWorld() -- Hello World!!!!!
helloWorld() -- Hello World!!!!!!
```

Funktio toimii aina samalla tavalla riippumatta siitä, kuinka monta kertaa sitä kutsutaan, mutta se muokkaa funktion yläpuolella olevaa muuttujaa joka kerta.

## table

Oppitunti: <https://www.rosogames.fi/lms/2-pelinkehityksen-alkeet/lessons/table/>

### 1. Avain-arvo -parit

Luo taulukko avain-arvo -pareilla ja tulosta sen arvoja sekä piste- että hakasulkumerkinnällä.

```lua
local car = {
	brand = "Toyota",
	model = "Corolla",
	year = 2020
}

-- Taulukon arvot voi tulostaa piste-merkinnällä:
print( car.brand ) -- "Toyota"
print( car.year )  -- 2020

-- Tai ne voi tulostaa hakasulkeiden avulla:
print( car["brand"] ) -- "Toyota"
print( car["year"] )  -- 2020
```

### 2. Tiedonhaku taulukosta ja taulukon päivittäminen

Käytä alla olevaa `playerData`-taulukkoa ja tee sille neljä alitehtävää.

```lua
local playerData = {
	name = "John",
	health = 100,
	age = 25,
	inventory = {
		items = {
			{ name = "sword", damage = 10 },
			{ name = "shield", defense = 5 }
		},
		gold = 50
	}
}
```

1. Tulostetaan pelaajan nimi ja ikä.

```lua
print( playerData.name ) -- "John"
print( playerData.age ) -- 25
```

Eli aina kun haluamme tulostaa taulukon sisältä jonkin tietyn arvon, niin meidän tulee viitata taulukkoon ja sen sisällä oleviin mahdollisiin alataulukoihin ja lopulta haluamaamme muuttujaan. Taulukoiden sisällä olevat avaimet/muuttujat erotellaan pisteellä, kuten yläpuolella olevassa ratkaisussa näkyy. Vaihtoehtoisesti taulukon sisällä oleviin avaimiin/muuttujiin voi viitata hakasulkeilla, esim. `print( playerData["name"] )`.

2. Kasvatetaan pelaajan HP:ta (health) 20 pisteellä ja tulostetaan tämä arvo.

```lua
-- Arvo on 100, koska sitä ei ole vielä muutettu.
print( playerData.health ) -- 100

-- Kasvatetaan arvoa 20 pisteellä.
playerData.health = playerData.health + 20
print( playerData.health ) -- 120
```

3. Tulostetaan pelaajan ensimmäisen esineen nimi.

```lua
-- items -taulukko löytyy playerData -taulukon sisäisestä taulukosta.
-- Meidän tulee siis mainita jokainen "taulukko askel" erikseen, ihan
-- kuin tietokoneen kansioiden ja tiedostojen nimien kanssa.

-- Koska items -taulukossa ei ole erikseen nimettyjä indeksejä, meidän
-- tulee viitata niihin numeroilla. Taulukon ensimmäinen arvo on 1, eli:
print( playerData.inventory.items[1].name ) -- "sword"
```

4. Voimme lisätä `playerData` -taulukkoon uuden esineen joko lisäämällä sen samalla kun taulukkoa luodaan, tai lisäämällä sen taulukon luomisen jälkeen. Esimerkiksi,

```lua
-- Lisätään uusi esine taulukkoa luotaessa:
local playerData = {
	name = "John",
	health = 100,
	age = 25,
	inventory = {
		items = {
			{ name = "sword", damage = 10 },
			{ name = "shield", defense = 5 },
			{ name = "potion", heal = 10 }
		},
		gold = 50
	}
}
```

Tai vaihtoehtoisesti voimme lisätä esineen taulukkoon myöhemmin:

```lua
-- Lisätään uusi esine taulukon luomisen jälkeen:
local playerData = {
	name = "John",
	health = 100,
	age = 25,
	inventory = {
		items = {
			{ name = "sword", damage = 10 },
			{ name = "shield", defense = 5 }
		},
		gold = 50
	}
}

-- Tapa 1: table.insert funktio.
table.insert( playerData.inventory.items, { name = "potion", heal = 10 } )

-- Tapa 2: pituus operaattorin käyttö.
playerData.inventory.items[#playerData.inventory.items + 1] = { name = "potion", heal = 10 }
```

## Toistorakenteet (loops)

Oppitunti: <https://www.rosogames.fi/lms/2-pelinkehityksen-alkeet/lessons/toistorakenteet-loops/>

### 1. for loop

Luo `for` loop, joka alkaa indeksistä `15`, loppuu indeksiin `2` ja jonka askelväli (step) on `-3`. Tulosta jokaisen iteraation numero. Mitä numeroita tulostuu ja tulostuuko luku 2?

`for` looppien rakenne oli seuraava:

```lua
for index = startIndex, endIndex, step do
	-- Suoritettava koodi.
end
```

Tehtävänannossa sanotaan, että loop alkaa indeksistä `15`, loppuu indeksiin `2` ja sen askelvälin tulee olla `-3`. Lisäksi jokaisen iteraation numero tulee tulostaa, eli:

```lua
for index = 15, 2, -3 do
	print( index )
end
```

Tämä tulostaa:

```lua
15
12
9
6
3
```

Luku 2 ei siis tulostu. Tämä johtuu siitä, että loopille on annettu askelväliksi -3, eli se laskee aina 3 lukua kerralla alaspäin. Viimeinen tulostettava luku on 3 ja siitä seuraava luku olisi vasta 0. Luku 2 ei siis tulostuisi missään tilanteessa, koska askelvälimme hyppäisi sen yli ja seuraava luku (0), on jo loopin ehtojen ulkopuolella.

### 2. loopin keskeyttäminen

Ota tehtävänannon esimerkkifunktio ja korvaa sen `for` loop `while`- tai `repeat`-loopilla.

```lua
local myTable = { "Kahvi", "Tee", "Maito", "Vesi" }

local function findTableIndex( t, value )
	-- Suoritetaan loop niin monta kertaa kuin
	-- funktioon syötetyllä taululla on arvoja.
	for i = 1, #t do
		-- Jos arvo löytyy palautetaan arvo.
		-- Tämä keskeyttää samalla loopin.
		if t[i] == value then
			return i
		end
	end

	-- Jos arvoa ei löydy, niin palautetaan nil.
	return nil
end

local index = findTableIndex( myTable, "Vesi" )
print( index ) -- 4
```

Yläpuolella oleva funktio hyödyntää `for` looppia. Tehtävänannossa pyydetään korvaamaan se `while` tai `repeat` loopilla. Näiden kahden loopin ja `for` loopin välillä oli se tärkeä ero, että näille loopeille tulee muistaa erikseen määrittää lopetus tai keskeytys ehto, etteivät ne jää vahingossa looppaamaan ikuisesti ja kaada ohjelmaa.

Tehdään siis funktioon tarvitut muutokset ja suoritetaan sitten vaaditut testit.

```lua
local myTable = { "Kahvi", "Tee", "Maito", "Vesi" }

local function findTableIndex( t, value )
	-- i, niin kuin iteraatio (tai indeksi).
	local i = 1

	-- Toistetaan while loop niin kauan kuin iteraation
	-- luku on pienempi kuin annetun taulukon mitta.
	while i <= #t do
		-- Jos arvo löytyy palautetaan arvo.
		-- Tämä keskeyttää samalla loopin.
		if t[i] == value then
			return i
		end
		-- Muista korottaa iteraation arvoa aina yhdellä.
		-- Jos arvoa ei muista korottaa, niin
		-- silloin joudutaan ikuiseen looppiin.
		i = i + 1
	end

	-- Jos arvoa ei löydy, niin palautetaan nil.
	return nil
end

local indexWater = findTableIndex( myTable, "Vesi" )
print( indexWater ) -- 4

local indexMilk = findTableIndex( myTable, "Maito" )
print( indexMilk ) -- 3

local indexCola = findTableIndex( myTable, "Cola" )
print( indexCola ) -- nil
```

"Vesi" ja "Maito" löytyvät funktioon syötetystä taulukosta, joten funktio palauttaa niitä vastaavat indeksit, eli niiden paikan taulukossa. Taulukosta ei löydy "Cola" arvoa, jolloin funktio looppaa taulukon läpi ilman tulosta ja funktion viimeinen rivi palauttaa `nil` arvon, kertoakseen käyttäjälle, ettei arvoa löytynyt taulukosta, eli sille ei ole indeksiä.

Muista, että Lua on merkkikokoriippuvainen. Tämä tarkoittaa, että "Vesi" ja "vesi" ovat eri asioita, eikä funktio löytäisi taulukosta arvoa, jos nämä eivät ole kirjoitettu identtisesti. Tällaisissa tilanteissa voit hyödyntää esim. `string.lower` funktiota ja vertailla tekstejä vasta sen jälkeen kun olet muuttanut molemmat käyttämään pieniä kirjaimia. Tämä voi olla joskus hyödyllistä, mutta toisinaan taas haluamme (haku)termien olevan tarkkoja. Esim. "Aine" voi todennäköisesti viitata Aine-nimiseen henkilöön, kun taas "aine" voi viitata johonkin aineeseen.

## Oikeaoppisen koodin kirjoittaminen Luassa

Oppitunti: <https://www.rosogames.fi/lms/2-pelinkehityksen-alkeet/lessons/oikeaoppisen-koodin-kirjoittaminen-luassa/>

### Koodin sisennys

Harjoituksessa annetaan huonosti sisennetty `processOrders`-funktio, ja tehtävänä on sisentää se oikein.

Oikein sisennetty koodi:

```lua
local function processOrders(orders)
	for i, order in ipairs(orders) do
		if order.isPaid == true then
			if order.amount > 100 then
				print("Large order:", order.id)
			else
				print("Regular order:", order.id)
			end
		else
			print("Unpaid order:", order.id)
		end
	end
	print("All orders processed.")
end

local orders = {
	{ id = 1, isPaid = true,  amount = 50  },
	{ id = 2, isPaid = false, amount = 200 },
	{ id = 3, isPaid = true,  amount = 150 }
}

processOrders(orders)
```
