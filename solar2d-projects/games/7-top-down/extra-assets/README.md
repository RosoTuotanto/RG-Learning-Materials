# Top-down-seikkailu: assetit

Tässä kansiossa ovat top-down-seikkailupelin grafiikka- ja ääniassetit sekä niiden lähdemateriaalit. Grafiikka on peräisin Kenneyn ilmaisista CC0-paketeista kaivon kuvaa lukuun ottamatta, ja äänet on tehty itse.

## Lisenssi

Kaikki Kenneyn grafiikka on lisensoitu Creative Commons Zero (CC0) -lisenssillä, eli se on vapaasti käytettävissä myös kaupallisesti eikä vaadi nimeämistä. Kenney kuitenkin mainitaan pelin krediiteissä ja tässä oppimateriaalissa hyvän tavan mukaisesti. Alkuperäiset lisenssitiedostot on säilytetty pakettien mukana kansioissa `kenney_roguelike-rpg-pack/License.txt` ja `kenney_roguelike-characters/License.txt`.

Taustamusiikit on sävelletty itse, ja vuorovaikutuksen ääniefekti on tuotettu itse Pythonin standardikirjastolla. Nekin ovat vapaasti käytettävissä.

## Lähteet ja latauspäivä

Molemmat paketit ladattiin 2026-08-16 suoraan Kenneyn sivustolta.

