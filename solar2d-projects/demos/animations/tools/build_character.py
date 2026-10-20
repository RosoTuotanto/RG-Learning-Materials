#!/usr/bin/env python3
"""Build the animation demo character from the hand-drawn pixel grids in tools/art.

The frame-by-frame form is a sprite sheet assembled from one grid per drawing, laid out
by tools/art/sheet.json. The skeletal form is a SpriteLoop .spla package: one image per
part grid, pivots from tools/art/parts.json, and a manifest that lists every part's
absolute canvas transform for every frame, computed here over a rig: keyframed poses place
the feet with inverse kinematics and forward kinematics turns them into transforms. Both
lesson images are written too. Output is deterministic.

Run from the demo folder:

    python3 -B tools/build_character.py [--preview DIR [--preview-only] [--only NAME ...]]
"""

import argparse
import json
import math
import re
import subprocess
import sys
from dataclasses import dataclass
from pathlib import Path

from PIL import Image, ImageDraw, ImageFont

DEMO_ROOT = Path(__file__).resolve().parent.parent
ART_ROOT = DEMO_ROOT / "tools" / "art"
PALETTE_PATH = ART_ROOT / "palette.json"
SHEET_SPEC_PATH = ART_ROOT / "sheet.json"
PARTS_SPEC_PATH = ART_ROOT / "parts.json"
SHEET_PATH = DEMO_ROOT / "assets" / "images" / "character-sheet.png"
SKELETAL_ROOT = DEMO_ROOT / "assets" / "skeletal"
LESSON_IMAGES = DEMO_ROOT.parent.parent.parent / "lms" / "5-narratiivi-ja-pelitaide" / "images"

LESSON_SCALE = 4
LESSON_SHEET_SCALE = 2
PREVIEW_SCALE = 4
PREVIEW_COLUMNS = 8
ONION_ALPHA = 0.35
FPS = 12
LUA_TIMEOUT = 30

SPRITE_SEQUENCES = ("idle", "walk", "jump")
SKELETAL_FAMILIES = ("idle", "walk", "jump")
PREVIEW_NAMES = [*SPRITE_SEQUENCES, *(f"skeletal-{family}" for family in SKELETAL_FAMILIES), "parts"]

TRANSPARENT = (0, 0, 0, 0)
LESSON_BACKGROUND = (238, 236, 230, 255)
LESSON_GRID = (176, 172, 164, 255)
LESSON_TEXT = (40, 40, 40, 255)
PIVOT_MARK = (220, 30, 60, 255)

COLOUR_PATTERN = re.compile(r"#[0-9A-Fa-f]{6}([0-9A-Fa-f]{2})?")
NAME_PATTERN = re.compile(r"[A-Za-z0-9_-]+")

# Rig, in canvas pixels, matched to the part grids. A joint at x.5 sits on a pixel centre,
# so the rest pose places every part image on whole pixels. Shoes stand on y = 68 (their
# bottom pixel row is 67). The near hip sits under the near leg of the idle-1 drawing and the
# far hip under its far leg, behind it, so both legs show the way the drawings show them.
HIP_X = 34.5
FAR_HIP_X = -5.0
GROUND_Y = 68.0
THIGH = 7
UPPER_ARM = 6
NECK_OFFSET = (-3.0, -19.0)
SHOULDER_OFFSET = (-3.0, -13.0)

# The shoe's bottom corners on the lower leg part, from the knee. The shoe is drawn onto the
# shin, so tipping the shoe onto its toe also tips the shin.
HEEL = (-2.5, 12.5)
TOE = (8.5, 12.5)
FOOT_LENGTH = TOE[0] - HEEL[0]

# A swinging foot passes at least this far above the planted one, so it never scuffs the
# ground or lifts the body.
CLEARANCE = 0.75

PART_ORDER = [
    "arm_far_upper",
    "arm_far_lower",
    "leg_far_upper",
    "leg_far_lower",
    "torso",
    "leg_near_upper",
    "leg_near_lower",
    "head",
    "arm_near_upper",
    "arm_near_lower",
]


def rotate(vector: tuple[float, float], degrees: float) -> tuple[float, float]:
    """Rotate clockwise on a y-down canvas, the way Solar2D applies rotation."""
    radians = math.radians(degrees)
    cos = math.cos(radians)
    sin = math.sin(radians)

    return (vector[0] * cos - vector[1] * sin, vector[0] * sin + vector[1] * cos)


def offset(point: tuple[float, float], vector: tuple[float, float]) -> tuple[float, float]:
    return (point[0] + vector[0], point[1] + vector[1])


# Pose angles are degrees of forward swing, positive toward the facing direction. Thighs and
# shins swing from hanging straight down, so a shin angle is also its shoe's tilt (positive
# lifts the toe); shoulders follow the torso and elbows bend forward. lean tips the torso about
# the hips, head tips the face down, shift moves the hips forward over the feet, rise lifts the
# lowest shoe off the ground and chest drops the upper body onto the hips.
STAND = {
    "shift": 0.0,
    "rise": 0.0,
    "chest": 0.0,
    "lean": 0.0,
    "head": 0.0,
    "near_shoulder": 0.0,
    "near_elbow": 11.0,
    "far_shoulder": 0.0,
    "far_elbow": 11.0,
    "near_thigh": 0.0,
    "near_shin": 0.0,
    "far_thigh": 0.0,
    "far_shin": 0.0,
}


