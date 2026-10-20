# Ohjelmointi: Platformerin indikaattorit ja viholliset

[Tehtävänannot](../../README.md) laajentavat Platformer-peliä kolmella tasolla: Ensiaskeleet (kolikkoindikaattorit), Seikkailu (vihainen laatikko) ja Haaste (lepakko).

Mallivastausprojekti löytyy kansiosta [`solar2d-projects/games/6-platformer/versio-kotitehtavat/`](../../../../solar2d-projects/games/6-platformer/versio-kotitehtavat/), ja voit tarkistaa oman ratkaisusi myös alla olevilla listoilla.

## Tarkista omasta ratkaisustasi

Ensiaskeleet:

- `scenes/levelSelect.lua` näyttää kaikkien pelikierrosten aikana kerättyjen kolikoiden kokonaismäärän, ja tieto haetaan ensimmäisellä kerralla tiedostosta `userdata.json`.
- `scenes/game.lua` näyttää kentän kerätyt kolikot suhteessa kentän kokonaismäärään (esim. "0/3"), ja teksti päivittyy aina, kun pelaaja kerää kolikon.
- Molemmat indikaattorit koostuvat kolikon grafiikasta ja tekstistä.

Seikkailu:

- Laatikko putoaa nopeasti alas, kun pelaajahahmo on sen alapuolella tai riittävän lähellä.
- Laatikko pysähtyy ensimmäiseen fyysiseen tasoon tai kentän alareunaan.
- Laatikolla on animaatio ja ääniefekti: aluksi se hymyilee, mutta pudotessaan se irvistää ja päästää äänen.

Haaste:

- Lepakko aloittaa idle-tilassa ja siirtyy attack-tilaan valitsemillasi ehdoilla, ja tarvittaessa myös takaisin.
- Hyökkäyksen aikana peli soittaa tilallisen, suunnan kertovan ääniefektin.
- Lepakolla on jatkuvasti toistuva animaatio.

## Testaa peliäsi

- Kerää kentän kaikki kolikot ja tarkista, että molemmat indikaattorit päivittyvät oikein. Sulje peli ja avaa se uudelleen: kokonaismäärän pitäisi säilyä.
- Kävele laatikon ohi kaukaa ja läheltä: laatikon pitäisi pudota vain, kun olet riittävän lähellä.
- Houkuttele lepakko hyökkäämään ja pakene sitten kauas: tarkista, että tilanvaihdot toimivat ehtojesi mukaan eikä lepakko jää jumiin kumpaankaan tilaan.
- Kuuntele tilalliset äänet sekä vihollisen vasemmalta että oikealta puolelta.
