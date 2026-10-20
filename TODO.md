# RG-Learning-Materials: Open Tasks

Reviewed: 2026-08-17
Scope: /workspace/Roso/RG-Learning-Materials/ repo-internal work. The repo skeleton and the homework/answers extraction (batch 4 of /workspace/Roso/lms/pelituottaja/.scratch/TODO.md) are complete. The repo publishes to https://github.com/RosoTuotanto/RG-Learning-Materials (personal account, ruled 2026-08-17) and GitHub Pages hosting fits the size limits. All lms TODO Task 14 plan decisions are closed: this repo is the single home of homework assignments and answers, and the LMS side keeps no assignment texts once lms TODO Task 15 lands.
Model: This document was prepared by Fable 5

---

<!-- INSTRUCTIONS

## Status Values

- `OPEN`: identified, not yet addressed.
- `IN-PROGRESS`: work underway.
- `COMPLETE`: done and verified.
- `REVIEW`: needs further investigation or a second opinion.
- `BLOCKED`: cannot proceed; the task notes what it depends on.

## How to Use

- Claude sets all new items to `OPEN` by default.
- To act on an item, ask Claude to handle it; Claude updates the status to `IN-PROGRESS` and then `COMPLETE` when done and verified.
- To dismiss or park an item, change its status yourself; add a brief reason where the status requires one.
- On a re-run or update, Claude preserves statuses that were changed from `OPEN`, adds new items as `OPEN`, and removes items per the update semantics.
- Items are matched by identity (ID prefix plus title), not by numbering or line numbers.
- Do NOT commit or push to git. The user manages all commits and pushes.
- Tasks are ordered by priority: bug fixes and quick wins first, then larger fixes, then new features, then long-term tasks. When adding new tasks, insert them at the appropriate position and renumber subsequent tasks.
- To remove completed tasks, tell Claude to "update the todo" or invoke /create-todo.
- This folder becomes a public GitHub repo later. Participant-facing content is Finnish; this file and commit messages are English.
- The HTML5 viewer task stays last in this list by request.

-->

---

## Task 1: Stage the learning game sources into games/

**Status:** `COMPLETE`

- **Outcome (2026-08-30):** All learning games are staged as source folders under `games/`: course 2 Nopeustesteri (reconstructed from lessons 046-051, which never had zips), course 3 Fysiikkapallo, course 4 Pokeri, course 5 Visual novel, course 6 Platformer, plus the top-down adventure in `7-top-down`. Each stage lives at `games/<game>/versio-N/<Nimi (versio N)>`, one complete Solar2D project folder per version. `7-top-down` keeps its `source/` subfolder layout; the HTML5 builds are no longer stored beside the sources (see Task 3 and the repo-level `builds/`). Each game folder has a short Finnish README. Plain Lua logic verified in-container; Simulator runs are Eetu's. Addendum (2026-09-04): the LMS final-sweep Task 3 review confirmed three code bugs in the 6-platformer source (stopAI finalize guard inverted, missing `enemy = {}` reset in scene:create, playSFX volume formula inverted); fixed across versio-17/18/19/kotitehtavat (11 files, luacheck and parse clean) to stay in parity with the corrected lessons (`MUUTOS-032`/`MUUTOS-033` in the LMS repo).

---

## Task 2: Stage the programming model answer projects into homework answers

**Status:** `COMPLETE`

- **Outcome (2026-08-30):** The programming model answers for courses 2-6 are implemented directly in the repo at `games/<game>/versio-kotitehtavat/`, each built on top of that game's final version and container-verified (plain Lua logic; Simulator runs are Eetu's). Each course's `homework/<course>/answers/1-ohjelmointi/README.md` is repointed to its model-answer project with a relative link; course 2 keeps its byte-exact inline code block from the LMS lesson. Addendum (2026-10-10): all five `versio-kotitehtavat` projects were reviewed against their homework specs and fixed (pokeri bet row moved off the cards to the top-right under the money counter plus input blocking during card animations, fysiikkapallo multiplier sum and seam double-count, nopeustesteri lint and score background, visual-novel Close placement, platformer AI paused with the menu); luacheck clean, Simulator pass pending.

---

## Task 3: HTML5 viewer site and tools/ build tooling

**Status:** `COMPLETE`

- **Outcome (2026-08-30):** The builder shipped as `tools/build_website.py`, generating the static site from the components in `tools/web-src/` (base template, footer, styles) plus a hand-editable `page.json` beside each generated page. The site is generated (84 pages: landing, game pages, version and `versio-kotitehtavat` pages, a demos overview and its demo pages), with the three-level `index > {game} > {version}` breadcrumb and a parallel demos branch. Each version and demo page iframes `./app/index.html`; the actual Solar2D HTML5 builds are pending host-side and get dropped into each page's `app/` subfolder. One command does everything: `python tools/build_website.py` regenerates the pages and patches every build via `tools/html5_build_patcher.py` (imported as a module), reporting MISSING/PATCHED/ALREADY/FAILED per app (exit 0 = pages fine and no patch failures; missing apps are loud warnings). `.github/workflows/pages.yml` deploys `builds/` as the Pages static payload.

---

## Task 4: Host rebuild after the 2026-10-12 renames

