class_name PlayerHud
extends RefCounted

const PANEL := Color(0.035, 0.065, 0.105, 0.94)
const PANEL_EDGE := Color("29405a")
const TEXT := Color("e5f2ff")
const MUTED := Color("89a8c6")
const MASS := Color("e3b76f")
const HEAT := Color("ea855f")
const CORE := Color("71c9c3")

static func objective_rect() -> Rect2:
	return Rect2(34, 88, 350, 86)

static func indicator_rect() -> Rect2:
	return Rect2(34, 190, 250, 82)

static func core_action_rect() -> Rect2:
	return Rect2(34, 284, 250, 44)

static func talent_rect(view_size: Vector2) -> Rect2:
	return Rect2(Vector2(view_size.x - 264, view_size.y - 106), Vector2(230, 66))

static func talent_tree_rect(view_size: Vector2) -> Rect2:
	return Rect2(Vector2(view_size.x - 734, view_size.y - 522), Vector2(700, 400))

static func talent_node_rect(view_size: Vector2, node: Dictionary) -> Rect2:
	var tree := talent_tree_rect(view_size)
	var tier := int(node.get("tier", 0))
	var slot := int(node.get("slot", 0))
	var count := int(node.get("tier_count", 1))
	var gap := 128.0
	var row_width := float(count - 1) * gap
	var centre_x := tree.get_center().x - row_width * 0.5 + float(slot) * gap
	var centre_y := tree.position.y + 58.0 + float(tier) * 51.0
	return Rect2(Vector2(centre_x - 22.0, centre_y - 22.0), Vector2(44, 44))

static func next_button_rect(view_size: Vector2, anchor: Rect2) -> Rect2:
	var bubble := notification_rect(view_size, anchor)
	return Rect2(bubble.end - Vector2(88, 34), Vector2(72, 22))

static func dismiss_button_rect(view_size: Vector2, anchor: Rect2) -> Rect2:
	var bubble := notification_rect(view_size, anchor)
	return Rect2(bubble.position + Vector2(bubble.size.x - 28, 8), Vector2(20, 20))

static func notification_rect(view_size: Vector2, anchor: Rect2) -> Rect2:
	var size := Vector2(310, 132)
	var position := anchor.position + Vector2(-size.x - 18, anchor.size.y * 0.5 - size.y * 0.5)
	if position.x < 18:
		position = anchor.end + Vector2(18, -size.y * 0.5)
	position.x = clampf(position.x, 18.0, view_size.x - size.x - 18.0)
	position.y = clampf(position.y, 78.0, view_size.y - size.y - 18.0)
	return Rect2(position, size)

static func draw(canvas: CanvasItem, font: Font, view_size: Vector2, snapshot: Dictionary,
		sun: Dictionary, talent: Dictionary, talent_open: bool, hovered_talent: StringName,
		notification: Dictionary, notification_anchor: Rect2) -> void:
	_text(canvas, font, Vector2(34, 42), "VOXELOID", 19, TEXT)
	_text(canvas, font, Vector2(35, 64), str(snapshot.get("phase_title", "First Matter")).to_upper(), 10, MUTED)
	_draw_objective(canvas, font, snapshot)
	var visible: Array = snapshot.get("visible_indicators", [])
	if visible.has(&"indicator.body_mass") or visible.has(&"indicator.heat"):
		_draw_indicators(canvas, font, sun, visible, snapshot)
	if visible.has(&"ui.talents"):
		_draw_talents(canvas, font, view_size, talent, talent_open, hovered_talent)
	if not notification.is_empty():
		_draw_notification(canvas, font, view_size, notification, notification_anchor)

static func _draw_objective(canvas: CanvasItem, font: Font, snapshot: Dictionary) -> void:
	var rect := objective_rect()
	canvas.draw_rect(rect, Color(0.045, 0.055, 0.08, 0.96))
	canvas.draw_rect(Rect2(rect.position, Vector2(4, rect.size.y)), MASS)
	canvas.draw_rect(rect, Color("624f35"), false, 1.0)
	canvas.draw_colored_polygon(PackedVector2Array([
		rect.position + Vector2(15, 12), rect.position + Vector2(20, 17),
		rect.position + Vector2(15, 22), rect.position + Vector2(10, 17)]), MASS)
	_text(canvas, font, rect.position + Vector2(28, 21), "QUEST", 9, MASS)
	_text(canvas, font, rect.position + Vector2(14, 45), str(snapshot.get("objective_title", "Call the first spark")), 14, TEXT, 250)
	var progress := clampf(float(snapshot.get("objective_progress", 0.0)), 0.0, 1.0)
	_bar(canvas, rect.position + Vector2(14, 62), Vector2(252, 8), progress, MASS)
	var current := str(snapshot.get("objective_current", ""))
	var target := str(snapshot.get("objective_target", ""))
	var detail := current
	if not current.is_empty() and not target.is_empty():
		detail = "%s / %s" % [current, target]
	elif detail.is_empty() and progress >= 1.0:
		detail = "DONE"
	_text(canvas, font, rect.position + Vector2(280, 69), detail, 10, MUTED, 56)

