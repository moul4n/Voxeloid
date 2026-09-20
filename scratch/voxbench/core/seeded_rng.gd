extends Node
## Autoload "SeededRng". One RNG for the whole bench so runs are reproducible.
## Seed comes from `++ --seed=N` on the command line, else 7.

var rng := RandomNumberGenerator.new()
var seed_value := 7


func _ready() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--seed="):
			seed_value = int(a.substr(7))
	reseed(seed_value)


func reseed(s: int) -> void:
	seed_value = s
	rng.seed = s


func randf() -> float:
	return rng.randf()


func randf_range(a: float, b: float) -> float:
	return rng.randf_range(a, b)


func randi_range(a: int, b: int) -> int:
	return rng.randi_range(a, b)
