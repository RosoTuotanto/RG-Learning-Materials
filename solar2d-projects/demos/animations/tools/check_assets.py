#!/usr/bin/env python3
"""Check the character inputs, data/animations.lua and the manifest build_character.py writes.

Prints only failures and a final count, and exits 1 if anything failed.

Run from anywhere:

    python3 -B tools/check_assets.py
"""

import itertools
import json
import subprocess
import sys

from PIL import Image, ImageChops

from build_character import (
    DEMO_ROOT,
    EXPOSURE_MS,
    FEET,
    FOLLOWERS,
    LUA_TIMEOUT,
    MANIFEST_PATH,
    PARTS_ROOT,
    PREVIEW_SCALE,
    SHEET_PATH,
    SKELETAL_ROOT,
    SWAP_STATES,
    AnimationData,
    ArtError,
    Body,
    PoseError,
    Rig,
    Sheet,
    Visuals,
    bent,
    build_clip,
    build_manifest,
    composite_frame,
    load_animation_data,
    load_rig,
    load_sheet,
    rotate,
    variant_ids,
)

SHEET_SIZE = (560, 560)
FRAME_SIZE = (80, 80)
FRAME_COUNT = 44
RIG_CANVAS = (80, 96)
RIG_FEET_ROW = 92
NAMES = ["idle", "walk", "jump"]
GROUNDED = ("idle", "walk")
VARIANTS = 3
# Manifest values are rounded to three decimals, so two of them can differ by one more step.
SEAM_TOLERANCE = 0.002
SLIDE_TOLERANCE = 0.01
# The scarf trails each variant's own last frames, so variants may start it this far apart.
FOLLOW_TOLERANCE = 1.5
MIN_DRAWINGS = 2
# Parts with no rotation of their own: each sits on its joint and turns with its parent, or along its bend curve.
RIGID = ("eyes", "mouth", "bouquet")
# No part a skin shows may cover these in any frame.
UNCOVERED = "eyes"

LUA_LAYOUT = """
local character = dofile( "data/layout.lua" ).character
io.write( character.spriteFeetOffset, " ", character.skeletalFeetOffset )
"""

# One line per slot ("slot NAME OPTION ..."), part rule ("part ID key=value ...") and skin rule ("skin key=value ..."),
# then "default SKIN".
LUA_OUTFITS = """
local outfits = dofile( "data/outfits.lua" )

local function writeRule( prefix, rule )
	local fields = {}

	for key, value in pairs( rule ) do
		fields[#fields + 1] = tostring( key ) .. "=" .. tostring( value )
	end

	table.sort( fields )
	io.write( prefix, " ", table.concat( fields, " " ), "\\n" )
end

for i = 1, #outfits.slots do
	local slot = outfits.slots[i]
	io.write( "slot ", slot, " ", table.concat( outfits.options[slot] or {}, " " ), "\\n" )
end

for partId, rules in pairs( outfits.parts ) do
	for i = 1, #rules do
		writeRule( "part " .. partId, rules[i] )
	end
end

for i = 1, #outfits.skins do
	writeRule( "skin", outfits.skins[i] )
end

io.write( "default ", tostring( outfits.defaultSkin ), "\\n" )
"""


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


def load(checker: Checker, loader, *arguments):
    """The loader's result through the build's own parser; None when its input is malformed."""
    try:
        return loader(*arguments)
    except ArtError as error:
        checker.expect(False, str(error))
        return None


def lowest_row(image: Image.Image) -> int | None:
    box = image.getchannel("A").getbbox()

    return box[3] - 1 if box else None


