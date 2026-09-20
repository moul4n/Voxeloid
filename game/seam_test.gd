extends SceneTree
const Field = preload("res://core/material_field.gd")
const Renderer = preload("res://core/field_renderer.gd")
func _initialize() -> void:
	call_deferred("run")
func run() -> void:
	RenderingServer.set_default_clear_color(Color("050914"))
	var field = Field.new()
	field.seed_uniform(20000000)
	var renderer = Renderer.new()
	root.add_child(renderer)
	var dark_pixels := 0
	for center_y in [160.0, 160.5, 160.4999, 160.5001, 160.501, 160.51]:
		renderer.update_field(field, Vector2(60, center_y), 0.2)
		await process_frame
		await RenderingServer.frame_post_draw
		var shot := root.get_texture().get_image()
		for x in range(200, mini(900, shot.get_width()), 3):
			for y in range(159, 162):
				if shot.get_pixel(x, y).get_luminance() < 0.15:
					dark_pixels += 1
		shot.save_png("res://../scratch/checks/seam-check.png")
	print("SEAM dark interior pixels: ", dark_pixels)
	quit(0 if dark_pixels == 0 else 1)
