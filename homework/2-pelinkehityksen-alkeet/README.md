# Kurssin 2 kotitehtävät: Pelinkehityksen alkeet

Nämä kotitehtävät kuuluvat kurssiin [Pelinkehityksen alkeet](https://www.rosogames.fi/lms/2-pelinkehityksen-alkeet/lessons/kotitehtavat-2/). Yleiset ohjeet kotitehtävien tekemiseen ja vastausten käyttöön ovat [kotitehtävien pääsivulla](../README.md). Tehtäväkohtaiset vastaukset löytyvät [`answers/`](answers/)-kansiosta.

Oppituntien pienten harjoitusten vastaukset (eri asia kuin kotitehtävät) löytyvät [`exercises/`](exercises/README.md)-kansiosta.

Kurssin kotitehtävät käsittelevät seuraavia aihealueita:

1. Ohjelmointi
2. Pelisuunnittelu
3. UI & UX

## 1. Ohjelmointi

Ohjelmointitehtävät jatkavat kurssilla rakennettua Nopeustesteri-peliä. Jos olet käynyt läpi kaikki Lua-esimerkit ja harjoitukset sekä rakentanut Nopeustesterin, sinulla on jo hyvä pohja.

Vastaukset: [`answers/1-ohjelmointi/`](answers/1-ohjelmointi/README.md)

### Ensiaskeleet: Nopeustesterin koodin siistiminen

1. Jos et ole vielä asentanut Luacheck-lisäosaa Visual Studio Codeen, niin tee se nyt.
   - Asennusohjeet löydät kurssin 1 oppitunnista ["Visual Studio Code"](https://www.rosogames.fi/lms/1-tyokalut-ja-orientaatio/lessons/visual-studio-code/).
   - Lyhyen opastuksen löydät oppitunnista ["Ohjelmoinnin opetteleminen"](https://www.rosogames.fi/lms/2-pelinkehityksen-alkeet/lessons/ohjelmoinnin-opetteleminen/).
2. Korjaa kaikki Luacheckin näyttämät virheet ja varoitukset.
   - Koodissasi ei pitäisi olla virheitä, sillä silloin se kaatuisi heti pelin käynnistyessä.
   - Jos koodisi vastaa kurssin aikana kirjoitettua esimerkkikoodia, niin saatat nähdä varoituksen "shadowing upvalue 'button' on line 12". Varoitus saattaa olla vähän erilainen, jos koodissasi on eri määrä kommentteja tai tyhjiä rivejä kuin esimerkissä.
   - Varoitus johtuu siitä, että `createButton`-funktion sisällä oleva `local button` -muuttuja varjostaa ylempänä olevaa `button`-taulukkoa. Muuttujilla on siis sama nimi, ja Luacheck kertoo, että toisen muuttujan nimeä tulisi vaihtaa sekaannuksen välttämiseksi.
   - Nimeä `createButton`-funktion sisällä oleva muuttuja selkeämmäksi, esim. `local newButton`:ksi. Muista, että kun olet muuttanut muuttujan nimen, niin sinun tulee muuttaa kaikki vanhat viittaukset koodissasi käyttämään uutta nimeä.
3. Muuta `onTouch`-funktion nimi paremmin funktion toimintaa kuvaavaksi.
   - Funktio nimettiin alun perin, kun pelissä oli vain yksi asia, jota pelaaja pystyi painamaan.
   - Nyt kun pelissä on muitakin UI-elementtejä, pelkkä `onTouch` on hieman epämääräinen. Muuta funktion nimi paremmin sen toimintaa kuvailevaksi, esim. `onTouchButton` tai `onPressButton`.
   - Muista muuttaa kaikki vanhat viittaukset käyttämään uutta nimeä. Luacheck ja Solar2D:n virheraportit auttavat sinua tarvittaessa löytämään muutoksia vaativat paikat koodistasi.
4. `print( event.phase, event.target.id )` -rivi ei ole enää tarpeellinen. Poista tai kommentoi se, jotta konsoli pysyy siistinä.

### Seikkailu: Nopeustesterin pienet visuaaliset parannukset

1. Indikaattorin ulkoasua voisi parantaa lisäämällä siihen pienen animaation, jonka aikana indikaattori häviää näkyvistä.
   - Poista koodista `timerIndicator` ja käytä ajastimen sijaan [transition-kirjastoa](https://docs.coronalabs.com/guide/media/transitionLib/index.html) tehdäksesi `indicator`-objektista näkymätön 200 ms kuluessa.
   - Voit halutessasi käyttää transitionia, eli siirtymää, myös muuttaaksesi väliaikaisesti indikaattorin kokoa.
2. Pisteiden taakse voisi lisätä yksivärisen, mustan taustan, jotta tekstit erottuvat paremmin kaikkia taustavärejä vastaan.
   - Luo musta tausta `scoreText`- ja `highscoreText`-objektien taakse, jotta ne näkyvät selvemmin.
   - Ota huomioon, että tekstit laajenevat oikealle pelaajan pisteiden kasvaessa.

### Haaste: pelin ominaisuuksien laajentaminen

1. Laajenna peliä siten, että jokaiselle nappulalle voidaan erikseen määrittää muoto: pyöreä tai nelikulmainen.
   - Nappuloiden koon tulee olla muokattavissa: pyöreälle nappulalle `radius` ja nelikulmaiselle `width` sekä `height`. Huom! Muutettuasi nappuloiden kokoa voit joutua myös muuttamaan niiden sijainteja ruudulla.
   - Nämä arvot määritellään `buttonData`-taulukossa ja käsitellään `createButton`-funktiossa.
2. Vaihda indikaattorin väriä sen mukaan, minkä nappulan päällä indikaattori milloinkin on.
   - Värit tulee määrittää `buttonData`-taulukossa. Voit valita nappulakohtaiset indikaattorin värit vapaasti.

## 2. Pelisuunnittelu

Olemme suunnitelleet pelin ja käyneet läpi muutamia pelisuunnittelun peruskäsitteitä. Tulevissa kursseissa syvennymme tähän aiheeseen enemmän.

### Tehtävä 1: Pelin vaikeustaso

Pelin vaikeustaso on tällä hetkellä lukittu, koska se käyttää tasaista 500 ms nopeutta arvonnassa.

- Mieti, miten vaikeustasoa voisi muuttaa niin, että peli tarjoaisi sopivan haasteen eri tasoisille pelaajille.
- Voisiko peliin kehittää yhden vaikeustason, joka mukautuisi automaattisesti pelaajan taitojen mukaan? Miten se toimisi?

Vastaus: [`answers/2-pelin-vaikeustaso/`](answers/2-pelin-vaikeustaso/README.md)

### Tehtävä 2: Videopelit ilman tavoitetta

Monet pelit, kuten The Sims, Minecraft ja Microsoft Flight Simulator, eivät sisällä selkeää tavoitetta. Pelaaja voi itse päättää, mitä tekee.

- The Sims -kehittäjä Will Wright kutsui peliään "nukkekodiksi", jossa pelaaja luo itse omat tavoitteensa.
- Minecraftissa on teknisesti voittoehto (Ender Dragon), mutta suurin osa pelaajista ei välitä siitä.
- Flight Simulatorissa ei ole mitään pakollista tavoitetta, pelaaja voi vain lentää.

Näitä pelejä kutsutaan usein sandbox-peleiksi. Mutta ovatko ne oikeasti pelejä vai enemmänkin leluja?

Kirjoita ajatuksiasi ylös ja pohdi seuraavia kysymyksiä. Voit myös keskustella niistä muiden osallistujien kanssa Discordissa:

- Ovatko tavoitteettomat pelit pelejä?
- Mikä tekee jostain asiasta pelin ja mikä ei?
- Miksi Minecraftia tai The Simsiä "pelataan", mutta hiekkalaatikolla tai nukeilla "leikitään"?

Vastaus: [`answers/3-videopelit-ilman-tavoitetta/`](answers/3-videopelit-ilman-tavoitetta/README.md)

## 3. UI & UX

UI = käyttöliittymä (User Interface). UX = käyttäjäkokemus (User Experience). Näihin syvennymme myöhemmillä kursseilla.

### Tehtävä 1: Nopeustesterin UI ja UX

Nopeustesteri on vielä hyvin yksinkertainen peli.

- Miten sen käyttöliittymää voisi muuttaa, jotta pelaaminen olisi hauskempaa ja mukaansatempaavampaa?
- Et saa lisätä ulkopuolisia kuvia tai ääniä, mutta kaikki muut ratkaisut ovat sallittuja.

Vastaus: [`answers/4-nopeustesterin-ui-ja-ux/`](answers/4-nopeustesterin-ui-ja-ux/README.md)
