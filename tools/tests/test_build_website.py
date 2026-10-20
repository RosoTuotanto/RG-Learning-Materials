#!/usr/bin/env python3
"""Tests for tools/build_website.py. Run: python3 tools/tests/test_build_website.py"""

import json
import re
import shutil
import sys
import tempfile
import unittest
import zipfile
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(REPO_ROOT / "tools"))

import build_website

# A synthetic Solar2D HTML5 build the patcher can fully patch, reused from the
# patcher's own fixture shape (single .bin holding a matching .js).
INDEX_HTML = """<!DOCTYPE html>
<html>
<head>
<style>
\t\tprogress {
\t\t\tappearance: none;
\t\t\tborder-radius: 3px;
\t\t\tbox-shadow: inset 0 2px 3px rgba(0, 0, 0, 0.2);
\t\t}
</style>
<script>
\tvar Module = {
\t\tprintErr: function(text) {
\t\t\tif( typeof(text) === "string" && text.toUpperCase().indexOf("ERROR") >= 0) alert(text);
\t\t\tstatusElement.innerHTML = text;
\t\t}
\t};
</script>
</head>
<body>
<script>
window.addEventListener('load',function(){window.focus()});
window.addEventListener('mousedown', function () {
document.activeElement.blur();
window.focus();
}, true);
</script>
</body>
</html>
"""

PATCHABLE_JS = (
    "var x=1;\n"
    "function _emscripten_set_blur_callback_on_thread(target,userData,useCapture,"
    "callbackfunc,eventTypeId,targetThread)"
    '{registerFocusEventCallback(target,userData,useCapture,callbackfunc,12,"blur",'
    "targetThread);return 0}\n"
    "var y=2;\n"
)

WASM_STUB = b"\x00asm\x01\x00\x00\x00stub"


def write_page_json(directory: Path, **fields) -> None:
    directory.mkdir(parents=True, exist_ok=True)
    (directory / "page.json").write_text(json.dumps(fields), encoding="utf-8")


def make_app_build(app_dir: Path, name: str) -> None:
    """Create a patchable Solar2D build inside an app/ folder."""
    app_dir.mkdir(parents=True, exist_ok=True)
    (app_dir / "index.html").write_text(INDEX_HTML, encoding="utf-8")
    (app_dir / "index-debug.html").write_text("debug", encoding="utf-8")
    (app_dir / "index-nosplash.html").write_text("nosplash", encoding="utf-8")
    with zipfile.ZipFile(app_dir / f"{name}.bin", "w", zipfile.ZIP_DEFLATED) as zf:
        zf.writestr(f"{name}.js", PATCHABLE_JS)
        zf.writestr(f"{name}.wasm", WASM_STUB)


def make_valid_tree(root: Path) -> None:
    """Landing, one game with versio-1..3 + kotitehtavat, one demo.

    Only versio-2 carries a real app/ build; every other version and the demo
    has no app folder, so those are expected MISSING warnings (exit still 0).
    """
    site = root / "site"
    write_page_json(site, title="Roso Games opetuspelit ja demot",
                    description="Selaimessa pelattavat opetuspelit ja demot.")

    game = site / "games" / "3-fysiikkapallo"
    write_page_json(
        game,
        title="Fysiikkapallo",
        description="Kurssin Pelisuunnittelu ja prototyypittäminen opetuspeli.",
        courseName="Pelisuunnittelu ja prototyypittäminen",
        courseUrl="https://www.rosogames.fi/lms/3-pelisuunnittelu-ja-prototyypittaminen/",
    )
    for slug in ("versio-1", "versio-2", "versio-3", "versio-kotitehtavat"):
        write_page_json(
            game / slug,
            title=f"Fysiikkapallo ({slug})",
            description=f"Vaihe {slug}.",
            source="https://github.com/RosoTuotanto/RG-Learning-Materials",
            lessons=[{
                "title": "Fysiikan perusteet",
                "url": "https://www.rosogames.fi/lms/3-pelisuunnittelu-ja-prototyypittaminen/lessons/fysiikan-perusteet/",
            }],
            width=640,
            height=960,
        )
    make_app_build(game / "versio-2" / "app", "fysiikka")

    demo = site / "demos" / "shader-demo"
    write_page_json(
        demo,
        title="Varjostin-demo",
        description="Varjostinkokeilu.",
        source="https://github.com/RosoTuotanto/RG-Learning-Materials/tree/main/solar2d-projects/demos/shader-demo",
    )


