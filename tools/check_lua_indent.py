#!/usr/bin/env python3
"""Report Lua lines whose leading whitespace contains a space (the materials indent with tabs)."""

import re
import sys
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parent.parent
DEFAULT_DIRS = ("solar2d-projects", "homework")
LUA_PATTERNS = ("*.lua", ".luacheckrc")

# Vendored upstream code keeps its own formatting byte-for-byte.
SKIPPED_PARTS = (".scratch",)
SKIPPED_SUFFIXES = ("libs/spriteloop.lua",)
SKIPPED_SEGMENTS = ("/com/ponywolf/",)

_LONG_OPEN_RE = re.compile(r"\[(=*)\[")
_INDENT_RE = re.compile(r"[ \t]*")
# Body runs to the next ``` line at any indent, so fences nested in list items match too.
_FENCE_RE = re.compile(r"^([ \t]*)```lua[^\n]*\n(.*?)^[ \t]*```", re.MULTILINE | re.DOTALL)


# ------------------------------------------------------------------------------
# Lua lexing

def string_lines(text):
    """Per line of text, True when the line starts inside a string literal."""
    flags = [False]
    i = 0
    n = len(text)

    while i < n:
        char = text[i]

        if char == "\n":
            flags.append(False)
            i += 1

        elif text.startswith("--", i):
            match = _LONG_OPEN_RE.match(text, i + 2)

            if match:
                i = _skip_long(text, match.end(), len(match.group(1)), flags, False)
            else:
                end = text.find("\n", i)
                i = n if end < 0 else end

        elif char == "[":
            match = _LONG_OPEN_RE.match(text, i)

            if match:
                i = _skip_long(text, match.end(), len(match.group(1)), flags, True)
            else:
                i += 1

        elif char in "\"'":
            i = _skip_short(text, i + 1, char, flags)

        else:
            i += 1

    return flags


def _skip_long(text, start, level, flags, is_string):
    close = "]" + "=" * level + "]"
    end = text.find(close, start)
    stop = len(text) if end < 0 else end + len(close)
    flags.extend([is_string] * text.count("\n", start, stop))
    return stop


def _skip_short(text, i, quote, flags):
    n = len(text)

    while i < n:
        char = text[i]

        if char == "\\" and i + 1 < n:
            if text[i + 1] == "\n":
                flags.append(True)
            i += 2

        elif char == quote:
            return i + 1

        elif char == "\n":
            # An unterminated string is a Lua syntax error; let the newline end it.
            return i

        else:
            i += 1

    return i


def space_indented_lines(text):
    """1-based numbers of lines indented with a space, outside string literals."""
    hits = []

    for number, (line, in_string) in enumerate(zip(text.split("\n"), string_lines(text)), start=1):
        if not in_string and " " in _INDENT_RE.match(line).group():
            hits.append(number)

    return hits


# ------------------------------------------------------------------------------
# File scanning

def is_skipped(path, target):
    posix = "/" + path.as_posix()

    # Relative so that a target given inside .scratch/ is still scanned.
    if any(part in SKIPPED_PARTS for part in path.relative_to(target).parts):
        return True

    return posix.endswith(SKIPPED_SUFFIXES) or any(segment in posix for segment in SKIPPED_SEGMENTS)


def check_file(path):
    # latin-1 maps every byte to one character, so any encoding scans safely.
    text = path.read_bytes().decode("latin-1")

    if path.suffix != ".md":
        return space_indented_lines(text)

    hits = []

    for match in _FENCE_RE.finditer(text):
        prefix = match.group(1)
        offset = text.count("\n", 0, match.start(2))
        # A fence inside a list item indents every body line by its own prefix, which is not Lua indentation.
        body = "\n".join(line[len(prefix):] if line.startswith(prefix) else line for line in match.group(2).split("\n"))
        hits.extend(number + offset for number in space_indented_lines(body))

    return hits


def candidate_files(target):
    if target.is_file():
        return [target.resolve()]

    patterns = LUA_PATTERNS + ("*.md",)
    return sorted(path for pattern in patterns for path in target.resolve().rglob(pattern))


def main(argv):
    targets = [Path(arg) for arg in argv] or [REPO_ROOT / name for name in DEFAULT_DIRS]
    total = 0

    for target in targets:
        if not target.exists():
            print(f"missing path: {target}", file=sys.stderr)
            return 2

        for path in candidate_files(target):
            if is_skipped(path, target.resolve()):
                continue

            for number in check_file(path):
                print(f"{path}:{number}")
                total += 1

    if total:
        print(f"{total} space-indented Lua line(s)", file=sys.stderr)
        return 1

    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