def pose(**angles: float) -> dict:
    return {**STAND, **angles}


def foot(thigh: float, shin: float, corner: tuple[float, float]) -> tuple[float, float]:
    """Where a point on the lower leg ends up, from the hip."""
    return offset(rotate((0.0, THIGH), -thigh), rotate(corner, -shin))


def depth(thigh: float, shin: float) -> float:
    """How far below the hip the lower of the shoe's two bottom corners is."""
    return max(foot(thigh, shin, HEEL)[1], foot(thigh, shin, TOE)[1])


def leg(side: str, thigh: float, shin: float) -> dict:
    return {f"{side}_thigh": thigh, f"{side}_shin": shin}


def reach(side: str, target: tuple[float, float], corner: tuple[float, float]) -> dict:
    """The leg that puts a point on the lower leg on target (from the hip), knee forward."""
    distance = math.hypot(*target)
    lower = math.hypot(*corner)

    if not abs(THIGH - lower) <= distance <= THIGH + lower:
        raise ValueError(f"{side} target {target} is out of the leg's reach")

    hip_bend = math.degrees(math.acos((THIGH**2 + distance**2 - lower**2) / (2 * THIGH * distance)))
    thigh = math.degrees(math.atan2(*target)) + hip_bend
    knee = rotate((0.0, THIGH), -thigh)
    lower_angle = math.degrees(math.atan2(target[0] - knee[0], target[1] - knee[1]))

    return leg(side, thigh, lower_angle - math.degrees(math.atan2(*corner)))


def planted(side: str, x: float, shin: float, corner: tuple[float, float] = HEEL) -> dict:
    """The leg whose shoe, tilted by shin, rests on corner at x from the hip. The shin keeps
    its tilt and the thigh swings to reach, so a flat shoe needs its ankle ahead of the hip."""
    return leg(side, math.degrees(math.asin((x - rotate(corner, -shin)[0]) / THIGH)), shin)


def rolled(side: str, x: float, bend: float = 0.0, corner: tuple[float, float] = TOE) -> dict:
    """The leg, bent by bend degrees at the knee, whose shoe rests on corner at x from the hip.
    The leg tips back over the corner as x falls behind, lifting the heel."""
    low = -80.0
    high = 30.0

    for _ in range(60):
        shin = (low + high) / 2

        if foot(shin + bend, shin, corner)[0] < x:
            low = shin
        else:
            high = shin

    if abs(foot(shin + bend, shin, corner)[0] - x) > 0.01:
        raise ValueError(f"{side} shoe corner {corner} at x {x} is out of the leg's reach")

    return leg(side, shin + bend, shin)


STAND_DEPTH = depth(0.0, 0.0)


def squat(shift: float) -> dict:
    """Both shoes flat where they stand while the hips move back by -shift and drop."""
    return {**planted("near", HEEL[0] - shift, 0.0), **planted("far", HEEL[0] - shift, 0.0), "shift": shift}


def tiptoe(shift: float) -> dict:
    """Both straight legs up on their toes where the toes stand, hips moved forward by shift."""
    return {**rolled("near", TOE[0] - shift), **rolled("far", TOE[0] - shift), "shift": shift}


def aloft(height: float, near: tuple[float, float], far: tuple[float, float]) -> dict:
    """Legs in the air with the hips height pixels above standing, however the legs fold."""
    deepest = max(depth(*near), depth(*far))

    return {**leg("near", *near), **leg("far", *far), "rise": STAND_DEPTH + height - deepest}


def lerp_pose(start: dict, end: dict, amount: float) -> dict:
    return {name: start[name] + (end[name] - start[name]) * amount for name in start}


def sample_keys(keys: list[tuple[float, dict]], time: float) -> dict:
    for (start_time, start), (end_time, end) in zip(keys, keys[1:]):
        if start_time <= time <= end_time:
            return lerp_pose(start, end, (time - start_time) / (end_time - start_time))

    return keys[-1][1]


@dataclass(frozen=True)
class Gait:
    """One walking style, keyed one step at a time.

    A step starts as the leading shoe lands on its heel at reach (tilted up by strike), or on
    its toe when strike is None, and the trailing toe pushes off at toe_off. The planted shoe
    then slides back evenly, flat while its ankle is ahead of the hip and rolled onto its toe
    after, while the trailing leg swings through the (phase, (thigh, shin)) keys.
    """

    frames: int
    reach: float
    toe_off: float
    strike: float | None
    bend: float
    swing: tuple[tuple[float, tuple[float, float]], ...]
    lean: float = 0.0
    head: float = 0.0
    shoulder: float = 0.0
    arm_swing: float = 20.0
    elbow_back: float = 14.0
    elbow_front: float = 26.0


def landing(gait: Gait, side: str) -> dict:
    if gait.strike is None:
        return rolled(side, gait.reach, gait.bend)

    return planted(side, gait.reach, gait.strike)


def stance(gait: Gait, side: str, progress: float) -> dict:
    if gait.strike is None:
        return rolled(side, gait.reach + (gait.toe_off - gait.reach) * progress, gait.bend)

    heel = gait.reach + (gait.toe_off - FOOT_LENGTH - gait.reach) * progress

    if heel >= HEEL[0]:
        return planted(side, heel, 0.0)

    return rolled(side, heel + FOOT_LENGTH, gait.bend)