class ValidTreeTests(unittest.TestCase):
    def setUp(self):
        self._tmp = tempfile.TemporaryDirectory()
        self.root = Path(self._tmp.name)
        make_valid_tree(self.root)
        self.site = self.root / "site"

    def tearDown(self):
        self._tmp.cleanup()

    def _read(self, *parts: str) -> str:
        return (self.site.joinpath(*parts)).read_text(encoding="utf-8")

    def test_all_pages_generated_and_no_unreplaced_placeholders(self):
        report = build_website.run(self.site)

        self.assertEqual(report.page_failures, [])
        self.assertEqual(report.exit_code, 0)

        expected = [
            ("index.html",),
            ("404.html",),
            ("sitemap.xml",),
            ("robots.txt",),
            ("games", "3-fysiikkapallo", "index.html"),
            ("games", "3-fysiikkapallo", "versio-1", "index.html"),
            ("games", "3-fysiikkapallo", "versio-2", "index.html"),
            ("games", "3-fysiikkapallo", "versio-3", "index.html"),
            ("games", "3-fysiikkapallo", "versio-kotitehtavat", "index.html"),
            ("demos", "shader-demo", "index.html"),
        ]
        self.assertEqual(report.pages_generated, len(expected))
        for parts in expected:
            html = self._read(*parts)
            self.assertNotIn("{{", html, f"unreplaced placeholder in {parts}")
            self.assertNotIn("}}", html, f"unreplaced placeholder in {parts}")

    def test_landing_lists_games_and_demos_and_headings(self):
        build_website.run(self.site)
        landing = self._read("index.html")
        self.assertIn("Roso Games opetuspelit ja demot", landing)
        self.assertIn(">Opetuspelit<", landing)
        self.assertIn(">Demot ja konseptit<", landing)
        self.assertIn('href="games/3-fysiikkapallo/"', landing)
        self.assertIn('href="demos/shader-demo/"', landing)
        # Hero branding + rosogames link.
        self.assertIn("assets/roso-games-hero.svg", landing)
        self.assertIn("https://www.rosogames.fi", landing)
        # English notice is a distinct box above the title, carrying the flags.
        notice = landing.find("lang-notice")
        self.assertNotEqual(notice, -1)
        self.assertLess(notice, landing.find("<h1>"))
        self.assertIn("assets/flags/us.svg", landing)
        self.assertIn("assets/flags/gb.svg", landing)
        # Divider sits between the hero and the Opetuspelit section.
        hr = landing.find('<hr class="section-divider">')
        self.assertNotEqual(hr, -1)
        self.assertLess(landing.find("<h1>"), hr)
        self.assertLess(hr, landing.find(">Opetuspelit<"))

    def test_breadcrumb_category_and_sibling_dropdowns(self):
        build_website.run(self.site)

        version = self._read("games", "3-fysiikkapallo", "versio-2", "index.html")
        # Home crumb resolves to the site root from three levels down.
        self.assertIn('href="../../../"', version)
        # Cascading Peli/Demo category crumb, with both category toggles.
        self.assertIn("crumb-category", version)
        self.assertIn("crumb-cat-menu", version)
        self.assertIn('class="cat-toggle" aria-expanded="true">Peli', version)
        self.assertIn('class="cat-toggle" aria-expanded="false">Demo', version)
        # Category lists both the game and the demo.
        self.assertIn('href="../../../games/3-fysiikkapallo/"', version)
        self.assertIn('href="../../../demos/shader-demo/"', version)
        # Versions dropdown lists every sibling version with Finnish labels.
        self.assertIn('href="../../../games/3-fysiikkapallo/versio-1/"', version)
        self.assertIn('href="../../../games/3-fysiikkapallo/versio-kotitehtavat/"', version)
        self.assertIn("Kotitehtävät", version)
        self.assertIn("Versio 1", version)

    def test_version_page_shape(self):
        build_website.run(self.site)
        version = self._read("games", "3-fysiikkapallo", "versio-2", "index.html")
        # Composed title (game name prefix, lowercase "versio").
        self.assertIn("<title>Fysiikkapallo - versio 2</title>", version)
        self.assertIn("<h1>Fysiikkapallo - versio 2</h1>", version)
        # Iframe loads the sibling build at the page.json dimensions.
        self.assertIn('src="./app/index.html"', version)
        self.assertIn('width="640"', version)
        self.assertIn('height="960"', version)
        # Lesson name is a link opening in a new tab.
        self.assertIn(
            'Oppitunti: <a href="https://www.rosogames.fi/lms/3-pelisuunnittelu-ja-prototyypittaminen/lessons/fysiikan-perusteet/" '
            'target="_blank" rel="noopener">Fysiikan perusteet</a>',
            version,
        )
        # Source: plain "Lähdekoodi:" label, the GitHub logo image is the link.
        self.assertIn('Lähdekoodi: <a class="source-link"', version)
        self.assertIn("assets/github-lockup-white.svg", version)
        # No description/lead paragraph on version pages.
        self.assertNotIn('class="lead"', version)

    def test_split_lesson_version_lists_every_part(self):
        write_page_json(
            self.site / "games" / "3-fysiikkapallo" / "versio-3",
            title="Fysiikkapallo (versio-3)",
            description="Vaihe 3.",
            lessons=[
                {"title": "Osa 1", "url": "https://example.com/osa-1/"},
                {"title": "Osa 2", "url": "https://example.com/osa-2/"},
            ],
        )
        build_website.run(self.site)
        version = self._read("games", "3-fysiikkapallo", "versio-3", "index.html")
        self.assertIn(
            'Oppitunnit: <a href="https://example.com/osa-1/" target="_blank" rel="noopener">Osa 1</a>, '
            '<a href="https://example.com/osa-2/" target="_blank" rel="noopener">Osa 2</a>',
            version,
        )

    def test_game_page_hero(self):
        build_website.run(self.site)
        game = self._read("games", "3-fysiikkapallo", "index.html")
        self.assertIn("<title>Fysiikkapallo</title>", game)
        # Course-link description built from courseName/courseUrl.
        self.assertIn(
            'Kurssin <a href="https://www.rosogames.fi/lms/3-pelisuunnittelu-ja-prototyypittaminen/" '
            'target="_blank" rel="noopener">Pelisuunnittelu ja prototyypittäminen</a> opetuspeli.',
            game,
        )
        # Landscape screenshot placeholder in the hero.
        self.assertIn('src="../../assets/screenshots/3-fysiikkapallo.png"', game)
        self.assertIn("hero-shot", game)

    def test_prev_next_at_chain_edges(self):
        build_website.run(self.site)

        first = self._read("games", "3-fysiikkapallo", "versio-1", "index.html")
        self.assertNotIn("Edellinen versio", first)
        self.assertIn("Seuraava versio", first)

        middle = self._read("games", "3-fysiikkapallo", "versio-2", "index.html")
        self.assertIn("Edellinen versio", middle)
        self.assertIn("Seuraava versio", middle)

        last = self._read("games", "3-fysiikkapallo", "versio-kotitehtavat", "index.html")
        self.assertIn("Edellinen versio", last)
        self.assertNotIn("Seuraava versio", last)

    def test_demo_page_shape(self):
        build_website.run(self.site)

        demo = self._read("demos", "shader-demo", "index.html")
        self.assertIn("<title>Demo - Varjostin-demo</title>", demo)
        self.assertIn("<h1>Demo - Varjostin-demo</h1>", demo)
        # Demos keep their description and gain the GitHub logo on the source link.
        self.assertIn('class="lead"', demo)
        self.assertIn("assets/github-lockup-white.svg", demo)
        self.assertIn('src="./app/index.html"', demo)
        # Demos are not a sequence.
        self.assertNotIn("Edellinen versio", demo)
        self.assertNotIn("Seuraava versio", demo)
        # Demo breadcrumb: Demo category expanded, sibling demo dropdown.
        self.assertIn('class="cat-toggle" aria-expanded="true">Demo', demo)
        self.assertIn('href="../../demos/shader-demo/"', demo)

    def test_favicon_and_shell(self):
        build_website.run(self.site)
        version = self._read("games", "3-fysiikkapallo", "versio-2", "index.html")
        self.assertIn('href="../../../favicon.ico"', version)
        self.assertIn('href="../../../favicon.svg"', version)
        self.assertIn('href="../../../apple-touch-icon.png"', version)
        self.assertIn('href="../../../site.webmanifest"', version)
        # Distinct header band with logo-only brand (no "Roso Games" text).
        self.assertIn('class="site-header"', version)
        self.assertIn('class="brand-mark"', version)
        self.assertNotIn("brand-name", version)

    def test_footer_on_every_page(self):
        build_website.run(self.site)
        for parts in (("index.html",), ("404.html",),
                      ("games", "3-fysiikkapallo", "versio-1", "index.html")):
            html = self._read(*parts)
            self.assertIn("site-footer", html)
            self.assertIn("&copy; 2026", html)
            self.assertIn("https://www.rosogames.fi", html)
            self.assertIn("Roso Games", html)
            self.assertIn("https://erantanen.com", html)
            self.assertIn("Eetu Rantanen", html)

    def test_404_page(self):
        build_website.run(self.site)
        page = self._read("404.html")
        self.assertIn("error-page", page)
        self.assertIn(">404<", page)
        self.assertIn("Sivua ei löytynyt", page)
        # 404 is excluded from indexing and carries no canonical/JSON-LD.
        self.assertIn('content="noindex, follow"', page)
        self.assertNotIn("canonical", page)
        self.assertNotIn("application/ld+json", page)
        # No breadcrumb placeholder is left behind.
        self.assertNotIn("{{", page)

    def test_seo_metadata_and_sitemap(self):
        report = build_website.run(self.site)
        self.assertEqual(report.exit_code, 0)

        version = self._read("games", "3-fysiikkapallo", "versio-2", "index.html")
        self.assertIn('<link rel="canonical" href="https://', version)
        self.assertIn('games/3-fysiikkapallo/versio-2/"', version)
        self.assertIn('content="index, follow"', version)
        self.assertIn('property="og:type" content="website"', version)
        self.assertIn('property="og:image"', version)
        self.assertIn('assets/og-image.png', version)
        self.assertIn('name="twitter:card" content="summary_large_image"', version)
        self.assertIn('name="author" content="Eetu Rantanen"', version)

        # JSON-LD only on the landing page.
        landing = self._read("index.html")
        self.assertIn("application/ld+json", landing)
        self.assertNotIn("application/ld+json", version)

        # robots.txt links the sitemap; sitemap lists indexable pages, not 404.
        robots = self._read("robots.txt")
        self.assertIn("Sitemap: https://", robots)
        sitemap = self._read("sitemap.xml")
        self.assertIn("<loc>https://", sitemap)
        self.assertIn("games/3-fysiikkapallo/versio-2/</loc>", sitemap)
        self.assertNotIn("404.html", sitemap)

    def test_missing_apps_are_warnings_not_failures(self):
        report = build_website.run(self.site)

        self.assertEqual(report.exit_code, 0)
        self.assertEqual(report.patch_failures, [])
        missing = {rel for rel, _ in report.missing_apps}
        self.assertIn("games/3-fysiikkapallo/versio-1", missing)
        self.assertIn("demos/shader-demo", missing)
        self.assertNotIn("games/3-fysiikkapallo/versio-2", missing)

    def test_synthetic_build_patched(self):
        report = build_website.run(self.site)

        statuses = dict(report.app_statuses)
        self.assertEqual(statuses["games/3-fysiikkapallo/versio-2"], build_website.PATCHED)

        js = zipfile.ZipFile(
            self.site / "games" / "3-fysiikkapallo" / "versio-2" / "app" / "fysiikka.bin"
        ).read("fysiikka.js").decode("utf-8")
        self.assertNotIn("registerFocusEventCallback", js)

        html = self._read("games", "3-fysiikkapallo", "versio-2", "app", "index.html")
        self.assertIn("statusElement.textContent", html)

    def test_rerun_is_byte_idempotent(self):
        build_website.run(self.site)
        snapshot = {
            path: path.read_bytes()
            for path in self.site.rglob("*")
            if path.is_file()
        }

        second = build_website.run(self.site)
        self.assertEqual(second.exit_code, 0)
        # Second run must not re-apply any patch.
        for _, status in second.app_statuses:
            self.assertNotEqual(status, build_website.PATCHED)

        after = {
            path: path.read_bytes()
            for path in self.site.rglob("*")
            if path.is_file()
        }
        self.assertEqual(snapshot.keys(), after.keys())
        for path, data in snapshot.items():
            self.assertEqual(data, after[path], f"{path} changed on re-run")


