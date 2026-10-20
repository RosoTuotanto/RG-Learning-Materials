#!/usr/bin/env python3
"""Regenerate the 2x game-ready assets from the vendored Kenney source sheets.

The Kenney roguelike sheets are 16 px tiles with 1 px spacing and no outer
margin. At the game's 960x640 content area the tiles are used at 2x (32 px
effective), so we pre-upscale with nearest-neighbour once here rather than
scaling at runtime, which keeps pixels crisp.

The map tileset holds only the curated tiles listed in tile_palette.py. Every
tile is edge-extruded: a 2 px border repeats its outermost pixels, so texture
sampling just outside a frame while the camera scrolls hits the tile's own
colour instead of a transparent gutter (no seam lines between tiles).

Run from anywhere; paths are resolved relative to this file. Outputs land in
../extra-assets/. Re-running overwrites the generated PNGs and is the supported way to
change selections: edit the tables and rerun. `--check` only verifies the built
tileset; a normal run builds everything and then runs the same check.
"""

import math
import os
import sys

from PIL import Image

from tile_palette import (
	PALETTE,
	SOURCE_MARGIN,
	SOURCE_SPACING,
	SOURCE_TILE_SIZE,
	TILE_MARGIN,
	TILE_SIZE,
	TILE_SPACING,
	TILESET_COLUMNS,
)

TILE = SOURCE_TILE_SIZE
SPACING = SOURCE_SPACING
MARGIN = SOURCE_MARGIN
SCALE = TILE_SIZE // SOURCE_TILE_SIZE

# The extruded border fills the whole gutter: half the spacing on each side of a tile.
EXTRUDE = TILE_SPACING // 2
assert TILE_MARGIN == EXTRUDE, "margin must equal the extrusion width"

HERE = os.path.dirname(os.path.abspath(__file__))
ASSETS = os.path.normpath(os.path.join(HERE, "..", "extra-assets"))

RPG_SHEET = os.path.join(
	ASSETS, "kenney_roguelike-rpg-pack", "Spritesheet", "roguelikeSheet_transparent.png"
)
CHAR_SHEET = os.path.join(
	ASSETS, "kenney_roguelike-characters", "Spritesheet", "roguelikeChar_transparent.png"
)

TILESET_NAME = "tileset-topdown.png"

# Selected characters, in frame order. Coordinates are (column, row) cells on the
# roguelike-characters sheet. The full-body characters live in columns 0 and 1;
# everything to their right is modular equipment. Identities are placeholder
# until Eetu's theme ruling; the frame order below is the imageSheet order.
CHARACTERS = [
	# name,                 col, row, game role
	("hero",                 0, 10, "player hero, teal-hooded traveller"),
	("npc_house",            1,  5, "quest NPC A, white-haired elder (house)"),
	("npc_beach",            1,  6, "quest NPC B, bearded man (beach road)"),
	("npc_bg_woman_orange",  0,  5, "background NPC, blonde woman in orange"),
	("npc_bg_woman_apron",   0,  9, "background NPC, red-haired woman in apron"),
	("npc_bg_man_vest",      1,  8, "background NPC, short-haired man in vest"),
]

# Selected items, in frame order. Coordinates are (column, row) cells on the
# roguelike-rpg-pack sheet. New frames are appended so existing frame indices
# never shift.
ITEMS = [
	# name,      col, row, game role
	("note",      42, 15, "quest/fetch item, sealed note delivered to NPC A"),
	("book_red",  46, 15, "optional plain collectible, red book"),
	("coins",     45, 11, "starting keepsake, stack of gold coins, no game role"),
	("torch",     17,  7, "starting keepsake, lit torch, no game role"),
	("bottle",    54, 14, "beach collectible, glass bottle washed ashore"),
]


def cell_box(col, row):
	"""Pixel box of a source cell, accounting for tile size and spacing."""
	x0 = MARGIN + col * (TILE + SPACING)
	y0 = MARGIN + row * (TILE + SPACING)
	return (x0, y0, x0 + TILE, y0 + TILE)


def upscale(image):
	"""Nearest-neighbour 2x so hard pixel edges are preserved."""
	return image.resize((image.width * SCALE, image.height * SCALE), Image.NEAREST)


def extrude(tile):
	"""Return the tile with an EXTRUDE px border repeating its outermost pixels."""
	size = tile.width
	padded = Image.new("RGBA", (size + 2 * EXTRUDE, size + 2 * EXTRUDE))
	padded.paste(tile, (EXTRUDE, EXTRUDE))

	# Edge strips stretch the outermost row or column across the border.
	strips = [
		((0, 0, size, 1), (size, EXTRUDE), (EXTRUDE, 0)),
		((0, size - 1, size, size), (size, EXTRUDE), (EXTRUDE, size + EXTRUDE)),
		((0, 0, 1, size), (EXTRUDE, size), (0, EXTRUDE)),
		((size - 1, 0, size, size), (EXTRUDE, size), (size + EXTRUDE, EXTRUDE)),
	]
	for box, stretched, position in strips:
		padded.paste(tile.crop(box).resize(stretched, Image.NEAREST), position)

	corners = [
		((0, 0), (0, 0)),
		((size - 1, 0), (size + EXTRUDE, 0)),
		((0, size - 1), (0, size + EXTRUDE)),
		((size - 1, size - 1), (size + EXTRUDE, size + EXTRUDE)),
	]
	for (x, y), position in corners:
		corner = Image.new("RGBA", (EXTRUDE, EXTRUDE), tile.getpixel((x, y)))
		padded.paste(corner, position)

	return padded


