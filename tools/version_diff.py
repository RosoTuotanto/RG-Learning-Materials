#!/usr/bin/env python3
"""Line-level diff of two game version folders as plain data for the site generator."""

import difflib
import fnmatch
import json
import os
import re
from dataclasses import dataclass, field
from pathlib import Path, PurePosixPath

_TOOLS_DIR = Path(__file__).resolve().parent
DEFAULT_CONFIG_PATH = _TOOLS_DIR / "web-src" / "diff.json"

ADDED = "added"
REMOVED = "removed"
MODIFIED = "modified"
MOVED = "moved"

CODE = "code"
MAP = "map"
IMAGE = "image"
AUDIO = "audio"
BINARY = "binary"

_TEXT_KINDS = (CODE, MAP)

# Every character falls into exactly one class, so joined tokens rebuild the line.
_TOKEN_RE = re.compile(r"\w+|\s+|[^\w\s]")


# ------------------------------------------------------------------------------
# Data contract

@dataclass
class Segment:
    text: str
    changed: bool


@dataclass
class Line:
    old_no: int | None
    new_no: int | None
    segments: list[Segment]


@dataclass
class Block:
    kind: str
    lines: list[Line] = field(default_factory=list)
    dels: list[Line] = field(default_factory=list)
    adds: list[Line] = field(default_factory=list)


@dataclass
class Hunk:
    blocks: list[Block]


@dataclass
class Gap:
    old_start: int
    new_start: int
    count: int


@dataclass
class FileDiff:
    status: str
    kind: str
    old_path: str | None
    new_path: str | None
    old_file: Path | None
    new_file: Path | None
    added: int = 0
    removed: int = 0
    line_count: int | None = None
    sections: list[Hunk | Gap] = field(default_factory=list)
    new_lines: list[str] | None = None
    expandable: bool = False

    @property
    def display_path(self) -> str:
        return self.new_path if self.new_path is not None else self.old_path


@dataclass
class VersionDiff:
    files: list[FileDiff]
    added: int
    removed: int


@dataclass
class _SourceFile:
    rel: str
    path: Path
    data: bytes
    kind: str
    lines: list[str] | None

    @property
    def content_key(self) -> tuple | bytes:
        return tuple(self.lines) if self.lines is not None else self.data


# ------------------------------------------------------------------------------
# Config

def load_config(path: Path | None = None) -> dict:
    config_path = Path(path) if path is not None else DEFAULT_CONFIG_PATH
    return json.loads(config_path.read_text(encoding="utf-8"))


# ------------------------------------------------------------------------------
# Loading

def _decode_lines(data: bytes) -> tuple[str, list[str]] | None:
    if b"\x00" in data:
        return None

    try:
        text = data.decode("utf-8")
    except UnicodeDecodeError:
        return None

    text = text.removeprefix("\ufeff").replace("\r\n", "\n").replace("\r", "\n")
    return text, text.splitlines()


def _classify(rel: str, decoded: tuple[str, list[str]] | None, cfg: dict) -> str:
    suffix = PurePosixPath(rel).suffix.lower()

    if suffix in cfg["imageExtensions"]:
        return IMAGE

    if suffix in cfg["audioExtensions"]:
        return AUDIO

    if decoded is None:
        return BINARY

    if suffix in cfg["mapExtensions"]:
        return MAP

    if suffix == ".json" and cfg["tiledJsonMarker"] in decoded[0]:
        return MAP

    return CODE


def _is_excluded_file(name: str, cfg: dict) -> bool:
    return any(fnmatch.fnmatchcase(name, pattern) for pattern in cfg["excludedFiles"])


def _collect(root: Path, cfg: dict) -> dict[str, _SourceFile]:
    excluded_dirs = set(cfg["excludedDirs"])
    files: dict[str, _SourceFile] = {}

    base = root.resolve()

    for dirpath, dirnames, filenames in os.walk(base):
        dirnames[:] = [name for name in dirnames if name not in excluded_dirs]

        for name in filenames:
            if _is_excluded_file(name, cfg):
                continue

            path = Path(dirpath) / name
            rel = path.relative_to(base).as_posix()
            data = path.read_bytes()
            decoded = _decode_lines(data)
            kind = _classify(rel, decoded, cfg)
            lines = decoded[1] if decoded is not None and kind in _TEXT_KINDS else None
            files[rel] = _SourceFile(rel, path, data, kind, lines)

    return files


# ------------------------------------------------------------------------------
# Inline segments

def _merge_marks(marks: list[tuple[str, bool]]) -> list[Segment]:
    segments: list[Segment] = []

    for text, changed in marks:
        if segments and segments[-1].changed == changed:
            segments[-1].text += text
        else:
            segments.append(Segment(text, changed))

    return segments