static func _draw_indicators(canvas: CanvasItem, font: Font, sun: Dictionary, visible: Array, snapshot: Dictionary) -> void:
	var rect := indicator_rect()
	canvas.draw_rect(rect, PANEL)
	canvas.draw_rect(rect, PANEL_EDGE, false, 1.0)
	var y := 21.0
	if visible.has(&"indicator.body_mass"):
		_text(canvas, font, rect.position + Vector2(14, y), "MASS", 10, MUTED, 70)
		_text(canvas, font, rect.position + Vector2(168, y), "%d" % int(snapshot.get("body_mass", 0.0)), 11, TEXT, 68)
		_bar(canvas, rect.position + Vector2(14, y + 10), Vector2(222, 6), float(snapshot.get("body_mass_display", 0.0)), MASS)
		y += 38.0
	if visible.has(&"indicator.heat"):
		_text(canvas, font, rect.position + Vector2(14, y), "HEAT", 10, MUTED, 70)
		_text(canvas, font, rect.position + Vector2(138, y), _kelvin(float(sun.get("temperature", 300.0))), 11, TEXT, 98)
		_bar(canvas, rect.position + Vector2(14, y + 10), Vector2(222, 6), float(sun.get("heat", 0.0)), HEAT)

static func _draw_talents(canvas: CanvasItem, font: Font, view_size: Vector2, talent: Dictionary,
		talent_open: bool, hovered_talent: StringName) -> void:
	var rect := talent_rect(view_size)
	var has_new_point := int(talent.get("points", 0)) > 0 and not talent_open
	if has_new_point:
		canvas.draw_rect(Rect2(rect.position - Vector2(4, 4), rect.size + Vector2(8, 8)), Color(0.44, 0.95, 0.86, 0.18))
	canvas.draw_rect(rect, PANEL)
	canvas.draw_rect(rect, Color("a8fff0") if has_new_point else CORE, false, 2.0 if has_new_point else 1.0)
	_text(canvas, font, rect.position + Vector2(14, 23), "CORE %d" % int(talent.get("level", 0)), 11, CORE)
	var compact_power := float(talent.get("compaction_power", 1.0))
	if compact_power > 1.001:
		_text(canvas, font, rect.position + Vector2(75, 23), "POWER x%.2f" % compact_power, 9, MASS, 86)
	_text(canvas, font, rect.position + Vector2(146, 23), "%d POINT%s" % [int(talent.get("points", 0)), "" if int(talent.get("points", 0)) == 1 else "S"], 9, TEXT, 72)
	_text(canvas, font, rect.position + Vector2(14, 50), "TALENTS", 11, TEXT)
	if has_new_point:
		_text(canvas, font, rect.position + Vector2(91, 50), "NEW", 8, Color("a8fff0"))
	_text(canvas, font, rect.position + Vector2(195, 50), "v" if talent_open else "^", 11, MUTED)
	if talent_open:
		_draw_talent_tree(canvas, font, view_size, talent, hovered_talent)

static func draw_talents(canvas: CanvasItem, font: Font, view_size: Vector2, talent: Dictionary,
		talent_open: bool, hovered_talent: StringName) -> void:
	_draw_talents(canvas, font, view_size, talent, talent_open, hovered_talent)

