#!/usr/bin/env python3
"""Generate the demo's placeholder sound effects.

The demo ships no recorded audio. These are synthesised from noise and sine sweeps with
the standard library alone, so the project stays free of both binary dependencies and
sample licensing. They are placeholders: good enough to make version 6 audible, not
sound design. Replace them with real recordings and the Lua side needs no changes.

Run from anywhere:

    python3 tools/generate_audio.py
"""

import argparse
import math
import random
import struct
import wave
from pathlib import Path

SAMPLE_RATE = 22050
SAMPLE_WIDTH = 2
MAX_AMPLITUDE = 2 ** 15 - 1

# Fixed so that regenerating the set never changes the shipped files.
RANDOM_SEED = 20260801

# Length of the fade applied to the end of every sound, in seconds. Without it the
# waveform is cut mid-cycle and every playback ends on a click.
TAIL_FADE = 0.008

Layer = tuple[list[float], float]


def sample_count(duration: float) -> int:
    return int(duration * SAMPLE_RATE)


def silence(duration: float) -> list[float]:
    return [0.0] * sample_count(duration)


def noise(duration: float, generator: random.Random) -> list[float]:
    return [generator.uniform(-1.0, 1.0) for _ in range(sample_count(duration))]


def low_pass(samples: list[float], cutoff: float) -> list[float]:
    """One-pole low pass. Rounds off noise into something with a body."""
    delta = 1.0 / SAMPLE_RATE
    time_constant = 1.0 / (2.0 * math.pi * cutoff)
    alpha = delta / (time_constant + delta)

    output = []
    previous = 0.0

    for sample in samples:
        previous += alpha * (sample - previous)
        output.append(previous)

    return output


def high_pass(samples: list[float], cutoff: float) -> list[float]:
    """The complement of the low pass, which is where the crack of a shot lives."""
    low = low_pass(samples, cutoff)

    return [samples[index] - low[index] for index in range(len(samples))]


def decay(samples: list[float], time_constant: float) -> list[float]:
    """Exponential amplitude envelope. Everything here is a hit, so nothing sustains."""
    output = []

    for index, sample in enumerate(samples):
        seconds = index / SAMPLE_RATE
        output.append(sample * math.exp(-seconds / time_constant))

    return output


def sine_sweep(
    duration: float,
    start_frequency: float,
    end_frequency: float,
    time_constant: float,
) -> list[float]:
    """A pitch drop, which is what gives an impact its weight."""
    total = sample_count(duration)
    output = []
    phase = 0.0

    for index in range(total):
        progress = index / max(total - 1, 1)
        frequency = start_frequency + (end_frequency - start_frequency) * progress
        phase += 2.0 * math.pi * frequency / SAMPLE_RATE

        seconds = index / SAMPLE_RATE
        output.append(math.sin(phase) * math.exp(-seconds / time_constant))

    return output


def mix(duration: float, *layers: Layer) -> list[float]:
    """Sum layers of different lengths into one buffer."""
    output = silence(duration)

    for layer, gain in layers:
        for index in range(min(len(layer), len(output))):
            output[index] += layer[index] * gain

    return output


def normalise(samples: list[float], peak: float) -> list[float]:
    loudest = max(abs(sample) for sample in samples)

    if loudest == 0.0:
        return samples

    scale = peak / loudest

    return [sample * scale for sample in samples]


def apply_tail_fade(samples: list[float]) -> list[float]:
    fade_length = min(sample_count(TAIL_FADE), len(samples))

    for offset in range(fade_length):
        index = len(samples) - fade_length + offset
        samples[index] *= 1.0 - offset / fade_length

    return samples


def write_wave(path: Path, samples: list[float]) -> int:
    apply_tail_fade(samples)

    frames = struct.pack(
        f"<{len(samples)}h",
        *[int(max(-1.0, min(1.0, sample)) * MAX_AMPLITUDE) for sample in samples],
    )

    with wave.open(str(path), "wb") as handle:
        handle.setnchannels(1)
        handle.setsampwidth(SAMPLE_WIDTH)
        handle.setframerate(SAMPLE_RATE)
        handle.writeframes(frames)

    return len(samples)


def make_shot(
    generator: random.Random,
    brightness: float,
    crack_cutoff: float,
    crack_gain: float,
    body_decay: float,
    tail_gain: float,
    thump_start: float,
    thump_end: float,
    thump_gain: float,
) -> list[float]:
    """A shot is a crack, a body and a low thump. The two fighters differ in all three
    rather than in filter cutoff alone, which on its own is not enough to tell apart."""
    duration = 0.25
    source = noise(duration, generator)

    body = decay(low_pass(source, brightness), body_decay)
    crack = decay(high_pass(source, crack_cutoff), 0.008)
    tail = decay(low_pass(source, 900), 0.120)
    thump = sine_sweep(duration, thump_start, thump_end, 0.060)

    return normalise(
        mix(duration, (body, 1.0), (crack, crack_gain), (tail, tail_gain), (thump, thump_gain)),
        0.92,
    )


def make_impact(
    generator: random.Random,
    brightness: float,
    thud_start: float,
    thud_end: float,
) -> list[float]:
    duration = 0.16
    source = noise(duration, generator)

    click = decay(high_pass(low_pass(source, brightness), 400), 0.018)
    thud = sine_sweep(duration, thud_start, thud_end, 0.045)

    return normalise(mix(duration, (click, 0.5), (thud, 1.0)), 0.78)


def make_casing(generator: random.Random) -> list[float]:
    duration = 0.09
    source = noise(duration, generator)

    click = decay(high_pass(source, 4000), 0.004)
    partials: list[Layer] = [
        (sine_sweep(duration, 3100, 3050, 0.018), 0.6),
        (sine_sweep(duration, 4730, 4650, 0.014), 0.4),
        (sine_sweep(duration, 6310, 6200, 0.010), 0.25),
    ]

    return normalise(mix(duration, (click, 0.5), *partials), 0.45)


def build_sounds(generator: random.Random) -> dict[str, list[float]]:
    """Fighter one is the sharp, snappy one and fighter two the heavy, dull one, so that
    the two sides of the fight can be told apart by ear alone."""
    return {
        "shot_one.wav": make_shot(
            generator,
            brightness=5200,
            crack_cutoff=9000,
            crack_gain=1.1,
            body_decay=0.022,
            tail_gain=0.12,
            thump_start=132,
            thump_end=76,
            thump_gain=0.4,
        ),
        "shot_two.wav": make_shot(
            generator,
            brightness=1500,
            crack_cutoff=2400,
            crack_gain=0.3,
            body_decay=0.055,
            tail_gain=0.45,
            thump_start=70,
            thump_end=42,
            thump_gain=1.0,
        ),
        "impact_one.wav": make_impact(generator, 3200, 190, 95),
        "impact_two.wav": make_impact(generator, 1900, 140, 72),
        "casing.wav": make_casing(generator),
    }


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "--output",
        type=Path,
        default=Path(__file__).resolve().parent.parent / "assets" / "audio",
        help="directory the .wav files are written to",
    )
    arguments = parser.parse_args()

    arguments.output.mkdir(parents=True, exist_ok=True)

    sounds = build_sounds(random.Random(RANDOM_SEED))

    for name in sorted(sounds):
        path = arguments.output / name
        frames = write_wave(path, sounds[name])
        print(f"wrote {path} ({frames} frames, {frames / SAMPLE_RATE * 1000:.0f} ms)")


if __name__ == "__main__":
    main()
