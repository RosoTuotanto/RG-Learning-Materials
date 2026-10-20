#!/usr/bin/env python3
"""
Solar2D HTML5 Build - Non-interactive batch patcher (WASM builds).

A build is a folder holding index.html plus <name>.bin, where <name>.bin is a
zip archive containing <name>.js and <name>.wasm. A folder counts as a build
only when it holds exactly one *.bin whose archive contains a .js matching the
.bin stem. Detection never keys off index.html: the patcher deletes two of the
generated HTML files, so an already-patched build must still be detected.

Patches applied to every build:
  1. .bin/.js: removes the blur callback registration so builds no longer
     freeze when the user clicks outside the app.
  2. index.html: comments out the alert() in printErr (blocking popups on
     non-fatal WASM errors).
  3. index.html: adds cross-browser vendor prefixes and styling fixes to the
     progress bar CSS.
  4. index.html: replaces statusElement.innerHTML with textContent.
  5. index.html: replaces the default listener script block with one that
     blocks arrow-key scrolling and adds pointer capture with edge projection.
  6. Deletes index-debug.html and index-nosplash.html.

Usage:
  python html5_build_patcher.py            Patch every build under ../site.
  python html5_build_patcher.py PATH       Patch a .bin file, a single build
                                           folder, or every build under a tree.

Each patch reports one of three states per build: APPLIED (target found and
patched), ALREADY (the patched form is already present), FAILED (neither the
target nor the patched form is present, i.e. pattern drift). The exit code is 0
only when every found build ends with every patch APPLIED or ALREADY, and 1
when any patch FAILED or when the target path yields no builds.
"""

import os
import re
import sys
import zipfile
from pathlib import Path

SEPARATOR_WIDTH = 60

APPLIED = "APPLIED"
ALREADY = "ALREADY"
FAILED = "FAILED"

# Distinctive markers of each patch's already-applied form. Checked before the
# target pattern so a second run never double-patches and never rewrites files.
PRINTERR_MARKER = (
    "// Commented out: blocking alert() on errors causes WASM crashes "
    "and freezes the UI"
)
# Both prefixes are inserted together, so requiring the pair avoids a false
# ALREADY from unrelated CSS that merely sets -webkit-appearance on its own.
PROGRESS_CSS_WEBKIT_MARKER = "-webkit-appearance: none;"
PROGRESS_CSS_MOZ_MARKER = "-moz-appearance: none;"
TEXT_CONTENT_MARKER = "statusElement.textContent"
ENHANCED_SCRIPT_MARKER = "function edgeProject("


def patch_blur_callback(js_content: str) -> tuple[str, str]:
    """Remove the blur callback registration from _emscripten_set_blur_callback_on_thread."""
    if re.search(r'function _emscripten_set_blur_callback_on_thread\([^)]*\)\{return 0\}', js_content):
        return js_content, ALREADY

    pattern = r'(function _emscripten_set_blur_callback_on_thread\([^)]*\)\{)registerFocusEventCallback\([^)]*\);(return 0\})'
    modified = re.sub(pattern, r'\1\2', js_content)
    if modified != js_content:
        return modified, APPLIED

    return js_content, FAILED


def patch_printerr_alert(content: str) -> tuple[str, str]:
    """Comment out the blocking alert() call in printErr."""
    if PRINTERR_MARKER in content:
        return content, ALREADY

    pattern = r'''if\(\s*typeof\(text\)\s*===\s*"string"\s*&&\s*text\.toUpperCase\(\)\.indexOf\("ERROR"\)\s*>=\s*0\)\s*alert\(text\);'''
    modified = re.sub(pattern, r'// Commented out: blocking alert() on errors causes WASM crashes and freezes the UI\n            // \g<0>', content)
    if modified != content:
        return modified, APPLIED

    return content, FAILED


