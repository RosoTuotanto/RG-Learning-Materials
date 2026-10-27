#!/usr/bin/env python3
"""Build the skeletal manifest.json and the two lesson images from the exported art, the rig in
tools/character-rig.json and the names, variant count and plays in data/animations.lua. Output
is deterministic.

Run from the demo folder:

    python3 -B tools/build_character.py [--preview DIR [--preview-only] [--only NAME ...]]
"""

import argparse
import dataclasses
import itertools
import json
import math
import re
import subprocess
import sys
from collections.abc import Callable
from dataclasses import dataclass
from pathlib import Path

from PIL import Image, ImageDraw, ImageFont

DEMO_ROOT = Path(__file__).resolve().parent.parent
SHEET_PATH = DEMO_ROOT / "assets" / "images" / "character-sheet.png"
SHEET_DATA_PATH = SHEET_PATH.with_suffix(".json")
SKELETAL_ROOT = DEMO_ROOT / "assets" / "skeletal"
PARTS_ROOT = SKELETAL_ROOT / "parts"
MANIFEST_PATH = SKELETAL_ROOT / "manifest.json"
RIG_PATH = DEMO_ROOT / "tools" / "character-rig.json"
ANIMATIONS_PATH = DEMO_ROOT / "data" / "animations.lua"
LESSON_IMAGES = DEMO_ROOT.parents[3] / "lms" / "5-narratiivi-ja-pelitaide" / "images"

LESSON_SCALE = 4
LESSON_SHEET_SCALE = 2
PREVIEW_SCALE = 4
PREVIEW_COLUMNS = 8
ONION_ALPHA = 0.35
LUA_TIMEOUT = 30

# Skeletal frame rate; the sprite sheet's durations are whole exposures at the same rate.
FPS = 12
EXPOSURE_MS = 1000 / FPS

SPRITE_SEQUENCES = ("idle", "walk", "jump")
SKELETAL_FAMILIES = ("idle", "walk", "jump")
PREVIEW_NAMES = [*SPRITE_SEQUENCES, *(f"skeletal-{family}" for family in SKELETAL_FAMILIES), "parts"]
TAG_DIRECTIONS = ("forward", "reverse", "pingpong", "pingpong_reverse")

TRANSPARENT = (0, 0, 0, 0)
LESSON_BACKGROUND = (238, 236, 230, 255)
LESSON_GRID = (176, 172, 164, 255)
LESSON_TEXT = (40, 40, 40, 255)
PIVOT_MARK = (220, 30, 60, 255)

NAME_PATTERN = re.compile(r"[A-Za-z0-9_-]+")

# The parts the keyframes drive by name; character-rig.json must define exactly these.
ROOT = "hips"
SIDES = ("near", "far")
PART_IDS = {
    "torso",
    "head",
    "eyes",
    "mouth",
    "scarf_knot",
    "scarf_1",
    "scarf_2",
    "scarf_3",
    *(f"{kind}_{side}_{segment}" for kind in ("arm", "leg") for side in SIDES for segment in ("upper", "lower")),
    *(f"{kind}_{side}" for kind in ("hand", "foot") for side in SIDES),
}
SWAP_STATES = {
    "eyes": {"open", "closed"},
    "mouth": {"neutral", "effort"},
    "hand_near": {"open", "fist"},
    "hand_far": {"open", "fist"},
}
FOLLOWERS = ("scarf_1", "scarf_2", "scarf_3")
FEET = tuple(f"foot_{side}" for side in SIDES)

# A swinging foot passes at least this far above the planted one, so it never scuffs the
# ground or lifts the body.
CLEARANCE = 0.75

# An extended leg reaches this share of its full length, so its knee still bends forward.
STRAIGHT = 0.995

BLINK_FRAMES = 2


class ArtError(Exception):
    """A malformed or missing input file; the message names the file and the problem."""


class PoseError(Exception):
    """A keyframe the rig cannot reach."""


# --------------------------------------------------------------------------------------------
# Reading the inputs


def art_error(path: Path, line: int | None, message: str) -> ArtError:
    where = f"{path}:{line}" if line else str(path)

    return ArtError(f"{where}: {message}")


def line_of(text: str, needle: str) -> int | None:
    for number, line in enumerate(text.splitlines(), start=1):
        if needle in line:
            return number

    return None


def read_text(path: Path) -> str:
    if not path.is_file():
        raise art_error(path, None, "file is missing")

    return path.read_text(encoding="utf-8")


def read_json(path: Path) -> tuple[object, str]:
    text = read_text(path)

    def unique_keys(pairs: list[tuple[str, object]]) -> dict:
        seen = {}

        for key, value in pairs:
            if key in seen:
                raise art_error(path, line_of(text, json.dumps(key, ensure_ascii=False)), f"key {key!r} appears twice")

            seen[key] = value

        return seen

    try:
        return json.loads(text, object_pairs_hook=unique_keys), text
    except json.JSONDecodeError as error:
        raise art_error(path, error.lineno, f"invalid JSON: {error.msg}") from error


def read_png(path: Path) -> Image.Image:
    if not path.is_file():
        raise art_error(path, None, "file is missing")

    try:
        with Image.open(path) as image:
            return image.convert("RGBA")
    except OSError as error:
        raise art_error(path, None, f"not a readable image: {error}") from error


def is_number(value: object) -> bool:
    return isinstance(value, (int, float)) and not isinstance(value, bool)


def is_count(value: object, minimum: int = 1) -> bool:
    return isinstance(value, int) and not isinstance(value, bool) and value >= minimum


def as_point(value: object, path: Path, line: int | None, what: str) -> tuple[float, float]:
    if not isinstance(value, list) or len(value) != 2 or not all(is_number(item) for item in value):
        raise art_error(path, line, f"{what} must be [x, y] numbers, got {value!r}")

    return (float(value[0]), float(value[1]))


@dataclass(frozen=True)
class Tag:
    name: str
    first: int
    last: int
    direction: str


