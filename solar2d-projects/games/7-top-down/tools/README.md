# Tuotantoskriptit

Nämä skriptit tuottavat top-down-seikkailupelin grafiikka-assetit ja Tiled-kartat uudelleen lähdemateriaalista. Ne ovat alkutuotannon apuvälineitä: kun Eetu on kerran muokannut karttoja Tiledissä, JSON-tiedostot ovat totuuden lähde eikä `build_maps.py`-skriptiä pidä enää ajaa uudelleen, koska se ylikirjoittaisi käsin tehdyt muutokset.

Kaikki skriptit käyttävät vain Pythonin standardikirjastoa ja Pillow'ta, ja polut ratkeavat suhteessa skriptin sijaintiin, joten ne voi ajaa mistä tahansa.

## build_assets.py

Suurentaa Kenneyn 16 pikselin spritesheetit 2x nearest neighbour -skaalauksella, kokoaa karttojen tilesetin extrudatuin reunoin ja pakkaa hahmot ja esineet valmiiksi image sheeteiksi. Tuottaa kansioon `../extra-assets/` tiedostot `tileset-topdown.png`, `characters.png` ja `items.png`, ja tarkistaa lopuksi tilesetin reunukset (`--check` ajaa pelkän tarkistuksen). Tilesetin tilet ja talojen koosteet (stampit) määritellään tiedostossa `tile_palette.py`, jota myös karttojen rakentaja käyttää. Hahmojen ja esineiden valinnat muutetaan skriptin taulukoista `CHARACTERS` ja `ITEMS`.

```
python build_assets.py
```

## generate_interact_sfx.py

Tuottaa vuorovaikutuksen ääniefektin `../extra-assets/audio/interact.wav`, lyhyen nousevan kahden sävelen piippauksen. Pelin kaikki assetit ovat mukana jo versiossa 0, joten äänitiedostot on kopioitu jokaisen versiokansion `assets/audio/`-kansioon; uudelleen tuotettu tehoste kopioidaan samoin kaikkiin versioihin.

```
python generate_interact_sfx.py
```

## build_maps.py

Tuottaa kolme Tiled-JSON-karttaa (`village.json`, `house.json`, `sideroad.json`) jokaisen versiokansion `maps/`-kansioon. Kartat viedään täsmälleen siinä muodossa, jonka Tiled itse tuottaa (ortogonaalinen, upotetut tilesetit, pakkaamattomat layerit), joten ponytiled osaa ladata ne ja osallistujat voivat avata ne Tiledissä. Tilet nimetään tiedoston `tile_palette.py` kautta, ja kartan rakenne (koot, rakennukset, polut, aidat, puut, objektit) on skriptin `VILLAGE_*`-, `HOUSE_*`- ja `ROAD_*`-taulukoissa muokattavana datana. Skripti tarkistaa rakentaessaan, ettei kaksi asiaa osu samaan tileen ja että spawn-pisteet, uloskäynnit, triggerit, esineet ja NPC:t ovat saavutettavissa pelaajahahmon aloituspaikasta.

Kun karttoja on kerran muokattu käsin Tiledissä, JSON-tiedostot ovat totuuden lähde, eikä skriptiä pidä enää ajaa niiden päälle, koska se ylikirjoittaisi käsin tehdyt muutokset.

Kurssissa on 16 vaihetta (`versio-0` ... `versio-15`), ja jokainen saa kaikki kolme karttaa. Vaiheiden erot:

- Versiot 0-3: peruskartat. Kylän viestitriggerit (`zoneWestRoad`, `zoneNorthRoad`) ja esineet ovat mukana kaikissa versioissa; versiot, joista vastaava extension vielä puuttuu, jättävät ne huomiotta.
- Versiosta 4 alkaen kylään upotetaan Collection of Images -tileset `images`, ja aukion keskelle tulee kaivo (`well`, 80 x 80 pikselin tile-objekti, ominaisuudet `bodyType` static ja `radius` 36).
- Versiosta 11 alkaen kylän uloskäynti rantatielle (`exitToSideRoad`) on lukittu ominaisuuksilla `requiredQuest` 1 ja `lockedMessage`.

