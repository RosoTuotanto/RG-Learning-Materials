# Kurssin 5 kotitehtävät: Narratiivi ja pelitaide

Nämä kotitehtävät kuuluvat kurssiin [Narratiivi ja pelitaide](https://www.rosogames.fi/lms/5-narratiivi-ja-pelitaide/lessons/kotitehtavat-5/). Yleiset ohjeet kotitehtävien tekemiseen ja vastausten käyttöön ovat [kotitehtävien pääsivulla](../README.md). Tehtäväkohtaiset vastaukset löytyvät [`answers/`](answers/)-kansiosta.

Kurssin kotitehtävät käsittelevät seuraavia aihealueita:

1. Ohjelmointi
2. Pelisuunnittelu, sekä UI & UX
3. Pelitaide
4. Narratiivinen suunnittelu ja kirjoittaminen

## 1. Ohjelmointi

Tällä kertaa pelimme on koodillisesti paljon kevyempi kuin aiemmin kehittämämme pelit. Pelin suurin sisältö ja toiminnallisuus tulevat Composerin scenejen luonnista ja hallinnasta sekä Twinessä luodusta tarinasta ja dialogista.

Vastaukset: [`answers/1-ohjelmointi/`](answers/1-ohjelmointi/README.md)

### Ensiaskeleet: UI-elementtien siirtäminen omaan moduuliin

- Siirrä kaikki `scenes/game.lua`-tiedostossa luodut UI-elementit (background, characters, text) kokonaan `scripts/ui.lua`-moduulin sisään.
- Tämä tekee koodista selkeämpää ja helpommin ylläpidettävää.
- Testaa ja varmista, että peli toimii edelleen oikein muutosten jälkeen.

### Seikkailu: Overlay scene Twinen ja Composerin avulla

- Lisää peliin uusi passage Twinen avulla, joka käynnistää overlay scenen Solar2D:ssä.
  - Saat vapaasti päättää, mistä nykyisestä passagesta pelaaja siirtyy uuteen passageen.
  - Varmista, että uudesta passagesta voi myös palata edelliseen passageen.
- Lisää overlay sceneen kaksi visuaalista elementtiä:
  - Musta, osittain läpinäkyvä nelikulmio, joka peittää overlay scenen alapuolella olevan pelin. Käytä nelikulmion luonnissa `screen.lua`-moduulia.
  - Overlay scenen vasempaan yläreunaan teksti "Close". Käytä tekstin luontiin `ui.newTitle`-funktiota ja aseta se paikalleen käyttäen `screen.lua`-moduulia. Lisää tekstiin touch event, joka sulkee overlay scenen objektia painettaessa. Kun overlay scene sulkeutuu, niin peli jatkuu normaalisti taustalla.

### Haaste: Overlay scenen ja game scenen välinen kommunikointi

- Jatka Seikkailu-kohdassa tehdyn overlay scenen kehittämistä.
- Luo overlay scenen keskelle kaksi ympyrää: sininen ja keltainen.
- Kun pelaaja painaa ympyrää, niin:
  - overlay scenen tulee kertoa alapuolella olevalle game scenelle, kumpaa ympyrää pelaaja painoi
  - overlay scene sulkeutuu
  - game scenen tulee näyttää tekstillä, käyttäen samoja UI-funktioita kuin jos pelaajahahmo puhuisi, kumpaa ympyrää pelaaja painoi, esim. `text = "I pressed " .. ballColor`. Game scenen tulee myös yhä näyttää linkkiteksti, jonka kautta pelaaja voi navigoida edelliseen passageen.

## 2. Pelisuunnittelu, sekä UI & UX

Visual novelit ja kinetic novelit eivät ole tarkkaan ottaen pelejä, ellei niissä ole interaktiivisia pelimekaniikoita ja gameplay looppeja.

### Tehtävä 1: Roso Noir -pelin jatkokehitys

- Mieti, mikä on pelin toivottu pelaajakokemus?
- Suunnittele pelimekaniikoita ja gameplay looppeja, jotka tukisivat tätä kokemusta. Nämä pelimekaniikat ja gameplay loopit voivat olla mitä tahansa.
- Pohdi, miten Roso Noirista saataisiin enemmän peli, eikä vain "valitse oma seikkailusi" -tyypin kuvakirja.

Vastaus: [`answers/2-roso-noir-pelin-jatkokehitys/`](answers/2-roso-noir-pelin-jatkokehitys/README.md)

## 3. Pelitaide

Taide on katsojan silmässä. Vai onko?

### Tehtävä 1: Visuaalisesti vaikuttava peli

- Valitse jokin peli, joka teki sinuun vaikutuksen taiteellisella tyylillään.
- Kuvaile, mikä pelin visuaalisessa ilmaisussa erityisesti teki sinuun vaikutuksen. Oliko tämä vaikutus hyvä vai huono, vai sekä että?
- Halutessasi voit ottaa kuvakaappauksen tai lyhyen videon pelistä ja jakaa sen muiden osallistujien kanssa Discordissa.

Vastaus: [`answers/3-visuaalisesti-vaikuttava-peli/`](answers/3-visuaalisesti-vaikuttava-peli/README.md)

## 4. Narratiivinen suunnittelu ja kirjoittaminen

"It was the best of games, it was the worst of games."

### Tehtävä 1: Vaikuttava tarina

- Valitse tarinavetoinen peli, joka teki sinuun vaikutuksen puhtaasti tarinallaan.
- Kuvaile, mikä pelin narratiivissa erityisesti teki sinuun vaikutuksen. Oliko tämä vaikutus hyvä vai huono, vai sekä että?
- Halutessasi voit ottaa kuvakaappauksen tai lyhyen videon pelistä ja jakaa sen muiden osallistujien kanssa Discordissa.

Vastaus: [`answers/4-vaikuttava-tarina/`](answers/4-vaikuttava-tarina/README.md)

### Tehtävä 2: Teema ja agenda

- Valitse yksi tai useampi tarinavetoinen peli, jota olet pelannut.
- Pohdi, mitä teemoja tai agendoja niissä oli.
- Mieti, paransivatko vai heikensivätkö ne pelikokemustasi. Miten?

Vastaus: [`answers/5-teema-ja-agenda/`](answers/5-teema-ja-agenda/README.md)

### Tehtävä 3: Ludonarratiivi

- Valitse tarinavetoinen peli ja pohdi, miten siinä ilmenee ludonarratiivinen dissonanssi tai johdonmukaisuus.
- Mieti, miten nämä asiat vaikuttivat pelikokemukseesi.
- Pohdi, miten dissonanssi olisi voitu välttää.

Vastaus: [`answers/6-ludonarratiivi/`](answers/6-ludonarratiivi/README.md)

### Tehtävä 4: Florence

- Palaa kurssin oppitunnille [Case study: Florence](https://www.rosogames.fi/lms/5-narratiivi-ja-pelitaide/lessons/case-study-florence/).
- Vastaa siellä esitettyihin kysymyksiin.

Vastaus: [`answers/7-florence/`](answers/7-florence/README.md)
