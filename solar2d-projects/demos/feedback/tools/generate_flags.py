#!/usr/bin/env python3
"""Generate the two flags the language button uses.

The button shows a flag rather than a two-letter code. Both flags are drawn here from
their published construction specifications instead of being downloaded, so the project
vendors no third-party image and carries no image licensing, the same reason the sound
effects are synthesised rather than sampled. Pillow is a build-time dependency of this
script alone; nothing at runtime touches an image library.

Run from anywhere:

    python3 tools/generate_flags.py
"""

import argparse
import math
from pathlib import Path

from PIL import Image, ImageDraw

# The diagonals of the Union Jack are unreadable without antialiasing, and Pillow's
# polygon fill has none, so everything is drawn large and resampled down.
SUPERSAMPLE = 8

WHITE = (255, 255, 255)

# Flag of Finland, Government Decision 827/1993: Pantone 294 C.
# https://en.wikipedia.org/wiki/Flag_of_Finland
FINLAND_BLUE = (0x00, 0x2F, 0x6C)

# Union Jack: Pantone 280 and Pantone 186 C.
# https://en.wikipedia.org/wiki/Union_Jack
UNION_BLUE = (0x01, 0x21, 0x69)
UNION_RED = (0xC8, 0x10, 0x2E)

# Pixels per construction unit in the finished images. The Finnish flag is authored in
# elevenths of its height and the Union Jack in thirtieths, so both land on whole pixels.
FINLAND_UNIT = 10
UNION_UNIT = 3

Point = tuple[float, float]


def diagonal_band(
    start: Point,
    end: Point,
    near: float,
    far: float,
    extend: float,
) -> list[Point]:
    """A quad running along start to end, bounded by two perpendicular offsets.

    The perpendicular is start-to-end rotated a quarter turn clockwise on screen, which
    is what lets all four arms of the St Patrick saltire use the same pair of offsets.
    Both ends are pushed out by extend so the band is cut by the flag border rather than
    stopping short of it.
    """
    deltaX = end[0] - start[0]
    deltaY = end[1] - start[1]
    length = math.hypot(deltaX, deltaY)

    unitX, unitY = deltaX / length, deltaY / length
    normalX, normalY = -unitY, unitX

    tail = (start[0] - unitX * extend, start[1] - unitY * extend)
    head = (end[0] + unitX * extend, end[1] + unitY * extend)

    return [
        (tail[0] + normalX * near, tail[1] + normalY * near),
        (head[0] + normalX * near, head[1] + normalY * near),
        (head[0] + normalX * far, head[1] + normalY * far),
        (tail[0] + normalX * far, tail[1] + normalY * far),
    ]


def draw_finland(scale: float) -> Image.Image:
    """11:18, divided 4:3:4 vertically and 5:3:10 horizontally.

    The horizontal division is the asymmetric one: the cross sits nearer the hoist.
    """
    width, height = 18 * scale, 11 * scale

    image = Image.new("RGB", (round(width), round(height)), WHITE)
    draw = ImageDraw.Draw(image)

    draw.rectangle([5 * scale, 0, 8 * scale, height], fill=FINLAND_BLUE)
    draw.rectangle([0, 4 * scale, width, 7 * scale], fill=FINLAND_BLUE)

    return image


def draw_union(scale: float) -> Image.Image:
    """1:2, authored in thirtieths of the height, so the flag is 60 by 30 units.

    Widths as flag-height fractions: the red St George's cross is 1/5 with a 1/15 white
    fimbriation each side; the white St Andrew's saltire is 1/5, showing as 1/10 and 1/30
    either side of the red St Patrick's saltire, which is 1/15 wide and offset by 1/30
    anticlockwise. In units that is 6, 2, 6, 3, 1, 2 and 1.

    The offset is the part that decides whether the flag is upside down. Every arm is
    drawn from its corner towards the centre with the red pushed to the same side of the
    centreline, which is one rotation rather than a mirror, and that leaves the broad
    white band uppermost at the hoist.
    """
    unitsWide, unitsHigh = 60, 30
    centre = (unitsWide * 0.5, unitsHigh * 0.5)

    image = Image.new("RGB", (round(unitsWide * scale), round(unitsHigh * scale)), UNION_BLUE)
    draw = ImageDraw.Draw(image)

    def fill(points: list[Point], colour: tuple[int, int, int]) -> None:
        draw.polygon([(x * scale, y * scale) for x, y in points], fill=colour)

    corners = [(0, 0), (unitsWide, 0), (unitsWide, unitsHigh), (0, unitsHigh)]

    # The white saltire runs corner to corner at its full 1/5 width.
    fill(diagonal_band(corners[0], corners[2], -3, 3, 4), WHITE)
    fill(diagonal_band(corners[1], corners[3], -3, 3, 4), WHITE)

    # The red saltire is four separate arms, each offset 1/30 off the centreline. They do
    # not meet cleanly in the middle, which does not matter: the cross covers the seam.
    for corner in corners:
        fill(diagonal_band(corner, centre, 0, 2, 4), UNION_RED)

    # The cross, drawn as its white fimbriation with the red laid inside it.
    draw.rectangle([(centre[0] - 5) * scale, 0, (centre[0] + 5) * scale, unitsHigh * scale], fill=WHITE)
    draw.rectangle([0, (centre[1] - 5) * scale, unitsWide * scale, (centre[1] + 5) * scale], fill=WHITE)

    draw.rectangle([(centre[0] - 3) * scale, 0, (centre[0] + 3) * scale, unitsHigh * scale], fill=UNION_RED)
    draw.rectangle([0, (centre[1] - 3) * scale, unitsWide * scale, (centre[1] + 3) * scale], fill=UNION_RED)

    return image


def render(builder, unit: int) -> Image.Image:
    large = builder(unit * SUPERSAMPLE)
    size = (large.width // SUPERSAMPLE, large.height // SUPERSAMPLE)

    return large.resize(size, Image.LANCZOS)


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "--output",
        type=Path,
        default=Path(__file__).resolve().parent.parent / "assets" / "images",
        help="directory the .png files are written to",
    )
    arguments = parser.parse_args()

    arguments.output.mkdir(parents=True, exist_ok=True)

    # Named for the language rather than the country, so the Lua side can build the path
    # from the language code without branching.
    flags = {
        "flag_fi.png": render(draw_finland, FINLAND_UNIT),
        "flag_en.png": render(draw_union, UNION_UNIT),
    }

    for name in sorted(flags):
        path = arguments.output / name
        flags[name].save(path)
        print(f"wrote {path} ({flags[name].width}x{flags[name].height})")


if __name__ == "__main__":
    main()