```
python3 -B build_maps.py --version N --out DIR   # yksi vaihe kansioon DIR
python3 -B build_maps.py --all [ROOT]            # kaikki ROOT/versio-N/maps-kansiot (oletus: pelin kansio)
python3 -B build_maps.py --all ROOT --preview    # lisäksi esikatselut kansioon ../.scratch/map-previews/
```

Skripti kopioi karttojen kuvat (`tileset-topdown.png`, `characters.png`, `items.png` ja `well.png`) kansiosta `../extra-assets/` karttojen rinnalle jokaisen version `versio-N/maps/`-kansioon. Kaivon kuva kopioidaan myös versioihin 0-3, vaikka niiden kartoissa ei vielä ole kaivoa, koska pelin kaikki assetit ovat mukana jo versiossa 0. Kartat viittaavat niihin pelkällä tiedostonimellä, jolloin sekä Tiled että ponytiledin ajonaikainen polunratkaisu löytävät ne samasta paikasta. `--all` poistaa samalla vanhentuneet tiedostot `city.json` ja `tileset-roguelike-2x.png`.

Kartan extensionit (hero, npc, item) lataavat hahmojen image sheetin polusta `maps/characters.png` ja esineiden image sheetin polusta `maps/items.png`, joten kuvien on oltava karttojen vieressä.

## render_maps.py

Renderöi valmiit kartat PNG-esikatseluiksi: layerit koostetaan tilesetin marginaali ja välit huomioiden, hahmot, esineet ja kaivo piirretään objektien kokoisina, ja jokainen objekti merkitään värillä ja nimellä. Tämä on sama renderöijä, jonka `build_maps.py --preview` kutsuu (se renderöi versiot 3 ja 4, eli viimeisen ilman kaivoa ja ensimmäisen kaivon kanssa). Käytetään karttojen visuaaliseen tarkistukseen; esikatselut kuuluvat `.scratch`-kansioon.

```
python3 -B render_maps.py                               # oletus: ../versio-15/maps -> ../.scratch/map-previews/
python3 -B render_maps.py ../versio-4/maps ../.scratch/map-previews/versio-4
```

## validate_maps.py

Tarkistaa kartat rakenteellisesti ja karttojen väliset viittaukset: jokaisen uloskäynnin kohdekartta on olemassa, kohteen spawn-piste löytyy kohdekartasta, kaikki gidit ovat tilesetin sisällä ja jokaisen tile layerin gidit pysyvät layerin omassa tilesetissä. Tileset-kuvat ja Collection of Images -tilesetin kuvat (kaivo) on löydyttävä kartan vierestä ilmoitetun kokoisina, ja extrudatun tilesetin jokaisen reunuspikselin on vastattava viereisen tilen reunapikseliä. Viestitriggereistä tarkistetaan, että niillä on `message`-ominaisuus ja että ne ovat sensoreita, ja yksikään exit- tai zone-sensori ei saa jäädä kiinteän seinän sisään (haudattu sensori ei voi koskaan laueta). Lukitusominaisuudet `requiredQuest` (positiivinen kokonaisluku) ja `lockedMessage` (ei-tyhjä merkkijono) saavat esiintyä vain yhdessä ja vain uloskäynneissä, ja lukitun uloskäynnin on oltava kartan reunalla kiinteä seinä heti takanaan, koska lukittu portti vain näyttää viestin eikä pysäytä pelaajaa. Kun kansio on `versio-N/maps`, tarkistetaan myös vaiheen sisältö: kylässä on kaivo täsmälleen versiosta 4 alkaen ja rantatien portti on lukittu täsmälleen versiosta 11 alkaen. Tarkistukset on johdettu suoraan siitä, mitä `com/ponywolf/ponytiled.lua` oikeasti jäsentää. Palauttaa nollasta poikkeavan paluuarvon, jos jokin on pielessä.

