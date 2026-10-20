# Ohjelmointi: Roso Noirin scenet ja overlayt

[Tehtävänannot](../../README.md) laajentavat Roso Noir -visual novelia kolmella tasolla: Ensiaskeleet (UI-elementtien siirtäminen omaan moduuliin), Seikkailu (overlay scene Twinen ja Composerin avulla) ja Haaste (overlay scenen ja game scenen välinen kommunikointi).

Mallivastausprojekti löytyy kansiosta [`solar2d-projects/games/5-visual-novel/versio-kotitehtavat/`](../../../../solar2d-projects/games/5-visual-novel/versio-kotitehtavat/), ja voit tarkistaa oman ratkaisusi myös alla olevilla listoilla.

## Tarkista omasta ratkaisustasi

Ensiaskeleet:

- Kaikki `scenes/game.lua`-tiedostossa luodut UI-elementit (background, characters, text) luodaan nyt `scripts/ui.lua`-moduulissa.
- Peli toimii muutosten jälkeen täsmälleen kuten ennenkin.

Seikkailu:

- Twinessä on uusi passage, joka käynnistää overlay scenen, ja siitä pääsee myös takaisin edelliseen passageen.
- Overlayn musta, osittain läpinäkyvä tausta luodaan `screen.lua`-moduulin avulla ja se peittää koko ruudun.
- "Close"-teksti on luotu `ui.newTitle`-funktiolla, se on sijoitettu `screen.lua`-moduulin avulla, ja sen painaminen sulkee overlayn, jolloin peli jatkuu normaalisti taustalla.

Haaste:

- Overlayn keskellä on sininen ja keltainen ympyrä.
- Ympyrän painaminen välittää tiedon game scenelle, sulkee overlayn, ja game scene näyttää valinnan samoilla UI-funktioilla kuin hahmojen puheen (esim. `text = "I pressed " .. ballColor`).
- Linkkiteksti edelliseen passageen navigointiin näkyy yhä.

## Testaa peliäsi

- Pelaa tarina läpi ja varmista, että kaikki vanhat passaget ja valinnat toimivat kuten ennen muutoksia.
- Avaa ja sulje overlay useita kertoja peräkkäin ja tarkista, ettei peli mene rikkinäiseen tilaan.
- Kokeile molempia ympyröitä ja tarkista, että game scene näyttää oikean värin joka kerralla.
