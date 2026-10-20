#!/usr/bin/env python3
"""Check the art grids in tools/art and the character assets that build_character.py writes.

Prints only failures and a final count, and exits 1 if anything failed.

Run from anywhere:

    python3 -B tools/check_assets.py
"""

import json
import sys
from pathlib import Path

from PIL import Image

from build_character import (
    HEEL,
    PART_ORDER,
    PREVIEW_SCALE,
    SHEET_PATH,
    SKELETAL_ROOT,
    TOE,
    ArtError,
    SheetSpec,
    build_manifest,
    build_sheet,
    composite_frame,
    load_frames,
    load_palette,
    load_parts,
    load_sheet_spec,
)

SHEET_SIZE = (512, 288)
FRAME_SIZE = (64, 72)
FRAME_COUNT = 30
FEET_ROW = 68
GROUNDED_PREFIXES = ("idle-", "walk-")
GROUNDED_FAMILIES = ("idle_", "walk_")

PART_IDS = set(PART_ORDER)

FAMILIES = {
    "idle": ["idle_1", "idle_2", "idle_3"],
    "walk": ["walk_1", "walk_2", "walk_3"],
    "jump": ["jump_1", "jump_2", "jump_3"],
}


class Checker:
    def __init__(self) -> None:
        self.checks = 0
        self.failures = 0

    def expect(self, condition: bool, message: str) -> bool:
        self.checks += 1

        if not condition:
            self.failures += 1
            print(f"FAIL: {message}")

        return condition


def load_art(checker: Checker) -> tuple[SheetSpec, dict, dict] | None:
    """Every grid through the build's own parser; None when any art file is malformed."""
    try:
        palette = load_palette()
        spec = load_sheet_spec()
        frames = load_frames(spec, palette)
        parts = load_parts(palette)
    except ArtError as error:
        checker.expect(False, str(error))
        return None

    checker.expect((spec.frame_width, spec.frame_height) == FRAME_SIZE, f"sheet.json frames are {spec.frame_width}x{spec.frame_height}, expected {FRAME_SIZE[0]}x{FRAME_SIZE[1]}")
    checker.expect(spec.feet_row == FEET_ROW, f"sheet.json feetRow is {spec.feet_row}, expected {FEET_ROW}")
    checker.expect(len(spec.frames) == FRAME_COUNT, f"sheet.json lists {len(spec.frames)} frames, expected {FRAME_COUNT}")

    for name, frame in frames.items():
        if name.startswith(GROUNDED_PREFIXES):
            box = frame.getchannel("A").getbbox()
            lowest = box[3] - 1 if box else None
            checker.expect(lowest == spec.feet_row - 1, f"frame {name}: lowest opaque row is {lowest}, expected {spec.feet_row - 1} (grounded)")

    return spec, frames, parts