def check_sheet(checker: Checker, sheet: Sheet, feet_row: int | None) -> None:
    """The JSON already matches the PNG (load_sheet stops otherwise); these are the app's needs."""
    checker.expect(sheet.image.size == SHEET_SIZE, f"sheet is {sheet.image.width}x{sheet.image.height}, expected {SHEET_SIZE[0]}x{SHEET_SIZE[1]}")
    checker.expect((sheet.frame_width, sheet.frame_height) == FRAME_SIZE, f"sheet frames are {sheet.frame_width}x{sheet.frame_height}, expected {FRAME_SIZE[0]}x{FRAME_SIZE[1]}")
    checker.expect(len(sheet.durations) == FRAME_COUNT, f"sheet JSON lists {len(sheet.durations)} frames, expected {FRAME_COUNT}")
    checker.expect(sorted(sheet.tags) == sorted(NAMES), f"frame tags are {sorted(sheet.tags)}, expected {sorted(NAMES)}")

    for index in range(len(sheet.durations)):
        checker.expect(lowest_row(sheet.frame(index)) is not None, f"sheet frame {index} is empty")

    for name in NAMES:
        if name in sheet.tags:
            drawings = {sheet.frame(index).tobytes() for index in sheet.played(name)}
            checker.expect(len(drawings) >= MIN_DRAWINGS, f"{name}: the sequence has {len(drawings)} distinct drawing(s), expected at least {MIN_DRAWINGS}")

    if feet_row is None:
        return

    for name in GROUNDED:
        if name in sheet.tags:
            for index in sheet.played(name):
                lowest = lowest_row(sheet.frame(index))
                checker.expect(lowest == feet_row - 1, f"{name} frame {index}: lowest opaque row is {lowest}, expected {feet_row - 1} (grounded)")


def check_animation_data(checker: Checker, data: AnimationData, sheet: Sheet | None) -> None:
    checker.expect(data.names == NAMES, f"skeletal.names are {data.names}, expected {NAMES}")
    checker.expect(data.variants == VARIANTS, f"skeletal.variants is {data.variants}, expected {VARIANTS}")
    checker.expect(data.sheet.get("file") == SHEET_PATH.relative_to(SHEET_PATH.parents[2]).as_posix(), f"sheet.file is {data.sheet.get('file')!r}")

    if not sheet:
        return

    declared = (data.sheet.get("width"), data.sheet.get("height"), data.sheet.get("numFrames"))
    expected = (sheet.frame_width, sheet.frame_height, len(sheet.durations))
    checker.expect(declared == expected, f"data/animations.lua sheet is {declared} (width, height, numFrames), the sheet JSON gives {expected}")

    for name in NAMES:
        sequence = data.sequences.get(name)

        if not checker.expect(sequence is not None and name in sheet.tags, f"{name}: needs both a sequence in data/animations.lua and a frame tag in the sheet JSON"):
            continue

        frames = []

        for index in sheet.played(name):
            duration = sheet.durations[index]
            exposures = round(duration / EXPOSURE_MS)
            checker.expect(exposures >= 1 and abs(duration - exposures * EXPOSURE_MS) < 1, f"sheet frame {index}: {duration} ms is not a whole number of {EXPOSURE_MS:.2f} ms exposures")
            frames += [index + 1] * exposures

        time = sum(sheet.durations[index] for index in sheet.played(name))
        checker.expect(sequence.frames == frames, f"{name}: sequence frames {sequence.frames} do not match the JSON tag and durations, which give {frames}")
        checker.expect(sequence.time == time, f"{name}: sequence time is {sequence.time}, the JSON durations add up to {time}")
        checker.expect(sequence.loop_count == 0, f"{name}: loopCount is {sequence.loop_count}, expected 0 (loop forever)")


