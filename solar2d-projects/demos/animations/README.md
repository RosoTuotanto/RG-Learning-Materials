# Animations Demo

One pixel-art character, animated two ways. On one side it is a sprite sheet played frame by frame, the way most 2D games animate; on the other it is a skeletal rig of ten separate parts that the runtime moves and rotates between keyframes. The character and the buttons are the same for both. Every sprite frame is drawn by hand, so the sprite side can do what a rigid rig cannot: squash and stretch, a smear and speed lines on take-off, dust on landing, a scarf that trails behind the body, and held drawings for timing. The rig only moves and rotates its parts, with the scarf painted onto the torso, but it plays smoother motion and varies it cheaply.

The button row at the bottom drives everything. The larger "change style" button on the left switches between the two methods, and the newly shown character starts the same animation. The three buttons beside it pick the animation: idle, walk or jump. The heading at the top names the method on screen, and a short description above the buttons sums up what that method costs and what it buys.

The two sides differ in one more way, and the demo makes it visible on purpose. The sprite sheet has exactly one sequence per button and loops it. The skeletal side has three variants of each animation: a variant plays once, the next one starts on the following frame, and the third wraps back to the first. The caption under the heading names the animation that is playing, and on the skeletal side it also shows the variant, for example "Playing: walk animation (variant 2/3)", changing on every switch. Every variant of an animation starts and ends in the same pose, so the chain plays as one continuous motion. A new variant on the skeletal side is a set of keyframes; on the sprite side it would be another row of hand-drawn frames, which is why games that want variety tend to reach for bones.

## Running it

Open the project folder in the Solar2D Simulator. There is nothing to install and no plugins are downloaded.

The controls live inside the canvas rather than around it, because the demo is meant to be embedded in a lesson page where the surrounding page is not ours.

## Art and data

All of the art is hand-drawn as text grids in `tools/art/`, one character per pixel. `tools/art/palette.json` maps each single-character key to a `#RRGGBB` or `#RRGGBBAA` colour, and `.` is transparent. Every sprite drawing is its own 64x72 grid in `tools/art/frames/<name>.txt`, and `tools/art/sheet.json` lists the drawings in sheet order together with the frame size, the 8-column layout and the feet row (68). Every skeletal part is a grid of any size in `tools/art/parts/<part>.txt`, with its pivot in `tools/art/parts.json`. The character faces right and its shoes end on row 67, so the feet rest on row 68.

Every material is a four-tone ramp lit from the upper right: the lowercase key is the base, its uppercase the shade, and a partner letter gives the light tone (lowercase) and the deep tone used for selective outlines (uppercase). `o` is the outline.

- Skin: `k` light, `s` base, `S` shade, `K` deep.
- Hair: `a` light, `h` base, `H` shade, `A` deep.
- Top: `l` light, `y` base, `Y` shade, `L` deep.
- Scarf: `v` light, `c` base, `C` shade, `V` deep.
- Trousers: `r` light, `t` base, `T` shade, `R` deep.
- Shoes: `e` light, `f` base, `F` shade, `E` deep.
- Belt: `b` base, `B` shade.
- Face: `i` eye, `w` eye glint and teeth, `m` mouth, `p` cheek.
- Effects: `x` speed line, `z` smear (semi-opaque), `d` light dust, `D` dark dust.

`tools/art/model/` holds reference elements for the animators in the same grid format: head expressions, hands, shoe angles and scarf tail shapes. The build does not read them.

`tools/build_character.py` reads the grids and assembles the 512x288 sprite sheet, the skeletal part images and the skeletal `manifest.json`, whose poses it computes over its own rig: the keyframes place each shoe with inverse kinematics, so a planted foot stays put while the hips move over it, and forward kinematics turns every pose into per-part transforms. It also writes the two images the animation lesson uses. A malformed grid, an unknown palette key or a missing file stops the build with the file and line named. `tools/check_assets.py` runs every grid through the same parser and checks the generated files against the grids and what the app expects, including that every idle and walk drawing and skeletal frame stands on the feet row, that no skeletal knee bends backward, and that the manifest matches a fresh build of the keyframes. Both are build-time tools, excluded from builds, and need Pillow, which the `game-web-dev` and `ai-data-dev` containers both have.

```sh
python3 -B tools/build_character.py
python3 -B tools/check_assets.py
```

