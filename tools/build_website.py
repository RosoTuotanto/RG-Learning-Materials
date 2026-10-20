#!/usr/bin/env python3
"""Static site generator + patch orchestrator for the site/ GitHub Pages payload.

Generates the viewer index.html for the landing page, each learning game, each
game version, and each demo, generates a 404 page, then runs the HTML5 build
patcher over every app/ build under the site root.

Each version with a predecessor in the sibling solar2d-projects/games/ folder
also gets a noindex muutokset/ page diffing its source against that predecessor.

Games are the folders under site/games/ and demos the folders under site/demos/.
The assets/ folder holds shared images; any other site-root folder is a stray.

Usage:
    python tools/build_website.py            Build into ../site.
    python tools/build_website.py PATH       Build into PATH (mainly for tests).
"""

import json
import re
import shutil
import sys
from dataclasses import dataclass, field
from html import escape
from itertools import zip_longest
from pathlib import Path
from urllib.parse import quote

_TOOLS_DIR = Path(__file__).resolve().parent
if str(_TOOLS_DIR) not in sys.path:
    sys.path.insert(0, str(_TOOLS_DIR))

import html5_build_patcher as patcher
import generate_og_images as ogimg
import version_diff as vdiff

WEB_SRC_DIR = _TOOLS_DIR / "web-src"
DEFAULT_SITE_ROOT = _TOOLS_DIR.parent / "site"

PAGE_JSON = "page.json"
ASSETS_DIRNAME = "assets"
KOTITEHTAVAT = "versio-kotitehtavat"

GAMES_DIRNAME = "games"
DEMOS_DIRNAME = "demos"
PROJECTS_DIRNAME = "solar2d-projects"
DIFF_DIRNAME = "muutokset"
MEDIA_DIRNAME = "tiedostot"
OLD_MEDIA_DIRNAME = "vanha"
NEW_MEDIA_DIRNAME = "uusi"

DEFAULT_WIDTH = 960
DEFAULT_HEIGHT = 640

# App patch statuses, reported per version/demo folder.
MISSING = "MISSING"
PATCHED = "PATCHED"
ALREADY = "ALREADY"
FAILED = "FAILED"

# Relative-path prefix token, substituted last so links inside the breadcrumb
# and body resolve from the site root regardless of the page's depth.
BASE = "{{basePath}}"

_VERSION_RE = re.compile(r"versio-(\d+)$")


# ------------------------------------------------------------------------------
# Report

@dataclass
class BuildReport:
    pages_generated: int = 0
    page_failures: list[tuple[str, str]] = field(default_factory=list)
    app_statuses: list[tuple[str, str]] = field(default_factory=list)
    stray_dirs: list[str] = field(default_factory=list)
    diff_pages: int = 0
    diff_warnings: list[str] = field(default_factory=list)
    diff_orphans_removed: int = 0

    @property
    def patch_failures(self) -> list[tuple[str, str]]:
        return [(path, status) for path, status in self.app_statuses if status == FAILED]

    @property
    def missing_apps(self) -> list[tuple[str, str]]:
        return [(path, status) for path, status in self.app_statuses if status == MISSING]

    @property
    def exit_code(self) -> int:
        return 1 if (self.page_failures or self.patch_failures) else 0


# ------------------------------------------------------------------------------
# page.json loading and discovery

def load_page(path: Path) -> tuple[dict | None, str | None]:
    """Return (data, None) for a valid page.json, else (None, reason)."""
    if not path.exists():
        return None, f"{PAGE_JSON} not found"
    try:
        text = path.read_text(encoding="utf-8")
    except OSError as error:
        return None, f"cannot read {PAGE_JSON}: {error}"
    try:
        data = json.loads(text)
    except json.JSONDecodeError as error:
        return None, f"invalid JSON: {error}"
    if not isinstance(data, dict):
        return None, f"{PAGE_JSON} must be a JSON object"
    title = data.get("title")
    description = data.get("description")
    if not isinstance(title, str) or not title.strip():
        return None, "missing required key: title"
    if not isinstance(description, str) or not description.strip():
        return None, "missing required key: description"
    return data, None


def version_label(slug: str) -> str:
    """Human-facing Finnish label for a version folder name."""
    if slug == KOTITEHTAVAT:
        return "Kotitehtävät"
    match = _VERSION_RE.match(slug)
    if match:
        return f"Versio {int(match.group(1))}"
    return slug


def _version_sort_key(name: str) -> tuple[int, int, str]:
    """Numeric versions first, other folders next, kotitehtavat always last."""
    if name == KOTITEHTAVAT:
        return (2, 0, name)
    match = _VERSION_RE.match(name)
    if match:
        return (0, int(match.group(1)), name)
    return (1, 0, name)


def _child_dirs(directory: Path) -> list[str]:
    if not directory.is_dir():
        return []
    return sorted(child.name for child in directory.iterdir() if child.is_dir())


def discover(site_root: Path) -> tuple[list[str], list[str], list[str]]:
    """Return (games, demos, strays): the folders under games/ and demos/, and
    every other site-root folder except assets/ (warned, ignored), each sorted."""
    known = (ASSETS_DIRNAME, GAMES_DIRNAME, DEMOS_DIRNAME)
    strays = [name for name in _child_dirs(site_root) if name not in known]
    return _child_dirs(site_root / GAMES_DIRNAME), _child_dirs(site_root / DEMOS_DIRNAME), strays


def discover_versions(game_dir: Path) -> list[str]:
    names = [
        p.name for p in game_dir.iterdir()
        if p.is_dir() and (p.name.startswith("versio-") or (p / PAGE_JSON).exists())
    ]
    return sorted(names, key=_version_sort_key)


def _dimension(data: dict, key: str, default: int) -> int:
    value = data.get(key, default)
    if isinstance(value, bool) or not isinstance(value, int) or value <= 0:
        return default
    return value


# ------------------------------------------------------------------------------
# Templates and rendering

def load_base_template() -> str:
    """Load base.html with styles.css and footer.html composed in once."""
    base = (WEB_SRC_DIR / "base.html").read_text(encoding="utf-8")
    return _compose_shell(base)


