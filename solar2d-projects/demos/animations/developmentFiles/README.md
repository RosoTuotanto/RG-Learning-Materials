# Development files

Editable sources for the demo's art. Both sources use the palette in `images/palette.gpl`.

This whole folder is excluded from builds (`developmentFiles/*` in `build.settings` `excludeFiles`).

- `images/character-sheet.aseprite` is the frame-by-frame character: 80x80 frames tagged `idle`, `walk` and `jump`, each frame with its own duration.
- `images/skeletal-parts.aseprite` holds the skeletal character's part images, one slice per image, named after the image.

Run the commands below from `developmentFiles/images/`. After either export, run `python3 -B tools/build_character.py` and `python3 -B tools/check_assets.py` from the demo folder.

## Sprite sheet: File > Export Sprite Sheet

- Layout tab: Sheet type "By Rows", Constraints "Fixed # of Columns" set to 7, Merge Duplicates off, Ignore Empty off.
- Sprite tab: Source "Sprite", Layers "Visible layers", Frames "All frames".
- Borders tab: Border Padding 0, Spacing 0, Inner Padding 0, Trim Sprite off, Trim Cels off, Extrude off.
- Output tab: Output File on, JSON Data on, format "Hash", Meta: Tags on.
- Save `character-sheet.png` and `character-sheet.json` to `assets/images/`.

It writes `assets/images/character-sheet.png`, every frame on a uniform grid with no trimming or padding, and `assets/images/character-sheet.json`, which carries each frame's rectangle and duration and the three tags. The demo reads frame durations as whole 1000/12 ms exposures, so keep every duration a multiple of one exposure, rounded to the millisecond (83, 167, 250 and so on).

CLI equivalent:

```sh
aseprite -b --list-tags character-sheet.aseprite --sheet ../../assets/images/character-sheet.png --sheet-type rows --sheet-columns 7 --format json-hash --data ../../assets/images/character-sheet.json
```

## Skeletal parts: one PNG per slice

Aseprite exports each slice to its own file only from the command line:

```sh
aseprite -b skeletal-parts.aseprite --save-as "../../assets/skeletal/parts/{slice}.png"
```

It writes `assets/skeletal/parts/<slice>.png` for every slice, such as `head.png` and `scarf_1.png`, each cropped to its slice.

The parts' exact pivots live in `tools/character-rig.json`, not in the slices. Many pivots sit on a half pixel, such as the middle of a two-pixel-wide joint, while an `.aseprite` slice pivot is a whole pixel, so the slice pivots are only approximate.
