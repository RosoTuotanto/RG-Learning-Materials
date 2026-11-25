# Template Showcase Demo

A menu of 18 tiny playable samples, six for each Roso Games template (Visual Novel, Platformer and Top-down), each showing one kind of game that template could become. Participants who have seen the course games tend to assume their own game has to look like them, and these samples show how far apart games built on the same template can be.

Try it in the browser on the [learning materials site](https://rosotuotanto.github.io/RG-Learning-Materials/demos/template-showcase/).

The samples are not built with the templates. They do not use RG Core or any template code, and each one is a single small idea to borrow from, not a template to start from.

## The samples

Each sample is its own folder in `samples/`.

| Visual Novel | What it shows |
| --- | --- |
| `visual-novel-hidden-object` | Search the office for six clues, some partly hidden. |
| `visual-novel-life-sim` | Days of picking two actions each, with stat bars and relationships that the choices change. |
| `visual-novel-interrogation` | Press a suspect's statements and present the evidence that proves each one wrong. |
| `visual-novel-deduction` | A corkboard of suspects and clues: pin strings between them and accuse. |
| `visual-novel-city-map` | A day on the city map where travel and conversations cost time and places change with the time of day. |
| `visual-novel-endings` | A short case where a few choices lead to one of three endings. |

| Platformer | What it shows |
| --- | --- |
| `platformer-classic` | Run, jump, stomp enemies, collect coins and bump blocks on the way to the flag. |
| `platformer-shooter` | A gun aimed at the mouse against turrets that shoot back. |
| `platformer-story` | A village of characters to talk to. |
| `platformer-puzzle` | Push crates onto switches to hold doors open and carry the key to the exit. |
| `platformer-precision` | Spikes, wall jumps and a dash, with coyote time and jump buffering. |
| `platformer-abilities` | Connected rooms where a double jump and a dash, once found, open the way on. |

| Top-down | What it shows |
| --- | --- |
| `top-down-combat` | Shooting at the mouse cursor against waves of melee and ranged enemies. |
| `top-down-controls` | Free movement and tile-by-tile grid movement in the same room. |
| `top-down-stealth` | Guards on patrol with vision cones. |
| `top-down-farming` | Till, plant, water and harvest, and sleep to make the crops grow. |
| `top-down-racing` | A drifting car on a looped track with checkpoints and lap times. |
| `top-down-puzzle` | Push crates onto every plate to open the door. |

## Running it

Open the project folder in the Solar2D Simulator. There is nothing to install and no plugins are downloaded.

## Reading a sample

- Each sample folder is complete on its own, so files repeat between samples on purpose. Only the fonts in `assets/fonts/roboto/` are shared.
- Start at `demo.lua` in the sample's folder: it is the scene the menu opens, and it builds the sample and wires its input.
- Every tuning value, colour, key binding and on-screen string is in the sample's `data/settings.lua`.
- Search the folder for `Idea:` to find the spots where a real game would take the idea further.

## Levels and Tiled maps

- The platformer and top-down samples load their levels from Tiled maps with ponytiled. Open the `.tmx` in the sample's `assets/` in Tiled; the `.json` beside it is the export the sample loads.
- Export from Tiled as JSON with CSV layer data and embedded tilesets, which is the format ponytiled reads.
- Tile layers hold only the art. The hidden `physics` object layer holds the collision shapes, so when you add solid tiles, cover them on that layer too, or the player walks straight through.
- The hidden `game` object layer holds the typed objects, such as the player start, enemies and coins.

## Copying a sample into a game

Copy the sample's folder into your project, then replace the path prefix in two places:

- Every `require` starts with `samples.<name>.`, for example `require( "samples.top-down-combat.classes.enemy" )`. Change it to wherever the folder now sits.
- Every image and sound path starts with `samples/<name>/`, for example `"samples/top-down-combat/assets/images/hero.png"`. Change it the same way.

The font paths in `data/settings.lua` point at `assets/fonts/roboto/` at the project root, so either copy those fonts too or point the paths at your own.

## Sounds and tests

- The sounds are generated beeps: `python3 -B tools/generate_sfx.py` builds each sample's WAV files from its definition in `tools/sfx/<sample>.json`.
- `tools/tests/run_all.sh` runs the samples' tests under Lua 5.1 without the Simulator.

## Author

[© 2026 Eetu Rantanen](https://www.erantanen.com)
