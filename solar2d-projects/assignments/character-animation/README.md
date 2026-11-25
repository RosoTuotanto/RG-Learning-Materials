# Character Animation

The companion project for the Roso Games lesson "Hahmo juoksemaan", which follows the drawing lesson "Muutakin kuin pikselitaidetta". Participants take the side-view character from the drawing lesson, or their own drawings, and make it stand and run in Solar2D twice: once as a frame-by-frame sprite sheet and once as a skeletal animation built in [SpriteLoop](https://balkanramgames.itch.io/spriteloop) and played with [spriteloop-solar2d](https://github.com/ponywolf/spriteloop-solar2d).

## Folders

- `start/` is the project participants work in. It runs as it is: a box slides along the ground with the left and right arrow keys until the character code replaces it.
- `finished/` is the same project with both animations wired.
- `parts/` holds the character parts SpriteLoop imports, numbered back to front. Every part is drawn in its assembled place on the same canvas, so all of them line up when they are given the same position.
- `character.spriteloop` is the finished SpriteLoop project.

## Running it

Open `start/` or `finished/` in the Solar2D Simulator and use the left and right arrow keys. `main.lua` picks the character module with one `require` line: `scripts.frameByFrame` or `scripts.skeletal`.

`finished/assets/character.spla` is exported from `character.spriteloop` in SpriteLoop with Export type **SPLA package** and Scope **All animations**.

## Author

[© 2026 Eetu Rantanen](https://www.erantanen.com)
