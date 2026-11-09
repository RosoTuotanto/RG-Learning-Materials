#!/usr/bin/env python3
"""Generate each sample's beep-and-boop sound effects from tools/sfx/<sample>.json.

A definition file maps sound names to a list of tones played one after another:

    {"jump": [{"wave": "square", "start": 300, "end": 620, "duration": 0.12, "volume": 0.3}],
     "coin": [{"wave": "sine", "start": 990, "duration": 0.06, "volume": 0.25, "gap": 0.02},
              {"wave": "sine", "start": 1320, "duration": 0.12, "volume": 0.25}]}

Tone keys: wave (sine, square, triangle or noise), start and end in Hz (end defaults to start, so a
different end slides the pitch), duration, attack, release and gap in seconds (attack 0.005 and
release 0.02 by default, which keeps the edges free of clicks; gap is silence after the tone,
default 0), volume from 0 to 1, and seed for noise (default 1). Noise holds each random value for
one cycle of the tone's frequency, so its pitch slides too. Each sound is written to
samples/<sample>/assets/audio/<sound>.wav as 16-bit mono 44.1 kHz, and a rerun writes identical bytes.

    python3 tools/generate_sfx.py [--sample NAME]
"""

import argparse
import json
import math
import random
import re
import struct
import sys
import wave
from pathlib import Path

PROJECT_ROOT = Path(__file__).resolve().parent.parent

SAMPLE_RATE = 44100
SAMPLE_WIDTH = 2
MAX_AMPLITUDE = 2 ** 15 - 1

WAVES = ("sine", "square", "triangle", "noise")
TONE_KEYS = {"wave", "start", "end", "duration", "volume", "attack", "release", "gap", "seed"}

DEFAULT_ATTACK = 0.005
DEFAULT_RELEASE = 0.02
DEFAULT_SEED = 1

# Names become folder and file names, so nothing that could step outside the target folder.
SAFE_NAME = re.compile(r"^[A-Za-z0-9_-]+$")


class DefinitionError(Exception):
    pass


def require_number(tone: dict, key: str, minimum: float, maximum: float | None = None) -> float:
    value = tone[key]

    if isinstance(value, bool) or not isinstance(value, (int, float)):
        raise DefinitionError(f"'{key}' must be a number")

    if value < minimum or (maximum is not None and value > maximum):
        limit = f"from {minimum} to {maximum}" if maximum is not None else f"at least {minimum}"
        raise DefinitionError(f"'{key}' is {value}, must be {limit}")

    return float(value)


def read_tone(tone: object) -> dict:
    if not isinstance(tone, dict):
        raise DefinitionError("each tone must be an object")

    unknown = set(tone) - TONE_KEYS
    if unknown:
        raise DefinitionError(f"unknown keys {sorted(unknown)}")

    for key in ("wave", "start", "duration", "volume"):
        if key not in tone:
            raise DefinitionError(f"missing '{key}'")

    if tone["wave"] not in WAVES:
        raise DefinitionError(f"'wave' must be one of {', '.join(WAVES)}")

    start = require_number(tone, "start", 1.0)
    duration = require_number(tone, "duration", 0.001)
    seed = tone.get("seed", DEFAULT_SEED)

    if isinstance(seed, bool) or not isinstance(seed, int):
        raise DefinitionError("'seed' must be a whole number")

    return {
        "wave": tone["wave"],
        "start": start,
        "end": require_number(tone, "end", 1.0) if "end" in tone else start,
        "duration": duration,
        "volume": require_number(tone, "volume", 0.0, 1.0),
        "attack": require_number(tone, "attack", 0.0) if "attack" in tone else DEFAULT_ATTACK,
        "release": require_number(tone, "release", 0.0) if "release" in tone else DEFAULT_RELEASE,
        "gap": require_number(tone, "gap", 0.0) if "gap" in tone else 0.0,
        "seed": seed,
    }


def oscillator(wave_name: str, phase: float) -> float:
    """Phase runs from 0 to 1 over one cycle."""
    if wave_name == "sine":
        return math.sin(2.0 * math.pi * phase)

    if wave_name == "square":
        return 1.0 if phase < 0.5 else -1.0

    return 4.0 * abs(phase - 0.5) - 1.0


def envelope(index: int, total: int, attack: int, release: int) -> float:
    gain = 1.0

    if attack > 0 and index < attack:
        gain = min(gain, index / attack)

    if release > 0 and index >= total - release:
        gain = min(gain, (total - 1 - index) / release)

    return gain


