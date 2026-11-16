#!/usr/bin/env python3
"""Generate the three Tiled maps (village, house, sideroad) for the top-down teaching game.

The maps are written in the JSON shape and layout Tiled itself exports (orthogonal,
embedded tilesets, plain-array tile layers with one map row per line), so ponytiled
loads them and learners can open them in Tiled. The layout lives as editable data
in the VILLAGE_*, HOUSE_* and ROAD_* tables below; tiles are named through
tools/tile_palette.py.

The course has 16 stages (versio-0 ... versio-15) and every stage folder gets all
three maps. Stage variants:
- versions 0-3: base maps. Zones and items are present in every version; stages
  without the matching extensions simply ignore them.
- versions 4-15: the village also embeds the image-collection tileset "images"
  and places the well as an 80x80 tile object with a static circle body.
- versions 11-15: the village's exit to the side road is quest-locked
  (requiredQuest and lockedMessage properties).

Once the maps are edited by hand in Tiled, the JSON files become the source of
truth and this generator goes stale: re-running it overwrites those edits.

Ponytiled requirements this emitter satisfies (com/ponywolf/ponytiled.lua):
- tile layers are plain integer arrays, never base64 or compressed;
- tilesets are embedded with a bare image path next to the map, and
  loadTileset honours margin and spacing, so the extruded tileset loads as is;
- tile objects from the image collection render via newImageRect(dir .. image)
  and get their body from object properties (radius gives a circle body).

Usage:
    python3 -B build_maps.py --version N --out DIR   # one stage into DIR
    python3 -B build_maps.py --all [ROOT]            # every ROOT/versio-N/maps
    python3 -B build_maps.py --all ROOT --preview    # also render PNG previews
"""

import argparse
import json
import math
import os
import random
import shutil

import tile_palette
from tile_palette import gid

# --------------------------------------------------------------------------
# Paths and stages.

TILE = tile_palette.TILE_SIZE

HERE = os.path.dirname(os.path.abspath(__file__))
GAME_ROOT = os.path.normpath(os.path.join(HERE, ".."))
ASSETS_DIR = os.path.join(GAME_ROOT, "extra-assets")
PREVIEW_ROOT = os.path.join(GAME_ROOT, ".scratch", "map-previews")

STAGE_COUNT = 16
WELL_FROM_VERSION = 4
LOCKED_EXIT_FROM_VERSION = 11

# Stages rendered by --all --preview: the last stage without the well and the first with it.
PREVIEW_VERSIONS = (3, 4)

STALE_FILES = ("city.json", "tileset-roguelike-2x.png")

# Every stage ships every map image, including the well that the maps reference only from WELL_FROM_VERSION on.
STAGE_IMAGES = ("tileset-topdown.png", "characters.png", "items.png", "well.png")

# --------------------------------------------------------------------------
# Embedded tilesets. Sizes must match the PNGs in extra-assets/ exactly.

TERRAIN_ROWS = math.ceil(len(tile_palette.TILE_NAMES) / tile_palette.TILESET_COLUMNS)
TERRAIN_TILECOUNT = TERRAIN_ROWS * tile_palette.TILESET_COLUMNS


def _sheet_extent(count):
	return 2 * tile_palette.TILE_MARGIN + count * TILE + (count - 1) * tile_palette.TILE_SPACING


TERRAIN_TILESET = {
	"columns": tile_palette.TILESET_COLUMNS,
	"firstgid": 1,
	"image": "tileset-topdown.png",
	"imageheight": _sheet_extent(TERRAIN_ROWS),
	"imagewidth": _sheet_extent(tile_palette.TILESET_COLUMNS),
	"margin": tile_palette.TILE_MARGIN,
	"name": "topdown",
	"spacing": tile_palette.TILE_SPACING,
	"tilecount": TERRAIN_TILECOUNT,
	"tileheight": TILE,
	"tilewidth": TILE,
}

CHARACTER_FIRSTGID = TERRAIN_TILECOUNT + 1
CHARACTER_TILESET = {
	"columns": 6,
	"firstgid": CHARACTER_FIRSTGID,
	"image": "characters.png",
	"imageheight": 32,
	"imagewidth": 192,
	"margin": 0,
	"name": "characters",
	"spacing": 0,
	"tilecount": 6,
	"tileheight": 32,
	"tilewidth": 32,
}

ITEM_FIRSTGID = CHARACTER_FIRSTGID + CHARACTER_TILESET["tilecount"]
ITEM_TILESET = {
	"columns": 5,
	"firstgid": ITEM_FIRSTGID,
	"image": "items.png",
	"imageheight": 32,
	"imagewidth": 160,
	"margin": 0,
	"name": "items",
	"spacing": 0,
	"tilecount": 5,
	"tileheight": 32,
	"tilewidth": 32,
}

# Image collection in the shape Tiled writes for "Collection of Images" tilesets.
IMAGES_FIRSTGID = ITEM_FIRSTGID + ITEM_TILESET["tilecount"]
WELL_SIZE = 80
IMAGES_TILESET = {
	"columns": 0,
	"firstgid": IMAGES_FIRSTGID,
	"grid": {"height": 1, "orientation": "orthogonal", "width": 1},
	"margin": 0,
	"name": "images",
	"spacing": 0,
	"tilecount": 1,
	"tileheight": WELL_SIZE,
	"tiles": [
		{"id": 0, "image": "well.png", "imageheight": WELL_SIZE, "imagewidth": WELL_SIZE},
	],
	"tilewidth": WELL_SIZE,
}
WELL_GID = IMAGES_FIRSTGID
WELL_RADIUS = 36

# Character frames: 1 hero, 2 elder Wren, 3 beach stranger Marlow, 4-6 villagers.
HERO_FRAME = 1

# Item frames: 1 note, 2 book_red, 3 coins, 4 torch, 5 bottle.
ITEM_FRAMES = {"note": 1, "book_red": 2, "coins": 3, "torch": 4, "bottle": 5}

HERO_RADIUS = 12

# Scenery bodies reach this far north of their top cell edge, so the hero's feet, which hang below its body, never draw over them.
BODY_LIFT = TILE // 2 - HERO_RADIUS

ZONE_WEST_MESSAGE = "You: I don't want to go that way."
ZONE_NORTH_MESSAGE = "You: There seems to be some obstruction, I can't go this way."
LOCKED_EXIT_QUEST = 1
LOCKED_EXIT_MESSAGE = "You: I don't have a reason to go there yet."

# --------------------------------------------------------------------------
# Village: small and fenced, larger than the 1138x640 view so the camera scrolls.
# Coordinates are (column, row) in tiles; rectangles are (column, row, columns, rows).

VILLAGE_W = 40
VILLAGE_H = 26

# The lawn mixes two grass tiles: the seed fixes which cells get the second one, the share how many.
VILLAGE_GRASS_SEED = 7
VILLAGE_GRASS_ALT_SHARE = 1 / 3

# (stamp name, left column, top row). The elder's house is the only stamp with a door.
VILLAGE_BUILDINGS = [
	("elder_house", 4, 4),
	("house_no_door", 24, 6),
	("shed", 36, 4),
]
ELDER_HOUSE_INDEX = 0

VILLAGE_SQUARE = (15, 10, 7, 7)

# Roads that leave the map: the north and south ones by column, the west one by row.
# Each runs through a fence opening VILLAGE_OPENING_WIDTH tiles wide, centred on it.
VILLAGE_NORTH_ROAD = 18
VILLAGE_SOUTH_ROAD = 18
VILLAGE_WEST_ROAD = 13
VILLAGE_OPENING_WIDTH = 3
VILLAGE_OPENING_HALF = VILLAGE_OPENING_WIDTH // 2