class FailureTreeTests(unittest.TestCase):
    def test_missing_and_invalid_page_json_fail_but_rest_generate(self):
        with tempfile.TemporaryDirectory() as tmp:
            site = Path(tmp) / "site"
            write_page_json(site, title="Etusivu", description="Kaikki pelit.")

            game = site / "games" / "2-nopeustesteri"
            write_page_json(game, title="Nopeustesteri", description="Reaktiopeli.")
            # Valid version.
            write_page_json(game / "versio-1", title="Nopeustesteri v1", description="Ensimmainen vaihe.")
            # Missing page.json (folder exists, matches versio- prefix).
            (game / "versio-2").mkdir(parents=True)
            # Invalid JSON.
            (game / "versio-3").mkdir(parents=True)
            (game / "versio-3" / "page.json").write_text("{ not valid json", encoding="utf-8")

            report = build_website.run(site)

            self.assertEqual(report.exit_code, 1)
            failed = {rel for rel, _ in report.page_failures}
            self.assertIn("games/2-nopeustesteri/versio-2/index.html", failed)
            self.assertIn("games/2-nopeustesteri/versio-3/index.html", failed)

            # The valid pages were still generated.
            self.assertTrue((site / "index.html").exists())
            self.assertTrue((game / "index.html").exists())
            self.assertTrue((game / "versio-1" / "index.html").exists())
            # Failed version pages were not written.
            self.assertFalse((game / "versio-2" / "index.html").exists())
            self.assertFalse((game / "versio-3" / "index.html").exists())

    def test_missing_required_key_fails(self):
        with tempfile.TemporaryDirectory() as tmp:
            site = Path(tmp) / "site"
            write_page_json(site, title="Etusivu", description="Kaikki pelit.")
            game = site / "games" / "4-pokeri"
            # description missing.
            write_page_json(game, title="Pokeri")
            write_page_json(game / "versio-1", title="Pokeri v1", description="Vaihe 1.")

            report = build_website.run(site)

            self.assertEqual(report.exit_code, 1)
            failed = {rel for rel, _ in report.page_failures}
            self.assertIn("games/4-pokeri/index.html", failed)
            # The version page under the failed game still generates.
            self.assertTrue((game / "versio-1" / "index.html").exists())


