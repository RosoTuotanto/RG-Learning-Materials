#!/usr/bin/env python3
"""Neo-brutalist Open Graph share-image generator for the site/ viewer site.

Renders one 1200x630 share image per page type into site/<dir>/: the frontpage
card, one card per learning game ("Peli > <title>") and one per demo
("Demo > <title>"). A game's card is shared by that game's page and all of its
version pages, so the slug never changes across versions.

Card set, output location, slug wording, colours and layout are all driven by
tools/web-src/og-images.json. build_website.py reads the same config (via the
naming helpers here) to point each page's og:image at the right file.

Usage:
    python tools/generate_og_images.py            Generate into ../site.
    python tools/generate_og_images.py PATH       Generate into PATH/ (tests).

Pillow is required only for generation; the naming helpers import nothing heavy,
so build_website.py can import this module without pulling Pillow in.
"""

import json
import sys
from pathlib import Path

_TOOLS_DIR = Path(__file__).resolve().parent
_REPO_ROOT = _TOOLS_DIR.parent
if str(_TOOLS_DIR) not in sys.path:
    sys.path.insert(0, str(_TOOLS_DIR))

WEB_SRC_DIR = _TOOLS_DIR / "web-src"
CONFIG_NAME = "og-images.json"
DEFAULT_SITE_ROOT = _REPO_ROOT / "site"


# ------------------------------------------------------------------------------
# Config and naming (no Pillow; safe for build_website.py to import)

def load_config(web_src_dir: Path = WEB_SRC_DIR) -> dict:
    return json.loads((web_src_dir / CONFIG_NAME).read_text(encoding="utf-8"))


def _cards(cfg: dict) -> dict:
    return cfg.get("cards", {})


def frontpage_filename(cfg: dict) -> str:
    return _cards(cfg).get("frontpage", {}).get("filename", "etusivu.png")


def game_filename(cfg: dict, slug: str) -> str:
    template = _cards(cfg).get("game", {}).get("filenameTemplate", "peli-{slug}.png")
    return template.format(slug=slug)


def demo_filename(cfg: dict, slug: str) -> str:
    template = _cards(cfg).get("demo", {}).get("filenameTemplate", "demo-{slug}.png")
    return template.format(slug=slug)


def og_relpath(cfg: dict, filename: str) -> str:
    """Site-root-relative path (also the URL path) for a generated card."""
    return f'{cfg.get("dir", "assets/og-images").rstrip("/")}/{filename}'


def resolve_og_image(cfg: dict, site_root: Path, filename: str) -> str:
    """Return the card's relpath if it exists under site_root, else the
    fallback card if that exists, else "" so the caller keeps its own default."""
    for candidate in (filename, cfg.get("fallback", "")):
        if candidate:
            rel = og_relpath(cfg, candidate)
            if (site_root / rel).is_file():
                return rel
    return ""


def frontpage_slug(cfg: dict) -> str:
    return _cards(cfg).get("frontpage", {}).get("slug", "Etusivu")


def game_slug(cfg: dict, title: str) -> str:
    template = _cards(cfg).get("game", {}).get("slugTemplate", "Peli > {title}")
    return template.format(title=title)


def demo_slug(cfg: dict, title: str) -> str:
    template = _cards(cfg).get("demo", {}).get("slugTemplate", "Demo > {title}")
    return template.format(title=title)


# ------------------------------------------------------------------------------
# Rendering (Pillow imported lazily)

def _hex(value: str) -> tuple[int, int, int]:
    value = value.lstrip("#")
    return tuple(int(value[i:i + 2], 16) for i in (0, 2, 4))


def _font(path: Path, size: int, weight: str):
    from PIL import ImageFont
    font = ImageFont.truetype(str(path), size)
    font.set_variation_by_name(weight)
    return font


def _text_width(font, text: str, tracking: float) -> float:
    """Advance width of text with per-character tracking (CSS letter-spacing),
    summing glyph advances so it stays consistent with the tracked drawing path."""
    return sum(font.getlength(ch) for ch in text) + tracking * len(text)