def patch_progress_css(content: str) -> tuple[str, str]:
    """Add cross-browser vendor prefixes and styling fixes to the progress bar."""
    if PROGRESS_CSS_WEBKIT_MARKER in content and PROGRESS_CSS_MOZ_MARKER in content:
        return content, ALREADY

    modified = re.sub(
        r'(\n)([ \t]*)(appearance:\s*none;)',
        r'\1\2-webkit-appearance: none;\1\2-moz-appearance: none;\1\2appearance: none;',
        content,
        count=1
    )
    modified = modified.replace('border-radius: 3px;', 'border: none;', 1)
    modified = modified.replace('0 2px 3px rgba', '0 4px 4px rgba', 1)

    if modified != content:
        return modified, APPLIED

    return content, FAILED


def patch_text_content(content: str) -> tuple[str, str]:
    """Replace statusElement.innerHTML with textContent to prevent XSS."""
    if TEXT_CONTENT_MARKER in content:
        return content, ALREADY

    modified = content.replace('statusElement.innerHTML', 'statusElement.textContent', 1)
    if modified != content:
        return modified, APPLIED

    return content, FAILED


# The enhanced script block that replaces Solar2D's default event listeners.
# Adds arrow key scroll prevention and pointer capture with edge projection.
ENHANCED_SCRIPT_BLOCK = '''\t<script>
\t\t// Solar2D's default listeners.
\t\twindow.addEventListener('load',function(){window.focus()});
\t\twindow.addEventListener('mousedown', function () {
\t\t\tdocument.activeElement.blur();
\t\t\twindow.focus();
\t\t}, true);

\t\t// Prevent arrow keys from scrolling the page.
\t\twindow.addEventListener("keydown", function(event) {
\t\t\tif (["ArrowLeft","ArrowUp","ArrowRight","ArrowDown"].indexOf(event.key) > -1 || (event.keyCode !== undefined && [37, 38, 39, 40].indexOf(event.keyCode) > -1)) {
\t\t\t\tevent.preventDefault();
\t\t\t}
\t\t}, false);

\t\t// Pointer capture: track drags outside the canvas by projecting
\t\t// the drag vector onto the nearest canvas edge (preserves angle).
\t\tvar canvas = document.getElementById('canvas');
\t\tvar emscriptenMousemove = null;
\t\tvar dragging = false;
\t\tvar outsideCanvas = false;
\t\tvar startX = 0, startY = 0;
\t\tvar lastX = 0, lastY = 0;

\t\t// Project line from start to cursor onto the nearest canvas edge.
\t\tfunction edgeProject(sx, sy, ex, ey, r) {
\t\t\tvar dx = ex - sx, dy = ey - sy;
\t\t\tvar t, tMin = 1, c;
\t\t\tif (dx > 0) {
\t\t\t\tt = (r.right - 1 - sx) / dx;
\t\t\t\tif (t > 0 && t < tMin) { c = sy + t * dy; if (c >= r.top && c < r.bottom) tMin = t; }
\t\t\t} else if (dx < 0) {
\t\t\t\tt = (r.left - sx) / dx;
\t\t\t\tif (t > 0 && t < tMin) { c = sy + t * dy; if (c >= r.top && c < r.bottom) tMin = t; }
\t\t\t}
\t\t\tif (dy > 0) {
\t\t\t\tt = (r.bottom - 1 - sy) / dy;
\t\t\t\tif (t > 0 && t < tMin) { c = sx + t * dx; if (c >= r.left && c < r.right) tMin = t; }
\t\t\t} else if (dy < 0) {
\t\t\t\tt = (r.top - sy) / dy;
\t\t\t\tif (t > 0 && t < tMin) { c = sx + t * dx; if (c >= r.left && c < r.right) tMin = t; }
\t\t\t}
\t\t\treturn {
\t\t\t\tx: Math.max(r.left, Math.min(r.right - 1, sx + tMin * dx)),
\t\t\t\ty: Math.max(r.top, Math.min(r.bottom - 1, sy + tMin * dy))
\t\t\t};
\t\t}

\t\t// Intercept Emscripten's mousemove handler on the canvas and
\t\t// block it during outside-canvas drags (only projected coords pass).
\t\tvar _origAdd = EventTarget.prototype.addEventListener;
\t\tcanvas.addEventListener = function(type, fn, opt) {
\t\t\tif (type === 'mousemove' && !emscriptenMousemove) {
\t\t\t\temscriptenMousemove = fn;
\t\t\t\t_origAdd.call(canvas, type, function(e) {
\t\t\t\t\tif (dragging && outsideCanvas) return;
\t\t\t\t\temscriptenMousemove.call(canvas, e);
\t\t\t\t}, opt);
\t\t\t} else {
\t\t\t\t_origAdd.call(this, type, fn, opt);
\t\t\t}
\t\t};
\t\tcanvas.addEventListener('pointerdown', function(e) {
\t\t\tdragging = true;
\t\t\toutsideCanvas = false;
\t\t\tstartX = e.clientX;
\t\t\tstartY = e.clientY;
\t\t\tlastX = e.clientX;
\t\t\tlastY = e.clientY;
\t\t\ttry { canvas.setPointerCapture(e.pointerId); } catch (err) {}
\t\t}, true);
\t\tdocument.addEventListener('pointerup', function() {
\t\t\tdragging = false;
\t\t\toutsideCanvas = false;
\t\t});
\t\tdocument.addEventListener('pointercancel', function() {
\t\t\tdragging = false;
\t\t\toutsideCanvas = false;
\t\t});

\t\t// When dragging outside the canvas, project onto the nearest
\t\t// edge (Solar2D's HTML5 layer ignores out-of-bounds values).
\t\tcanvas.addEventListener('pointermove', function(e) {
\t\t\tif (!dragging) return;
\t\t\tvar rect = canvas.getBoundingClientRect();
\t\t\tvar isOutside = e.clientX < rect.left || e.clientX >= rect.right ||
\t\t\t\t\t\t\te.clientY < rect.top || e.clientY >= rect.bottom;
\t\t\toutsideCanvas = isOutside;
\t\t\tif (isOutside) {
\t\t\t\tlastX += e.movementX;
\t\t\t\tlastY += e.movementY;
\t\t\t\tif (emscriptenMousemove) {
\t\t\t\t\tvar p = edgeProject(startX, startY, lastX, lastY, rect);
\t\t\t\t\temscriptenMousemove.call(canvas, new MouseEvent('mousemove', {
\t\t\t\t\t\tclientX: p.x,
\t\t\t\t\t\tclientY: p.y,
\t\t\t\t\t\tscreenX: e.screenX,
\t\t\t\t\t\tscreenY: e.screenY,
\t\t\t\t\t\tmovementX: e.movementX,
\t\t\t\t\t\tmovementY: e.movementY,
\t\t\t\t\t\tbutton: e.button,
\t\t\t\t\t\tbuttons: e.buttons,
\t\t\t\t\t\tctrlKey: e.ctrlKey,
\t\t\t\t\t\tshiftKey: e.shiftKey,
\t\t\t\t\t\taltKey: e.altKey,
\t\t\t\t\t\tmetaKey: e.metaKey
\t\t\t\t\t}));
\t\t\t\t}
\t\t\t} else {
\t\t\t\tlastX = e.clientX;
\t\t\t\tlastY = e.clientY;
\t\t\t}
\t\t}, true);

\t\t// Forward parent-document moves into the iframe with projected coords.
\t\tvar iframe;
\t\ttry { iframe = window.frameElement; } catch (e) {}
\t\tif (iframe) {
\t\t\twindow.parent.document.addEventListener('mousemove', function(e) {
\t\t\t\tif (dragging && emscriptenMousemove) {
\t\t\t\t\tvar iRect = iframe.getBoundingClientRect();
\t\t\t\t\tvar cRect = canvas.getBoundingClientRect();
\t\t\t\t\tvar mx = e.clientX - iRect.left;
\t\t\t\t\tvar my = e.clientY - iRect.top;
\t\t\t\t\tif (mx < cRect.left || mx >= cRect.right || my < cRect.top || my >= cRect.bottom) {
\t\t\t\t\t\toutsideCanvas = true;
\t\t\t\t\t\tvar p = edgeProject(startX, startY, mx, my, cRect);
\t\t\t\t\t\temscriptenMousemove.call(canvas, new MouseEvent('mousemove', {
\t\t\t\t\t\t\tclientX: p.x,
\t\t\t\t\t\t\tclientY: p.y,
\t\t\t\t\t\t\tscreenX: e.screenX,
\t\t\t\t\t\t\tscreenY: e.screenY,
\t\t\t\t\t\t\tmovementX: e.movementX,
\t\t\t\t\t\t\tmovementY: e.movementY,
\t\t\t\t\t\t\tbutton: e.button,
\t\t\t\t\t\t\tbuttons: e.buttons,
\t\t\t\t\t\t\tctrlKey: e.ctrlKey,
\t\t\t\t\t\t\tshiftKey: e.shiftKey,
\t\t\t\t\t\t\taltKey: e.altKey,
\t\t\t\t\t\t\tmetaKey: e.metaKey
\t\t\t\t\t\t}));
\t\t\t\t\t}
\t\t\t\t}
\t\t\t});
\t\t\twindow.parent.document.addEventListener('mouseup', function() {
\t\t\t\tdragging = false;
\t\t\t\toutsideCanvas = false;
\t\t\t});
\t\t}
\t</script>'''


