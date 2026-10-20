#!/usr/bin/env python3
"""Generate the three Tiled maps (village, house, sideroad) for the top-down teaching game.

The maps are written in the JSON shape Tiled itself exports (orthogonal, embedded
tilesets, plain-array tile layers), so ponytiled loads them and learners can open
them in Tiled. The layout lives as editable data in the VILLAGE_*, HOUSE_* and
ROAD_* tables below; tiles are named through tools/tile_palette.py.

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

TERRAIN_ROWS = math.ceil(len(tile_palette.PALETTE) / tile_palette.TILESET_COLUMNS)
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

ZONE_WEST_MESSAGE = "You: I don't want to go that way."
ZONE_NORTH_MESSAGE = "You: There seems to be some obstruction, I can't go this way."
LOCKED_EXIT_QUEST = 1
LOCKED_EXIT_MESSAGE = "You: I don't have a reason to go there yet."

# --------------------------------------------------------------------------
# Village: small and fenced, larger than the 1138x640 view so the camera scrolls.
# Coordinates are (column, row) in tiles; rectangles are (column, row, columns, rows).

VILLAGE_W = 40
VILLAGE_H = 26

# (stamp name, left column, top row). The elder's house is the only stamp with a door.
VILLAGE_BUILDINGS = [
	("elder_house", 4, 4),
	("house_no_door", 24, 6),
	("shed", 36, 4),
]
ELDER_HOUSE_INDEX = 0

VILLAGE_SQUARE = (15, 10, 7, 7)

# One-tile paths as polylines of axis-aligned segments.
VILLAGE_PATHS = [
	[(8, 10), (8, 13)],
	[(0, 13), (14, 13)],
	[(22, 13), (32, 13), (32, 16)],
	[(18, 0), (18, 9)],
	[(18, 17), (18, 25)],
]

VILLAGE_PONDS = [(30, 17, 6, 5)]

# Fence rectangles. The perimeter sits on the boundary walls, so only the garden
# fence needs bodies of its own. Gaps are cells left open.
VILLAGE_FENCES = [
	{"rect": (0, 0, VILLAGE_W, VILLAGE_H), "gaps": [(17, 0), (18, 0), (19, 0), (18, 25), (0, 13)], "walls": False},
	{"rect": (3, 17, 6, 5), "gaps": [], "walls": True},
]

VILLAGE_GATE = (18, 25)

# North road obstruction: props across the road, backed by one wall body.
VILLAGE_OBSTRUCTION = [("crate", 17, 1), ("barrel", 18, 1), ("crate", 19, 1)]

VILLAGE_ZONES = [
	("zoneWestRoad", (1, 12, 2, 3), ZONE_WEST_MESSAGE, False),
	("zoneNorthRoad", (17, 2, 3, 2), ZONE_NORTH_MESSAGE, True),
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
	("flowers_red", 4, 18), ("flowers_blue", 5, 18), ("flowers_red", 6, 18), ("flowers_blue", 7, 18),
	("bush", 4, 19), ("flowers_blue", 5, 19), ("flowers_red", 6, 19), ("bush", 7, 19),
	("flowers_blue", 4, 20), ("flowers_red", 5, 20), ("flowers_blue", 6, 20), ("flowers_red", 7, 20),
	("flowers_red", 5, 10), ("flowers_blue", 6, 10), ("bush", 10, 9),
	("flowers_blue", 25, 12), ("flowers_red", 28, 12),
	("bush", 13, 10), ("stump", 9, 17), ("rock", 22, 21), ("bush", 16, 20), ("bush", 20, 20),
	("rock", 36, 11), ("barrel", 35, 7),
	("grass_tuft", 5, 14), ("grass_tuft", 12, 16), ("grass_tuft", 27, 15), ("grass_tuft", 35, 9),
	("grass_tuft", 10, 22), ("grass_tuft", 29, 22), ("grass_tuft", 2, 11), ("grass_tuft", 23, 4),
	("grass_tuft", 17, 6), ("grass_tuft", 28, 16),
	("signpost", 19, 24),
]

# Market stall props on the square; these get bodies so the hero walks around them.
VILLAGE_SOLID_PROPS = [("barrel", 21, 15), ("crate", 21, 16), ("crate", 20, 16)]

VILLAGE_HERO = (8, 11)
VILLAGE_SPAWNS = [("fromHouse", 8, 10), ("fromSideRoad", 18, 23)]

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

HOUSE_FURNITURE = [
	("wardrobe_top", 1, 1), ("wardrobe_bottom", 1, 2), ("bookshelf", 2, 1), ("bookshelf", 3, 1),
	("plant", 4, 2), ("window", 6, 1), ("window", 11, 1), ("plant", 12, 2),
	("drawers", 14, 1), ("bed", 15, 1), ("bed", 16, 1),
	("chair_down", 11, 5), ("chair_down", 12, 5), ("table_left", 11, 6), ("table_right", 12, 6),
	("chair_up", 11, 7), ("chair_up", 12, 7),
	("barrel", 16, 9), ("crate", 16, 10), ("crate", 15, 10), ("plant", 1, 10),
]
HOUSE_RUG = (2, 5, 5, 4)

# Furniture on the open floor that the player walks around.
HOUSE_SOLID_FURNITURE = [(11, 5, 2, 3), (16, 9, 1, 2), (15, 10, 1, 1), (1, 10, 1, 1)]

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

ROAD_TREES = [
	("pine", 1, 1), ("pine", 3, 2), ("pine", 5, 1), ("pine", 2, 4), ("pine", 4, 5), ("pine", 1, 7),
	("pine", 3, 8), ("pine", 1, 10), ("pine", 4, 11), ("pine", 2, 13), ("pine", 4, 16), ("pine", 1, 16),
	("pine", 3, 18), ("pine", 5, 19),
	("pine", 10, 1), ("pine", 12, 2), ("pine", 14, 1), ("pine", 11, 4), ("pine", 13, 5), ("pine", 10, 9),
	("pine", 12, 8), ("pine", 14, 10), ("pine", 11, 12), ("pine", 13, 13), ("pine", 10, 16),
	("pine", 12, 17), ("pine", 14, 16), ("pine", 11, 19), ("pine", 14, 19),
	("pine", 1, 4), ("pine", 5, 7), ("pine", 4, 9), ("pine", 2, 10), ("pine", 5, 12), ("pine", 3, 14),
	("pine", 1, 13), ("pine", 5, 16), ("pine", 2, 18), ("pine", 1, 19),
	("pine", 14, 4), ("pine", 10, 6), ("pine", 12, 11), ("pine", 13, 8), ("pine", 10, 13),
	("pine", 14, 13), ("pine", 12, 14), ("pine", 11, 16), ("pine", 13, 19),
]

ROAD_DECOR = [
	("signpost", 9, 1), ("bush", 5, 4), ("stump", 9, 10), ("grass_tuft", 7, 11), ("bush", 9, 18),
	("rock", 3, 21), ("rock", 13, 22), ("grass_tuft", 9, 16),
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


def draw_trees(grid, trees, occupancy):
	for kind, col, base_row in trees:
		occupancy.claim([(col, base_row - 1), (col, base_row)], f"{kind} tree")
		grid[base_row - 1][col] = gid(kind + "_top")
		grid[base_row][col] = gid(kind + "_bottom")


def draw_decor(grid, decor, occupancy, allow=()):
	for tile_name, col, row in decor:
		occupancy.claim([(col, row)], tile_name, allow)
		grid[row][col] = gid(tile_name)


def draw_lake(grid, rect):
	col0, row0, cols, rows = rect
	for col, row in rect_cells(rect):
		vertical = "n" if row == row0 else "s" if row == row0 + rows - 1 else ""
		horizontal = "w" if col == col0 else "e" if col == col0 + cols - 1 else ""
		suffix = vertical + horizontal
		grid[row][col] = gid("water_" + suffix if suffix else "water")


def draw_fence(grid, fence):
	"""Horizontal runs carry the corner posts; vertical runs sit between them."""
	col0, row0, cols, rows = fence["rect"]
	gaps = set(fence["gaps"])
	run_cells = []
	for row in (row0, row0 + rows - 1):
		segment = []
		for col in list(range(col0, col0 + cols)) + [None]:
			if col is not None and (col, row) not in gaps:
				segment.append((col, row))
				continue
			for index, (seg_col, seg_row) in enumerate(segment):
				if index == 0:
					name = "fence_start"
				elif index == len(segment) - 1:
					name = "fence_end"
				else:
					name = "fence_post" if index % 4 == 0 else "fence_rail"
				grid[seg_row][seg_col] = gid(name)
			if segment:
				run_cells.append(segment)
			segment = []
	for col, side in ((col0, "fence_side_w"), (col0 + cols - 1, "fence_side_e")):
		segment = []
		for row in list(range(row0 + 1, row0 + rows - 1)) + [None]:
			if row is not None and (col, row) not in gaps:
				grid[row][col] = gid(side)
				segment.append((col, row))
				continue
			if segment:
				run_cells.append(segment)
			segment = []
	return run_cells


def place_stamp(building_grid, detail_grid, stamp_name, col0, row0):
	"""Draw a building stamp; returns (footprint cells, door cells)."""
	layers = tile_palette.STAMPS[stamp_name]
	footprint = []
	doors = []
	for layer_name, grid in (("building", building_grid), ("detail", detail_grid)):
		for delta_row, line in enumerate(layers[layer_name]):
			for delta_col, tile_name in enumerate(line):
				if tile_name is None:
					continue
				cell = (col0 + delta_col, row0 + delta_row)
				grid[cell[1]][cell[0]] = gid(tile_name)
				if cell not in footprint:
					footprint.append(cell)
				if tile_name == "door":
					doors.append(cell)
	return footprint, doors


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
	# ponytiled detects new-style properties by testing properties[1].value for
	# truthiness (ponytiled.lua:37), so the first property must never be false.
	return [{"name": key, "type": PROPERTY_TYPES[key], "value": value} for key, value in pairs]


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


def wall_object(ids, rect):
	return rect_object(ids, "", "wall", rect, [("bodyType", "static")])


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


def assemble_map(width, height, tile_layers, game_objects, physics_objects, tilesets):
	layers = []
	for name, grid in tile_layers:
		layers.append(tile_layer(name, grid, len(layers) + 1))
	layers.append(object_layer("game", game_objects, len(layers) + 1, True))
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
	for what, cells, adjacent in targets:
		candidates = set(cells)
		if adjacent:
			candidates = {(col + delta_col, row + delta_row)
				for col, row in cells for delta_col, delta_row in DIRECTIONS.values()}
		if not candidates & reached:
			raise ValueError(f"{map_name}: {what} is unreachable from the hero start")


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


def build_village(version):
	width, height = VILLAGE_W, VILLAGE_H
	occupancy = Occupancy("village")
	ground = make_grid(width, height, gid("grass"))
	paths = make_grid(width, height)
	buildings = make_grid(width, height)
	details = make_grid(width, height)
	fences = make_grid(width, height)
	decor = make_grid(width, height)
	wall_rects = []

	fill_rect(ground, VILLAGE_SQUARE, "paving")
	square_cells = rect_cells(VILLAGE_SQUARE)
	occupancy.claim(square_cells, "square")

	for pond in VILLAGE_PONDS:
		draw_lake(ground, pond)
		occupancy.claim(rect_cells(pond), "pond")
		wall_rects.append(pond)

	door_cells = []
	for index, (stamp_name, col0, row0) in enumerate(VILLAGE_BUILDINGS):
		footprint, doors = place_stamp(buildings, details, stamp_name, col0, row0)
		occupancy.claim(footprint, stamp_name)
		if index == ELDER_HOUSE_INDEX:
			door_cells = doors
		wall_rects.extend(cells_to_rects([cell for cell in footprint if cell not in doors]))
	elder_door = door_cells[0]

	path_cells = []
	for polyline in VILLAGE_PATHS:
		for cell in polyline_cells(polyline):
			if cell not in path_cells:
				path_cells.append(cell)
	occupancy.claim(path_cells, "path")
	draw_paths(paths, set(path_cells), set(square_cells), width, height)

	for fence in VILLAGE_FENCES:
		runs = draw_fence(fences, fence)
		for run in runs:
			occupancy.claim(run, "fence")
			if fence["walls"]:
				wall_rects.extend(cells_to_rects(run))

	# The obstruction sits on the north road on purpose, so it bypasses the path claim.
	for tile_name, col, row in VILLAGE_OBSTRUCTION:
		decor[row][col] = gid(tile_name)
	wall_rects.append(cells_to_rects([(col, row) for _name, col, row in VILLAGE_OBSTRUCTION])[0])

	draw_trees(decor, VILLAGE_TREES, occupancy)
	draw_decor(decor, VILLAGE_DECOR, occupancy)
	draw_decor(decor, VILLAGE_SOLID_PROPS, occupancy, allow=("square",))
	wall_rects.extend((col, row, 1, 1) for _name, col, row in VILLAGE_SOLID_PROPS)

	# Boundary walls on all four edges; the bottom one leaves the gate open.
	gate_col, gate_row = VILLAGE_GATE
	wall_rects.extend([
		(0, 0, width, 1),
		(0, height - 1, gate_col, 1),
		(gate_col + 1, height - 1, width - gate_col - 1, 1),
		(0, 0, 1, height),
		(width - 1, 0, 1, height),
	])

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
	physics = [wall_object(ids, rect) for rect in wall_rects]
	physics.append(exit_object(ids, "exitToHouse", (elder_door[0], elder_door[1], 1, 1), "house", "fromVillage"))
	lock = None
	if version >= LOCKED_EXIT_FROM_VERSION:
		lock = (LOCKED_EXIT_QUEST, LOCKED_EXIT_MESSAGE)
	physics.append(exit_object(ids, "exitToSideRoad", (gate_col, gate_row, 1, 1), "sideroad", "fromVillage", lock))
	for name, rect, message, once in VILLAGE_ZONES:
		physics.append(zone_object(ids, name, rect, message, once))

	# A locked gate only shows a message, so a wall just outside the map keeps the player in.
	physics.append(wall_object(ids, (gate_col, height, 1, 1)))

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
	targets += [("exitToHouse", [elder_door], False), ("exitToSideRoad", [VILLAGE_GATE], False)]
	targets += [(name, rect_cells(rect), False) for name, rect, _message, _once in VILLAGE_ZONES]
	check_reachable("village", width, height, wall_rects, blocked_extra, VILLAGE_HERO, targets)

	tile_layers = [
		("ground", ground),
		("paths", paths),
		("buildings", buildings),
		("details", details),
		("fences", fences),
		("decor", decor),
	]
	return assemble_map(width, height, tile_layers, game_objects, physics, tilesets)


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
		furniture[height - 1][col] = gid("doormat")

	rug_col, rug_row, rug_cols, rug_rows = HOUSE_RUG
	for col, row in rect_cells(HOUSE_RUG):
		vertical = "n" if row == rug_row else "s" if row == rug_row + rug_rows - 1 else ""
		horizontal = "w" if col == rug_col else "e" if col == rug_col + rug_cols - 1 else ""
		suffix = vertical + horizontal
		furniture[row][col] = gid("rug_" + suffix if suffix else "rug")
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
	physics = [wall_object(ids, rect) for rect in wall_rects]
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

	paths = make_grid(width, height)
	path_cells = []
	for polyline in ROAD_PATHS:
		path_cells.extend(cell for cell in polyline_cells(polyline) if cell not in path_cells)
	occupancy.claim(path_cells, "path")
	draw_paths(paths, set(path_cells), set(), width, height)

	decor = make_grid(width, height)
	draw_trees(decor, ROAD_TREES, occupancy)
	draw_decor(decor, ROAD_DECOR, occupancy)

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
	wall_rects = [
		(0, 0, 1, height),
		(width - 1, 0, 1, height),
		(0, ROAD_WATER_TOP + 1, width, height - ROAD_WATER_TOP - 1),
		(0, 0, exit_col, 1),
		(exit_col + exit_width, 0, width - exit_col - exit_width, 1),
	]
	physics = [wall_object(ids, rect) for rect in wall_rects]
	physics.append(exit_object(ids, "exitToVillage", exit_rect, "village", "fromSideRoad"))

	npc_cell = (ROAD_NPC[2], ROAD_NPC[3])
	check_reachable("sideroad", width, height, wall_rects, [npc_cell], ROAD_HERO, [
		(spawn_name, [(spawn_col, spawn_row)], False),
		(ROAD_NPC[0], [npc_cell], True),
		("exitToVillage", rect_cells(exit_rect), False),
	] + [(item[0], [(item[2], item[3])], False) for item in ROAD_ITEMS])

	tile_layers = [("ground", ground), ("sand", sand), ("paths", paths), ("decor", decor)]
	return assemble_map(width, height, tile_layers, game_objects, physics,
		[TERRAIN_TILESET, CHARACTER_TILESET, ITEM_TILESET])


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
		with open(path, "w", encoding="utf-8") as handle:
			json.dump(data, handle, indent=1)
			handle.write("\n")
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