def _wrap(words: list[str], font, max_width: float, tracking: float) -> list[list[str]]:
    """Greedy word wrap; returns lines as lists of words (never splits a word)."""
    lines: list[list[str]] = []
    current: list[str] = []
    for word in words:
        trial = " ".join(current + [word])
        if current and _text_width(font, trial, tracking) > max_width:
            lines.append(current)
            current = [word]
        else:
            current.append(word)
    if current:
        lines.append(current)
    return lines


def _fit_heading(text: str, font_path: Path, weight: str, max_width: float,
                 max_height: float, size_hi: int, size_lo: int, line_height: float,
                 letter_spacing_em: float):
    """Largest size whose wrapped, uppercased heading fits the box. Mirrors the
    site h1: line advance is line_height * font size (CSS line-height), and each
    glyph carries letter_spacing_em * font size of tracking (CSS letter-spacing)."""
    words = text.upper().split()
    for size in range(size_hi, size_lo - 1, -2):
        font = _font(font_path, size, weight)
        tracking = letter_spacing_em * size
        lines = _wrap(words, font, max_width, tracking)
        if any(_text_width(font, " ".join(line), tracking) > max_width for line in lines):
            continue
        line_h = int(round(size * line_height))
        if line_h * len(lines) <= max_height:
            return font, lines, line_h, tracking
    font = _font(font_path, size_lo, weight)
    tracking = letter_spacing_em * size_lo
    lines = _wrap(words, font, max_width, tracking)
    return font, lines, int(round(size_lo * line_height)), tracking


def _draw_tracked(draw, text, font, x, y, fill, tracking):
    """Draw text glyph by glyph, advancing by tracking after each; return end x."""
    for ch in text:
        draw.text((x, y), ch, font=font, fill=fill)
        x += font.getlength(ch) + tracking
    return x


def _draw_heading(draw, lines, font, line_h, box, colors, highlight, tracking):
    """Draw wrapped heading; paint a filled accent block behind the highlight word."""
    x0, y0 = box
    highlight_up = highlight.upper() if highlight else None
    ascent, descent = font.getmetrics()
    space_w = font.getlength(" ") + tracking
    y = y0
    for line in lines:
        x = x0
        for i, word in enumerate(line):
            if i > 0:
                x += space_w
            if highlight_up and word.strip(".,:;!?").upper() == highlight_up:
                pad_x, pad_y = 6, 2
                w = _text_width(font, word, tracking)
                draw.rectangle(
                    [x - pad_x, y - pad_y, x + w + pad_x, y + ascent + descent + pad_y],
                    fill=colors["accent"],
                )
                _draw_tracked(draw, word, font, x, y, colors["accentInk"], tracking)
                x += w
            else:
                x = _draw_tracked(draw, word, font, x, y, colors["text"], tracking)
        y += line_h


def _draw_slug(draw, slug, font, anchor, colors, underline_h, underline_gap, tracking):
    """Draw the slug bottom-left; segments in accent, ' > ' separators in muted,
    with an accent underline bar. anchor is the bottom-left (x, y)."""
    x0, bottom = anchor
    ascent, descent = font.getmetrics()
    text_h = ascent + descent
    y = bottom - underline_h - underline_gap - text_h
    segments = [s.strip() for s in slug.split(">")]
    x = x0
    for i, seg in enumerate(segments):
        if i > 0:
            x = _draw_tracked(draw, " > ", font, x, y, colors["muted"], tracking)
        x = _draw_tracked(draw, seg.upper(), font, x, y, colors["accent"], tracking)
    draw.rectangle([x0, bottom - underline_h, x, bottom], fill=colors["accent"])