def gait_step(gait: Gait, lead: str, trail: str, frames: int) -> list[dict]:
    contact = landing(gait, lead)
    push = reach(trail, (gait.toe_off, depth(contact[f"{lead}_thigh"], contact[f"{lead}_shin"])), TOE)
    swing_keys = [(0.0, push), *((phase, leg(trail, *angles)) for phase, angles in gait.swing), (1.0, landing(gait, trail))]
    elbows = gait.elbow_front - gait.elbow_back
    poses = []

    for index in range(frames):
        phase = index / frames
        legs = {**contact, **push} if index == 0 else {**stance(gait, lead, phase), **sample_keys(swing_keys, phase)}

        # The leading arm swings forward with the trailing leg.
        arm = -gait.arm_swing * math.cos(math.pi * phase)
        forward = (1 - math.cos(math.pi * phase)) / 2

        poses.append(pose(
            **legs,
            lean=gait.lean,
            head=gait.head,
            **{
                f"{lead}_shoulder": gait.shoulder + arm,
                f"{trail}_shoulder": gait.shoulder - arm,
                f"{lead}_elbow": gait.elbow_back + elbows * forward,
                f"{trail}_elbow": gait.elbow_front - elbows * forward,
            },
        ))

    return poses


def walk_cycle(steps: list[Gait | tuple[Gait, Gait]]) -> tuple[int, list[tuple[float, dict]]]:
    """Frame count and one key per frame for steps that alternate the leading leg, starting
    with the near one. A (from, to) pair eases from one gait into the other over its step."""
    poses = []

    for index, step in enumerate(steps):
        lead, trail = ("near", "far") if index % 2 == 0 else ("far", "near")

        if isinstance(step, tuple):
            frames = max(step[0].frames, step[1].frames)
            pairs = zip(gait_step(step[0], lead, trail, frames), gait_step(step[1], lead, trail, frames))
            step_poses = [lerp_pose(start, end, frame / frames) for frame, (start, end) in enumerate(pairs)]
        else:
            step_poses = gait_step(step, lead, trail, step.frames)

        for frame, current in enumerate(step_poses[1:], start=1):
            gap = depth(current[f"{lead}_thigh"], current[f"{lead}_shin"]) - depth(current[f"{trail}_thigh"], current[f"{trail}_shin"])

            if gap < CLEARANCE:
                raise ValueError(f"step {index + 1} frame {frame}: the swinging {trail} foot clears the ground by {gap:.2f}")

        poses += step_poses

    first = steps[0][0] if isinstance(steps[0], tuple) else steps[0]
    poses.append(gait_step(first, "near", "far", 1)[0])

    return len(poses), list(enumerate(poses))


IDLE_DOWN = pose(chest=1, near_shoulder=3, far_shoulder=-3, near_elbow=22, far_elbow=22)

# The swing keys lift the trailing shoe behind, then bring the knee up while the shin swings
# through: the shoe is longest tipped onto its toe, so it can only pass under a raised knee.
WALK = Gait(
    frames=6,
    reach=2.0,
    toe_off=-9.8,
    strike=12.0,
    bend=0.0,
    swing=((1 / 6, (-8.0, -76.0)), (2 / 6, (18.0, -70.0)), (3 / 6, (44.0, -32.0)), (4 / 6, (40.0, -2.0)), (5 / 6, (26.0, 10.0))),
    lean=4.0,
)

MARCH = Gait(
    frames=6,
    reach=2.0,
    toe_off=-9.8,
    strike=12.0,
    bend=0.0,
    swing=((1 / 6, (-6.0, -78.0)), (2 / 6, (26.0, -72.0)), (3 / 6, (58.0, -30.0)), (4 / 6, (50.0, 0.0)), (5 / 6, (28.0, 12.0))),
    lean=1.0,
    head=-2.0,
    arm_swing=40.0,
    elbow_back=60.0,
    elbow_front=90.0,
)

# A tiptoe step lengthens the leg, so the sneak stands as tall as the walk and crouches with
# its knees and lean instead.
SNEAK = Gait(
    frames=8,
    reach=9.0,
    toe_off=-6.0,
    strike=None,
    bend=55.0,
    swing=((1 / 8, (-2.0, -80.0)), (3 / 8, (44.0, -70.0)), (5 / 8, (66.0, -20.0)), (7 / 8, (56.0, 0.0))),
    lean=14.0,
    head=-8.0,
    shoulder=46.0,
    arm_swing=8.0,
    elbow_back=96.0,
    elbow_front=100.0,
)

JUMP_CROUCH = pose(**squat(-6.5), chest=1, lean=28, head=-12, near_shoulder=-55, far_shoulder=-60, near_elbow=10, far_elbow=10)
JUMP_LAUNCH = pose(**tiptoe(2.0), lean=6, head=-4, near_shoulder=110, far_shoulder=100, near_elbow=10, far_elbow=10)
JUMP_RISE = pose(**aloft(9.75, (-4, -14), (-6, -16)), lean=2, near_shoulder=125, far_shoulder=110, near_elbow=-35, far_elbow=-25)
JUMP_APEX = pose(**aloft(13, (40, -30), (34, -36)), head=-4, near_shoulder=115, far_shoulder=100, near_elbow=-25, far_elbow=-15)
JUMP_FALL = pose(**aloft(9.75, (20, -6), (14, -10)), head=-2, near_shoulder=95, far_shoulder=85, near_elbow=0, far_elbow=0)
JUMP_TOUCH = pose(**leg("near", 6, -4), **leg("far", 4, -6), lean=4, near_shoulder=60, far_shoulder=50, near_elbow=24, far_elbow=24)
JUMP_LAND = pose(**squat(-5.5), chest=1, lean=22, head=-8, near_shoulder=30, far_shoulder=20, near_elbow=30, far_elbow=30)