def _compose_shell(template: str) -> str:
    css = (WEB_SRC_DIR / "styles.css").read_text(encoding="utf-8")
    footer = (WEB_SRC_DIR / "footer.html").read_text(encoding="utf-8")
    template = template.replace("{{inlineStyles}}", f"<style>\n{css}</style>")
    template = template.replace("{{footer}}", footer.rstrip("\n"))
    return template


def render_page(base: str, *, title: str, description: str, breadcrumb: str,
                body: str, base_path: str, seo: str = "") -> str:
    page = base
    page = page.replace("{{pageTitle}}", escape(title))
    page = page.replace("{{metaDescription}}", escape(description))
    page = page.replace("{{seoHead}}", seo)
    page = page.replace("{{breadcrumb}}", breadcrumb)
    page = page.replace("{{bodyContent}}", body)
    page = page.replace("{{basePath}}", base_path)
    return page


# ------------------------------------------------------------------------------
# SEO

def load_site_config() -> dict:
    return json.loads((WEB_SRC_DIR / "site.json").read_text(encoding="utf-8"))


def seo_head(cfg: dict, *, canonical: str, title: str, description: str,
             jsonld: str = "", og_image_rel: str | None = None,
             indexable: bool = True) -> str:
    """Per-page SEO block: canonical, robots, Open Graph, Twitter card, JSON-LD."""
    og_image = cfg["baseUrl"] + (og_image_rel or cfg["ogImage"])
    rows = [f'<meta name="author" content="{escape(cfg["author"]["name"])}">']

    if indexable:
        rows.append('<meta name="robots" content="index, follow">')
        rows.append(f'<link rel="canonical" href="{escape(canonical)}">')
    else:
        rows.append('<meta name="robots" content="noindex, follow">')

    rows += [
        '<meta property="og:type" content="website">',
        f'<meta property="og:site_name" content="{escape(cfg["siteName"])}">',
        f'<meta property="og:title" content="{escape(title)}">',
        f'<meta property="og:description" content="{escape(description)}">',
        f'<meta property="og:url" content="{escape(canonical)}">',
        f'<meta property="og:image" content="{escape(og_image)}">',
        '<meta property="og:image:width" content="1200">',
        '<meta property="og:image:height" content="630">',
        f'<meta property="og:image:alt" content="{escape(cfg["siteName"])}">',
        f'<meta property="og:locale" content="{escape(cfg["ogLocale"])}">',
        '<meta name="twitter:card" content="summary_large_image">',
        f'<meta name="twitter:title" content="{escape(title)}">',
        f'<meta name="twitter:description" content="{escape(description)}">',
        f'<meta name="twitter:image" content="{escape(og_image)}">',
        f'<meta name="twitter:image:alt" content="{escape(cfg["siteName"])}">',
        f'<meta name="apple-mobile-web-app-title" content="{escape(cfg["appleTitle"])}">',
    ]
    if jsonld:
        rows.append(jsonld)
    return "\n    ".join(rows)


def _og_image_for(og_cfg: dict, site_root: Path, filename: str, default: str) -> str:
    """Pick the page's generated share image if present, else the configured
    fallback card, else the site-wide default from site.json."""
    return ogimg.resolve_og_image(og_cfg, site_root, filename) or default


def landing_jsonld(cfg: dict, description: str) -> str:
    base = cfg["baseUrl"]
    author = cfg["author"]
    publisher = cfg["publisher"]
    publisher_id = base + publisher["idFragment"]
    graph = {
        "@context": "https://schema.org",
        "@graph": [
            {
                "@type": "Person",
                "@id": author["id"],
                "name": author["name"],
                "alternateName": author["alternateName"],
                "url": author["url"],
                "sameAs": author["sameAs"],
            },
            {
                "@type": "Organization",
                "@id": publisher_id,
                "name": publisher["name"],
                "url": publisher["url"],
                "sameAs": publisher["sameAs"],
            },
            {
                "@type": "WebSite",
                "@id": base + "#website",
                "url": base,
                "name": cfg["siteName"],
                "description": description,
                "inLanguage": cfg["inLanguage"],
                "author": {"@id": author["id"]},
                "publisher": {"@id": publisher_id},
            },
        ],
    }
    return (
        '<script type="application/ld+json">\n'
        + json.dumps(graph, ensure_ascii=False, indent=2)
        + '\n    </script>'
    )


def _render_sitemap_robots(site_root: Path, cfg: dict, paths: list[str],
                           report: BuildReport) -> None:
    base = cfg["baseUrl"]
    locs = "\n".join(f'  <url><loc>{escape(base + p)}</loc></url>' for p in paths)
    sitemap = (
        '<?xml version="1.0" encoding="UTF-8"?>\n'
        '<urlset xmlns="http://www.sitemaps.org/schemas/sitemap/0.9">\n'
        f'{locs}\n'
        '</urlset>\n'
    )
    _write_page(site_root / "sitemap.xml", sitemap, report)
    robots = f"User-agent: *\nAllow: /\n\nSitemap: {base}sitemap.xml\n"
    _write_page(site_root / "robots.txt", robots, report)


# ------------------------------------------------------------------------------
# Breadcrumb

def _dropdown(label_html: str, items: list[tuple[str, str, bool]]) -> str:
    rows = []
    for href, text_html, current in items:
        cls = ' class="current"' if current else ""
        rows.append(f'    <li><a{cls} href="{href}">{text_html}</a></li>')
    menu = "\n".join(rows)
    return (
        '<li class="crumb crumb-dropdown">\n'
        f'  <button type="button" class="crumb-toggle" aria-haspopup="true" aria-expanded="false">{label_html}</button>\n'
        '  <ul class="crumb-menu">\n'
        f'{menu}\n'
        '  </ul>\n'
        '</li>'
    )


def _cat_rows(items: list[tuple[str, str, bool]], empty_text: str) -> str:
    if not items:
        return f'        <li class="cat-empty">{empty_text}</li>'
    rows = []
    for href, text_html, current in items:
        cls = ' class="current"' if current else ""
        rows.append(f'        <li><a{cls} href="{href}">{text_html}</a></li>')
    return "\n".join(rows)


