#!/usr/bin/env python3
"""Curated tile selection for the top-down game, shared by the asset and map builders.

Stdlib only so the map builder can import it without Pillow. PALETTE order is the
tile order in extra-assets/tileset-topdown.png, so gid(name) is stable as long as
entries are only appended. Source cells are (column, row) on the Kenney RPG sheet.

Overlay tiles (paths, sand, fences, props, stamps) have transparent surroundings
and go on a layer above the grass ground layer.
"""

# Output tileset geometry (2x content with a 2 px extruded border around every tile).
TILE_SIZE = 32
TILE_MARGIN = 2
TILE_SPACING = 4
TILESET_COLUMNS = 10

# Source sheet geometry.
SOURCE_TILE_SIZE = 16
SOURCE_SPACING = 1
SOURCE_MARGIN = 0

PALETTE = [
	# Ground.
	("grass", 5, 0),
	("grass_alt", 5, 1),
	("grass_tuft", 22, 10),

	# One-tile-wide dirt path, named by the edges each piece connects to.
	("path_ns", 9, 7),
	("path_we", 9, 8),
	("path_es", 7, 7),
	("path_ws", 8, 7),
	("path_ne", 7, 8),
	("path_nw", 8, 8),
	("path_wes", 5, 7),
	("path_nsw", 6, 7),
	("path_nes", 5, 8),
	("path_nwe", 6, 8),
	("path_end_n", 5, 11),
	("path_end_s", 6, 11),

	# Sand area over grass or water; the edge pieces fade to transparent outwards.
	("sand_nw", 7, 21),
	("sand_n", 8, 21),
	("sand_ne", 9, 21),
	("sand_w", 7, 22),
	("sand", 8, 22),
	("sand_e", 9, 22),
	("sand_sw", 7, 23),
	("sand_s", 8, 23),
	("sand_se", 9, 23),

	# Lake with a grass shore: a 3x3 frame plus inner corners for concave bends,
	# named by the corner that holds the small grass notch.
	("water", 0, 0),
	("water_nw", 2, 0),
	("water_n", 3, 0),
	("water_ne", 4, 0),
	("water_w", 2, 1),
	("water_e", 4, 1),
	("water_sw", 2, 2),
	("water_s", 3, 2),
	("water_se", 4, 2),
	("water_inner_nw", 1, 2),
	("water_inner_ne", 0, 2),
	("water_inner_sw", 1, 1),
	("water_inner_se", 0, 1),

	("paving", 9, 0),

	# Nature.
	("pine_top", 16, 10),
	("pine_bottom", 16, 11),
	("tree_top", 13, 10),
	("tree_bottom", 13, 11),
	("bush", 25, 9),
	("flowers_blue", 28, 9),
	("flowers_red", 29, 9),
	("rock", 54, 21),
	("stump", 53, 19),

	# Fence. Horizontal runs: fence_start, fence_rail/fence_post..., fence_end.
	# Vertical runs sit on a tile edge: fence_side_w draws on the west edge of its
	# cell, fence_side_e on the east edge, so they line up under the run's end posts.
	("fence_start", 48, 23),
	("fence_rail", 52, 23),
	("fence_post", 53, 23),
	("fence_end", 49, 23),
	("fence_side_w", 51, 23),
	("fence_side_e", 50, 23),

	# Props.
	("signpost", 19, 0),
	("crate", 48, 17),
	("barrel", 28, 7),

	# House exterior: beige walls.
	("wall_left", 17, 15),
	("wall", 18, 15),
	("wall_right", 19, 15),
	("wall_bottom_left", 14, 15),
	("wall_bottom", 13, 15),
	("wall_bottom_right", 16, 15),
	("window", 44, 5),
	("door", 33, 0),
	("barn_door_left", 28, 6),
	("barn_door_right", 29, 6),

	# House exterior: brown gabled roof (slopes and gable overlays sit on the detail layer).
	("roof_slope_left", 20, 21),
	("roof_slope_right", 21, 21),
	("roof_top_left", 24, 21),
	("roof_top", 25, 21),
	("roof_top_right", 26, 21),
	("gable_left", 20, 22),
	("gable_right", 21, 22),
	("gable_ridge", 25, 22),
	("gable_left_small", 23, 24),
	("eave_left", 20, 23),
	("eave_middle", 22, 22),
	("eave_right", 21, 23),
	("roof_bottom", 25, 23),
	("roof_bottom_right", 26, 23),

	# Interior. Wall caps are the top-down view of wall tops; wall faces reuse
	# wall and wall_bottom above.
	("floor", 5, 2),
	("cap", 14, 12),
	("cap_side", 15, 13),
	("cap_nw", 16, 12),
	("cap_ne", 17, 12),
	("cap_sw", 16, 13),
	("cap_se", 17, 13),
	("cap_end_w", 13, 12),
	("cap_end_e", 15, 12),
	("doormat", 18, 26),
	("rug_nw", 10, 16),
	("rug_n", 11, 16),
	("rug_ne", 12, 16),
	("rug_w", 10, 17),
	("rug", 11, 17),
	("rug_e", 12, 17),
	("rug_sw", 10, 18),
	("rug_s", 11, 18),
	("rug_se", 12, 18),
	("table_left", 26, 3),
	("table_right", 27, 3),
	("chair_down", 19, 3),
	("chair_up", 20, 3),
	("bed", 15, 3),
	("drawers", 24, 5),
	("wardrobe_top", 26, 5),
	("wardrobe_bottom", 26, 6),
	("bookshelf", 43, 14),
	("plant", 22, 11),
]

