class_name Atlas
extends RefCounted
## Procedural stand-in for the baked vox atlas (art/bake/bake.py produces the real one).
## Generates tiny "voxel-looking" sprites at runtime so the bench has no art dependency.
## Every frame is drawn with the shared 3-shade rule: top light, left mid, right dark.

const GRID := 8            # frames per row/column in the debris atlas
const FRAME := 8           # px per debris frame
const VOX := 2             # px per fake voxel

# The shared ramp (docs/vox-speed-bible.html § Art direction). Index 0 = rock, 1 = ice, 2 = ember, 3 = acid, 4 = crystal, 5 = gold.
const RAMP := [
	[Color("6e6a62"), Color("9a958a"), Color("c9c3b4")],
	[Color("4f7fa8"), Color("7fb2d8"), Color("bfe3f5")],
	[Color("a83e14"), Color("e0731f"), Color("ffb347")],
	[Color("3b7a2a"), Color("6cc244"), Color("b9f27a")],
	[Color("5a3f8f"), Color("8f6ad1"), Color("c9b1ff")],
	[Color("8a6a12"), Color("d4a628"), Color("ffe27a")],
]


static func debris_atlas(rng: RandomNumberGenerator) -> ImageTexture:
	var img := Image.create(GRID * FRAME, GRID * FRAME, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	for f in range(GRID * GRID):
		var ox := (f % GRID) * FRAME
		var oy := (f / GRID) * FRAME
		var ramp: Array = RAMP[f % RAMP.size()]
		var n := rng.randi_range(3, 6)
		var cells := {}
		var cx := 1
		var cy := 1
		for i in range(n):
			cells[Vector2i(cx, cy)] = true
			cx = clampi(cx + rng.randi_range(-1, 1), 0, (FRAME / VOX) - 1)
			cy = clampi(cy + rng.randi_range(-1, 1), 0, (FRAME / VOX) - 1)
		for c in cells.keys():
			_vox(img, ox + c.x * VOX, oy + c.y * VOX, ramp)
	return ImageTexture.create_from_image(img)


static func part(w: int, h: int, ramp_index: int) -> ImageTexture:
	var img := Image.create(w, h, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	var ramp: Array = RAMP[ramp_index % RAMP.size()]
	for y in range(0, h, VOX):
		for x in range(0, w, VOX):
			_vox(img, x, y, ramp)
	# rim light on the top row, shadow on the bottom row
	for x in range(w):
		img.set_pixel(x, 0, ramp[2].lightened(0.25))
		img.set_pixel(x, h - 1, ramp[0].darkened(0.35))
	return ImageTexture.create_from_image(img)


static func _vox(img: Image, x: int, y: int, ramp: Array) -> void:
	# 2×2 fake voxel: top-left light, top-right mid, bottom dark (clipped at the image edge)
	var w := img.get_width()
	var h := img.get_height()
	img.set_pixel(x, y, ramp[2])
	if x + 1 < w:
		img.set_pixel(x + 1, y, ramp[1])
	if y + 1 < h:
		img.set_pixel(x, y + 1, ramp[1])
	if x + 1 < w and y + 1 < h:
		img.set_pixel(x + 1, y + 1, ramp[0])
