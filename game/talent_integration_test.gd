extends SceneTree

const MainScene := preload("res://main.tscn")
var failures := 0

func check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		push_error(message)

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var main = MainScene.instantiate()
	root.add_child(main)
	main.set_process(false)
	main.set_physics_process(false)
	main.voxels.seed_uniform(20)
	main._refresh_progression()
	main.voxels.assimilate_player_core()
	main._refresh_progression()
	check(main._is_unlocked(&"ui.talents"), "first Core level did not reveal talents")
	check(not main.talent_tree_open, "first talent guide skipped the highlighted Core box")
	check(not main.space_backdrop.visible, "stars appeared before a point was spent")
	var open_tree := InputEventMouseButton.new()
	open_tree.button_index = MOUSE_BUTTON_LEFT
	open_tree.pressed = true
	open_tree.position = main.PlayerHud.talent_rect(main.get_viewport_rect().size).get_center()
	main._unhandled_input(open_tree)
	check(main.talent_tree_open, "clicking the highlighted Core box did not open talents")
	check(main.notification_tour.current_step().title == "Start with Flow", "opening talents did not guide the first Flow pick")
	main.notification_tour.dismiss_current()
	main._unhandled_input(open_tree)
	main._unhandled_input(open_tree)
	check(main.notification_tour.current_step().is_empty(), "talent hint appeared again after its first opening")
	var automatic: Dictionary = {}
	for node in main._talent_snapshot().nodes:
		if node.id == &"automatic_invocation":
			automatic = node
			break
	var click := InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_LEFT
	click.pressed = true
	click.position = main.PlayerHud.talent_node_rect(main.get_viewport_rect().size, automatic).get_center()
	main._unhandled_input(click)
	check(main.core_talent_tree.rank(&"automatic_invocation") == 1, "talent node did not spend the point")
	check(not main.space_backdrop.visible, "stars appeared after only one talent point")
	var before: int = main.voxels.count
	main._physics_process(1.05)
	check(main.voxels.count > before, "Automatic Invocation did not call matter")
	check(main._buy_talent(&"resonant_pull", true), "dev grant could not add Stronger Pull")
	before = main.voxels.count
	for index in 20:
		main.release_grains()
	check(main.voxels.count - before == 23, "Stronger Pull did not preserve its fractional manual yield")
	check(not main.space_backdrop.visible, "stars appeared before three talent points were spent")
	check(main._buy_talent(&"resonant_pull", true), "third dev talent grant failed")
	check(main.space_backdrop.visible, "third talent point did not reveal the stellar background")
	if failures == 0:
		print("Talent integration checks passed: staged guide, point spend, third-talent stars and automatic matter.")
	quit(1 if failures else 0)
