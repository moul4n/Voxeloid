class_name GrainRenderer
extends RefCounted

const FLOATS_PER_INSTANCE := 12
const DEFAULT_CAPACITY := 10000
const DISC_TEXTURE_SIZE := 32

var _multimesh: MultiMesh
var _texture: Texture2D
var _buffer := PackedFloat32Array()
var _capacity := 0

func _init(capacity: int = DEFAULT_CAPACITY) -> void:
	_capacity = maxi(capacity, 1)
	var quad := QuadMesh.new()
	quad.size = Vector2.ONE
	_multimesh = MultiMesh.new()
	_multimesh.transform_format = MultiMesh.TRANSFORM_2D
	_multimesh.use_colors = true
	_multimesh.mesh = quad
	_multimesh.instance_count = _capacity
	_multimesh.visible_instance_count = 0
	_buffer.resize(_capacity * FLOATS_PER_INSTANCE)
	_texture = _make_disc_texture()

func update(positions: PackedVector2Array, count: int, center: Vector2, zoom: float, grain_size: float, color: Color) -> void:
	var visible_count := mini(maxi(count, 0), _capacity)
	var diameter := grain_size * zoom
	for index in visible_count:
		var position := center + positions[index] * zoom
		var offset := index * FLOATS_PER_INSTANCE
		# Transform2D is stored as 8 floats, followed by RGBA vertex color.
		_buffer[offset] = diameter
		_buffer[offset + 1] = 0.0
		_buffer[offset + 2] = 0.0
		_buffer[offset + 3] = position.x
		_buffer[offset + 4] = 0.0
		_buffer[offset + 5] = diameter
		_buffer[offset + 6] = 0.0
		_buffer[offset + 7] = position.y
		_buffer[offset + 8] = color.r
		_buffer[offset + 9] = color.g
		_buffer[offset + 10] = color.b
		_buffer[offset + 11] = color.a
	_multimesh.buffer = _buffer
	_multimesh.visible_instance_count = visible_count

func draw(canvas: CanvasItem, solver, center: Vector2, zoom: float) -> void:
	update(solver.positions, solver.count, center, zoom, solver.grain_size, solver.material.color)
	if _multimesh.visible_instance_count > 0:
		canvas.draw_multimesh(_multimesh, _texture)

func _make_disc_texture() -> Texture2D:
	var image := Image.create(DISC_TEXTURE_SIZE, DISC_TEXTURE_SIZE, false, Image.FORMAT_RGBA8)
	var center := Vector2(DISC_TEXTURE_SIZE, DISC_TEXTURE_SIZE) * 0.5
	var radius := float(DISC_TEXTURE_SIZE) * 0.5 - 0.5
	for y in DISC_TEXTURE_SIZE:
		for x in DISC_TEXTURE_SIZE:
			var distance := Vector2(float(x) + 0.5, float(y) + 0.5).distance_to(center)
			var coverage := clampf(radius + 0.5 - distance, 0.0, 1.0)
			image.set_pixel(x, y, Color(1.0, 1.0, 1.0, coverage))
	image.generate_mipmaps()
	return ImageTexture.create_from_image(image)