def _cat_section(cat_label: str, expanded: bool, items: list[tuple[str, str, bool]],
                 empty_text: str) -> str:
    state = "true" if expanded else "false"
    return (
        '    <li class="crumb-cat">\n'
        f'      <button type="button" class="cat-toggle" aria-expanded="{state}">{cat_label}</button>\n'
        '      <ul class="cat-list">\n'
        f'{_cat_rows(items, empty_text)}\n'
        '      </ul>\n'
        '    </li>'
    )


def crumb_home(current: bool) -> str:
    if current:
        return '<li class="crumb current">Etusivu</li>'
    return f'<li class="crumb"><a href="{BASE}">Etusivu</a></li>'


def crumb_category(kind: str, game_nav: list[dict], demo_nav: list[dict], *,
                   active_game: str | None = None, active_demo: str | None = None) -> str:
    """Cascading Peli/Demo crumb: pick a category, then a game or demo to open."""
    game_items = [
        (f'{BASE}{g["path"]}', escape(g["title"]), kind == "peli" and g["slug"] == active_game)
        for g in game_nav
    ]
    demo_items = [
        (f'{BASE}{d["path"]}', escape(d["title"]), kind == "demo" and d["slug"] == active_demo)
        for d in demo_nav
    ]
    label = "Peli" if kind == "peli" else "Demo"
    games_section = _cat_section("Peli", kind == "peli", game_items, "Ei pelejä")
    demos_section = _cat_section("Demo", kind == "demo", demo_items, "Ei vielä demoja")
    return (
        '<li class="crumb crumb-dropdown crumb-category">\n'
        f'  <button type="button" class="crumb-toggle" aria-haspopup="true" aria-expanded="false">{label}</button>\n'
        '  <ul class="crumb-menu crumb-cat-menu">\n'
        f'{games_section}\n'
        f'{demos_section}\n'
        '  </ul>\n'
        '</li>'
    )


def crumb_game(game_nav: list[dict], active_slug: str) -> str:
    items = [
        (f'{BASE}{g["path"]}', escape(g["title"]), g["slug"] == active_slug)
        for g in game_nav
    ]
    label = next((escape(g["title"]) for g in game_nav if g["slug"] == active_slug), escape(active_slug))
    return _dropdown(label, items)


def crumb_versions(game_path: str, versions: list[dict], active_slug: str) -> str:
    items = [
        (f'{BASE}{game_path}{v["slug"]}/', escape(v["label"]), v["slug"] == active_slug)
        for v in versions
    ]
    return _dropdown(escape(version_label(active_slug)), items)


def crumb_demo(demo_nav: list[dict], active_slug: str) -> str:
    items = [
        (f'{BASE}{d["path"]}', escape(d["title"]), d["slug"] == active_slug)
        for d in demo_nav
    ]
    label = next((escape(d["title"]) for d in demo_nav if d["slug"] == active_slug), escape(active_slug))
    return _dropdown(label, items)


def breadcrumb_html(crumbs: list[str]) -> str:
    trail = "\n".join(crumbs)
    return (
        '<nav class="breadcrumb" aria-label="Murupolku">\n'
        '<ol class="crumb-trail">\n'
        f'{trail}\n'
        '</ol>\n'
        '</nav>'
    )


# ------------------------------------------------------------------------------
# Body builders

def _link_list(items: list[tuple[str, str]]) -> str:
    rows = [f'  <li><a href="{href}">{escape(text)}</a></li>' for href, text in items]
    return '<ul class="card-list">\n' + "\n".join(rows) + '\n</ul>'


def landing_body(game_nav: list[dict], demo_nav: list[dict]) -> str:
    fragment = (WEB_SRC_DIR / "landing.html").read_text(encoding="utf-8")
    games_list = _link_list([(f'{BASE}{g["path"]}', g["title"]) for g in game_nav])
    if demo_nav:
        demos_list = _link_list([(f'{BASE}{d["path"]}', d["title"]) for d in demo_nav])
    else:
        demos_list = '<p class="empty-note">Demoja ei ole vielä julkaistu.</p>'
    fragment = fragment.replace("{{gamesList}}", games_list)
    fragment = fragment.replace("{{demosList}}", demos_list)
    return fragment.rstrip("\n")


def game_body(title: str, data: dict, game_slug: str, game_path: str, versions: list[dict]) -> str:
    course_name = data.get("courseName")
    course_url = data.get("courseUrl")
    if (isinstance(course_name, str) and course_name.strip()
            and isinstance(course_url, str) and course_url.strip()):
        desc = (
            f'Kurssin <a href="{escape(course_url)}" target="_blank" rel="noopener">'
            f'{escape(course_name)}</a> opetuspeli.'
        )
    else:
        desc = escape(data["description"])
    shot = (
        f'<img class="hero-shot" src="{BASE}assets/screenshots/{game_slug}.png" '
        f'alt="Kuvakaappaus pelistä {escape(data["title"])}" loading="lazy">'
    )
    hero = (
        '<div class="hero">\n'
        '  <div class="hero-text">\n'
        f'    <h1>{escape(title)}</h1>\n'
        f'    <p class="lead">{desc}</p>\n'
        '  </div>\n'
        f'  <div class="hero-media">{shot}</div>\n'
        '</div>'
    )
    cards = _link_list([(f'{BASE}{game_path}{v["slug"]}/', v["label"]) for v in versions])
    return f'{hero}\n<section class="section">\n<h2>Versiot</h2>\n{cards}\n</section>'


def _lesson_link(lesson: dict) -> str:
    title = escape(lesson["title"])
    url = lesson.get("url")
    if isinstance(url, str) and url.strip():
        return f'<a href="{escape(url)}" target="_blank" rel="noopener">{title}</a>'
    return title


def _meta_block(data: dict, changes: str = "") -> str:
    rows = []
    # A version that completes a split lesson lists every part it covers.
    lessons = [
        lesson for lesson in data.get("lessons", [])
        if isinstance(lesson, dict) and isinstance(lesson.get("title"), str) and lesson["title"].strip()
    ]
    if lessons:
        label = "Oppitunti" if len(lessons) == 1 else "Oppitunnit"
        links = ", ".join(_lesson_link(lesson) for lesson in lessons)
        rows.append(f'  <p class="lesson">{label}: {links}</p>')
    source = data.get("source")
    if isinstance(source, str) and source.strip():
        rows.append(
            f'  <p class="source">Lähdekoodi: '
            f'<a class="source-link" href="{escape(source)}" target="_blank" rel="noopener">'
            f'<img class="gh-logo" src="{BASE}assets/github-lockup-white.svg" '
            f'alt="Lähdekoodi GitHubissa"></a></p>'
        )
    if changes:
        rows.append(changes)
    if not rows:
        return ""
    return '<div class="page-meta">\n' + "\n".join(rows) + '\n</div>'


