#!/usr/bin/env python3
"""Tests for tools/html5_build_patcher.py. Run: python3 tools/tests/test_patcher.py"""

import subprocess
import sys
import tempfile
import unittest
import zipfile
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parents[2]
PATCHER = REPO_ROOT / "tools" / "html5_build_patcher.py"

sys.path.insert(0, str(REPO_ROOT / "tools"))
import html5_build_patcher

APPLIED = "APPLIED"
FAILED = "FAILED"

# index.html carrying the exact literals each patch targets.
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

# JS whose blur callback body matches the removal pattern.
PATCHABLE_JS = (
    "var x=1;\n"
    "function _emscripten_set_blur_callback_on_thread(target,userData,useCapture,"
    "callbackfunc,eventTypeId,targetThread)"
    '{registerFocusEventCallback(target,userData,useCapture,callbackfunc,12,"blur",'
    "targetThread);return 0}\n"
    "var y=2;\n"
)

# JS with neither the blur pattern nor its patched marker: pattern drift.
FAILED_JS = "var x=1;\nfunction unrelated(){return 1}\nvar y=2;\n"

WASM_STUB = b"\x00asm\x01\x00\x00\x00stub"


def make_build(build_dir: Path, name: str, js_body: str) -> None:
    """Create a synthetic Solar2D HTML5 build folder."""
    build_dir.mkdir(parents=True, exist_ok=True)

    (build_dir / "index.html").write_text(INDEX_HTML, encoding="utf-8")
    (build_dir / "index-debug.html").write_text("debug", encoding="utf-8")
    (build_dir / "index-nosplash.html").write_text("nosplash", encoding="utf-8")

    bin_path = build_dir / f"{name}.bin"
    with zipfile.ZipFile(bin_path, "w", zipfile.ZIP_DEFLATED) as zf:
        zf.writestr(f"{name}.js", js_body)
        zf.writestr(f"{name}.wasm", WASM_STUB)


def run_patcher(*args: str) -> subprocess.CompletedProcess:
    """Invoke the patcher as a subprocess so real exit codes are exercised."""
    return subprocess.run(
        [sys.executable, str(PATCHER), *args],
        cwd=str(REPO_ROOT),
        capture_output=True,
        text=True,
    )


def read_js_from_bin(bin_path: Path, name: str) -> str:
    with zipfile.ZipFile(bin_path, "r") as zf:
        return zf.read(f"{name}.js").decode("utf-8")


class SingleBuildTests(unittest.TestCase):
    def test_all_patches_applied_and_debug_html_deleted(self):
        with tempfile.TemporaryDirectory() as tmp:
            build = Path(tmp) / "versio-1"
            make_build(build, "game", PATCHABLE_JS)

            result = run_patcher(str(build))

            self.assertEqual(result.returncode, 0, result.stdout)
            self.assertNotIn(FAILED, result.stdout)
            self.assertIn("Summary: 1 builds found, 1 fully ok, 0 with failures", result.stdout)

            self.assertFalse((build / "index-debug.html").exists())
            self.assertFalse((build / "index-nosplash.html").exists())

            js = read_js_from_bin(build / "game.bin", "game")
            self.assertNotIn("registerFocusEventCallback", js)
            self.assertIn("{return 0}", js)

            html = (build / "index.html").read_text(encoding="utf-8")
            self.assertIn("// Commented out: blocking alert()", html)
            self.assertIn("statusElement.textContent", html)

            # Progress bar CSS: every sub-replacement, both directions.
            self.assertIn("-webkit-appearance: none;", html)
            self.assertIn("-moz-appearance: none;", html)
            self.assertIn("border: none;", html)
            self.assertIn("0 4px 4px rgba", html)
            self.assertNotIn("border-radius: 3px;", html)
            self.assertNotIn("0 2px 3px rgba", html)

            # The enhanced script block must be present verbatim, not just a marker.
            self.assertIn(html5_build_patcher.ENHANCED_SCRIPT_BLOCK, html)

    def test_single_bin_argument(self):
        with tempfile.TemporaryDirectory() as tmp:
            build = Path(tmp) / "versio-1"
            make_build(build, "game", PATCHABLE_JS)

            result = run_patcher(str(build / "game.bin"))

            self.assertEqual(result.returncode, 0, result.stdout)
            self.assertIn("Summary: 1 builds found", result.stdout)


class NestedTreeTests(unittest.TestCase):
    def test_finds_exactly_the_builds(self):
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            make_build(root / "game-a" / "versio-1", "game-a", PATCHABLE_JS)
            make_build(root / "nested" / "game-b" / "versio-kotitehtavat", "game-b", PATCHABLE_JS)

            # Non-build folders: no .bin, and a .bin whose js stem does not match.
            (root / "assets").mkdir()
            (root / "assets" / "notes.txt").write_text("nothing", encoding="utf-8")
            decoy = root / "decoy"
            decoy.mkdir()
            with zipfile.ZipFile(decoy / "wrong.bin", "w") as zf:
                zf.writestr("other.js", "var z=0;")

            result = run_patcher(str(root))

            self.assertEqual(result.returncode, 0, result.stdout)
            self.assertIn("Summary: 2 builds found, 2 fully ok, 0 with failures", result.stdout)


class IdempotenceTests(unittest.TestCase):
    def test_rerun_is_a_full_no_op(self):
        with tempfile.TemporaryDirectory() as tmp:
            build = Path(tmp) / "versio-1"
            make_build(build, "game", PATCHABLE_JS)

            first = run_patcher(str(build))
            self.assertEqual(first.returncode, 0, first.stdout)

            bin_bytes = (build / "game.bin").read_bytes()
            html_bytes = (build / "index.html").read_bytes()

            second = run_patcher(str(build))
            self.assertEqual(second.returncode, 0, second.stdout)
            self.assertNotIn(APPLIED, second.stdout)
            self.assertNotIn(FAILED, second.stdout)

            self.assertEqual(bin_bytes, (build / "game.bin").read_bytes())
            self.assertEqual(html_bytes, (build / "index.html").read_bytes())


class FailureTests(unittest.TestCase):
    def test_pattern_drift_yields_failed_and_exit_1(self):
        with tempfile.TemporaryDirectory() as tmp:
            build = Path(tmp) / "versio-1"
            make_build(build, "game", FAILED_JS)

            result = run_patcher(str(build))

            self.assertEqual(result.returncode, 1, result.stdout)
            self.assertIn(f"blur callback removal: {FAILED}", result.stdout)
            self.assertIn("1 with failures", result.stdout)

    def test_zero_build_path_exits_1(self):
        with tempfile.TemporaryDirectory() as tmp:
            empty = Path(tmp) / "empty"
            empty.mkdir()
            (empty / "readme.txt").write_text("no builds here", encoding="utf-8")

            result = run_patcher(str(empty))

            self.assertEqual(result.returncode, 1, result.stdout)
            self.assertIn("No builds found", result.stdout)


if __name__ == "__main__":
    unittest.main(verbosity=2)
