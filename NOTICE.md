# Notices

The code in this repository was written for the Roso Games learning materials (the course games, demos, assignments, homework answers, the site generator and the tools), unless it is listed below. It is licensed under the MIT License in [LICENSE](LICENSE), Copyright (c) 2025-2026 Eetu Rantanen and Roso Games (Kukunori ry).

The parts listed below come from other projects and keep their own licence and copyright. Paths are relative to `solar2d-projects/` unless they start with `site/` or `tools/`.

## Eetu Rantanen's libraries

| Part | Where | Licence | Copyright |
| --- | --- | --- | --- |
| screen | `scripts/screen.lua` (`scripts/core/screen.lua` in two versions of `games/6-platformer`) in `games/5-visual-novel`, `games/6-platformer`, `games/7-top-down`, `demos/animations`, `demos/feedback` and `demos/template-showcase` | MIT | © 2020-2023 Spyric Games Ltd. |
| Spyric Story Weaver 0.10.1 | `scripts/spyricStoryWeaver.lua` in `games/5-visual-novel` and `games/7-top-down`, `libs/spyricStoryWeaver.lua` in seven `demos/template-showcase` samples | MIT | Eetu Rantanen |
| rng | `demos/feedback/scripts/rng.lua` | MIT | © 2026 Eetu Rantanen |
| JSON stubs | `demos/animations/tools/stubs/json.lua` and `demos/template-showcase/tools/harness/stub/json.lua` | MIT | © 2026 Eetu Rantanen |

## Third-party libraries

| Part | Where | Licence | Copyright |
| --- | --- | --- | --- |
| PonyTiled | `com/ponywolf/ponytiled.lua` in `games/6-platformer` and `games/7-top-down`, `libs/ponytiled.lua` in eleven `demos/template-showcase` samples | MIT, in `libs/ponytiled-LICENSE.txt` of those samples | © 2016-2025 Ponywolf, © 2022-2026 Eetu Rantanen |
| XML parser | `com/coronalabs/xml.lua` in `games/6-platformer` and `games/7-top-down` | distributed with PonyTiled; the file states no licence | not stated; the file is a modified version of Alexander Makeev's LuaXml |
| SpriteLoop runtime 1.0.0 | `com/ponywolf/spriteloop.lua` in `assignments/character-animation/start` and `finished`, `demos/animations/libs/spriteloop.lua` | MIT, in `com/ponywolf/LICENSE` of the assignment | © 2026 Michael Wilson (Ponywolf) |
| Solar2D engine modules | `demos/template-showcase/tools/harness/engine/` | MIT, in `LICENSE.md` there | © 2020-2021 Solar2D |

## Third-party art, fonts and audio

| Part | Where | Licence | Copyright |
| --- | --- | --- | --- |
| Kenney Pixel Platformer (1.2) | `assets/images/tiles/` and `characters/` in `games/6-platformer`, and six `demos/template-showcase` samples | CC0, in `assets/images/License.txt` | Kenney (www.kenney.nl) |
| Kenney Roguelike/RPG pack | `games/7-top-down/extra-assets/kenney_roguelike-rpg-pack/`, the tilesets built from it in `games/7-top-down`, and six `demos/template-showcase` samples | CC0, in `License.txt` beside the files | Kenney (www.kenney.nl) |
| Kenney Roguelike Characters (2.0) | `games/7-top-down/extra-assets/kenney_roguelike-characters/`, the character art built from it in `games/7-top-down`, and five `demos/template-showcase` samples | CC0, in `License.txt` or `License-characters.txt` beside the files | Kenney (www.kenney.nl) |
| Munro font | `assets/fonts/munro.ttf` in `games/6-platformer` and `games/7-top-down` | notice in `assets/fonts/COPYRIGHT.txt` | © 2007 Ten by Twenty, all rights reserved |
| Roboto font (Apache) | `games/5-visual-novel`, `assets/fonts/Roboto/` | Apache License 2.0, in `LICENSE.txt` there | not named in the licence file |
| Roboto font (OFL) | `assets/fonts/roboto/` in `demos/animations`, `demos/ball-prototype`, `demos/feedback` and `demos/template-showcase` | SIL Open Font License 1.1, in `OFL.txt` there | © 2011 The Roboto Project Authors |
| Archivo font | `site/assets/fonts/` and `tools/og-assets/` | SIL Open Font License 1.1, in `LICENSE-Archivo.txt` there | © 2020 The Archivo Project Authors |
| Inter font | `site/assets/fonts/` | SIL Open Font License 1.1, in `LICENSE-Inter.txt` there | © 2016 The Inter Project Authors |
