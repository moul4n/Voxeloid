class_name ProgressionMetricRegistry
extends RefCounted

enum ValueType { NUMBER, BOOLEAN, TEXT }

const DEFINITIONS := {
	"mass.total_gathered": {"owner": "material_field", "revision": 1, "type": ValueType.NUMBER, "default": 0.0},
	"mass.body": {"owner": "material_field", "revision": 1, "type": ValueType.NUMBER, "default": 0.0},
	"mass.core": {"owner": "material_field", "revision": 1, "type": ValueType.NUMBER, "default": 0.0},
	"mass.loose": {"owner": "material_field", "revision": 1, "type": ValueType.NUMBER, "default": 0.0},
	"core.level": {"owner": "sun_progression", "revision": 1, "type": ValueType.NUMBER, "default": 0.0},
	"capture.ambient_total": {"owner": "ambient_dust", "revision": 1, "type": ValueType.NUMBER, "default": 0.0},
	"body.smu": {"owner": "sun_progression", "revision": 1, "type": ValueType.NUMBER, "default": 0.0},
	"body.temperature_mk": {"owner": "sun_progression", "revision": 1, "type": ValueType.NUMBER, "default": 0.0},
	"body.heat": {"owner": "sun_progression", "revision": 1, "type": ValueType.NUMBER, "default": 0.0},
	"body.layers": {"owner": "sun_progression", "revision": 1, "type": ValueType.NUMBER, "default": 0.0},
	"body.compactions": {"owner": "material_field", "revision": 1, "type": ValueType.NUMBER, "default": 0.0},
	"production.manual_rate": {"owner": "production", "revision": 1, "type": ValueType.NUMBER, "default": 0.0},
	"production.automatic_rate": {"owner": "production", "revision": 1, "type": ValueType.NUMBER, "default": 0.0},
	"body.gravity": {"owner": "material_field", "revision": 1, "type": ValueType.NUMBER, "default": 0.0},
	"body.rotation": {"owner": "sun_progression", "revision": 1, "type": ValueType.NUMBER, "default": 0.0},
}

func has(metric_name: StringName) -> bool:
	return DEFINITIONS.has(String(metric_name))

func definition(metric_name: StringName) -> Dictionary:
	return DEFINITIONS.get(String(metric_name), {}).duplicate(true)

func default_values() -> Dictionary:
	var values := {}
	for metric_name in DEFINITIONS:
		values[metric_name] = DEFINITIONS[metric_name].default
	return values

func accepts(metric_name: StringName, value: Variant) -> bool:
	var metric: Dictionary = DEFINITIONS.get(String(metric_name), {})
	if metric.is_empty():
		return false
	match int(metric.type):
		ValueType.NUMBER:
			return typeof(value) == TYPE_INT or typeof(value) == TYPE_FLOAT
		ValueType.BOOLEAN:
			return typeof(value) == TYPE_BOOL
		ValueType.TEXT:
			return typeof(value) == TYPE_STRING or typeof(value) == TYPE_STRING_NAME
	return false
