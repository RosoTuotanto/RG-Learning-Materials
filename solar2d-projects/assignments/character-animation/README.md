# Character Animation

The companion project for the Roso Games lesson "Hahmo juoksemaan", which follows the drawing lesson "Muutakin kuin pikselitaidetta". Participants take the side-view character from the drawing lesson, or their own drawings, and make it stand and run in Solar2D twice: once as a frame-by-frame sprite sheet and once as a skeletal animation built in [SpriteLoop](https://balkanramgames.itch.io/spriteloop) and played with [spriteloop-solar2d](https://github.com/ponywolf/spriteloop-solar2d).

## Folders

- `start/` is the project participants work in. It runs as it is: a box slides along the ground with the left and right arrow keys until the character code replaces it.
- `finished/` is the same project with both animations wired. It differs from `start/` only in `scripts/frameByFrame.lua`, `scripts/skeletal.lua` and the exported `assets/character.spla`.
- `parts/` holds the ten character parts SpriteLoop imports, numbered back to front. Every part is a 128x128 image with the part drawn in its assembled place, so all ten line up when they are given the same position.
- `character.spriteloop` is the finished SpriteLoop project: the canvas, pivots, parent links, and the `Idle` and `Run` animations the lesson builds.

## Running it

Open `start/` or `finished/` in the Solar2D Simulator and use the left and right arrow keys. `main.lua` picks the character module with one `require` line: `scripts.frameByFrame` or `scripts.skeletal`.

`main.lua` moves the character 12 content units per 70 ms, the distance the planted foot travels per frame in the run sheet, so the feet do not slide. The character's centre sits 61 units above the ground, where the feet of every 128x128 frame end.

The skeletal module loads the `.spla` with `forceReload = true`. spriteloop unpacks a `.spla` into the caches directory and otherwise reuses that copy on every later launch, so a re-exported file would not show up.

`build.settings` declares `plugin.zip` only because spriteloop looks the plugin up when it loads; without the declaration, the Simulator prints a warning.

`finished/assets/character.spla` is exported from `character.spriteloop` in SpriteLoop with Export type **SPLA package** and Scope **All animations**.

## License

- spriteloop-solar2d is under the MIT license, in `com/ponywolf/LICENSE` of both projects.
- The character art is the author's own, under CC0 1.0.

## Author

[© 2026 Eetu Rantanen](https://www.erantanen.com)
