# Ohjelmointi: Fysiikkapallon pisteytys

[Tehtävänannot](../../README.md) lisäävät Fysiikkapallo-peliin pisteytyksen kolmella tasolla: Ensiaskeleet (pisteiden lisääminen), Seikkailu (pistekertoimet ja high score) ja Haaste (korkeuteen perustuvat pisteet).

Mallivastausprojekti löytyy kansiosta [`solar2d-projects/games/3-fysiikkapallo/versio-kotitehtavat/`](../../../../solar2d-projects/games/3-fysiikkapallo/versio-kotitehtavat/), ja voit tarkistaa oman ratkaisusi myös alla olevilla listoilla.

## Tarkista omasta ratkaisustasi

Ensiaskeleet:

- Pelaaja saa pisteen vain sääntöjen mukaisesta maaliin osumisesta, eli ei silloin, kun varoitusindikaattori on näkyvissä.
- Pisteet näkyvät tekstiobjektissa ja teksti päivittyy heti, kun pisteet muuttuvat.

Seikkailu:

- Pisteet nollautuvat, kun pelaaja aloittaa uuden heiton.
- Kerroin kasvaa tasoihin osumisesta ja maaliin osuessa käytetään viimeisimmän osuman kerrointa.
- Kertoimia ei kasvateta, kun pelaaja pitää vielä pallosta kiinni.
- Saman heiton useat maaliosumat käsitellään erillisinä tapahtumina.
- Score-teksti näyttää sekä pisteet että kertoimen, ja ne jäävät heiton päätyttyä näkyviin.
- High score tallentaa korkeimman yhdellä heitolla saavutetun pistemäärän.

Haaste:

- Maaliosuman pisteet riippuvat maalin korkeudesta ruudulla.
- Saman heiton maaliosumien pisteet lasketaan yhteen.
- Useampaan tasoon osuessa kertoimet lasketaan yhteen ja summaa käytetään seuraavassa maaliosumassa.

## Testaa peliäsi

- Heitä pallo suoraan maaliin ilman tasoja: pisteitä pitäisi tulla kertoimella 1.
- Kimmota pallo yhden tai useamman tason kautta maaliin ja tarkista, että kerroin vastaa odotustasi.
- Yritä "huijata" kuljettamalla palloa kädessä maalia kohti: pisteitä ei saa tulla.
- Tarkista, että high score säilyy oikein myös silloin, kun seuraava heitto tuottaa vähemmän pisteitä.
