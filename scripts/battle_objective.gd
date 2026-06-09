class_name BattleObjective extends RefCounted

var id: String = ""
var name: String = ""
var description: String = ""
var archetype: String = "balanced"
var check_condition: String = ""
var reward_type: String = ""
var reward_value: int = 1
var risk_level: int = 1

static func make(
	objective_id: String,
	objective_name: String,
	objective_description: String,
	objective_archetype: String,
	condition: String,
	reward: String,
	value: int,
	risk: int
):
	var objective = load("res://scripts/battle_objective.gd").new()
	objective.id = objective_id
	objective.name = objective_name
	objective.description = objective_description
	objective.archetype = objective_archetype
	objective.check_condition = condition
	objective.reward_type = reward
	objective.reward_value = value
	objective.risk_level = risk
	return objective

static func pool() -> Array:
	return [
		make("orderly_sentence", "objective_orderly_name", "objective_orderly_desc", "balanced", "SUBJECT_PREDICATE_OBJECT", "DRAW", 1, 1),
		make("harmony_line", "objective_harmony_name", "objective_harmony_desc", "rhetoric", "NO_CONSTRAINT_RISK", "MANA", 1, 1),
		make("break_order", "objective_break_name", "objective_break_desc", "attack", "BREAK_ATK", "EMPOWER", 1, 2),
		make("echo_line", "objective_echo_name", "objective_echo_desc", "rhetoric", "RHETORIC", "SHIELD", 4, 2),
		make("guarded_clause", "objective_guard_name", "objective_guard_desc", "defense", "GUARD_DEF", "HEAL", 2, 1),
	]

static func choose_for_turn(turn_number: int, preferred_archetype: String = "balanced"):
	var candidates = pool()
	var preferred: Array = []
	for objective in candidates:
		if objective.archetype == preferred_archetype:
			preferred.append(objective)
	if preferred.is_empty():
		preferred = candidates
	var index = abs(turn_number) % preferred.size()
	return preferred[index]

func evaluate(sentence: ScoringEngine.SentenceInput, breakdown: ScoringEngine.ScoreBreakdown, player: Player, context: Dictionary = {}) -> Dictionary:
	var complete = _is_complete(sentence)
	var ok = false
	var reason = ""
	match check_condition:
		"SUBJECT_PREDICATE_OBJECT":
			ok = _has_component(sentence, CardData.SentenceComponent.SUBJECT) and _has_component(sentence, CardData.SentenceComponent.PREDICATE) and _has_component(sentence, CardData.SentenceComponent.OBJECT)
			reason = "S+P+O"
		"NO_CONSTRAINT_RISK":
			ok = complete and breakdown.constraint_penalty_percent <= 0.0 and breakdown.constraint_bonus > 0.0
			reason = "risk %.0f%%" % (breakdown.constraint_penalty_percent * 100.0)
		"BREAK_ATK":
			ok = complete and breakdown.stance_name == "break" and max(breakdown.atk, int(context.get("actual_damage", 0))) >= 8
			reason = "ATK %d" % max(breakdown.atk, int(context.get("actual_damage", 0)))
		"RHETORIC":
			ok = complete and (breakdown.rhetoric_flags.size() > 0 or breakdown.crt >= 6)
			reason = "CRT %d" % breakdown.crt
		"GUARD_DEF":
			ok = complete and breakdown.stance_name == "guard" and breakdown.def_ >= 6
			reason = "DEF %d" % breakdown.def_
		_:
			ok = false
			reason = "unknown"
	var state = "complete" if ok else "pending"
	if sentence.length() == 0:
		state = "empty"
	elif not complete:
		state = "partial"
	return {
		"state": state,
		"will_complete": ok,
		"reason": reason,
		"reward_type": reward_type,
		"reward_value": reward_value,
		"archetype": archetype,
	}

func reward_summary() -> String:
	return "%s +%d" % [reward_type, reward_value]

static func _is_complete(sentence: ScoringEngine.SentenceInput) -> bool:
	if sentence == null or sentence.length() == 0:
		return false
	for word in sentence.words:
		if str(word).strip_edges().is_empty():
			return false
	return true

static func _has_component(sentence: ScoringEngine.SentenceInput, component: int) -> bool:
	if sentence == null:
		return false
	return sentence.components.has(component)