class EscapingTests(unittest.TestCase):
    """Escaping is the load-bearing safety property; guard both HTML contexts."""

    def test_hostile_input_is_escaped_in_text_and_attributes(self):
        with tempfile.TemporaryDirectory() as tmp:
            site = Path(tmp) / "site"
            write_page_json(site, title="Etusivu", description="Kaikki pelit.")
            game = site / "games" / "6-platformer"
            write_page_json(game, title='Peli & <x>', description="Platformer.")
            write_page_json(
                game / "versio-1",
                title='Kentät & <ääni> "test"',
                description='Kuvaus & <b>bold</b> "quote"',
                lessons=[{"title": 'Ääni & <tag> "x"', "url": "https://example.com/l?a=1&b=<2>"}],
                source="https://example.com/x?a=1&b=<2>",
            )

            report = build_website.run(site)
            self.assertEqual(report.exit_code, 0)

            html = (game / "versio-1" / "index.html").read_text(encoding="utf-8")

            # The composed h1 carries the escaped GAME title (display prefix).
            self.assertIn("<h1>Peli &amp; &lt;x&gt; - versio 1</h1>", html)
            # Meta description (version description) escaped in attribute context.
            self.assertIn('content="Kuvaus &amp; &lt;b&gt;bold&lt;/b&gt; &quot;quote&quot;"', html)
            # Lesson title and url escaped.
            self.assertIn("Oppitunti: <a href=\"https://example.com/l?a=1&amp;b=&lt;2&gt;\"", html)
            self.assertIn("Ääni &amp; &lt;tag&gt; &quot;x&quot;</a>", html)
            # Source href escaped.
            self.assertIn('href="https://example.com/x?a=1&amp;b=&lt;2&gt;"', html)
            # Breadcrumb (game title) escaped in the dropdown.
            self.assertIn("Peli &amp; &lt;x&gt;", html)

            # The raw, unescaped injections must not appear anywhere.
            self.assertNotIn("<ääni>", html)
            self.assertNotIn("<b>bold</b>", html)
            self.assertNotIn("<tag>", html)
            self.assertNotIn("?a=1&b=<2>", html)
            self.assertNotIn("Peli & <x>", html)

            # Nordic characters are preserved, never stripped.
            self.assertIn("Ääni", html)


