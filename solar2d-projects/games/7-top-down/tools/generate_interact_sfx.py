#!/usr/bin/env python3
"""Generate the top-down game's interaction sound effect (extra-assets/audio/interact.wav).

A short rising two-note chiptune blip. The tone is a soft square built from
its first three odd harmonics only, which keeps the retro character without
the aliasing and harshness of a raw square wave. Standard library only.
"""

import math
import os
import struct
import wave

SAMPLE_RATE = 44100
PEAK = 0.5  # -6 dBFS

# (frequency in Hz, duration in seconds): B5 then E6, a rising fourth.
NOTES = [(987.77, 0.055), (1318.51, 0.115)]

# Odd harmonics rolled off faster than a square wave, stopped at the 5th (6.6 kHz at most).
HARMONICS = [(1, 1.0), (3, 1.0 / 4.0), (5, 1.0 / 9.0)]

ATTACK_SECONDS = 0.003
NOTE_RELEASE_SECONDS = 0.008
TAIL_DECAY_SECONDS = 0.045

HERE = os.path.dirname(os.path.abspath(__file__))
OUTPUT_PATH = os.path.normpath(os.path.join(HERE, "..", "extra-assets", "audio", "interact.wav"))


def write_wav(path, samples):
	"""Write mono 16-bit PCM."""
	with wave.open(path, "wb") as wav:
		wav.setnchannels(1)
		wav.setsampwidth(2)
		wav.setframerate(SAMPLE_RATE)
		frames = bytearray()
		for value in samples:
			frames += struct.pack("<h", round(value * 32767))
		wav.writeframes(bytes(frames))


def note_envelope(frame_index, frame_count, is_last):
	"""Short attack and release so no note edge clicks; the last note decays out."""
	seconds = frame_index / SAMPLE_RATE
	remaining = (frame_count - frame_index) / SAMPLE_RATE
	attack = min(1.0, seconds / ATTACK_SECONDS)

	if is_last:
		release = math.exp(-seconds / TAIL_DECAY_SECONDS) * min(1.0, remaining / NOTE_RELEASE_SECONDS)
	else:
		release = min(1.0, remaining / NOTE_RELEASE_SECONDS)

	return attack * release


def build_samples():
	samples = []
	harmonic_sum = sum(amplitude for _, amplitude in HARMONICS)

	for note_index, (frequency, duration) in enumerate(NOTES):
		frame_count = int(SAMPLE_RATE * duration)
		is_last = note_index == len(NOTES) - 1

		for frame_index in range(frame_count):
			seconds = frame_index / SAMPLE_RATE
			tone = 0.0
			for harmonic, amplitude in HARMONICS:
				tone += amplitude * math.sin(2 * math.pi * frequency * harmonic * seconds)

			samples.append(tone / harmonic_sum * note_envelope(frame_index, frame_count, is_last))

	peak = max(abs(value) for value in samples)
	return [value / peak * PEAK for value in samples]


def main():
	os.makedirs(os.path.dirname(OUTPUT_PATH), exist_ok=True)
	samples = build_samples()
	write_wav(OUTPUT_PATH, samples)
	print(f"{os.path.basename(OUTPUT_PATH)} {len(samples) / SAMPLE_RATE * 1000:.0f}ms frames={len(samples)}")


if __name__ == "__main__":
	main()