@dataclass
class Sheet:
    image: Image.Image
    frame_width: int
    frame_height: int
    durations: list[int]
    tags: dict[str, Tag]

    @property
    def columns(self) -> int:
        return self.image.width // self.frame_width

    def frame(self, index: int) -> Image.Image:
        left = (index % self.columns) * self.frame_width
        top = (index // self.columns) * self.frame_height

        return self.image.crop((left, top, left + self.frame_width, top + self.frame_height))

    def played(self, name: str) -> list[int]:
        """The tag's frame indices in the order its direction plays them, once round."""
        tag = self.tags[name]
        forward = list(range(tag.first, tag.last + 1))
        backward = forward[::-1]

        return {
            "forward": forward,
            "reverse": backward,
            "pingpong": forward + forward[-2:0:-1],
            "pingpong_reverse": backward + backward[-2:0:-1],
        }[tag.direction]


def load_sheet(png_path: Path = SHEET_PATH, data_path: Path = SHEET_DATA_PATH) -> Sheet:
    """The uniform-grid sheet and its Aseprite json-hash export."""
    image = read_png(png_path)
    data, text = read_json(data_path)

    if not isinstance(data, dict) or not isinstance(data.get("frames"), dict) or not isinstance(data.get("meta"), dict):
        raise art_error(data_path, 1, 'expected Aseprite json-hash: an object with "frames" (an object) and "meta"')

    meta = data["meta"]
    size = meta.get("size")

    if not isinstance(size, dict) or not is_count(size.get("w")) or not is_count(size.get("h")):
        raise art_error(data_path, line_of(text, '"size"'), "meta.size must be {\"w\": .., \"h\": ..} positive integers")

    if (size["w"], size["h"]) != image.size:
        raise art_error(data_path, line_of(text, '"size"'), f"meta.size is {size['w']}x{size['h']} but {png_path.name} is {image.width}x{image.height}")

    if "image" in meta and meta["image"] != png_path.name:
        raise art_error(data_path, line_of(text, '"image"'), f"meta.image is {meta['image']!r}, expected {png_path.name!r}")

    if not data["frames"]:
        raise art_error(data_path, line_of(text, '"frames"'), "frames is empty")

    frame_size = None
    durations = []

    for index, (key, entry) in enumerate(data["frames"].items()):
        line = line_of(text, json.dumps(key, ensure_ascii=False))
        rect = entry.get("frame") if isinstance(entry, dict) else None

        if not isinstance(rect, dict) or not all(is_count(rect.get(axis), 0) for axis in ("x", "y", "w", "h")):
            raise art_error(data_path, line, f"frame {key!r}: frame must be {{x, y, w, h}} whole numbers")

        if entry.get("rotated") or entry.get("trimmed"):
            raise art_error(data_path, line, f"frame {key!r}: rotated or trimmed frames do not fit a uniform grid; export untrimmed")

        if not is_count(entry.get("duration")):
            raise art_error(data_path, line, f"frame {key!r}: duration must be a positive whole number of milliseconds, got {entry.get('duration')!r}")

        if frame_size is None:
            frame_size = (rect["w"], rect["h"])

            if frame_size[0] < 1 or frame_size[1] < 1 or image.width % frame_size[0] or image.height % frame_size[1]:
                raise art_error(data_path, line, f"frame size {frame_size[0]}x{frame_size[1]} does not tile the {image.width}x{image.height} sheet")

        columns = image.width // frame_size[0]
        expected = ((index % columns) * frame_size[0], (index // columns) * frame_size[1], *frame_size)
        actual = (rect["x"], rect["y"], rect["w"], rect["h"])

        if actual != expected:
            raise art_error(data_path, line, f"frame {key!r} is at {actual}, a uniform row-major grid puts frame {index} at {expected}")

        if expected[1] + frame_size[1] > image.height:
            raise art_error(data_path, line, f"frame {key!r} lies outside the {image.width}x{image.height} sheet")

        durations.append(entry["duration"])

    tags = {}

    if not isinstance(meta.get("frameTags"), list):
        raise art_error(data_path, line_of(text, '"meta"'), "meta.frameTags must be a list")

    for tag in meta["frameTags"]:
        name = tag.get("name") if isinstance(tag, dict) else None
        line = line_of(text, json.dumps(name)) if isinstance(name, str) else line_of(text, '"frameTags"')

        if not isinstance(name, str) or not NAME_PATTERN.fullmatch(name):
            raise art_error(data_path, line, f"frame tag name {name!r} must use only letters, digits, - and _")

        if name in tags:
            raise art_error(data_path, line, f"frame tag {name!r} appears twice")

        first = tag.get("from")
        last = tag.get("to")

        if not is_count(first, 0) or not is_count(last, 0) or not first <= last < len(durations):
            raise art_error(data_path, line, f"frame tag {name!r}: from {first!r} and to {last!r} must be frame indices with from <= to < {len(durations)}")

        if tag.get("direction") not in TAG_DIRECTIONS:
            raise art_error(data_path, line, f"frame tag {name!r}: direction {tag.get('direction')!r} is not one of {', '.join(TAG_DIRECTIONS)}")

        tags[name] = Tag(name, first, last, tag["direction"])

    return Sheet(image, frame_size[0], frame_size[1], durations, tags)


@dataclass(frozen=True)
class Follow:
    """Procedural follow-through: a lagged share of the source's rotation plus a trail angle
    from the source's speed, tipping the part backward by direction."""

    source: str
    lag: float
    rotation: float
    drag: float
    fall: float
    direction: int
    low: float
    high: float


@dataclass(frozen=True)
class RigPart:
    id: str
    parent: str
    joint: tuple[float, float]
    pivot: tuple[float, float]
    states: dict[str, str]
    default: str
    heel: tuple[float, float] | None
    toe: tuple[float, float] | None
    follow: Follow | None

    @property
    def layer(self) -> str:
        return self.states[self.default]


@dataclass
class Rig:
    canvas: tuple[int, int]
    feet_row: int
    hip_x: float
    parts: list[RigPart]
    images: dict[str, Image.Image]

    def __post_init__(self) -> None:
        self.by_id = {part.id: part for part in self.parts}
        self.solve_order = []
        placed = {ROOT}

        while len(self.solve_order) < len(self.parts):
            ready = [part.id for part in self.parts if part.id not in placed and part.parent in placed]

            if not ready:
                raise ArtError(f"{RIG_PATH}: the parent chain loops through {', '.join(part.id for part in self.parts if part.id not in placed)}")

            self.solve_order += ready
            placed.update(ready)

    def image(self, part_id: str, state: str | None = None) -> Image.Image:
        part = self.by_id[part_id]

        return self.images[part.states[state or part.default]]


def rig_follow(value: object, path: Path, line: int | None, part_id: str) -> Follow:
    keys = {"source", "lag", "rotation", "drag", "fall", "direction", "min", "max"}

    if not isinstance(value, dict) or set(value) != keys:
        raise art_error(path, line, f"{part_id}: follow must have exactly {', '.join(sorted(keys))}")

    if not isinstance(value["source"], str):
        raise art_error(path, line, f"{part_id}: follow source must be a part id")

    for key in keys - {"source"}:
        if not is_number(value[key]):
            raise art_error(path, line, f"{part_id}: follow {key} must be a number, got {value[key]!r}")

    if value["direction"] not in (1, -1) or value["lag"] < 0 or value["min"] > value["max"]:
        raise art_error(path, line, f"{part_id}: follow needs direction 1 or -1, lag >= 0 and min <= max")

    return Follow(value["source"], float(value["lag"]), float(value["rotation"]), float(value["drag"]), float(value["fall"]), value["direction"], float(value["min"]), float(value["max"]))


def load_rig(path: Path = RIG_PATH, parts_root: Path = PARTS_ROOT) -> Rig:
    """The rig description and every layer image it names."""
    data, text = read_json(path)

    if not isinstance(data, dict) or set(data) != {"canvas", "feetRow", "hipX", "parts"}:
        raise art_error(path, 1, 'expected an object with exactly "canvas", "feetRow", "hipX" and "parts"')

    canvas = data["canvas"]

    if not isinstance(canvas, dict) or not is_count(canvas.get("width")) or not is_count(canvas.get("height")):
        raise art_error(path, line_of(text, '"canvas"'), "canvas must be {\"width\": .., \"height\": ..} positive integers")

    if not is_count(data["feetRow"]) or data["feetRow"] > canvas["height"]:
        raise art_error(path, line_of(text, '"feetRow"'), f"feetRow must be a positive integer inside the {canvas['height']}-pixel canvas")

    if not is_number(data["hipX"]):
        raise art_error(path, line_of(text, '"hipX"'), "hipX must be a number")

    if not isinstance(data["parts"], list):
        raise art_error(path, line_of(text, '"parts"'), "parts must be a list in draw order, back to front")

    parts = []
    known = {"id", "parent", "joint", "pivot", "image", "images", "default", "heel", "toe", "follow"}

    for entry in data["parts"]:
        part_id = entry.get("id") if isinstance(entry, dict) else None
        line = line_of(text, f'"id": "{part_id}"') if isinstance(part_id, str) else line_of(text, '"parts"')

        if not isinstance(part_id, str) or part_id not in PART_IDS:
            raise art_error(path, line, f"unknown part {part_id!r}; the keyframes drive {', '.join(sorted(PART_IDS))}")

        if any(part.id == part_id for part in parts):
            raise art_error(path, line, f"part {part_id} appears twice")

        if set(entry) - known:
            raise art_error(path, line, f"{part_id}: unknown keys {', '.join(sorted(set(entry) - known))}")

        parent = entry.get("parent")

        if parent != ROOT and parent not in PART_IDS:
            raise art_error(path, line, f"{part_id}: parent {parent!r} is not {ROOT!r} or a part id")

        if "image" in entry and "images" not in entry and "default" not in entry:
            states = {"": entry["image"]}
            default = ""
        elif "images" in entry and "image" not in entry and isinstance(entry["images"], dict) and entry.get("default") in entry["images"]:
            states = dict(entry["images"])
            default = entry["default"]
        else:
            raise art_error(path, line, f'{part_id}: give one "image", or "images" (state to layer) with a "default" state among them')

        if set(states) != SWAP_STATES.get(part_id, {""}):
            wanted = ", ".join(sorted(SWAP_STATES[part_id])) if part_id in SWAP_STATES else 'one "image"'
            raise art_error(path, line, f"{part_id}: images must be {wanted}")

        for layer in states.values():
            if not isinstance(layer, str) or not NAME_PATTERN.fullmatch(layer):
                raise art_error(path, line, f"{part_id}: layer name {layer!r} must use only letters, digits, - and _")

        is_foot = part_id in FEET

        if is_foot != ("heel" in entry and "toe" in entry) or (not is_foot and ("heel" in entry or "toe" in entry)):
            raise art_error(path, line, f"{part_id}: heel and toe belong on {' and '.join(FEET)}, and both feet need them")

        if (part_id in FOLLOWERS) != ("follow" in entry):
            raise art_error(path, line, f"{part_id}: follow belongs on {', '.join(FOLLOWERS)}, and each of them needs it")

        parts.append(RigPart(
            id=part_id,
            parent=parent,
            joint=as_point(entry.get("joint"), path, line, f"{part_id} joint"),
            pivot=as_point(entry.get("pivot"), path, line, f"{part_id} pivot"),
            states=states,
            default=default,
            heel=as_point(entry["heel"], path, line, f"{part_id} heel") if is_foot else None,
            toe=as_point(entry["toe"], path, line, f"{part_id} toe") if is_foot else None,
            follow=rig_follow(entry["follow"], path, line, part_id) if "follow" in entry else None,
        ))

    missing = PART_IDS - {part.id for part in parts}

    if missing:
        raise art_error(path, line_of(text, '"parts"'), f"missing parts: {', '.join(sorted(missing))}")

    by_id = {part.id: part for part in parts}

    for chain in [("hips", f"leg_{side}_upper", f"leg_{side}_lower", f"foot_{side}") for side in SIDES] + [("hips", "torso")]:
        for parent, child in zip(chain, chain[1:]):
            if by_id[child].parent != parent:
                raise art_error(path, line_of(text, f'"id": "{child}"'), f"{child}: parent must be {parent}; the inverse kinematics and grounding rely on it")

    for part in parts:
        if part.follow:
            source = part.follow.source

            if source not in by_id or source in FOLLOWERS:
                raise art_error(path, line_of(text, f'"id": "{part.id}"'), f"{part.id}: follow source {source!r} must be a part that is not itself a follower")

        elif part.parent in FOLLOWERS:
            raise art_error(path, line_of(text, f'"id": "{part.id}"'), f"{part.id}: only followers may hang from the follower {part.parent}")

    images = {}

    for part in parts:
        sizes = set()

        for layer in part.states.values():
            images[layer] = read_png(parts_root / f"{layer}.png")
            sizes.add(images[layer].size)

        if len(sizes) > 1:
            raise art_error(parts_root, None, f"{part.id}: its images {', '.join(part.states.values())} differ in size; the runtime keeps one pivot per part")

    return Rig((canvas["width"], canvas["height"]), data["feetRow"], float(data["hipX"]), parts, images)


@dataclass(frozen=True)
class Sequence:
    time: float
    frames: list[int]
    loop_count: int


@dataclass(frozen=True)
class AnimationData:
    names: list[str]
    variants: int
    plays: dict[str, int]
    sheet: dict
    sequences: dict[str, Sequence]


# Prints data/animations.lua one record per line, space-separated.
LUA_DATA = """
local animations = dofile( "data/animations.lua" )
local skeletal = animations.skeletal
local sheet = animations.sheet

io.write( "names ", table.concat( skeletal.names, " " ), "\\n" )

io.write( "variants ", tostring( skeletal.variants ), "\\n" )

for i = 1, #skeletal.names do
	local name = skeletal.names[i]
	io.write( "plays ", name, " ", tostring( skeletal.plays and skeletal.plays[name] ), "\\n" )
end

io.write( "sheet ", sheet.file, " ", sheet.width, " ", sheet.height, " ", sheet.numFrames, " ", sheet.feetRow, "\\n" )

for i = 1, #animations.names do
	local name = animations.names[i]
	local sequence = animations.sequences[name]
	io.write( "sequence ", name, " ", sequence.time, " ", sequence.loopCount, " ", table.concat( sequence.frames, "," ), "\\n" )
end
"""


def load_animation_data(path: Path = ANIMATIONS_PATH) -> AnimationData:
    """data/animations.lua exactly as the app sees it, read by running Lua."""
    try:
        result = subprocess.run(["lua5.1", "-e", LUA_DATA], cwd=DEMO_ROOT, capture_output=True, text=True, timeout=LUA_TIMEOUT)
    except (OSError, subprocess.TimeoutExpired) as error:
        raise art_error(path, None, f"could not run lua5.1: {error}") from error

    if result.returncode != 0:
        raise art_error(path, None, f"lua5.1 failed: {result.stderr.strip()}")

    def whole(value: str, what: str) -> int:
        try:
            number = float(value)
        except ValueError:
            number = 0.0

        if number < 1 or number != int(number):
            raise art_error(path, None, f"{what} is {value}, expected a whole number of at least 1")

        return int(number)

    names = []
    variants = None
    plays = {}
    sheet = {}
    sequences = {}

    for line in result.stdout.splitlines():
        kind, *fields = line.split(" ")

        if kind == "names":
            names = fields
        elif kind == "variants":
            variants = whole(fields[0], "skeletal.variants")
        elif kind == "plays":
            plays[fields[0]] = whole(fields[1], f"skeletal.plays.{fields[0]}")
        elif kind == "sheet":
            sheet = {"file": fields[0], "width": float(fields[1]), "height": float(fields[2]), "numFrames": float(fields[3]), "feetRow": float(fields[4])}
        else:
            numbers = [float(item) for item in fields[3].split(",") if item]

            if not numbers or any(number != int(number) for number in numbers):
                raise art_error(path, None, f"sequence {fields[0]} frames {fields[3]} must be whole numbers")

            sequences[fields[0]] = Sequence(float(fields[1]), [int(number) for number in numbers], int(float(fields[2])))

    if variants is None:
        raise art_error(path, None, "skeletal.variants is missing")

    return AnimationData(names, variants, plays, sheet, sequences)


# --------------------------------------------------------------------------------------------
# Kinematics


def rotate(vector: tuple[float, float], degrees: float) -> tuple[float, float]:
    """Rotate clockwise on a y-down canvas, the way Solar2D applies rotation."""
    radians = math.radians(degrees)
    cos = math.cos(radians)
    sin = math.sin(radians)

    return (vector[0] * cos - vector[1] * sin, vector[0] * sin + vector[1] * cos)


def offset(point: tuple[float, float], vector: tuple[float, float], scale: float = 1.0) -> tuple[float, float]:
    return (point[0] + vector[0] * scale, point[1] + vector[1] * scale)


def smooth(amount: float) -> float:
    amount = min(max(amount, 0.0), 1.0)

    return amount * amount * (3 - 2 * amount)


def lerp(start: float, end: float, amount: float) -> float:
    return start + (end - start) * amount


def opaque_corners(image: Image.Image, pivot: tuple[float, float]) -> list[tuple[float, float]]:
    """Corners of the image's opaque pixels relative to its pivot, for grounding."""
    alpha = image.getchannel("A")
    corners = set()

    for y in range(image.height):
        for x in range(image.width):
            if alpha.getpixel((x, y)):
                corners.update((x + dx - pivot[0], y + dy - pivot[1]) for dx in (0, 1) for dy in (0, 1))

    return sorted(corners)


# Angles are degrees, positive forward: thigh, shin and ankle (toe up) from the ground, shoulders
# from the torso, elbows and wrists from their parent; head tips the face down, knot turns clockwise.
# In pixels, shift moves the hips forward, rise lifts the feet off the ground, chest lowers the torso.
STAND = {
    "shift": 0.0,
    "rise": 0.0,
    "chest": 0.0,
    "lean": 0.0,
    "head": 0.0,
    "knot": 0.0,
    **{f"{side}_{joint}": 0.0 for side in SIDES for joint in ("shoulder", "wrist", "thigh", "shin", "ankle")},
    **{part_id: 0.0 for part_id in FOLLOWERS},

    # The painted stand reference: near hand resting at the hip front, far foot a step back.
    "near_shoulder": -8.0,
    "near_elbow": 35.0,
    "near_wrist": 15.0,
    "far_shoulder": 6.0,
    "far_elbow": 25.0,
    "near_thigh": 3.0,
    "far_thigh": -9.0,
    "far_shin": -9.0,
}

STATES = {"eyes": "open", "mouth": "neutral", "hand_near": "open", "hand_far": "open"}


def pose(**angles: float) -> dict:
    unknown = set(angles) - set(STAND)

    if unknown:
        raise PoseError(f"unknown pose angles: {', '.join(sorted(unknown))}")

    return {**STAND, **angles}


def lerp_pose(start: dict, end: dict, amount: float) -> dict:
    return {name: lerp(start[name], end[name], amount) for name in start}


def sample_offsets(keys: list[tuple[float, dict]], time: float) -> dict:
    """Additive angles keyed over time; zero outside the keys and for names a key leaves out."""
    for (start_time, start), (end_time, end) in zip(keys, keys[1:]):
        if start_time <= time <= end_time:
            amount = smooth((time - start_time) / (end_time - start_time))

            return {name: lerp(start.get(name, 0.0), end.get(name, 0.0), amount) for name in {**start, **end}}

    return {}


def add(current: dict, offsets: dict) -> dict:
    return {name: value + offsets.get(name, 0.0) for name, value in current.items()}


class Body:
    """The rig's legs as inverse kinematics helpers, and forward kinematics over every part."""

    def __init__(self, rig: Rig) -> None:
        self.rig = rig
        self.knee = {side: rig.by_id[f"leg_{side}_lower"].joint for side in SIDES}
        self.ankle_joint = {side: rig.by_id[f"foot_{side}"].joint for side in SIDES}
        self.points = {side: {"heel": rig.by_id[f"foot_{side}"].heel, "toe": rig.by_id[f"foot_{side}"].toe} for side in SIDES}
        self.corners = {side: opaque_corners(rig.image(f"foot_{side}"), rig.by_id[f"foot_{side}"].pivot) for side in SIDES}
        self.stand_depth = self.depth("near", 0.0, 0.0, 0.0)
        self.stand_toes = {side: offset(self.ankle(side, STAND[f"{side}_thigh"], STAND[f"{side}_shin"]), rotate(self.points[side]["toe"], -STAND[f"{side}_ankle"])) for side in SIDES}

    def length(self, side: str) -> float:
        return math.hypot(*self.knee[side]) + math.hypot(*self.ankle_joint[side])

    def ankle(self, side: str, thigh: float, shin: float) -> tuple[float, float]:
        """Where the ankle ends up, from the hip."""
        return offset(rotate(self.knee[side], -thigh), rotate(self.ankle_joint[side], -shin))

    def depth(self, side: str, thigh: float, shin: float, ankle: float) -> float:
        """How far below the hip the foot's lowest corner is."""
        joint = self.ankle(side, thigh, shin)

        return max(joint[1] + rotate(corner, -ankle)[1] for corner in self.corners[side])

    def reach(self, side: str, target: tuple[float, float]) -> dict:
        """The thigh and shin that put the ankle on target (from the hip), knee forward."""
        upper = math.hypot(*self.knee[side])
        lower = math.hypot(*self.ankle_joint[side])
        distance = math.hypot(*target)

        if not abs(upper - lower) - 1e-9 <= distance <= upper + lower + 1e-9:
            raise PoseError(f"{side} ankle target ({target[0]:.2f}, {target[1]:.2f}) is out of the leg's reach")

        cosine = (upper**2 + distance**2 - lower**2) / (2 * upper * max(distance, 1e-9))
        thigh_direction = math.degrees(math.atan2(*target)) + math.degrees(math.acos(min(max(cosine, -1.0), 1.0)))
        thigh = thigh_direction - math.degrees(math.atan2(*self.knee[side]))
        knee = rotate(self.knee[side], -thigh)
        shin = math.degrees(math.atan2(target[0] - knee[0], target[1] - knee[1])) - math.degrees(math.atan2(*self.ankle_joint[side]))

        return {f"{side}_thigh": thigh, f"{side}_shin": shin}

    def planted(self, side: str, x: float, depth: float, ankle: float = 0.0, corner: str = "heel") -> dict:
        """The leg whose foot, tilted by ankle, rests on its heel or toe at (x, depth) from the hip."""
        point = rotate(self.points[side][corner], -ankle)

        return {**self.reach(side, (x - point[0], depth - point[1])), f"{side}_ankle": ankle}

    def rolled(self, side: str, x: float, depth: float, ankle: float = 0.0) -> dict:
        """The leg whose toe rests at (x, depth) from the hip, heel lifted by -ankle degrees or
        further until the leg reaches."""
        toe = self.points[side]["toe"]
        reach = STRAIGHT * self.length(side)

        def distance(ankle: float) -> float:
            point = rotate(toe, -ankle)
            return math.hypot(x - point[0], depth - point[1])

        if distance(ankle) <= reach:
            return self.planted(side, x, depth, ankle, "toe")

        low = -85.0
        high = ankle

        if distance(low) > reach:
            raise PoseError(f"{side} toe at ({x:.2f}, {depth:.2f}) is out of the leg's reach")

        for _ in range(60):
            middle = (low + high) / 2

            if distance(middle) > reach:
                high = middle
            else:
                low = middle

        return self.planted(side, x, depth, low, "toe")

    def stance(self, side: str, x: float, depth: float) -> dict:
        """A standing foot whose flat position puts the ankle at x: flat while the leg reaches,
        then rolled onto its toe in place."""
        heel = self.points[side]["heel"]

        if math.hypot(x, depth - heel[1]) <= STRAIGHT * self.length(side):
            return self.planted(side, x + heel[0], depth)

        return self.rolled(side, x + self.points[side]["toe"][0], depth)

    def footing(self, shift: float, drop: float, roll: float) -> dict:
        """Both toes where they stand, heels lifted by roll degrees, the hips moved forward by
        shift and down by drop."""
        legs = {}

        for side in SIDES:
            toe = self.stand_toes[side]
            legs.update(self.planted(side, toe[0] - shift, toe[1] - drop, -roll, "toe"))

        return {**legs, "shift": shift}

    def tiptoe_drop(self, shift: float, roll: float) -> float:
        """The drop, negative, that lifts the hips until the longer-reaching leg is almost straight."""
        drops = []

        for side in SIDES:
            reach = STRAIGHT * self.length(side)
            toe = self.stand_toes[side]
            point = rotate(self.points[side]["toe"], roll)
            ankle_x = toe[0] - shift - point[0]

            if abs(ankle_x) > reach:
                raise PoseError(f"{side} toe at x {toe[0] - shift:.2f} is out of the leg's reach")

            drops.append(toe[1] - point[1] - math.sqrt(reach**2 - ankle_x**2))

        return max(drops)

    def aloft(self, height: float, near: tuple[float, float, float], far: tuple[float, float, float]) -> dict:
        """Legs at (thigh, shin, ankle) in the air with the hips height pixels above standing."""
        deepest = max(self.depth("near", *near), self.depth("far", *far))
        legs = {f"{side}_{joint}": angle for side, angles in (("near", near), ("far", far)) for joint, angle in zip(("thigh", "shin", "ankle"), angles)}

        return {**legs, "rise": self.stand_depth + height - deepest}

    def local_rotations(self, current: dict) -> dict[str, float]:
        """Each part's rotation relative to its parent, in Solar2D's clockwise degrees."""
        rotations = {
            "torso": current["lean"],
            "head": current["head"],
            "scarf_knot": current["knot"],
            "eyes": 0.0,
            "mouth": 0.0,
            **{part_id: current[part_id] for part_id in FOLLOWERS},
        }

        for side in SIDES:
            rotations[f"arm_{side}_upper"] = -current[f"{side}_shoulder"]
            rotations[f"arm_{side}_lower"] = -current[f"{side}_elbow"]
            rotations[f"hand_{side}"] = -current[f"{side}_wrist"]
            rotations[f"leg_{side}_upper"] = -current[f"{side}_thigh"]
            rotations[f"leg_{side}_lower"] = current[f"{side}_thigh"] - current[f"{side}_shin"]
            rotations[f"foot_{side}"] = current[f"{side}_shin"] - current[f"{side}_ankle"]

        return rotations

    def solve(self, current: dict) -> dict[str, tuple[float, float, float]]:
        """Forward kinematics: absolute (x, y, rotation) per part, in draw order.

        Rotation 0 is the part as drawn. The hip height is set so the lowest corner of either
        foot sits rise pixels above the ground, so grounded poses stand on it at any foot angle
        without per-pose tuning.
        """
        rotations = self.local_rotations(current)
        world = {ROOT: (self.rig.hip_x + current["shift"], 0.0, 0.0)}

        for part_id in self.rig.solve_order:
            part = self.rig.by_id[part_id]
            parent_x, parent_y, parent_rotation = world[part.parent]
            joint = offset(part.joint, (0.0, current["chest"])) if part_id == "torso" else part.joint
            x, y = offset((parent_x, parent_y), rotate(joint, parent_rotation))
            world[part_id] = (x, y, parent_rotation + rotations[part_id])

        lowest = max(
            world[foot][1] + rotate(corner, world[foot][2])[1]
            for side, foot in zip(SIDES, FEET)
            for corner in self.corners[side]
        )
        drop = self.rig.feet_row - current["rise"] - lowest

        return {part.id: (world[part.id][0], world[part.id][1] + drop, world[part.id][2]) for part in self.rig.parts}


# --------------------------------------------------------------------------------------------
# Keyframes


def still(time: float) -> float:
    return 0.0


@dataclass(frozen=True)
class Clip:
    """One looping animation: frames poses over one period. A keyed clip lists its (pose, footing)
    keys, planted lists the frames whose feet stand where STAND puts them, and travel gives how
    fast the ground slides back under the feet at a time, in pixels per frame."""

    frames: int
    pose: Callable[[float], dict]
    states: dict[str, str]
    swaps: tuple[tuple[int, int, str, str], ...]
    travel: Callable[[float], float] = still
    keys: tuple[tuple[dict, tuple[float, float, float] | None], ...] = ()
    planted: tuple[int, ...] = ()

    def frame_states(self, index: int) -> dict[str, str]:
        states = dict(self.states)

        for first, end, part_id, state in self.swaps:
            if first <= index < end:
                states[part_id] = state

        return states


def blink(at: float, frames: int) -> tuple[int, int, str, str]:
    first = round(at * frames)

    return (first, first + BLINK_FRAMES, "eyes", "closed")


def frame_range(frames: int, test: Callable[[int], bool]) -> tuple[int, int] | None:
    """The first and past-the-end index of the frames that pass test, which must be one run."""
    inside = [index for index in range(frames) if test(index)]

    return (inside[0], inside[-1] + 1) if inside else None


@dataclass(frozen=True)
class Idle:
    """Breaths of breath frames each under additive pose keys, a weight shift and swaps, keyed
    over shares of the clip. A sway key moves the hips forward by shift and down by drop with
    both feet planted; each tap run lifts the near toe tap degrees count times, heel down."""

    breath: int
    breaths: int
    blinks: tuple[float, ...]
    keys: tuple[tuple[float, dict], ...] = ()
    sway: tuple[tuple[float, dict], ...] = ()
    swaps: tuple[tuple[float, float, str, str], ...] = ()
    taps: tuple[tuple[float, float, int], ...] = ()
    tap: float = 0.0


# The breath's low point, as offsets from standing.
IDLE_DOWN = add(STAND, {"chest": 1, "near_shoulder": 3, "far_shoulder": -3, "near_elbow": 9, "far_elbow": 9})

IDLE_VARIANTS = (
    # Relaxed breathing.
    Idle(breath=24, breaths=2, blinks=(0.3,)),

    # Looks up, then leans in to look down ahead, blinking at each glance.
    Idle(
        breath=24,
        breaths=2,
        blinks=(0.12, 0.36, 0.8),
        keys=(
            (0.06, {}),
            (0.16, {"head": -16, "lean": -2}),
            (0.3, {"head": -18, "lean": -2}),
            (0.4, {"head": 12, "lean": 3}),
            (0.58, {"head": 14, "lean": 4}),
            (0.68, {"head": -3}),
            (0.76, {"head": -4}),
            (0.88, {}),
        ),
        sway=(
            (0.3, {}),
            (0.42, {"shift": 1.5, "drop": 1.0}),
            (0.6, {"shift": 1.5, "drop": 1.0}),
            (0.74, {}),
        ),
    ),

    # Impatient: quicker breaths, fists, and two runs of toe taps.
    Idle(
        breath=16,
        breaths=3,
        blinks=(0.48,),
        keys=(
            (0.04, {}),
            (0.12, {"head": 6, "near_shoulder": 6, "near_elbow": 25, "far_elbow": 20}),
            (0.86, {"head": 6, "near_shoulder": 6, "near_elbow": 25, "far_elbow": 20}),
            (0.96, {}),
        ),
        swaps=((0.08, 0.92, "hand_near", "fist"), (0.08, 0.92, "hand_far", "fist")),
        taps=((0.18, 0.42, 3), (0.58, 0.82, 3)),
        tap=20.0,
    ),
)


def idle_clip(body: Body, plan: Idle) -> Clip:
    frames = plan.breath * plan.breaths
    near_ankle = body.ankle("near", STAND["near_thigh"], STAND["near_shin"])
    heel = offset(near_ankle, body.points["near"]["heel"])

    def tapping(share: float) -> float:
        for start, end, count in plan.taps:
            if start <= share < end:
                # Each tap lifts the toe over its first half and rests it on the ground for the second.
                return plan.tap * max(0.0, math.sin(2 * math.pi * ((share - start) / (end - start) * count % 1.0)))

        return 0.0

    def at(time: float) -> dict:
        share = (time % frames) / frames
        breath = (1 - math.cos(2 * math.pi * time / plan.breath)) / 2
        current = add(lerp_pose(STAND, IDLE_DOWN, breath), sample_offsets(list(plan.keys), share))
        sway = sample_offsets(list(plan.sway), share)

        if sway:
            current.update(body.footing(sway.get("shift", 0.0), sway.get("drop", 0.0), 0.0))

        lift = tapping(share)

        if lift:
            current.update(body.planted("near", heel[0] - current["shift"], heel[1] - sway.get("drop", 0.0), lift))

        return current

    swaps = [blink(share, frames) for share in plan.blinks]
    swaps += [(round(start * frames), round(end * frames), part_id, state) for start, end, part_id, state in plan.swaps]
    planted = tuple(index for index in range(frames) if not tapping(index / frames))

    return Clip(frames, at, dict(STATES), tuple(swaps), planted=planted)


@dataclass(frozen=True)
class Gait:
    """A two-step cycle of 2 * step_frames frames, near leg first. A standing foot's flat ankle
    slides from reach to push (x from the hip), landing heel first tilted by strike, or on its
    toe with the heel lifted tiptoe degrees; a swinging foot arcs lift pixels up through
    swing_ankle. The hips sit sink pixels below straight legs and bob lower on double support."""

    step_frames: float
    reach: float
    push: float
    strike: float
    tiptoe: float
    swing_ankle: float
    lift: float
    sink: float
    bob: float
    lean: float
    head: float
    shoulder: float
    arm_swing: float
    elbow_back: float
    elbow_front: float
    wrist: float
    hands: str


def blend_gait(start: Gait, end: Gait, amount: float) -> Gait:
    values = {field.name: lerp(getattr(start, field.name), getattr(end, field.name), amount) for field in dataclasses.fields(Gait) if field.name != "hands"}

    return Gait(**values, hands=end.hands if amount >= 0.5 else start.hands)


# The relaxed walk, matching the hand-drawn one; its contact pose starts every walk.
WALK = Gait(
    step_frames=6,
    reach=7.0,
    push=-9.0,
    strike=8.0,
    tiptoe=0.0,
    swing_ankle=-12.0,
    lift=4.5,
    sink=0.2,
    bob=0.0,
    lean=4.0,
    head=-4.0,
    shoulder=0.0,
    arm_swing=26.0,
    elbow_back=15.0,
    elbow_front=50.0,
    wrist=5.0,
    hands="open",
)

WALK_BRISK = Gait(
    step_frames=5,
    reach=8.5,
    push=-11.5,
    strike=10.0,
    tiptoe=0.0,
    swing_ankle=-16.0,
    lift=5.5,
    sink=0.3,
    bob=0.0,
    lean=10.0,
    head=-8.0,
    shoulder=4.0,
    arm_swing=32.0,
    elbow_back=60.0,
    elbow_front=80.0,
    wrist=0.0,
    hands="fist",
)

WALK_SNEAK = Gait(
    step_frames=9,
    reach=6.5,
    push=-8.5,
    strike=0.0,
    tiptoe=12.0,
    swing_ankle=-10.0,
    lift=4.5,
    sink=2.5,
    bob=0.0,
    lean=12.0,
    head=-10.0,
    shoulder=30.0,
    arm_swing=8.0,
    elbow_back=75.0,
    elbow_front=90.0,
    wrist=-20.0,
    hands="open",
)


@dataclass(frozen=True)
class Walk:
    """frames of a style that eases in from WALK over a ramp share of the clip, after one WALK
    cycle, and back out over the last ramp share, so every walk starts and ends on WALK's contact
    pose and each foot lands at WALK's pace inside the clip as it does across the loop."""

    style: Gait
    frames: int
    ramp: float = 0.0


# Each length holds a whole number of cycles at the gaits' own cadence, so a variant's closing
# WALK cycle runs at walk_1's pace.
WALK_VARIANTS = (
    Walk(WALK, 48),
    Walk(WALK_BRISK, 43, 0.15),
    Walk(WALK_SNEAK, 45, 0.15),
)
WALK_BLINK = 0.6
STRIKE_SHARE = 0.25

# Phase integration steps per frame, for a walk whose cadence changes.
SUBSTEPS = 16


def walk_clip(body: Body, plan: Walk) -> Clip:
    frames = plan.frames
    heel = {side: body.points[side]["heel"] for side in SIDES}
    toe = {side: body.points[side]["toe"] for side in SIDES}

    def gait_at(time: float) -> Gait:
        share = (time % frames) / frames
        lead = 2 * WALK.step_frames / frames
        weight = smooth(min(share - lead, 1.0 - share) / plan.ramp) if plan.ramp > 0 else 1.0

        return blend_gait(WALK, plan.style, weight)

    # The phase advances at each moment's cadence, scaled so the clip holds whole cycles.
    rates = [1 / (2 * gait_at(index / SUBSTEPS).step_frames) for index in range(frames * SUBSTEPS + 1)]
    cumulative = [0.0]

    for before, after in zip(rates, rates[1:]):
        cumulative.append(cumulative[-1] + (before + after) / (2 * SUBSTEPS))

    cycles = max(1, round(cumulative[-1]))
    scale = cycles / cumulative[-1]

    def phase_at(time: float) -> float:
        position = (time % frames) * SUBSTEPS
        index = min(int(position), len(cumulative) - 2)

        # Rounding keeps float error from turning a contact frame into the end of a swing.
        return round(scale * lerp(cumulative[index], cumulative[index + 1], position - index), 9) % 1.0

    def stance_share(gait: Gait) -> float:
        return (gait.step_frames + 1) / (2 * gait.step_frames)

    def bump(gait: Gait, phase: float) -> float:
        """0 at mid-stance, peaking while both feet are down."""
        return (1 - math.cos(4 * math.pi * (phase - stance_share(gait) / 2))) / 2

    def support(gait: Gait, flat_x: float, ankle: float) -> float:
        """How far below the hips the ground is when a straight leg stands on a foot whose flat
        ankle is at flat_x, tilted by ankle onto its heel or toe."""
        corner = heel["near"] if ankle > 0 else toe["near"]
        point = rotate(corner, -ankle)
        across = flat_x + corner[0] - point[0]

        return math.sqrt((STRAIGHT * body.length("near")) ** 2 - across**2) + point[1]

    def ground(gait: Gait, phase: float) -> float:
        """How far the ground is below the hips: lowest as the heel strikes, highest over the
        supporting foot, sink lower throughout and bob lower again on double support."""
        step = (gait.reach - gait.push) * gait.step_frames / (gait.step_frames + 1)
        low = support(gait, gait.reach, gait.strike - gait.tiptoe)
        high = support(gait, gait.reach - step / 2, -gait.tiptoe)
        rise = (1 - math.cos(2 * math.pi * ((2 * phase) % 1.0))) / 2

        return lerp(low, high, rise) - gait.sink - gait.bob * bump(gait, phase)

    def standing(gait: Gait, side: str, progress: float, depth: float) -> dict:
        flat_x = lerp(gait.reach, gait.push, progress)
        ankle = gait.strike * (1 - smooth(progress / STRIKE_SHARE)) - gait.tiptoe

        if ankle > 0:
            return body.planted(side, flat_x + heel[side][0], depth, ankle)

        return body.rolled(side, flat_x + toe[side][0], depth, ankle)

    def leg_at(gait: Gait, side: str, phase: float) -> dict:
        share = stance_share(gait)
        depth = ground(gait, phase)

        if phase <= share:
            return standing(gait, side, phase / share, depth)

        progress = (phase - share) / (1 - share)
        start = standing(gait, side, 1.0, ground(gait, share))
        end = standing(gait, side, 0.0, ground(gait, 0.0))
        start_ankle = body.ankle(side, start[f"{side}_thigh"], start[f"{side}_shin"])
        end_ankle = body.ankle(side, end[f"{side}_thigh"], end[f"{side}_shin"])

        # The hips bob while the foot swings, so the path is relative to the ground under them. The
        # foot lifts highest early, behind the body, and reaches forward low.
        start_ankle = (start_ankle[0], start_ankle[1] - ground(gait, share) + depth)
        end_ankle = (end_ankle[0], end_ankle[1] - ground(gait, 0.0) + depth)
        target = (
            lerp(start_ankle[0], end_ankle[0], smooth(progress)),
            lerp(start_ankle[1], end_ankle[1], progress) - gait.lift * math.sin(math.pi * (1 - (1 - progress) ** 2)),
        )

        if progress < 0.5:
            ankle = lerp(start[f"{side}_ankle"], gait.swing_ankle, smooth(progress * 2))
        else:
            ankle = lerp(gait.swing_ankle, end[f"{side}_ankle"], smooth(progress * 2 - 1))

        legs = body.reach(side, target)
        clearance = depth - body.depth(side, legs[f"{side}_thigh"], legs[f"{side}_shin"], ankle)

        # Lifting off and setting down, the foot only has to stay above the ground.
        if clearance < (CLEARANCE if 0.25 <= progress <= 0.75 else 0.0):
            raise PoseError(f"the swinging {side} foot clears the ground by {clearance:.2f} at {progress:.2f} of its swing")

        return {**legs, f"{side}_ankle": ankle}

    def at(time: float) -> dict:
        gait = gait_at(time)
        phase = phase_at(time)
        swing = -math.cos(2 * math.pi * phase)
        forward = (1 + swing) / 2

        return pose(
            **leg_at(gait, "near", phase),
            **leg_at(gait, "far", (phase + 0.5) % 1.0),
            lean=gait.lean,
            head=gait.head,
            near_shoulder=gait.shoulder + gait.arm_swing * swing,
            far_shoulder=gait.shoulder - gait.arm_swing * swing,
            near_elbow=lerp(gait.elbow_back, gait.elbow_front, forward),
            far_elbow=lerp(gait.elbow_front, gait.elbow_back, forward),
            near_wrist=gait.wrist,
            far_wrist=gait.wrist,
        )

    def travel(time: float) -> float:
        """How fast the ground slides back under the feet, in pixels per frame."""
        gait = gait_at(time)

        return (gait.reach - gait.push) * scale / (2 * gait.step_frames * stance_share(gait))

    swaps = [blink(WALK_BLINK, frames)]
    fists = frame_range(frames, lambda index: gait_at(index).hands == "fist")

    if fists:
        swaps += [(*fists, "hand_near", "fist"), (*fists, "hand_far", "fist")]

    return Clip(frames, at, dict(STATES), tuple(swaps), travel)


@dataclass(frozen=True)
class Jump:
    """Frames per stage, from standing through crouch, launch, rise, apex, fall, touch-down and
    landing back to standing, and the apex height in pixels. rise_pose and apex_pose replace
    those keys' angles, and apex_legs the apex's (thigh, shin, ankle) per side, near first."""

    height: float
    crouch: int
    launch: int
    rise: int
    hang: int
    fall: int
    recover: int
    rest: int
    rise_pose: dict = dataclasses.field(default_factory=dict)
    apex_pose: dict = dataclasses.field(default_factory=dict)
    apex_legs: tuple[tuple[float, float, float], tuple[float, float, float]] = ((80, -10, 0), (50, -30, -40))


JUMP_VARIANTS = (
    # The hand-drawn jump: the apex is the painted reference.
    Jump(height=12, crouch=3, launch=2, rise=2, hang=1, fall=2, recover=3, rest=4),

    # Over twice as high with a long hang, stretched out and reaching up.
    Jump(
        height=26,
        crouch=3,
        launch=2,
        rise=3,
        hang=3,
        fall=3,
        recover=3,
        rest=4,
        rise_pose={"near_shoulder": 140, "far_shoulder": 120, "near_elbow": 10, "far_elbow": 15},
        apex_pose={"near_shoulder": 155, "near_elbow": 5, "near_wrist": 0, "far_shoulder": 135, "far_elbow": 10, "head": -10, "lean": -3},
        apex_legs=((15, -5, -30), (-5, -20, -40)),
    ),

    # Knees tucked up and a fist pumped overhead at the apex.
    Jump(
        height=14,
        crouch=3,
        launch=2,
        rise=2,
        hang=2,
        fall=2,
        recover=3,
        rest=4,
        rise_pose={"near_shoulder": 70, "near_elbow": 110, "near_wrist": 0},
        apex_pose={"near_shoulder": 165, "near_elbow": 0, "near_wrist": -10, "far_shoulder": 20, "far_elbow": 60, "head": -8, "lean": -4},
        apex_legs=((105, -20, -5), (90, -30, -15)),
    ),
)


def jump_clip(body: Body, plan: Jump) -> Clip:
    # Footing is (shift, drop, roll) for Body.footing; keys with footing on both sides are on the ground.
    standing = (0.0, 0.0, 0.0)
    crouching = (-5.5, 3.5, 0.0)
    launching = (2.0, body.tiptoe_drop(2.0, 40.0), 40.0)
    landing = (-4.5, 3.0, 0.0)

    crouch = pose(**body.footing(*crouching), chest=1, lean=28, head=-12, near_shoulder=-55, far_shoulder=-60, near_elbow=10, far_elbow=10)
    launch = pose(**body.footing(*launching), lean=6, head=-4, near_shoulder=110, far_shoulder=100, near_elbow=10, far_elbow=10)
    rise = pose(**body.aloft(plan.height * 0.75, (30, 0, -20), (20, -10, -30)), lean=2, near_shoulder=110, far_shoulder=60, near_elbow=20, far_elbow=30)
    rise = {**rise, **plan.rise_pose}

    # The painted jump reference, the far arm tucked behind the torso.
    apex = pose(**body.aloft(plan.height, *plan.apex_legs), near_shoulder=85, near_elbow=45, near_wrist=10, far_shoulder=0, far_elbow=20)
    apex = {**apex, **plan.apex_pose}

    fall = pose(**body.aloft(plan.height * 0.75, (30, -6, -5), (20, -10, -5)), head=-2, near_shoulder=70, far_shoulder=30, near_elbow=30, far_elbow=30)
    touch = pose(near_thigh=6, near_shin=-4, near_ankle=-10, far_thigh=4, far_shin=-6, far_ankle=-10, lean=4, near_shoulder=50, far_shoulder=30, near_elbow=30, far_elbow=30)
    land = pose(**body.footing(*landing), chest=1, lean=22, head=-8, near_shoulder=30, far_shoulder=20, near_elbow=35, far_elbow=35)

    times = list(itertools.accumulate([0, plan.crouch, plan.launch, plan.rise, plan.rise, plan.hang, plan.fall, plan.fall, 1, plan.recover, plan.rest]))
    poses = [STAND, crouch, launch, rise, apex, apex, fall, touch, land, STAND, STAND]
    footings = [standing, crouching, launching, None, None, None, None, None, landing, standing, standing]
    keys = list(zip(times, poses, footings))
    frames = times[-1]

    def sample(time: float) -> tuple[dict, bool]:
        """The pose lerped between keys, and whether it stands; standing legs follow the lerped
        footing through inverse kinematics, so the feet stay put while the hips move."""
        for (start_time, start, start_feet), (end_time, end, end_feet) in zip(keys, keys[1:]):
            if start_time <= time <= end_time:
                amount = (time - start_time) / (end_time - start_time)
                current = lerp_pose(start, end, amount)

                if start_feet and end_feet:
                    feet = [lerp(start_value, end_value, amount) for start_value, end_value in zip(start_feet, end_feet)]
                    return {**current, **body.footing(*feet)}, True

                return current, bool(start_feet and amount == 0 or end_feet and amount == 1)

        raise PoseError(f"jump time {time} is outside its keys")

    swaps = [
        blink((times[9] + 1) / frames, frames),
        (times[1], times[5] + 1, "mouth", "effort"),
        (times[3] + 1, times[6] + 1, "hand_near", "fist"),
    ]

    planted = tuple(index for index in range(frames) if sample(float(index))[1])

    return Clip(frames, lambda time: sample(time % frames)[0], dict(STATES), tuple(swaps), keys=tuple(zip(poses, footings)), planted=planted)


FAMILIES = {
    "idle": (idle_clip, IDLE_VARIANTS),
    "walk": (walk_clip, WALK_VARIANTS),
    "jump": (jump_clip, JUMP_VARIANTS),
}


def variant_ids(data: AnimationData) -> list[tuple[str, str, int]]:
    """(animation id, family, variant number from 1) for every variant, in data order."""
    found = []

    for family in data.names:
        if family not in FAMILIES:
            raise ArtError(f"{ANIMATIONS_PATH}: skeletal name {family!r} has no keyframes; the build knows {', '.join(FAMILIES)}")

        plans = FAMILIES[family][1]

        if len(plans) != data.variants:
            raise ArtError(f"{ANIMATIONS_PATH}: skeletal.variants is {data.variants}, but the build defines {len(plans)} {family} variants")

        found += [(f"{family}_{number}", family, number) for number in range(1, data.variants + 1)]

    return found


def build_clip(body: Body, family: str, number: int) -> Clip:
    make, plans = FAMILIES[family]

    return make(body, plans[number - 1])


def build_clips(body: Body, data: AnimationData) -> list[tuple[str, Clip]]:
    clips = []

    for animation_id, family, number in variant_ids(data):
        try:
            clips.append((animation_id, build_clip(body, family, number)))
        except PoseError as error:
            raise PoseError(f"{animation_id}: {error}") from error

    return clips


def follow_through(body: Body, clip: Clip, base: list[dict]) -> list[dict]:
    """Each follower's local rotation per frame, lagged behind its source's motion.

    Sampling wraps around the period, so a looping clip's followers loop with it.
    """
    frames = clip.frames
    rig = body.rig

    def signal(part_id: str, axis: int, time: float) -> float:
        start = math.floor(time)
        amount = time - start

        return lerp(base[start % frames][part_id][axis], base[(start + 1) % frames][part_id][axis], amount)

    def speed(part_id: str, axis: int, time: float) -> float:
        return (signal(part_id, axis, time + 1) - signal(part_id, axis, time - 1)) / 2

    world = []

    for index in range(frames):
        rotations = {}

        for part_id in FOLLOWERS:
            follow = rig.by_id[part_id].follow
            time = index - follow.lag
            trail = follow.drag * (speed(follow.source, 0, time) + clip.travel(time % frames)) + follow.fall * speed(follow.source, 1, time)
            trail = min(max(trail, follow.low), follow.high)
            rotations[part_id] = follow.rotation * signal(follow.source, 2, time) + follow.direction * trail

        world.append(rotations)

    locals_ = []

    for index in range(frames):
        local = {}

        for part_id in FOLLOWERS:
            parent = rig.by_id[part_id].parent
            parent_rotation = world[index][parent] if parent in FOLLOWERS else base[index][parent][2]
            local[part_id] = world[index][part_id] - parent_rotation

        locals_.append(local)

    return locals_


def animate(body: Body, clip: Clip) -> list[tuple[dict, dict]]:
    """(transforms, swap states) per frame."""
    poses = [clip.pose(float(index)) for index in range(clip.frames)]
    base = [body.solve(current) for current in poses]
    followers = follow_through(body, clip, base)

    return [(body.solve({**current, **follow}), clip.frame_states(index)) for index, (current, follow) in enumerate(zip(poses, followers))]


# --------------------------------------------------------------------------------------------
# The manifest


def tidy(value: float) -> float:
    """Three decimals, and never a negative zero in the manifest."""
    return round(value, 3) + 0.0


def build_manifest(rig: Rig, body: Body, clips: list[tuple[str, Clip]]) -> dict:
    manifest_parts = []
    variants = []
    skin_parts = {}

    for order, part in enumerate(rig.parts):
        image = rig.image(part.id)
        manifest_parts.append({
            "id": part.id,
            "key": part.id,
            "name": part.id,
            "kind": "image",
            "asset": f"parts/{part.layer}.png",
            "width": image.width,
            "height": image.height,
            "pivot": {"x": part.pivot[0], "y": part.pivot[1]},
            "drawOrder": order,
            "visible": True,
        })

        if part.id in SWAP_STATES:
            # The runtime resolves a frame part's state through the active skin's states map.
            for state, layer in sorted(part.states.items()):
                variants.append({
                    "id": layer,
                    "part": part.id,
                    "key": state,
                    "name": layer,
                    "asset": f"parts/{layer}.png",
                    "width": rig.images[layer].width,
                    "height": rig.images[layer].height,
                })

            skin_parts[part.id] = {"states": {state: layer for state, layer in sorted(part.states.items())}}

    animations = []

    for animation_id, clip in clips:
        frames = []

        for index, (transforms, states) in enumerate(animate(body, clip)):
            frame_parts = []

            for part in rig.parts:
                x, y, rotation = transforms[part.id]

                # Scale, skew and opacity stay out: parts only rotate and move, and the runtime
                # reads a missing scale or opacity as 1 and a missing skew as 0.
                entry = {
                    "part": part.id,
                    "x": tidy(x),
                    "y": tidy(y),
                    "rotation": tidy(rotation),
                }

                if part.id in SWAP_STATES:
                    entry["state"] = states[part.id]

                frame_parts.append(entry)

            frames.append({"index": index, "sourceFrame": index, "parts": frame_parts})

        animations.append({
            "id": animation_id,
            "name": animation_id,
            "fps": FPS,
            # Plain play() loops it; a loop = false override cannot stop it, because the
            # runtime's `a and b or c` idiom drops a false override.
            "loop": True,
            "frameCount": clip.frames,
            "frames": frames,
        })

    return {
        "format": "spla",
        "version": 1,
        "name": "character",
        "canvas": {"width": rig.canvas[0], "height": rig.canvas[1]},
        "parts": manifest_parts,
        "variants": variants,
        "skins": [{"id": "default", "name": "default", "parts": skin_parts}],
        "animations": animations,
    }


def manifest_text(manifest: dict) -> str:
    """Indented JSON with each frame's parts compact on one line; HTML5 builds download it."""
    compact = {}
    shallow = {**manifest, "animations": []}

    for animation in manifest["animations"]:
        frames = []

        for frame in animation["frames"]:
            marker = f"@parts{len(compact)}@"
            compact[marker] = json.dumps(frame["parts"], separators=(",", ":"))
            frames.append({**frame, "parts": marker})

        shallow["animations"].append({**animation, "frames": frames})

    text = json.dumps(shallow, indent=2)

    return re.sub(r'"(@parts\d+@)"', lambda match: compact[match.group(1)], text) + "\n"


# --------------------------------------------------------------------------------------------
# Previews and lesson images


def scaled(image: Image.Image, scale: int) -> Image.Image:
    return image.resize((image.width * scale, image.height * scale), Image.NEAREST)


class Visuals:
    """Each part's image and pivot per state, resolved from a manifest the way the runtime does."""

    def __init__(self, manifest: dict, root: Path = SKELETAL_ROOT) -> None:
        self.parts = {part["id"]: part for part in manifest["parts"]}
        self.variants = {variant["id"]: variant for variant in manifest.get("variants", [])}
        skins = manifest.get("skins") or [{}]
        self.skin = skins[0].get("parts", {})
        self.root = root
        self.cache = {}

    def state_asset(self, part_id: str, state: str | None) -> dict | None:
        """The variant a frame state resolves to, or None for the part's own image."""
        states = self.skin.get(part_id, {}).get("states", {})

        if state is None or state not in states:
            return None

        return self.variants.get(states[state])

    def get(self, part_id: str, state: str | None) -> tuple[Image.Image, tuple[float, float]]:
        key = (part_id, state)

        if key not in self.cache:
            part = self.parts[part_id]
            source = self.state_asset(part_id, state) or part

            with Image.open(self.root / source["asset"]) as image:
                picture = image.convert("RGBA")

            pivot = (part["pivot"]["x"] + 0.5 * (picture.width - part["width"]), part["pivot"]["y"] + 0.5 * (picture.height - part["height"]))
            self.cache[key] = (picture, pivot)

        return self.cache[key]


def composite_frame(frame: dict, visuals: Visuals, canvas: tuple[int, int], scale: int) -> Image.Image:
    """Place parts the way the runtime does: pivot at (x, y), rotated clockwise about it."""
    image = Image.new("RGBA", (canvas[0] * scale, canvas[1] * scale), TRANSPARENT)

    for entry in frame["parts"]:
        part, pivot = visuals.get(entry["part"], entry.get("state"))
        big = scaled(part, scale)
        pivot_x = round(pivot[0] * scale)
        pivot_y = round(pivot[1] * scale)
        radius = math.ceil(math.hypot(max(pivot_x, big.width - pivot_x), max(pivot_y, big.height - pivot_y))) + 1

        padded = Image.new("RGBA", (radius * 2, radius * 2), TRANSPARENT)
        padded.paste(big, (radius - pivot_x, radius - pivot_y))
        rotated = padded.rotate(-entry["rotation"], resample=Image.NEAREST)

        position = (round(entry["x"] * scale) - radius, round(entry["y"] * scale) - radius)
        image.paste(rotated, position, rotated)

    return image


def onion_frame(previous: Image.Image, current: Image.Image) -> Image.Image:
    faded = previous.copy()
    faded.putalpha(faded.getchannel("A").point(lambda alpha: round(alpha * ONION_ALPHA)))

    image = Image.new("RGBA", current.size, TRANSPARENT)
    image.alpha_composite(faded)
    image.alpha_composite(current)

    return image


def ground_cell(size: tuple[int, int], feet_row: int, scale: int) -> Image.Image:
    """An opaque preview cell with the ground line on the feet row."""
    cell = Image.new("RGBA", (size[0] * scale, size[1] * scale), LESSON_BACKGROUND)
    ground = feet_row * scale
    ImageDraw.Draw(cell).line([(0, ground), (cell.width - 1, ground)], fill=LESSON_GRID)

    return cell


def contact_sheet(rows: list[tuple[str, list[tuple[str, Image.Image]]]], size: tuple[int, int], feet_row: int, scale: int) -> Image.Image:
    """Labelled rows of labelled frames at scale, with a ground line on the feet row."""
    font = ImageFont.load_default(size=14)
    cell = ground_cell(size, feet_row, scale)
    label_height = 20
    blocks = []

    for label, frames in rows:
        lines = math.ceil(len(frames) / PREVIEW_COLUMNS)
        blocks.append((label, frames, lines))

    height = sum(label_height + lines * cell.height for _, _, lines in blocks)
    sheet = Image.new("RGBA", (PREVIEW_COLUMNS * cell.width, height), LESSON_BACKGROUND)
    draw = ImageDraw.Draw(sheet)
    top = 0

    for label, frames, lines in blocks:
        draw.text((4, top + 3), label, fill=LESSON_TEXT, font=font)
        top += label_height

        for index, (frame_label, frame) in enumerate(frames):
            left = (index % PREVIEW_COLUMNS) * cell.width
            cell_top = top + (index // PREVIEW_COLUMNS) * cell.height

            sheet.paste(cell, (left, cell_top))
            draw.rectangle([left, cell_top, left + cell.width - 1, cell_top + cell.height - 1], outline=LESSON_GRID)
            sheet.paste(frame, (left, cell_top), frame)
            draw.text((left + 4, cell_top + 3), frame_label, fill=LESSON_TEXT, font=font)

        top += lines * cell.height

    return sheet


def sprite_previews(name: str, sheet: Sheet, feet_row: int) -> dict[str, Image.Image | list]:
    """Contact sheet, onion-skin sheet and GIF frames (image, milliseconds) for one frame tag."""
    played = sheet.played(name)
    size = (sheet.frame_width, sheet.frame_height)
    big = {index: scaled(sheet.frame(index), PREVIEW_SCALE) for index in played}
    title = f"{name}: {len(played)} drawings over {sum(sheet.durations[index] for index in played)} ms"
    cells = [(f"{index} {sheet.durations[index]} ms", big[index]) for index in played]
    onion = []

    for position, index in enumerate(played):
        previous = played[position - 1]
        onion.append((f"{index} over {previous}", onion_frame(big[previous], big[index])))

    animation = []

    for index in played:
        image = ground_cell(size, feet_row, PREVIEW_SCALE)
        image.alpha_composite(big[index])
        animation.append((image.convert("RGB"), sheet.durations[index]))

    return {
        "contact": contact_sheet([(title, cells)], size, feet_row, PREVIEW_SCALE),
        "onion": contact_sheet([(f"{title}, previous drawing faded underneath", onion)], size, feet_row, PREVIEW_SCALE),
        "gif": animation,
    }


def parts_sheet(rig: Rig, scale: int) -> Image.Image:
    """Every layer in draw order, each labelled, with its part's pivot marked."""
    font = ImageFont.load_default(size=16)
    columns = 6
    margin = 16
    padding = 12
    label_height = 24
    layers = [(part, layer) for part in rig.parts for _, layer in sorted(part.states.items(), key=lambda item: item[0] != part.default)]
    art_width = max(rig.images[layer].width for _, layer in layers) * scale
    art_height = max(rig.images[layer].height for _, layer in layers) * scale
    label_width = max(math.ceil(font.getlength(layer)) for _, layer in layers)
    cell_width = max(art_width, label_width) + padding * 2
    cell_height = art_height + label_height + padding * 2
    rows = math.ceil(len(layers) / columns)
    image = Image.new("RGB", (columns * cell_width + margin * 2, rows * cell_height + margin * 2), LESSON_BACKGROUND[:3])
    draw = ImageDraw.Draw(image)

    for index, (part, layer) in enumerate(layers):
        big = scaled(rig.images[layer], scale)
        left = margin + (index % columns) * cell_width
        top = margin + (index // columns) * cell_height + padding
        art_left = left + (cell_width - big.width) // 2
        art_top = top + art_height - big.height

        image.paste(big, (art_left, art_top), big)

        pivot_x = art_left + round(part.pivot[0] * scale)
        pivot_y = art_top + round(part.pivot[1] * scale)
        draw.rectangle([pivot_x - 2, pivot_y - 2, pivot_x + 1, pivot_y + 1], fill=PIVOT_MARK[:3])

        text_width = draw.textlength(layer, font=font)
        draw.text((left + (cell_width - text_width) / 2, top + art_height + (label_height - 16) // 2 + 4), layer, fill=LESSON_TEXT[:3], font=font)

    return image


def lesson_sheet(sheet: Sheet) -> Image.Image:
    big = scaled(sheet.image, LESSON_SHEET_SCALE)
    image = Image.new("RGBA", big.size, LESSON_BACKGROUND)
    image.paste(big, (0, 0), big)
    draw = ImageDraw.Draw(image)

    for column in range(1, sheet.columns):
        x = column * sheet.frame_width * LESSON_SHEET_SCALE
        draw.line([(x, 0), (x, image.height - 1)], fill=LESSON_GRID)

    for row in range(1, sheet.image.height // sheet.frame_height):
        y = row * sheet.frame_height * LESSON_SHEET_SCALE
        draw.line([(0, y), (image.width - 1, y)], fill=LESSON_GRID)

    return image.convert("RGB")


def save(image: Image.Image, path: Path) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    image.save(path)
    print(f"wrote {path} ({image.width}x{image.height})")


def save_gif(frames: list[tuple[Image.Image, int]], path: Path) -> None:
    images = [image for image, _ in frames]
    durations = [duration for _, duration in frames]
    images[0].save(path, save_all=True, append_images=images[1:], duration=durations, loop=0)
    print(f"wrote {path} ({len(images)} drawings, {sum(durations)} ms)")


def write_previews(directory: Path, only: list[str], sheet: Sheet, sheet_feet_row: int, rig: Rig, manifest: dict) -> None:
    directory.mkdir(parents=True, exist_ok=True)
    visuals = Visuals(manifest)

    for name in [name for name in PREVIEW_NAMES if name in only]:
        if name in SPRITE_SEQUENCES:
            if name not in sheet.tags:
                raise art_error(SHEET_DATA_PATH, None, f"no frame tag named {name}")

            previews = sprite_previews(name, sheet, sheet_feet_row)
            save(previews["contact"].convert("RGB"), directory / f"{name}-contact.png")
            save(previews["onion"].convert("RGB"), directory / f"{name}-onion.png")
            save_gif(previews["gif"], directory / f"{name}.gif")

        elif name == "parts":
            save(parts_sheet(rig, PREVIEW_SCALE), directory / "parts.png")

        else:
            family = name.removeprefix("skeletal-")
            rows = []

            for animation in manifest["animations"]:
                if animation["id"].split("_")[0] == family:
                    cells = [(str(frame["index"]), composite_frame(frame, visuals, rig.canvas, PREVIEW_SCALE)) for frame in animation["frames"]]
                    rows.append((f"skeletal {animation['id']} ({len(cells)} frames)", cells))

            save(contact_sheet(rows, rig.canvas, rig.feet_row, PREVIEW_SCALE).convert("RGB"), directory / f"{name}.png")


def write_assets(sheet: Sheet, rig: Rig, manifest: dict) -> None:
    MANIFEST_PATH.parent.mkdir(parents=True, exist_ok=True)
    MANIFEST_PATH.write_text(manifest_text(manifest), encoding="utf-8")
    print(f"wrote {MANIFEST_PATH}")

    save(lesson_sheet(sheet), LESSON_IMAGES / "animointi-solar2dssa-spritesheet.png")
    save(parts_sheet(rig, LESSON_SCALE), LESSON_IMAGES / "animointi-solar2dssa-osat.png")


def load_all() -> tuple[Sheet, Rig, Body, AnimationData, dict]:
    sheet = load_sheet()
    rig = load_rig()
    data = load_animation_data()
    body = Body(rig)
    manifest = build_manifest(rig, body, build_clips(body, data))

    return sheet, rig, body, data, manifest


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("--preview", type=Path, metavar="DIR", help="also write 4x previews to this directory")
    parser.add_argument("--preview-only", action="store_true", help="write only the previews: no manifest or lesson images")
    parser.add_argument("--only", action="append", choices=PREVIEW_NAMES, metavar="NAME", help=f"limit previews to NAME (repeatable): {', '.join(PREVIEW_NAMES)}")
    arguments = parser.parse_args()

    if (arguments.preview_only or arguments.only) and not arguments.preview:
        parser.error("--preview-only and --only need --preview DIR")

    try:
        sheet, rig, _, data, manifest = load_all()

        if not arguments.preview_only:
            write_assets(sheet, rig, manifest)

        if arguments.preview:
            write_previews(arguments.preview, arguments.only or PREVIEW_NAMES, sheet, int(data.sheet["feetRow"]), rig, manifest)
    except (ArtError, PoseError) as error:
        sys.exit(f"error: {error}")


if __name__ == "__main__":
    main()