class DiscoveryTests(unittest.TestCase):
    def test_stray_directory_is_warned_and_assets_is_skipped(self):
        with tempfile.TemporaryDirectory() as tmp:
            site = Path(tmp) / "site"
            write_page_json(site, title="Etusivu", description="Kaikki pelit.")
            game = site / "games" / "3-fysiikkapallo"
            write_page_json(game, title="Fysiikkapallo", description="Pallofysiikka.")
            write_page_json(game / "versio-1", title="Vaihe 1", description="Ensimmainen.")
            # Shared assets dir: skipped silently, never a stray or a demo.
            (site / "assets").mkdir(parents=True)
            (site / "assets" / "logo.svg").write_text("<svg/>", encoding="utf-8")
            # Stray: a site-root folder outside assets/, games/ and demos/.
            stray = site / "random-notes"
            stray.mkdir(parents=True)
            (stray / "notes.txt").write_text("loose", encoding="utf-8")

            report = build_website.run(site)

            self.assertEqual(report.exit_code, 0)
            self.assertIn("random-notes", report.stray_dirs)
            self.assertNotIn("assets", report.stray_dirs)
            self.assertNotIn("games", report.stray_dirs)
            self.assertEqual(report.page_failures, [])
            self.assertFalse((site / "random-notes" / "index.html").exists())
            self.assertFalse((site / "assets" / "index.html").exists())
            landing = (site / "index.html").read_text(encoding="utf-8")
            self.assertNotIn('href="random-notes/"', landing)

    def test_game_folder_without_page_json_still_fails(self):
        with tempfile.TemporaryDirectory() as tmp:
            site = Path(tmp) / "site"
            write_page_json(site, title="Etusivu", description="Kaikki pelit.")
            # A game folder that lost its page.json but keeps versio-* subfolders.
            broken = site / "games" / "9-broken"
            write_page_json(broken / "versio-1", title="Vaihe 1", description="Ensimmainen.")

            report = build_website.run(site)

            self.assertEqual(report.exit_code, 1)
            self.assertNotIn("9-broken", report.stray_dirs)
            failed = {rel for rel, _ in report.page_failures}
            self.assertIn("games/9-broken/index.html", failed)
            # The version under the failed game still generates.
            self.assertTrue((broken / "versio-1" / "index.html").exists())


