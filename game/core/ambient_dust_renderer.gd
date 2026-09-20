extends Node2D

var dust: RefCounted
var body_center := Vector2.ZERO
var zoom := 1.0
var view_size := Vector2.ZERO
var drawn_count := 0

func update_view(model: RefCounted, center: Vector2, view_zoom: float, size: Vector2) -> void:
	dust = model
	body_center = center
	zoom = view_zoom
	view_size = size
	queue_redraw()

func _draw() -> void:
	drawn_count = 0
	if dust == null:
		return
	var positions: PackedVector2Array = dust.positions
	var velocities: PackedVector2Array = dust.velocities
	var ages: PackedFloat32Array = dust.ages
	var screen := Rect2(Vector2(-12, -12), view_size + Vector2(24, 24))
	for index in int(dust.active_count):
		var at := body_center + positions[index] * zoom
		if not screen.has_point(at):
			continue
		var speed := velocities[index].length()
		var direction := velocities[index].normalized()
		var length := clampf(speed * zoom * 0.045, 1.0, 8.0)
		var fade := clampf(ages[index] * 2.0, 0.0, 1.0)
		var tint := Color("ba9470").lerp(Color("e8bb76"), clampf(speed / 450.0, 0.0, 1.0))
		draw_line(at - direction * length, at, Color(tint, 0.25 * fade), 1.0, true)
		draw_circle(at, clampf(zoom, 0.65, 1.3), Color(tint, 0.64 * fade))
		drawn_count += 1
