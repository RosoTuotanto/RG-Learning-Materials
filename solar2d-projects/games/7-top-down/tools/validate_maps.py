#!/usr/bin/env python3
"""Structural and cross-map validation for the top-down teaching maps.

Every check is derived from what com/ponywolf/ponytiled.lua actually parses, so
a map that passes here loads under ponytiled and Solar2D. Line references are to
that file.

Checks:
- top-level shape Tiled produces and ponytiled assumes: type "map", orthogonal,
  integer tilewidth/tileheight/width/height, a tilesets list, a tiledversion so
  the file opens in Tiled (M.new reads data.width/height/tilewidth/tileheight,
  ponytiled.lua:177).
- tile layers carry a plain integer data array of width*height, and carry
  neither "encoding" nor "compression": ponytiled prints an error and draws
  nothing for encoded/compressed layers (ponytiled.lua:405-407).
- tilesets are embedded (an "image", never a "source"), with firstgid,
  tilecount, columns and image dimensions, and non-overlapping gid ranges: the
  loader builds an imageSheet straight from tileset.image and firstgid
  (loadTileset, ponytiled.lua:241-271; findLast, ponytiled.lua:273-286).
- every tileset image path resolves from the map file's own directory, which is
  what both Tiled and the runtime use (normalizePath(dir .. tileset.image),
  ponytiled.lua:269), and its pixel size matches the declared imagewidth/height
  so the frame maths line up.
- image-collection tilesets (no sheet image, a "tiles" list) have every tile
  image beside the map at its declared size; ponytiled loads those objects with
  newImageRect(dir .. tile.image).
- every tile gid (flip bits masked, ponytiled.lua:290-296) is 0 or lands in a
  tileset range, and all gids of one tile layer stay inside that layer's own
  image-sheet tileset.
- object gids land in a tileset range (gidLookup, ponytiled.lua:288-398).
- extruded tilesets (margin > 0): every gutter pixel equals the adjacent tile
  edge pixel, so sub-pixel sampling never shows a seam.
- exits carry targetMap and targetSpawn; every targetMap file exists and every
  targetSpawn is a real spawn object in the target map; every map has a hero.
- zones carry a message and are sensors; no exit or zone sensor overlaps a
  solid wall body (a buried sensor can never fire).
- requiredQuest (positive int) and lockedMessage (non-empty string) appear only
  together and only on exits, and a locked exit sits on a map edge with a solid
  wall right behind it, since a locked exit only shows a message.
- in a versio-N folder: the village has the well object exactly from versio-4 and
  a locked exitToSideRoad exactly from versio-11.
"""

import json
import os
import re
import sys

from PIL import Image

from build_maps import LOCKED_EXIT_FROM_VERSION, WELL_FROM_VERSION

FLIP_MASK = 0x1FFFFFFF

HERE = os.path.dirname(os.path.abspath(__file__))
GAME_ROOT = os.path.normpath(os.path.join(HERE, ".."))
DEFAULT_MAP_DIR = os.path.join(GAME_ROOT, "versio-15", "maps")

MAP_NAMES = ("village", "house", "sideroad")


class Report:
	def __init__(self):
		self.errors = []

	def check(self, condition, message):
		if not condition:
			self.errors.append(message)


def check_image_file(report, name, map_dir, file_name, width, height, owner):
	"""True when the image exists beside the map with the declared size."""
	image_path = os.path.join(map_dir, file_name)
	if not os.path.exists(image_path):
		report.check(False, f"{name}: {owner} image '{file_name}' not found next to the map at {image_path}")
		return False
	with Image.open(image_path) as image:
		report.check(image.size == (width, height),
			f"{name}: {owner} declares {width}x{height} for '{file_name}' but the image is {image.size[0]}x{image.size[1]}")
		return image.size == (width, height)


