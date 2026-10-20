#!/usr/bin/env python3
"""Tests for tools/generate_og_images.py and its build_website.py wiring.
Run: python3 tools/tests/test_generate_og_images.py"""

import json
import sys
import tempfile
import unittest
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(REPO_ROOT / "tools"))

import build_website
import generate_og_images as og

try:
    from PIL import Image  # noqa: F401
    HAVE_PIL = True
except ImportError:
    HAVE_PIL = False


def write_page_json(directory: Path, **fields) -> None:
    directory.mkdir(parents=True, exist_ok=True)
    (directory / "page.json").write_text(json.dumps(fields), encoding="utf-8")


def make_tree(root: Path) -> Path:
    site = root / "site"
    write_page_json(site, title="Etusivu", description="Kaikki pelit.")
    game = site / "games" / "4-pokeri"
    write_page_json(game, title="Pokeri", description="Korttipeli.")
    for slug in ("versio-1", "versio-2", "versio-kotitehtavat"):
        write_page_json(game / slug, title=f"Pokeri ({slug})", description=f"Vaihe {slug}.")
    write_page_json(site / "demos" / "feedback", title="Palaute ja game feel",
                    description="Palautedemo.")
    return site


class NamingTests(unittest.TestCase):
    def setUp(self):
        self.cfg = og.load_config()

    def test_filenames_follow_config_templates(self):
        self.assertEqual(og.frontpage_filename(self.cfg), "etusivu.png")
        self.assertEqual(og.game_filename(self.cfg, "4-pokeri"), "peli-4-pokeri.png")
        self.assertEqual(og.demo_filename(self.cfg, "feedback"), "demo-feedback.png")

    def test_slugs_follow_config_templates(self):
        self.assertEqual(og.frontpage_slug(self.cfg), "Etusivu")
        self.assertEqual(og.game_slug(self.cfg, "Pokeri"), "Peli > Pokeri")
        self.assertEqual(og.demo_slug(self.cfg, "Palaute ja game feel"),
                         "Demo > Palaute ja game feel")

    def test_relpath_is_under_configured_dir(self):
        self.assertEqual(og.og_relpath(self.cfg, "etusivu.png"),
                         "assets/og-images/etusivu.png")

    def test_resolve_falls_back_then_gives_up(self):
        with tempfile.TemporaryDirectory() as tmp:
            site = Path(tmp)
            (site / "assets" / "og-images").mkdir(parents=True)
            (site / "assets" / "og-images" / "etusivu.png").write_bytes(b"x")
            # A missing specific card falls back to the fallback card.
            self.assertEqual(
                og.resolve_og_image(self.cfg, site, "peli-4-pokeri.png"),
                "assets/og-images/etusivu.png",
            )
            # An existing specific card resolves to itself.
            self.assertEqual(
                og.resolve_og_image(self.cfg, site, "etusivu.png"),
                "assets/og-images/etusivu.png",
            )
            # Nothing present at all: empty string, so the caller keeps its default.
            (site / "assets" / "og-images" / "etusivu.png").unlink()
            self.assertEqual(og.resolve_og_image(self.cfg, site, "peli-4-pokeri.png"), "")


@unittest.skipUnless(HAVE_PIL, "Pillow required for rendering")
class RenderTests(unittest.TestCase):
    def test_generate_writes_one_card_per_page_type(self):
        with tempfile.TemporaryDirectory() as tmp:
            site = make_tree(Path(tmp))
            written = og.generate(site)

            self.assertIn("assets/og-images/etusivu.png", written)
            self.assertIn("assets/og-images/peli-4-pokeri.png", written)
            self.assertIn("assets/og-images/demo-feedback.png", written)
            # One frontpage + one game + one demo (versions do not get their own).
            self.assertEqual(len(written), 3)

            for rel in written:
                path = site / rel
                self.assertTrue(path.is_file(), rel)
                from PIL import Image
                with Image.open(path) as im:
                    self.assertEqual(im.size, (1200, 630))

    def test_build_website_points_pages_at_generated_cards(self):
        with tempfile.TemporaryDirectory() as tmp:
            site = make_tree(Path(tmp))
            og.generate(site)
            build_website.run(site)

            def read(*parts):
                return site.joinpath(*parts).read_text(encoding="utf-8")

            base = build_website.load_site_config()["baseUrl"]

            landing = read("index.html")
            self.assertIn(f'og:image" content="{base}assets/og-images/etusivu.png"', landing)

            game = read("games", "4-pokeri", "index.html")
            self.assertIn(f'og:image" content="{base}assets/og-images/peli-4-pokeri.png"', game)

            # Every version of a game shares that game's card.
            for slug in ("versio-1", "versio-2", "versio-kotitehtavat"):
                page = read("games", "4-pokeri", slug, "index.html")
                self.assertIn(
                    f'og:image" content="{base}assets/og-images/peli-4-pokeri.png"', page)

            demo = read("demos", "feedback", "index.html")
            self.assertIn(f'og:image" content="{base}assets/og-images/demo-feedback.png"', demo)

    def test_missing_card_falls_back_to_site_default(self):
        with tempfile.TemporaryDirectory() as tmp:
            site = make_tree(Path(tmp))
            # No og-images generated at all.
            build_website.run(site)
            default = build_website.load_site_config()["ogImage"]
            game = site.joinpath("games", "4-pokeri", "index.html").read_text(encoding="utf-8")
            self.assertIn(f'og:image" content="https://', game)
            self.assertIn(default, game)


if __name__ == "__main__":
    unittest.main(verbosity=2)