# One-tile paths as polylines of axis-aligned segments.
VILLAGE_PATHS = [
	[(8, 10), (8, VILLAGE_WEST_ROAD)],
	[(0, VILLAGE_WEST_ROAD), (14, VILLAGE_WEST_ROAD)],
	[(22, 13), (32, 13), (32, 16)],
	[(VILLAGE_NORTH_ROAD, 0), (VILLAGE_NORTH_ROAD, 9)],
	[(VILLAGE_SOUTH_ROAD, 17), (VILLAGE_SOUTH_ROAD, VILLAGE_H - 1)],
]

VILLAGE_PONDS = [(30, 17, 6, 5)]

# Floating plants on the pond's open water.
VILLAGE_POND_DECOR = [("lily_pads", 31, 19), ("water_lily", 33, 18), ("lily_pad", 34, 20)]

VILLAGE_EXIT = (VILLAGE_SOUTH_ROAD - VILLAGE_OPENING_HALF, VILLAGE_OPENING_WIDTH)  # first column of the bottom-row exit, width

# Fence rectangles. An opening is (side, first column or row, width): a gap where a road leaves the map.
# A gate is (column, tile name) on the bottom run. The perimeter stands on the boundary walls.
VILLAGE_FENCES = [
	{
		"rect": (0, 0, VILLAGE_W, VILLAGE_H),
		"openings": [
			("n", VILLAGE_NORTH_ROAD - VILLAGE_OPENING_HALF, VILLAGE_OPENING_WIDTH),
			("s", VILLAGE_EXIT[0], VILLAGE_EXIT[1]),
			("w", VILLAGE_WEST_ROAD - VILLAGE_OPENING_HALF, VILLAGE_OPENING_WIDTH),
		],
		"inset": True,
		"walls": False,
	},
	{"rect": (3, 17, 6, 5), "gate": (5, "gate_closed"), "inset": False, "walls": True},
]

# Flower bed inside the garden fence.
VILLAGE_GARDEN_BED = (4, 18, 4, 3)

# North road obstruction: props across the whole opening, on the row inside the fence.
VILLAGE_OBSTRUCTION = [
	("crate", VILLAGE_NORTH_ROAD - VILLAGE_OPENING_HALF, 1),
	("barrel", VILLAGE_NORTH_ROAD, 1),
	("crate", VILLAGE_NORTH_ROAD + VILLAGE_OPENING_HALF, 1),
]

# Each zone spans its road's opening, just inside the obstruction or the fence.
VILLAGE_ZONES = [
	("zoneWestRoad", (1, VILLAGE_WEST_ROAD - VILLAGE_OPENING_HALF, 2, VILLAGE_OPENING_WIDTH), ZONE_WEST_MESSAGE, False),
	("zoneNorthRoad", (VILLAGE_NORTH_ROAD - VILLAGE_OPENING_HALF, 2, VILLAGE_OPENING_WIDTH, 2), ZONE_NORTH_MESSAGE, True),
]

# (kind, column, base row); the crown sits one row above the base.
VILLAGE_TREES = [
	("pine", 1, 2), ("tree", 3, 2), ("pine", 6, 2), ("pine", 10, 2), ("tree", 12, 2),
	("pine", 15, 2), ("pine", 21, 2), ("tree", 23, 2), ("pine", 26, 2), ("tree", 29, 2),
	("pine", 32, 2), ("tree", 34, 2), ("pine", 38, 2),
	("pine", 1, 6), ("tree", 1, 9), ("pine", 1, 17), ("tree", 1, 21), ("pine", 1, 24),
	("tree", 4, 24), ("pine", 7, 24), ("pine", 10, 24), ("tree", 13, 24), ("pine", 15, 24),
	("pine", 21, 24), ("tree", 24, 24), ("pine", 27, 24), ("tree", 30, 24), ("pine", 33, 24),
	("tree", 36, 24),
	("pine", 38, 6), ("tree", 38, 10), ("pine", 38, 14), ("tree", 38, 18), ("pine", 38, 21),
	("tree", 11, 8), ("pine", 13, 6), ("tree", 22, 8), ("pine", 31, 9), ("tree", 34, 11),
	("pine", 36, 15), ("tree", 24, 18), ("pine", 27, 21), ("tree", 11, 20), ("pine", 13, 22),
]

# Single-tile decoration: (tile name, column, row).
VILLAGE_DECOR = [
	("flowers_red", 4, 18), ("flowers_white", 6, 18), ("flowers_blue", 7, 18),
	("flowers_blue", 5, 19), ("flowers_red", 6, 19),
	("flowers_white", 4, 20), ("flowers_red", 5, 20), ("flowers_blue", 7, 20),
	("flowers_red", 5, 10), ("flowers_blue", 6, 10), ("bush", 10, 9),
	("flowers_blue", 25, 12), ("flowers_red", 28, 12),
	("bush", 13, 10), ("stump", 9, 17), ("rock", 22, 21), ("bush", 16, 20), ("bush", 20, 20),
	("rock", 36, 11), ("barrel", 35, 7),
	("grass_tuft", 5, 14), ("plant", 12, 16), ("grass_tuft", 27, 15), ("plant", 35, 9),
	("grass_tuft", 10, 22), ("plant", 29, 22), ("grass_tuft", 2, 11), ("grass_tuft", 23, 4),
	("plant", 17, 6), ("grass_tuft", 28, 16),
	("grass_tuft", 9, 4), ("plant", 14, 19), ("grass_tuft", 25, 20), ("plant", 33, 5),
	("flowers_blue", 29, 20), ("flowers_white", 36, 19),
	("signpost", 20, 24),
]

# Market stall on the square: stock beside the vendor and a produce stand in front of her.
VILLAGE_MARKET_STALL = [("produce_crate", 21, 15), ("stand_right", 21, 16), ("stand_left", 20, 16)]

VILLAGE_HERO = (8, 11)
VILLAGE_SPAWNS = [("fromHouse", 8, 10), ("fromSideRoad", VILLAGE_SOUTH_ROAD, 23)]

# (name, frame, column, row, dialogue node or None)
VILLAGE_NPCS = [
	("npcMarket", 4, 20, 15, None),
	("npcWanderer", 5, 11, 11, None),
	("npcFisher", 6, 33, 16, None),
]

# (object name, item id, column, row)
VILLAGE_ITEMS = [("book", "book_red", 14, 16)]

# --------------------------------------------------------------------------
# House interior: smaller than the 960x640 screen on both axes.

HOUSE_W = 18
HOUSE_H = 12
HOUSE_DOOR = (8, 2)  # first column of the doorway gap in the bottom wall, gap width
HOUSE_WALL_ROWS = 3  # cap row plus the two wall-face rows

# Doorway tiles as (tile, column offset, row offset) from the first gap cell: steps in the gap, the mat just inside.
HOUSE_DOORWAY = [("doorstep_left", 0, 0), ("doorstep_right", 1, 0), ("doormat_left", 0, -1), ("doormat_right", 1, -1)]

