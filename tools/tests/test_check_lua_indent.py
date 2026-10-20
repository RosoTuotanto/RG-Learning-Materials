#!/usr/bin/env python3
"""Tests for tools/check_lua_indent.py. Run: python3 -B tools/tests/test_check_lua_indent.py"""

import contextlib
import io
import sys
import tempfile
import unittest
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(REPO_ROOT / "tools"))

import check_lua_indent as gate


class GateTestCase(unittest.TestCase):
    def setUp(self) -> None:
        self._tmp = tempfile.TemporaryDirectory()
        self.root = Path(self._tmp.name)

    def tearDown(self) -> None:
        self._tmp.cleanup()

    def write(self, rel: str, content: str) -> Path:
        path = self.root / rel
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_bytes(content.encode("utf-8"))
        return path

    def run_gate(self) -> tuple[int, list[str]]:
        output = io.StringIO()

        with contextlib.redirect_stdout(output), contextlib.redirect_stderr(io.StringIO()):
            code = gate.main([str(self.root)])

        return code, output.getvalue().splitlines()


class LuaFileTests(GateTestCase):
    def test_space_indented_line_is_reported(self) -> None:
        path = self.write("game/main.lua", "if a then\r\n    b()\r\nend\r\n")
        code, hits = self.run_gate()

        self.assertEqual(code, 1)
        self.assertEqual(hits, [f"{path.resolve()}:2"])

    def test_tab_indentation_passes(self) -> None:
        self.write("game/main.lua", "if a then\n\tif b then\n\t\tc()\n\tend\nend\n")

        self.assertEqual(self.run_gate(), (0, []))

    def test_space_lines_inside_long_strings_are_skipped(self) -> None:
        self.write("game/main.lua", 'local s = [==[\n    kept ]] still\n]==]\nlocal t = "a\\\n    b"\n--[[\n\tcomment\n]]\n')

        self.assertEqual(self.run_gate(), (0, []))

    def test_space_lines_inside_long_comments_are_reported(self) -> None:
        self.write("game/main.lua", "--[[\n    note\n]]\n")

        self.assertEqual(self.run_gate()[0], 1)

    def test_luacheckrc_is_scanned(self) -> None:
        path = self.write("game/.luacheckrc", "std = {\n  globals = {},\n}\n")
        code, hits = self.run_gate()

        self.assertEqual(code, 1)
        self.assertEqual(hits, [f"{path.resolve()}:2"])

    def test_vendored_and_scratch_files_are_skipped(self) -> None:
        self.write("game/com/ponywolf/ponytiled.lua", "if a then\n  b()\nend\n")
        self.write("demos/animations/libs/spriteloop.lua", "if a then\n  b()\nend\n")
        self.write("game/.scratch/old.lua", "if a then\n  b()\nend\n")

        self.assertEqual(self.run_gate(), (0, []))


class MarkdownTests(GateTestCase):
    def test_lua_fence_is_reported_with_file_line(self) -> None:
        path = self.write("docs/guide.md", "Intro\n\n```lua\nif a then\n    b()\nend\n```\n\n```json\n{\n    \"a\": 1\n}\n```\n")
        code, hits = self.run_gate()

        self.assertEqual(code, 1)
        self.assertEqual(hits, [f"{path.resolve()}:5"])

    def test_fence_nested_in_list_item_ignores_its_prefix(self) -> None:
        self.write("README.md", "1. Step:\n\n   ```lua\n   if a then\n   \tb()\n   end\n   ```\n")

        self.assertEqual(self.run_gate(), (0, []))

    def test_fence_nested_in_list_item_reports_space_indent(self) -> None:
        path = self.write("README.md", "- Step:\n\n  ```lua\n  if a then\n      b()\n  end\n  ```\n")
        code, hits = self.run_gate()

        self.assertEqual(code, 1)
        self.assertEqual(hits, [f"{path.resolve()}:5"])


if __name__ == "__main__":
    unittest.main()