**Status:** `OPEN` (Eetu's host steps; tracked in `/workspace/ROSO-LMS-TODO.md` section 3, which carries the full build list. This entry is the reference copy.)

- **Context (2026-10-12):** rulings 32, 33, 35 and 36 renamed the course 3 game and build folders to `games/3-fysiikkapallo` and `builds/3-fysiikkapallo`, and set the course 6 in-game menu title to "Platformer". Pages and OG cards are regenerated in the container; HTML5 builds need the host.
- **Note:** `site/games/3-fysiikkapallo/` is the renamed build folder, so any HTML5 build already inside it keeps working but was not rebuilt. The container run found no HTML5 build in any `app/` folder.
- **Menu title changed:** rebuild HTML5 from each source folder into its target:

- `solar2d-projects/games/6-platformer/versio-1/` -> `site/games/6-platformer/versio-1/app/`
- `solar2d-projects/games/6-platformer/versio-2/` -> `site/games/6-platformer/versio-2/app/`
- `solar2d-projects/games/6-platformer/versio-3/` -> `site/games/6-platformer/versio-3/app/`
- `solar2d-projects/games/6-platformer/versio-4/` -> `site/games/6-platformer/versio-4/app/`
- `solar2d-projects/games/6-platformer/versio-5/` -> `site/games/6-platformer/versio-5/app/`
- `solar2d-projects/games/6-platformer/versio-6/` -> `site/games/6-platformer/versio-6/app/`
- `solar2d-projects/games/6-platformer/versio-7/` -> `site/games/6-platformer/versio-7/app/`
- `solar2d-projects/games/6-platformer/versio-8/` -> `site/games/6-platformer/versio-8/app/`
- `solar2d-projects/games/6-platformer/versio-9/` -> `site/games/6-platformer/versio-9/app/`
- `solar2d-projects/games/6-platformer/versio-10/` -> `site/games/6-platformer/versio-10/app/`
- `solar2d-projects/games/6-platformer/versio-11/` -> `site/games/6-platformer/versio-11/app/`
- `solar2d-projects/games/6-platformer/versio-12/` -> `site/games/6-platformer/versio-12/app/`
- `solar2d-projects/games/6-platformer/versio-13/` -> `site/games/6-platformer/versio-13/app/`
- `solar2d-projects/games/6-platformer/versio-14/` -> `site/games/6-platformer/versio-14/app/`
- `solar2d-projects/games/6-platformer/versio-15/` -> `site/games/6-platformer/versio-15/app/`
- `solar2d-projects/games/6-platformer/versio-16/` -> `site/games/6-platformer/versio-16/app/`
- `solar2d-projects/games/6-platformer/versio-17/` -> `site/games/6-platformer/versio-17/app/`
- `solar2d-projects/games/6-platformer/versio-18/` -> `site/games/6-platformer/versio-18/app/`
- `solar2d-projects/games/6-platformer/versio-19/` -> `site/games/6-platformer/versio-19/app/`
- `solar2d-projects/games/6-platformer/versio-kotitehtavat/` -> `site/games/6-platformer/versio-kotitehtavat/app/`

- **Also MISSING per `python tools/build_website.py` (2026-10-12), build into each folder's `app/`:**

- `site/games/2-nopeustesteri/`: versio-1 to versio-8, versio-kotitehtavat
- `site/games/3-fysiikkapallo/`: versio-1 to versio-7, versio-kotitehtavat
- `site/games/4-pokeri/`: versio-1 to versio-12, versio-kotitehtavat
- `site/games/5-visual-novel/`: versio-1 to versio-9, versio-kotitehtavat
- `site/games/7-top-down/`: versio-1 to versio-15
- `site/demos/animations/` and `site/demos/feedback/` (demos)
- **After the builds:** run `python tools/build_website.py` from the repo root so it patches every new build; it reported 77 MISSING apps in total.

---

## Task 5: Animations demo (course 5 lesson "Animointi Solar2D:ssä")

**Status:** `OPEN` (Eetu's host steps; tracked in `/workspace/ROSO-LMS-TODO.md` section 3. This entry is the reference copy.)

- **Done in the container (2026-10-02):** `solar2d-projects/demos/animations/` is a complete Solar2D project: one pixel-art character animated as a 16-frame sprite sheet and as a ten-part skeletal rig played by the vendored `libs/spriteloop.lua` (ponywolf/spriteloop-solar2d, commit 9c30399, no upstream license file; see its README). `tools/build_character.py` generates every asset plus the two lesson images in the LMS repo; `tools/check_assets.py`, `tools/verify_state.lua` and `tools/verify_scene.lua` pass (248, 26 and 79 checks); luacheck clean. `builds/animations/page.json` and the generated page exist, the OG card is generated.
- **License (ruled 2026-10-03):** the spriteloop-solar2d repository carries no license file yet; the author is being asked to add the MIT license. Confirm it landed upstream before the first push. `libs/spriteloop.lua` carries one marked local patch (lazy `plugin.zip` lookup, so the Simulator prints no plugin warning); offer it upstream.
- **Host steps, in order:** open `solar2d-projects/demos/animations/` in the Solar2D Simulator and check the look (buttons, tap to switch, the skeletal variant caption cycling 1 to 3); build HTML5 into `site/demos/animations/app/`; run `python tools/build_website.py` from the repo root (patches the build); commit and push; open `https://rosotuotanto.github.io/RG-Learning-Materials/animations/app/index.html`; then confirm the iframe on the lesson page `animointi-solar2dssa` in the LMS once that page is uploaded.
- **Also check on the host:** the skeletal character loads on the HTML5 build (the runtime reads `assets/skeletal/manifest.json` with `io.open` from the resource directory) and touch on a phone toggles the style without triggering a button.