def render_card(cfg: dict, slug: str, out_path: Path) -> None:
    from PIL import Image, ImageDraw

    colors = {k: _hex(v) for k, v in cfg["colors"].items()}
    lay = cfg["layout"]
    W = cfg["canvas"]["width"]
    H = cfg["canvas"]["height"]
    font_path = (_REPO_ROOT / cfg["assets"]["font"]).resolve()
    logo_path = (_REPO_ROOT / cfg["assets"]["logo"]).resolve()

    img = Image.new("RGB", (W, H), colors["bg"])
    draw = ImageDraw.Draw(img)

    inset = lay["frameInset"]
    draw.rectangle(
        [inset, inset, W - inset - 1, H - inset - 1],
        outline=colors["line"], width=lay["frameWidth"],
    )

    pad = lay["padding"]
    content_l, content_t, content_r, content_b = pad, pad, W - pad, H - pad

    slug_min = lay.get("slugMinSize", lay["slugSize"])
    slug_measure = slug.replace(">", " > ").upper()
    slug_ls = lay.get("slugLetterSpacing", 0.0)
    slug_size = lay["slugSize"]
    slug_font = _font(font_path, slug_size, lay["slugWeight"])
    while (slug_size > slug_min
           and _text_width(slug_font, slug_measure, slug_ls * slug_size) > (content_r - content_l)):
        slug_size = max(slug_min, slug_size - 2)
        slug_font = _font(font_path, slug_size, lay["slugWeight"])
    slug_tracking = slug_ls * slug_size
    slug_ascent, slug_descent = slug_font.getmetrics()
    slug_block = slug_ascent + slug_descent + lay["slugUnderlineGap"] + lay["slugUnderlineHeight"]

    heading_bottom = content_b - slug_block - lay["slugGap"]
    logo_col_w = lay["logoColumnWidth"]
    head_w = content_r - content_l - logo_col_w - lay["gutter"]
    head_h = heading_bottom - content_t

    font, lines, line_h, tracking = _fit_heading(
        cfg["heading"], font_path, lay["headingWeight"], head_w, head_h,
        lay["headingMaxSize"], lay["headingMinSize"], lay["headingLineSpacing"],
        lay.get("headingLetterSpacing", 0.0),
    )
    _draw_heading(draw, lines, font, line_h, (content_l, content_t), colors,
                  cfg.get("highlightWord"), tracking)

    logo = Image.open(logo_path).convert("RGBA")
    bbox = logo.getchannel("A").getbbox()
    if bbox:
        logo = logo.crop(bbox)
    scale = min(logo_col_w / logo.width, head_h / logo.height)
    logo = logo.resize((max(1, int(logo.width * scale)), max(1, int(logo.height * scale))),
                        Image.LANCZOS)
    logo_x = content_r - logo.width
    logo_y = content_t
    img.paste(logo, (logo_x, logo_y), logo)

    _draw_slug(draw, slug, slug_font, (content_l, content_b), colors,
               lay["slugUnderlineHeight"], lay["slugUnderlineGap"], slug_tracking)

    out_path.parent.mkdir(parents=True, exist_ok=True)
    img.save(out_path, "PNG")


# ------------------------------------------------------------------------------
# Generation

def generate(site_root: Path, cfg: dict | None = None) -> list[str]:
    """Render every card into site_root; return the list of relpaths written."""
    import build_website as bw

    cfg = cfg or load_config()
    site_root = Path(site_root)
    written: list[str] = []

    def emit(filename: str, slug: str) -> None:
        rel = og_relpath(cfg, filename)
        render_card(cfg, slug, site_root / rel)
        written.append(rel)

    emit(frontpage_filename(cfg), frontpage_slug(cfg))

    games, demos, _ = bw.discover(site_root)
    for gslug in games:
        data, _ = bw.load_page(site_root / bw.GAMES_DIRNAME / gslug / bw.PAGE_JSON)
        title = data["title"] if data else gslug
        emit(game_filename(cfg, gslug), game_slug(cfg, title))
    for dslug in demos:
        data, _ = bw.load_page(site_root / bw.DEMOS_DIRNAME / dslug / bw.PAGE_JSON)
        title = data["title"] if data else dslug
        emit(demo_filename(cfg, dslug), demo_slug(cfg, title))

    return written


def main(argv: list[str] | None = None) -> int:
    argv = sys.argv[1:] if argv is None else argv
    site_root = Path(argv[0]) if argv else DEFAULT_SITE_ROOT
    written = generate(site_root)
    print(f"OG image generator -> {site_root}")
    print("-" * 60)
    for rel in written:
        print(f"  wrote {rel}")
    print("-" * 60)
    print(f"Images generated: {len(written)}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
