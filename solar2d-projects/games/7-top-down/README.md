# Top-down-seikkailu

Kurssin 6 (Kentät, äänimaailma ja pelisuunnittelun haasteet) opetuspeli. Peli rakennetaan kurssin oppitunneilla vaihe vaiheelta, ja kukin `versio-N`-kansio sisältää pelin siinä tilassa, jossa se on tietyn oppitunnin lopussa. Pelin sisäinen kieli on englanti; koodin kommentit ovat suomeksi.

Pelaaja saapuu Saltfordin kylään, jonka vanhin pyytää selvittämään, miksi muukalainen on leiriytynyt rannalle. Rantatie aukeaa vasta tehtävän myötä. Muukalainen antaa viestin, jonka pelaaja vie vanhimmalle.

Kansiot `versio-0` ... `versio-15` ovat pelin kehitysvaiheet oppituntien etenemisen mukaisesti:

| Versio | Oppitunti |
|--------|-----------|
| 0 | Top-down-seikkailun esisuunnittelu ja pohjustaminen (pohjaprojekti) |
| 1 | Ensimmäisen kentän lataaminen |
| 2 | Lisätään pelaajahahmo seikkailuun |
| 3 | Hahmon liikkuminen top-down-pelissä |
| 4 | Kuvan lisääminen kylään |
| 5 | Törmäykset, vuorovaikutus ja NPC:t |
| 6 | Kameran lisääminen peliin |
| 7 | Kenttien välinen siirtymä |
| 8 | Weaver-integraatio |
| 9 | Tehtävät ja dialogin ehdot |
| 10 | Inventory ja esineiden poimiminen |
| 11 | Sisällön lukitseminen |
| 12 | Parannellaan loadsave-moduulia |
| 13 | Pelitilan tallentaminen ja lataaminen |
| 14 | Äänet seikkailussa |
| 15 | Pelin viimeistely (myös kurssin viimeisen oppitunnin valmis peli) |

Pelin kaikki grafiikka ja äänet ovat mukana jo `versio-0`-kansiossa, joten oppitunnit lisäävät peliin vain koodia sekä kartta- ja tarinamuutoksia. `extra-assets`-kansio sisältää pelin grafiikan ja äänien lähdemateriaalit ja niiden lisenssitiedot (katso `extra-assets/README.md`). `tools`-kansio sisältää skriptit, joilla tileset, kartat ja muut assetit tuotetaan, sekä pelin logiikkaa tarkistavat testiskriptit (katso `tools/README.md`).
