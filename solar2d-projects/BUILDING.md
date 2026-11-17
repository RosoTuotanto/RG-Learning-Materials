# Building the HTML5 versions

Every game version and demo has a page on the [learning materials site](https://rosotuotanto.github.io/RG-Learning-Materials/), and each page plays an HTML5 build of its project. The builds are made by hand in the Solar2D Simulator, copied into `site/`, and finished with the site builder.

## What gets built

- Games: every `games/<game>/versio-N/` and `games/<game>/versio-kotitehtavat/` folder.
- Demos: every `demos/<demo>/` folder.
- `versio-0` folders are never built. They exist only as the comparison base for `versio-1` on the changes pages, so they have no page on the site.
- `assignments/` is never built (see the last section).

## Build settings

Every project's `build.settings` must keep `neverStripDebugInfo = true` in its `build` table. It keeps debug info in the build, so Lua errors on the site, in the browser console and in the site's crash panel, show real function names and line numbers. Every project in this folder has it set, so a new project or version copied from an existing one inherits it.

## HTML5 Build Setup

Open the project folder in the Simulator and choose File > Build > HTML5.

- Application Name: the name of the site page folder the build goes to, so `versio-3`, `versio-kotitehtavat`, or the demo name such as `ball-prototype`. Every build on the site follows this naming.
- Save to Folder: any folder outside the project. The Simulator writes the build to `<Save to Folder>/<Application Name>.html5/`.
- Include Standard Resources: on for `6-platformer` and `7-top-down`, off for every other game and demo.
- Create FB Instant archive: off.

`6-platformer` and `7-top-down` need Include Standard Resources because their options scene uses `widget.newSlider` and `widget.newSwitch` with the default widget theme. On HTML5 the setting only adds the default theme images (`widget_theme_*.png`) to the build, and without them those widgets have no images to draw. No other project uses the `widget` library.

## Adding the builds to the site

1. Copy the contents of each `<Application Name>.html5/` folder into the matching page's `app/` folder: `site/games/<game>/<versio>/app/` or `site/demos/<demo>/app/`. Replace whatever the folder held before.
2. Run `python tools/build_website.py` from the repository root. It regenerates every page and patches every build in `site/` in place, and its report lists each app as MISSING, PATCHED, ALREADY, or FAILED. A FAILED patch makes the run fail.
3. When a game or demo was added or renamed, also run `python tools/generate_og_images.py` and then `python tools/build_website.py` again, so the new page gets its own share image.

Never skip the site builder after copying a build in. An unpatched build freezes when the visitor clicks outside it, shares its save files with every other build on the site, discards Lua `print()` output, and never reports a crash to the page's crash panel. To patch a single build without regenerating the site, run `python tools/html5_build_patcher.py <path>` with the build's `app/` folder.

## assignments/

The projects in `assignments/` are not built and have no page on the site. They are almost-ready Solar2D projects that participants open in the Simulator and complete in a lesson assignment. Each project's own `README.md` names its lesson and how the project is used.
