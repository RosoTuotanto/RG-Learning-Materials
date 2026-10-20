# Pelisuunnittelu: Pelin vaikeustaso

[Tehtävässä](../../README.md) pohdittiin, miten Nopeustesterin lukittua vaikeustasoa voisi muuttaa niin, että peli tarjoaisi sopivan haasteen eri tasoisille pelaajille.

Tämä on avoin suunnittelutehtävä, joten yhtä oikeaa vastausta ei ole. Alla on esimerkkivastaus, johon voit verrata omia ideoitasi.

## Esimerkkivastaus

Pelin vaikeustasoa voi muokata monella eri tapaa, esimerkiksi:

- Peliin voi lisätä vaikeustasovalikon, josta kukin pelaaja voi valita juuri itselleen sopivan vaikeustason.
- Pelistä voisi tehdä vaikeamman nopeuttamalla nappuloiden arvontaa ajan kuluessa, esim. 500 ms, 450 ms, 400 ms ja niin edelleen.
- Peliin voisi lisätä useampia, erikokoisia nappuloita, jolloin pelaajan täytyy keskittyä enemmän.
- Peliin voisi lisätä kierroksia, joissa peli näyttää kaksi tai useamman nappulan, jotka tulee painaa seuraavaksi.
- Yksi vaihtoehto olisi mukautuva vaikeustaso: jos pelaaja onnistuu hyvin, niin peli nopeutuu kierrosten välissä, mutta jos pelaaja häviää liian nopeasti, niin peli hidastuu. Näin peli pysyy sopivan haastavana kaikille.

Vaikeustasoa voi lähestyä myös muuttamalla pelin ydintä. Pisteytyksen voisi kääntää toisin päin: pelin tarkoitus ei olisikaan enää painaa niin montaa nappulaa oikeassa järjestyksessä kuin mahdollista, vaan painaa esimerkiksi 10 tai 30 nappulaa oikeassa järjestyksessä niin nopeasti kuin mahdollista. Pisteytys vaihtuisi siis painalluksista aikaan: pelaajalle näytettäisiin pisteiden sijaan kulunut aika ja montako nappulaa kierroksella on vielä jäljellä. Näin jokainen pelaaja saisi pelata peliä täysin omassa rauhassa ja omalla tahdillaan, eli niin nopeasti tai niin hitaasti kuin haluaa.

## Mitä tehtävä opettaa

Yksinkertaisiltakin tuntuvat asiat, niinkin yksinkertaisissa peleissä kuin Nopeustesterissä, saattavat sisältää paljon erilaisia, toinen toistaan monimutkaisempia ja monipuolisempia ratkaisuja. Tämä liittyy local maxima ja global maxima -käsitteisiin pelimekaniikoiden ja balanssin optimoinnissa, joihin palataan kurssilla 3.
