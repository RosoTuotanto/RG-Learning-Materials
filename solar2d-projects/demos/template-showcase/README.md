# Template Showcase Demo

A menu of 18 tiny playable samples, six for each Roso Games template (Visual Novel, Platformer and Top-down), each showing one kind of game that template could become. Participants who have seen the course games tend to assume their own game has to look like them; these samples are there to show how far apart games built on the same template can be.

Try it in the browser on the [learning materials site](https://rosotuotanto.github.io/RG-Learning-Materials/demos/template-showcase/).

The samples are not built with the templates. They do not use RG Core or any template code, and each one is a single small idea rather than the start of a game. The disclaimer box at the bottom of the menu says so, and it stays there for good: a sample is an idea to borrow from, not a template to start from.

## The samples

A short loading screen shows between the menu and a sample. Every sample with sound has its own `Volume` slider in the top-right corner. Back to Menu in the top-left corner returns to the menu from any sample, and every visit starts the sample fresh.

### Visual Novel

All six open in the detective's office and run their story with Weaver. Click or Space advances the text, and choices are clicked.

| Folder | What it shows | Controls |
| --- | --- | --- |
| `visual-novel-hidden-object` | Search the office for six clues, some partly hidden; each find plays a short passage about it. | Click a clue. |
| `visual-novel-life-sim` | Days of picking two actions each; every dialogue choice shows what it will do to four stat bars and to the relationships, which the Relationships panel lists. | Click actions, choices and the Relationships button. |
| `visual-novel-interrogation` | A suspect's three statements, one at a time; press a statement for a pointer to the evidence that proves it wrong, then present that evidence until every statement is broken. | Click Press, Present and an item of evidence. |
| `visual-novel-deduction` | A corkboard of suspects and clues; pin strings between them and accuse. | Drag from a clue to a suspect, drag a string off to remove it, click Accuse. |
| `visual-novel-city-map` | A day on the city map from 9:00 to 21:00, where travel and every conversation cost time, places change with the time of day, and what the detective has learned by nine picks one of three endings. | Click a place on the map to travel there, or the current place to talk there. |
| `visual-novel-endings` | A short case with Jimmy and Vivian where a few choices lead to one of three endings, and an Endings screen that remembers which ones you have found. | Click or Space, click a choice. |

### Platformer

| Folder | What it shows | Controls |
| --- | --- | --- |
| `platformer-classic` | Run, jump, stomp enemies, collect coins and bump blocks on the way to the flag. | A/D or arrows to run, Space to jump. |
| `platformer-shooter` | A gun aimed at the mouse against turrets that shoot back. | A/D or arrows to move, Space to jump, mouse to aim, click to shoot. |
| `platformer-story` | A village of characters to talk to; one conversation changes what happens further on. | A/D or arrows to move, Space to jump, E or Up to talk, Up/Down and Enter or click for choices. |
| `platformer-puzzle` | Push crates onto ramped switches to hold doors open and carry the key to the exit, over two rooms. | A/D or arrows to move, Space to jump, R to restart. |
| `platformer-precision` | Spikes, wall jumps and a dash, with coyote time and jump buffering, on the way to the end flag. | Arrows or WASD to move and aim, Space to jump, Shift or X to dash. |
| `platformer-abilities` | Connected rooms where a double jump and a dash, once found, open the way on; crossing the chasm takes both. | A/D or arrows to move, Space to jump, Shift or X to dash once found. |

### Top-down

| Folder | What it shows | Controls |
| --- | --- | --- |
| `top-down-combat` | Shooting at the mouse cursor against waves of melee and ranged enemies. | WASD or arrows to move, mouse to aim, click to shoot. |
| `top-down-controls` | Free movement and tile-by-tile grid movement in the same room. | WASD or arrows to move, Tab or the on-screen toggle to switch. |
| `top-down-stealth` | Guards on patrol with vision cones; reach the door unseen. | WASD or arrows to move. |
| `top-down-farming` | Till, plant, water and harvest, and sleep to make the crops grow. | WASD or arrows to move, 1-4 or click to pick a tool, Space to use it. |
| `top-down-racing` | A drifting car on a wide looped track with checkpoints and lap times; a finished lap plays a tune and lights its time. | Up/W to drive, Down/S to brake, Left/A and Right/D to steer, Space to drift. |
| `top-down-puzzle` | Push crates onto every plate to open the door, over three rooms. | WASD or arrows to move, Z to undo, R to restart. |

## Why files repeat across samples

Each sample folder is complete on its own: its scene, its classes, its settings, its images, its sounds and any library it needs. Samples of the same template share a base (input, the ponytiled map loader, player or story player), and every one of them carries its own copy. That duplication is deliberate, so everything one idea needs is in one place and a folder can be read or copied without following references elsewhere in the project. The only shared files are the fonts in `assets/fonts/roboto/`.

## Reading a sample

- Start at `demo.lua` in the sample's folder: it is the scene the menu opens, and it builds the sample and wires its input.
- Every tuning value, colour, key binding and on-screen string is in the sample's `data/settings.lua`.
- Search the folder for `Idea:` to find the spots where a real game would take the idea further, such as adding enemy types, giving guards hearing or saving progress.

## Levels and Tiled maps

- The platformer and top-down samples load their levels from Tiled maps through ponytiled, which each of them carries as `libs/ponytiled.lua`.
- Each map's `.tmx` in the sample's `assets/` is the file to open and edit in Tiled, and the `.json` beside it is the export the sample loads.
- Export from Tiled as JSON with CSV layer data and embedded tilesets, which is the format ponytiled reads. The maps are saved with Tiled 1.11.
- `demo.lua` decodes the `.json`, passes it to `ponytiled.new`, and finds where things start with `map:findObject` and `map:findObjects`.
- Tile layers hold the art. The platformer samples draw from `tilemap.png` and each top-down sample from one packed `tileset.png`.
- The hidden `physics` object layer holds the collision shapes, and each one becomes a static body when the map loads. Tiles alone are only art: when you add solid tiles, cover them on this layer too, or the player walks straight through.
- In the platformer maps each separate solid area is one shape: a rect when the area is a rectangle, otherwise one polygon along its outline, which ponytiled builds as a chain, so the player slides down a wall instead of catching where two stacked shapes meet. A hole inside an area gets its own polygon along the hole's edge.
- In the top-down maps the walls are rects.
- The hidden `game` object layer holds typed objects such as the player start, enemies, coins, checkpoints, guards' patrol paths and field plots.
- platformer-puzzle has one map per room, `room1` and `room2`.
- top-down-puzzle keeps its boards as text rows in `data/rooms.lua`, because its puzzle rules read them as a grid.

## Copying a sample into a game

Copy the sample's folder into your project, then replace the path prefix in two places:

- Every `require` starts with `samples.<name>.` (for example `require( "samples.top-down-combat.classes.enemy" )`); change it to wherever the folder now sits.
- Every image and sound path starts with `samples/<name>/` (for example `"samples/top-down-combat/assets/images/hero.png"`); change it the same way.

The font paths in `data/settings.lua` point at `assets/fonts/roboto/` at the project root, so either copy those fonts too or point the paths at your own.

## Running it

Open the project folder in the Solar2D Simulator. There is nothing to install and no plugins are downloaded.

In a browser, click the game once before using the keyboard, so the page sends its key presses to the game.

## Generated sounds

The sounds are simple beeps generated by code, so the project carries no recorded or downloaded audio. Each sample with sound has a definition file in `tools/sfx/<sample>.json`, and `tools/generate_sfx.py` turns it into the WAV files in that sample's `assets/audio/`. The script's docstring describes the definition format. It needs only Python 3, and a rerun writes identical files. Run it from the project folder:

```sh
python3 -B tools/generate_sfx.py
python3 -B tools/generate_sfx.py --sample top-down-combat
```

## Tests and linting

The samples' headless tests run under Lua 5.1 with `tools/tests/run_all.sh` from the demo root. Run `luacheck .` from the demo root too.

## Building for the web

The demo is designed to be an HTML5 build embedded in a lesson page. One step is not optional: stock Solar2D HTML5 builds suspend the runtime when the window loses focus, not just when the tab is hidden. Untreated, clicking anywhere on the lesson page outside the demo freezes it, and a resize while suspended leaves a canvas that a touch cannot recover. Patch every build with `tools/html5_build_patcher.py` at the repository root before shipping it, and check the patched output rather than trusting the run, since the patcher reports a missed pattern as a warning and still exits successfully.

## License

- The Kenney art in the platformer and top-down samples is CC0, with its licence file in each sample's `assets/images/`.
- Roboto is under the SIL Open Font License, in `assets/fonts/roboto/OFL.txt`.
- ponytiled is under the MIT license, in `libs/ponytiled-LICENSE.txt` of each sample that uses it.
- Weaver (`libs/spyricStoryWeaver.lua`) is under the MIT license, stated in its header.
- `scripts/screen.lua` is from Spyric Games, under the MIT license.
- The Solar2D modules in `tools/harness/engine/` are under the MIT license, in its `LICENSE.md`.
- The Roso Noir art and every other image not from Kenney are the author's own.

## Author

[© 2026 Eetu Rantanen](https://www.erantanen.com)