def _iframe_block(title: str, width: int, height: int) -> str:
    return (
        '<div class="game-stage">\n'
        f'  <iframe class="game-frame" src="./app/index.html" title="{escape(title)}" '
        f'width="{width}" height="{height}"></iframe>\n'
        '</div>'
    )


def _step_nav(aria_label: str, previous: tuple[str, str] | None,
              following: tuple[str, str] | None) -> str:
    """Bottom prev/next buttons; each side is (href, text) or None."""
    links = []
    if previous:
        links.append(f'  <a class="nav-prev" href="{previous[0]}">{previous[1]}</a>')
    if following:
        links.append(f'  <a class="nav-next" href="{following[0]}">{following[1]}</a>')
    if not links:
        return ""
    return (
        f'<nav class="version-nav" aria-label="{aria_label}">\n'
        + "\n".join(links)
        + '\n</nav>'
    )


def _version_nav(game_path: str, versions: list[dict], index: int) -> str:
    previous = None
    following = None
    if index > 0:
        previous = (f'{BASE}{game_path}{versions[index - 1]["slug"]}/', "Edellinen versio")
    if index < len(versions) - 1:
        following = (f'{BASE}{game_path}{versions[index + 1]["slug"]}/', "Seuraava versio")
    return _step_nav("Versionavigointi", previous, following)


def version_body(title: str, data: dict, game_path: str, versions: list[dict], index: int,
                 changes: str = "") -> str:
    width = _dimension(data, "width", DEFAULT_WIDTH)
    height = _dimension(data, "height", DEFAULT_HEIGHT)
    parts = [f'<h1>{escape(title)}</h1>']
    meta = _meta_block(data, changes)
    if meta:
        parts.append(meta)
    parts.append(_iframe_block(title, width, height))
    nav = _version_nav(game_path, versions, index)
    if nav:
        parts.append(nav)
    return "\n".join(parts)


def demo_body(title: str, data: dict) -> str:
    width = _dimension(data, "width", DEFAULT_WIDTH)
    height = _dimension(data, "height", DEFAULT_HEIGHT)
    parts = [
        f'<h1>{escape(title)}</h1>',
        f'<p class="lead">{escape(data["description"])}</p>',
    ]
    meta = _meta_block(data)
    if meta:
        parts.append(meta)
    parts.append(_iframe_block(title, width, height))
    return "\n".join(parts)


# ------------------------------------------------------------------------------
# Diff pages

STATUS_LABELS = {
    vdiff.ADDED: "lisätty",
    vdiff.REMOVED: "poistettu",
    vdiff.MODIFIED: "muutettu",
    vdiff.MOVED: "siirretty",
}

KIND_TAGS = {
    vdiff.MAP: "kartta",
    vdiff.IMAGE: "kuva",
    vdiff.AUDIO: "ääni",
}

MEDIA_KINDS = (vdiff.IMAGE, vdiff.AUDIO)

OPEN_KINDS = (vdiff.CODE, vdiff.IMAGE, vdiff.AUDIO)

UNIFIED_COLUMNS = 4
SPLIT_COLUMNS = 6


def _plural(count: int, singular: str, plural: str) -> str:
    return f"{count} {singular if count == 1 else plural}"


def _pair_text(prev_slug: str, slug: str) -> str:
    return f"{version_label(prev_slug).lower()} -> {version_label(slug).lower()}"


def changes_line(prev_slug: str, slug: str) -> str:
    """The version page's meta line linking to its diff page."""
    return (
        f'  <p class="changes">Muutokset: <a href="./{DIFF_DIRNAME}/">'
        f'{escape(_pair_text(prev_slug, slug))}</a></p>'
    )


def _source_versions(game_src: Path) -> list[str]:
    names = [
        child.name for child in game_src.iterdir()
        if child.is_dir() and (_VERSION_RE.match(child.name) or child.name == KOTITEHTAVAT)
    ]
    return sorted(names, key=_version_sort_key)


def _game_diffs(games_root: Path, game: dict, diff_cfg: dict,
                report: BuildReport) -> dict[str, tuple[str, vdiff.VersionDiff]]:
    """Map each source version slug that has a predecessor to (prev_slug, diff)."""
    gslug = game["slug"]
    game_src = games_root / gslug
    if not game_src.is_dir():
        report.diff_warnings.append(f"{gslug}: {PROJECTS_DIRNAME}/{GAMES_DIRNAME}/{gslug}/ not found, no diff pages")
        return {}

    slugs = _source_versions(game_src)
    diffs = vdiff.diff_sequence([game_src / slug for slug in slugs], diff_cfg)
    pairs = {slug: (slugs[index], diffs[index]) for index, slug in enumerate(slugs[1:])}

    for version in game["versions"]:
        if version["slug"] not in slugs:
            report.diff_warnings.append(
                f'{gslug}/{version["slug"]}: {PROJECTS_DIRNAME}/{GAMES_DIRNAME}/{gslug}/{version["slug"]}/ not found, no diff page'
            )
    return pairs


def _code_html(segments: list[vdiff.Segment]) -> str:
    parts = []
    for segment in segments:
        text = escape(segment.text, quote=False)
        parts.append(f"<mark>{text}</mark>" if segment.changed else text)
    return "".join(parts)


def _side_class(side: str) -> str:
    return f" {side}" if side else ""


# Line numbers and +/- markers live in data attributes so copying code copies only code.
def _num_cell(number: int | None, side: str = "") -> str:
    attr = f' data-line="{number}"' if number is not None else ""
    return f'<td class="diff-num{_side_class(side)}"{attr}></td>'


