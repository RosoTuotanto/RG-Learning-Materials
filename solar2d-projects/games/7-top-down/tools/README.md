# Tuotantoskriptit

Näillä skripteillä on tuotettu top-down-seikkailun tileset, image sheetit, kartat ja vuorovaikutuksen ääniefekti, ja niillä tarkistetaan pelin kartat ja logiikka. Pelin pelaamiseen tai oppituntien seuraamiseen et tarvitse niitä.

Kuvia käsittelevät Python-skriptit tarvitsevat Pillow'n ja Lua-testit `lua5.1`:n. Aja kaikki skriptit tästä kansiosta.

## Assetit ja kartat

| Skripti | Mitä se tekee |
| --- | --- |
| `build_assets.py` | Kokoaa Kenneyn paketeista tilesetin sekä hahmojen ja esineiden image sheetit kansioon `../extra-assets/`. `--check` ajaa pelkän tarkistuksen. |
| `tile_palette.py` | Tilesetin tilejen valinta ja nimet. `build_assets.py` ja `build_maps.py` lukevat sen. |
| `generate_interact_sfx.py` | Tuottaa ääniefektin `../extra-assets/audio/interact.wav`. |
| `build_maps.py` | Tuottaa pelin kolme karttaa version `maps/`-kansioon ja kopioi karttojen kuvat niiden viereen. |
| `render_maps.py` | Piirtää kartoista PNG-esikatselut. |
| `validate_maps.py` | Tarkistaa karttojen rakenteen ja karttojen väliset viittaukset. |

`build_maps.py --all` kirjoittaa jokaisen version kartat uudelleen, joten Tiledissä käsin tehdyt muutokset katoavat.

```
python3 -B build_assets.py
python3 -B build_maps.py --version 4 --out DIR
python3 -B build_maps.py --all
python3 -B render_maps.py ../versio-4/maps DIR
python3 -B validate_maps.py ../versio-4/maps
```

## Testit

Lua-testit ajavat pelin omaa koodia ilman Solar2D Simulatoria. Ensimmäinen argumentti on version kansio. `verify_story.lua`, `verify_inventory.lua` ja `verify_interact.lua` ottavat toisena argumenttina versionumeron.

| Testi | Mitä se tarkistaa | Versiot |
| --- | --- | --- |
| `verify_story.lua` | Dialogit, tehtäväketjun ja tarinan tallennuksen | 8-15 |
| `verify_exit.lua` | Karttojen väliset siirtymät ja lukitun portin | 7-15 |
| `verify_camera.lua` | Kameran sijainnin pyöristyksen kokonaisiin pikseleihin | kaikki |
| `verify_loadsave.lua` | Tallennuksen ja latauksen | 12-15 |
| `verify_inventory.lua` | Esinepaikat ja esineiden poimimisen | 10-15 |
| `verify_zone.lua` | Viestitriggerit | 15 |
| `verify_interact.lua` | Interact-näppäimen kohteen valinnan | 5-15 |

```
lua5.1 verify_story.lua ../versio-9 9
lua5.1 verify_inventory.lua ../versio-10 10
lua5.1 verify_camera.lua
```

Ilman argumentteja testit tarkistavat version 15. `verify_story.lua` tarvitsee aina molemmat argumentit.

## Tarinan muokkaaminen

Weaver erottelee `(either: ...)`-komennon vaihtoehdot pilkuilla, joten yksikään vaihtoehto ei saa sisältää pilkkua. `verify_story.lua` tarkistaa tämän, kun versionumero on 15.