_INDEX = {name: index for index, (name, _col, _row) in enumerate(PALETTE)}


def gid(name, firstgid=1):
	"""Tiled gid of a palette tile; raises KeyError on an unknown name."""
	return firstgid + _INDEX[name]


# Building stamps: each layer is a list of rows (north first) of tile names or None.
# Place them over grass; "building" is walls and roof fill, "detail" is drawn above it
# (roof slopes, gable overlays, windows, doors). All layers of a stamp share one size.

# Gabled front (west) with a flat-roofed wing (east), after the village house in
# Kenney's sample map. South face: two windows and a door in the wing.
ELDER_HOUSE = {
	"building": [
		[None, None, None, None, None, None],
		["roof_top_left", "roof_top", "roof_top_right", None, None, None],
		["wall", "wall", "wall", "roof_top", "roof_top", "roof_top_right"],
		["wall_left", "wall", "wall_right", "roof_bottom", "roof_bottom", "roof_bottom_right"],
		["wall_left", "wall", "wall", "wall", "wall", "wall_right"],
		["wall_bottom_left", "wall_bottom", "wall_bottom", "wall_bottom", "wall_bottom", "wall_bottom_right"],
	],
	"detail": [
		["roof_slope_left", "roof_top", "roof_slope_right", None, None, None],
		["gable_left", "gable_ridge", "gable_right", None, None, None],
		["eave_left", "eave_middle", "eave_right", None, None, None],
		[None, None, None, None, None, None],
		[None, "window", None, "window", None, None],
		[None, None, None, None, "door", None],
	],
}

# Same outline as the elder's house, windows only on the south face.
HOUSE_NO_DOOR = {
	"building": [row[:] for row in ELDER_HOUSE["building"]],
	"detail": [
		["roof_slope_left", "roof_top", "roof_slope_right", None, None, None],
		["gable_left", "gable_ridge", "gable_right", None, None, None],
		["eave_left", "eave_middle", "eave_right", None, None, None],
		[None, None, None, None, None, None],
		[None, "window", None, None, "window", None],
		[None, None, None, None, None, None],
	],
}

# Two-tile gabled shed with barn doors.
SHED = {
	"building": [
		[None, None],
		[None, None],
		["wall_left", "wall_right"],
		["wall_bottom_left", "wall_bottom_right"],
	],
	"detail": [
		["roof_slope_left", "roof_slope_right"],
		["gable_left_small", "gable_right"],
		["eave_left", "eave_right"],
		["barn_door_left", "barn_door_right"],
	],
}

STAMPS = {
	"elder_house": ELDER_HOUSE,
	"house_no_door": HOUSE_NO_DOOR,
	"shed": SHED,
}


def _validate():
	names = [name for name, _col, _row in PALETTE]
	cells = [(col, row) for _name, col, row in PALETTE]
	assert len(set(names)) == len(names), "duplicate palette name"
	assert len(set(cells)) == len(cells), "duplicate palette cell"

	for stamp_name, layers in STAMPS.items():
		shapes = {(len(grid), len(grid[0])) for grid in layers.values()}
		assert len(shapes) == 1, f"{stamp_name}: layers differ in size"
		for grid in layers.values():
			for line in grid:
				assert len(line) == len(grid[0]), f"{stamp_name}: ragged row"
				for name in line:
					assert name is None or name in _INDEX, f"{stamp_name}: unknown tile {name}"


_validate()
