#!/usr/bin/env python3
"""Tests for tools/version_diff.py. Run: python3 -B tools/tests/test_version_diff.py"""

import sys
import tempfile
import unittest
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(REPO_ROOT / "tools"))

import version_diff as vd

CFG = vd.load_config()

PNG_BYTES = b"\x89PNG\r\n\x1a\n\x00\x00\x00\rIHDR"
OGG_BYTES = b"OggS\x00\x02\x00\x00"


def numbered(count: int, prefix: str = "line") -> list[str]:
    return [f"{prefix} {index}" for index in range(1, count + 1)]


def as_text(lines: list[str]) -> str:
    return "\n".join(lines) + "\n"


def joined(line: vd.Line) -> str:
    return "".join(segment.text for segment in line.segments)


class DiffTestCase(unittest.TestCase):
    def setUp(self) -> None:
        self._tmp = tempfile.TemporaryDirectory()
        root = Path(self._tmp.name)
        self.old_dir = root / "versio-1"
        self.new_dir = root / "versio-2"
        self.old_dir.mkdir()
        self.new_dir.mkdir()

    def tearDown(self) -> None:
        self._tmp.cleanup()

    def write(self, side: Path, rel: str, content: str | bytes) -> None:
        path = side / rel
        path.parent.mkdir(parents=True, exist_ok=True)

        if isinstance(content, bytes):
            path.write_bytes(content)
        else:
            path.write_bytes(content.encode("utf-8"))

    def run_diff(self) -> vd.VersionDiff:
        return vd.diff_versions(self.old_dir, self.new_dir, CFG)

    def only_file(self) -> vd.FileDiff:
        result = self.run_diff()
        self.assertEqual(len(result.files), 1, [file_diff.display_path for file_diff in result.files])
        return result.files[0]


# ------------------------------------------------------------------------------
# Detection and normalisation

class DetectionTests(DiffTestCase):
    def test_text_and_binary_detection(self) -> None:
        self.write(self.new_dir, "main.lua", "print( 1 )\n")
        self.write(self.new_dir, "blob.dat", b"abc\x00def")
        self.write(self.new_dir, "latin1.txt", "Hyv\xe4\xe4".encode("latin-1"))
        kinds = {file_diff.new_path: file_diff.kind for file_diff in self.run_diff().files}

        self.assertEqual(kinds, {"main.lua": "code", "blob.dat": "binary", "latin1.txt": "binary"})

    def test_line_ending_bom_and_trailing_newline_changes_are_unlisted(self) -> None:
        self.write(self.old_dir, "crlf.lua", "a\r\nb\r\n")
        self.write(self.new_dir, "crlf.lua", "a\nb\n")
        self.write(self.old_dir, "cr.lua", "a\rb")
        self.write(self.new_dir, "cr.lua", "a\nb\n")
        self.write(self.old_dir, "bom.lua", "\ufeffa\nb\n")
        self.write(self.new_dir, "bom.lua", "a\nb")

        self.assertEqual(self.run_diff().files, [])

    def test_media_and_binary_kinds_count_no_lines(self) -> None:
        self.write(self.old_dir, "images/hero.png", PNG_BYTES)
        self.write(self.new_dir, "images/hero.png", PNG_BYTES + b"\x01")
        self.write(self.new_dir, "audio/hit.ogg", OGG_BYTES)
        self.write(self.new_dir, "audio/jump.WAV", b"RIFF\x00\x00WAVE")
        self.write(self.new_dir, "font.ttf", b"\x00\x01\x00\x00")
        result = self.run_diff()
        by_path = {file_diff.display_path: file_diff for file_diff in result.files}

        self.assertEqual(by_path["images/hero.png"].kind, "image")
        self.assertEqual(by_path["images/hero.png"].status, "modified")
        self.assertEqual(by_path["images/hero.png"].old_file, (self.old_dir / "images/hero.png").resolve())
        self.assertEqual(by_path["images/hero.png"].new_file, (self.new_dir / "images/hero.png").resolve())
        self.assertEqual(by_path["audio/hit.ogg"].kind, "audio")
        self.assertEqual(by_path["audio/jump.WAV"].kind, "audio")
        self.assertEqual(by_path["font.ttf"].kind, "binary")

        for file_diff in result.files:
            self.assertEqual((file_diff.added, file_diff.removed, file_diff.sections), (0, 0, []))

        self.assertEqual((result.added, result.removed), (0, 0))

    def test_excluded_dirs_and_patterns_are_skipped_at_any_depth(self) -> None:
        self.write(self.new_dir, "AndroidResources/res/values.xml", "<x/>\n")
        self.write(self.new_dir, "nested/Images.xcassets/Contents.json", "{}\n")
        self.write(self.new_dir, "scripts/__pycache__/m.cpython-312.pyc", b"\x00")
        self.write(self.new_dir, ".scratch/notes.md", "x\n")
        self.write(self.new_dir, "Icon-xxhdpi.png", PNG_BYTES)
        self.write(self.new_dir, "sub/.DS_Store", b"\x00")
        self.write(self.new_dir, "Thumbs.db", b"\x00")
        self.write(self.new_dir, "desktop.ini", "[x]\n")
        self.write(self.new_dir, "tool.pyc", b"\x00")
        self.write(self.new_dir, "main.lua", "x\n")

        self.assertEqual([file_diff.new_path for file_diff in self.run_diff().files], ["main.lua"])