TUCK_RISE = pose(**aloft(11, (30, -20), (24, -26)), lean=4, near_shoulder=110, far_shoulder=100, near_elbow=20, far_elbow=20)
TUCK_APEX = pose(**aloft(15, (86, -14), (80, -20)), lean=10, head=-6, near_shoulder=40, far_shoulder=34, near_elbow=70, far_elbow=74)
TUCK_FALL = pose(**aloft(11, (30, -8), (24, -12)), lean=4, near_shoulder=90, far_shoulder=80, near_elbow=24, far_elbow=24)

STAR_LAUNCH = pose(**tiptoe(2.0), lean=6, head=-4, near_shoulder=70, far_shoulder=-60, near_elbow=10, far_elbow=10)
STAR_APEX = pose(**aloft(13, (30, 18), (-30, -40)), head=-6, near_shoulder=130, far_shoulder=-130, near_elbow=0, far_elbow=0)
STAR_FALL = pose(**aloft(9.75, (14, 4), (-12, -22)), near_shoulder=80, far_shoulder=-70, near_elbow=16, far_elbow=16)

# Every variant of a family starts and ends on the family's base pose.
SKELETAL_ANIMATIONS = {
    "idle_1": (24, [(0, STAND), (6, IDLE_DOWN), (12, STAND), (18, IDLE_DOWN), (23, STAND)]),
    "idle_2": (24, [
        (0, STAND),
        (4, pose(lean=-3, head=-18, near_shoulder=2, far_shoulder=-8)),
        (9, pose(lean=-4, head=-20, near_shoulder=2, far_shoulder=-8)),
        (13, pose(lean=6, head=16, near_shoulder=14, far_shoulder=2, near_elbow=20)),
        (18, pose(lean=6, head=18, near_shoulder=14, far_shoulder=2, near_elbow=20)),
        (23, STAND),
    ]),
    "idle_3": (24, [
        (0, STAND),
        (5, pose(lean=-2, near_shoulder=70, far_shoulder=60, near_elbow=40, far_elbow=40)),
        (9, pose(chest=-1, lean=-6, head=-14, near_shoulder=104, far_shoulder=96, near_elbow=0, far_elbow=0)),
        (14, pose(chest=-1, lean=-7, head=-16, near_shoulder=100, far_shoulder=92, near_elbow=0, far_elbow=0)),
        (19, pose(lean=-1, near_shoulder=50, far_shoulder=40, near_elbow=30, far_elbow=30)),
        (23, STAND),
    ]),
    "walk_1": walk_cycle([WALK, WALK]),
    "walk_2": walk_cycle([(WALK, MARCH), MARCH, MARCH, (MARCH, WALK)]),
    "walk_3": walk_cycle([(WALK, SNEAK), SNEAK, SNEAK, (SNEAK, WALK)]),
    "jump_1": (18, [
        (0, STAND),
        (3, JUMP_CROUCH),
        (5, JUMP_LAUNCH),
        (7, JUMP_RISE),
        (9, JUMP_APEX),
        (11, JUMP_FALL),
        (13, JUMP_TOUCH),
        (14, JUMP_LAND),
        (17, STAND),
    ]),
    "jump_2": (18, [
        (0, STAND),
        (3, JUMP_CROUCH),
        (5, JUMP_LAUNCH),
        (7, TUCK_RISE),
        (9, TUCK_APEX),
        (11, TUCK_FALL),
        (13, JUMP_TOUCH),
        (14, JUMP_LAND),
        (17, STAND),
    ]),
    "jump_3": (18, [
        (0, STAND),
        (3, JUMP_CROUCH),
        (5, STAR_LAUNCH),
        (8, STAR_APEX),
        (9, STAR_APEX),
        (11, STAR_FALL),
        (13, JUMP_TOUCH),
        (14, JUMP_LAND),
        (17, STAND),
    ]),
}


def shoe_corners(image: Image.Image, pivot: tuple[float, float]) -> list[tuple[float, float]]:
    """Corners of the lower leg's opaque pixels relative to its pivot, for grounding."""
    alpha = image.getchannel("A")
    corners = set()

    for y in range(image.height):
        for x in range(image.width):
            if alpha.getpixel((x, y)):
                corners.update((x + dx - pivot[0], y + dy - pivot[1]) for dx in (0, 1) for dy in (0, 1))

    return sorted(corners)


