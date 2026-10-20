# Kurssin 3 kotitehtävät: Pelisuunnittelu ja prototyypittäminen

Nämä kotitehtävät kuuluvat kurssiin [Pelisuunnittelu ja prototyypittäminen](https://www.rosogames.fi/lms/3-pelisuunnittelu-ja-prototyypittaminen/lessons/kotitehtavat-3/). Yleiset ohjeet kotitehtävien tekemiseen ja vastausten käyttöön ovat [kotitehtävien pääsivulla](../README.md). Tehtäväkohtaiset vastaukset löytyvät [`answers/`](answers/)-kansiosta.

Kurssin kotitehtävät käsittelevät seuraavia aihealueita:

1. Ohjelmointi
2. Pelisuunnittelu
3. UI & UX

## 1. Ohjelmointi

Nykytilanne: Fysiikkapallo-pelistä puuttuu pisteytysmekanismi. Peli on jo nyt responsiivinen ja hauska, mutta pisteiden ansaitseminen tekisi siitä huomattavasti mielenkiintoisemman. Lisäksi high score -järjestelmä lisäisi pelin uudelleenpeluuarvoa ja vetovoimaa.

Vastaukset: [`answers/1-ohjelmointi/`](answers/1-ohjelmointi/README.md)

### Ensiaskeleet: pisteiden lisääminen

- Lisää peliin mekaniikka, jossa pelaaja saa yhden pisteen aina osuessaan maaliin sääntöjen mukaan (eli kun varoitusindikaattori ei ole näkyvissä).
- Luo yksinkertainen tekstiobjekti, joka näyttää pelaajan pisteet (score). Voit ottaa mallia Nopeustesterin score-tekstistä.
- Pisteiden tulee kasvaa yhdellä aina, kun pelaaja saa uuden pisteen.
- Tässä vaiheessa high score -toimintoa ei vielä tarvita.

### Seikkailu: pisteytyksen jatkokehittäminen

Jatka Ensiaskeleet-tehtävässä jo luotua järjestelmää.

- Kun pelaaja aloittaa uuden heiton, pisteet nollautuvat (0).
- Pelaaja saa yhden pisteen osuessaan maaliin sääntöjen mukaan, mutta piste kerrotaan pistekertoimella.
- Jos pelaaja osuu maaliin useasti saman heiton aikana, käsittele osumat erillisinä tapahtumina (älä laske niitä yhteen).

Pistekertoimet:

- Voit valita käyttämäsi kertoimet vapaasti. Esimerkiksi: heiton alussa kerroin = 1, jos pallo osuu floor-objektiin niin kerroin = 2, corner-objektiin kerroin = 3 ja obstacle-objektiin kerroin = 5.
- Käytä tässä tehtävässä aina vain viimeisimmän osuman kerrointa.

Huomioita:

- Älä laske kertoimia, jos pelaaja pitää vielä pallosta kiinni (tämä on jo huomioitu nykyisessä koodissa).
- Muokkaa score-tekstiä niin, että se näyttää nykyisen heiton pisteet ja kertoimen. Saat vapaasti päättää, miten näytät ne. Esimerkiksi: jos maaliin ei ole osuttu, pisteet = 0; jos pallo ei ole osunut tasoihin, kerroin = 1; heiton aikana score-teksti voisi olla `score = 0 * 1` tai vaikkapa `score = 0 (x1)`.
- Kun heitto päättyy, pisteet ja kerroin on hyvä jättää näkyviin, jotta pelaaja voi katsoa niitä rauhassa.

High score:

- Lisää yksinkertainen high score -mekaniikka, joka tallentaa pelaajan korkeimman yhdellä heitolla saavuttaman pistemäärän. Voit ottaa mallia Nopeustesteri-pelistä.
- Saat vapaasti päättää, muuttuuko high score heti kun pelaaja saa uuden ennätyksen vai vasta kun pelaaja aloittaa uuden kierroksen.

### Haaste: pelin ominaisuuksien laajentaminen

Jatka Seikkailu-tehtävässä jo luotua järjestelmää.

- Anna pisteitä maaliin osumisesta sen korkeuden perusteella. Esimerkiksi kun maali on ruudun alaosassa, osumasta saa 1 pisteen, ja kun maali on ruudun yläosassa, osumasta saa 5 pistettä. Saat vapaasti päättää, miten näytät tämän kertoimen pelaajalle.
- Voit laskea pisteet dynaamisesti haluamallasi tavalla, esimerkiksi kaavalla `points = 1 + (maximumPoints - 1) * heightMultiplier`.
- Jos pelaaja osuu maaliin useasti saman heiton aikana, niin laske kaikki pisteet yhteen.
- Jos pelaaja osuu useampaan tasoon, niin laske kertoimet yhteen ja käytä kertoimien summaa seuraavassa maaliin osumisessa.
- Huom! Tämä tehtävä on haastava. Jos se tuntuu liian vaikealta, niin pyydä rohkeasti apua tai katso mallivastausta.

## 2. Pelisuunnittelu

Käsittelimme kurssin aikana pelisuunnittelun peruspilareita, gameplay looppeja ja pelimekaniikoita.

### Tehtävä 1: Pelin jatkokehittäminen

- Analysoi Fysiikkapallo-peliä sellaisena kuin se on nyt.
- Huomaa, että emme määrittäneet peruspilareita tai gameplay looppeja etukäteen: ne syntyivät orgaanisesti kehityksen aikana.
- Mieti: mitkä voisivat olla pelin peruspilarit, ja miten ne tulisi huomioida pelin jatkokehityksessä?
- Listaa kaikki pelissä käytetyt pelimekaniikat.
- Tunnista, mitä gameplay looppeja ne muodostavat.
- Pohdi, miten näitä looppeja voisi parantaa.

Vastaus: [`answers/2-pelin-jatkokehittaminen/`](answers/2-pelin-jatkokehittaminen/README.md)

### Tehtävä 2: Prototyypin jatkaminen, local maxima ja global maxima

[Fysiikkapallo-pelin viimeisellä oppitunnilla käsiteltiin ideaa peliprototyypin jatkamisesta](https://www.rosogames.fi/lms/3-pelisuunnittelu-ja-prototyypittaminen/lessons/peliprototyypin-jatkaminen/).

- Avaa edellä mainittu oppitunti uuteen välilehteen.
- Mieti jokaisen kuvan kohdalla, ovatko ne enemmän local maxima vai global maxima -ajattelua? Miksi?
- Mitä mahdollisia ongelmia tai haasteita jokaisen version jatkokehityksestä voisi syntyä?
- Mitä uusia pelimekaniikoita ja gameplay looppeja eri versiot voisivat mahdollistaa?

Vastaus: [`answers/3-prototyypin-jatkaminen/`](answers/3-prototyypin-jatkaminen/README.md)

## 3. UI & UX

Fysiikkapallo-pelissä on jo joitakin grafiikoita ja ääniefektejä.

### Tehtävä 1: Pelin jatkokehittäminen

- Mieti, millainen olisi pelaajalle toivottu käyttäjäkokemus.
- Jos peliä jatkokehitetään, pohdi: miten käyttöliittymää voisi muuttaa ja miten äänimaailmaa voisi parantaa?
- Voit suunnitelmissasi lisätä peliin mitä tahansa grafiikoita, ääniä tai muita elementtejä.
- Halutessasi voit myös kokeilla lisätä näitä ominaisuuksia suoraan peliin (eli koodata).

Vastaus: [`answers/4-pelin-jatkokehittaminen-ui-ja-ux/`](answers/4-pelin-jatkokehittaminen-ui-ja-ux/README.md)