# ------------------------------------------------------------------------------
# Moves

class MoveTests(DiffTestCase):
    def test_identical_content_move_has_no_sections(self) -> None:
        self.write(self.old_dir, "player.lua", as_text(numbered(5)))
        self.write(self.new_dir, "scripts/characters/hero.lua", as_text(numbered(5)))
        file_diff = self.only_file()

        self.assertEqual(file_diff.status, "moved")
        self.assertEqual((file_diff.old_path, file_diff.new_path), ("player.lua", "scripts/characters/hero.lua"))
        self.assertEqual((file_diff.sections, file_diff.added, file_diff.removed), ([], 0, 0))

    def test_identical_binary_move_pairs_by_bytes(self) -> None:
        self.write(self.old_dir, "hero.png", PNG_BYTES)
        self.write(self.new_dir, "images/player.png", PNG_BYTES)
        file_diff = self.only_file()

        self.assertEqual((file_diff.status, file_diff.kind), ("moved", "image"))

    def test_similar_same_basename_move_carries_changes(self) -> None:
        old_lines = numbered(20)
        new_lines = list(old_lines)
        new_lines[9] = "changed line"
        self.write(self.old_dir, "map.lua", as_text(old_lines))
        self.write(self.new_dir, "scripts/map/map.lua", as_text(new_lines))
        file_diff = self.only_file()

        self.assertEqual(file_diff.status, "moved")
        self.assertEqual(file_diff.new_path, "scripts/map/map.lua")
        self.assertEqual((file_diff.added, file_diff.removed), (1, 1))
        self.assertTrue(any(isinstance(section, vd.Hunk) for section in file_diff.sections))

    def test_dissimilar_same_basename_is_not_a_move(self) -> None:
        self.write(self.old_dir, "utils.lua", as_text(numbered(10, "old")))
        self.write(self.new_dir, "lib/utils.lua", as_text(numbered(10, "fresh content")))
        statuses = sorted(file_diff.status for file_diff in self.run_diff().files)

        self.assertEqual(statuses, ["added", "removed"])

    def test_each_file_pairs_once_best_match_first(self) -> None:
        base = numbered(10)
        close = list(base)
        close[0] = "edited"
        far = base[:6] + ["x", "y", "z", "w"]
        self.write(self.old_dir, "a/game.lua", as_text(base))
        self.write(self.new_dir, "b/game.lua", as_text(far))
        self.write(self.new_dir, "c/game.lua", as_text(close))
        by_path = {file_diff.display_path: file_diff for file_diff in self.run_diff().files}

        self.assertEqual(by_path["c/game.lua"].status, "moved")
        self.assertEqual(by_path["c/game.lua"].old_path, "a/game.lua")
        self.assertEqual(by_path["b/game.lua"].status, "added")


# ------------------------------------------------------------------------------
# Hunks, gaps, and inline segments

