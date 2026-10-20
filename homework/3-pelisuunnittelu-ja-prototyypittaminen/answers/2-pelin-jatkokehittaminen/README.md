# Pelisuunnittelu: Pelin jatkokehittäminen

[Tehtävässä](../../README.md) analysoitiin Fysiikkapallo-peliä: sen peruspilareita, pelimekaniikoita ja gameplay looppeja sekä niiden parantamista.

Tämä on avoin analyysitehtävä, joten yhtä oikeaa vastausta ei ole. Alla on esimerkkivastaus, johon voit verrata omaa analyysiasi.

## Peruspilarit

Nykyisestä versiosta voidaan tunnistaa useita erilaisia pilareita. Kolme erityisen keskeistä ovat:

- Fysiikkapohjainen vuorovaikutus: pelaaja liikuttaa palloa kosketuksella, ja fysiikkamoottori sekä äänet hoitavat liikkeen, törmäykset ja muun palautteen. Tämä luo pelin game feelin ja tekee siitä opettavaisen.
- Tavoitteellisuus ja haasteet: pelaajan päämäärä on saada pallo maaliin. Maali liikkuu ylös ja alas, mikä lisää haastetta, ja haasteellisuutta voidaan kasvattaa pistekertoimilla.
- Reiluus ja rajat (anticheat ja boundary): peli valvoo, ettei palloa voi vain kuljettaa suoraan maaliin. Tämä luo sääntöjä ja opettaa pelaajalle, että onnistuminen vaatii oikeanlaista toimintaa, ja minkälaista se on.

Saatoit tunnistaa myös muita pilareita, kuten progressio ja oppiminen, palkitsevuus ja motivaatio, vaihtelu ja yllätyksellisyys tai luovuus ja ongelmanratkonta. Mitkä tahansa pilarit tunnistetaan, jatkokehityksessä ne tulee pitää kirkkaana: kaikkien lisättävien pelimekaniikoiden ja kaiken hiontatyön tulee edistää niitä. Huomaa myös, että peruspilarit saattavat olla toisensa poissulkevia: peli ei esimerkiksi voi olla samalla "rentouttava" ja "pelottava".

## Pelimekaniikat

Pelissä on käytetty muun muassa seuraavia pelimekaniikoita:

- Drag & drop -ohjaus (pallon raahaaminen kosketuksella)
- Fysiikat (oikeastaan kaikki mitä pelissä tapahtuu: pallo lentää, kimpoilee, pysähtyy ja reagoi kentän kanssa)
- Maaliin osuminen (triggeri sensorilla)
- Liikkuva kohde (maali liikkuu transitionilla)
- Pyörivä este (obstacle pyörii jatkuvasti)
- Reunojen rajaus (boundary palauttaa pallon alkuun)
- Anticheat-varoitus (punainen overlay, jos pallo on liian pitkällä)
- Äänipalautteet (bounce, score, reset)
- Resetointi (välitön palautus alkuun törmäyksestä tai välilyönnillä)
- Kotitehtävien myötä myös pisteytys ja pistekertoimen kasvattaminen heittämällä pallo tasojen kautta maaliin

## Gameplay loopit

Pelissä on useita eri looppeja, esimerkiksi:

- Core gameplay loop: pelaaja tarttuu palloon, heittää tai raahaa sitä, pallo liikkuu fysiikoiden mukaan ja törmää esteisiin, ja lopulta pallo joko osuu maaliin tai palautuu alkuun, jolloin pelaaja tarttuu siihen uudestaan.
- Haastelooppi: maali liikkuu ja pelissä on esteitä ja tasoja, pelaaja yrittää tähdätä, käyttää oikean määrän voimaa ja ajoittaa heiton oikein, ja onnistuminen palkitaan äänellä ja visuaalisella palautteella, sekä kotitehtävien myötä pisteillä.
- Sääntölooppi (anticheat): pelaaja yrittää oikoa, peli varoittaa ja estää "laittoman pisteytyksen", ja pelaaja oppii toimimaan sääntöjen mukaan.

## Kehitysehdotuksia looppeihin

- Core gameplay loopin parantaminen: lisää vaihtelua esteisiin (liikkuvia, katoavia, kimmoisia pintoja), anna visuaalista palautetta törmäyksistä (esim. pieni välähdys tai partikkeliefekti, tai ehkäpä pallo voisi "tärähtää" osumasta), lisää pisteytysjärjestelmä ja pistekertoimia (kotitehtävä) sekä useita erilaisia kenttiä.
- Haasteloopin syventäminen: lisää useita maaleja eri paikkoihin, jolloin pelaaja valitsee reitin; tee aikahaasteita, joissa maali on avoinna vain hetken; lisää progressio, jossa jokainen kenttä tuo uuden esteen tai vaikeustason.
- Sääntöloopin kehittäminen: jatkuvien varoitusten sijaan voisi tulla rangaistus (esim. pistevähennys tai välitön reset). Toisaalta voisi lisätä positiivisen vahvistuksen: pelaajalla on alussa bonuspisteitä tulevalle heitolle, ja mitä pidempään pallo on laittomalla alueella, sitä vähemmän bonusta pelaaja saa.