# Furniture against the top wall stands on the lower wall-face row and wall decor hangs on the upper one.
HOUSE_FURNITURE = [
	("wardrobe_top", 1, 1), ("wardrobe_bottom", 1, 2),
	("bookcase_top_left", 2, 1), ("bookcase_top_right", 3, 1),
	("bookcase_bottom_left", 2, 2), ("bookcase_bottom_right", 3, 2),
	("potted_plant", 4, 2), ("window_curtains", 6, 1), ("painting", 8, 1), ("fireplace", 8, 2),
	("window_curtains", 10, 1), ("potted_flower", 12, 2),
	("bed", 14, 3), ("clock", 15, 1), ("drawers", 15, 2), ("bed_unmade", 16, 3),
	("chair_down", 11, 5), ("chair_down", 12, 5), ("table_left", 11, 6), ("table_right", 12, 6),
	("chair_up", 11, 7), ("chair_up", 12, 7),
	("barrel", 16, 9), ("crate", 16, 10), ("sack", 15, 10), ("potted_plant", 1, 10),
]
HOUSE_RUG = (2, 5, 5, 4)

# Furniture on the open floor that the player walks around.
HOUSE_SOLID_FURNITURE = [(14, 3, 1, 1), (16, 3, 1, 1), (11, 5, 2, 3), (16, 9, 1, 2), (15, 10, 1, 1), (1, 10, 1, 1)]

HOUSE_HERO = (9, 9)
HOUSE_SPAWN = ("fromVillage", 8, 9)
HOUSE_NPC = ("npcHouse", 2, 8, 5, "npcHouse")

# --------------------------------------------------------------------------
# Side road: a forest road to a beach, narrower than the screen on purpose.

ROAD_W = 16
ROAD_H = 30
ROAD_SAND_TOP = 20
ROAD_WATER_TOP = 24  # the shoreline row: sand edge drawn over water
ROAD_EXIT = (7, 3)  # first column of the top-row exit, width

ROAD_PATHS = [[(8, 0), (8, 7), (6, 7), (6, 14), (8, 14), (8, 19)]]

# Sand reaches one row up into the forest opening so the road ends on the beach: first column, width.
ROAD_SAND_TONGUE = (5, 7)

# Dense along both edges so the forest reads as the barrier; neighbouring columns are offset by one row.
ROAD_TREES = [
	("pine", 0, 1), ("pine", 0, 3), ("pine", 0, 5), ("pine", 0, 7), ("pine", 0, 9),
	("pine", 0, 11), ("pine", 0, 13), ("pine", 0, 15), ("pine", 0, 17), ("pine", 0, 19),
	("pine", 1, 2), ("pine", 1, 4), ("pine", 1, 6), ("pine", 1, 8), ("pine", 1, 10),
	("pine", 1, 12), ("pine", 1, 14), ("pine", 1, 16), ("pine", 1, 18),
	("pine", 2, 1), ("pine", 2, 3), ("pine", 2, 5), ("pine", 2, 7), ("pine", 2, 11),
	("pine", 2, 13), ("pine", 2, 15), ("pine", 2, 17), ("pine", 2, 19),
	("pine", 3, 2), ("pine", 3, 4), ("pine", 3, 6), ("pine", 3, 8), ("pine", 3, 12),
	("pine", 3, 14), ("pine", 3, 18),
	("pine", 4, 1), ("pine", 4, 3), ("pine", 4, 5), ("tree", 4, 11), ("pine", 4, 17), ("pine", 4, 19),
	("pine", 5, 2), ("tree", 5, 4), ("tree", 5, 16),
	("tree", 6, 1),

	("tree", 8, 11),
	("pine", 9, 9), ("pine", 9, 12),
	("tree", 10, 1), ("pine", 10, 9), ("pine", 10, 11), ("pine", 10, 13), ("tree", 10, 17),
	("pine", 11, 2), ("pine", 11, 6), ("pine", 11, 8), ("pine", 11, 10), ("pine", 11, 12), ("pine", 11, 16),
	("pine", 12, 1), ("pine", 12, 3), ("pine", 12, 5), ("pine", 12, 7), ("pine", 12, 9),
	("pine", 12, 11), ("pine", 12, 13), ("pine", 12, 15), ("pine", 12, 17), ("pine", 12, 19),
	("pine", 13, 2), ("pine", 13, 4), ("pine", 13, 6), ("pine", 13, 8), ("pine", 13, 10),
	("pine", 13, 14), ("pine", 13, 16), ("pine", 13, 18),
	("pine", 14, 1), ("pine", 14, 3), ("pine", 14, 5), ("pine", 14, 7), ("pine", 14, 9),
	("pine", 14, 11), ("pine", 14, 13), ("pine", 14, 15), ("pine", 14, 17), ("pine", 14, 19),
	("pine", 15, 2), ("pine", 15, 4), ("pine", 15, 6), ("pine", 15, 8), ("pine", 15, 10),
	("pine", 15, 12), ("pine", 15, 14), ("pine", 15, 16), ("pine", 15, 18),
]

ROAD_DECOR = [
	# Trunk halves on the top row: their crowns lie beyond the map edge.
	("pine_bottom", 1, 0), ("pine_bottom", 3, 0), ("pine_bottom", 5, 0),
	("pine_bottom", 11, 0), ("pine_bottom", 13, 0), ("pine_bottom", 15, 0),

	("signpost", 10, 2), ("bush", 6, 5), ("stump", 9, 10), ("mushroom", 4, 13),
	("flowers_red", 8, 8), ("flowers_blue", 7, 13),
	("grass_tuft", 9, 3), ("grass_tuft", 7, 5), ("grass_tuft", 5, 9), ("grass_tuft", 5, 14), ("grass_tuft", 9, 17),
	("pine_small", 10, 4), ("pine_small", 2, 9), ("pine_small", 13, 12), ("pine_small", 3, 16),
	("pine_small", 6, 18), ("pine_small", 1, 19), ("pine_small", 15, 19),

	# Rocks on the boundary wall columns show why the beach ends there.
	("rock_mossy_small", 0, 20), ("rock_mossy", 0, 21), ("rock", 0, 22), ("rock_low", 0, 23), ("rock_small", 0, 24),
	("rock_mossy", 15, 20), ("rock_small", 15, 21), ("rock", 15, 22), ("rock_low", 15, 23), ("rock", 15, 24),

	("boat", 3, 25), ("mooring_post", 4, 25),
	("water_rock_low", 0, 25), ("water_rock", 15, 25), ("water_rock_small", 14, 26),
	("water_rock", 10, 27), ("water_rock_low", 5, 28), ("water_rock_small", 11, 28),
]

# Marlow's camp beside the spot where he stands.
ROAD_CAMP = [
	("tent_top_left", 2, 20), ("tent_top_right", 3, 20), ("tent_bottom_left", 2, 21), ("tent_bottom_right", 3, 21),
	("stump_axe", 1, 21),
	("campfire", 4, 22),
]

ROAD_HERO = (8, 3)
ROAD_SPAWN = ("fromVillage", 8, 2)
ROAD_NPC = ("npcBeach", 3, 5, 22, "npcBeach")
ROAD_ITEMS = [("bottle", "bottle", 11, 23)]

# --------------------------------------------------------------------------
# Grid helpers. A grid is a list of rows of gids (0 is empty).


def make_grid(width, height, fill=0):
	return [[fill for _col in range(width)] for _row in range(height)]


def rect_cells(rect):
	col0, row0, cols, rows = rect
	return [(col, row) for row in range(row0, row0 + rows) for col in range(col0, col0 + cols)]


def fill_rect(grid, rect, tile_name):
	for col, row in rect_cells(rect):
		grid[row][col] = gid(tile_name)


def polyline_cells(polyline):
	cells = []
	for (start_col, start_row), (end_col, end_row) in zip(polyline, polyline[1:]):
		step_col = (end_col > start_col) - (end_col < start_col)
		step_row = (end_row > start_row) - (end_row < start_row)
		col, row = start_col, start_row
		while True:
			if (col, row) not in cells:
				cells.append((col, row))
			if (col, row) == (end_col, end_row):
				break
			col += step_col
			row += step_row
	return cells


