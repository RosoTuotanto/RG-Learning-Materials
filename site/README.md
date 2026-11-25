# site

The GitHub Pages viewer site. `python tools/build_website.py` generates it, and `.github/workflows/pages.yml` publishes it.

Every `index.html` in this folder is generated, and the builder overwrites it. Edit these instead:

- The `page.json` beside each page holds that page's content.
- `tools/web-src/` holds the page templates, the styles and the site configuration in `site.json`.

## Updating the site

1. Copy each Solar2D HTML5 build into the matching page's `app/` folder. [BUILDING.md](../solar2d-projects/BUILDING.md) gives the build settings.
2. Run `python tools/build_website.py` from the repository root. It regenerates every page, patches every build in place, and reports missing or failed apps.
3. After adding or renaming a game or demo, run `python tools/generate_og_images.py` and then the site build again, so the new page gets its own share image. The image generator needs Pillow.

The builder's tests run with `python3 -B -m unittest discover -s tests` from `tools/`.

## What the builder generates

- The front page, one page per game, version and demo, and `404.html`.
- A `muutokset/` page under each version that has a previous version in `solar2d-projects/games/`, showing what changed between the two. `versio-kotitehtavat` is compared with the highest numbered version, and `versio-0` has no page.
- `sitemap.xml`, `robots.txt` and each page's SEO tags, from the base URL in `tools/web-src/site.json`.

The root README shows a screenshot of the front page from `assets/readme/`. Retake it when the site's look changes.
