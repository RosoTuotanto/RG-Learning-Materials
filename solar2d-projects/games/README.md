# Opetuspelit

Tämä kansio sisältää Roso Games -kurssien opetuspelien lähdekoodit ja assetit. Jokaisella pelillä on oma kansionsa ja jokaisella kehitysvaiheella oma `versio-N`-alikansionsa, joka on kokonainen, Solar2D Simulatorissa ajettava projektikansio: `main.lua`, `config.lua`, `build.settings` ja assetit ovat suoraan version kansiossa. Vaiheet vastaavat kurssien oppituntien etenemistä, joten voit avata pelin juuri siinä tilassa, jossa se on tietyn oppitunnin lopussa. Kun oppitunti on jaettu useaan osaan, versio vastaa viimeisen osan lopputilannetta, ja sen sivu listaa kaikki osat. Lisäksi jokaisella pelillä on `versio-kotitehtavat`-kansio, jossa on kurssin ohjelmointikotitehtävien malliratkaisu toteutettuna pelin viimeisimmän version päälle.

Kurssien opetuspelit ja niiden kansiot:

- `2-nopeustesteri` - Nopeustesteri (kurssi 2: Pelinkehityksen alkeet)
- `3-fysiikkapallo` - Fysiikkapallo (kurssi 3: Pelisuunnittelu ja prototyypittäminen)
- `4-pokeri` - Pokeri (kurssi 4: Käyttäjäkokemus pelisuunnittelussa)
- `5-visual-novel` - Roso Noir -visual novel (kurssi 5: Narratiivi ja pelitaide)
- `6-platformer` - Platformer (kurssi 6: Kentät, äänimaailma ja pelisuunnittelun haasteet)
- `7-top-down` - Top-down-seikkailu (kurssi 6: Kentät, äänimaailma ja pelisuunnittelun haasteet)

Kunkin pelin oma `README.md` kertoo tarkemmin sen kehitysvaiheista. Kurssin 2 Nopeustesteri on rekonstruoitu kurssin oppituntien 046-051 sisällöstä, koska siitä ei ollut valmiita projektipaketteja.

Kansio `7-top-down` poikkeaa muista: sen 16 kehitysvaihetta ovat kansioissa `versio-0` ... `versio-15`, eikä sillä ole `versio-kotitehtavat`-kansiota. Peli on rakennettu suoraan tähän repositorioon kurssin 6 top-down-oppituntiketjua varten.

Top-down-seikkailun sisäinen kieli on englanti (dialogit, tarina, käyttöliittymä ja konsolitulosteet); koodin kommentit ja tämän repositorion ohjeet pysyvät suomeksi.

Top-down-seikkailun grafiikka on Kenneyn CC0-paketeista (kenney.nl): Roguelike/RPG-paketti ja Roguelike Characters -paketti. CC0 ei edellytä mainintaa, mutta Kenney mainitaan silti.

Pelien selaimessa pelattavat HTML5-buildit eivät ole tässä kansiossa vaan repositorion juuren `site/`-kansiossa, joka julkaistaan GitHub Pagesin kautta. Kukin versio saa oman sivunsa kansioon `site/games/<peli>/versio-N/` (ja `versio-kotitehtavat/`), ja itse build pudotetaan sen `app/`-alikansioon. Kunkin version sivu linkittää muutossivulle `site/games/<peli>/versio-N/muutokset/`, joka näyttää, mitä versiossa muuttui tämän kansion edelliseen versioon verrattuna: tiedostojen lisätyt ja poistetut rivit, siirretyt tiedostot sekä muuttuneiden kuvien ja äänien esikatselut. `versio-kotitehtavat`-kansiota verrataan pelin suurimpaan numeroituun versioon, ja `versio-0` on olemassa vain tässä kansiossa `versio-1`:n vertailukohtana eikä saa omaa sivua. Sivusto muutossivuineen generoidaan ja buildit viimeistellään ajamalla repositorion juuresta `python tools/build_website.py`.

## Site build tooling

`python tools/build_website.py` (run from the repo root) regenerates the viewer site under `site/`: the landing page, one page per game, one per version and `versio-kotitehtavat`, each demo page (demos live under `site/demos/`, e.g. `site/demos/feedback/`), and a `404.html`. It also writes a `muutokset/` changes page under each version and `versio-kotitehtavat` page, linked from that page, showing what changed against the previous version in `solar2d-projects/games/`: added and removed lines per file, moved files, and previews of changed images and audio. `versio-kotitehtavat` is compared with the game's highest numbered version, and `versio-0` exists only in `solar2d-projects/games/` as the base for `versio-1`, with no page of its own. Changes pages are `noindex` and left out of `sitemap.xml`, and the generator copies changed images and audio next to each changes page for the previews. Each version and demo page iframes its own `app/index.html`, so drop the matching Solar2D HTML5 build output into that page's `app/` subfolder before running. The same command patches every build in place and reports MISSING/PATCHED/ALREADY/FAILED per app. It exits 0 when the pages generate and no patch fails; a missing `app/` build is a warning, not a failure. `tools/html5_build_patcher.py` stays usable on its own for patching a single one-off build.
