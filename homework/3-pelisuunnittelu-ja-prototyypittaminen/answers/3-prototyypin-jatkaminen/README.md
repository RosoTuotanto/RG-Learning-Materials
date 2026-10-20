# Pelisuunnittelu: Prototyypin jatkaminen, local maxima ja global maxima

[Tehtävässä](../../README.md) arvioitiin [Peliprototyypin jatkaminen](https://www.rosogames.fi/lms/3-pelisuunnittelu-ja-prototyypittaminen/lessons/peliprototyypin-jatkaminen/) -oppitunnin kolmea versiota Fysiikkapallon jatkokehityksestä: kummasta ajattelutavasta on kyse, mitä ongelmia versiosta voisi syntyä ja mitä uutta se mahdollistaisi.

Tässäkään tehtävässä ei ole yhtä oikeaa vastausta, ja sinulla voi olla myös omia ideoita pelin jatkokehityksestä. Alla on esimerkkivastaus jokaisesta versiosta. Tiivistelmä:

| Versio | Ajattelutapa | Haasteet | Uudet loopit |
| --- | --- | --- | --- |
| 1. Pallo + alustat (nykyversio) | Local maxima | Kenttäsuunnittelu, selkeys | Suunnittele, kokeile, säädä |
| 2. Linko + rata (Angry Birds -tyyli) | Local ja global maxima | Ennustettavuus, yksinkertaisuus | Lataa, tähtää, ammu |
| 3. Platformer-hahmo | Global maxima | Identiteetin muutos, ohjaushaasteet | Liiku, hyppää, kerää |

## Versio 1: Pallo + alustat (nykyversio)

Local vai global maxima?

- Tämä on se sama versio, mihin jätimme pelin kehityksen, eli se on enemmän local maxima kuin global.

Mahdolliset ongelmat:

- Kenttäsuunnittelu: jos alustoja on liikaa tai ne ovat liian monimutkaisia, pelaaja voi turhautua. Etenkin, jos kenttien erot koostuvat vain esteiden määristä ja niiden sijainneista.
- Toistettavuus: jos ratkaisu on aina sama ja pelissä ei ole muuta päämäärää kuin pisteytys, uudelleenpeluuarvo jää pieneksi.

Uudet pelimekaniikat ja loopit:

- Reittisuunnittelu: pelaajan täytyy miettiä, mistä kulmasta ja millä voimalla pallo lähtee liikkeelle, jotta se kimpoaa oikeille alustoille.
- Useita ratkaisuja: kenttä voi sallia eri tapoja päästä maaliin, mikä lisää luovuutta.
- Uusi gameplay looppi voisi olla: suunnittele, kokeile, tarkkaile kimpoamisia, säädä, onnistu.

## Versio 2: Linko + rata (Angry Birds -tyyli)

Local vai global maxima?

- Tässä voi puhua sekä local maxima että global maxima -ajattelusta, riippuen mihin muutoksissa panostetaan.
- Versio rakentuu suoraan nykyisen fysiikkapallon perusidealle (pallo, fysiikka, maali), mutta lisää uuden ohjaustavan (linko ja heittorata). Se saattaa muuttaa pelin ydintä (global) tai vain syventää sitä (local).

Mahdolliset ongelmat:

- Trajektorien laskenta voi tehdä pelistä liian ennustettavan, jolloin pelaaja ei enää opi fysiikan kautta vaan seuraa "valmista viivaa".
- Toistettavuus voi kärsiä, jos haaste ei kasva monipuolisesti.

Uudet pelimekaniikat ja loopit:

- Ajoitus ja voiman säätely: kuinka paljon linkoa venyttää.
- Tarkkuushaaste: tähtäys eri kulmiin ja voimakkuuksiin.
- Progressio: esteitä, liikkuvia maaleja, useita tähtiä kerättäväksi yhdellä laukauksella.
- Looppi: lataa, tähtää, ammu, tarkista tulos, yritä uudelleen.

## Versio 3: Platformer-hahmo

Tässä voi myös kysyä: tulitko edes ajatelleeksi, että tämä muutos voisi tehdä Fysiikkapallosta platformerin (tasohyppelypelin)?

Local vai global maxima?

- Pelin perusajatus muuttuu: kyse ei ole enää pelkästään pallon heitosta, vaan sen liikkumisesta ja kenttäsuunnittelusta. Tämä on enemmän global maxima -ajattelua.

Mahdolliset ongelmat:

- Suunta muuttuu niin paljon, että alkuperäinen Fysiikkapallo-identiteetti voi hämärtyä tai hävitä kokonaan.
- Tarvitaan uusia ohjausmekanismeja (hyppy, liike, törmäykset).
- Kenttäsuunnittelu voi olla työlästä, jos halutaan monipuolisia kenttiä.

Uudet pelimekaniikat ja loopit:

- Platformer: pelaaja liikkuu, hyppii ja väistää esteitä.
- Keräily: tähti voisi toimia maalina tai kerättävänä tavoitteena.
- Esteiden hallinta: liikkuvat alustat, painovoiman vaihtelut, liukuvat pinnat.
- Looppi: liiku, hyppää, vältä esteet, kerää tähti, etene seuraavaan kenttään.