def check_sheet(checker: Checker, art: tuple[SheetSpec, dict, dict] | None) -> None:
    if not checker.expect(SHEET_PATH.is_file(), f"missing {SHEET_PATH}"):
        return

    sheet = Image.open(SHEET_PATH).convert("RGBA")
    checker.expect(sheet.size == SHEET_SIZE, f"sheet is {sheet.width}x{sheet.height}, expected {SHEET_SIZE[0]}x{SHEET_SIZE[1]}")

    columns = SHEET_SIZE[0] // FRAME_SIZE[0]

    for index in range(FRAME_COUNT):
        left = (index % columns) * FRAME_SIZE[0]
        top = (index // columns) * FRAME_SIZE[1]
        box = (left, top, left + FRAME_SIZE[0], top + FRAME_SIZE[1])

        if checker.expect(box[2] <= sheet.width and box[3] <= sheet.height, f"sheet frame {index + 1} {box} is outside the image"):
            alpha = sheet.crop(box).getchannel("A")
            checker.expect(alpha.getbbox() is not None, f"sheet frame {index + 1} is empty")

    if art:
        spec, frames, _ = art
        built = build_sheet(spec, list(frames.values()))
        checker.expect(built.tobytes() == sheet.tobytes(), "sheet does not match the frame grids; run tools/build_character.py")


def frame_poses(frame: dict) -> dict:
    return {entry["part"]: entry for entry in frame["parts"]}


def check_shoe_corners(checker: Checker, parts: dict) -> None:
    """The rig's HEEL and TOE must be the bottom corners of each lower leg's shoe, or feet float or sink."""
    for side in ("near", "far"):
        image, pivot = parts[f"leg_{side}_lower"]
        alpha = image.getchannel("A")
        bottom = [x for x in range(image.width) if alpha.getpixel((x, image.height - 1))]
        corners = ((bottom[0] - pivot[0], image.height - pivot[1]), (bottom[-1] + 1 - pivot[0], image.height - pivot[1])) if bottom else None
        checker.expect(corners == (HEEL, TOE), f"leg_{side}_lower: shoe bottom corners are {corners}, the rig expects HEEL {HEEL} and TOE {TOE}")


def check_skeletal_poses(checker: Checker, animations: dict, spec: SheetSpec, parts: dict) -> None:
    """Every knee bends forward, and every idle and walk frame stands on the feet row."""
    for animation_id, animation in animations.items():
        for frame in animation["frames"]:
            poses = frame_poses(frame)
            where = f"{animation_id} frame {frame['index']}"

            for side in ("near", "far"):
                bend = poses[f"leg_{side}_lower"]["rotation"] - poses[f"leg_{side}_upper"]["rotation"]
                checker.expect(bend > -0.01, f"{where}: the {side} knee bends backward by {-bend:.1f} degrees")

            if animation_id.startswith(GROUNDED_FAMILIES):
                box = composite_frame(frame, parts, spec, PREVIEW_SCALE).getchannel("A").getbbox()
                lowest = (box[3] - 1) // PREVIEW_SCALE if box else None
                checker.expect(lowest == spec.feet_row - 1, f"{where}: lowest opaque row is {lowest}, expected {spec.feet_row - 1} (grounded)")


def check_manifest(checker: Checker, art: tuple[SheetSpec, dict, dict] | None) -> None:
    manifest_path = SKELETAL_ROOT / "manifest.json"

    if not checker.expect(manifest_path.is_file(), f"missing {manifest_path}"):
        return

    manifest = json.loads(manifest_path.read_text(encoding="utf-8"))
    checker.expect(manifest["canvas"] == {"width": FRAME_SIZE[0], "height": FRAME_SIZE[1]}, f"manifest canvas is {manifest['canvas']}, expected {FRAME_SIZE[0]}x{FRAME_SIZE[1]}")
    grids = art[2] if art else {}

    for part in manifest["parts"]:
        path = SKELETAL_ROOT / part["asset"]

        if checker.expect(path.is_file(), f"part {part['id']}: missing {path}"):
            image = Image.open(path).convert("RGBA")
            declared = (part["width"], part["height"])
            checker.expect(image.size == declared, f"part {part['id']}: image is {image.size}, manifest declares {declared}")

            if part["id"] in grids:
                grid, pivot = grids[part["id"]]
                checker.expect(image.tobytes() == grid.tobytes(), f"part {part['id']}: image does not match its grid; run tools/build_character.py")
                checker.expect((part["pivot"]["x"], part["pivot"]["y"]) == pivot, f"part {part['id']}: manifest pivot differs from parts.json")

    checker.expect({part["id"] for part in manifest["parts"]} == PART_IDS, "manifest part ids are not the ten required ids")

    animations = {animation["id"]: animation for animation in manifest["animations"]}
    required = {animation_id for family in FAMILIES.values() for animation_id in family}
    checker.expect(set(animations) == required, f"animation ids are {sorted(animations)}, expected {sorted(required)}")
    checker.expect(len(manifest["animations"]) == len(required), "animation ids are not unique")

    for animation_id, animation in animations.items():
        checker.expect(animation["frameCount"] == len(animation["frames"]), f"{animation_id}: frameCount does not match the frame list")

        for frame in animation["frames"]:
            listed = [entry["part"] for entry in frame["parts"]]
            checker.expect(sorted(listed) == sorted(PART_IDS), f"{animation_id} frame {frame['index']}: does not list all ten parts exactly once")

    if art:
        spec, _, parts = art
        checker.expect(manifest == build_manifest(parts, spec), "manifest does not match the rig and keyframes; run tools/build_character.py")
        check_shoe_corners(checker, parts)
        check_skeletal_poses(checker, animations, spec, parts)

    for family, members in FAMILIES.items():
        present = [animations[member] for member in members if member in animations]

        if len(present) != len(members):
            continue

        first = frame_poses(present[0]["frames"][0])
        last = frame_poses(present[0]["frames"][-1])

        checker.expect(first == last, f"{family}: {members[0]} does not end on its first frame")

        for animation in present[1:]:
            checker.expect(frame_poses(animation["frames"][0]) == first, f"{family}: {animation['id']} first frame differs from {members[0]}")
            checker.expect(frame_poses(animation["frames"][-1]) == last, f"{family}: {animation['id']} last frame differs from {members[0]}")


def main() -> None:
    checker = Checker()
    art = load_art(checker)
    check_sheet(checker, art)
    check_manifest(checker, art)

    print(f"{checker.checks} checks, {checker.failures} failures")
    sys.exit(1 if checker.failures else 0)


if __name__ == "__main__":
    main()
