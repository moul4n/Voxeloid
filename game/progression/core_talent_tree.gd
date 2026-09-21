class_name CoreTalentTree
extends RefCounted

const TIERS := [
	{"spent": 0, "gathered": 0.0},
	{"spent": 2, "gathered": 56.0},
	{"spent": 3, "gathered": 121.0},
	{"spent": 6, "gathered": 825.0},
	{"spent": 9, "gathered": 4934.0},
	{"spent": 14, "gathered": 93678.0},
]

const TALENTS := [
	{"id": &"automatic_invocation", "name": "Gentle Current", "design_name": "Automatic Invocation", "short": "FLOW", "tier": 0, "ranks": 10, "live": true, "effect": "+1 automatic call each second"},
	{"id": &"resonant_pull", "name": "Stronger Pull", "design_name": "Resonant Pull", "short": "PULL", "tier": 0, "ranks": 10, "live": true, "requires": &"automatic_invocation", "effect": "+15% matter each call"},
	{"id": &"rapid_recovery", "name": "Faster Flow", "design_name": "Rapid Recovery", "short": "FAST", "tier": 0, "ranks": 10, "live": true, "requires": &"automatic_invocation", "effect": "Automatic calls run 1.6x faster"},
	{"id": &"efficient_assimilation", "name": "Efficient Assimilation", "short": "SAVE", "tier": 1, "ranks": 4, "live": false, "effect": "Future Core levels cost 10% less"},
	{"id": &"gravity_focus", "name": "Gravity Focus", "short": "GRAV", "tier": 2, "ranks": 4, "live": false, "effect": "Improves matter capture"},
	{"id": &"mass_lattice", "name": "Mass Lattice", "short": "MASS", "tier": 2, "ranks": 5, "live": false, "effect": "Core mass gives a larger boost"},
	{"id": &"compression_harvest", "name": "Compression Harvest", "short": "HARV", "tier": 3, "ranks": 4, "live": false, "effect": "Compaction grants Core growth"},
	{"id": &"thermal_conduits", "name": "Thermal Conduits", "short": "HEAT", "tier": 3, "ranks": 4, "live": false, "effect": "Improves safe heat flow"},
	{"id": &"echo_pull", "name": "Echo Pull", "short": "ECHO", "tier": 4, "ranks": 3, "live": false, "effect": "+12% matter each call"},
	{"id": &"overclock_governor", "name": "Overclock Governor", "short": "OVER", "tier": 4, "ranks": 4, "live": false, "effect": "Improves safe overclocking"},
	{"id": &"continuous_breach", "name": "Continuous Breach", "short": "FLOW", "tier": 5, "ranks": 1, "live": false, "effect": "Doubles automatic calls"},
]

var ranks: Dictionary = {}

func spent_points() -> int:
	var total := 0
	for value in ranks.values():
		total += int(value)
	return total

func available_points(core_level: int) -> int:
	return maxi(core_level - spent_points(), 0)

func rank(talent_id: StringName) -> int:
	return int(ranks.get(talent_id, 0))

func definition(talent_id: StringName) -> Dictionary:
	for talent in TALENTS:
		if talent.id == talent_id:
			return talent
	return {}

func is_tier_open(tier: int, total_gathered: float) -> bool:
	if tier < 0 or tier >= TIERS.size():
		return false
	var gate: Dictionary = TIERS[tier]
	return spent_points() >= int(gate.spent) and total_gathered >= float(gate.gathered)

func can_buy(talent_id: StringName, core_level: int, total_gathered: float) -> bool:
	var talent := definition(talent_id)
	if talent.is_empty() or available_points(core_level) <= 0:
		return false
	var required: StringName = StringName(talent.get("requires", &""))
	if not required.is_empty() and rank(required) <= 0:
		return false
	return bool(talent.get("live", false)) and rank(talent_id) < int(talent.ranks) and is_tier_open(int(talent.tier), total_gathered)

func buy(talent_id: StringName, core_level: int, total_gathered: float) -> bool:
	if not can_buy(talent_id, core_level, total_gathered):
		return false
	ranks[talent_id] = rank(talent_id) + 1
	return true

func grant(talent_id: StringName) -> bool:
	var talent := definition(talent_id)
	if talent.is_empty() or not bool(talent.get("live", false)) or rank(talent_id) >= int(talent.ranks):
		return false
	ranks[talent_id] = rank(talent_id) + 1
	return true

func manual_yield_multiplier(compaction_power: float = 1.0) -> float:
	var talent_bonus := 0.15 * rank(&"resonant_pull") + 0.12 * rank(&"echo_pull")
	return 1.0 + talent_bonus * maxf(compaction_power, 1.0)

func automatic_rate(compaction_power: float = 1.0) -> float:
	var invocation_ranks := rank(&"automatic_invocation")
	if invocation_ranks == 0:
		return 0.0
	var rate := float(invocation_ranks) * pow(1.6, rank(&"rapid_recovery"))
	if rank(&"continuous_breach") > 0:
		rate *= 2.0
	return rate * maxf(compaction_power, 1.0)

func snapshot(core_level: int, total_gathered: float, compaction_power: float = 1.0) -> Dictionary:
	var nodes: Array = []
	var tier_counts: Dictionary = {}
	for talent in TALENTS:
		tier_counts[talent.tier] = int(tier_counts.get(talent.tier, 0)) + 1
	var tier_slots: Dictionary = {}
	for talent in TALENTS:
		var node: Dictionary = talent.duplicate()
		node["slot"] = int(tier_slots.get(talent.tier, 0))
		node["tier_count"] = int(tier_counts.get(talent.tier, 1))
		tier_slots[talent.tier] = int(node.slot) + 1
		node["rank"] = rank(talent.id)
		node["available"] = can_buy(talent.id, core_level, total_gathered)
		node["tier_open"] = is_tier_open(int(talent.tier), total_gathered)
		nodes.append(node)
	return {
		"level": core_level,
		"points": available_points(core_level),
		"spent": spent_points(),
		"gathered": total_gathered,
		"nodes": nodes,
		"automatic_rate": automatic_rate(compaction_power),
		"manual_multiplier": manual_yield_multiplier(compaction_power),
		"compaction_power": maxf(compaction_power, 1.0),
	}