def check_rig(checker: Checker, rig: Rig) -> None:
    """Every image exists and loads (load_rig stops otherwise); feet and stray files are checked here."""
    checker.expect(rig.canvas == RIG_CANVAS, f"rig canvas is {rig.canvas}, expected {RIG_CANVAS}")
    checker.expect(rig.feet_row == RIG_FEET_ROW, f"rig feetRow is {rig.feet_row}, expected {RIG_FEET_ROW}")

    for foot in FEET:
        part = rig.by_id[foot]
        image = rig.image(foot)
        alpha = image.getchannel("A")
        bottom = [x for x in range(image.width) if alpha.getpixel((x, image.height - 1))]
        corners = ((bottom[0] - part.pivot[0], image.height - part.pivot[1]), (bottom[-1] + 1 - part.pivot[0], image.height - part.pivot[1])) if bottom else None
        checker.expect(corners == (part.heel, part.toe), f"{foot}: sole corners are {corners}, the rig gives heel {part.heel} and toe {part.toe}")

    layers = {layer for part in rig.parts for layer in [*part.states.values(), *part.variants]}
    files = {path.stem for path in PARTS_ROOT.glob("*.png")}
    checker.expect(not layers - files, f"assets/skeletal/parts lacks layers the rig uses: {sorted(layers - files)}")
    checker.expect(not files - layers, f"assets/skeletal/parts holds layers the rig does not use: {sorted(files - layers)}")


def check_layout(checker: Checker, data: AnimationData, rig: Rig) -> None:
    """data/layout.lua stands both characters' feet rows on the floor line."""
    try:
        result = subprocess.run(["lua5.1", "-e", LUA_LAYOUT], cwd=DEMO_ROOT, capture_output=True, text=True, timeout=LUA_TIMEOUT)
    except (OSError, subprocess.TimeoutExpired) as error:
        checker.expect(False, f"data/layout.lua: could not run lua5.1: {error}")
        return

    if not checker.expect(result.returncode == 0, f"data/layout.lua: lua5.1 failed: {result.stderr.strip()}"):
        return

    sprite, skeletal = (float(value) for value in result.stdout.split())
    sprite_expected = data.sheet["feetRow"] - data.sheet["height"] / 2
    skeletal_expected = rig.feet_row - rig.canvas[1] / 2
    checker.expect(sprite == sprite_expected, f"data/layout.lua spriteFeetOffset is {sprite:g}, the sheet's feetRow - height / 2 is {sprite_expected:g}")
    checker.expect(skeletal == skeletal_expected, f"data/layout.lua skeletalFeetOffset is {skeletal:g}, the rig's feetRow - canvas height / 2 is {skeletal_expected:g}")


def frame_poses(frame: dict) -> dict:
    return {entry["part"]: entry for entry in frame["parts"]}


def seam_jumps(frames: list[dict]) -> list[str]:
    """Every part axis whose last-to-first step is larger than its largest step inside the clip."""
    tracks = [frame_poses(frame) for frame in frames]
    jumps = []

    for part_id in tracks[0]:
        for axis in ("x", "y", "rotation"):
            values = [track[part_id][axis] for track in tracks]
            largest = max((abs(after - before) for before, after in zip(values, values[1:])), default=0.0)
            wrap = abs(values[0] - values[-1])

            if wrap > largest + SEAM_TOLERANCE:
                jumps.append(f"{part_id} {axis} by {wrap:.3f}, its largest step is {largest:.3f}")

    return jumps


def check_shared_start(checker: Checker, variants: list[dict]) -> None:
    """Every variant of a family starts on its first variant's first frame, so the app can switch
    variants at a loop boundary; each loop seam is checked by seam_jumps."""
    if not variants or not all(animation["frames"] for animation in variants):
        return

    starts = [frame_poses(animation["frames"][0]) for animation in variants]
    first = starts[0]
    part_ids = sorted(set().union(*starts))

    for animation, start in zip(variants[1:], starts[1:]):
        for part_id in part_ids:
            if not checker.expect(part_id in first and part_id in start, f"{animation['id']} frame 0: {part_id} is not in both it and {variants[0]['id']} frame 0"):
                continue

            entry = first[part_id]
            other = start[part_id]
            moved = max((abs(other.get(axis, 0.0) - entry[axis]) for axis in ("x", "y", "rotation")), default=0.0)
            tolerance = FOLLOW_TOLERANCE if part_id in FOLLOWERS else SEAM_TOLERANCE
            same = moved <= tolerance and other.get("state") == entry.get("state")
            checker.expect(same, f"{animation['id']} frame 0: {part_id} differs from {variants[0]['id']} frame 0 by {moved:.3f}, state {other.get('state')!r} against {entry.get('state')!r}")