def render_tone(tone: dict) -> list[float]:
    total = max(int(round(tone["duration"] * SAMPLE_RATE)), 1)

    # Attack and release share the tone between them when they would overlap.
    attack = int(round(tone["attack"] * SAMPLE_RATE))
    release = int(round(tone["release"] * SAMPLE_RATE))
    if attack + release > total:
        scale = total / (attack + release)
        attack = int(attack * scale)
        release = int(release * scale)

    generator = random.Random(tone["seed"])
    held_noise = generator.uniform(-1.0, 1.0)
    phase = 0.0
    output = []

    for index in range(total):
        progress = index / max(total - 1, 1)
        frequency = tone["start"] + (tone["end"] - tone["start"]) * progress

        if tone["wave"] == "noise":
            value = held_noise
        else:
            value = oscillator(tone["wave"], phase)

        output.append(value * tone["volume"] * envelope(index, total, attack, release))

        phase += frequency / SAMPLE_RATE
        if phase >= 1.0:
            phase -= math.floor(phase)
            held_noise = generator.uniform(-1.0, 1.0)

    output.extend([0.0] * int(round(tone["gap"] * SAMPLE_RATE)))

    return output


def write_wave(path: Path, samples: list[float]) -> None:
    frames = struct.pack(
        f"<{len(samples)}h",
        *[int(round(max(-1.0, min(1.0, sample)) * MAX_AMPLITUDE)) for sample in samples],
    )

    with wave.open(str(path), "wb") as handle:
        handle.setnchannels(1)
        handle.setsampwidth(SAMPLE_WIDTH)
        handle.setframerate(SAMPLE_RATE)
        handle.writeframes(frames)


def generate_sample(definition_path: Path, samples_dir: Path) -> None:
    sample = definition_path.stem
    if not SAFE_NAME.match(sample):
        raise DefinitionError(f"{definition_path.name}: sample name must use only letters, digits, - and _")

    with definition_path.open(encoding="utf-8") as handle:
        try:
            sounds = json.load(handle)
        except json.JSONDecodeError as error:
            raise DefinitionError(f"{definition_path.name}: {error}") from None

    if not isinstance(sounds, dict) or not sounds:
        raise DefinitionError(f"{definition_path.name}: expected an object of sound names")

    # Every sound is rendered before anything is written, so a broken definition leaves no files behind.
    rendered: dict[str, list[float]] = {}

    for name in sorted(sounds):
        if not SAFE_NAME.match(name):
            raise DefinitionError(f"{definition_path.name}: sound name '{name}' must use only letters, digits, - and _")

        tones = sounds[name]
        if not isinstance(tones, list) or not tones:
            raise DefinitionError(f"{definition_path.name}: '{name}' must be a non-empty list of tones")

        samples: list[float] = []
        for position, tone in enumerate(tones, start=1):
            try:
                samples.extend(render_tone(read_tone(tone)))
            except DefinitionError as error:
                raise DefinitionError(f"{definition_path.name}: '{name}' tone {position}: {error}") from None

        rendered[name] = samples

    output_dir = samples_dir / sample / "assets" / "audio"
    output_dir.mkdir(parents=True, exist_ok=True)

    for name, samples in rendered.items():
        path = output_dir / f"{name}.wav"
        write_wave(path, samples)
        print(f"wrote {path} ({len(samples) / SAMPLE_RATE * 1000:.0f} ms)")


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("--sample", help="generate only this sample's sounds")
    parser.add_argument(
        "--definitions",
        type=Path,
        default=PROJECT_ROOT / "tools" / "sfx",
        help="folder holding the <sample>.json definition files",
    )
    parser.add_argument(
        "--samples-dir",
        type=Path,
        default=PROJECT_ROOT / "samples",
        help="folder holding the sample folders the sounds are written into",
    )
    arguments = parser.parse_args()

    if arguments.sample:
        paths = [arguments.definitions / f"{arguments.sample}.json"]
        if not paths[0].is_file():
            print(f"no definition file {paths[0]}", file=sys.stderr)
            return 1
    else:
        paths = sorted(arguments.definitions.glob("*.json"))
        if not paths:
            print(f"no definition files in {arguments.definitions}")
            return 0

    try:
        for path in paths:
            generate_sample(path, arguments.samples_dir)
    except DefinitionError as error:
        print(f"error: {error}", file=sys.stderr)
        return 1

    return 0


if __name__ == "__main__":
    sys.exit(main())