static func _draw_talent_tree(canvas: CanvasItem, font: Font, view_size: Vector2,
		talent: Dictionary, hovered_talent: StringName) -> void:
	var rect := talent_tree_rect(view_size)
	canvas.draw_rect(rect, Color(0.025, 0.055, 0.09, 0.98))
	canvas.draw_rect(rect, CORE, false, 1.0)
	_text(canvas, font, rect.position + Vector2(18, 24), "CORE TALENTS", 14, TEXT)
	var compact_power := float(talent.get("compaction_power", 1.0))
	if compact_power > 1.001:
		_text(canvas, font, rect.position + Vector2(410, 24), "POWER x%.2f" % compact_power, 9, MASS, 130)
	_text(canvas, font, rect.position + Vector2(560, 24), "%d AVAILABLE" % int(talent.get("points", 0)), 9, CORE, 120)
	var nodes: Array = talent.get("nodes", [])
	for node in nodes:
		var node_rect := talent_node_rect(view_size, node)
		var centre := node_rect.get_center()
		var tier_open := bool(node.get("tier_open", false))
		var bought := int(node.get("rank", 0)) > 0
		var first_pick := int(talent.get("spent", 0)) == 0 and int(talent.get("points", 0)) > 0 and StringName(node.get("id", &"")) == &"automatic_invocation"
		var colour := CORE if bought else (Color("b8d5dd") if tier_open else Color("304255"))
		if int(node.get("tier", 0)) > 0:
			canvas.draw_line(centre - Vector2(0, 25), Vector2(centre.x, centre.y - 39), Color(colour, 0.42), 1.0)
		canvas.draw_circle(centre, 20.0, Color(colour, 0.16))
		canvas.draw_arc(centre, 20.0, 0.0, TAU, 32, colour, 2.0 if bought else 1.0)
		if first_pick:
			canvas.draw_circle(centre, 28.0, Color(0.45, 1.0, 0.88, 0.10))
			canvas.draw_arc(centre, 27.0, 0.0, TAU, 40, Color("a8fff0"), 2.0)
			_text(canvas, font, centre + Vector2(-19, -28), "START", 7, Color("a8fff0"), 40)
		_text(canvas, font, centre + Vector2(-16, 4), str(node.get("short", "?")), 8, colour, 32)
		if int(node.get("ranks", 1)) > 1:
			_text(canvas, font, centre + Vector2(13, 19), "%d/%d" % [int(node.get("rank", 0)), int(node.get("ranks", 1))], 7, colour, 30)
	var inspected: Dictionary = {}
	for node in nodes:
		if StringName(node.get("id", &"")) == hovered_talent:
			inspected = node
			break
	if inspected.is_empty() and not nodes.is_empty():
		inspected = nodes[0]
	var footer_y := rect.end.y - 43.0
	canvas.draw_line(Vector2(rect.position.x + 18, footer_y - 17), Vector2(rect.end.x - 18, footer_y - 17), PANEL_EDGE, 1.0)
	_text(canvas, font, Vector2(rect.position.x + 18, footer_y), str(inspected.get("name", "Choose a talent")), 11, TEXT, 210)
	_text(canvas, font, Vector2(rect.position.x + 238, footer_y), str(inspected.get("effect", "")), 9, MUTED, 250)
	var gate := "CLICK TO SPEND 1 POINT" if bool(inspected.get("available", false)) else ""
	if gate.is_empty() and not bool(inspected.get("live", false)):
		gate = "PLANNED"
	elif gate.is_empty() and int(inspected.get("rank", 0)) >= int(inspected.get("ranks", 1)):
		gate = "COMPLETE"
	elif gate.is_empty() and not bool(inspected.get("tier_open", false)):
		gate = "GATHER MORE AND SPEND POINTS ABOVE"
	elif gate.is_empty() and not StringName(inspected.get("requires", &"")).is_empty():
		gate = "UNLOCK GENTLE CURRENT FIRST"
	elif gate.is_empty():
		gate = "NEED 1 POINT"
	_text(canvas, font, Vector2(rect.end.x - 190, footer_y + 20), gate, 8, CORE if bool(inspected.get("available", false)) else MUTED, 172)

static func _draw_notification(canvas: CanvasItem, font: Font, view_size: Vector2,
		notification: Dictionary, anchor: Rect2) -> void:
	var rect := notification_rect(view_size, anchor)
	var anchor_point := anchor.get_center()
	var edge := Vector2(rect.end.x, clampf(anchor_point.y, rect.position.y + 16.0, rect.end.y - 16.0)) if rect.position.x < anchor.position.x else Vector2(rect.position.x, clampf(anchor_point.y, rect.position.y + 16.0, rect.end.y - 16.0))
	canvas.draw_line(edge, anchor_point, Color("81c9c7"), 1.0)
	canvas.draw_rect(rect, Color(0.045, 0.10, 0.14, 0.98))
	canvas.draw_rect(rect, Color("81c9c7"), false, 1.5)
	_text(canvas, font, rect.position + Vector2(16, 24), str(notification.get("title", "New discovery")), 14, TEXT, 260)
	var lines := _wrap_lines(str(notification.get("body", "")), 48, 3)
	for index in lines.size():
		_text(canvas, font, rect.position + Vector2(16, 48 + index * 15), lines[index], 10, Color("b7cbd5"), 270)
	var next_rect := next_button_rect(view_size, anchor)
	canvas.draw_rect(next_rect, Color("17434a"))
	_text(canvas, font, next_rect.position + Vector2(18, 16), "NEXT", 9, Color("c9eeea"))
	var dismiss := dismiss_button_rect(view_size, anchor)
	_text(canvas, font, dismiss.position + Vector2(5, 15), "x", 11, MUTED)

static func _bar(canvas: CanvasItem, at: Vector2, size: Vector2, amount: float, colour: Color) -> void:
	canvas.draw_rect(Rect2(at, size), Color("233244"))
	canvas.draw_rect(Rect2(at, Vector2(size.x * clampf(amount, 0.0, 1.0), size.y)), colour)

static func _text(canvas: CanvasItem, font: Font, at: Vector2, label: String, size: int,
		colour: Color, width: float = -1.0) -> void:
	canvas.draw_string(font, at, label, HORIZONTAL_ALIGNMENT_LEFT, width, size, colour)

static func _kelvin(value: float) -> String:
	if value >= 1000000.0:
		return "%.2f MK" % (value / 1000000.0)
	if value >= 10000.0:
		return "%.1f kK" % (value / 1000.0)
	return "%d K" % int(value)

static func _wrap_lines(value: String, maximum_characters: int, maximum_lines: int) -> Array[String]:
	var result: Array[String] = []
	var line := ""
	for word in value.split(" ", false):
		var candidate := word if line.is_empty() else line + " " + word
		if candidate.length() <= maximum_characters:
			line = candidate
		else:
			result.append(line)
			line = word
			if result.size() >= maximum_lines - 1:
				break
	if result.size() < maximum_lines and not line.is_empty():
		result.append(line)
	return result