def _sign_cell(sign: str, side: str = "") -> str:
    attr = f' data-sign="{sign}"' if sign else ""
    return f'<td class="diff-sign{_side_class(side)}"{attr}></td>'


def _code_cell(code: str, side: str = "") -> str:
    return f'<td class="diff-code{_side_class(side)}">{code}</td>'


def _unified_rows(hunk: vdiff.Hunk) -> list[str]:
    rows = []
    for block in hunk.blocks:
        if block.kind == "context":
            for line in block.lines:
                rows.append(
                    f'<tr class="diff-ctx">{_num_cell(line.old_no)}{_num_cell(line.new_no)}'
                    f'{_sign_cell("")}{_code_cell(_code_html(line.segments))}</tr>'
                )
            continue

        for line in block.dels:
            rows.append(
                f'<tr class="diff-del">{_num_cell(line.old_no)}{_num_cell(None)}'
                f'{_sign_cell("-")}{_code_cell(_code_html(line.segments))}</tr>'
            )
        for line in block.adds:
            rows.append(
                f'<tr class="diff-add">{_num_cell(None)}{_num_cell(line.new_no)}'
                f'{_sign_cell("+")}{_code_cell(_code_html(line.segments))}</tr>'
            )
    return rows


def _split_side(line: vdiff.Line | None, sign: str, side: str) -> str:
    if line is None:
        return _num_cell(None, "diff-empty") + _sign_cell("", "diff-empty") + _code_cell("", "diff-empty")
    number = line.old_no if sign == "-" else line.new_no
    return _num_cell(number, side) + _sign_cell(sign, side) + _code_cell(_code_html(line.segments), side)


def _split_rows(hunk: vdiff.Hunk) -> list[str]:
    rows = []
    for block in hunk.blocks:
        if block.kind == "context":
            for line in block.lines:
                code = _code_html(line.segments)
                rows.append(
                    f'<tr class="diff-ctx">{_num_cell(line.old_no)}{_sign_cell("")}{_code_cell(code)}'
                    f'{_num_cell(line.new_no)}{_sign_cell("")}{_code_cell(code)}</tr>'
                )
            continue

        for old_line, new_line in zip_longest(block.dels, block.adds):
            rows.append(
                f'<tr class="diff-change">{_split_side(old_line, "-", "diff-del")}'
                f'{_split_side(new_line, "+", "diff-add")}</tr>'
            )
    return rows


def _gap_row(gap: vdiff.Gap, gap_id: str, columns: int, expandable: bool) -> str:
    if expandable:
        if gap.count == 1:
            label = "Näytä 1 piilotettu rivi"
        else:
            label = f"Näytä {gap.count} piilotettua riviä"
        content = f'<button type="button" class="diff-expand">{label}</button>'
    else:
        content = f'{_plural(gap.count, "rivi", "riviä")} piilotettu'
    return (
        f'<tr class="diff-gap" data-gap="{gap_id}" data-old-start="{gap.old_start}" '
        f'data-new-start="{gap.new_start}" data-count="{gap.count}">'
        f'<td colspan="{columns}">{content}</td></tr>'
    )


def _table(view_class: str, rows: list[str]) -> str:
    return (
        f'<table class="diff-table {view_class}">\n<tbody>\n'
        + "\n".join(rows)
        + '\n</tbody>\n</table>'
    )


def _json_payload(lines: list[str]) -> str:
    # Escaping <, > and & keeps "</script>" in code from closing the element; JSON.parse undoes it.
    payload = json.dumps(lines, ensure_ascii=False)
    return payload.replace("<", "\\u003c").replace(">", "\\u003e").replace("&", "\\u0026")


def _text_tables(file_diff: vdiff.FileDiff, file_index: int) -> str:
    unified = []
    split = []
    gap_index = 0
    for section in file_diff.sections:
        if isinstance(section, vdiff.Gap):
            gap_id = f"f{file_index}-g{gap_index}"
            gap_index += 1
            unified.append(_gap_row(section, gap_id, UNIFIED_COLUMNS, file_diff.expandable))
            split.append(_gap_row(section, gap_id, SPLIT_COLUMNS, file_diff.expandable))
            continue

        unified.extend(_unified_rows(section))
        split.extend(_split_rows(section))

    parts = [_table("diff-unified", unified), _table("diff-split", split)]
    if file_diff.expandable and file_diff.new_lines is not None:
        parts.append(
            f'<script type="application/json" class="diff-source">{_json_payload(file_diff.new_lines)}</script>'
        )
    return "\n".join(parts)


def _note(text: str) -> str:
    return f'<p class="diff-note">{escape(text)}</p>'


def _media_rel(side_dir: str, path: str) -> str:
    return f"{MEDIA_DIRNAME}/{side_dir}/{path}"


def _media_figure(kind: str, side_dir: str, path: str, caption: str) -> str:
    src = escape(quote(_media_rel(side_dir, path)))
    if kind == vdiff.IMAGE:
        media = f'<img class="diff-image" src="./{src}" alt="{escape(path)} ({escape(caption)})" loading="lazy">'
    else:
        media = f'<audio class="diff-audio" controls preload="none" src="./{src}"></audio>'
    return (
        '  <figure class="diff-figure">\n'
        f'    {media}\n'
        f'    <figcaption>{escape(caption)}</figcaption>\n'
        '  </figure>'
    )


def _media_block(file_diff: vdiff.FileDiff, labels: tuple[str, str]) -> str:
    old_label, new_label = labels
    figures = []
    if file_diff.old_path is not None:
        figures.append(_media_figure(file_diff.kind, OLD_MEDIA_DIRNAME, file_diff.old_path, old_label))
    if file_diff.new_path is not None:
        figures.append(_media_figure(file_diff.kind, NEW_MEDIA_DIRNAME, file_diff.new_path, new_label))
    kind_class = "diff-images" if file_diff.kind == vdiff.IMAGE else "diff-sounds"
    return f'<div class="diff-media {kind_class}">\n' + "\n".join(figures) + '\n</div>'


