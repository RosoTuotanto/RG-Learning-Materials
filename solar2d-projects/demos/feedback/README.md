# Feedback Demo

Two boxes shoot each other with pistols. The same fight replays across seven versions, and each one changes a layer of feedback on a mechanic that never changes at all. Version 1 already contains every piece of information the fight has to offer and none of the feel. Everything after it adds nothing to the mechanic and everything to how it reads, until version 7 takes one of those additions back out again.

The points the demo is making, and the ones it deliberately does not make, are written out in [NOTES.md](NOTES.md).

## The versions

| # | Name | What it changes |
| --- | --- | --- |
| 1 | Baseline | Nothing. Shot, bullet, hit, health bar. |
| 2 | The target reacts | Colour flash on hit. |
| 3 | The target moves | Knockback on hit. |
| 4 | The shooter reacts | Recoil, muzzle flash, ejected casing. |
| 5 | Timing and weight | Anticipation, easing curves, hit stop, screen shake. |
| 6 | Sound | Shot, impact and casing audio, one timbre per fighter. |
| 7 | More is not always better | Removes the casing sound. |

Versions are cumulative, so version 4 runs everything versions 1 to 3 turned on. A version can also take a layer back off, which is all version 7 does: it is version 6 without the casing ping, because that one repeats too often and stands out too much. It is in the demo to make the point that an addition is not automatically an improvement and that only trying it tells you which it was.

## Running it

Open the project folder in the Solar2D Simulator. There is nothing to install and no plugins are downloaded.

The controls live inside the canvas rather than around it, because the demo is meant to be embedded in a lesson page where the surrounding page is not ours. There are four: the seven version buttons, a volume slider, a reset button in the top left corner and a language toggle in the top right. Switching version is instant and restarts the fight from its first loop, which is the comparison the demo is built around: going from version 7 straight back to version 1 is one click. Reset does the same thing to the version already on screen.

Neither corner button carries text. The reset arrow is drawn from a line and a polygon because the project's fonts have no glyph for it, and the language toggle shows the flag of the language being read rather than a two-letter code for the one it switches to.

Only versions 6 and 7 make any sound, which is why the slider carries a line saying so. It defaults to half volume rather than to silence, on the grounds that nothing can be heard until a visitor has stepped all the way through to them.

## Language

The demo shows Finnish by default and the button in the top right corner switches between Finnish and English at any time.

On an HTML5 build the starting language comes from the hosting page instead. `plugin_pageUrl.js` is a small HTML5-only plugin whose whole job is to report the URL of the page the demo is running on; if that URL contains `/en/`, the demo starts in English. The lesson site keeps its English tree under that path, so an English lesson gets an English demo without a second build.

Three things worth knowing about that:

- The match is on the literal string `/en/`. A page at `https://example.fi/en` with no trailing slash will not match.
- The demo is expected to be iframed, and the page that decides the language is the parent rather than the iframe. The plugin tries the parent's URL first, which only works same-origin, then the referrer, which survives a cross-origin embed unless the page strips it, and finally its own URL.
- On every other platform, and in the Simulator, the plugin is never loaded and the demo starts in Finnish.

Code, comments and these documents are English only. Only the text the demo puts on screen is translated, and it all lives in `data/strings.lua`.

## Tuning it

Every value the demo uses lives in `data/`, and no tuning value appears in the code that consumes it.

- `data/versions.lua` holds which layers each version switches on and off, plus every duration, distance, colour and easing curve those layers use. This is the file to open first.
- `data/fight.lua` holds the beat timeline: when each shot is fired and by whom, how far either way that moment is allowed to move, how much health each fighter has, and how fast a bullet travels.
- `data/layout.lua` holds positions, sizes, fonts and the palette.
- `data/strings.lua` holds every piece of text on screen, in both languages.

Change a beat time in `data/fight.lua` and every version changes with it, which is what keeps the comparison honest.

`beatVariance` has a ceiling that is not a matter of taste. The beats are 800 ms apart and a bullet is in the air for 358 ms, so anything above 200 ms lets two offsets close a gap below the flight time and a fighter answers a bullet that has not landed yet. That inverts the cause and effect the whole demo is about.

## How the comparison stays honest

Two versions have to play the identical fight or the difference a learner sees cannot be attributed to the feedback layer. That costs three things:

- Shot timing comes from the authored beat list, and the jitter only moves each beat inside a fixed window: the order, the shooters and the outcome are the same every time. All motion is time-based rather than frame-counted.
- Randomness is the beat jitter plus casing spin and velocity, all from `scripts/rng.lua` rather than `math.random`. The seed is the base one plus a loop counter, and selecting or resetting a version puts that counter back to zero, so every loop is timed differently while the first loop of every version is identical.
- Positional effects always animate back to a stored anchor instead of applying relative offsets, so nothing drifts across a long loop.

Comparing two versions therefore means switching between them rather than watching one for a while and then the other: a switch restarts at loop one on both sides.

The hit stop freezes the scene by pausing every transition and holding the scene's own frame clock. It is entered before any transition is created on that frame, because a pause cannot reach tweens the transition library is already iterating over.

## Art

The fight is drawn entirely from `display.newRect`, `display.newPolygon` and `display.newLine`. That keeps the HTML5 payload down and the source readable, and it keeps the demo honest, since the whole argument is that feel comes from behaviour rather than from art. The guns are L-shaped polygons whose back end sits inside the body, which is enough to read as a held object without the demo turning into anything more graphic than two boxes.

The only images in the project are the two flags on the language button, and even those are generated rather than downloaded, so nothing third-party is vendored.

## Generated assets

Both generators are build-time tools with fixed output. They are excluded from builds and only need running when their output is deliberately changed.

The `.wav` files are placeholders, synthesised from noise and sine sweeps so that the project carries no sample licensing. Replacing them with real recordings of the same file names needs no code changes.

```sh
python3 tools/generate_audio.py
```

The flags are drawn from their published construction specifications, which is what keeps them free of image licensing. The Finnish flag is 11:18 divided 4:3:4 and 5:3:10; the Union Jack is 1:2 with its saltire offset a thirtieth of the height anticlockwise, which is the detail that decides whether it comes out upside down. If it is ever regenerated, check that the broad white diagonal is uppermost on the hoist side. This one needs Pillow, which the `game-web-dev` and `ai-data-dev` containers both have.

```sh
python3 tools/generate_flags.py
```

## Building for the web

The demo is designed to be an HTML5 build embedded in a lesson page. One step is not optional: stock Solar2D HTML5 builds suspend the runtime when the window loses focus, not just when the tab is hidden. Untreated, clicking anywhere on the lesson page outside the demo freezes it, and a resize while suspended leaves a canvas that a touch cannot recover. Patch every build with `html5_build_patcher.py` before shipping it, and check the patched output rather than trusting the run, since the patcher reports a missed pattern as a warning and still exits successfully.

## Author

[© 2026 Eetu Rantanen](https://www.erantanen.com)
