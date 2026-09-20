extends RefCounted

# Cumulative occupied area in overburden coordinates. A small log-spaced
# table covers 0..1 billion grains without integrating every radial layer.
const SAMPLES := 512
const MAX_GRAINS := 1000000000.0
var _counts := PackedFloat64Array()
var _areas := PackedFloat64Array()
var _log_step := log(1.0 + MAX_GRAINS) / float(SAMPLES)

func rebuild(area: float, loose: float, pressures: Vector3, targets: Vector3,
		pressure_per_grain: float, response: float) -> void:
	_counts.resize(SAMPLES + 1)
	_areas.resize(SAMPLES + 1)
	_counts[0] = 0.0
	_areas[0] = 0.0
	for i in range(1, SAMPLES + 1):
		var upper := exp(float(i) * _log_step) - 1.0
		var lower := _counts[i - 1]
		var pressure := (upper + lower) * 0.5 * pressure_per_grain * maxf(response, 0.0)
		var packing := clampf(loose, 0.05, 0.995)
		for stage in 3:
			var target := clampf(targets[stage], packing, 0.995)
			packing = lerpf(packing, target, pressure / (pressure + maxf(pressures[stage], 0.001)))
		_counts[i] = upper
		_areas[i] = _areas[i - 1] + (upper - lower) * area / packing

func integral(grains_above: float) -> float:
	var amount := clampf(grains_above, 0.0, MAX_GRAINS)
	if amount <= 0.0:
		return 0.0
	var index := mini(int(log(1.0 + amount) / _log_step), SAMPLES - 1)
	var fraction := (amount - _counts[index]) / (_counts[index + 1] - _counts[index])
	return lerpf(_areas[index], _areas[index + 1], fraction)