The art is 64x72 pixels per frame, shown at 4x with nearest-neighbour filtering so the pixels stay sharp.

`--preview DIR` also writes 4x previews: for each sprite sequence a contact sheet with the ground line, an onion-skin sheet that shows the previous drawing faded under each drawing, and a GIF that plays the sequence with its real timing, plus contact sheets of the skeletal families and a sheet of the parts. `--preview-only` writes the previews and nothing else, leaving the assets and lesson images untouched, and `--only NAME` (repeatable) limits them to `idle`, `walk`, `jump`, `skeletal-idle`, `skeletal-walk`, `skeletal-jump` or `parts`. The sprite previews read the sequences from `data/animations.lua` through `lua5.1`.

```sh
python3 -B tools/build_character.py --preview-only --preview .scratch/preview --only walk
```

Every tuning value lives in `data/`: positions, sizes, colours and fonts in `data/layout.lua`, the sheet layout, sequences (each a `frames` list, where repeating a frame holds it longer), frame timings, scale and variant count in `data/animations.lua`, and every on-screen string in `data/strings.lua`.

## The skeletal package

The skeletal character is a SpriteLoop package: a `manifest.json` that lists the parts, their pivots and draw order, and every animation frame's per-part transforms, plus one PNG per part. [SpriteLoop](https://balkanramgames.itch.io/spriteloop), a free animation tool by Balkan Ram Games, exports this format, and spriteloop-solar2d plays it.

This demo was built without the SpriteLoop app. `tools/build_character.py` authors the package directly in the same `.spla` folder format, from a rig and keyframes of its own, so the runtime reads exactly what SpriteLoop would export. A package made in SpriteLoop drops into `assets/skeletal/` in its place, as long as it keeps the animation names the app plays.

The package is loaded as a plain folder, not as a `.spla` archive, so no zip plugin is needed.

Every animation in the manifest is written with `loop: false`, and the app decides looping per `play()` call. The runtime cannot turn a looping manifest animation into a one-shot one (its loop override is dropped when the override is `false`), and the variant chain depends on the "complete" event that only a one-shot animation fires.

## Third-party code

- spriteloop-solar2d by ponywolf, https://github.com/ponywolf/spriteloop-solar2d, vendored as `libs/spriteloop.lua` from commit `9c3039903b3e7432be7d9b44007522e053483fe3` (2026-08-27, module `_VERSION` 1.0.0) with one local patch, marked in the file: the `plugin.zip` lookup happens only when a `.spla` archive is loaded, so the folder-loading demo configures no plugin and the Simulator prints no "plugin.zip is not configured" warning.
- The upstream repository has no license file at that commit; the author has been asked to add the MIT license. Check that it has landed before this folder is published.
- `scripts/screen.lua` is from Spyric Games, under the MIT license, copied unchanged from the feedback demo.
- Roboto is under the SIL Open Font License; the license text is in `assets/fonts/roboto/OFL.txt`.

## Verifying in the container

The app runs under stock Lua 5.1 with the engine stubbed, which is how the state machine, the touch wiring and the variant chain are checked without the Simulator. `tools/verify_state.lua` tests `scripts/demoState.lua` on its own; `tools/verify_scene.lua` loads the real scene, the real vendored runtime and the real manifest through `tools/stubs/solar2d_stub.lua` and `tools/stubs/json.lua`, then presses the buttons, checks that taps outside them change nothing and drives frames until the variants switch. Each prints only failures and a final count.

```sh
luacheck --no-color .
lua5.1 tools/verify_state.lua
lua5.1 tools/verify_scene.lua
python3 -B tools/check_assets.py
```

What the stubs cannot show is the Simulator's look, the HTML5 build and touch on a phone; those are host-side checks.

## Building for the web

The demo is designed to be an HTML5 build embedded in a lesson page. One step is not optional: stock Solar2D HTML5 builds suspend the runtime when the window loses focus, not just when the tab is hidden. Untreated, clicking anywhere on the lesson page outside the demo freezes it, and a resize while suspended leaves a canvas that a touch cannot recover. Patch every build with `tools/html5_build_patcher.py` at the repository root before shipping it, and check the patched output rather than trusting the run, since the patcher reports a missed pattern as a warning and still exits successfully.

## Author

[© 2026 Eetu Rantanen](https://www.erantanen.com)