```
python3 -B validate_maps.py                    # oletus: ../versio-15/maps
python3 -B validate_maps.py ../versio-4/maps
```

## verify_story.lua

Ajaa pelin tarinatiedoston oikean, vendoroidun Weaver-tarinamoottorin ja pelin dialogimoduulin läpi pienillä Solar2D-stubeilla ja tarkistaa tehtäväketjun. Toinen argumentti on versionumero, ja assertit ajetaan vaiheittain:

- 8: Weaver-perusdialogi (kylän vanhimman esittäytyminen ja vaihtoehdot, rannan muukalaisen jutustelu). Lisäksi tarkistetaan, ettei Weaver kirjoita tallennusta itsestään ja että tarina ladataan kerran `main.lua`-tiedostossa eikä pelinäkymässä, koska pelinäkymän lataama tarina nollaisi tehtävätilan jokaisessa kentän vaihdossa.
- 9: tehtäväketju (`intro` ohjaa vanhimman luo, vanhin antaa tehtävän ja kertoo rantatien alkavan eteläportilta, muukalainen vain tervehtii ennen tehtävää ja vastaa vasta tehtävän ollessa aktiivinen, raportti vanhimmalle päättää ketjun).
- 10: viestin antaminen ja toimitus palautuvat omina `<<annaViesti>>`- ja `<<toimitaViesti>>`-komentoina taulukkoina.
- 11: `dialogue.getFlag` lukee saman tehtävätilan, jota lukittu portti käyttää.
- 13: tarinan tallennus ja lataus: `dialogue.save` kirjoittaa Weaverin tallennuksen, `dialogue.init` aloittaa tarinan alusta tallennuksesta huolimatta, `dialogue.load` palauttaa tallennushetken tilan, ja tallennus, josta puuttuu uusia passageja ja muuttujia, täydentyy oletusarvoilla eikä kaada Weaveria.
- 15: taustarepliikin (`npcTausta`) regressiotarkistus. Se arpoo repliikin ~200 kertaa ja vaatii, että jokainen tulos on yksi odotetuista puhtaista merkkijonoista ilman lainausmerkkejä. Tämä koodaa pysyvän sisältösäännön: **Weaverin `(either: ...)` pilkkoo sulkeiden sisällön naiivisti pilkuilla (`spyricStoryWeaver.lua`, funktio `either`), joten yksikään vaihtoehto ei saa sisältää pilkkua.** Jos tarinaan lisää uusia either-vaihtoehtoja, ne on kirjoitettava pilkuttomiksi ja lisättävä odotettujen merkkijonojen joukkoon.

Lisäksi jokainen vaihe ajaa Weaverin syntaksitarkistuksen erillisellä testitarinalla, joka kirjoitetaan väliaikaiskansioon. Se varmistaa Weaver 0.10.1:n säännöt, joihin uudet tarinat voivat nojata: `//`- ja `#`-alkuiset rivit ovat kommentteja, ja muuttujien nimissä saa olla alaviivoja (`$has_key`, `_door_open`), myös kun `$`- ja `_`-muuttujia on samassa ehdossa. Alaviiva aloittaa väliaikaisen muuttujan vain sanan alussa.

Weaverin tallennukset kirjoitetaan ajon ajaksi omaan väliaikaiskansioon, joka poistetaan lopuksi. Testiskriptin `table.copy`-stubi kopioi Solar2D:n tavoin vain taulukon numeroavaimet, jottei testi peitä nimettyjen kenttien katoamista.

```
lua5.1 verify_story.lua ../versio-9 9
lua5.1 verify_story.lua ../versio-15 15
```

## verify_exit.lua

