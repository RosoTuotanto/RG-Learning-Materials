# og-assets

Input assets for `tools/generate_og_images.py` (the Open Graph share-image generator). These are not served; the generated images land in `site/assets/og-images/`.

## Files

- `Archivo.ttf` - Archivo variable font (weight + width axes), used by Pillow for the heading and slug text. Downloaded from the Google Fonts repository (`cdn.jsdelivr.net/gh/google/fonts@main/ofl/archivo/Archivo[wdth,wght].ttf`) on 2026-08-31. Licensed under the SIL Open Font License 1.1 (`LICENSE-Archivo.txt`).
- `logo.png` - the Roso Games logo, rasterized once from `site/assets/roso-games-hero.svg` (transparent background, 3x the 520px viewBox). Pillow cannot render SVG, so this raster is committed as a generator input. The source SVG is frozen; regenerate only if it ever changes.

## Regenerating logo.png

Requires the container's global Playwright (Chromium). From the repo root:

```bash
NODE_PATH=$(npm root -g) node - <<'JS'
const { chromium } = require("playwright");
const fs = require("fs");
(async () => {
    const svg = fs.readFileSync("site/assets/roso-games-hero.svg", "utf8");
    const browser = await chromium.launch();
    const page = await browser.newPage({ viewport: { width: 520, height: 520 }, deviceScaleFactor: 3 });
    await page.setContent(`<!doctype html><body style="margin:0;background:transparent"><div id="w" style="width:520px;height:520px">${svg}</div>`);
    await (await page.$("#w svg")).screenshot({ path: "tools/og-assets/logo.png", omitBackground: true });
    await browser.close();
})();
JS
```