def patch_inject_scripts(content: str) -> tuple[str, str]:
    """Replace the default event listener script block with the enhanced version."""
    if ENHANCED_SCRIPT_MARKER in content:
        return content, ALREADY

    pattern = r'<script>\s*window\.addEventListener\(\'load\'.*?</script>'
    modified = re.sub(pattern, ENHANCED_SCRIPT_BLOCK, content, count=1, flags=re.DOTALL)
    if modified != content:
        return modified, APPLIED

    return content, FAILED


def patch_bin(bin_path: Path) -> str:
    """Patch the .js inside a .bin archive. Rewrites the archive only on APPLIED."""
    js_name = bin_path.stem + ".js"

    with zipfile.ZipFile(bin_path, "r") as zip_ref:
        names = zip_ref.namelist()
        if js_name not in names:
            return FAILED
        members = {name: zip_ref.read(name) for name in names}

    js_content = members[js_name].decode("utf-8")
    modified, status = patch_blur_callback(js_content)

    if status == APPLIED:
        members[js_name] = modified.encode("utf-8")
        with zipfile.ZipFile(bin_path, "w", zipfile.ZIP_DEFLATED) as zip_ref:
            for name in names:
                zip_ref.writestr(name, members[name])

    return status


def patch_index_html(index_path: Path) -> list[tuple[str, str]]:
    """Apply the four index.html patches. Rewrites the file only when content changed."""
    patches = [
        ("printErr alert comment-out", patch_printerr_alert),
        ("progress bar CSS", patch_progress_css),
        ("statusElement textContent", patch_text_content),
        ("enhanced script block", patch_inject_scripts),
    ]

    if not index_path.exists():
        return [(name, FAILED) for name, _ in patches]

    with open(index_path, "r", encoding="utf-8") as f:
        content = f.read()

    results = []
    changed = False
    for name, fn in patches:
        content, status = fn(content)
        results.append((name, status))
        if status == APPLIED:
            changed = True

    if changed:
        with open(index_path, "w", encoding="utf-8") as f:
            f.write(content)

    return results