def check_skins(checker: Checker, rig: Rig, manifest: dict) -> None:
    """The default skin shows no hidden part; every other skin keeps every swap, shows its hidden
    parts and holds its locked parts on one image."""
    skins = {skin["id"]: skin.get("parts", {}) for skin in manifest.get("skins", [])}
    checker.expect(list(skins) == ["default", *(skin.id for skin in rig.skins)], f"manifest skins are {list(skins)}, expected default and the rig's skins")
    variants = {variant["id"]: variant for variant in manifest.get("variants", [])}

    for part in rig.parts:
        if part.hidden:
            entry = next((entry for entry in manifest["parts"] if entry["id"] == part.id), {})
            checker.expect(entry.get("visible") is False and "visible" not in skins.get("default", {}).get(part.id, {}), f"{part.id}: hidden in the rig, but the default skin shows it")
            checker.expect((SKELETAL_ROOT / entry.get("asset", "")).is_file(), f"{part.id}: its image {entry.get('asset')!r} does not resolve")

    for skin in rig.skins:
        overrides = skins.get(skin.id, {})

        for part_id in skin.show:
            checker.expect(overrides.get(part_id, {}).get("visible") is True, f"skin {skin.id}: does not show {part_id}")

        for part_id, states in SWAP_STATES.items():
            mapped = overrides.get(part_id, {}).get("states", {})
            checker.expect(set(mapped) == states and all(mapped[state] in variants and variants[mapped[state]]["part"] == part_id for state in states), f"skin {skin.id}: {part_id} states {mapped} do not resolve every state to one of its images")

            if part_id in skin.lock_states:
                locked = rig.by_id[part_id].states[skin.lock_states[part_id]]
                checker.expect(set(mapped.values()) == {locked}, f"skin {skin.id}: {part_id} shows {sorted(set(mapped.values()))}, expected only {locked}")


def lua_outfits(checker: Checker) -> list[list[str]] | None:
    try:
        result = subprocess.run(["lua5.1", "-e", LUA_OUTFITS], cwd=DEMO_ROOT, capture_output=True, text=True, timeout=LUA_TIMEOUT)
    except (OSError, subprocess.TimeoutExpired) as error:
        checker.expect(False, f"data/outfits.lua: could not run lua5.1: {error}")
        return None

    if not checker.expect(result.returncode == 0, f"data/outfits.lua: lua5.1 failed: {result.stderr.strip()}"):
        return None

    return [line.split() for line in result.stdout.splitlines()]


def rule_fields(fields: list[str]) -> dict[str, str]:
    return dict(field.split("=", 1) for field in fields)


