class_name TacticalStance extends RefCounted

enum Stance { BALANCED, BREAK, GUARD, HARMONY }

const KEYS = ["balanced", "break", "guard", "harmony"]
const LABEL_KEYS = ["stance_balanced", "stance_break", "stance_guard", "stance_harmony"]

static func normalize(stance: int) -> int:
	if stance < Stance.BALANCED or stance > Stance.HARMONY:
		return Stance.BALANCED
	return stance

static func key(stance: int) -> String:
	return KEYS[normalize(stance)]

static func label_key(stance: int) -> String:
	return LABEL_KEYS[normalize(stance)]

static func preferred_archetype(stance: int) -> String:
	match normalize(stance):
		Stance.BREAK:
			return "attack"
		Stance.GUARD:
			return "defense"
		Stance.HARMONY:
			return "rhetoric"
		_:
			return "balanced"

static func modifiers(stance: int) -> Dictionary:
	match normalize(stance):
		Stance.BREAK:
			return {
				"atk_mult": 1.20,
				"def_mult": 0.85,
				"crt_mult": 1.0,
				"constraint_bonus_mult": 1.0,
				"constraint_penalty_mult": 1.0,
				"heal_bonus": 0,
			}
		Stance.GUARD:
			return {
				"atk_mult": 0.85,
				"def_mult": 1.25,
				"crt_mult": 1.0,
				"constraint_bonus_mult": 1.0,
				"constraint_penalty_mult": 1.0,
				"heal_bonus": 1,
			}
		Stance.HARMONY:
			return {
				"atk_mult": 1.0,
				"def_mult": 1.0,
				"crt_mult": 0.80,
				"constraint_bonus_mult": 1.50,
				"constraint_penalty_mult": 0.75,
				"heal_bonus": 0,
			}
	return {
		"atk_mult": 1.0,
		"def_mult": 1.0,
		"crt_mult": 1.0,
		"constraint_bonus_mult": 1.0,
		"constraint_penalty_mult": 1.0,
		"heal_bonus": 0,
	}