def delete_unused_html(build_dir: Path) -> str:
    """Delete index-debug.html and index-nosplash.html. Never fails on absent files."""
    deleted = False
    for filename in ("index-debug.html", "index-nosplash.html"):
        file_path = build_dir / filename
        if file_path.exists():
            file_path.unlink()
            deleted = True

    return APPLIED if deleted else ALREADY


def bin_holds_matching_js(bin_path: Path) -> bool:
    """True when the archive contains a .js file whose name matches the .bin stem."""
    js_name = bin_path.stem + ".js"
    try:
        with zipfile.ZipFile(bin_path, "r") as zip_ref:
            return js_name in zip_ref.namelist()
    except (zipfile.BadZipFile, OSError):
        return False


def build_bin_in_dir(directory: Path) -> Path | None:
    """Return the build's .bin when the directory is a single Solar2D build, else None."""
    if not directory.is_dir():
        return None

    bin_files = list(directory.glob("*.bin"))
    if len(bin_files) != 1:
        return None

    bin_path = bin_files[0]
    return bin_path if bin_holds_matching_js(bin_path) else None


def find_builds(root: Path) -> list[Path]:
    """Return the .bin of every build directory in the tree, root included."""
    builds = []
    for dirpath, dirnames, _ in os.walk(root):
        directory = Path(dirpath)
        bin_path = build_bin_in_dir(directory)
        if bin_path is not None:
            builds.append(bin_path)
            dirnames[:] = []  # a build folder holds no nested builds

    return sorted(builds)