HOSTILE_LINE = 'print( "</script><b>tag</b> & more" )'


def _main_lua(changes: dict[int, str]) -> list[str]:
    lines = [f"local value{index} = {index}" for index in range(1, 31)]
    for line_no, text in changes.items():
        lines[line_no - 1] = text
    return lines


def _write_source(version_dir: Path, files: dict[str, bytes | list[str]]) -> None:
    for rel, content in files.items():
        target = version_dir / rel
        target.parent.mkdir(parents=True, exist_ok=True)
        if isinstance(content, list):
            target.write_text("\n".join(content) + "\n", encoding="utf-8")
        else:
            target.write_bytes(content)


V1_LINES = _main_lua({2: HOSTILE_LINE, 25: "local value25 = 250"})
V2_LINES = _main_lua({2: HOSTILE_LINE, 15: "local value15 = 150", 25: "local value25 = 250"})


def make_diff_tree(root: Path) -> None:
    """The valid tree plus solar2d-projects/games/ holding versio-0..2 and kotitehtavat.

    site/ has versio-3 with no source, so it gets no diff page.
    """
    make_valid_tree(root)
    game_src = root / "solar2d-projects" / "games" / "3-fysiikkapallo"
    _write_source(game_src / "versio-0", {
        "main.lua": _main_lua({}),
        "images/ball.png": b"old-ball",
    })
    _write_source(game_src / "versio-1", {
        "main.lua": V1_LINES,
        "images/ball.png": b"new-ball",
        "äänet/hyppy.wav": b"RIFF-jump",
    })
    _write_source(game_src / "versio-2", {
        "main.lua": V2_LINES,
        "images/ball.png": b"new-ball",
        "äänet/hyppy.wav": b"RIFF-jump",
    })
    _write_source(game_src / "versio-kotitehtavat", {
        "main.lua": V2_LINES,
        "images/ball.png": b"new-ball",
        "äänet/hyppy.wav": b"RIFF-jump",
        "maps/level.tmx": ["<map>", "</map>"],
    })