def solve(current: dict, shoes: dict[str, list[tuple[float, float]]]) -> dict:
    """Forward kinematics: absolute (x, y, rotation) per part.

    Rotation 0 is a limb hanging straight down. Arms and head inherit the torso's lean;
    legs hang from their hips. The hip height is set so the lowest corner of either rotated
    lower leg (the shoe) sits rise pixels above the ground, so grounded poses stand on it
    at any shin angle without per-pose tuning.
    """
    leg_rotations = {}
    drops = []

    for side in ("near", "far"):
        thigh = -current[f"{side}_thigh"]
        shin = -current[f"{side}_shin"]
        leg_rotations[side] = (thigh, shin)

        knee_drop = rotate((0.0, THIGH), thigh)[1]
        drops.append(knee_drop + max(rotate(corner, shin)[1] for corner in shoes[side]))

    hip = (HIP_X + current["shift"], GROUND_Y - current["rise"] - max(drops))
    hips = {"near": hip, "far": offset(hip, (FAR_HIP_X, 0.0))}

    lean = current["lean"]
    chest = (hip[0], hip[1] + current["chest"])
    neck = offset(chest, rotate(NECK_OFFSET, lean))
    shoulder = offset(chest, rotate(SHOULDER_OFFSET, lean))

    transforms = {
        "torso": (chest[0], chest[1], lean),
        "head": (neck[0], neck[1], lean + current["head"]),
    }

    for side in ("near", "far"):
        upper = lean - current[f"{side}_shoulder"]
        lower = upper - current[f"{side}_elbow"]
        elbow = offset(shoulder, rotate((0.0, UPPER_ARM), upper))

        transforms[f"arm_{side}_upper"] = (shoulder[0], shoulder[1], upper)
        transforms[f"arm_{side}_lower"] = (elbow[0], elbow[1], lower)

        thigh, shin = leg_rotations[side]
        knee = offset(hips[side], rotate((0.0, THIGH), thigh))

        transforms[f"leg_{side}_upper"] = (hips[side][0], hips[side][1], thigh)
        transforms[f"leg_{side}_lower"] = (knee[0], knee[1], shin)

    return transforms


class ArtError(Exception):
    """A malformed or missing art file; the message names the file and line."""


@dataclass
class SheetSpec:
    columns: int
    frame_width: int
    frame_height: int
    feet_row: int
    frames: list[str]


@dataclass
class Sequence:
    name: str
    time: int
    frames: list[int]


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


def load_palette(path: Path = PALETTE_PATH) -> dict[str, tuple[int, int, int, int]]:
    data, text = read_json(path)

    if not isinstance(data, dict):
        raise art_error(path, 1, "expected an object mapping single-character keys to colours")

    palette = {}

    for key, value in data.items():
        line = line_of(text, json.dumps(key, ensure_ascii=False))

        if len(key) != 1 or key.isspace():
            raise art_error(path, line, f"key {key!r} is not a single visible character")

        if not isinstance(value, str) or not COLOUR_PATTERN.fullmatch(value):
            raise art_error(path, line, f"colour for {key!r} is {value!r}, expected #RRGGBB or #RRGGBBAA")

        digits = value[1:] if len(value) == 9 else value[1:] + "FF"
        palette[key] = tuple(int(digits[index:index + 2], 16) for index in range(0, 8, 2))

    if "." not in palette:
        raise art_error(path, None, 'the transparent key "." is missing')

    if palette["."][3] != 0:
        raise art_error(path, line_of(text, '"."'), 'key "." must be fully transparent')

    return palette


def read_grid(path: Path, palette: dict, width: int | None = None, height: int | None = None) -> Image.Image:
    """One palette key per pixel; every row the same width, and the exact size when given."""
    rows = read_text(path).splitlines()

    if not rows:
        raise art_error(path, None, "grid is empty")

    if height is not None and len(rows) != height:
        line = height + 1 if len(rows) > height else len(rows)
        raise art_error(path, line, f"grid has {len(rows)} rows, expected {height}")

    expected = len(rows[0]) if width is None else width
    pixels = []

    for number, row in enumerate(rows, start=1):
        if len(row) != expected:
            raise art_error(path, number, f"row is {len(row)} keys wide, expected {expected}")

        for column, key in enumerate(row, start=1):
            if key not in palette:
                raise art_error(path, number, f"column {column}: key {key!r} is not in {PALETTE_PATH.name}")

            pixels.append(palette[key])

    if expected == 0:
        raise art_error(path, 1, "grid rows are empty")

    image = Image.new("RGBA", (expected, len(rows)), TRANSPARENT)
    image.putdata(pixels)

    return image


def positive_int(data: dict, key: str, path: Path, text: str) -> int:
    value = data.get(key)

    if isinstance(value, bool) or not isinstance(value, int) or value < 1:
        raise art_error(path, line_of(text, f'"{key}"'), f"{key} must be a positive integer, got {value!r}")

    return value


def load_sheet_spec(path: Path = SHEET_SPEC_PATH) -> SheetSpec:
    data, text = read_json(path)

    if not isinstance(data, dict):
        raise art_error(path, 1, "expected an object")

    spec = SheetSpec(
        columns=positive_int(data, "columns", path, text),
        frame_width=positive_int(data, "frameWidth", path, text),
        frame_height=positive_int(data, "frameHeight", path, text),
        feet_row=positive_int(data, "feetRow", path, text),
        frames=data.get("frames"),
    )

    if spec.feet_row > spec.frame_height:
        raise art_error(path, line_of(text, '"feetRow"'), f"feetRow {spec.feet_row} is below the {spec.frame_height}-pixel frame")

    if not isinstance(spec.frames, list) or not spec.frames:
        raise art_error(path, line_of(text, '"frames"'), "frames must be a non-empty list of drawing names")

    for name in spec.frames:
        if not isinstance(name, str) or not NAME_PATTERN.fullmatch(name):
            raise art_error(path, line_of(text, json.dumps(name)), f"frame name {name!r} must use only letters, digits, - and _")

        if spec.frames.count(name) > 1:
            raise art_error(path, line_of(text, json.dumps(name)), f"frame name {name!r} appears twice")

    return spec