Ajaa pelin oikean `maps/extensions/exit.lua`-extensionin mockatuilla törmäystapahtumilla ja tarkistaa siirtymäportit: lukitsematon portti siirtää pelaajan kohdekarttaan seuraavalla framella, siirtymä käynnistyy vain kerran, lukittu portti (`requiredQuest` ja `lockedMessage`) näyttää viestin eikä siirrä pelaajaa ennen tehtävää ja päästää läpi, kun tehtävä on edennyt. Portin lukitus on olemassa versiosta 11 alkaen.

```
lua5.1 verify_exit.lua                          # oletus: versio 15
lua5.1 verify_exit.lua ../versio-11
```

## verify_camera.lua

Ajaa pelin oikean `classes/camera.lua`-moduulin pienillä stubeilla ja tarkistaa, että kamera asettaa karttaryhmän aina kokonaisiin sisältöpikseleihin: kohdistuksessa, smoothingilla tehdyssä seurannassa murto-osaisilla kohdesijainneilla ja shaken aikana. Murto-osainen ryhmän sijainti avaa tilejen väliin yhden pikselin saumoja, kun kamera liikkuu. Kamera on sama kaikissa versioissa.

```
lua5.1 verify_camera.lua                        # oletus: versio 15
```

## verify_loadsave.lua

Ajaa pelin oikean `scripts/loadsave.lua`-moduulin pienillä Solar2D-stubeilla (muistinvarainen tiedostojärjestelmä sekä yksinkertainen JSON-stubi) ja tarkistaa tallennuksen kestävyyden: tallennuksen ja latauksen round tripin, puuttuvan tiedoston (palautuu nil), rikkinäisen tiedoston (palautuu nil kaatumatta), poiston (`loadsave.delete`) sekä pelitilan versio 13 -tallennusmuodon round tripin. Moduuli on sama versioissa 12-15.

```
lua5.1 verify_loadsave.lua                          # oletus: versio 15
lua5.1 verify_loadsave.lua ../versio-12
```

## verify_inventory.lua

Ajaa pelin oikean `scripts/inventory.lua`-moduulin (ruudukkomalli) ja `maps/extensions/item.lua`-extensionin pienillä stubeilla ja tarkistaa esinepaikkojen logiikan: lisäyksen ensimmäiseen vapaaseen paikkaan, `has`/`remove`-haun tunnisteella, siirron ja vaihdon paikkojen välillä, täyden repun, aloitusesineet sekä esinepaikkojen `json.encode`/`json.decode`-round tripin, joka todistaa ettei serialisointi tarvitse harvaa taulukkoa (merkkijonoavaimet säilyvät ehjinä). Toinen argumentti on versionumero: vaiheessa 10 poimittu esine ilmestyy takaisin, kun kartta rakennetaan uudelleen (oppitunnin päättävä ongelma), vaiheesta 11 alkaen poimintarekisteri estää sen, ja vaiheesta 13 alkaen tarkistetaan myös `reset` ja `restore`. Inventory on olemassa versiosta 10 alkaen.

```
lua5.1 verify_inventory.lua                          # oletus: versio 15
lua5.1 verify_inventory.lua ../versio-10 10
```

## verify_zone.lua

Ajaa pelin oikean `maps/extensions/zone.lua`-extensionin mockatuilla törmäystapahtumilla ja tarkistaa viestitriggereiden laukeamislogiikan: aina laukeava triggeri laukeaa jokaisella saapumisella, `once`-triggeri vain kerran, rekisteri on karttakohtainen, `restore` estää tallennuksessa jo lauenneen triggerin uusintalaukeamisen ja `reset` nollaa rekisterin uutta peliä varten. Trigger-extension on olemassa vasta versiossa 15.

```
lua5.1 verify_zone.lua                          # oletus: versio 15
```

Kaikki Lua-testiskriptit palauttavat nollasta poikkeavan paluuarvon, jos jokin assert epäonnistuu. Ne ajetaan tästä kansiosta; `luacheck versio-N` ajetaan pelin kansiosta, jotta `.luacheckrc` on käytössä.