class HunkTests(DiffTestCase):
    def test_hunks_and_gaps_cover_both_files(self) -> None:
        old_lines = numbered(40)
        new_lines = list(old_lines)
        new_lines[14] = "edited 15"
        new_lines.insert(30, "inserted")
        del new_lines[5]
        self.write(self.old_dir, "main.lua", as_text(old_lines))
        self.write(self.new_dir, "main.lua", as_text(new_lines))
        file_diff = self.only_file()

        self.assertEqual(file_diff.status, "modified")
        self.assertIsInstance(file_diff.sections[0], vd.Gap)
        self.assertIsInstance(file_diff.sections[-1], vd.Gap)
        self.assertEqual(sum(isinstance(section, vd.Hunk) for section in file_diff.sections), 3)

        old_seen: list[int] = []
        new_seen: list[int] = []

        for section in file_diff.sections:
            if isinstance(section, vd.Gap):
                old_seen.extend(range(section.old_start, section.old_start + section.count))
                new_seen.extend(range(section.new_start, section.new_start + section.count))
                continue

            for block in section.blocks:
                for line in block.lines + block.dels + block.adds:
                    if line.old_no is not None:
                        old_seen.append(line.old_no)
                        self.assertEqual(joined(line), old_lines[line.old_no - 1])

                    if line.new_no is not None:
                        new_seen.append(line.new_no)
                        self.assertEqual(joined(line), new_lines[line.new_no - 1])

        self.assertEqual(old_seen, list(range(1, len(old_lines) + 1)))
        self.assertEqual(new_seen, list(range(1, len(new_lines) + 1)))
        self.assertEqual((file_diff.added, file_diff.removed), (2, 2))
        self.assertTrue(file_diff.expandable)
        self.assertEqual(file_diff.new_lines, new_lines)

    def test_small_change_without_gaps_is_not_expandable(self) -> None:
        self.write(self.old_dir, "main.lua", "a\nb\n")
        self.write(self.new_dir, "main.lua", "a\nc\n")
        file_diff = self.only_file()

        self.assertFalse(any(isinstance(section, vd.Gap) for section in file_diff.sections))
        self.assertFalse(file_diff.expandable)
        self.assertIsNone(file_diff.new_lines)

    def test_inline_segments_on_long_single_line_json_edit(self) -> None:
        entries = ",".join(f'{{"id":{index},"name":"tile{index}","solid":false}}' for index in range(200))
        old_line = f'{{"tiles":[{entries}],"width":30}}'
        new_line = old_line.replace('"name":"tile57"', '"name":"kivi"')
        self.write(self.old_dir, "data/level.json", old_line + "\n")
        self.write(self.new_dir, "data/level.json", new_line + "\n")
        block = self.only_file().sections[0].blocks[0]
        del_line = block.dels[0]
        add_line = block.adds[0]

        self.assertEqual(joined(del_line), old_line)
        self.assertEqual(joined(add_line), new_line)
        self.assertEqual([segment.text for segment in del_line.segments if segment.changed], ["tile57"])
        self.assertEqual([segment.text for segment in add_line.segments if segment.changed], ["kivi"])
        self.assertEqual(len(add_line.segments), 3)

    def test_unrelated_paired_lines_stay_unmarked(self) -> None:
        self.write(self.old_dir, "main.lua", "local speed = 10\n")
        self.write(self.new_dir, "main.lua", "print( \"Peli alkaa\" )\n")
        block = self.only_file().sections[0].blocks[0]

        for line in block.dels + block.adds:
            self.assertEqual(len(line.segments), 1)
            self.assertFalse(line.segments[0].changed)

    def test_lines_sharing_only_whitespace_and_punctuation_stay_unmarked(self) -> None:
        old_lines = ["-- Luodaan pelinappula keskelle peliruutua.", "local button = display.newCircle( 480, 320, 64 )"]
        new_lines = ["-- Funktio, joka luo nappulan annettuihin koordinaatteihin.", "local function createButton( x, y )"]
        self.write(self.old_dir, "main.lua", as_text(old_lines))
        self.write(self.new_dir, "main.lua", as_text(new_lines))
        block = self.only_file().sections[0].blocks[0]

        self.assertEqual((len(block.dels), len(block.adds)), (2, 2))

        for line in block.dels + block.adds:
            self.assertEqual([segment.changed for segment in line.segments], [False])

    def test_added_and_removed_code_files_are_single_change_blocks(self) -> None:
        self.write(self.old_dir, "old.lua", "a\nb\n")
        self.write(self.new_dir, "new.lua", "x\ny\nz\n")
        result = self.run_diff()
        by_status = {file_diff.status: file_diff for file_diff in result.files}

        added_block = by_status["added"].sections[0].blocks[0]
        removed_block = by_status["removed"].sections[0].blocks[0]
        self.assertEqual([line.new_no for line in added_block.adds], [1, 2, 3])
        self.assertEqual([line.old_no for line in removed_block.dels], [1, 2])
        self.assertEqual((result.added, result.removed), (3, 2))
        self.assertEqual([file_diff.display_path for file_diff in result.files], ["new.lua", "old.lua"])

    def test_markup_and_finnish_text_pass_through_untouched(self) -> None:
        line = 'print( "</script><b>Hyvää päivää, Åke & Öljy</b>" )'
        self.write(self.new_dir, "teksti.lua", line + "\n")
        self.write(self.new_dir, "tarina/äänet.lua", "-- ääkköset\n")
        result = self.run_diff()
        by_path = {file_diff.display_path: file_diff for file_diff in result.files}

        self.assertEqual(joined(by_path["teksti.lua"].sections[0].blocks[0].adds[0]), line)
        self.assertEqual(joined(by_path["tarina/äänet.lua"].sections[0].blocks[0].adds[0]), "-- ääkköset")


    def test_sequence_matches_pairwise_diffs(self) -> None:
        third_dir = self.old_dir.parent / "versio-kotitehtavat"
        self.write(self.old_dir, "main.lua", "a\n")
        self.write(self.new_dir, "main.lua", "a\nb\n")
        self.write(third_dir, "main.lua", "c\nb\n")
        dirs = [self.old_dir, self.new_dir, third_dir]
        pairwise = [vd.diff_versions(old, new, CFG) for old, new in zip(dirs, dirs[1:])]

        self.assertEqual(vd.diff_sequence(dirs, CFG), pairwise)