def load_frames(spec: SheetSpec, palette: dict) -> dict[str, Image.Image]:
    """Drawing name to image, in sheet order."""
    return {
        name: read_grid(ART_ROOT / "frames" / f"{name}.txt", palette, spec.frame_width, spec.frame_height)
        for name in spec.frames
    }


def load_parts(palette: dict, path: Path = PARTS_SPEC_PATH) -> dict[str, tuple[Image.Image, tuple[float, float]]]:
    """Part id to (image, pivot in part pixels)."""
    data, text = read_json(path)

    if not isinstance(data, dict):
        raise art_error(path, 1, "expected an object mapping part ids to pivots")

    missing = [part_id for part_id in PART_ORDER if part_id not in data]
    extra = [part_id for part_id in data if part_id not in PART_ORDER]

    if missing:
        raise art_error(path, None, f"missing parts: {', '.join(missing)}")

    if extra:
        raise art_error(path, line_of(text, f'"{extra[0]}"'), f"unknown parts: {', '.join(extra)}")

    parts = {}

    for part_id in PART_ORDER:
        pivot = data[part_id]
        line = line_of(text, f'"{part_id}"')

        if not isinstance(pivot, dict) or set(pivot) != {"x", "y"}:
            raise art_error(path, line, f"{part_id}: pivot must be {{\"x\": .., \"y\": ..}}")

        for axis in ("x", "y"):
            if isinstance(pivot[axis], bool) or not isinstance(pivot[axis], (int, float)):
                raise art_error(path, line, f"{part_id}: pivot {axis} must be a number, got {pivot[axis]!r}")

        image = read_grid(ART_ROOT / "parts" / f"{part_id}.txt", palette)
        parts[part_id] = (image, (pivot["x"], pivot["y"]))

    return parts


