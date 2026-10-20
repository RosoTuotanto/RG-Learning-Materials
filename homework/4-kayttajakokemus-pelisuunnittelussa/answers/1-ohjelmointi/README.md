# Ohjelmointi: Pokerin panostus ja animaatiot

[Tehtävänannot](../../README.md) laajentavat Pokeri-peliä kolmella tasolla: Ensiaskeleet (panoksen säätäminen), Seikkailu (ilmoitus rahan loppumisesta) ja Haaste (korttien ja pakan animaatiot).

Mallivastausprojekti löytyy kansiosta [`solar2d-projects/games/4-pokeri/versio-kotitehtavat/`](../../../../solar2d-projects/games/4-pokeri/versio-kotitehtavat/), ja voit tarkistaa oman ratkaisusi myös alla olevilla listoilla.

## Tarkista omasta ratkaisustasi

Ensiaskeleet:

- Pelaaja voi korottaa ja laskea seuraavan kierroksen panosta, ja panoksella on ylä- ja alaraja.
- Uusi kierros käynnistyy vain, jos pelaajalla on varaa nykyiseen panokseen, ja panos vähennetään pelaajan rahoista kierroksen alussa.
- Voitot maksetaan panoksen mukaisella kertoimella.
- Voittotaulukon luvut päivittyvät automaattisesti panoksen muuttuessa.

Seikkailu:

- Ilmoitus näkyy, kun pelaaja yrittää pelata ilman riittävää rahaa.
- Ilmoituksen voi sulkea, ja sen ollessa auki pelin muita nappeja tai kortteja ei voi painaa.
- Panosta ei voi muuttaa kesken kierroksen.

Haaste:

- Kortin valinnalla ja valinnan poistamisella on animaatio.
- Korttipakalla on sekoitusanimaatio kierroksen alussa tai lopussa.
- Nappeja, kortteja yms. ei voi painaa kesken animaation.

## Testaa peliäsi

- Pelaa rahasi loppuun ja yritä jatkaa: ilmoituksen pitäisi ilmestyä, ja sen sulkemisen jälkeen pelin pitäisi toimia normaalisti.
- Yritä muuttaa panosta kesken kierroksen ja tarkista, ettei se onnistu.
- Naputa nappeja ja kortteja nopeasti kesken animaatioiden ja varmista, ettei peli mene rikkinäiseen tilaan.
- Tarkista, että voittotaulukko näyttää oikeat summat sekä pienimmällä että suurimmalla panoksella.