def cells_to_rects(cells):
	"""Merge a cell set into rectangles: horizontal runs first, then identical runs stacked vertically."""
	runs_by_row = {}
	for row in sorted({row for _col, row in cells}):
		columns = sorted(col for col, cell_row in cells if cell_row == row)
		runs = []
		for col in columns:
			if runs and runs[-1][1] == col - 1:
				runs[-1][1] = col
			else:
				runs.append([col, col])
		runs_by_row[row] = [tuple(run) for run in runs]

	rects = []
	open_rects = {}
	for row in sorted(runs_by_row):
		next_open = {}
		for run in runs_by_row[row]:
			if run in open_rects and open_rects[run][1] + open_rects[run][3] == row:
				rect = open_rects[run]
				rect[3] += 1
			else:
				rect = [run[0], row, run[1] - run[0] + 1, 1]
				rects.append(rect)
			next_open[run] = rect
		open_rects = next_open
	return [tuple(rect) for rect in rects]


def fewest_rects(cells):
	"""Rectangles over a cell set, merged row-first or column-first, whichever gives fewer."""
	by_rows = cells_to_rects(cells)
	transposed = cells_to_rects([(row, col) for col, row in cells])
	by_columns = [(col0, row0, cols, rows) for row0, col0, rows, cols in transposed]
	return min(by_rows, by_columns, key=len)


def flood_fill(width, height, blocked, start):
	"""Cells reachable from start in four-way steps over in-map cells that are not blocked."""
	reached = {start}
	frontier = [start]
	while frontier:
		col, row = frontier.pop()
		for delta_col, delta_row in DIRECTIONS.values():
			neighbour = (col + delta_col, row + delta_row)
			inside = 0 <= neighbour[0] < width and 0 <= neighbour[1] < height
			if inside and neighbour not in blocked and neighbour not in reached:
				reached.add(neighbour)
				frontier.append(neighbour)
	return reached


class Occupancy:
	"""Catches layout data that stacks two things on one cell (a tree on a path, an NPC in a wall)."""

	def __init__(self, map_name):
		self.map_name = map_name
		self.owner = {}

	def claim(self, cells, what, allow=()):
		"""Claim cells for what; cells owned by a name in allow (walkable ground) may be shared."""
		for cell in cells:
			if cell in self.owner and self.owner[cell] not in allow:
				raise ValueError(f"{self.map_name}: {what} at {cell} overlaps {self.owner[cell]}")
			self.owner[cell] = what


# Path pieces by the set of edges they connect.
PATH_PIECES = {
	frozenset("ns"): "path_ns",
	frozenset("we"): "path_we",
	frozenset("es"): "path_es",
	frozenset("ws"): "path_ws",
	frozenset("ne"): "path_ne",
	frozenset("nw"): "path_nw",
	frozenset("wes"): "path_wes",
	frozenset("nsw"): "path_nsw",
	frozenset("nes"): "path_nes",
	frozenset("nwe"): "path_nwe",
	frozenset("n"): "path_end_n",
	frozenset("s"): "path_end_s",
}
DIRECTIONS = {"n": (0, -1), "s": (0, 1), "w": (-1, 0), "e": (1, 0)}
OPPOSITE = {"n": "s", "s": "n", "w": "e", "e": "w"}


def draw_paths(grid, path_cells, joins, width, height):
	"""Pick each path piece from its neighbours; paths on the map border run off it."""
	for col, row in path_cells:
		edges = set()
		for direction, (delta_col, delta_row) in DIRECTIONS.items():
			neighbour = (col + delta_col, row + delta_row)
			off_map = not (0 <= neighbour[0] < width and 0 <= neighbour[1] < height)
			if off_map or neighbour in path_cells or neighbour in joins:
				edges.add(direction)
		grid[row][col] = gid(PATH_PIECES[frozenset(edges)])


class Scenery:
	"""Standing scenery: the decor grid below the characters, the grid above them, and the cells that block the hero."""

	def __init__(self, width, height):
		self.decor = make_grid(width, height)
		self.above = make_grid(width, height)
		self.solid = []

	def place(self, tile_name, col, row):
		if tile_name in tile_palette.OVERHEAD_TILES:
			self.above[row][col] = gid(tile_name)
			return
		self.decor[row][col] = gid(tile_name)
		if tile_name not in tile_palette.GROUND_COVER:
			self.block([(col, row)])

	def block(self, cells):
		for cell in cells:
			if cell not in self.solid:
				self.solid.append(cell)

	def trees(self, trees, occupancy):
		for kind, col, base_row in trees:
			occupancy.claim([(col, base_row - 1), (col, base_row)], f"{kind} tree")
			self.place(kind + "_top", col, base_row - 1)
			self.place(kind + "_bottom", col, base_row)

	def pieces(self, pieces, occupancy, allow=()):
		for tile_name, col, row in pieces:
			occupancy.claim([(col, row)], tile_name, allow)
			self.place(tile_name, col, row)

	def bodies(self, width, height, boundary, start):
		"""Rectangles over every in-map cell the hero cannot reach from start, apart from the cells boundary covers.

		Enclosed open cells (crowns between trunks, a fenced bed) join the bodies, which keeps the rectangle count low.
		"""
		covered = {cell for rect in boundary for cell in rect_cells(rect)}
		open_cells = flood_fill(width, height, covered | set(self.solid), start) | covered
		closed = [(col, row) for row in range(height) for col in range(width) if (col, row) not in open_cells]
		return fewest_rects(closed)


def draw_patch(grid, rect, edge_prefix, centre):
	"""Fill a rectangle with centre tiles inside a frame of edge_prefix pieces named by compass side."""
	col0, row0, cols, rows = rect
	for col, row in rect_cells(rect):
		vertical = "n" if row == row0 else "s" if row == row0 + rows - 1 else ""
		horizontal = "w" if col == col0 else "e" if col == col0 + cols - 1 else ""
		suffix = vertical + horizontal
		grid[row][col] = gid(edge_prefix + "_" + suffix if suffix else centre)


