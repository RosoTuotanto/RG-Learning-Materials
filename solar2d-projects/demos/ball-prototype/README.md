# Ball Prototype Demo

The pressable circle from the lesson "Iterointi käytännössä", twice: as version 1, the first prototype, and as version 9, after eight rounds of iteration. The lesson asks where development should have stopped, and the answer is version 1: version 9 is smoother and has three bugs fixed, but it answers the same question about how the circle feels to press.

Try it in the browser on the [learning materials site](https://rosotuotanto.github.io/RG-Learning-Materials/demos/ball-prototype/).

## The versions

`scripts/version1.lua` and `scripts/version9.lua` are the lesson's listings verbatim, with only a `return button` added at the end. Their comments are Finnish, as in the lesson, and nothing in them is fixed. That includes version 1's bug: if the finger slides off the circle before it is lifted, the circle stays big, and pressing it again grows it further.

## Running it

Open the project folder in the Solar2D Simulator. There is nothing to install and no plugins are downloaded.

Selecting a version starts it from a fresh circle, which also resets a circle stuck big by version 1's bug.

## Language

The demo shows Finnish by default, and the flag button switches between Finnish and English. An HTML5 build starts in English when the URL of the page it is embedded in contains `/en/`, which `plugin_pageUrl.js` reports to the demo.

## Author

[© 2026 Eetu Rantanen](https://www.erantanen.com)
