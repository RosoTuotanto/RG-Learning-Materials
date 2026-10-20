# Kurssin 4 kotitehtävät: Käyttäjäkokemus pelisuunnittelussa

Nämä kotitehtävät kuuluvat kurssiin [Käyttäjäkokemus pelisuunnittelussa](https://www.rosogames.fi/lms/4-kayttajakokemus-pelisuunnittelussa/lessons/kotitehtavat-4/). Yleiset ohjeet kotitehtävien tekemiseen ja vastausten käyttöön ovat [kotitehtävien pääsivulla](../README.md). Tehtäväkohtaiset vastaukset löytyvät [`answers/`](answers/)-kansiosta.

Kurssin kotitehtävät käsittelevät seuraavia aihealueita:

1. Ohjelmointi
2. Pelisuunnittelu
3. UI & UX
4. Pelaamisen psykologia

## 1. Ohjelmointi

Nykytilanne: Olemme rakentaneet Pokeri-peliin yksinkertaisen panostusmekaniikan, mutta pelaajalla ei ole vielä mahdollisuutta muuttaa panostaan.

Vastaukset: [`answers/1-ohjelmointi/`](answers/1-ohjelmointi/README.md)

### Ensiaskeleet: Panoksen säätäminen

- Lisää peliin toiminnallisuus, jonka avulla pelaaja voi korottaa tai laskea seuraavan pelikierroksen panosta.
- Toteutustapa on vapaa: esimerkiksi näppäimistön painallukset tai kaksi uutta UI-nappia.
- Määritä panokselle ylä- ja alaraja. Saat päättää itse, mitä ne ovat.
- Ennen kuin uusi kierros alkaa, tarkista onko pelaajalla riittävästi rahaa pelata nykyisellä panoksella. Jos pelaajalla ei ole varaa, niin mitään ei tapahdu. Jos pelaajalla on varaa, niin vähennä pelaajalta panoksen verran rahaa ja käynnistä uusi kierros.
- Jos pelaaja voittaa, maksa voitot panoksen mukaisella kertoimella.
- Tee voittotaulukosta dynaaminen: sen luvut muuttuvat automaattisesti panoksen muuttuessa.

### Seikkailu: Panoksen vaikutus voittotaulukkoon

- Lisää peliin jonkinlainen visuaalinen ilmoitus pelaajalle, jos hän yrittää pelata, mutta hänellä ei ole riittävästi rahaa.
  - Saat vapaasti päättää, miten toteutat ilmoituksen, esim. käyttämällä nelikulmioita ja tekstiä, natiivia varoitusikkunaa, jne.
  - Ilmoitus tulee pystyä sulkemaan, ettei se estä peliin palaamista.
  - Ilmoituksen tulee estää pelaajaa painamasta pelin muita nappeja tai kortteja.
- Huolehdi, että käyttöliittymä pysyy selkeänä ja helposti luettavana.
- Estä pelaajaa muuttamasta panosta kesken kierroksen. Saatoit toteuttaa tämän jo osana edellistä tehtävää. Jos et, niin tee se nyt.

### Haaste: Animaatiot ja käyttäjäkokemus

- Lisää peliin animaatio sille, kun pelaaja valitsee kädestään kortin tai poistaa valinnan.
  - Tällä hetkellä korttien valinta tapahtuu välittömästi.
  - Saat vapaasti päättää, miten käytät transition-kirjastoa animoidaksesi korttien valinnan ja valinnan poistamisen.
- Lisää korttipakalle sekoitusanimaatio joko uuden kierroksen alussa tai kierroksen lopussa. Saat vapaasti päättää, miltä sekoitus näyttää ja miten se tukee pelin tunnelmaa.
- Estä pelaajaa painamasta nappeja, kortteja, yms. kesken animaation.

## 2. Pelisuunnittelu

Kurssilla tutustuimme Liz Englandin kuuluisaan The Door Problem -esimerkkiin, joka osoittaa, miten yksinkertainenkin asia voi avata valtavan määrän suunnittelukysymyksiä.

### Tehtävä 1: Oman oviongelman tunnistaminen

- Valitse jokin pelaamasi peli.
- Etsi siitä yksinkertainen asia, joka aiheuttaa oviongelman kaltaisen suunnitteluhaasteen (älä kuitenkaan valitse ovea).
- Kirjoita lyhyt ajatteluketju: mitä kysymyksiä ja ongelmia tämän asian sisällyttäminen peliin aiheuttaa.
- Halutessasi voit ottaa kuvakaappauksen tai videon havainnollistamaan asiaa ja jakaa sen muiden osallistujien kanssa Discordissa.

Vastaus: [`answers/2-oman-oviongelman-tunnistaminen/`](answers/2-oman-oviongelman-tunnistaminen/README.md)

## 3. UI & UX

Kurssilla käsittelimme käyttöliittymän (UI) ja käyttäjäkokemuksen (UX) perusperiaatteita sekä niiden yhteispeliä.

### Tehtävä 1: UI-analyysi

- Valitse yksi tai useampi peli, jota olet pelannut.
- Ota pelistä kuvakaappaus tai lyhyt video, jossa näkyy sen käyttöliittymä.
- Analysoi: minkälaista käyttäjäkokemusta kehittäjät tavoittelivat? Miksi käyttöliittymä on suunniteltu juuri sellaiseksi kuin se on? Onko ratkaisuissa erityisiä onnistumisia tai ongelmia?
- Jos et keksi tai löydä sopivaa peliä, niin voit käyttää kurssin [Käytännön esimerkkejä](https://www.rosogames.fi/lms/4-kayttajakokemus-pelisuunnittelussa/lessons/kaytannon-esimerkkeja/) -oppitunnin kuvakaappauksia.
- Halutessasi voit jakaa oman esimerkkisi Discordissa, jotta muutkin pääsevät pohtimaan sitä.

Vastaus: [`answers/3-ui-analyysi/`](answers/3-ui-analyysi/README.md)

## 4. Pelaamisen psykologia

Kurssilla tutustuimme pelaamisen psykologisiin ulottuvuuksiin: motivaatioon, palkitsemiseen, rankaisemiseen ja reiluuden kokemukseen.

### Tehtävä 1: Psykologian soveltaminen peleissä

- Valitse yksi tai useampi peli, jota olet pelannut.
- Pohdi: miten peli hyödyntää kognitiivista psykologiaa? Miten siinä huomioidaan motivaatio, palkitseminen ja rankaiseminen? Tuntuuko peli reilulta? Miksi tai miksi ei?
- Jos pelissä ei ole näitä elementtejä, niin mieti, miten niiden lisääminen voisi parantaa pelikokemusta.
- Halutessasi voit ottaa kuvakaappauksen tai videon ja jakaa sen muiden osallistujien kanssa Discordissa.

Vastaus: [`answers/4-psykologian-soveltaminen-peleissa/`](answers/4-psykologian-soveltaminen-peleissa/README.md)

### Tehtävä 2: Pokerin reiluus ja kontrolloitu satunnaisuus

- Pohdi, missä tilanteissa pelistä voisi tulla hauskempi tai mielenkiintoisempi, jos satunnaisuutta kontrolloitaisiin.
- Mieti myös, mitä ongelmia voisi syntyä, jos satunnaisuutta säädellään liikaa.
- Älä ajattele asiaa uhkapelaamisen näkökulmasta, vaan keskity siihen, miten pelaajan pelikokemusta voisi parantaa.

Vastaus: [`answers/5-pokerin-reiluus-ja-kontrolloitu-satunnaisuus/`](answers/5-pokerin-reiluus-ja-kontrolloitu-satunnaisuus/README.md)
