# Kurssin 6 kotitehtävät: Kentät, äänimaailma ja pelisuunnittelun haasteet

Nämä kotitehtävät kuuluvat kurssiin [Kentät, äänimaailma ja pelisuunnittelun haasteet](https://www.rosogames.fi/lms/6-kentat-aanimaailma-ja-pelisuunnittelun-haasteet/lessons/kotitehtavat-6/). Yleiset ohjeet kotitehtävien tekemiseen ja vastausten käyttöön ovat [kotitehtävien pääsivulla](../README.md). Tehtäväkohtaiset vastaukset löytyvät [`answers/`](answers/)-kansiosta.

Huom! Kurssilla 6 on vain yhdet kotitehtävät. Ne koostuvat Platformerin jatkokehityksestä (ohjelmointi ja kenttäsuunnittelu) sekä yleisestä kenttä- ja äänisuunnittelusta. Kurssin toisella puoliskolla ei anneta erillisiä uusia kotitehtäviä, joten voit käyttää sen ajan näiden tehtävien huolelliseen suorittamiseen tai aikaisempien kurssien materiaalien kertaamiseen ja niiden kotitehtävien loppuun saattamiseen.

Kurssin kotitehtävät käsittelevät seuraavia aihealueita:

1. Ohjelmointi
2. Kenttäsuunnittelu
3. Äänisuunnittelu

## 1. Ohjelmointi

Vastaukset: [`answers/1-ohjelmointi/`](answers/1-ohjelmointi/README.md)

### Ensiaskeleet: Kolikkoindikaattorit peliin

Lisää peliin indikaattorit, jotka näyttävät pelaajan keräämät kolikot.

- `scenes/levelSelect.lua`:
  - Näyttää, montako kolikkoa pelaaja on kerännyt yhteensä eri pelikierrosten aikana.
  - Indikaattori koostuu kahdesta osasta: kolikon grafiikasta ja tekstistä, joka kertoo kolikoiden kokonaismäärän.
  - Voit sijoittaa indikaattorin haluamaasi paikkaan, esimerkiksi vasempaan tai oikeaan yläreunaan, tai otsikon alapuolelle keskelle ruutua.
  - Ensimmäisellä kerralla tieto haetaan tiedostosta `userdata.json`.
- `scenes/game.lua`:
  - Näyttää, montako kolikkoa kentässä on ja montako pelaaja on jo kerännyt.
  - Indikaattori koostuu kolikon grafiikasta ja tekstistä, joka näyttää kerätyt kolikot suhteessa kentän kokonaismäärään, esimerkiksi "0/3", jossa pelaaja on kerännyt 0 kolikkoa ja kentässä on yhteensä 3 kolikkoa.
  - Luontevin paikka indikaattorille on pelaajan HP-indikaattorin vieressä.
  - Muista päivittää teksti aina, kun pelaaja kerää uuden kolikon.

### Seikkailu: "Vihainen laatikko"

Kehitimme opetuspelissä yhdelle vihollistyypille tekoälyn. Voit ottaa siitä mallia. Lisää vihaiselle laatikolle toiminnallisuus, joka reagoi pelaajan liikkeisiin:

- Kun pelaajahahmo on laatikon alapuolella tai riittävän lähellä sitä, niin laatikko putoaa nopeasti alas.
- Laatikko pysähtyy, kun se osuu ensimmäiseen fyysiseen tasoon (tile) tai kentän alareunaan.
- Lisää laatikolle animaatio ja ääniefekti: aluksi laatikko hymyilee, mutta pudotessaan se irvistää ja päästää jonkin äänen.

### Haaste: "Lepakko"

Kehitimme opetuspelissä yhdelle vihollistyypille tekoälyn. Voit ottaa siitä mallia. Lisää lepakolle toiminnallisuus, jossa sillä on kaksi tilaa. Saat vapaasti päättää, miten lepakko toimii näissä tilanteissa:

- Idle-tila:
  - Lepakko odottaa, kun pelaaja on liian kaukana.
  - Voit päättää, miten lepakko liikkuu tässä tilassa. Pyöriikö se esim. paikallaan, vai metsästääkö se pelaajaa?
  - Lepakko aloittaa aina idle-tilassa. Saat päättää, millä ehdoilla lepakko palaa attack-tilasta idle-tilaan.
- Attack-tila:
  - Lepakko hyökkää pelaajan kimppuun.
  - Voit itse päättää, milloin lepakko vaihtaa idle-tilasta attack-tilaan ja takaisin.
  - Hyökkäyksen aikana pelin tulee soittaa tilallinen ja suunnan kertova ääniefekti. Voit käyttää valmista efektiä tai luoda uuden.

Lisää lepakolle animaatio, joka toistuu jatkuvasti.

## 2. Kenttäsuunnittelu

### Tehtävä 1: Uuden kentän suunnittelu, kehittäminen ja lisääminen Platformeriin

1. Aloita suunnittelemalla kenttä paperilla ja kynällä, tai digitaalisesti. Kiinnitä huomiota sommitteluun, rytmiin ja pelaajan reittiin: mistä pelaaja aloittaa, mitä reittejä pitkin hänen tulisi päätyä maaliin, ja onko kentässä haasteita ja palkintoja?
2. Toteuta suunnittelemasi kenttä Tiled-sovelluksessa ja lisää se peliin.
   - Tehtävässä ei tarvitse ohjelmoida, mutta voit kerrata kentän lisäämisen [Ladataan kenttä pelissä](https://www.rosogames.fi/lms/6-kentat-aanimaailma-ja-pelisuunnittelun-haasteet/lessons/ladataan-kentta-pelissa/) -oppitunnista.
   - Jos tarvitset apua koodipuolen tai muun toteutuksen suhteen, niin pyydä muilta osallistujilta apua.
3. Kun olet lisännyt kentän peliin, niin testaa kenttää ja varmista, että se on läpäistävissä.
4. Lopuksi voit:
   - Jakaa kenttäsi paperiprototyypin #kerro-mitä-teet -kanavalla.
   - Jakaa screenshotin kentästäsi Tiled-sovelluksesta #kerro-mitä-teet -kanavalla.
   - Jakaa koko kenttäsi muiden osallistujien kanssa, jotta he pääsevät koittamaan sitä. Saat vapaasti miettiä ja päättää, miten kenttä on helpointa jakaa muille.

Vastaus: [`answers/2-uuden-kentan-suunnittelu/`](answers/2-uuden-kentan-suunnittelu/README.md)

### Tehtävä 2: Platformerin onboarding-suunnittelu

Mieti kehittämäämme Platformer-peliä. Tee lyhyt suunnitelma siitä, miten pelaajalle opetetaan pelin perusmekaniikat kentän avulla ilman erillistä ohjetekstiä.

Vastaus: [`answers/3-platformerin-onboarding-suunnittelu/`](answers/3-platformerin-onboarding-suunnittelu/README.md)

### Tehtävä 3: Muiden pelien onboarding-suunnittelu

- Valitse jokin pelaamasi peli.
- Mieti, miten kyseisessä pelissä on toteutettu pelin onboarding: miten peli opettaa pelaajia pelaamaan sitä? Opettaako peli pelaajia riittävän hyvin? Onnistuuko peli siinä hyvin vai ei? Miten sitä voitaisiin parantaa?

Vastaus: [`answers/4-muiden-pelien-onboarding-suunnittelu/`](answers/4-muiden-pelien-onboarding-suunnittelu/README.md)

## 3. Äänisuunnittelu

### Tehtävä 1: Foley-äänet

- Luo vapaavalintaiset 1-5 Foley-ääntä.
  - Äänet voivat olla kehittämäämme Platformer-peliin, ja voit korvata niillä pelin nykyiset ääniefektit.
  - Voit myös halutessasi tehdä aivan mitä tahansa muita ääniefektejä, esim. valosapelin, jonkun loitsun, kävelyä, jne.
- Jaa luomasi äänet muiden osallistujien kanssa Discordissa ja kerro heille prosessistasi.

Vastaus: [`answers/5-foley-aanet/`](answers/5-foley-aanet/README.md)

### Tehtävä 2: Uusi tilallinen ääni Platformeriin

- Ohjelmointikotitehtävissä peliin lisätään "Vihainen laatikko" ja "Lepakko" -viholliset.
- Laadi näille hahmoille tilalliset ääniefektit, jotka kuuluvat joko oikealta tai vasemmalta, riippuen pelaajan ja vihollisen sijainneista.
- Saat vapaasti päättää, miten toteutat äänet ja miltä ne kuulostavat. Voit esimerkiksi äänittää kaikki ääniefektit Audacityllä.

Vastaus: [`answers/6-uusi-tilallinen-aani-platformeriin/`](answers/6-uusi-tilallinen-aani-platformeriin/README.md)

### Tehtävä 3: Ääniefektit muissa peleissä

- Valitse jokin pelaamasi peli. Koita valita peli, jossa on sekä hyviä että ei niin hyviä ääniefektejä.
- Mieti, minkälaisia ääniefektejä kyseisessä pelissä on käytetty: mikä tekee näistä äänistä hyviä tai ei niin hyviä? Miten niitä voitaisiin parantaa entisestään?
- Mitä pelille tapahtuisi ilman näitä ääniä? Saavutettavuus: voisiko peli toimia ilman niitä, ja miten ne voitaisiin korvata?

Vastaus: [`answers/7-aaniefektit-muissa-peleissa/`](answers/7-aaniefektit-muissa-peleissa/README.md)