class DiffPageTests(unittest.TestCase):
    def setUp(self):
        self._tmp = tempfile.TemporaryDirectory()
        self.root = Path(self._tmp.name)
        make_diff_tree(self.root)
        self.site = self.root / "site"
        self.game = self.site / "games" / "3-fysiikkapallo"

    def tearDown(self):
        self._tmp.cleanup()

    def _diff_page(self, slug: str) -> str:
        return (self.game / slug / "muutokset" / "index.html").read_text(encoding="utf-8")

    def test_diff_pages_and_meta_lines(self):
        report = build_website.run(self.site)
        self.assertEqual(report.exit_code, 0)
        self.assertEqual(report.diff_pages, 3)

        for slug in ("versio-1", "versio-2", "versio-kotitehtavat"):
            self.assertTrue((self.game / slug / "muutokset" / "index.html").exists(), slug)
        self.assertFalse((self.game / "versio-3" / "muutokset").exists())
        self.assertEqual(list(self.site.rglob("versio-0")), [])

        expected = {
            "versio-1": "versio 0 -&gt; versio 1",
            "versio-2": "versio 1 -&gt; versio 2",
            "versio-kotitehtavat": "versio 2 -&gt; kotitehtävät",
        }
        for slug, text in expected.items():
            page = (self.game / slug / "index.html").read_text(encoding="utf-8")
            line = f'  <p class="changes">Muutokset: <a href="./muutokset/">{text}</a></p>\n</div>'
            self.assertIn(line, page, slug)

        orphan = (self.game / "versio-3" / "index.html").read_text(encoding="utf-8")
        self.assertNotIn('class="changes"', orphan)
        self.assertTrue(any("versio-3" in warning for warning in report.diff_warnings))
        self.assertFalse(any("versio-1" in warning for warning in report.diff_warnings))

    def test_missing_games_root_is_a_warning(self):
        with tempfile.TemporaryDirectory() as tmp:
            make_valid_tree(Path(tmp))
            site = Path(tmp) / "site"
            report = build_website.run(site)

            self.assertEqual(report.exit_code, 0)
            self.assertEqual(report.diff_pages, 0)
            self.assertEqual(len(report.diff_warnings), 1)
            self.assertEqual(list(site.rglob("muutokset")), [])

    def test_diff_page_seo_and_sitemap(self):
        build_website.run(self.site)
        page = self._diff_page("versio-2")

        self.assertIn('<meta name="robots" content="noindex, follow">', page)
        self.assertNotIn('rel="canonical"', page)
        self.assertIn('property="og:image"', page)
        sitemap = (self.site / "sitemap.xml").read_text(encoding="utf-8")
        self.assertNotIn("muutokset", sitemap)

    def test_diff_page_shape_breadcrumb_and_step_nav(self):
        build_website.run(self.site)
        first = self._diff_page("versio-1")

        self.assertIn("<h1>Fysiikkapallo - versio 1: muutokset</h1>", first)
        self.assertIn('<p class="diff-summary">Versio 0 -&gt; versio 1 | 3 tiedostoa, +', first)
        self.assertIn('<a href="../">Takaisin: Versio 1</a>', first)
        self.assertIn('<div class="diff-toggle" role="group" aria-label="Näkymä" hidden>', first)
        self.assertIn('<div class="diff-files" data-view="unified">', first)
        self.assertIn('<li class="crumb"><a href="../../../../games/3-fysiikkapallo/versio-1/">Versio 1</a></li>', first)
        self.assertIn('<li class="crumb current">Muutokset</li>', first)
        self.assertNotIn('class="nav-prev"', first)
        self.assertIn('<a class="nav-next" href="../../../../games/3-fysiikkapallo/versio-2/muutokset/">', first)

        middle = self._diff_page("versio-2")
        self.assertIn('<a class="nav-prev" href="../../../../games/3-fysiikkapallo/versio-1/muutokset/">', middle)
        self.assertIn('<a class="nav-next" href="../../../../games/3-fysiikkapallo/versio-kotitehtavat/muutokset/">', middle)

        last = self._diff_page("versio-kotitehtavat")
        self.assertIn("<h1>Fysiikkapallo - kotitehtävät: muutokset</h1>", last)
        self.assertIn('<a class="nav-prev" href="../../../../games/3-fysiikkapallo/versio-2/muutokset/">', last)
        self.assertNotIn('class="nav-next"', last)
        self.assertIn("1 tiedosto, +2 -0", last)
        self.assertIn('<details class="diff-file" id="tiedosto-1" data-kind="map">', last)
        self.assertIn('<span class="diff-tag">kartta</span>', last)
        self.assertIn("Uusi tiedosto, 2 riviä.", last)

    def test_media_copied_and_stale_files_removed(self):
        media = self.game / "versio-1" / "muutokset" / "tiedostot"
        stale = media / "uusi" / "vanhentunut" / "pois.png"
        stale.parent.mkdir(parents=True)
        stale.write_bytes(b"stale")

        build_website.run(self.site)

        self.assertEqual((media / "vanha" / "images" / "ball.png").read_bytes(), b"old-ball")
        self.assertEqual((media / "uusi" / "images" / "ball.png").read_bytes(), b"new-ball")
        self.assertEqual((media / "uusi" / "äänet" / "hyppy.wav").read_bytes(), b"RIFF-jump")
        self.assertFalse(stale.exists())
        self.assertFalse(stale.parent.exists())

        page = self._diff_page("versio-1")
        self.assertIn('src="./tiedostot/vanha/images/ball.png"', page)
        self.assertIn('<figcaption>Versio 0</figcaption>', page)
        self.assertIn('<audio class="diff-audio" controls preload="none" '
                      'src="./tiedostot/uusi/%C3%A4%C3%A4net/hyppy.wav"></audio>', page)
        self.assertIn('<span class="diff-path">äänet/hyppy.wav</span>', page)
        self.assertIn('data-kind="image" open>', page)
        self.assertIn('data-kind="audio" open>', page)

    def test_orphaned_diff_folder_removed(self):
        build_website.run(self.site)
        orphan = self.game / "versio-1" / "muutokset"
        self.assertTrue(orphan.is_dir())
        unrelated = self.game / "versio-1" / "notes.txt"
        unrelated.write_text("keep", encoding="utf-8")

        shutil.rmtree(self.root / "solar2d-projects" / "games" / "3-fysiikkapallo" / "versio-0")
        report = build_website.run(self.site)

        self.assertFalse(orphan.exists())
        self.assertEqual(report.diff_orphans_removed, 1)
        self.assertEqual(report.diff_pages, 2)
        self.assertTrue(unrelated.exists())
        self.assertTrue((self.game / "versio-1" / "index.html").exists())
        self.assertTrue((self.game / "versio-2" / "muutokset" / "index.html").exists())

    def test_code_escaped_in_tables_and_json(self):
        build_website.run(self.site)
        payload_re = re.compile(r'<script type="application/json" class="diff-source">(.*?)</script>', re.S)

        first = self._diff_page("versio-1")
        self.assertIn("&lt;/script&gt;&lt;b&gt;tag&lt;/b&gt; &amp; more", first)
        self.assertNotIn("<b>tag", first)
        self.assertIn('<td class="diff-num diff-add" data-line="2"></td>'
                      '<td class="diff-sign diff-add" data-sign="+"></td>', first)

        for slug, lines in (("versio-1", V1_LINES), ("versio-2", V2_LINES)):
            payloads = payload_re.findall(self._diff_page(slug))
            self.assertEqual(len(payloads), 1, slug)
            self.assertNotIn("<", payloads[0])
            self.assertNotIn(">", payloads[0])
            self.assertNotIn("&", payloads[0])
            self.assertEqual(json.loads(payloads[0]), lines)

        second = self._diff_page("versio-2")
        self.assertIn('<button type="button" class="diff-expand">Näytä 11 piilotettua riviä</button>', second)
        self.assertEqual(second.count('data-gap="f1-g0"'), 2)

    def test_rerun_is_byte_identical(self):
        build_website.run(self.site)
        media_file = self.game / "versio-1" / "muutokset" / "tiedostot" / "uusi" / "images" / "ball.png"
        mtime = media_file.stat().st_mtime_ns
        snapshot = {path: path.read_bytes() for path in self.site.rglob("*") if path.is_file()}

        build_website.run(self.site)

        after = {path: path.read_bytes() for path in self.site.rglob("*") if path.is_file()}
        self.assertEqual(snapshot, after)
        self.assertEqual(media_file.stat().st_mtime_ns, mtime)


if __name__ == "__main__":
    unittest.main(verbosity=2)