def check_outfits(checker: Checker, rig: Rig, manifest: dict) -> None:
    """data/outfits.lua names only the manifest's own variants and skins, uses every hand-swapped
    variant, and never lets two rules for one part, or two skin rules, match the same outfit."""
    lines = lua_outfits(checker)

    if lines is None:
        return

    slots = {line[1]: line[2:] for line in lines if line[0] == "slot"}
    part_rules = {}
    skin_rules = [rule_fields(line[1:]) for line in lines if line[0] == "skin"]
    default = next((line[1] for line in lines if line[0] == "default"), None)

    for line in lines:
        if line[0] == "part":
            part_rules.setdefault(line[1], []).append(rule_fields(line[2:]))

    checker.expect(all(len(options) >= 2 for options in slots.values()) and slots, f"data/outfits.lua: every slot needs at least two options, got {slots}")

    variants = {variant["id"]: variant["part"] for variant in manifest.get("variants", [])}
    skins = [skin["id"] for skin in manifest.get("skins", [])]
    used = set()

    for part_id, rules in part_rules.items():
        for rule in rules:
            variant = rule.get("variant")
            used.add(variant)
            checker.expect(variants.get(variant) == part_id and part_id in rig.by_id and variant in rig.by_id[part_id].variants, f"data/outfits.lua: {part_id} rule names {variant!r}, which is not one of that part's hand-swapped variants")

    for rule in skin_rules:
        checker.expect(rule.get("skin") in skins[1:], f"data/outfits.lua: skin rule names {rule.get('skin')!r}, not one of the manifest's extra skins {skins[1:]}")

    checker.expect(default == (skins[0] if skins else None), f"data/outfits.lua: defaultSkin is {default!r}, the manifest's first skin is {skins[0] if skins else None!r}")

    manual = {layer for part in rig.parts for layer in part.variants}
    checker.expect(manual <= used, f"data/outfits.lua: no rule uses {sorted(manual - used)}")

    for kind, rules in [*part_rules.items(), ("skins", skin_rules)]:
        for rule in rules:
            named = {slot: option for slot, option in rule.items() if slot not in ("variant", "skin")}
            checker.expect(named and all(slot in slots and option in slots[slot] for slot, option in named.items()), f"data/outfits.lua: {kind} rule {rule} names a slot or option that does not exist")

        for outfit in itertools.product(*slots.values()):
            chosen = dict(zip(slots, outfit))
            matches = [rule for rule in rules if all(chosen.get(slot) == option for slot, option in rule.items() if slot not in ("variant", "skin"))]
            checker.expect(len(matches) <= 1, f"data/outfits.lua: {kind} has {len(matches)} rules matching {chosen}")


def check_rigid(checker: Checker, rig: Rig, animation_id: str, frame: dict) -> None:
    """Each rigid part sits at its joint on its parent and turns with it, or along its bend curve."""
    poses = frame_poses(frame)

    for part_id in RIGID:
        part = rig.by_id[part_id]
        parent = poses[part.parent]
        joint = rotate(part.joint, parent["rotation"])
        entry = poses[part_id]
        rotation = bent(part.bend, parent["rotation"]) if part.bend else parent["rotation"]
        moved = max(abs(entry["x"] - parent["x"] - joint[0]), abs(entry["y"] - parent["y"] - joint[1]), abs(entry["rotation"] - rotation))
        checker.expect(moved <= SEAM_TOLERANCE, f"{animation_id} frame {frame['index']}: {part_id} is {moved:.3f} off its joint on {part.parent}")


def part_mask(frame: dict, visuals: Visuals, canvas: tuple[int, int], part_id: str) -> Image.Image:
    subset = {**frame, "parts": [entry for entry in frame["parts"] if entry["part"] == part_id]}

    return composite_frame(subset, visuals, canvas, 1).getchannel("A").point(lambda alpha: 255 if alpha else 0)


def unhidden(masks: dict[str, Image.Image], order: list[str], part_id: str, skip: tuple[str, ...]) -> Image.Image:
    """The part's pixels no later part draws over, leaving out the parts in skip."""
    visible = masks[part_id]

    for later in order[order.index(part_id) + 1:]:
        if later in masks and later not in skip:
            visible = ImageChops.subtract(visible, masks[later])

    return visible


def check_uncovered(checker: Checker, rig: Rig, manifest: dict, animations: dict) -> None:
    """No part a skin shows covers a pixel of the uncovered part that would be visible without it."""
    order = [part.id for part in rig.parts]

    for skin in rig.skins:
        visuals = Visuals(manifest, skin=skin.id)

        for animation_id, animation in animations.items():
            for frame in animation["frames"]:
                masks = {part_id: part_mask(frame, visuals, rig.canvas, part_id) for part_id in order if visuals.visible(part_id)}
                target = unhidden(masks, order, UNCOVERED, skin.show)

                for part_id in skin.show:
                    covered = ImageChops.multiply(target, unhidden(masks, order, part_id, ())).histogram()[255]
                    checker.expect(not covered, f"skin {skin.id}: {animation_id} frame {frame['index']}: {part_id} covers {covered} {UNCOVERED} pixels")