# ------------------------------------------------------------------------------
# Maps

class MapTests(DiffTestCase):
    def test_added_and_removed_maps_carry_only_line_count(self) -> None:
        self.write(self.new_dir, "maps/taso.tmx", as_text(numbered(12)))
        self.write(self.old_dir, "data/kartta.json", '{\n"tiledversion":"1.10",\n"layers":[]\n}\n')
        result = self.run_diff()
        by_path = {file_diff.display_path: file_diff for file_diff in result.files}
        added_map = by_path["maps/taso.tmx"]
        removed_map = by_path["data/kartta.json"]

        self.assertEqual((added_map.kind, added_map.status, added_map.line_count, added_map.sections), ("map", "added", 12, []))
        self.assertEqual(added_map.added, 12)
        self.assertEqual((removed_map.kind, removed_map.status, removed_map.line_count, removed_map.sections), ("map", "removed", 4, []))
        self.assertEqual(removed_map.removed, 4)

    def test_plain_json_is_code(self) -> None:
        self.write(self.new_dir, "data/asetukset.json", '{"volume": 1}\n')

        self.assertEqual(self.only_file().kind, "code")

    def test_modified_map_has_hunks_but_no_expansion(self) -> None:
        old_lines = numbered(40)
        new_lines = list(old_lines)
        new_lines[20] = "tile changed"
        self.write(self.old_dir, "tiles.tsx", as_text(old_lines))
        self.write(self.new_dir, "tiles.tsx", as_text(new_lines))
        file_diff = self.only_file()

        self.assertEqual(file_diff.kind, "map")
        self.assertTrue(any(isinstance(section, vd.Hunk) for section in file_diff.sections))
        self.assertTrue(any(isinstance(section, vd.Gap) for section in file_diff.sections))
        self.assertFalse(file_diff.expandable)
        self.assertIsNone(file_diff.new_lines)


if __name__ == "__main__":
    unittest.main()