def tileset_rows():
	return math.ceil(len(PALETTE) / TILESET_COLUMNS)


def tile_origin(index):
	"""Top-left of tile content (0-based index), ponytiled's frame formula."""
	stride = TILE_SIZE + TILE_SPACING
	return (
		TILE_MARGIN + (index % TILESET_COLUMNS) * stride,
		TILE_MARGIN + (index // TILESET_COLUMNS) * stride,
	)


def palette_tiles(sheet):
	"""Upscaled content of every palette tile, in palette order."""
	return [upscale(sheet.crop(cell_box(col, row))) for _name, col, row in PALETTE]


def build_tileset():
	sheet = Image.open(RPG_SHEET).convert("RGBA")
	stride = TILE_SIZE + TILE_SPACING
	rows = tileset_rows()
	out = Image.new("RGBA", (TILESET_COLUMNS * stride, rows * stride), (0, 0, 0, 0))

	for index, tile in enumerate(palette_tiles(sheet)):
		x, y = tile_origin(index)
		out.paste(extrude(tile), (x - EXTRUDE, y - EXTRUDE))

	out.save(os.path.join(ASSETS, TILESET_NAME))
	print(
		f"{TILESET_NAME} {out.width}x{out.height} tilewidth={TILE_SIZE} tileheight={TILE_SIZE} "
		f"margin={TILE_MARGIN} spacing={TILE_SPACING} columns={TILESET_COLUMNS} "
		f"tilecount={TILESET_COLUMNS * rows} (used {len(PALETTE)}, rest transparent)"
	)


def check_tileset():
	"""Return a list of problems with the built tileset; empty means it is valid."""
	sheet = Image.open(RPG_SHEET).convert("RGBA")
	built = Image.open(os.path.join(ASSETS, TILESET_NAME)).convert("RGBA")
	stride = TILE_SIZE + TILE_SPACING
	problems = []

	expected_size = (TILESET_COLUMNS * stride, tileset_rows() * stride)
	if built.size != expected_size:
		return [f"image size {built.size}, expected {expected_size}"]

	# Tiled derives the column count from the image width; it must match ours.
	tiled_columns = (built.width - 2 * TILE_MARGIN + TILE_SPACING) // stride
	if tiled_columns != TILESET_COLUMNS:
		problems.append(f"Tiled would see {tiled_columns} columns")

	pixels = built.load()
	for index, tile in enumerate(palette_tiles(sheet)):
		name = PALETTE[index][0]
		x0, y0 = tile_origin(index)

		frame = built.crop((x0, y0, x0 + TILE_SIZE, y0 + TILE_SIZE))
		if frame.tobytes() != tile.tobytes():
			problems.append(f"{name}: frame at ({x0},{y0}) is not the tile content")
			continue

		# Every border pixel must equal the nearest content pixel (clamped lookup).
		for y in range(y0 - EXTRUDE, y0 + TILE_SIZE + EXTRUDE):
			for x in range(x0 - EXTRUDE, x0 + TILE_SIZE + EXTRUDE):
				inside = x0 <= x < x0 + TILE_SIZE and y0 <= y < y0 + TILE_SIZE
				if inside:
					continue
				source_x = min(max(x, x0), x0 + TILE_SIZE - 1)
				source_y = min(max(y, y0), y0 + TILE_SIZE - 1)
				if pixels[x, y] != pixels[source_x, source_y]:
					problems.append(f"{name}: gutter pixel ({x},{y}) differs from edge")
					break
			else:
				continue
			break

	return problems


def build_frame_sheet(source_path, cells, dest_name):
	"""Pack the selected source cells into one uniform, spacing-free frame sheet
	(a clean graphics.newImageSheet layout), then upscale the whole thing 2x."""
	source = Image.open(source_path).convert("RGBA")
	frame_count = len(cells)
	packed = Image.new("RGBA", (TILE * frame_count, TILE), (0, 0, 0, 0))
	for index, (_name, col, row, _role) in enumerate(cells):
		frame = source.crop(cell_box(col, row))
		packed.paste(frame, (index * TILE, 0))
	out = upscale(packed)
	dest = os.path.join(ASSETS, dest_name)
	out.save(dest)
	frame_w = TILE * SCALE
	print(
		f"{dest_name} {out.size} frames={frame_count} "
		f"frameWidth={frame_w} frameHeight={frame_w}"
	)


def run_check():
	problems = check_tileset()
	if problems:
		for problem in problems:
			print(f"CHECK FAILED: {problem}")
		return 1
	print(f"check ok: {len(PALETTE)} tiles, frames and extruded gutters verified")
	return 0


def main():
	if "--check" in sys.argv[1:]:
		return run_check()

	build_tileset()
	build_frame_sheet(CHAR_SHEET, CHARACTERS, "characters.png")
	build_frame_sheet(RPG_SHEET, ITEMS, "items.png")
	return run_check()


if __name__ == "__main__":
	sys.exit(main())