def toe(rig: Rig, entry: dict) -> tuple[float, float]:
    """The foot's toe corner on the canvas."""
    point = rotate(rig.by_id[entry["part"]].toe, entry["rotation"])

    return (entry["x"] + point[0], entry["y"] + point[1])


def check_frames(checker: Checker, animations: dict, clips: dict, rig: Rig, manifest: dict) -> None:
    """Swaps resolve, nothing scales or skews, knees bend forward, grounded frames stand on the
    feet row, planted feet stay put and every animation loops without a jump."""
    visuals = Visuals(manifest)

    for animation_id, animation in animations.items():
        family = animation_id.split("_")[0]
        planted = clips[animation_id].planted if animation_id in clips else ()
        blinks = 0
        complete = True
        toes = None

        for frame in animation["frames"]:
            poses = frame_poses(frame)
            where = f"{animation_id} frame {frame['index']}"

            if not checker.expect(sorted(poses) == sorted(rig.by_id) and len(frame["parts"]) == len(rig.parts), f"{where}: does not list every part exactly once"):
                complete = False
                continue

            for entry in frame["parts"]:
                # The runtime reads a missing scale as 1, and a missing skew as 0.
                transform = (entry.get("scaleX", 1), entry.get("scaleY", 1), entry.get("skewX", 0), entry.get("skewY", 0))
                checker.expect(transform == (1, 1, 0, 0), f"{where}: {entry['part']} scales or skews by {transform}")

                if entry["part"] in SWAP_STATES:
                    variant = visuals.state_asset(entry["part"], entry.get("state"))
                    checker.expect(variant is not None and (SKELETAL_ROOT / variant["asset"]).is_file(), f"{where}: {entry['part']} state {entry.get('state')!r} does not resolve to an image")
                else:
                    checker.expect("state" not in entry, f"{where}: {entry['part']} has a state but no swap images")

            blinks += poses["eyes"].get("state") == "closed"
            check_rigid(checker, rig, animation_id, frame)

            for side in ("near", "far"):
                bend = poses[f"leg_{side}_lower"]["rotation"] - poses[f"leg_{side}_upper"]["rotation"]
                checker.expect(bend > -0.01, f"{where}: the {side} knee bends backward by {-bend:.1f} degrees")

            if family in GROUNDED or frame["index"] in planted:
                lowest = lowest_row(composite_frame(frame, visuals, rig.canvas, PREVIEW_SCALE))
                lowest = lowest // PREVIEW_SCALE if lowest is not None else None
                checker.expect(lowest == rig.feet_row - 1, f"{where}: lowest opaque row is {lowest}, expected {rig.feet_row - 1} (grounded)")

            if frame["index"] in planted:
                current = [toe(rig, poses[foot]) for foot in FEET]
                toes = toes or current

                for foot, start, now in zip(FEET, toes, current):
                    moved = max(abs(now[0] - start[0]), abs(now[1] - start[1]))
                    checker.expect(moved <= SLIDE_TOLERANCE, f"{where}: the planted {foot} toe is {moved:.3f} px from where it stood")

        checker.expect(blinks > 0, f"{animation_id}: never blinks")

        if complete and animation["frames"]:
            jumps = seam_jumps(animation["frames"])
            checker.expect(not jumps, f"{animation_id}: the last frame does not lead back into the first: {'; '.join(jumps[:3])}")