def draw_fence(grid, fence):
	"""Draw a fence rectangle with a post at every cell boundary; returns its runs.

	Each side may have one opening, a gap framed by posts. A gate is a tile with its own posts on the bottom run.
	"""
	col0, row0, cols, rows = fence["rect"]
	last_col = col0 + cols - 1
	bottom_row = row0 + rows - 1
	gate_col, gate_name = fence.get("gate", (None, None))
	openings = fence.get("openings", [])
	gaps = {side: range(first, first + width) for side, first, width in openings}
	assert len(gaps) == len(openings), "a fence side has more than one opening"

	# Rail pieces by (post on the west side, post on the east side).
	pieces = {(True, True): "single", (True, False): "start", (False, True): "end", (False, False): "rail"}

	# An inset fence keeps its side runs off the rectangle's outermost pixels; the rails run between the side columns.
	inset = fence["inset"]
	rail_cols = range(col0 + 1, last_col) if inset else range(col0, last_col + 1)
	side_rows = range(row0 + 1, bottom_row + 1) if inset else range(row0 + 1, bottom_row)
	if gate_col is not None:
		assert "s" not in gaps, "a fence has both a gate and an opening on its bottom run"
		gaps["s"] = range(gate_col, gate_col + 1)
	for side, gap in gaps.items():
		run = rail_cols if side in "ns" else side_rows
		assert gap[0] in run and gap[-1] in run, f"fence opening {side} {list(gap)} is outside its run"

	def rail_piece(col, gap, is_gate):
		# Posts stand on the side of each cell that faces the gap. A gate tile has its own posts, so the cells beside it bring none.
		beside_gate = is_gate and col in (gap[0] - 1, gap[-1] + 1)
		post_west = (gap is None or col > gap[-1]) and not beside_gate and not (inset and col == rail_cols[0])
		post_east = gap is not None and col < gap[0] and not beside_gate
		if not inset:
			post_west = post_west or col == col0
			post_east = post_east or col == last_col
		return pieces[post_west, post_east]

	def outside(side, value):
		return side not in gaps or value not in gaps[side]

	# The top run is the low fence; the bottom run is the tall one, whose posts reach up to the side runs.
	top = [(col, row0) for col in rail_cols if outside("n", col)]
	for col, row in top:
		grid[row][col] = gid("fence_low_" + rail_piece(col, gaps.get("n"), False))
	bottom = [(col, bottom_row) for col in rail_cols if col == gate_col or outside("s", col)]
	for col, row in bottom:
		grid[row][col] = gid(gate_name if col == gate_col else "fence_" + rail_piece(col, gaps.get("s"), gate_col is not None))

	if inset:
		west_name, east_name = "fence_side_e", "fence_side_w"
		grid[row0][col0] = gid("fence_low_cap_e")
		grid[row0][last_col] = gid("fence_low_cap_w")
		top = [(col0, row0)] + top + [(last_col, row0)]
	else:
		west_name, east_name = "fence_side_w", "fence_side_e"
	# A side run's pieces show a post top only at their north end, so the piece above an opening gets an end post.
	west = [(col0, row) for row in side_rows if outside("w", row)]
	east = [(last_col, row) for row in side_rows if outside("e", row)]
	for side, name, run in (("w", west_name, west), ("e", east_name, east)):
		for col, row in run:
			ends_run = not outside(side, row + 1)
			grid[row][col] = gid(name + "_end" if ends_run else name)
	return [top, bottom, west, east]


def place_stamp(building_grid, detail_grid, above_grid, stamp_name, col0, row0):
	"""Draw a building stamp, its roof on the grid above the characters; returns (roof cells, wall cells, door cells)."""
	layers = tile_palette.STAMPS[stamp_name]
	cells = {"roof": [], "wall": [], "detail": []}
	doors = []
	for layer_name, grid in (("roof", above_grid), ("wall", building_grid), ("detail", detail_grid)):
		for delta_row, line in enumerate(layers[layer_name]):
			for delta_col, tile_name in enumerate(line):
				if tile_name is None:
					continue
				cell = (col0 + delta_col, row0 + delta_row)
				grid[cell[1]][cell[0]] = gid(tile_name)
				cells[layer_name].append(cell)
				if tile_name == "door":
					doors.append(cell)
	return cells["roof"], cells["wall"], doors


# --------------------------------------------------------------------------
# Tiled structure builders.


class ObjectIds:
	def __init__(self):
		self.next_id = 1

	def take(self):
		object_id = self.next_id
		self.next_id += 1
		return object_id


PROPERTY_TYPES = {
	"targetMap": "string",
	"targetSpawn": "string",
	"bodyType": "string",
	"isSensor": "bool",
	"node": "string",
	"item": "string",
	"frame": "int",
	"radius": "int",
	"message": "string",
	"once": "bool",
	"requiredQuest": "int",
	"lockedMessage": "string",
}


def _properties(pairs):
	"""Custom properties in name order, which is the order Tiled writes them in."""
	properties = [{"name": key, "type": PROPERTY_TYPES[key], "value": value} for key, value in sorted(pairs, key=lambda pair: pair[0])]

	# ponytiled detects new-style properties by testing properties[1].value for truthiness (ponytiled.lua:37).
	assert not properties or properties[0]["value"] is not False, f"{properties[0]['name']}: the first property must not be false"
	return properties


def tile_layer(name, grid, layer_id):
	data = []
	for row in grid:
		data.extend(row)
	return {
		"data": data,
		"height": len(grid),
		"id": layer_id,
		"name": name,
		"opacity": 1,
		"type": "tilelayer",
		"visible": True,
		"width": len(grid[0]),
		"x": 0,
		"y": 0,
	}


def object_layer(name, objects, layer_id, visible):
	return {
		"draworder": "topdown",
		"id": layer_id,
		"name": name,
		"objects": objects,
		"opacity": 1,
		"type": "objectgroup",
		"visible": visible,
		"x": 0,
		"y": 0,
	}


def tile_object(ids, name, type_name, object_gid, x, y, size, properties):
	"""Tile objects anchor bottom-left: (x, y) is the bottom-left corner in pixels."""
	return {
		"gid": object_gid,
		"height": size,
		"id": ids.take(),
		"name": name,
		"properties": _properties(properties),
		"rotation": 0,
		"type": type_name,
		"visible": True,
		"width": size,
		"x": x,
		"y": y,
	}


def rect_object(ids, name, type_name, rect, properties=None, visible=True):
	col0, row0, cols, rows = rect
	obj = {
		"height": rows * TILE,
		"id": ids.take(),
		"name": name,
		"rotation": 0,
		"type": type_name,
		"visible": visible,
		"width": cols * TILE,
		"x": col0 * TILE,
		"y": row0 * TILE,
	}
	if properties:
		obj["properties"] = _properties(properties)
	return obj


def hero_object(ids, cell):
	col, row = cell
	return tile_object(ids, "hero", "hero", CHARACTER_FIRSTGID + HERO_FRAME - 1,
		col * TILE, (row + 1) * TILE, TILE, [("frame", HERO_FRAME)])


def npc_object(ids, npc):
	name, frame, col, row, node = npc
	properties = [("frame", frame)]
	if node:
		properties.append(("node", node))
	return tile_object(ids, name, "npc", CHARACTER_FIRSTGID + frame - 1,
		col * TILE, (row + 1) * TILE, TILE, properties)


def item_object(ids, item):
	name, item_id, col, row = item
	frame = ITEM_FRAMES[item_id]
	return tile_object(ids, name, "item", ITEM_FIRSTGID + frame - 1,
		col * TILE, (row + 1) * TILE, TILE, [("frame", frame), ("item", item_id)])


def spawn_object(ids, name, col, row):
	return rect_object(ids, name, "spawn", (col, row, 1, 1), visible=False)


def wall_object(ids, rect, lift=0):
	"""A static wall over rect, reaching lift pixels north of its top cell edge."""
	obj = rect_object(ids, "", "wall", rect, [("bodyType", "static")])
	obj["y"] -= lift
	obj["height"] += lift
	return obj


def exit_object(ids, name, rect, target_map, target_spawn, lock=None):
	properties = [
		("bodyType", "static"),
		("isSensor", True),
		("targetMap", target_map),
		("targetSpawn", target_spawn),
	]
	if lock:
		properties.append(("requiredQuest", lock[0]))
		properties.append(("lockedMessage", lock[1]))
	return rect_object(ids, name, "exit", rect, properties)


def zone_object(ids, name, rect, message, once):
	return rect_object(ids, name, "zone", rect, [
		("bodyType", "static"),
		("isSensor", True),
		("message", message),
		("once", once),
	])