def _non_space(tokens: list[str]) -> list[str]:
    return [token for token in tokens if not token.isspace()]


def _inline_segments(old_text: str, new_text: str, threshold: float) -> tuple[list[Segment], list[Segment]] | None:
    old_tokens = _TOKEN_RE.findall(old_text)
    new_tokens = _TOKEN_RE.findall(new_text)
    # Shared whitespace makes unrelated lines look similar, so only words and symbols decide the pairing.
    words = difflib.SequenceMatcher(None, _non_space(old_tokens), _non_space(new_tokens), autojunk=False)

    # The cheap upper bounds reject unrelated pairs before the quadratic match.
    if words.real_quick_ratio() < threshold or words.quick_ratio() < threshold or words.ratio() < threshold:
        return None

    matcher = difflib.SequenceMatcher(None, old_tokens, new_tokens, autojunk=False)
    old_marks: list[tuple[str, bool]] = []
    new_marks: list[tuple[str, bool]] = []

    for tag, i1, i2, j1, j2 in matcher.get_opcodes():
        changed = tag != "equal"
        old_marks.extend((token, changed) for token in old_tokens[i1:i2])
        new_marks.extend((token, changed) for token in new_tokens[j1:j2])

    return _merge_marks(old_marks), _merge_marks(new_marks)


# ------------------------------------------------------------------------------
# Line diff

def _plain(text: str) -> list[Segment]:
    return [Segment(text, False)]


def _change_block(old: list[str], new: list[str], opcode: tuple, cfg: dict) -> Block:
    _, i1, i2, j1, j2 = opcode
    dels = [Line(index + 1, None, _plain(old[index])) for index in range(i1, i2)]
    adds = [Line(None, index + 1, _plain(new[index])) for index in range(j1, j2)]

    for del_line, add_line in zip(dels, adds):
        pair = _inline_segments(del_line.segments[0].text, add_line.segments[0].text, cfg["inlineSimilarity"])

        if pair is not None:
            del_line.segments, add_line.segments = pair

    return Block("change", dels=dels, adds=adds)


def _context_block(old: list[str], opcode: tuple) -> Block:
    _, i1, i2, j1, _ = opcode
    lines = [Line(i1 + offset + 1, j1 + offset + 1, _plain(old[i1 + offset])) for offset in range(i2 - i1)]
    return Block("context", lines=lines)


def _common_edges(old: list[str], new: list[str]) -> tuple[int, int]:
    limit = min(len(old), len(new))
    prefix = 0

    while prefix < limit and old[prefix] == new[prefix]:
        prefix += 1

    suffix = 0

    while suffix < limit - prefix and old[-1 - suffix] == new[-1 - suffix]:
        suffix += 1

    return prefix, suffix


def _grouped_opcodes(old: list[str], new: list[str], context: int) -> list[list[tuple]]:
    # Matching only the changed middle (plus context) keeps maps with thousands of repeated lines fast.
    prefix, suffix = _common_edges(old, new)
    start = max(0, prefix - context)
    trim_end = max(0, suffix - context)
    matcher = difflib.SequenceMatcher(None, old[start:len(old) - trim_end], new[start:len(new) - trim_end], autojunk=False)
    groups = []

    for group in matcher.get_grouped_opcodes(context):
        groups.append([(tag, i1 + start, i2 + start, j1 + start, j2 + start) for tag, i1, i2, j1, j2 in group])

    return groups


def _text_sections(old: list[str], new: list[str], cfg: dict) -> tuple[list[Hunk | Gap], int, int]:
    sections: list[Hunk | Gap] = []
    added = 0
    removed = 0
    old_pos = 0
    new_pos = 0

    for group in _grouped_opcodes(old, new, cfg["contextLines"]):
        hidden = group[0][1] - old_pos

        if hidden > 0:
            sections.append(Gap(old_pos + 1, new_pos + 1, hidden))

        blocks: list[Block] = []

        for opcode in group:
            tag, i1, i2, j1, j2 = opcode

            if tag == "equal":
                if i2 > i1:
                    blocks.append(_context_block(old, opcode))
            else:
                blocks.append(_change_block(old, new, opcode, cfg))
                added += j2 - j1
                removed += i2 - i1

        sections.append(Hunk(blocks))
        old_pos = group[-1][2]
        new_pos = group[-1][4]

    tail = len(old) - old_pos

    if tail > 0:
        sections.append(Gap(old_pos + 1, new_pos + 1, tail))

    return sections, added, removed


def _line_similarity(old: list[str], new: list[str]) -> float:
    matcher = difflib.SequenceMatcher(None, old, new, autojunk=False)
    return matcher.ratio()


# ------------------------------------------------------------------------------
# File diffs

