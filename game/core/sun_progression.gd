extends RefCounted

# Gameplay units, not individual atomic masses in kilograms.
const MASS_PER_SMU := 976.958 # Baseline mapping; efficiency can later change logical cost.
const TARGET_SMU := 1000.0
const IGNITION_SMU := 75.0
const LAYER_COUNT := 7
const LAYER_MASSES := [6000.0, 12600.0, 26460.0, 55566.0, 116689.0, 245046.0, 514597.0]
const PLAYER_LEVEL_CAP := 15
const PLAYER_BASE_COST := 20.0
const PLAYER_COST_GROWTH := 1.8
const MAX_COMPACTION_OVERFILL := 1.0
const INNER_DENSIFICATION_REWARD := 1.12
const INNER_HEAT_SPIKE := 0.08
const HEAT_SPIKE_HALF_LIFE := 45.0
const BAND_NAMES := ["Stellar core", "Radiative interior", "Convective envelope", "Photosphere"]

var completed_layers := 0
var absorbed_mass := 0.0
var player_level := 0
# Independent thermal state. Shielding/talent heat transfer will own this later.
var player_temperature := 300.0
var spin := 0.0
var ignition_unlocked := false
var production_reward := 1.0
var inner_densifications := 0
var densification_reward := 1.0
var densification_heat := 0.0
var completed_smu := 0.0
var current_layer_mass := 0.0
var history: Array[Dictionary] = []

func required_mass() -> float:
	if completed_layers >= LAYER_COUNT:
		return 0.0
	return maxf(LAYER_MASSES[completed_layers] - current_layer_mass, 0.0)

func player_cost() -> float:
	return ceil(PLAYER_BASE_COST * pow(PLAYER_COST_GROWTH, player_level))

func record_compaction(mass: float, count: int, forced: bool) -> void:
	var requirement := required_mass()
	var layer_smu: float = float(LAYER_MASSES[completed_layers]) / _total_layer_mass() * TARGET_SMU
	var nominal_requirement: float = float(LAYER_MASSES[completed_layers])
	var physical_credit: float = layer_smu * clampf(mass / nominal_requirement, 0.0, 1.0)
	completed_smu += physical_credit
	current_layer_mass += mass
	var completed: bool = current_layer_mass >= nominal_requirement
	var reward := 1.45 if completed else 1.0
	history.append({"mass": mass, "grains": count, "requirement": requirement, "physical_smu": physical_credit, "reward": reward, "forced": forced})
	if completed:
		production_reward *= reward
		completed_layers += 1
		current_layer_mass = 0.0

func record_inner_densification() -> void:
	inner_densifications += 1
	densification_reward *= INNER_DENSIFICATION_REWARD
	densification_heat = minf(densification_heat + INNER_HEAT_SPIKE, 0.35)

func step(delta: float) -> void:
	if delta <= 0.0 or densification_heat <= 0.0:
		return
	densification_heat *= pow(0.5, delta / HEAT_SPIKE_HALF_LIFE)
	if densification_heat < 0.00001:
		densification_heat = 0.0

func _total_layer_mass() -> float:
	var total := 0.0
	for amount in LAYER_MASSES:
		total += amount
	return total

func status(body_mass: float, bound_mass: float, loose_mass: float, converting: bool) -> Dictionary:
	var partial_requirement := required_mass()
	var partial_smu := 0.0
	if partial_requirement > 0.0:
		var layer_smu: float = float(LAYER_MASSES[completed_layers]) / _total_layer_mass() * TARGET_SMU
		var remaining_credit: float = layer_smu * clampf(partial_requirement / float(LAYER_MASSES[completed_layers]), 0.0, 1.0)
		partial_smu = minf(layer_smu * loose_mass / LAYER_MASSES[completed_layers], remaining_credit)
	var smu := minf(completed_smu + partial_smu, TARGET_SMU)
	if smu >= IGNITION_SMU and not converting:
		ignition_unlocked = true
	var ignited := ignition_unlocked
	var heat := 0.0
	var temperature := 300.0
	var phase := "First matter"
	if completed_layers > 0:
		phase = "Gravitational seed"
	if smu >= 50.0 and completed_layers > 0:
		phase = "Protostar"
	if ignited:
		var u := clampf((smu - IGNITION_SMU) / (TARGET_SMU - IGNITION_SMU), 0.0, 1.0)
		temperature = 4000000.0 + 11000000.0 * u * u * (3.0 - 2.0 * u)
		phase = "First ignition" if smu < 150.0 else "Main-sequence growth"
	else:
		var ignition_progress := clampf(smu / IGNITION_SMU, 0.0, 1.0)
		temperature = lerpf(200000.0, 4000000.0, pow(ignition_progress, 0.75))
	temperature = minf(15000000.0, temperature + 15000000.0 * densification_heat)
	heat = clampf(log(1.0 + temperature / 10000.0) / log(1501.0), 0.0, 1.0)
	var target_ready := smu >= TARGET_SMU - 0.000001 and completed_layers >= LAYER_COUNT and ignited and not converting
	if target_ready:
		phase = "Solar stabilisation"
	return {"enabled": true, "heat": heat, "ignited": ignited, "spin": spin,
		"phase": phase, "body_smu": smu, "temperature": temperature,
		"layers": completed_layers, "layer_requirement": required_mass(),
		"layer_progress": clampf(loose_mass / maxf(required_mass(), 1.0), 0.0, 1.0),
		"solar_progress": clampf(smu / TARGET_SMU, 0.0, 1.0),
		"player_mass": absorbed_mass, "player_level": player_level,
		"player_cost": player_cost(), "player_temperature": player_temperature,
		"player_progress": clampf(loose_mass / player_cost(), 0.0, 1.0),
		"helium_discovery_available": ignited, "stabilisation_available": target_ready,
		"production_reward": production_reward,
		"densification_count": inner_densifications,
		"densification_reward": densification_reward,
		"densification_heat": densification_heat,
		"total_production_reward": production_reward * densification_reward}