def assemble_map(width, height, tile_layers, game_objects, physics_objects, tilesets, above=None):
	"""Tile layers, then the characters, then the optional above grid that hides them, then the hidden physics."""
	layers = []
	for name, grid in tile_layers:
		layers.append(tile_layer(name, grid, len(layers) + 1))
	layers.append(object_layer("game", game_objects, len(layers) + 1, True))
	if above is not None:
		layers.append(tile_layer("above", above, len(layers) + 1))
	layers.append(object_layer("physics", physics_objects, len(layers) + 1, False))
	next_object_id = 1 + max(obj["id"] for obj in game_objects + physics_objects)
	return {
		"compressionlevel": -1,
		"height": height,
		"infinite": False,
		"layers": layers,
		"nextlayerid": len(layers) + 1,
		"nextobjectid": next_object_id,
		"orientation": "orthogonal",
		"renderorder": "right-down",
		"tiledversion": "1.11.2",
		"tileheight": TILE,
		"tilesets": [json.loads(json.dumps(tileset)) for tileset in tilesets],
		"tilewidth": TILE,
		"type": "map",
		"version": "1.10",
		"width": width,
	}


# --------------------------------------------------------------------------
# Reachability self-check: flood fill over tiles from the hero, walls and NPCs block.


def check_reachable(map_name, width, height, wall_rects, blocked_extra, start, targets):
	blocked = set(blocked_extra)
	for rect in wall_rects:
		blocked.update(rect_cells(rect))
	if start in blocked:
		raise ValueError(f"{map_name}: hero start {start} is blocked")
	reached = flood_fill(width, height, blocked, start)
	for what, cells, adjacent in targets:
		candidates = set(cells)
		if adjacent:
			candidates = {(col + delta_col, row + delta_row)
				for col, row in cells for delta_col, delta_row in DIRECTIONS.values()}
		if not candidates & reached:
			raise ValueError(f"{map_name}: {what} is unreachable from the hero start")


def check_road_width(map_name, path_cells, wall_rects):
	"""Every road cell keeps the 3x3 block around it free of walls, so the road stays three tiles wide."""
	blocked = {cell for rect in wall_rects for cell in rect_cells(rect)}
	for col, row in path_cells:
		for delta_col in (-1, 0, 1):
			for delta_row in (-1, 0, 1):
				if (col + delta_col, row + delta_row) in blocked:
					raise ValueError(f"{map_name}: a body at {(col + delta_col, row + delta_row)} narrows the road at {(col, row)}")


