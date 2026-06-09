class_name BattleEventChoice extends RefCounted

var id: String = ""
var name: String = ""
var description: String = ""
var effect_type: String = ""
var value: int = 0
var preferred_archetype: String = "balanced"

static func make(
	choice_id: String,
	choice_name: String,
	choice_description: String,
	effect: String,
	effect_value: int,
	archetype: String
):
	var choice = load("res://scripts/battle_event_choice.gd").new()
	choice.id = choice_id
	choice.name = choice_name
	choice.description = choice_description
	choice.effect_type = effect
	choice.value = effect_value
	choice.preferred_archetype = archetype
	return choice