def check_manifest(checker: Checker, rig: Rig, data: AnimationData) -> None:
    if not checker.expect(MANIFEST_PATH.is_file(), f"missing {MANIFEST_PATH}"):
        return

    try:
        manifest = json.loads(MANIFEST_PATH.read_text(encoding="utf-8"))
    except (OSError, UnicodeDecodeError, json.JSONDecodeError) as error:
        checker.expect(False, f"{MANIFEST_PATH}: cannot be read as JSON: {error}")
        return

    body = Body(rig)
    try:
        expected = variant_ids(data)
        clips = [(animation_id, build_clip(body, family, number)) for animation_id, family, number in expected]
    except (ArtError, PoseError) as error:
        checker.expect(False, f"keyframes: {error}")
        return

    checker.expect(manifest == build_manifest(rig, body, clips), "manifest does not match a fresh build; run tools/build_character.py")

    if not checker.expect(isinstance(manifest, dict) and {"canvas", "parts", "animations"} <= set(manifest), f"{MANIFEST_PATH}: needs canvas, parts and animations"):
        return

    checker.expect(manifest["canvas"] == {"width": rig.canvas[0], "height": rig.canvas[1]}, f"manifest canvas is {manifest['canvas']}, the rig gives {rig.canvas}")
    checker.expect([part["id"] for part in manifest["parts"]] == [part.id for part in rig.parts], "manifest parts are not the rig's parts in draw order")

    for part in manifest["parts"]:
        with Image.open(SKELETAL_ROOT / part["asset"]) as image:
            size = image.size

        declared = (part["width"], part["height"])
        checker.expect(size == declared, f"part {part['id']}: image is {size}, manifest declares {declared}")

    parts = {part["id"]: part for part in manifest["parts"]}

    for variant in manifest.get("variants", []):
        if not checker.expect((SKELETAL_ROOT / variant["asset"]).is_file(), f"variant {variant['id']}: missing {variant['asset']}"):
            continue

        with Image.open(SKELETAL_ROOT / variant["asset"]) as image:
            size = image.size

        part = parts.get(variant["part"])
        base = (part["width"], part["height"]) if part else None
        checker.expect(size == (variant["width"], variant["height"]) == base, f"variant {variant['id']}: image is {size}, its part {variant['part']} is {base}; the runtime keeps one pivot per part")

    check_skins(checker, rig, manifest)
    check_outfits(checker, rig, manifest)

    animations = {animation["id"]: animation for animation in manifest["animations"]}
    names = [animation_id for animation_id, _, _ in expected]
    checker.expect(list(animations) == names and len(manifest["animations"]) == len(names), f"animation ids are {list(animations)}, expected {names}")

    for family in NAMES:
        present = [animation_id for animation_id in animations if animation_id.split("_")[0] == family]
        wanted = [f"{family}_{number}" for number in range(1, data.variants + 1)]
        checker.expect(present == wanted, f"{family}: variants are {present}, expected {wanted}")
        check_shared_start(checker, [animations[animation_id] for animation_id in wanted if animation_id in animations])

    for animation_id, clip in clips:
        animation = animations.get(animation_id)

        if not animation:
            continue

        checker.expect(animation["loop"] is True, f"{animation_id}: loop is {animation['loop']!r}; the app plays every animation as a plain loop")
        checker.expect(animation["frameCount"] == len(animation["frames"]) == clip.frames, f"{animation_id}: frameCount does not match the frame list")

        if clip.keys:
            checker.expect(clip.keys[0] == clip.keys[-1], f"{animation_id}: the first and last keys are different poses, so the loop jumps")

    check_frames(checker, animations, dict(clips), rig, manifest)
    check_uncovered(checker, rig, manifest, animations)


def main() -> None:
    checker = Checker()
    sheet = load(checker, load_sheet)
    rig = load(checker, load_rig)
    data = load(checker, load_animation_data)

    if sheet:
        check_sheet(checker, sheet, int(data.sheet["feetRow"]) if data else None)

    if data:
        check_animation_data(checker, data, sheet)

    if rig:
        check_rig(checker, rig)

    if rig and data:
        check_layout(checker, data, rig)
        check_manifest(checker, rig, data)

    print(f"{checker.checks} checks, {checker.failures} failures")
    sys.exit(1 if checker.failures else 0)


if __name__ == "__main__":
    main()