def build_sheet(spec: SheetSpec, frames: list[Image.Image]) -> Image.Image:
    rows = math.ceil(len(frames) / spec.columns)
    sheet = Image.new("RGBA", (spec.frame_width * spec.columns, spec.frame_height * rows), TRANSPARENT)

    for index, frame in enumerate(frames):
        sheet.paste(frame, ((index % spec.columns) * spec.frame_width, (index // spec.columns) * spec.frame_height))

    return sheet


def tidy(value: float) -> float:
    """Three decimals, and never a negative zero in the manifest."""
    return round(value, 3) + 0.0


def build_manifest(parts: dict, spec: SheetSpec) -> dict:
    manifest_parts = []

    for order, part_id in enumerate(PART_ORDER):
        image, pivot = parts[part_id]
        manifest_parts.append({
            "id": part_id,
            "key": part_id,
            "name": part_id,
            "kind": "image",
            "asset": f"parts/{part_id}.png",
            "width": image.width,
            "height": image.height,
            "pivot": {"x": pivot[0], "y": pivot[1]},
            "drawOrder": order,
            "visible": True,
        })

    animations = []
    shoes = {side: shoe_corners(*parts[f"leg_{side}_lower"]) for side in ("near", "far")}

    for animation_id, (frame_count, keys) in SKELETAL_ANIMATIONS.items():
        frames = []

        for index in range(frame_count):
            transforms = solve(sample_keys(keys, float(index)), shoes)
            frame_parts = []

            for part_id in PART_ORDER:
                x, y, rotation = transforms[part_id]
                frame_parts.append({
                    "part": part_id,
                    "x": tidy(x),
                    "y": tidy(y),
                    "rotation": tidy(rotation),
                    "skewX": 0,
                    "skewY": 0,
                    "scaleX": 1,
                    "scaleY": 1,
                    "opacity": 1,
                })

            frames.append({"index": index, "sourceFrame": index, "parts": frame_parts})

        animations.append({
            "id": animation_id,
            "name": animation_id,
            "fps": FPS,
            # The runtime cannot override a looping manifest to loop = false
            # (its `a and b or c` idiom drops a false override), so the file
            # says false and the app decides looping per play() call.
            "loop": False,
            "frameCount": frame_count,
            "frames": frames,
        })

    return {
        "format": "spla",
        "version": 1,
        "name": "character",
        "canvas": {"width": spec.frame_width, "height": spec.frame_height},
        "parts": manifest_parts,
        "animations": animations,
    }


# Prints each sprite sequence as: name, time, then the comma-separated frame numbers.
LUA_SEQUENCES = """
local animations = dofile( "data/animations.lua" )

for i = 1, #animations.names do
	local name = animations.names[i]
	local sequence = animations.sequences[name]
	io.write( name, " ", sequence.time, " ", table.concat( sequence.frames, "," ), "\\n" )
end
"""


def load_sprite_sequences(frame_count: int) -> dict[str, Sequence]:
    """The sequences exactly as data/animations.lua defines them, read by running Lua."""
    try:
        result = subprocess.run(["lua5.1", "-e", LUA_SEQUENCES], cwd=DEMO_ROOT, capture_output=True, text=True, timeout=LUA_TIMEOUT)
    except (OSError, subprocess.TimeoutExpired) as error:
        raise ArtError(f"data/animations.lua: could not run lua5.1: {error}") from error

    if result.returncode != 0:
        raise ArtError(f"data/animations.lua: lua5.1 failed: {result.stderr.strip()}")

    sequences = {}

    for line in result.stdout.splitlines():
        name, time, frames = line.split(" ")
        numbers = [float(item) for item in frames.split(",") if item]

        if not numbers or any(number != int(number) or not 1 <= number <= frame_count for number in numbers):
            raise ArtError(f"data/animations.lua: sequence {name} frames {frames} must be whole numbers in 1..{frame_count}")

        sequences[name] = Sequence(name, int(float(time)), [int(number) for number in numbers])

    return sequences


def exposures(frames: list[int]) -> list[tuple[int, int]]:
    """Consecutive repeats folded into (frame number, how many exposures it is held)."""
    held = []

    for number in frames:
        if held and held[-1][0] == number:
            held[-1] = (number, held[-1][1] + 1)
        else:
            held.append((number, 1))

    return held


def scaled(image: Image.Image, scale: int) -> Image.Image:
    return image.resize((image.width * scale, image.height * scale), Image.NEAREST)


def composite_frame(frame: dict, parts: dict, spec: SheetSpec, scale: int) -> Image.Image:
    """Place parts the way the runtime does: pivot at (x, y), rotated clockwise about it."""
    canvas = Image.new("RGBA", (spec.frame_width * scale, spec.frame_height * scale), TRANSPARENT)

    for entry in frame["parts"]:
        image, pivot = parts[entry["part"]]
        big = scaled(image, scale)
        pivot_x = round(pivot[0] * scale)
        pivot_y = round(pivot[1] * scale)
        radius = math.ceil(math.hypot(max(pivot_x, big.width - pivot_x), max(pivot_y, big.height - pivot_y))) + 1

        padded = Image.new("RGBA", (radius * 2, radius * 2), TRANSPARENT)
        padded.paste(big, (radius - pivot_x, radius - pivot_y))
        rotated = padded.rotate(-entry["rotation"], resample=Image.NEAREST)

        position = (round(entry["x"] * scale) - radius, round(entry["y"] * scale) - radius)
        canvas.paste(rotated, position, rotated)

    return canvas


def onion_frame(previous: Image.Image, current: Image.Image) -> Image.Image:
    faded = previous.copy()
    faded.putalpha(faded.getchannel("A").point(lambda alpha: round(alpha * ONION_ALPHA)))

    image = Image.new("RGBA", current.size, TRANSPARENT)
    image.alpha_composite(faded)
    image.alpha_composite(current)

    return image


def ground_cell(spec: SheetSpec, scale: int) -> Image.Image:
    """An opaque preview cell with the ground line on the feet row."""
    cell = Image.new("RGBA", (spec.frame_width * scale, spec.frame_height * scale), LESSON_BACKGROUND)
    ground = spec.feet_row * scale
    ImageDraw.Draw(cell).line([(0, ground), (cell.width - 1, ground)], fill=LESSON_GRID)

    return cell


def contact_sheet(rows: list[tuple[str, list[tuple[str, Image.Image]]]], spec: SheetSpec, scale: int) -> Image.Image:
    """Labelled rows of labelled frames at scale, with a ground line on the feet row."""
    font = ImageFont.load_default(size=14)
    cell = ground_cell(spec, scale)
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


def held_label(name: str, count: int) -> str:
    return name if count == 1 else f"{name} x{count}"


def sprite_previews(sequence: Sequence, spec: SheetSpec, frames: dict[str, Image.Image]) -> dict[str, Image.Image | list]:
    """Contact sheet, onion-skin sheet and GIF frames (image, milliseconds) for one sequence."""
    names = list(frames)
    held = exposures(sequence.frames)
    big = {number: scaled(frames[names[number - 1]], PREVIEW_SCALE) for number, _ in held}
    title = f"{sequence.name}: {len(sequence.frames)} exposures over {sequence.time} ms"

    cells = [(held_label(names[number - 1], count), big[number]) for number, count in held]
    onion = []

    for index, (number, count) in enumerate(held):
        previous = held[index - 1][0]
        onion.append((f"{held_label(names[number - 1], count)} over {names[previous - 1]}", onion_frame(big[previous], big[number])))

    exposure = sequence.time / len(sequence.frames)
    animation = []

    for number, count in held:
        image = ground_cell(spec, PREVIEW_SCALE)
        image.alpha_composite(big[number])
        animation.append((image.convert("RGB"), round(exposure * count)))

    return {
        "contact": contact_sheet([(title, cells)], spec, PREVIEW_SCALE),
        "onion": contact_sheet([(f"{title}, previous drawing faded underneath", onion)], spec, PREVIEW_SCALE),
        "gif": animation,
    }


def parts_sheet(parts: dict, scale: int) -> Image.Image:
    """The parts in draw order, each labelled, with its pivot marked; cells fit the largest part."""
    font = ImageFont.load_default(size=16)
    columns = 5
    margin = 16
    padding = 12
    label_height = 24
    art_width = max(part[0].width for part in parts.values()) * scale
    art_height = max(part[0].height for part in parts.values()) * scale
    label_width = max(math.ceil(font.getlength(part_id)) for part_id in PART_ORDER)
    cell_width = max(art_width, label_width) + padding * 2
    cell_height = art_height + label_height + padding * 2
    rows = math.ceil(len(PART_ORDER) / columns)
    image = Image.new("RGB", (columns * cell_width + margin * 2, rows * cell_height + margin * 2), LESSON_BACKGROUND[:3])
    draw = ImageDraw.Draw(image)

    for index, part_id in enumerate(PART_ORDER):
        part, pivot = parts[part_id]
        big = scaled(part, scale)
        left = margin + (index % columns) * cell_width
        top = margin + (index // columns) * cell_height + padding
        art_left = left + (cell_width - big.width) // 2
        art_top = top + art_height - big.height

        image.paste(big, (art_left, art_top), big)

        pivot_x = art_left + round(pivot[0] * scale)
        pivot_y = art_top + round(pivot[1] * scale)
        draw.rectangle([pivot_x - 2, pivot_y - 2, pivot_x + 1, pivot_y + 1], fill=PIVOT_MARK[:3])

        text_width = draw.textlength(part_id, font=font)
        draw.text((left + (cell_width - text_width) / 2, top + art_height + (label_height - 16) // 2 + 4), part_id, fill=LESSON_TEXT[:3], font=font)

    return image


def lesson_sheet(sheet: Image.Image, spec: SheetSpec) -> Image.Image:
    big = scaled(sheet, LESSON_SHEET_SCALE)
    image = Image.new("RGBA", big.size, LESSON_BACKGROUND)
    image.paste(big, (0, 0), big)
    draw = ImageDraw.Draw(image)

    for column in range(1, sheet.width // spec.frame_width):
        x = column * spec.frame_width * LESSON_SHEET_SCALE
        draw.line([(x, 0), (x, image.height - 1)], fill=LESSON_GRID)

    for row in range(1, sheet.height // spec.frame_height):
        y = row * spec.frame_height * LESSON_SHEET_SCALE
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


def write_previews(directory: Path, only: list[str], spec: SheetSpec, frames: dict, manifest: dict, parts: dict) -> None:
    directory.mkdir(parents=True, exist_ok=True)
    wanted = [name for name in PREVIEW_NAMES if name in only]
    sequences = {}

    if any(name in SPRITE_SEQUENCES for name in wanted):
        sequences = load_sprite_sequences(len(frames))

    for name in wanted:
        if name in SPRITE_SEQUENCES:
            if name not in sequences:
                raise ArtError(f"data/animations.lua: no sequence named {name}")

            previews = sprite_previews(sequences[name], spec, frames)
            save(previews["contact"].convert("RGB"), directory / f"{name}-contact.png")
            save(previews["onion"].convert("RGB"), directory / f"{name}-onion.png")
            save_gif(previews["gif"], directory / f"{name}.gif")

        elif name == "parts":
            save(parts_sheet(parts, PREVIEW_SCALE), directory / "parts.png")

        else:
            family = name.removeprefix("skeletal-")
            rows = []

            for animation in manifest["animations"]:
                if animation["id"].startswith(family):
                    cells = [(str(frame["index"]), composite_frame(frame, parts, spec, PREVIEW_SCALE)) for frame in animation["frames"]]
                    rows.append((f"skeletal {animation['id']} ({len(cells)} frames)", cells))

            save(contact_sheet(rows, spec, PREVIEW_SCALE).convert("RGB"), directory / f"{name}.png")


def write_assets(spec: SheetSpec, sheet: Image.Image, manifest: dict, parts: dict) -> None:
    save(sheet, SHEET_PATH)

    for part_id in PART_ORDER:
        save(parts[part_id][0], SKELETAL_ROOT / "parts" / f"{part_id}.png")

    SKELETAL_ROOT.mkdir(parents=True, exist_ok=True)
    (SKELETAL_ROOT / "manifest.json").write_text(json.dumps(manifest, indent=2) + "\n", encoding="utf-8")
    print(f"wrote {SKELETAL_ROOT / 'manifest.json'}")

    save(lesson_sheet(sheet, spec), LESSON_IMAGES / "animointi-solar2dssa-spritesheet.png")
    save(parts_sheet(parts, LESSON_SCALE), LESSON_IMAGES / "animointi-solar2dssa-osat.png")


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("--preview", type=Path, metavar="DIR", help="also write 4x previews to this directory")
    parser.add_argument("--preview-only", action="store_true", help="write only the previews: no assets, manifest or lesson images")
    parser.add_argument("--only", action="append", choices=PREVIEW_NAMES, metavar="NAME", help=f"limit previews to NAME (repeatable): {', '.join(PREVIEW_NAMES)}")
    arguments = parser.parse_args()

    if (arguments.preview_only or arguments.only) and not arguments.preview:
        parser.error("--preview-only and --only need --preview DIR")

    try:
        palette = load_palette()
        spec = load_sheet_spec()
        frames = load_frames(spec, palette)
        parts = load_parts(palette)
        sheet = build_sheet(spec, list(frames.values()))
        manifest = build_manifest(parts, spec)

        if not arguments.preview_only:
            write_assets(spec, sheet, manifest, parts)

        if arguments.preview:
            write_previews(arguments.preview, arguments.only or PREVIEW_NAMES, spec, frames, manifest, parts)
    except ArtError as error:
        sys.exit(f"error: {error}")


if __name__ == "__main__":
    main()
