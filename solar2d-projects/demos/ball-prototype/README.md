# Ball Prototype Demo

The pressable circle from the lesson "Iterointi käytännössä", twice: once as version 1, the first prototype, and once as version 9, after eight rounds of iteration. The lesson asks where development should have stopped, and the answer is version 1. Pressing the two side by side is the argument: version 9 is smoother and has three bugs fixed, but it answers exactly the same question about how the circle feels to press.

## The versions

`scripts/version1.lua` and `scripts/version9.lua` are the lesson's listings verbatim, with only a `return button` added at the end so the demo can hold on to the circle each one creates. Their comments stay Finnish because that is what the learner reads in the lesson, and nothing in them is fixed or reformatted. That includes version 1's bug: if the finger slides off the circle before it is lifted, the `"ended"` phase never reaches the circle and it stays big. Pressing it again grows it further.

## Running it

Open the project folder in the Solar2D Simulator. There is nothing to install and no plugins are downloaded.

The controls live inside the canvas, because the demo is meant to be embedded in a lesson page. Press the circle, and switch between the versions with the two buttons at the bottom. Selecting a version always starts it from a fresh circle, so pressing the version already showing is also how a circle stuck big by version 1's bug is reset.

## Language

The demo shows Finnish by default and the flag button in the top right corner switches between Finnish and English at any time.

On an HTML5 build the starting language comes from the hosting page instead. `plugin_pageUrl.js` is a small HTML5-only plugin that reports the URL of the page the demo is running on; if that URL contains `/en/`, the demo starts in English. It tries the parent page's URL first, then the referrer, then its own URL. In the Simulator and on every other platform the plugin is never loaded and the demo starts in Finnish.

Code and comments outside the two version files are English. Only the text the demo puts on screen is translated, and it all lives in `data/strings.lua`. Positions, sizes, fonts and colours live in `data/layout.lua`.

## Building for the web

The demo is designed to be an HTML5 build embedded in a lesson page. One step is not optional: stock Solar2D HTML5 builds suspend the runtime when the window loses focus, not just when the tab is hidden. Untreated, clicking anywhere on the lesson page outside the demo freezes it, and a resize while suspended leaves a canvas that a touch cannot recover. Patch every build with `html5_build_patcher.py` before shipping it, and check the patched output rather than trusting the run, since the patcher reports a missed pattern as a warning and still exits successfully.

## Author

[© 2026 Eetu Rantanen](https://www.erantanen.com)