def _file_body(file_diff: vdiff.FileDiff, file_index: int, labels: tuple[str, str]) -> str:
    if file_diff.kind in MEDIA_KINDS:
        return _media_block(file_diff, labels)

    if file_diff.line_count is None:
        return _note("Binääritiedosto, ei esikatselua.")

    if file_diff.sections:
        return _text_tables(file_diff, file_index)

    if file_diff.status == vdiff.MOVED:
        return _note("Sisältö ennallaan.")

    lines = _plural(file_diff.line_count, "rivi", "riviä")
    if file_diff.status == vdiff.ADDED:
        return _note(f"Uusi tiedosto, {lines}.")
    return _note(f"Poistettu tiedosto, {lines}.")


def _file_details(file_diff: vdiff.FileDiff, file_index: int, labels: tuple[str, str]) -> str:
    if file_diff.status == vdiff.MOVED:
        path_text = f"{file_diff.old_path} -> {file_diff.new_path}"
    else:
        path_text = file_diff.display_path

    summary = [f'<span class="diff-path">{escape(path_text)}</span>']
    tag = KIND_TAGS.get(file_diff.kind)
    if tag:
        summary.append(f'<span class="diff-tag">{escape(tag)}</span>')
    summary.append(
        f'<span class="diff-status" data-status="{escape(file_diff.status)}">'
        f'{escape(STATUS_LABELS[file_diff.status])}</span>'
    )
    if file_diff.line_count is not None:
        summary.append(
            f'<span class="diff-stat"><span class="diff-plus">+{file_diff.added}</span> '
            f'<span class="diff-minus">-{file_diff.removed}</span></span>'
        )

    open_attr = " open" if file_diff.kind in OPEN_KINDS else ""
    return (
        f'<details class="diff-file" id="tiedosto-{file_index}" data-kind="{escape(file_diff.kind)}"{open_attr}>\n'
        f'<summary>{" ".join(summary)}</summary>\n'
        f'<div class="diff-body">\n{_file_body(file_diff, file_index, labels)}\n</div>\n'
        '</details>'
    )


def _diff_nav(game_path: str, diff_slugs: list[str], slug: str) -> str:
    index = diff_slugs.index(slug)
    previous = None
    following = None
    if index > 0:
        previous = (f"{BASE}{game_path}{diff_slugs[index - 1]}/{DIFF_DIRNAME}/", "Edelliset muutokset")
    if index < len(diff_slugs) - 1:
        following = (f"{BASE}{game_path}{diff_slugs[index + 1]}/{DIFF_DIRNAME}/", "Seuraavat muutokset")
    return _step_nav("Muutosnavigointi", previous, following)


def diff_body(title: str, game_path: str, slug: str, prev_slug: str,
              version_diff: vdiff.VersionDiff, diff_slugs: list[str]) -> str:
    files_text = _plural(len(version_diff.files), "tiedosto", "tiedostoa")
    summary = (
        f"{version_label(prev_slug)} -> {version_label(slug).lower()} | "
        f"{files_text}, +{version_diff.added} -{version_diff.removed}"
    )
    toggle = (
        '<div class="diff-toggle" role="group" aria-label="Näkymä" hidden>\n'
        '  <button type="button" data-view="unified" aria-pressed="true">Yksi sarake</button>\n'
        '  <button type="button" data-view="split" aria-pressed="false">Rinnakkain</button>\n'
        '</div>'
    )

    labels = (version_label(prev_slug), version_label(slug))
    if version_diff.files:
        files = [
            _file_details(file_diff, index, labels)
            for index, file_diff in enumerate(version_diff.files, 1)
        ]
    else:
        files = [_note("Ei muuttuneita tiedostoja.")]

    parts = [
        f'<h1>{escape(title)}</h1>',
        f'<p class="diff-summary">{escape(summary)}</p>',
        f'<p class="back-link"><a href="../">Takaisin: {escape(version_label(slug))}</a></p>',
        toggle,
        '<div class="diff-files" data-view="unified">\n' + "\n".join(files) + '\n</div>',
    ]
    nav = _diff_nav(game_path, diff_slugs, slug)
    if nav:
        parts.append(nav)
    return "\n".join(parts)


def _media_files(version_diff: vdiff.VersionDiff) -> list[tuple[Path, str]]:
    """(source file, path relative to the diff page) for every previewed file."""
    files = []
    for file_diff in version_diff.files:
        if file_diff.kind not in MEDIA_KINDS:
            continue
        if file_diff.old_file is not None:
            files.append((file_diff.old_file, _media_rel(OLD_MEDIA_DIRNAME, file_diff.old_path)))
        if file_diff.new_file is not None:
            files.append((file_diff.new_file, _media_rel(NEW_MEDIA_DIRNAME, file_diff.new_path)))
    return files


def _sync_media(diff_dir: Path, version_diff: vdiff.VersionDiff) -> None:
    """Copy previewed files under tiedostot/ and delete whatever the diff no longer references."""
    keep = set()
    for source, rel in _media_files(version_diff):
        target = diff_dir / rel
        keep.add(target)
        data = source.read_bytes()
        # Skipping identical writes keeps reruns byte-identical, mtimes included.
        if target.is_file() and target.read_bytes() == data:
            continue
        target.parent.mkdir(parents=True, exist_ok=True)
        target.write_bytes(data)

    media_root = diff_dir / MEDIA_DIRNAME
    if not media_root.is_dir():
        return

    for entry in list(media_root.rglob("*")):
        if not entry.is_dir() and entry not in keep:
            entry.unlink()

    folders = [entry for entry in media_root.rglob("*") if entry.is_dir()]
    for folder in sorted(folders, key=lambda entry: len(entry.parts), reverse=True):
        if not any(folder.iterdir()):
            folder.rmdir()
    if not any(media_root.iterdir()):
        media_root.rmdir()


def _remove_orphan_diff(version_dir: Path, report: BuildReport) -> None:
    """Delete a muutokset/ folder left from a build where this version still had a predecessor."""
    diff_dir = version_dir / DIFF_DIRNAME
    if diff_dir.is_dir():
        shutil.rmtree(diff_dir)
        report.diff_orphans_removed += 1


