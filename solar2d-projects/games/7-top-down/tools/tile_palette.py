#!/usr/bin/env python3
"""Curated tile selection for the top-down game, shared by the asset and map builders.

Stdlib only so the map builder can import it without Pillow. TILE_NAMES order is the
tile order in extra-assets/tileset-topdown.png: PALETTE, COMPOSITE_TILES, CUSTOM_TILES.
PALETTE and COMPOSITE_PARTS source cells are (column, row) on the Kenney RPG sheet.

Overlay tiles (paths, stone and meadow frames, sand, fences, props, stamps) have transparent surroundings
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

	# Stone square: paving inside a kerb frame whose pieces round off towards the grass.
	("paving", 9, 0),
	("stone_nw", 7, 15),
	("stone_n", 8, 15),
	("stone_ne", 9, 15),
	("stone_w", 7, 16),
	("stone_e", 9, 16),
	("stone_sw", 7, 17),
	("stone_s", 8, 17),
	("stone_se", 9, 17),

	# Meadow patch, framed the same way.
	("meadow_nw", 2, 15),
	("meadow_n", 3, 15),
	("meadow_ne", 4, 15),
	("meadow_w", 2, 16),
	("meadow", 3, 16),
	("meadow_e", 4, 16),
	("meadow_sw", 2, 17),
	("meadow_s", 3, 17),
	("meadow_se", 4, 17),

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
	("sand_inner_nw", 6, 22),
	("sand_inner_ne", 5, 22),

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

	# On the water.
	("lily_pads", 28, 10),
	("lily_pad", 26, 11),
	("water_lily", 25, 11),
	("water_rock", 54, 24),
	("water_rock_small", 55, 24),
	("water_rock_low", 56, 24),
	("boat", 53, 18),
	("mooring_post", 53, 16),

	# Nature.
	("pine_top", 16, 10),
	("pine_bottom", 16, 11),
	("pine_small", 16, 9),
	("tree_top", 13, 10),
	("tree_bottom", 13, 11),
	("bush", 25, 9),
	("plant", 22, 11),
	("flowers_blue", 28, 9),
	("flowers_red", 29, 9),
	("flowers_white", 31, 9),
	("mushroom", 48, 6),
	("rock", 54, 21),
	("rock_small", 55, 21),
	("rock_low", 56, 21),
	("rock_mossy", 54, 22),
	("rock_mossy_small", 55, 22),
	("stump", 53, 19),
	("stump_axe", 53, 21),

	# Tall fence. A horizontal piece is named by where its posts stand: fence_start has one
	# at its west end, fence_end at its east end, fence_single at both, fence_rail at neither.
	# Vertical runs sit on a tile edge: fence_side_w draws on the west edge of its cell,
	# fence_side_e on the east edge.
	("fence_start", 48, 23),
	("fence_rail", 52, 23),
	("fence_end", 49, 23),
	("fence_single", 47, 23),
	("fence_side_w", 51, 23),
	("fence_side_e", 50, 23),
	("gate_closed", 46, 23),

	# Low fence for a run along the top of an area, named like the tall one. The caps end the run above a vertical run.
	("fence_low_start", 48, 24),
	("fence_low_rail", 52, 24),
	("fence_low_end", 49, 24),
	("fence_low_single", 47, 24),
	("fence_low_cap_w", 51, 24),
	("fence_low_cap_e", 50, 24),

	# Props.
	("signpost", 19, 0),
	("crate", 48, 17),
	("barrel", 23, 0),
	("sack", 27, 2),
	("stand_left", 15, 6),
	("stand_right", 17, 6),
	("produce_crate", 13, 7),
	("tent_top_left", 46, 10),
	("tent_top_right", 47, 10),
	("tent_bottom_left", 46, 11),
	("tent_bottom_right", 47, 11),
	("campfire", 14, 8),

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

	# House exterior: brown gabled roof.
	("roof_slope_left", 20, 21),
	("roof_slope_right", 21, 21),
	("roof_top", 25, 21),
	("roof_top_right", 26, 21),
	("gable_right", 21, 22),
	("gable_left_small", 23, 24),
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
	("doorstep_left", 13, 17),
	("doorstep_right", 15, 17),
	("rug_nw", 10, 16),
	("rug_n", 11, 16),
	("rug_ne", 12, 16),
	("rug_w", 10, 17),
	("rug", 11, 17),
	("rug_e", 12, 17),
	("rug_sw", 10, 18),
	("rug_s", 11, 18),
	("rug_se", 12, 18),

	# On the wall face.
	("window_curtains", 44, 4),
	("painting", 29, 10),
	("clock", 26, 8),
	("fireplace", 54, 8),

	# Furniture.
	("table_left", 26, 3),
	("table_middle", 27, 3),
	("table_right", 27, 5),
	("chair_down", 19, 3),
	("chair_up", 20, 3),
	("bed", 15, 3),
	("bed_unmade", 14, 3),
	("drawers", 24, 5),
	("wardrobe_top", 26, 5),
	("wardrobe_bottom", 26, 6),
	("bookcase_top_left", 45, 12),
	("bookcase_top_right", 50, 12),
	("bookcase_bottom_left", 45, 14),
	("bookcase_bottom_right", 50, 14),
]

# Overlays that only appear inside a composite tile, so they take no tileset slot of their own.
COMPOSITE_PARTS = [
	("roof_top_left", 24, 21),
	("gable_left", 20, 22),
	("gable_ridge", 25, 22),
	("eave_left", 20, 23),
	("eave_middle", 22, 22),
	("eave_right", 21, 23),
]

# Tiles made of two palette tiles or parts, the second drawn over the first.
COMPOSITE_TILES = [
	# A kerb piece over a path piece is the square's edge where a path arrives.
	("stone_n_path", "path_ns", "stone_n"),
	("stone_s_path", "path_ns", "stone_s"),
	("stone_w_path", "path_we", "stone_w"),
	("stone_e_path", "path_we", "stone_e"),

	# A low post in front of a vertical fence run ends the run above an opening.
	("fence_side_e_end", "fence_side_e", "fence_low_cap_e"),

	# Roof cells are one tile each, because the whole roof is drawn on the layer above the characters.
	("gable_left_roof", "roof_top_left", "gable_left"),
	("gable_ridge_roof", "roof_top", "gable_ridge"),
	("gable_right_roof", "roof_top_right", "gable_right"),
	("eave_left_wall", "wall", "eave_left"),
	("eave_middle_wall", "wall", "eave_middle"),
	("eave_right_wall", "wall", "eave_right"),
	("eave_left_wall_left", "wall_left", "eave_left"),
	("eave_right_wall_right", "wall_right", "eave_right"),
]

# Tiles drawn for this game: one 16 px image each, extra-assets/custom-tiles/<name>.png.
# They are the last tiles in the tileset.
CUSTOM_TILES = [
	"potted_plant",
	"potted_flower",
	"doormat_left",
	"doormat_right",
]

TILE_NAMES = [name for name, _col, _row in PALETTE] + [name for name, _under, _over in COMPOSITE_TILES] + CUSTOM_TILES

_INDEX = {name: index for index, name in enumerate(TILE_NAMES)}


def gid(name, firstgid=1):
	"""Tiled gid of a palette tile; raises KeyError on an unknown name."""
	return firstgid + _INDEX[name]


# Building stamps: each layer is a list of rows (north first) of tile names or None, all of one size.
# Place them over grass. "roof" is every row down to and including the eave and goes on the layer above
# the characters, with no body. "wall" is the solid base below it, and "detail" (windows, doors) is drawn
# over the wall.

_NO_ROW = [None] * 6

# Gabled front (west) with a flat-roofed wing (east), after the village house in
# Kenney's sample map. South face: two windows and a door in the wing.
ELDER_HOUSE = {
	"roof": [
		["roof_slope_left", "roof_top", "roof_slope_right", None, None, None],
		["gable_left_roof", "gable_ridge_roof", "gable_right_roof", None, None, None],
		["eave_left_wall", "eave_middle_wall", "eave_right_wall", "roof_top", "roof_top", "roof_top_right"],
		[None, None, None, "roof_bottom", "roof_bottom", "roof_bottom_right"],
		_NO_ROW,
		_NO_ROW,
	],
	"wall": [
		_NO_ROW,
		_NO_ROW,
		_NO_ROW,
		["wall_left", "wall", "wall_right", None, None, None],
		["wall_left", "wall", "wall", "wall", "wall", "wall_right"],
		["wall_bottom_left", "wall_bottom", "wall_bottom", "wall_bottom", "wall_bottom", "wall_bottom_right"],
	],
	"detail": [
		_NO_ROW,
		_NO_ROW,
		_NO_ROW,
		_NO_ROW,
		[None, "window", None, "window", None, None],
		[None, None, None, None, "door", None],
	],
}

# Same outline as the elder's house, windows only on the south face.
HOUSE_NO_DOOR = {
	"roof": ELDER_HOUSE["roof"],
	"wall": ELDER_HOUSE["wall"],
	"detail": [
		_NO_ROW,
		_NO_ROW,
		_NO_ROW,
		_NO_ROW,
		[None, "window", None, None, "window", None],
		_NO_ROW,
	],
}

# Two-tile gabled shed with barn doors.
SHED = {
	"roof": [
		["roof_slope_left", "roof_slope_right"],
		["gable_left_small", "gable_right"],
		["eave_left_wall_left", "eave_right_wall_right"],
		[None, None],
	],
	"wall": [
		[None, None],
		[None, None],
		[None, None],
		["wall_bottom_left", "wall_bottom_right"],
	],
	"detail": [
		[None, None],
		[None, None],
		[None, None],
		["barn_door_left", "barn_door_right"],
	],
}

STAMPS = {
	"elder_house": ELDER_HOUSE,
	"house_no_door": HOUSE_NO_DOOR,
	"shed": SHED,
}

# Tiles drawn on the layer above the characters: tree crowns, the tent's top and every roof tile.
OVERHEAD_TILES = {"pine_top", "tree_top", "tent_top_left", "tent_top_right"} | {
	name for stamp in STAMPS.values() for line in stamp["roof"] for name in line if name
}

# Scenery the player walks over. Every other tile placed as scenery below the characters is solid.
GROUND_COVER = {
	"grass_tuft", "plant", "flowers_blue", "flowers_red", "flowers_white", "mushroom",
	"lily_pads", "lily_pad", "water_lily",
}


def _validate():
	names = TILE_NAMES
	cells = [(col, row) for _name, col, row in PALETTE + COMPOSITE_PARTS]
	assert len(set(names)) == len(names), "duplicate palette name"
	assert len(set(cells)) == len(cells), "duplicate palette cell"

	source_names = {name for name, _col, _row in PALETTE + COMPOSITE_PARTS}
	assert len(source_names) == len(PALETTE) + len(COMPOSITE_PARTS), "a composite part shares a palette name"
	for name, under, over in COMPOSITE_TILES:
		assert under in source_names and over in source_names, f"{name}: unknown part"

	for stamp_name, layers in STAMPS.items():
		assert set(layers) == {"roof", "wall", "detail"}, f"{stamp_name}: layers must be roof, wall and detail"
		shapes = {(len(grid), len(grid[0])) for grid in layers.values()}
		assert len(shapes) == 1, f"{stamp_name}: layers differ in size"
		for grid in layers.values():
			for line in grid:
				assert len(line) == len(grid[0]), f"{stamp_name}: ragged row"
				for name in line:
					assert name is None or name in _INDEX, f"{stamp_name}: unknown tile {name}"

		# Per column the roof rows come first and the wall rows follow; details sit on wall cells only.
		for col in range(len(layers["roof"][0])):
			kinds = ["roof" if layers["roof"][row][col] else "wall" if layers["wall"][row][col] else None for row in range(len(layers["roof"]))]
			first_wall = kinds.index("wall") if "wall" in kinds else len(kinds)
			assert "roof" not in kinds[first_wall:], f"{stamp_name}: column {col} has a wall cell above a roof cell"
			drawn = [row for row, kind in enumerate(kinds) if kind]
			assert not drawn or None not in kinds[drawn[0]:drawn[-1] + 1], f"{stamp_name}: column {col} has an empty cell inside the building"
			for row, kind in enumerate(kinds):
				assert not (layers["roof"][row][col] and layers["wall"][row][col]), f"{stamp_name}: cell {(col, row)} is both roof and wall"
				assert not layers["detail"][row][col] or kind == "wall", f"{stamp_name}: detail at {(col, row)} is not on a wall cell"

	below = {name for layers in STAMPS.values() for key in ("wall", "detail") for line in layers[key] for name in line if name}
	assert not OVERHEAD_TILES & below, f"tiles both above and below the characters: {sorted(OVERHEAD_TILES & below)}"
	for name in OVERHEAD_TILES | GROUND_COVER:
		assert name in _INDEX, f"unknown tile {name}"


_validate()
