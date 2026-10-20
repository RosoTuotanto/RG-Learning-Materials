# Roso Games -oppimateriaalit

Tämä repositorio on osa Roso Games -projekteja. Se täydentää osoitteessa [www.rosogames.fi/opetus](https://www.rosogames.fi/opetus) olevaa oppimisympäristöä: täältä löydät kurssien kotitehtävät vastauksineen sekä opetuspelien lähdekoodit kehitysvaiheittain.

Sisältö on toistaiseksi vain suomeksi. Englanninkielinen laajennus on mahdollinen myöhemmin.

## Rakenne

- [`homework/`](homework/README.md) sisältää kurssien 2-6 kotitehtävät ja niiden vastaukset. Jokaisella kurssilla on oma kansionsa, jonka `README.md` listaa kurssin kaikki kotitehtävät, ja jonka `answers/`-kansiosta löytyvät tehtäväkohtaiset vastaukset ja pohdinnat. Kurssin 2 kansiossa on lisäksi `exercises/`, jossa ovat oppituntien pienten harjoitusten vastaukset.
- `solar2d-projects/` sisältää kaikki Solar2D-projektit. [`solar2d-projects/games/`](solar2d-projects/games/README.md) sisältää kurssien opetuspelien lähdekoodit ja assetit eri kehitysvaiheissa: yksi kansio per peli ja yksi `versio-N`-alikansio per vaihe, jonka sisällä on kokonainen, Solar2D Simulatorissa ajettava projektikansio. Lisäksi jokaisella pelillä on `versio-kotitehtavat`-kansio, jossa on kurssin ohjelmointikotitehtävien malliratkaisu. Kurssin 6 top-down-seikkailulla (`7-top-down`) ei ole `versio-kotitehtavat`-kansiota, ja sen yhteiset assetit ja tuotantoskriptit ovat pelin kansion `extra-assets/`- ja `tools/`-alikansioissa. `solar2d-projects/demos/` sisältää demojen lähdekoodit (tällä hetkellä `feedback` ja `animations`).
- `site/` sisältää selaimessa pelattavan katselusivuston, joka julkaistaan sellaisenaan GitHub Pagesin kautta. Kukin pelin versio (`site/games/<peli>/versio-N/` ja `site/games/<peli>/versio-kotitehtavat/`) sekä demo (`site/demos/<demo>/`) saa oman sivunsa; sivun vieressä on `page.json`-sisältötiedosto ja `app/`-alikansio, johon kyseistä sivua vastaava HTML5-build pudotetaan. Pelin versioiden sivuilla on lisäksi `muutokset/`-alisivu, joka näyttää, mitä versiossa muuttui edelliseen versioon verrattuna. Sivusto generoidaan ja buildit viimeistellään ajamalla repositorion juuresta `python tools/build_website.py`.
- `tools/` sisältää sivuston generaattorin, sen testit ja repositorion tarkistustyökalut (katso [`site/README.md`](site/README.md)).

## Kotitehtävät ja vastaukset

Kotitehtävät ovat vapaaehtoisia ja ne tehdään itsenäisesti omalla ajalla. Niitä ei käydä läpi viikkotapaamisissa, vaan vastaukset ovat täällä avoimesti itseopiskelua ja oman työn tarkistamista varten. Tee tehtävä ensin itse ja vertaa vasta sitten omaa ratkaisuasi vastaukseen: niin opit eniten.

Sisältö täydentyy vaiheittain. Puuttuva mallivastaus tai pelin kehitysvaihe ei ole virhe, vaan se lisätään myöhemmin.
