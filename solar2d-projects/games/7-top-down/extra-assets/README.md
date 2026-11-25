# Top-down-seikkailu: lisäassetit

Pelin kaikki grafiikka ja äänet ovat mukana jo `versio-0`-kansiossa. Tässä kansiossa ovat niiden alkuperäiset tiedostot. Tein kaivon kuvan käyttäen Kenneyn tilesettiä mallina.

## Tilesetin Tiled-parametrit

Kun lisäät `tileset-topdown.png`-kuvan tilesetiksi Tiledissä, käytä näitä arvoja, jotta tilet osuvat kohdalleen:

| Parametri | Arvo |
| --- | --- |
| tilewidth | 32 |
| tileheight | 32 |
| margin | 2 |
| spacing | 4 |

Jokaisen tilen ympärillä on 2 pikselin reunus, joka toistaa tilen reunan väriä. Se estää tilejen väliin ilmestyvät ohuet viivat, kun kamera liikkuu.

Kartat viedään Tiledistä JSON-muodossa ja CSV-muotoisilla layereilla, koska ponytiled ei osaa lukea base64- tai pakattuja layereita. Tilesetit upotetaan karttoihin.

## Image sheetit

Molemmissa image sheeteissä framet ovat yhdellä rivillä, ja jokainen frame on 32 x 32 pikseliä.

| Frame | `characters.png` | `items.png` |
| --- | --- | --- |
| 1 | pelaajahahmo | Marlow'n viesti |
| 2 | kylän vanhin Wren | punainen kirja |
| 3 | kartanpiirtäjä Marlow | kolikkopino |
| 4 | taustan NPC, nainen oranssissa | soihtu |
| 5 | taustan NPC, nainen esiliinassa | lasipullo |
| 6 | taustan NPC, mies liivissä | |

Hahmoilla ei ole kävelyanimaation frameja, joten liikkumisen tuntu tehdään koodissa.