def well_blocked_cells(centre_x, centre_y):
	cells = []
	reach = WELL_RADIUS + HERO_RADIUS
	for row in range(int((centre_y - reach) // TILE), int((centre_y + reach) // TILE) + 1):
		for col in range(int((centre_x - reach) // TILE), int((centre_x + reach) // TILE) + 1):
			if math.hypot((col + 0.5) * TILE - centre_x, (row + 0.5) * TILE - centre_y) < reach:
				cells.append((col, row))
	return cells


# --------------------------------------------------------------------------
# Village.


def village_grass(width, height):
	"""Ground grid of two grass tiles in a fixed random mix, so the lawn does not repeat on a visible grid."""
	mix = random.Random(VILLAGE_GRASS_SEED)
	return [[gid("grass_alt" if mix.random() < VILLAGE_GRASS_ALT_SHARE else "grass") for _col in range(width)] for _row in range(height)]


def build_village(version):
	width, height = VILLAGE_W, VILLAGE_H
	occupancy = Occupancy("village")
	ground = village_grass(width, height)
	paths = make_grid(width, height)
	buildings = make_grid(width, height)
	details = make_grid(width, height)
	fences = make_grid(width, height)
	scenery = Scenery(width, height)

	# The square is a stone kerb around cobbles; the kerb pieces need the grass below them.
	draw_patch(paths, VILLAGE_SQUARE, "stone", "paving")
	square_cells = rect_cells(VILLAGE_SQUARE)
	occupancy.claim(square_cells, "square")

	draw_patch(paths, VILLAGE_GARDEN_BED, "meadow", "meadow")

	for pond in VILLAGE_PONDS:
		draw_patch(ground, pond, "water", "water")
		occupancy.claim(rect_cells(pond), "pond")
		scenery.block(rect_cells(pond))

	door_cells = []
	for index, (stamp_name, col0, row0) in enumerate(VILLAGE_BUILDINGS):
		roof, walls, doors = place_stamp(buildings, details, scenery.above, stamp_name, col0, row0)
		occupancy.claim(roof + walls, stamp_name)
		if index == ELDER_HOUSE_INDEX:
			door_cells = doors
		scenery.block([cell for cell in walls if cell not in doors])
	elder_door = door_cells[0]

	path_cells = []
	for polyline in VILLAGE_PATHS:
		for cell in polyline_cells(polyline):
			if cell not in path_cells:
				path_cells.append(cell)
	occupancy.claim(path_cells, "path")
	# The door counts as a join, so the path runs straight up to it.
	draw_paths(paths, set(path_cells), set(square_cells) | {elder_door}, width, height)

	# Where a path arrives at the square, the kerb piece has the path drawn under it, so no grass shows between them.
	for col, row in path_cells:
		for heading, (delta_col, delta_row) in DIRECTIONS.items():
			kerb_col, kerb_row = col + delta_col, row + delta_row
			if (kerb_col, kerb_row) in square_cells:
				kerb = "stone_" + OPPOSITE[heading]
				assert paths[kerb_row][kerb_col] == gid(kerb), f"the path at {(col, row)} must meet the square on a straight edge"
				paths[kerb_row][kerb_col] = gid(kerb + "_path")

	for fence in VILLAGE_FENCES:
		for run in draw_fence(fences, fence):
			occupancy.claim(run, "fence")
			if fence["walls"]:
				scenery.block(run)

	# The obstruction sits on the north road on purpose, so it bypasses the path claim.
	for tile_name, col, row in VILLAGE_OBSTRUCTION:
		scenery.place(tile_name, col, row)

	scenery.trees(VILLAGE_TREES, occupancy)
	scenery.pieces(VILLAGE_DECOR, occupancy)
	scenery.pieces(VILLAGE_POND_DECOR, occupancy, allow=("pond",))
	scenery.pieces(VILLAGE_MARKET_STALL, occupancy, allow=("square",))

	# Boundary walls on all four edges; the bottom one leaves the exit open. The roads north and west end at the walls.
	exit_col, exit_width = VILLAGE_EXIT
	exit_rect = (exit_col, height - 1, exit_width, 1)
	boundary = [
		(0, 0, width, 1),
		(0, height - 1, exit_col, 1),
		(exit_col + exit_width, height - 1, width - exit_col - exit_width, 1),
		(0, 0, 1, height),
		(width - 1, 0, 1, height),
	]
	scenery_rects = scenery.bodies(width, height, boundary, VILLAGE_HERO)
	wall_rects = scenery_rects + boundary

	# Game layer.
	ids = ObjectIds()
	walkable = ("path", "square")
	game_objects = [hero_object(ids, VILLAGE_HERO)]
	occupancy.claim([VILLAGE_HERO], "hero", walkable)
	for name, col, row in VILLAGE_SPAWNS:
		occupancy.claim([(col, row)], name, walkable)
		game_objects.append(spawn_object(ids, name, col, row))
	for npc in VILLAGE_NPCS:
		occupancy.claim([(npc[2], npc[3])], npc[0], walkable)
		game_objects.append(npc_object(ids, npc))
	for item in VILLAGE_ITEMS:
		occupancy.claim([(item[2], item[3])], item[0], walkable)
		game_objects.append(item_object(ids, item))

	square_col, square_row, square_cols, square_rows = VILLAGE_SQUARE
	well_centre_x = (square_col + square_cols / 2) * TILE
	well_centre_y = (square_row + square_rows / 2) * TILE
	tilesets = [TERRAIN_TILESET, CHARACTER_TILESET, ITEM_TILESET]
	blocked_extra = [(npc[2], npc[3]) for npc in VILLAGE_NPCS]

	# Physics layer.
	physics = [wall_object(ids, rect, BODY_LIFT) for rect in scenery_rects]
	physics += [wall_object(ids, rect) for rect in boundary]
	physics.append(exit_object(ids, "exitToHouse", (elder_door[0], elder_door[1], 1, 1), "house", "fromVillage"))
	lock = None
	if version >= LOCKED_EXIT_FROM_VERSION:
		lock = (LOCKED_EXIT_QUEST, LOCKED_EXIT_MESSAGE)
	physics.append(exit_object(ids, "exitToSideRoad", exit_rect, "sideroad", "fromVillage", lock))
	for name, rect, message, once in VILLAGE_ZONES:
		physics.append(zone_object(ids, name, rect, message, once))

	# A locked exit only shows a message, so a wall just outside the map keeps the player in.
	physics.append(wall_object(ids, (exit_col, height, exit_width, 1)))

	# The well is created last so it gets the next free object id, as Tiled gives a new object.
	if version >= WELL_FROM_VERSION:
		tilesets.append(IMAGES_TILESET)
		game_objects.append(tile_object(ids, "well", "", WELL_GID,
			int(well_centre_x - WELL_SIZE / 2), int(well_centre_y + WELL_SIZE / 2), WELL_SIZE,
			[("bodyType", "static"), ("radius", WELL_RADIUS)]))
		blocked_extra.extend(well_blocked_cells(well_centre_x, well_centre_y))

	targets = [(name, [(col, row)], False) for name, col, row in VILLAGE_SPAWNS]
	targets += [(npc[0], [(npc[2], npc[3])], True) for npc in VILLAGE_NPCS]
	targets += [(item[0], [(item[2], item[3])], False) for item in VILLAGE_ITEMS]
	targets += [("exitToHouse", [elder_door], False), ("exitToSideRoad", rect_cells(exit_rect), False)]
	targets += [(name, rect_cells(rect), False) for name, rect, _message, _once in VILLAGE_ZONES]
	check_reachable("village", width, height, wall_rects, blocked_extra, VILLAGE_HERO, targets)

	tile_layers = [
		("ground", ground),
		("paths", paths),
		("buildings", buildings),
		("details", details),
		("fences", fences),
		("decor", scenery.decor),
	]
	return assemble_map(width, height, tile_layers, game_objects, physics, tilesets, scenery.above)


# --------------------------------------------------------------------------
# House.


def build_house(version):
	width, height = HOUSE_W, HOUSE_H
	door_col, door_width = HOUSE_DOOR
	floor = make_grid(width, height, gid("floor"))
	walls = make_grid(width, height)
	furniture = make_grid(width, height)

	# Wall caps ring the room; the top wall shows its face on the two rows below the cap.
	for col in range(width):
		walls[0][col] = gid("cap")
		walls[height - 1][col] = gid("cap")
	for row in range(1, height - 1):
		walls[row][0] = gid("cap_side")
		walls[row][width - 1] = gid("cap_side")
	for col in range(1, width - 1):
		walls[1][col] = gid("wall")
		walls[2][col] = gid("wall_bottom")
	walls[0][0] = gid("cap_nw")
	walls[0][width - 1] = gid("cap_ne")
	walls[height - 1][0] = gid("cap_sw")
	walls[height - 1][width - 1] = gid("cap_se")
	walls[height - 1][door_col - 1] = gid("cap_end_e")
	walls[height - 1][door_col + door_width] = gid("cap_end_w")
	for col in range(door_col, door_col + door_width):
		walls[height - 1][col] = 0

	gap_cols = {col_offset for _name, col_offset, row_offset in HOUSE_DOORWAY if row_offset == 0}
	assert gap_cols == set(range(door_width)), "HOUSE_DOORWAY must put a tile on every cell of the HOUSE_DOOR gap"
	for tile_name, col_offset, row_offset in HOUSE_DOORWAY:
		furniture[height - 1 + row_offset][door_col + col_offset] = gid(tile_name)

	draw_patch(furniture, HOUSE_RUG, "rug", "rug")
	for tile_name, col, row in HOUSE_FURNITURE:
		furniture[row][col] = gid(tile_name)

	ids = ObjectIds()
	spawn_name, spawn_col, spawn_row = HOUSE_SPAWN
	game_objects = [
		hero_object(ids, HOUSE_HERO),
		spawn_object(ids, spawn_name, spawn_col, spawn_row),
		npc_object(ids, HOUSE_NPC),
	]

	wall_rects = [
		(0, 0, width, HOUSE_WALL_ROWS),
		(0, 0, 1, height),
		(width - 1, 0, 1, height),
		(0, height - 1, door_col, 1),
		(door_col + door_width, height - 1, width - door_col - door_width, 1),
	] + HOUSE_SOLID_FURNITURE
	exit_rect = (door_col, height - 1, door_width, 1)
	physics = [wall_object(ids, rect, BODY_LIFT if rect in HOUSE_SOLID_FURNITURE else 0) for rect in wall_rects]
	physics.append(exit_object(ids, "exitToVillage", exit_rect, "village", "fromHouse"))

	npc_cell = (HOUSE_NPC[2], HOUSE_NPC[3])
	check_reachable("house", width, height, wall_rects, [npc_cell], HOUSE_HERO, [
		(spawn_name, [(spawn_col, spawn_row)], False),
		(HOUSE_NPC[0], [npc_cell], True),
		("exitToVillage", rect_cells(exit_rect), False),
	])

	tile_layers = [("floor", floor), ("walls", walls), ("furniture", furniture)]
	return assemble_map(width, height, tile_layers, game_objects, physics,
		[TERRAIN_TILESET, CHARACTER_TILESET, ITEM_TILESET])


# --------------------------------------------------------------------------
# Side road.


def build_sideroad(version):
	width, height = ROAD_W, ROAD_H
	occupancy = Occupancy("sideroad")
	ground = make_grid(width, height, gid("grass"))
	fill_rect(ground, (0, ROAD_WATER_TOP, width, height - ROAD_WATER_TOP), "water")

	# Sand runs edge to edge: grass fades into it at the top, and its bottom row is the shoreline.
	sand = make_grid(width, height)
	fill_rect(sand, (0, ROAD_SAND_TOP, width, 1), "sand_n")
	fill_rect(sand, (0, ROAD_SAND_TOP + 1, width, ROAD_WATER_TOP - ROAD_SAND_TOP - 1), "sand")
	fill_rect(sand, (0, ROAD_WATER_TOP, width, 1), "sand_s")

	tongue_col, tongue_width = ROAD_SAND_TONGUE
	tongue_last = tongue_col + tongue_width - 1
	fill_rect(sand, (tongue_col, ROAD_SAND_TOP - 1, tongue_width, 1), "sand_n")
	fill_rect(sand, (tongue_col, ROAD_SAND_TOP, tongue_width, 1), "sand")
	sand[ROAD_SAND_TOP - 1][tongue_col] = gid("sand_nw")
	sand[ROAD_SAND_TOP - 1][tongue_last] = gid("sand_ne")
	sand[ROAD_SAND_TOP][tongue_col] = gid("sand_inner_nw")
	sand[ROAD_SAND_TOP][tongue_last] = gid("sand_inner_ne")

	paths = make_grid(width, height)
	path_cells = []
	for polyline in ROAD_PATHS:
		path_cells.extend(cell for cell in polyline_cells(polyline) if cell not in path_cells)
	occupancy.claim(path_cells, "path")
	draw_paths(paths, set(path_cells), set(), width, height)

	scenery = Scenery(width, height)
	scenery.trees(ROAD_TREES, occupancy)
	scenery.pieces(ROAD_DECOR, occupancy)
	scenery.pieces(ROAD_CAMP, occupancy)

	npc_cell = (ROAD_NPC[2], ROAD_NPC[3])
	occupancy.claim([npc_cell], ROAD_NPC[0])

	ids = ObjectIds()
	spawn_name, spawn_col, spawn_row = ROAD_SPAWN
	game_objects = [
		hero_object(ids, ROAD_HERO),
		spawn_object(ids, spawn_name, spawn_col, spawn_row),
		npc_object(ids, ROAD_NPC),
	]
	for item in ROAD_ITEMS:
		occupancy.claim([(item[2], item[3])], item[0])
		game_objects.append(item_object(ids, item))

	exit_col, exit_width = ROAD_EXIT
	exit_rect = (exit_col, 0, exit_width, 1)
	boundary = [
		(0, 0, 1, height),
		(width - 1, 0, 1, height),
		(0, ROAD_WATER_TOP + 1, width, height - ROAD_WATER_TOP - 1),
		(0, 0, exit_col, 1),
		(exit_col + exit_width, 0, width - exit_col - exit_width, 1),
	]
	scenery_rects = scenery.bodies(width, height, boundary, ROAD_HERO)
	wall_rects = scenery_rects + boundary
	physics = [wall_object(ids, rect, BODY_LIFT) for rect in scenery_rects]
	physics += [wall_object(ids, rect) for rect in boundary]
	physics.append(exit_object(ids, "exitToVillage", exit_rect, "village", "fromSideRoad"))

	camp_cells = [(col, row) for _name, col, row in ROAD_CAMP]
	check_reachable("sideroad", width, height, wall_rects, [npc_cell], ROAD_HERO, [
		(spawn_name, [(spawn_col, spawn_row)], False),
		(ROAD_NPC[0], [npc_cell], True),
		("exitToVillage", rect_cells(exit_rect), False),
		("camp", camp_cells, True),
	] + [(item[0], [(item[2], item[3])], False) for item in ROAD_ITEMS])
	check_road_width("sideroad", path_cells, wall_rects)

	tile_layers = [("ground", ground), ("sand", sand), ("paths", paths), ("decor", scenery.decor)]
	return assemble_map(width, height, tile_layers, game_objects, physics,
		[TERRAIN_TILESET, CHARACTER_TILESET, ITEM_TILESET], scenery.above)


# --------------------------------------------------------------------------
# The JSON layout Tiled writes, without the trailing spaces it leaves on some lines.

# Columns right of its key where an object value, the objects of an array, and a wrapped array line start.
TILED_OBJECT_INDENT = 3
TILED_ARRAY_INDENT = 7
TILED_WRAP_INDENT = 3


def _tiled_scalar(value):
	if isinstance(value, float) and value.is_integer():
		value = int(value)
	text = json.dumps(value)
	return text.replace("/", "\\/") if isinstance(value, str) else text


def _tiled_object(obj, brace_indent, wrap):
	key_indent = brace_indent + 1
	entries = [" " * key_indent + f'"{key}":' + _tiled_value(obj[key], key_indent, wrap) for key in sorted(obj)]
	return " " * brace_indent + "{\n" + ",\n".join(entries) + "\n" + " " * brace_indent + "}"


def _tiled_value(value, key_indent, wrap):
	if isinstance(value, dict):
		return "\n" + _tiled_object(value, key_indent + TILED_OBJECT_INDENT, wrap)
	if not isinstance(value, list):
		return _tiled_scalar(value)

	# Tiled starts a new line after every `wrap` elements of any array, which puts one map row of layer data on a line.
	parts = []
	for index, element in enumerate(value):
		if index:
			parts.append(",\n" + " " * (key_indent + TILED_WRAP_INDENT) if index % wrap == 0 else ", ")

		if isinstance(element, dict):
			parts.append("\n" + _tiled_object(element, key_indent + TILED_ARRAY_INDENT, wrap))
		else:
			parts.append(_tiled_scalar(element))
	return "[" + "".join(parts) + "]"


def tiled_json(data):
	entries = [f'"{key}":' + _tiled_value(data[key], 1, data["width"]) for key in sorted(data)]
	text = "{ " + ",\n ".join(entries) + "\n}"
	return "\n".join(line.rstrip() for line in text.split("\n"))


# --------------------------------------------------------------------------
# Output.

MAPS = {
	"village": build_village,
	"house": build_house,
	"sideroad": build_sideroad,
}


def referenced_images(data):
	images = []
	for tileset in data["tilesets"]:
		if "image" in tileset:
			images.append(tileset["image"])
		for tile in tileset.get("tiles", []):
			if "image" in tile:
				images.append(tile["image"])
	return images


def write_version(version, out_dir):
	os.makedirs(out_dir, exist_ok=True)
	images = list(STAGE_IMAGES)
	for name, builder in MAPS.items():
		data = builder(version)
		path = os.path.join(out_dir, name + ".json")
		with open(path, "w", encoding="utf-8", newline="\n") as handle:
			handle.write(tiled_json(data))
		images.extend(image for image in referenced_images(data) if image not in images)
	for image in images:
		shutil.copyfile(os.path.join(ASSETS_DIR, image), os.path.join(out_dir, image))
	print(f"versio-{version}: {', '.join(MAPS)} + {len(images)} images -> {out_dir}")


def remove_stale(out_dir):
	for file_name in STALE_FILES:
		path = os.path.join(out_dir, file_name)
		if os.path.exists(path):
			os.remove(path)
			print(f"removed stale {path}")


def render_previews(version, map_dir):
	import render_maps  # imported lazily so building maps needs no Pillow
	render_maps.render_all(map_dir, os.path.join(PREVIEW_ROOT, f"versio-{version}"))


def main():
	parser = argparse.ArgumentParser(description="Build the three top-down teaching maps.")
	parser.add_argument("--version", type=int, help="stage number 0-15 (with --out)")
	parser.add_argument("--out", help="output directory for one stage")
	parser.add_argument("--all", nargs="?", const=GAME_ROOT, metavar="ROOT",
		help="write every ROOT/versio-N/maps (default ROOT: the game folder)")
	parser.add_argument("--preview", action="store_true", help="render PNG previews into .scratch/map-previews/")
	args = parser.parse_args()

	if args.all:
		written = []
		for version in range(STAGE_COUNT):
			version_dir = os.path.join(args.all, f"versio-{version}")
			if not os.path.isdir(version_dir):
				print(f"skipped missing {version_dir}")
				continue
			map_dir = os.path.join(version_dir, "maps")
			write_version(version, map_dir)
			remove_stale(map_dir)
			written.append((version, map_dir))
		if args.preview:
			for version, map_dir in written:
				if version in PREVIEW_VERSIONS:
					render_previews(version, map_dir)
		return

	if args.version is None or args.out is None:
		parser.error("give --version N --out DIR, or --all [ROOT]")
	if not 0 <= args.version < STAGE_COUNT:
		parser.error(f"--version must be 0-{STAGE_COUNT - 1}")
	write_version(args.version, args.out)
	if args.preview:
		render_previews(args.version, args.out)


if __name__ == "__main__":
	main()