def check_gutters(report, name, tileset, image_path):
	"""Each tile's margin-wide border must repeat the tile's own edge pixels."""
	gutter = tileset["margin"]
	tile_w = tileset["tilewidth"]
	tile_h = tileset["tileheight"]
	step_x = tile_w + tileset["spacing"]
	step_y = tile_h + tileset["spacing"]
	with Image.open(image_path) as image:
		pixels = image.convert("RGBA").load()
	for index in range(tileset["tilecount"]):
		left = gutter + (index % tileset["columns"]) * step_x
		top = gutter + (index // tileset["columns"]) * step_y
		mismatch = None
		for y in range(top - gutter, top + tile_h + gutter):
			for x in range(left - gutter, left + tile_w + gutter):
				inside_x = min(max(x, left), left + tile_w - 1)
				inside_y = min(max(y, top), top + tile_h - 1)
				if (inside_x, inside_y) != (x, y) and pixels[x, y] != pixels[inside_x, inside_y]:
					mismatch = (x, y)
					break
			if mismatch:
				break
		report.check(mismatch is None,
			f"{name}: tileset '{tileset['name']}' tile {index} gutter pixel {mismatch} differs from the tile edge")


def tileset_ranges(report, name, tilesets, map_dir):
	"""Returns (first gid, last gid, tileset name, is image sheet) per tileset."""
	ranges = []
	for tileset in tilesets:
		report.check("source" not in tileset,
			f"{name}: tileset '{tileset.get('name')}' is external (has 'source'); the project embeds tilesets so each map is self-contained")
		is_sheet = "image" in tileset
		required = ("firstgid", "tilecount", "columns", "tilewidth", "tileheight")
		if is_sheet:
			required += ("imagewidth", "imageheight")
		else:
			report.check(bool(tileset.get("tiles")),
				f"{name}: tileset '{tileset.get('name')}' has neither an 'image' nor a 'tiles' image collection")
		for key in required:
			report.check(key in tileset, f"{name}: tileset '{tileset.get('name')}' missing '{key}'")
		if "firstgid" not in tileset or "tilecount" not in tileset:
			continue
		if is_sheet:
			owner = f"tileset '{tileset['name']}'"
			if check_image_file(report, name, map_dir, tileset["image"], tileset["imagewidth"], tileset["imageheight"], owner):
				if tileset.get("margin", 0) > 0:
					check_gutters(report, name, tileset, os.path.join(map_dir, tileset["image"]))
		else:
			for tile in tileset.get("tiles", []):
				report.check("image" in tile, f"{name}: collection tile {tile.get('id')} in '{tileset['name']}' has no image")
				if "image" in tile:
					owner = f"collection '{tileset['name']}' tile {tile.get('id')}"
					check_image_file(report, name, map_dir, tile["image"], tile.get("imagewidth"), tile.get("imageheight"), owner)
		first = tileset["firstgid"]
		last = first + tileset["tilecount"] - 1
		ranges.append((first, last, tileset.get("name"), is_sheet))
	# Ranges must not overlap.
	ordered = sorted(ranges)
	for index in range(1, len(ordered)):
		report.check(ordered[index][0] > ordered[index - 1][1],
			f"{name}: tileset gid ranges overlap ({ordered[index - 1]} and {ordered[index]})")
	return ranges


def gid_in_ranges(gid, ranges):
	real = gid & FLIP_MASK
	if real == 0:
		return True
	return tileset_for_gid(real, ranges) is not None


def tileset_for_gid(gid, ranges):
	real = gid & FLIP_MASK
	for tileset_range in ranges:
		if tileset_range[0] <= real <= tileset_range[1]:
			return tileset_range
	return None


def collect_spawns(data):
	spawns = set()
	heroes = 0
	for layer in data["layers"]:
		if layer["type"] != "objectgroup":
			continue
		for obj in layer["objects"]:
			if obj.get("type") == "spawn" and obj.get("name"):
				spawns.add(obj["name"])
			if obj.get("type") == "hero":
				heroes += 1
	return spawns, heroes


def object_property(obj, key):
	for prop in obj.get("properties", []):
		if prop.get("name") == key:
			return prop.get("value")
	return None


def object_rect(obj):
	"""(left, top, width, height) in pixels. Tile objects (gid) anchor bottom-left."""
	width = obj.get("width", 0)
	height = obj.get("height", 0)
	if "gid" in obj:
		return (obj["x"], obj["y"] - height, width, height)
	return (obj["x"], obj["y"], width, height)


def rect_overlap_area(rect_a, rect_b):
	ax, ay, aw, ah = rect_a
	bx, by, bw, bh = rect_b
	span_x = min(ax + aw, bx + bw) - max(ax, bx)
	span_y = min(ay + ah, by + bh) - max(ay, by)
	if span_x > 0 and span_y > 0:
		return span_x * span_y
	return 0


def check_sensor_occlusion(report, name, data):
	"""A sensor buried in a solid static body can never fire: a solid body stops
	the hero before it can overlap the sensor. Require zero overlap between every
	exit/zone sensor and every solid (non-sensor) wall body."""
	solids = []
	sensors = []
	for layer in data["layers"]:
		if layer["type"] != "objectgroup":
			continue
		for obj in layer["objects"]:
			if obj.get("type") in ("exit", "zone"):
				sensors.append(obj)
			elif object_property(obj, "bodyType") is not None and object_property(obj, "isSensor") is not True:
				solids.append(obj)
	for sensor in sensors:
		sensor_rect = object_rect(sensor)
		covered = sum(rect_overlap_area(sensor_rect, object_rect(solid)) for solid in solids)
		report.check(covered == 0,
			f"{name}: {sensor.get('type')} '{sensor.get('name')}' is buried in solid wall bodies "
			f"(overlap {covered} px^2); it can never fire")


def check_layer_gids(report, name, layer, data_array, ranges):
	"""Every gid of a tile layer must sit in the same image-sheet tileset as its first tile."""
	layer_tileset = None
	for gid in data_array:
		if gid & FLIP_MASK == 0:
			continue
		tileset_range = tileset_for_gid(gid, ranges)
		if tileset_range is None:
			report.check(False, f"{name}: tile layer '{layer.get('name')}' has out-of-range gid {gid}")
			return
		if layer_tileset is None:
			layer_tileset = tileset_range
			report.check(tileset_range[3],
				f"{name}: tile layer '{layer.get('name')}' uses image-collection tileset '{tileset_range[2]}'")
		if tileset_range != layer_tileset:
			report.check(False, f"{name}: tile layer '{layer.get('name')}' mixes tilesets "
				f"'{layer_tileset[2]}' and '{tileset_range[2]}' (gid {gid & FLIP_MASK})")
			return


def check_exit_lock(report, name, obj):
	required_quest = object_property(obj, "requiredQuest")
	locked_message = object_property(obj, "lockedMessage")
	if required_quest is None and locked_message is None:
		return
	label = f"{obj.get('type')} '{obj.get('name')}'"
	report.check(obj.get("type") == "exit", f"{name}: {label} has requiredQuest/lockedMessage but only exits may be locked")
	report.check(required_quest is not None and locked_message is not None,
		f"{name}: {label} needs requiredQuest and lockedMessage together")
	if required_quest is not None:
		report.check(isinstance(required_quest, int) and not isinstance(required_quest, bool) and required_quest > 0,
			f"{name}: {label} requiredQuest must be a positive int, got {required_quest!r}")
	if locked_message is not None:
		report.check(isinstance(locked_message, str) and locked_message.strip() != "",
			f"{name}: {label} lockedMessage must be a non-empty string")


def check_locked_exit_backstop(report, name, data):
	"""A locked exit only shows a message, so the hero must not be able to walk on
	through it: a locked exit sits on a map edge with a solid wall right behind it."""
	map_width = data["width"] * data["tilewidth"]
	map_height = data["height"] * data["tileheight"]
	objects = [obj for layer in data["layers"] if layer["type"] == "objectgroup" for obj in layer["objects"]]
	solids = [object_rect(obj) for obj in objects
		if object_property(obj, "bodyType") is not None and object_property(obj, "isSensor") is not True]

	for obj in objects:
		if obj.get("type") != "exit" or object_property(obj, "requiredQuest") is None:
			continue
		left, top, width, height = object_rect(obj)
		if top + height >= map_height:
			behind = (left, map_height, width, data["tileheight"])
		elif top <= 0:
			behind = (left, -data["tileheight"], width, data["tileheight"])
		elif left <= 0:
			behind = (-data["tilewidth"], top, data["tilewidth"], height)
		elif left + width >= map_width:
			behind = (map_width, top, data["tilewidth"], height)
		else:
			report.check(False, f"{name}: locked exit '{obj.get('name')}' must sit on a map edge")
			continue
		covered = sum(rect_overlap_area(behind, solid) for solid in solids)
		report.check(covered >= behind[2] * behind[3],
			f"{name}: locked exit '{obj.get('name')}' has no solid wall behind it; the hero can walk off the map")


def check_stage(report, maps, version):
	"""Stage features that the lessons depend on: the well from WELL_FROM_VERSION,
	the locked beach gate from LOCKED_EXIT_FROM_VERSION."""
	village = maps.get("village")
	if village is None:
		return
	objects = {obj.get("name"): obj for layer in village["layers"] if layer["type"] == "objectgroup" for obj in layer["objects"]}
	has_well = "well" in objects
	report.check(has_well == (version >= WELL_FROM_VERSION),
		f"village: versio-{version} {'lacks' if not has_well else 'already has'} the well object")
	gate = objects.get("exitToSideRoad")
	is_locked = gate is not None and object_property(gate, "requiredQuest") is not None
	report.check(is_locked == (version >= LOCKED_EXIT_FROM_VERSION),
		f"village: versio-{version} exitToSideRoad is {'locked' if is_locked else 'not locked'}")


def validate_map(report, name, data, map_dir):
	report.check(data.get("type") == "map", f"{name}: top-level type is not 'map'")
	report.check(data.get("orientation") == "orthogonal", f"{name}: orientation is not orthogonal")
	report.check("tiledversion" in data, f"{name}: missing tiledversion (needed to open in Tiled)")
	for key in ("width", "height", "tilewidth", "tileheight", "layers", "tilesets"):
		report.check(key in data, f"{name}: missing top-level '{key}'")
	width = data["width"]
	height = data["height"]

	ranges = tileset_ranges(report, name, data["tilesets"], map_dir)

	has_physics = False
	for layer in data["layers"]:
		layer_type = layer.get("type")
		if layer_type == "tilelayer":
			report.check("encoding" not in layer,
				f"{name}: tile layer '{layer.get('name')}' has 'encoding'; ponytiled only reads plain arrays")
			report.check("compression" not in layer,
				f"{name}: tile layer '{layer.get('name')}' has 'compression'; ponytiled only reads plain arrays")
			data_array = layer.get("data")
			report.check(isinstance(data_array, list),
				f"{name}: tile layer '{layer.get('name')}' data is not a plain array")
			if isinstance(data_array, list):
				report.check(len(data_array) == width * height,
					f"{name}: tile layer '{layer.get('name')}' has {len(data_array)} cells, expected {width * height}")
				check_layer_gids(report, name, layer, data_array, ranges)
		elif layer_type == "objectgroup":
			if layer.get("name") == "physics":
				has_physics = True
				report.check(layer.get("visible") is False,
					f"{name}: physics layer should be hidden (visible false) per the template convention")
			for obj in layer["objects"]:
				if "gid" in obj:
					report.check(gid_in_ranges(obj["gid"], ranges),
						f"{name}: object '{obj.get('name')}' has out-of-range gid {obj['gid']}")
				if obj.get("type") == "exit":
					report.check(object_property(obj, "targetMap") is not None,
						f"{name}: exit '{obj.get('name')}' missing targetMap")
					report.check(object_property(obj, "targetSpawn") is not None,
						f"{name}: exit '{obj.get('name')}' missing targetSpawn")
					report.check(object_property(obj, "bodyType") is not None,
						f"{name}: exit '{obj.get('name')}' missing bodyType")
				check_exit_lock(report, name, obj)
				if obj.get("type") == "zone":
					report.check(object_property(obj, "message") is not None,
						f"{name}: zone '{obj.get('name')}' missing message")
					report.check(object_property(obj, "isSensor") is True,
						f"{name}: zone '{obj.get('name')}' must be a sensor (isSensor true)")
					report.check(object_property(obj, "bodyType") is not None,
						f"{name}: zone '{obj.get('name')}' missing bodyType")
	report.check(has_physics, f"{name}: no hidden 'physics' object layer")
	check_sensor_occlusion(report, name, data)
	check_locked_exit_backstop(report, name, data)


def cross_validate(report, maps):
	for name, data in maps.items():
		spawns, heroes = collect_spawns(data)
		report.check(heroes == 1, f"{name}: expected exactly one hero object, found {heroes}")
		for layer in data["layers"]:
			if layer["type"] != "objectgroup":
				continue
			for obj in layer["objects"]:
				if obj.get("type") != "exit":
					continue
				target_map = object_property(obj, "targetMap")
				target_spawn = object_property(obj, "targetSpawn")
				report.check(target_map in maps,
					f"{name}: exit '{obj.get('name')}' targets unknown map '{target_map}'")
				if target_map in maps:
					target_spawns, _ = collect_spawns(maps[target_map])
					report.check(target_spawn in target_spawns,
						f"{name}: exit '{obj.get('name')}' target spawn '{target_spawn}' not found in '{target_map}' (spawns: {sorted(target_spawns)})")


def main():
	map_dir = sys.argv[1] if len(sys.argv) > 1 else DEFAULT_MAP_DIR
	report = Report()
	maps = {}
	for name in MAP_NAMES:
		path = os.path.join(map_dir, name + ".json")
		if not os.path.exists(path):
			report.check(False, f"{name}: map file missing at {path}")
			continue
		with open(path, "r", encoding="utf-8") as handle:
			maps[name] = json.load(handle)

	for name, data in maps.items():
		validate_map(report, name, data, map_dir)
	cross_validate(report, maps)

	# A versio-N folder carries stage-specific features; other folders skip the stage check.
	stage_match = re.search(r"versio-(\d+)", os.path.abspath(map_dir))
	if stage_match:
		check_stage(report, maps, int(stage_match.group(1)))

	if report.errors:
		print(f"FAIL: {len(report.errors)} problem(s)")
		for message in report.errors:
			print(f"  - {message}")
		sys.exit(1)
	print(f"OK: {len(maps)} maps validated ({', '.join(maps)})")


if __name__ == "__main__":
	main()