- Roguelike/RPG pack: paketin sivu [https://kenney.nl/assets/roguelike-rpg-pack](https://kenney.nl/assets/roguelike-rpg-pack), suora latausosoite `https://kenney.nl/media/pages/assets/roguelike-rpg-pack/12c03cd78b-1677697420/kenney_roguelike-rpg-pack.zip`. Tiedosto tallennettu nimellä `kenney_roguelike-rpg-pack.zip` ja purettu kansioon `kenney_roguelike-rpg-pack/`.
- Roguelike Characters (2.0): paketin sivu [https://kenney.nl/assets/roguelike-characters](https://kenney.nl/assets/roguelike-characters), suora latausosoite `https://kenney.nl/media/pages/assets/roguelike-characters/53ffff4133-1729196490/kenney_roguelike-characters.zip`. Tiedosto tallennettu nimellä `kenney_roguelike-characters.zip` ja purettu kansioon `kenney_roguelike-characters/`.

## Tiedostot

Pelissä käytettävät, valmiiksi 2x-suurennetut tiedostot kaivon kuvaa lukuun ottamatta on tuotettu skripteillä kansiossa `../tools/`. Suurennos on tehty nearest neighbour -skaalauksella (`Image.NEAREST`), jotta pikselit pysyvät terävinä. Skriptit voi ajaa uudelleen, jos valintoja muuttaa.

- `tileset-topdown.png`: Tiled-karttojen tileset, johon on valittu RPG-paketista vain pelin tarvitsemat tilet (maasto, luonto, aidat, talojen osat ja sisätilat) 2x-suurennettuina. Valinta ja tilejen nimet ovat tiedostossa `../tools/tile_palette.py`.
- `well.png`: ylhäältä kuvattu pyöreä kaivo, 80 x 80 pikseliä. Tein kaivon kuvan käyttäen Kenneyn tilesettiä mallina. Koko ei ole 32:n monikerta, koska kaivo näyttää, että kartan objekti voi olla minkä kokoinen kuva tahansa eikä vain yksi tile.
- `characters.png`: pelin hahmojen image sheet, kuusi framea yhdellä rivillä.
- `items.png`: pelin esineiden image sheet, viisi framea yhdellä rivillä.
- `audio/outdoors.mp3`: ulkotilan taustamusiikki, luupattava raita.
- `audio/indoors.mp3`: sisätilan taustamusiikki, luupattava raita.
- `audio/interact.wav`: vuorovaikutuksen ääniefekti, lyhyt nouseva kahden sävelen piippaus. Tuotettu skriptillä `../tools/generate_interact_sfx.py`.
- `kenney_roguelike-rpg-pack/` ja `kenney_roguelike-characters/`: puretut alkuperäiset paketit lisensseineen ja esimerkkeineen. Näitä ei käytetä pelissä suoraan, vaan ne ovat lähdemateriaalia tuotantoskripteille.
- `kenney_roguelike-rpg-pack.zip` ja `kenney_roguelike-characters.zip`: alkuperäiset latauspaketit muuttumattomina alkuperän varmistamista varten.

## Lähdemateriaalin tile-mitat

Molempien Kenneyn spritesheetien tile on 16 x 16 pikseliä, tilejen välissä on 1 pikselin väli eikä sheetin reunoilla ole marginaalia. Tämä on tarkistettu itse kuvatiedostoista, ei oletettu.

| Spritesheet | Kuvakoko | Tile | Väli | Marginaali | Sarakkeita | Rivejä | Tilejä |
|-------------|----------|------|------|------------|------------|--------|--------|
| roguelikeSheet_transparent.png | 968 x 526 | 16 x 16 | 1 | 0 | 57 | 31 | 1767 |
| roguelikeChar_transparent.png | 918 x 203 | 16 x 16 | 1 | 0 | 54 | 12 | 648 |

Hahmojen spritesheetillä tilejä on 648, mutta suuri osa on tyhjiä; varsinaisia sprite-kuvia on noin 450. Kokonaiset hahmot ovat sarakkeissa 0 ja 1, ja kaikki niiden oikealla puolella on modulaarisia osia (paidat, hiukset, kasvot, kilvet, aseet). Hahmoilla ei ole kävelyanimaation frameja, vaan jokainen hahmo on yksi edestäpäin kuvattu asento.

## Valmiin tilesetin Tiled-parametrit

`tileset-topdown.png` on tarkoitettu Tiledin tileset-tiedostoksi. Käytä näitä arvoja täsmälleen, jotta tilet osuvat kohdalleen:

| Parametri | Arvo |
|-----------|------|
| Kuvakoko | 360 x 396 |
| tilewidth | 32 |
| tileheight | 32 |
| margin | 2 |
| spacing | 4 |
| columns | 10 |
| tilecount | 110 |

Tilejä on käytössä 109, ja viimeinen paikka on läpinäkyvä. Tilet on extrudattu: jokaisen tilen ympärillä on 2 pikselin reunus, joka toistaa tilen omaa uloimman rivin ja sarakkeen väriä. Siksi sheetin reunalla on 2 pikselin marginaali ja tilejen välissä 4 pikselin väli. Extrudointi estää saumat: kun kamera liikkuu ja tile piirretään puolikkaan pikselin kohdalle, näytönohjain voi lukea väriä hieman tilen ulkopuolelta, ja läpinäkyvästä välistä luettu väri näkyisi ohuena viivana tilejen välissä. `tools/build_assets.py` tarkistaa rakennuksen jälkeen, että jokainen reunuspikseli vastaa tilen reunaa ja että ponytiledin kaavalla lasketut tilet osuvat täsmälleen tilejen sisältöön.

Kartat viedään Tiledistä JSON-muodossa ja CSV-muotoisilla layereilla, koska ponytiled ei osaa lukea base64- tai pakattuja layereita. Tilesetit upotetaan karttoihin, jotta jokainen kartta on yksi itsenäinen tiedosto, jota myös projektin tarkistustyökalut lukevat suoraan.

## Hahmojen image sheet

`characters.png` on kuuden framen image sheet yhdellä rivillä, ilman väliä ja marginaalia. Solar2D-kutsu:

`graphics.newImageSheet( "characters.png", { width = 32, height = 32, numFrames = 6, sheetContentWidth = 192, sheetContentHeight = 32 } )`

Framejen järjestys (Solar2D:n framenumerot alkavat 1:stä):

| Frame | Nimi | Rooli pelissä |
|-------|------|---------------|
| 1 | hero | pelaajahahmo, sinihuppuinen kulkija |
| 2 | npc_house | kylän vanhin Wren, valkohiuksinen vanhus (talo) |
| 3 | npc_beach | rannalle leiriytynyt kartanpiirtäjä Marlow, parrakas mies (rantatie) |
| 4 | npc_bg_woman_orange | taustan NPC, vaaleahiuksinen nainen oranssissa |
| 5 | npc_bg_woman_apron | taustan NPC, punahiuksinen nainen esiliinassa |
| 6 | npc_bg_man_vest | taustan NPC, lyhythiuksinen mies liivissä |

Koska hahmoilla ei ole kävelyanimaation frameja, jokaisen hahmon "animaatio" on yksi frame. Liikkumisen tuntu tehdään koodissa (esimerkiksi kevyt pomppu ja hahmon flippaus liikkeen suuntaan), ei frameja vaihtamalla.

## Esineiden image sheet

`items.png` on viiden framen image sheet yhdellä rivillä, ilman väliä ja marginaalia. Solar2D-kutsu:

`graphics.newImageSheet( "items.png", { width = 32, height = 32, numFrames = 5, sheetContentWidth = 160, sheetContentHeight = 32 } )`

| Frame | Nimi | Rooli pelissä | Lähdetile RPG-spritesheetillä (col,row) |
|-------|------|---------------|-----------------------------------------|
| 1 | note | tehtäväesine, Marlow'n sinetöity viesti, joka viedään kylän vanhimmalle | 42,15 |
| 2 | book_red | vapaaehtoinen kerättävä, punainen kirja | 46,15 |
| 3 | coins | repun aloitusesine, kolikkopino, ei roolia pelissä | 45,11 |
| 4 | torch | repun aloitusesine, soihtu, ei roolia pelissä | 17,7 |
| 5 | bottle | rannalta löytyvä kerättävä, rantaan ajautunut lasipullo | 54,14 |
