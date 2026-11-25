# og-assets

Input assets for `tools/generate_og_images.py` (the Open Graph share-image generator). These are not served; the generated images land in `site/assets/og-images/`.

## Regenerating logo.png

`logo.png` is `site/assets/roso-games-hero.svg` rasterized, because Pillow cannot render SVG. Regenerate it only if the SVG changes. This needs Playwright with Chromium. From the repo root:

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