def _single_side(source: _SourceFile, status: str) -> FileDiff:
    is_added = status == ADDED
    file_diff = FileDiff(
        status=status,
        kind=source.kind,
        old_path=None if is_added else source.rel,
        new_path=source.rel if is_added else None,
        old_file=None if is_added else source.path,
        new_file=source.path if is_added else None,
    )

    if source.lines is None:
        return file_diff

    count = len(source.lines)
    file_diff.line_count = count

    if is_added:
        file_diff.added = count
    else:
        file_diff.removed = count

    if source.kind == CODE and count:
        if is_added:
            lines = [Line(None, index + 1, _plain(text)) for index, text in enumerate(source.lines)]
            block = Block("change", adds=lines)
        else:
            lines = [Line(index + 1, None, _plain(text)) for index, text in enumerate(source.lines)]
            block = Block("change", dels=lines)

        file_diff.sections = [Hunk([block])]

    return file_diff


def _paired(old: _SourceFile, new: _SourceFile, status: str, cfg: dict) -> FileDiff:
    file_diff = FileDiff(
        status=status,
        kind=new.kind,
        old_path=old.rel,
        new_path=new.rel,
        old_file=old.path,
        new_file=new.path,
    )

    if old.lines is None or new.lines is None:
        return file_diff

    file_diff.line_count = len(new.lines)

    if old.lines == new.lines:
        return file_diff

    sections, added, removed = _text_sections(old.lines, new.lines, cfg)
    file_diff.sections = sections
    file_diff.added = added
    file_diff.removed = removed

    has_gaps = any(isinstance(section, Gap) for section in sections)

    # Map files run to thousands of lines, so their hidden runs stay hidden.
    if new.kind == CODE and has_gaps:
        file_diff.expandable = True
        file_diff.new_lines = list(new.lines)

    return file_diff


def _pair_moves(removed: dict[str, _SourceFile], added: dict[str, _SourceFile], cfg: dict) -> list[tuple[_SourceFile, _SourceFile]]:
    pairs: list[tuple[_SourceFile, _SourceFile]] = []
    added_by_content: dict[tuple | bytes, list[str]] = {}

    for rel in sorted(added):
        added_by_content.setdefault(added[rel].content_key, []).append(rel)

    for rel in sorted(removed):
        candidates = added_by_content.get(removed[rel].content_key)

        if candidates:
            new_rel = candidates.pop(0)
            pairs.append((removed.pop(rel), added.pop(new_rel)))

    scored: list[tuple[float, str, str]] = []

    for old_rel, old_file in removed.items():
        if old_file.lines is None:
            continue

        old_name = PurePosixPath(old_rel).name

        for new_rel, new_file in added.items():
            if new_file.lines is None or PurePosixPath(new_rel).name != old_name:
                continue

            score = _line_similarity(old_file.lines, new_file.lines)

            if score >= cfg["moveSimilarity"]:
                scored.append((score, old_rel, new_rel))

    scored.sort(key=lambda entry: (-entry[0], entry[1], entry[2]))

    for _, old_rel, new_rel in scored:
        if old_rel in removed and new_rel in added:
            pairs.append((removed.pop(old_rel), added.pop(new_rel)))

    return pairs


def _diff_snapshots(old_files: dict[str, _SourceFile], new_files: dict[str, _SourceFile], cfg: dict) -> VersionDiff:
    files: list[FileDiff] = []

    for rel in old_files.keys() & new_files.keys():
        old = old_files[rel]
        new = new_files[rel]

        if old.content_key != new.content_key:
            files.append(_paired(old, new, MODIFIED, cfg))

    removed = {rel: source for rel, source in old_files.items() if rel not in new_files}
    added = {rel: source for rel, source in new_files.items() if rel not in old_files}

    for old, new in _pair_moves(removed, added, cfg):
        files.append(_paired(old, new, MOVED, cfg))

    files.extend(_single_side(source, REMOVED) for source in removed.values())
    files.extend(_single_side(source, ADDED) for source in added.values())
    files.sort(key=lambda file_diff: file_diff.display_path)

    return VersionDiff(
        files=files,
        added=sum(file_diff.added for file_diff in files),
        removed=sum(file_diff.removed for file_diff in files),
    )


def diff_versions(old_dir: Path, new_dir: Path, cfg: dict) -> VersionDiff:
    return _diff_snapshots(_collect(Path(old_dir), cfg), _collect(Path(new_dir), cfg), cfg)


def diff_sequence(version_dirs: list[Path], cfg: dict) -> list[VersionDiff]:
    """Diffs each folder against the one before it, reading every folder once."""
    diffs: list[VersionDiff] = []
    previous = None

    for version_dir in version_dirs:
        current = _collect(Path(version_dir), cfg)

        if previous is not None:
            diffs.append(_diff_snapshots(previous, current, cfg))

        previous = current

    return diffs
