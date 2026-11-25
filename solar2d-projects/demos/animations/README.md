# Animations Demo

One pixel-art character animated two ways, to show what each method gives and what it costs: a sprite sheet played frame by frame, and a skeletal rig whose parts the runtime moves and rotates between keyframes.

Try it in the browser on the [learning materials site](https://rosotuotanto.github.io/RG-Learning-Materials/demos/animations/).

Frame-by-frame gives the artist full control, because every frame is drawn by hand, and a later change means redrawing the animation. Skeletal animation takes much less time and effort, though it can still take a lot of both, and it extends with image swaps: a blink, a change of clothes, a bouquet to hold.

## Running it

Open the project folder in the Solar2D Simulator. There is nothing to install and no plugins are downloaded.

The sprite side loops one sequence per animation. The skeletal side plays three variants of each animation in turn, and its Customize panel changes the outfit.

## Changing the art

The art is drawn in Aseprite, and [developmentFiles/README.md](developmentFiles/README.md) gives the export steps. After an export, rebuild the skeletal package and check it:

```sh
python3 -B tools/build_character.py
python3 -B tools/check_assets.py
```

- Both scripts need Pillow and `lua5.1`.
- `build_character.py` writes `assets/skeletal/manifest.json` from the rig in `tools/character-rig.json` and the keyframes defined in the script. It also writes the two images the animation lesson uses.
- `check_assets.py` checks the exports, the rig, the manifest and the values in `data/` against each other.
- `build_character.py --preview DIR` also writes contact sheets and GIFs of the animations.

Every tuning value and on-screen string is in `data/`.

## How it works

- The skeletal character is a [SpriteLoop](https://balkanramgames.itch.io/spriteloop) package, played by spriteloop-solar2d in `libs/spriteloop.lua`.
- `build_character.py` writes the package in SpriteLoop's own folder format, so a package exported from SpriteLoop can replace it as long as it keeps the animation names.
- The state logic and the scene also run under plain Lua 5.1 with the engine stubbed: `lua5.1 tools/verify_state.lua` and `lua5.1 tools/verify_scene.lua`.

## Author

[© 2026 Eetu Rantanen](https://www.erantanen.com)