def patch_tree(root: Path) -> list[tuple[Path, list[tuple[str, str]]]]:
    """Patch every build under root; return (build_dir, per-patch results) per build.

    Library entry point for batch patching without the CLI's printing or exit
    handling. build_dir is the folder that holds the build's .bin.
    """
    return [(bin_path.parent, patch_build(bin_path)) for bin_path in find_builds(root)]


def resolve_targets(arg_path: str) -> list[Path]:
    """Resolve a CLI argument to a list of build .bin paths."""
    path = Path(arg_path)

    if path.is_file() and path.suffix == ".bin":
        return [path] if bin_holds_matching_js(path) else []

    if path.is_dir():
        return find_builds(path)

    return []


def clean_path(raw_path: str) -> str:
    """Strip drag-and-drop artifacts and surrounding quotes from a pasted path."""
    path = raw_path.strip()

    # VS Code prepends "& '" when drag-dropping onto a PowerShell terminal.
    if path.startswith("& '") or path.startswith('& "'):
        path = path[2:].strip()

    path = path.strip('"').strip("'")

    return path


def display_path(path: Path) -> str:
    """Path relative to the current directory when possible, otherwise as given."""
    try:
        return str(path.relative_to(Path.cwd()))
    except ValueError:
        return str(path)


def patch_build(bin_path: Path) -> list[tuple[str, str]]:
    """Patch one build and return every patch's (name, status)."""
    build_dir = bin_path.parent

    results = [("blur callback removal", patch_bin(bin_path))]
    results.extend(patch_index_html(build_dir / "index.html"))
    results.append(("debug HTML cleanup", delete_unused_html(build_dir)))

    return results


def main() -> int:
    print("Solar2D HTML5 Build Patcher")
    print("-" * SEPARATOR_WIDTH)

    if len(sys.argv) > 1:
        target = clean_path(sys.argv[1])
        builds = resolve_targets(target)
    else:
        target = str((Path(__file__).resolve().parent.parent / "site"))
        builds = find_builds(Path(target))

    if not builds:
        print(f"No builds found under '{target}'.")
        print("A build is a folder with one *.bin whose archive holds a matching .js.")
        return 1

    ok_count = 0
    fail_count = 0

    for bin_path in builds:
        print(f"Build: {display_path(bin_path.parent)}")
        results = patch_build(bin_path)
        for name, status in results:
            print(f"  {name}: {status}")

        if any(status == FAILED for _, status in results):
            fail_count += 1
        else:
            ok_count += 1
        print()

    print("-" * SEPARATOR_WIDTH)
    print(f"Summary: {len(builds)} builds found, {ok_count} fully ok, {fail_count} with failures")

    return 1 if fail_count else 0


if __name__ == "__main__":
    sys.exit(main())
