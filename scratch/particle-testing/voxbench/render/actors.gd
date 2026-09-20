class_name Actors
extends Node2D
## Actor tier: pooled Node2D + Sprite2D objects with individual state, never instantiated mid-run.
## This is the tier enemies, pickups and projectiles will use, so its per-instance cost is the
## number we care about. Area2D overlap is optional (key O) so its cost can be measured alone.

const POOL := 2000

var live := 0
var use_area := false
var _nodes: Array[Sprite2D] = []
var _vel: PackedVector2Array
var _areas: Array[Area2D] = []
var _tex: Texture2D
var _bounds := Rect2(0, 0, 960, 540)
var _tweens: Array[Tween] = []


func _ready() -> void:
	_tex = Atlas.part(6, 6, 3)
	_vel.resize(POOL)
	for i in range(POOL):
		var s := Sprite2D.new()
		s.texture = _tex
		s.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		s.visible = false
		add_child(s)
		_nodes.append(s)
		var a := Area2D.new()
		var cs := CollisionShape2D.new()
		var circ := CircleShape2D.new()
		circ.radius = 3.0
		cs.shape = circ
		a.add_child(cs)
		a.monitoring = false
		a.monitorable = false
		s.add_child(a)
		_areas.append(a)


func set_use_area(on: bool) -> void:
	use_area = on
	for i in range(live):
		_areas[i].monitoring = on
		_areas[i].monitorable = on


func spawn(n: int) -> void:
	var rng := SeededRng.rng
	var target := mini(POOL, live + n)
	for i in range(live, target):
		var s := _nodes[i]
		s.position = Vector2(rng.randf_range(0, _bounds.size.x), rng.randf_range(0, _bounds.size.y))
		s.visible = true
		s.modulate = Color.WHITE
		_vel[i] = Vector2.from_angle(rng.randf() * TAU) * rng.randf_range(40, 140)
		_areas[i].monitoring = use_area
		_areas[i].monitorable = use_area
	live = target
	Metrics.live_actors_now = live


func clear() -> void:
	for i in range(live):
		_nodes[i].visible = false
		_areas[i].monitoring = false
		_areas[i].monitorable = false
	live = 0
	Metrics.live_actors_now = 0


func _process(dt: float) -> void:
	# Straight GDScript loop: this is the cost we're measuring. Bounce inside bounds.
	var w := _bounds.size.x
	var h := _bounds.size.y
	for i in range(live):
		var s := _nodes[i]
		var p := s.position + _vel[i] * dt
		var v := _vel[i]
		if p.x < 0.0 or p.x > w:
			v.x = -v.x
			p.x = clampf(p.x, 0.0, w)
		if p.y < 0.0 or p.y > h:
			v.y = -v.y
			p.y = clampf(p.y, 0.0, h)
		_vel[i] = v
		s.position = p


func apply_layers(mask: int) -> void:
	# Actor implementations of the visual layers (docs/phase0-build-plan.html § Visual layers)
	for tw in _tweens:
		if tw.is_valid():
			tw.kill()
	_tweens.clear()
	var tint := Color(1.0, 0.75, 0.45) if (mask & 1) else Color.WHITE
	for i in range(POOL):
		_nodes[i].modulate = tint
		_nodes[i].scale = Vector2.ONE
	if mask & 4:
		for i in range(live):
			var tw := create_tween().set_loops()
			var ph := float(i % 7) * 0.05
			tw.tween_property(_nodes[i], "scale", Vector2(1.18, 1.18), 0.22 + ph).set_trans(Tween.TRANS_SINE)
			tw.tween_property(_nodes[i], "scale", Vector2(1.0, 1.0), 0.22 + ph).set_trans(Tween.TRANS_SINE)
			_tweens.append(tw)
