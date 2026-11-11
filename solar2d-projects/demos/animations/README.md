# Animations Demo

One pixel-art character, animated two ways, to show what each method gives and what it costs. On one side it is a sprite sheet played frame by frame, the way most 2D games animate; on the other it is a skeletal rig of 20 separate parts that the runtime moves and rotates between keyframes, plus a bouquet it can hold. The character and the style and animation buttons are the same for both.

Try it in the browser on the [learning materials site](https://rosotuotanto.github.io/RG-Learning-Materials/demos/animations/).

Frame-by-frame gives the artist full control, because every frame is drawn by hand. The sprite side shows what that buys: squash and stretch, a smear frame with speed lines, dust bursts, a glance toward the viewer that a rigid head cannot make, a scarf that ripples and folds differently in every drawing, and holds timed by hand. It also shows the price: drawing it well takes time, skill and effort, and a later change, such as a faster walk with a longer stride or a higher jump, means redrawing the animation. The skeletal side looks less hand-crafted, since its parts only rotate and move and cannot squash, stretch or smear, but it extends with extra parts and image swaps (a blink, an effort mouth, open or fist hands, a change of clothes, a bouquet to hold). Skeletal animation takes much less time and effort than frame-by-frame, though it can still take a lot of both, and changes are adjustments made in an animation tool.

The button row at the bottom picks the style and the animation. The larger "Switch animation style" button on the left switches between the two methods, and the newly shown character starts the same animation. Beside it, a panel titled "Select animation sequence" holds the three buttons that pick the animation: idle, walk or jump. The heading at the top reads "Now showing: skeletal animation" or "Now showing: frame-by-frame animation", and the caption under it names the animation that is playing. What each method costs and what it buys is explained on the demo's page on the site (`details` in its `page.json`), not in the app.

On the skeletal side, a panel titled "Customize" on the right edge holds three buttons that change the outfit, each labelled with what the character shows now. "shirt: yellow" and "shirt: red" toggle the shirt colour, "pants: blue" and "pants: grey" toggle the trousers between blue and light grey, and "hold nothing" and "hold flowers" put a bouquet in the near hand, which then stays a fist; that button shows the active fill while the bouquet is held. A press changes only the images, so the animation and variant carry on where they are, and the choices stay through style, animation and variant changes. The panel is hidden while frame-by-frame shows.

The sprite sheet loops one sequence per button. The skeletal side has three variants of each animation and plays them in turn, with no buttons for them: each variant loops the number of times `plays` in `data/animations.lua` sets, the next one starts at that loop boundary, and the third wraps back to the first. On the skeletal side the caption also shows the variant, for example "Playing: walk animation (variant 2/3)", changing on every switch. Picking an animation or switching style starts again from variant 1. A new skeletal variant is a new set of keyframes for the same parts (this demo defines them in `tools/build_character.py`); on the sprite side it would be every frame of the animation drawn again.

## Running it

Open the project folder in the Solar2D Simulator. There is nothing to install and no plugins are downloaded.

The controls live inside the canvas rather than around it, because the demo is meant to be embedded in a lesson page where the surrounding page is not ours.

## Art and data

The art is drawn in Aseprite and exported; the build reads the exports and never draws anything itself. The character faces right. Its feet rest on row 76 of every 80x80 sprite frame (`sheet.feetRow` in `data/animations.lua`) and on row 92 of the 80x96 skeletal canvas (`feetRow` in the rig), whose extra height above the head leaves room for the high jump; `data/layout.lua` places each style so both stand on the same floor line. The art is shown at 4x with nearest-neighbour filtering so the pixels stay sharp.

- `developmentFiles/images/character-sheet.aseprite` is the sprite sheet's source, exported to `assets/images/character-sheet.png` as a 560x560 uniform grid of 44 drawings at 80x80 (14 idle, 12 walk and 18 jump), seven to a row with no trimming, plus `assets/images/character-sheet.json` in Aseprite's json-hash format. `developmentFiles/README.md` gives the export steps.
- The build reads `frames` (each frame's `frame` rectangle and `duration` in milliseconds, which must be whole 1000/12 ms exposures, rounded to the millisecond), `meta.size` and `meta.frameTags`, one tag per animation (`idle`, `walk`, `jump`) with its `from`, `to` and `direction`.
- `developmentFiles/images/skeletal-parts.aseprite` is the skeletal parts' source, one slice per image, exported one PNG per slice to `assets/skeletal/parts/<slice>.png`. Both sources use the palette in `developmentFiles/images/palette.gpl`.
- `tools/character-rig.json` describes the rig: the canvas, the feet row, the near hip's x position, and the parts in draw order, back to front. It holds the parts' exact pivots, many of them on half pixels, which `.aseprite` slice pivots cannot hold.

Each part in the rig names its `parent` (another part, or `hips` for the root the legs and torso hang from), its `joint` (where its pivot sits in the parent's frame, relative to the parent's pivot, which also sets the limb lengths), its `pivot` in its own image, and either one `image` or `images`, a map from swap state to image, with a `default` state. The feet add `heel` and `toe`, the sole's bottom corners relative to the ankle pivot. The scarf chain adds `follow`, the follow-through settings that make it trail the scarf knot's motion with a lag, each link further down lagging and swinging more. `variants` lists images the app swaps in by hand, outside the frames' states, and `hidden` hides a part unless a skin shows it. `bend` lets a part bend at its joint like a wrist: a list of `[rigid, bent]` canvas rotations in degrees that maps the rotation it would have turning with its parent to the rotation it gets, linear between the points and held past the first and last. Every image of a part, its variants included, must be the same size, because the runtime keeps one pivot per part.

The rig's `skins` add skins beside the default one: each lists the hidden parts it shows (`show`) and the swap parts it holds on one state in every frame (`lockStates`).

The rig has 21 parts drawn from 34 images: torso, head with overlay `eyes` (open, closed) and `mouth` (neutral, effort), `scarf_knot` with the chain `scarf_1`, `scarf_2` and `scarf_3`, near and far `arm_*_upper`, `arm_*_lower`, `hand_*` (open, fist), `leg_*_upper`, `leg_*_lower` and `foot_*`, and the hidden `bouquet`, which hangs from the near hand and bends at the grip. The swaps are the four parts with two images each: eyes, mouth and both hands. The outfit recolours are variants: a red shirt on the torso and both upper arms, light grey trousers on the four leg parts, and the torso in each combination of the two (`torso_red_shirt`, `torso_grey_pants`, `torso_red_shirt_grey_pants`), because it carries both the shirt and the trouser waist. The `bouquet` skin shows the bouquet and holds the near hand in its fist.

The draw order, back to front, is the far arm, the far foot and leg, the scarf chain, the torso, the scarf knot, the near foot and leg, the head with its eyes and mouth, and the near arm, with the bouquet directly behind the near hand, so the fist is drawn over it. Each foot is drawn before its leg, so the trouser hem overlaps the shoe.

`tools/build_character.py` turns these into the skeletal `manifest.json`. Its poses place each foot by its ankle with inverse kinematics, so a planted foot stays put while the hips move over it, and heel and toe roll are a foot rotation. In a walk the hips ride an arc over the supporting foot, as high as a straight leg allows, so the body bobs the way a stride makes it. Forward kinematics walks the parent chain to turn every pose into per-part transforms, the hidden bouquet included, and the scarf chain follows the body's motion with a lag, hanging down the back. The bouquet's `bend` keeps it with the hand in the idles, the walk's back swing and the jump's crouch, holds the blossoms up and forward when the arm swings forward or up, and tips them forward at the jump's apex, where the fist is in front of the face, so the bouquet never covers the eyes. The key poses are the painted references, standing and the jump's apex, and the relaxed walk follows the hand-drawn walk's stride, bob and arm swing. Parts only rotate and move, never scale or skew. The build also writes the two images the animation lesson uses, from the sheet and the parts; they show the drawn outfit and leave out the bouquet. A malformed or missing input stops the build with the file and the problem named.

`tools/check_assets.py` checks the inputs and the manifest against each other and against what the app expects:

- The sheet JSON matches the sheet PNG, every sequence has at least two distinct drawings, and every idle and walk drawing stands on the feet row.
- The sequences in `data/animations.lua` match the JSON tags and durations.
- Every rig part, swap and variant image exists, every PNG in `assets/skeletal/parts/` is used, and each foot's heel and toe match its image.
- `data/layout.lua` stands both characters' feet rows on the floor line.
- The manifest equals a fresh build and holds exactly `variants` animations per family, named `<name>_1` onwards, and `plays` has a count for every name.
- Every variant of a family starts on the same frame as its first variant, so the app can switch variants at a loop boundary.
- Every animation loops cleanly and blinks, and every swap state resolves to an image.
- Every variant is the same size as its part, the default skin hides the bouquet, and the `bouquet` skin shows it, keeps every swap and holds the near hand on its fist.
- `data/outfits.lua` names only the manifest's own variants and skins, uses every variant, and never has two rules for one part, or two skin rules, matching the same outfit.
- The bouquet, eyes and mouth sit on their joints in every frame, the eyes and mouth turn with their parent, and the bouquet turns along its `bend` curve.
- In every skin, no part the skin shows covers an eye pixel in any frame.
- No knee bends backward, idle and walk frames and the jump's crouch, launch and landing stand on the feet row, feet planted in idle and in those jump frames stay put, and no part scales or skews.

Both are build-time tools, excluded from builds. They need Pillow and `lua5.1`, because they read `data/animations.lua` by running it; the `game-web-dev` container has both.

```sh
python3 -B tools/build_character.py
python3 -B tools/check_assets.py
```

`--preview DIR` also writes 4x previews: for each sprite tag a contact sheet with the ground line, an onion-skin sheet that shows the previous drawing faded under each drawing, and a GIF that plays the tag with its JSON durations, plus contact sheets of every skeletal variant per family in the drawn outfit and a sheet of every frame-state layer of the shown parts. `--preview-only` writes the previews and nothing else, leaving the manifest and lesson images untouched, and `--only NAME` (repeatable) limits them to `idle`, `walk`, `jump`, `skeletal-idle`, `skeletal-walk`, `skeletal-jump` or `parts`.

```sh
python3 -B tools/build_character.py --preview-only --preview .scratch/preview --only walk
```

Every tuning value lives in `data/`: positions, sizes, colours and fonts in `data/layout.lua`, the sheet layout, sequences (each a `frames` list of 1000/12 ms exposures, where repeating a frame holds it longer), scale and the skeletal variant count and plays in `data/animations.lua`, the outfit buttons' options and the variants and skin each one shows in `data/outfits.lua`, and every on-screen string in `data/strings.lua`.

## The skeletal package

The skeletal character is a SpriteLoop package: a `manifest.json` that lists the parts, their pivots and draw order, and every animation frame's per-part transforms, plus one PNG per part image. [SpriteLoop](https://balkanramgames.itch.io/spriteloop), a free animation tool by Balkan Ram Games, exports this format, and spriteloop-solar2d plays it.

This demo was built without the SpriteLoop app. `tools/build_character.py` authors the package directly in the same `.spla` folder format, from the rig and keyframes of its own, so the runtime reads exactly what SpriteLoop would export. A package made in SpriteLoop drops into `assets/skeletal/` in its place, as long as it keeps the animation names the app plays.

The package is loaded as a plain folder, not as a `.spla` archive, so no zip plugin is needed.

Each animation family (`idle`, `walk`, `jump`) is built in three variants, `<name>_1` to `<name>_3`, each a set of keyframes written as functions of a parameter set, which is what makes a new variation cheap on the skeletal side:

- `idle_1` takes one slow breath and blinks. `idle_2` looks up, then shifts its weight forward and looks down ahead, blinking at each glance. `idle_3` is impatient: quicker breaths, clenched fists and two runs of toe taps.
- `walk_1` is the relaxed walk that matches the hand-drawn one. `walk_2` speeds up into a brisk walk with a longer stride, a forward lean and pumping fists, and `walk_3` slows into a sneak on tiptoe with bent knees and the hands raised. Both ease in from the relaxed walk over their first steps and back out over their last, so the caption's variant number changes in the middle of each change of gait.
- `jump_1` is the hand-drawn jump. `jump_2` goes over twice as high and hangs longer, stretched out and reaching up, and `jump_3` tucks its knees and pumps a fist overhead at the apex.

`data/animations.lua` sets the number of variants and how many times each family's variant plays before the next one starts; the build stops if it defines a different number of variants. Every variant of a family starts and ends on the same pose (standing, the relaxed walk's contact pose, standing), so switching at a loop boundary never jumps, and every animation blinks once per loop.

Image swaps need no playback code. Each swap image is a manifest variant, the package's first skin maps each swappable part's states to those variants, and every frame names its swap parts' `state`; the runtime resolves a frame's state through the active skin on every frame it draws. The runtime loads a swap image on its first swap, after the scene has set the texture filter back to linear for the text, and the engine keeps a loaded image, with the filter it was loaded under, only while something uses it. So `scripts/skeletalCharacter.lua` holds one texture per distinct image in the package, the outfit variants and the bouquet included, read from the package spriteloop has already loaded and created while the nearest filter is set, and releases them when the scene is destroyed; every swap then reuses a sharp texture.

The outfit uses the runtime's other two swaps, so it needs no frames of its own either. A recolour is a variant no frame names: `scripts/skeletalCharacter.lua` sets it with `setVariant`, which beats a frame's state, and `clearVariant` brings the drawn image back. The bouquet is a part hidden by default, and the `setSkin` call that picks the `bouquet` skin shows it and turns both of the near hand's states into the fist. Each of these calls redraws the current frame without interpolation, so the app then steps the rig by zero seconds to redraw it the way playback does, and the animation carries on without a restart.

Every animation in the manifest is written with `loop: true` and loops with a plain `play( name )`; its last frame leads into its first. The runtime's loop override only works one way: `play( name, { loop = true } )` loops even a `loop: false` animation, but `{ loop = false }` cannot stop a `loop: true` one, because the override is read with an `a and b or c` idiom that drops `false`. These animations never fire the "complete" event. The app counts a variant's plays with the `onLoop` callback of `play` and starts the next variant inside that callback: the runtime calls it before drawing the frame and draws from the animation that is current then, so the new variant's first frame shows on that same frame.

## Third-party code

- spriteloop-solar2d by ponywolf, https://github.com/ponywolf/spriteloop-solar2d, vendored as `libs/spriteloop.lua` from commit `9c3039903b3e7432be7d9b44007522e053483fe3` (2026-08-27, module `_VERSION` 1.0.0) with one local patch, marked in the file: the `plugin.zip` lookup happens only when a `.spla` archive is loaded, so the folder-loading demo configures no plugin and the Simulator prints no "plugin.zip is not configured" warning.
- The upstream repository has no license file at that commit; the author has been asked to add the MIT license. Check that it has landed before this folder is published.
- `scripts/screen.lua` is from Spyric Games, under the MIT license, copied unchanged from the feedback demo.
- Roboto is under the SIL Open Font License; the license text is in `assets/fonts/roboto/OFL.txt`.

## Verifying in the container

The app runs under stock Lua 5.1 with the engine stubbed, which is how the state machine, the variant cycle and the touch wiring are checked without the Simulator. `tools/verify_state.lua` tests `scripts/demoState.lua` on its own: the play counting, the wrap from the last variant to the first, the reset to variant 1 and the outfit toggles, which leave the animation alone and survive every animation and style change. `tools/verify_scene.lua` loads the real scene, the real vendored runtime and the real manifest through `tools/stubs/solar2d_stub.lua` and `tools/stubs/json.lua`, then presses the buttons and drives frames between presses. It checks that each variant loops its count and that the next one starts on the same frame from its first frame, the caption on every switch, that a press restarts from variant 1 and a hidden character does not advance, that taps outside the buttons change nothing, the outfit panel (hidden and untouchable while frame-by-frame shows, each button's label following its option, every shirt, trousers and bouquet combination drawing the right images without restarting the animation, the fist and the outfit on every frame of every variant while the bouquet is held, and the choices kept through style, animation and variant changes), and that every package image, the swap images included, is loaded under the nearest filter; the stub records the filter in effect for every image and texture load. Each prints only failures and a final count.

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