def _render_diff_page(context: dict, game: dict, version: dict, prev_slug: str,
                      version_diff: vdiff.VersionDiff, diff_slugs: list[str],
                      report: BuildReport) -> None:
    gslug = game["slug"]
    gpath = game["path"]
    gtitle = game["data"]["title"] if game["data"] else gslug
    slug = version["slug"]
    display = f"{gtitle} - {version_label(slug).lower()}: muutokset"
    description = f"{gtitle}: muutokset {_pair_text(prev_slug, slug)}."
    cfg = context["cfg"]
    crumbs = [
        crumb_home(False),
        crumb_category("peli", context["game_nav"], context["demo_nav"], active_game=gslug),
        crumb_game(context["game_nav"], gslug),
        f'<li class="crumb"><a href="{BASE}{gpath}{slug}/">{escape(version_label(slug))}</a></li>',
        '<li class="crumb current">Muutokset</li>',
    ]
    body = diff_body(display, gpath, slug, prev_slug, version_diff, diff_slugs)
    body += f'\n<script>\n{context["diff_js"]}</script>'
    page = render_page(
        context["base"],
        title=display,
        description=description,
        breadcrumb=breadcrumb_html(crumbs),
        body=body,
        base_path="../../../../",
        seo=seo_head(cfg, canonical=f"{cfg['baseUrl']}{gpath}{slug}/{DIFF_DIRNAME}/",
                     title=display, description=description,
                     og_image_rel=context["og_image_rel"], indexable=False),
    )
    diff_dir = version["dir"] / DIFF_DIRNAME
    _write_page(diff_dir / "index.html", page, report)
    _sync_media(diff_dir, version_diff)
    report.diff_pages += 1


# ------------------------------------------------------------------------------
# Generation

def _write_page(path: Path, content: str, report: BuildReport) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(content, encoding="utf-8")
    report.pages_generated += 1


def _collect_model(
    site_root: Path,
) -> tuple[tuple[dict | None, str | None], list[dict], list[dict], list[str]]:
    """Read the whole site tree once into a navigation model."""
    landing = load_page(site_root / PAGE_JSON)

    game_slugs, demo_slugs, stray_dirs = discover(site_root)
    game_nav = []
    for gslug in game_slugs:
        gdir = site_root / GAMES_DIRNAME / gslug
        gdata, gerror = load_page(gdir / PAGE_JSON)
        versions = []
        for vslug in discover_versions(gdir):
            vdir = gdir / vslug
            vdata, verror = load_page(vdir / PAGE_JSON)
            versions.append({
                "slug": vslug,
                "label": version_label(vslug),
                "dir": vdir,
                "data": vdata,
                "error": verror,
            })
        game_nav.append({
            "slug": gslug,
            "path": f"{GAMES_DIRNAME}/{gslug}/",
            "title": gdata["title"] if gdata else gslug,
            "dir": gdir,
            "data": gdata,
            "error": gerror,
            "versions": versions,
        })

    demo_nav = []
    for dslug in demo_slugs:
        ddir = site_root / DEMOS_DIRNAME / dslug
        ddata, derror = load_page(ddir / PAGE_JSON)
        demo_nav.append({
            "slug": dslug,
            "path": f"{DEMOS_DIRNAME}/{dslug}/",
            "title": ddata["title"] if ddata else dslug,
            "dir": ddir,
            "data": ddata,
            "error": derror,
        })

    return landing, game_nav, demo_nav, stray_dirs


def _render_404(site_root: Path, report: BuildReport) -> None:
    template = (WEB_SRC_DIR / "404.html").read_text(encoding="utf-8")
    # The 404 resolves resource paths at runtime from the deployment root, so the
    # inlined-CSS basePath token collapses to empty and a runtime <base> anchors it.
    page = _compose_shell(template).replace(BASE, "")
    _write_page(site_root / "404.html", page, report)


