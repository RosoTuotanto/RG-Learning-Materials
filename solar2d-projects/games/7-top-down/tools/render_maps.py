#!/usr/bin/env python3
"""Render PNG previews of the built Tiled maps so the layouts can be eyeballed.

Composites the tile layers the way ponytiled does (gid -> embedded tileset frame,
honouring margin and spacing), draws tile objects from image sheets and image
collections at their object size, and outlines every object with its name.
Previews are throwaway and belong in .scratch/.

Run standalone (python3 -B render_maps.py [MAP_DIR [OUT_DIR]]) or via build_maps.py --preview.
"""

import json
import os
import sys

from PIL import Image, ImageDraw

FLIP_MASK = 0x1FFFFFFF
MAP_NAMES = ("village", "house", "sideroad")

# Object outline colours by Tiled type.
MARKER_COLOURS = {
	"hero": (0, 120, 255, 255),
	"spawn": (255, 255, 0, 255),
	"npc": (255, 0, 200, 255),
	"item": (0, 220, 120, 255),
	"exit": (255, 60, 60, 255),
	"zone": (255, 150, 0, 255),
	"wall": (150, 150, 150, 180),
}

HERE = os.path.dirname(os.path.abspath(__file__))
GAME_ROOT = os.path.normpath(os.path.join(HERE, ".."))
DEFAULT_MAP_DIR = os.path.join(GAME_ROOT, "versio-15", "maps")
DEFAULT_OUT_DIR = os.path.join(GAME_ROOT, ".scratch", "map-previews")


class TilesetFrames:
	"""Resolves gids to frame images for image-sheet and image-collection tilesets."""

	def __init__(self, map_dir, tilesets):
		self.map_dir = map_dir
		self.tilesets = tilesets
		self.images = {}

	def _image(self, file_name):
		if file_name not in self.images:
			self.images[file_name] = Image.open(os.path.join(self.map_dir, file_name)).convert("RGBA")
		return self.images[file_name]

	def frame(self, gid):
		real = gid & FLIP_MASK
		for tileset in self.tilesets:
			index = real - tileset["firstgid"]
			if not 0 <= index < tileset["tilecount"]:
				continue
			if "image" in tileset:
				tile_w = tileset["tilewidth"]
				tile_h = tileset["tileheight"]
				margin = tileset.get("margin", 0)
				spacing = tileset.get("spacing", 0)
				left = margin + (index % tileset["columns"]) * (tile_w + spacing)
				top = margin + (index // tileset["columns"]) * (tile_h + spacing)
				return self._image(tileset["image"]).crop((left, top, left + tile_w, top + tile_h))
			for tile in tileset.get("tiles", []):
				if tile["id"] == index:
					return self._image(tile["image"])
		return None


def render_map(map_path, out_png):
	with open(map_path, "r", encoding="utf-8") as handle:
		data = json.load(handle)
	width = data["width"]
	height = data["height"]
	tile_w = data["tilewidth"]
	tile_h = data["tileheight"]
	frames = TilesetFrames(os.path.dirname(map_path), data["tilesets"])

	canvas = Image.new("RGBA", (width * tile_w, height * tile_h), (0, 0, 0, 255))
	for layer in data["layers"]:
		if layer["type"] != "tilelayer" or not layer.get("visible", True):
			continue
		for index, gid in enumerate(layer["data"]):
			if gid == 0:
				continue
			frame = frames.frame(gid)
			if frame is None:
				continue
			# Tiles anchor bottom-left in ponytiled; tall tiles rise above their cell.
			left = (index % width) * tile_w
			top = (index // width + 1) * tile_h - frame.height
			canvas.alpha_composite(frame, (left, top))

	# Tile objects first, then every outline and label on top so none are hidden.
	objects = [obj for layer in data["layers"] if layer["type"] == "objectgroup" for obj in layer["objects"]]
	for obj in objects:
		if "gid" not in obj:
			continue
		frame = frames.frame(obj["gid"])
		if frame is not None:
			size = (int(obj["width"]), int(obj["height"]))
			canvas.alpha_composite(frame.resize(size, Image.NEAREST), (int(obj["x"]), int(obj["y"] - obj["height"])))

	draw = ImageDraw.Draw(canvas)
	for obj in objects:
		colour = MARKER_COLOURS.get(obj.get("type"), (255, 255, 255, 255))
		left = obj["x"]
		top = obj["y"] - obj["height"] if "gid" in obj else obj["y"]
		draw.rectangle([left, top, left + obj["width"] - 1, top + obj["height"] - 1], outline=colour, width=2)
		label = obj.get("name") or ""
		if label:
			draw.text((left + 3, top + 2), label, fill=colour)
	canvas.save(out_png)
	print(f"{os.path.basename(map_path)} -> {out_png} ({canvas.size[0]}x{canvas.size[1]})")


def render_all(map_dir=DEFAULT_MAP_DIR, out_dir=DEFAULT_OUT_DIR):
	os.makedirs(out_dir, exist_ok=True)
	for name in MAP_NAMES:
		map_path = os.path.join(map_dir, name + ".json")
		if os.path.exists(map_path):
			render_map(map_path, os.path.join(out_dir, f"preview_{name}.png"))


if __name__ == "__main__":
	render_all(*sys.argv[1:3])
