# Instructions: rewrite README.md for this folder

This folder's `README.md` predates the rename to `extra-assets/` and still describes the folder as the game's asset sources. Rewrite it once the user has finished their planned changes to the folder's contents, then delete this file.

## Framing

- The folder holds extra assets: files added to the game in addition to what `versio-0` contains from the start, since every `versio-N` folder already carries the game's own assets.
- Match `../../3-fysiikkapallo/extra-assets/README.md` and `../../6-platformer/extra-assets/README.md`: a `# Top-down-seikkailu: lisäassetit` title, the same intro paragraph, and a `## Sisältö` list naming each item, what it is, the lesson that introduces it, and the first version that contains it.
- Write in Finnish with the repo's game-dev vocabulary (assetit, tileset, image sheet, frame).
- Look up each lesson title in `site/games/7-top-down/versio-N/page.json` and confirm the first containing version by searching the `versio-N` folders.
- Every top-down asset currently ships in `versio-0`, so the "added later" framing is false for the current contents. If some files stay that are not added later (Kenney source packs, the master copies the tools copy into each version), say plainly what they are rather than forcing them under that framing.

## Content to keep while its files remain

- The Kenney CC0 licence section and the source packs' download URLs and date.
- The well credit sentence verbatim: "Tein kaivon kuvan käyttäen Kenneyn tilesettiä mallina." Give no technical detail on how the well image was made.
- The Tiled parameter table for `tileset-topdown.png` and the frame tables for `characters.png` and `items.png`, which the lessons rely on.

## Coupled files

- `../tools/build_assets.py`, `../tools/build_maps.py` and `../tools/generate_interact_sfx.py` read or write this folder by path. Update them and `../tools/README.md` if files move or are renamed, then run `python3 -B build_assets.py --check` in `../tools/`.
- `../README.md` describes this folder in one sentence; keep it consistent with the new README.
- The LMS course 6 lessons (`Roso/lms`, FINAL pages 068, 069, 071, 073, 074 and 080, plus `TOPDOWN-PLAN.md`) quote these file names; mirror any rename there.
