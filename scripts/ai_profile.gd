class_name AIProfile extends RefCounted

const TacticalStanceScript = preload("res://scripts/tactical_stance.gd")

var id: String = ""
var profile_name: String = ""
var archetype: String = "balanced"
var preferred_stance: int = TacticalStanceScript.Stance.BALANCED
var weakness: String = ""
var log_style: String = ""
var system_prompt_hint: String = ""

static func make(
	profile_id: String,
	display_name: String,
	profile_archetype: String,
	stance: int,
	profile_weakness: String,
	style: String,
	prompt_hint: String
):
	var profile = load("res://scripts/ai_profile.gd").new()
	profile.id = profile_id
	profile.profile_name = display_name
	profile.archetype = profile_archetype
	profile.preferred_stance = stance
	profile.weakness = profile_weakness
	profile.log_style = style
	profile.system_prompt_hint = prompt_hint
	return profile

static func profiles() -> Array:
	return [
		make("rush_poet", "Rush Poet", "attack", TacticalStanceScript.Stance.BREAK, "High shield and Guard stance blunt its damage.", "sharp", "You are an impatient attacking poet. Prefer Break stance, predicates, objects, and pressure."),
		make("harmony_scholar", "Harmony Scholar", "rhetoric", TacticalStanceScript.Stance.HARMONY, "Fast Break turns can punish its setup.", "measured", "You are a careful scholar. Prefer Harmony stance, matching constraints, rhetoric, and readable words."),
		make("ward_scribe", "Ward Scribe", "defense", TacticalStanceScript.Stance.GUARD, "Long rhetoric chains can outscale its defense.", "steady", "You are a defensive scribe. Prefer Guard stance, shield, healing, and stable subject or attribute lines."),
	]

static func choose_for_seed(seed_value: int):
	var all_profiles = profiles()
	if all_profiles.is_empty():
		return null
	return all_profiles[abs(seed_value) % all_profiles.size()]

func to_context() -> Dictionary:
	return {
		"id": id,
		"name": profile_name,
		"archetype": archetype,
		"preferred_stance": TacticalStanceScript.key(preferred_stance),
		"weakness": weakness,
		"log_style": log_style,
		"system_prompt_hint": system_prompt_hint,
	}
