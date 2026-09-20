class_name Rig
extends Node2D
## Hero-tier part rig: head, body, two legs, tool as separate sprites driven by tweens.
## No AnimationPlayer, no keyframes. A real character swaps the textures for baked vox parts
## from art/atlas/ and keeps this exact node tree (see docs/vox-speed-bible.html § Art pipeline).

var head: Sprite2D
var body: Sprite2D
var leg_l: Sprite2D
var leg_r: Sprite2D
var tool: Sprite2D
var _t := 0.0
var _swing_tween: Tween


func _ready() -> void:
	body = _part(Atlas.part(10, 12, 0), Vector2(0, 0))
	head = _part(Atlas.part(8, 8, 1), Vector2(0, -10))
	leg_l = _part(Atlas.part(4, 6, 0), Vector2(-3, 9))
	leg_r = _part(Atlas.part(4, 6, 0), Vector2(3, 9))
	tool = _part(Atlas.part(3, 10, 5), Vector2(7, -2))
	tool.offset = Vector2(0, -5)     # pivot at the handle end
	swing_loop()


func _part(tex: Texture2D, pos: Vector2) -> Sprite2D:
	var s := Sprite2D.new()
	s.texture = tex
	s.position = pos
	s.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	add_child(s)
	return s


func _process(dt: float) -> void:
	_t += dt
	# idle bob + walk cycle, all procedural
	body.position.y = sin(_t * 6.0) * 0.6
	head.position.y = -10 + sin(_t * 6.0 + 0.5) * 0.8
	leg_l.rotation = sin(_t * 9.0) * 0.5
	leg_r.rotation = -sin(_t * 9.0) * 0.5
	body.scale.x = 1.0 + sin(_t * 12.0) * 0.03   # squash


func swing_loop() -> void:
	if _swing_tween:
		_swing_tween.kill()
	_swing_tween = create_tween().set_loops()
	_swing_tween.tween_property(tool, "rotation", -1.6, 0.18).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_swing_tween.tween_property(tool, "rotation", 0.4, 0.10).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	_swing_tween.tween_callback(func(): swung.emit())
	_swing_tween.tween_property(tool, "rotation", 0.0, 0.16)


signal swung