def run(site_root: Path) -> BuildReport:
    """Generate every viewer page, patch every app build, and return the report."""
    site_root = Path(site_root)
    base = load_base_template()
    cfg = load_site_config()
    og_cfg = ogimg.load_config()
    report = BuildReport()
    indexable: list[str] = []

    landing, game_nav, demo_nav, stray_dirs = _collect_model(site_root)
    report.stray_dirs.extend(stray_dirs)

    # Landing page.
    landing_data, landing_error = landing
    if landing_error:
        report.page_failures.append(("index.html", landing_error))
    else:
        canonical = cfg["baseUrl"]
        page = render_page(
            base,
            title=landing_data["title"],
            description=landing_data["description"],
            breadcrumb=breadcrumb_html([crumb_home(True)]),
            body=landing_body(game_nav, demo_nav),
            base_path="",
            seo=seo_head(
                cfg,
                canonical=canonical,
                title=landing_data["title"],
                description=landing_data["description"],
                jsonld=landing_jsonld(cfg, landing_data["description"]),
                og_image_rel=_og_image_for(
                    og_cfg, site_root, ogimg.frontpage_filename(og_cfg), cfg["ogImage"]),
            ),
        )
        _write_page(site_root / "index.html", page, report)
        indexable.append("")

    games_root = site_root.parent / PROJECTS_DIRNAME / GAMES_DIRNAME
    games_present = games_root.is_dir()
    if game_nav and not games_present:
        report.diff_warnings.append(f"{games_root} not found, no diff pages")
    diff_cfg = vdiff.load_config()
    diff_js = (WEB_SRC_DIR / "diff.js").read_text(encoding="utf-8")

    # Game pages, their version pages, and each version's diff page.
    for game in game_nav:
        gslug = game["slug"]
        gpath = game["path"]
        gtitle = game["data"]["title"] if game["data"] else gslug
        game_og_image = _og_image_for(og_cfg, site_root, ogimg.game_filename(og_cfg, gslug), cfg["ogImage"])
        pairs = _game_diffs(games_root, game, diff_cfg, report) if games_present else {}
        diff_slugs = [
            version["slug"] for version in game["versions"]
            if not version["error"] and version["slug"] in pairs
        ]
        diff_context = {
            "base": base,
            "cfg": cfg,
            "game_nav": game_nav,
            "demo_nav": demo_nav,
            "diff_js": diff_js,
            "og_image_rel": game_og_image,
        }
        if game["error"]:
            report.page_failures.append((f"{gpath}index.html", game["error"]))
        else:
            path = gpath
            canonical = cfg["baseUrl"] + path
            crumbs = [
                crumb_home(False),
                crumb_category("peli", game_nav, demo_nav, active_game=gslug),
                crumb_game(game_nav, gslug),
            ]
            page = render_page(
                base,
                title=gtitle,
                description=game["data"]["description"],
                breadcrumb=breadcrumb_html(crumbs),
                body=game_body(gtitle, game["data"], gslug, gpath, game["versions"]),
                base_path="../../",
                seo=seo_head(cfg, canonical=canonical, title=gtitle,
                             description=game["data"]["description"],
                             og_image_rel=game_og_image),
            )
            _write_page(game["dir"] / "index.html", page, report)
            indexable.append(path)

        for index, version in enumerate(game["versions"]):
            rel = f'{gpath}{version["slug"]}/index.html'
            if version["slug"] not in diff_slugs:
                _remove_orphan_diff(version["dir"], report)

            if version["error"]:
                report.page_failures.append((rel, version["error"]))
                continue
            display = f'{gtitle} - {version_label(version["slug"]).lower()}'
            path = f'{gpath}{version["slug"]}/'
            pair = pairs.get(version["slug"])
            changes = changes_line(pair[0], version["slug"]) if pair else ""
            canonical = cfg["baseUrl"] + path
            crumbs = [
                crumb_home(False),
                crumb_category("peli", game_nav, demo_nav, active_game=gslug),
                crumb_game(game_nav, gslug),
                crumb_versions(gpath, game["versions"], version["slug"]),
            ]
            page = render_page(
                base,
                title=display,
                description=version["data"]["description"],
                breadcrumb=breadcrumb_html(crumbs),
                body=version_body(display, version["data"], gpath, game["versions"], index, changes),
                base_path="../../../",
                seo=seo_head(cfg, canonical=canonical, title=display,
                             description=version["data"]["description"],
                             og_image_rel=game_og_image),
            )
            _write_page(version["dir"] / "index.html", page, report)
            indexable.append(path)

            if pair:
                _render_diff_page(diff_context, game, version, pair[0], pair[1], diff_slugs, report)

    # Demo pages.
    for demo in demo_nav:
        dslug = demo["slug"]
        if demo["error"]:
            report.page_failures.append((f'{demo["path"]}index.html', demo["error"]))
            continue
        display = f'Demo - {demo["data"]["title"]}'
        path = demo["path"]
        canonical = cfg["baseUrl"] + path
        crumbs = [
            crumb_home(False),
            crumb_category("demo", game_nav, demo_nav, active_demo=dslug),
            crumb_demo(demo_nav, dslug),
        ]
        page = render_page(
            base,
            title=display,
            description=demo["data"]["description"],
            breadcrumb=breadcrumb_html(crumbs),
            body=demo_body(display, demo["data"]),
            base_path="../../",
            seo=seo_head(cfg, canonical=canonical, title=display,
                         description=demo["data"]["description"],
                         og_image_rel=_og_image_for(
                             og_cfg, site_root, ogimg.demo_filename(og_cfg, dslug),
                             cfg["ogImage"])),
        )
        _write_page(demo["dir"] / "index.html", page, report)
        indexable.append(path)

    _render_404(site_root, report)
    _render_sitemap_robots(site_root, cfg, indexable, report)
    _patch_apps(site_root, game_nav, demo_nav, report)
    return report


def _aggregate(results: list[tuple[str, str]]) -> str:
    statuses = [status for _, status in results]
    if patcher.FAILED in statuses:
        return FAILED
    if patcher.APPLIED in statuses:
        return PATCHED
    return ALREADY


def _patch_apps(site_root: Path, game_nav: list[dict], demo_nav: list[dict],
                report: BuildReport) -> None:
    status_by_app = {
        build_dir.resolve(): _aggregate(results)
        for build_dir, results in patcher.patch_tree(site_root)
    }

    for game in game_nav:
        for version in game["versions"]:
            app_dir = (version["dir"] / "app").resolve()
            rel = f'{game["path"]}{version["slug"]}'
            report.app_statuses.append((rel, status_by_app.get(app_dir, MISSING)))

    for demo in demo_nav:
        app_dir = (demo["dir"] / "app").resolve()
        report.app_statuses.append((demo["path"].rstrip("/"), status_by_app.get(app_dir, MISSING)))


# ------------------------------------------------------------------------------
# CLI

def print_summary(report: BuildReport, site_root: Path) -> None:
    print("RG-Learning-Materials site builder")
    print("-" * 60)
    print(f"Site root: {site_root}")
    print(f"Pages generated: {report.pages_generated}")
    print(f"Diff pages generated: {report.diff_pages}")
    if report.diff_orphans_removed:
        print(f"Orphaned diff folders removed: {report.diff_orphans_removed}")

    if report.page_failures:
        print(f"Page FAILURES: {len(report.page_failures)}")
        for rel, reason in report.page_failures:
            print(f"  FAILED {rel}: {reason}")

    if report.stray_dirs:
        print(f"WARNING: {len(report.stray_dirs)} stray directory(ies) ignored (not assets/, games/ or demos/):")
        for name in report.stray_dirs:
            print(f"  STRAY {name}/")

    if report.diff_warnings:
        print(f"WARNING: {len(report.diff_warnings)} diff page warning(s):")
        for warning in report.diff_warnings:
            print(f"  DIFF {warning}")

    patched = [(p, s) for p, s in report.app_statuses if s in (PATCHED, ALREADY)]
    print(f"Apps patched/already: {len(patched)}")

    if report.missing_apps:
        print(f"WARNING: {len(report.missing_apps)} app folder(s) missing or no detectable build:")
        for rel, _ in report.missing_apps:
            print(f"  MISSING {rel}/app")

    if report.patch_failures:
        print(f"Patch FAILURES: {len(report.patch_failures)}")
        for rel, _ in report.patch_failures:
            print(f"  FAILED {rel}/app")

    print("-" * 60)
    print(f"Exit code: {report.exit_code}")


def main(argv: list[str] | None = None) -> int:
    argv = sys.argv[1:] if argv is None else argv
    site_root = Path(argv[0]) if argv else DEFAULT_SITE_ROOT
    report = run(site_root)
    print_summary(report, site_root)
    return report.exit_code


if __name__ == "__main__":
    sys.exit(main())
