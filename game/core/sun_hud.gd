extends RefCounted

static func player_button_rect() -> Rect2:
	return Rect2(35, 426, 224, 30)

static func text(canvas: CanvasItem, font: Font, at: Vector2, label: String, size: int = 10, colour: Color = Color("adbdcf")) -> void:
	canvas.draw_string(font, at, label, HORIZONTAL_ALIGNMENT_LEFT, 200, size, colour)

static func bar(canvas: CanvasItem, at: Vector2, amount: float, colour: Color) -> void:
	canvas.draw_rect(Rect2(at, Vector2(196, 5)), Color("233244"))
	canvas.draw_rect(Rect2(at, Vector2(196 * clampf(amount, 0.0, 1.0), 5)), colour)

static func kelvin(value: float) -> String:
	if value >= 1000000.0:
		return "%.2f MK" % (value / 1000000.0)
	if value >= 10000.0:
		return "%.1f kK" % (value / 1000.0)
	return "%d K" % int(value)

static func draw(canvas: CanvasItem, font: Font, state: Dictionary) -> void:
	if not state.get("enabled", false):
		return
	var body := Vector2(35, 190)
	var player := Vector2(35, 312)
	canvas.draw_rect(Rect2(body, Vector2(224, 110)), Color(0.04, 0.075, 0.12, 0.94))
	canvas.draw_rect(Rect2(player, Vector2(224, 110)), Color(0.04, 0.075, 0.12, 0.94))
	text(canvas, font, body + Vector2(14, 19), "SUN  /  LAYER %d OF 7" % mini(int(state.layers), 7), 11, Color("f2c98c"))
	text(canvas, font, body + Vector2(14, 36), str(state.phase), 10)
	text(canvas, font, body + Vector2(14, 54), "MASS   %.1f / 1,000 SMU" % float(state.body_smu))
	bar(canvas, body + Vector2(14, 61), float(state.solar_progress), Color("e3b76f"))
	text(canvas, font, body + Vector2(14, 83), "CENTRE   " + kelvin(float(state.temperature)))
	bar(canvas, body + Vector2(14, 90), float(state.heat), Color("ea855f"))
	text(canvas, font, player + Vector2(14, 19), "PLAYER CORE  /  LEVEL %d" % int(state.player_level), 11, Color("8cdad6"))
	text(canvas, font, player + Vector2(14, 36), "MASS   %.0f absorbed" % float(state.player_mass))
	var reserve_name := "liquid reserve" if bool(state.get("ignited", false)) else "loose mass"
	text(canvas, font, player + Vector2(14, 54), "LEVEL CAP REACHED" if int(state.player_level) >= 15 else "NEXT LEVEL   %.0f %s" % [float(state.player_cost), reserve_name])
	bar(canvas, player + Vector2(14, 61), float(state.player_level) / 15.0, Color("71c9c3"))
	text(canvas, font, player + Vector2(14, 83), "CORE   " + kelvin(float(state.player_temperature)) + "  /  shielded")
	bar(canvas, player + Vector2(14, 90), float(state.player_temperature) / 2000.0, Color("81aacb"))
	canvas.draw_rect(player_button_rect(), Color("14323a"))
	text(canvas, font, Vector2(49, 446), "ABSORB FOR CORE LEVEL" if int(state.player_level) < 15 else "SUN CORE LEVEL CAP REACHED", 10, Color("92cec9"))
