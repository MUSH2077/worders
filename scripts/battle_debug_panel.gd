class_name BattleDebugPanel extends Panel

var _title := Label.new()
var _body := Label.new()
var _last_score := {}
var _last_combat := {}
var _last_turn := "none"
var _last_event := "none"

func _ready() -> void:
	custom_minimum_size = Vector2(360, 220)
	size = Vector2(360, 220)
	mouse_filter = Control.MOUSE_FILTER_PASS
	var box = VBoxContainer.new()
	box.layout_mode = 1
	box.anchors_preset = PRESET_FULL_RECT
	box.anchor_right = 1.0
	box.anchor_bottom = 1.0
	box.offset_left = 12
	box.offset_top = 10
	box.offset_right = -12
	box.offset_bottom = -10
	box.add_theme_constant_override("separation", 8)
	add_child(box)
	_title.text = "WORDERS DEBUG"
	_title.add_theme_color_override("font_color", Color(1.0, 0.86, 0.48, 1))
	_title.add_theme_font_size_override("font_size", 16)
	box.add_child(_title)
	_body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_body.add_theme_color_override("font_color", Color(0.86, 0.92, 1.0, 0.96))
	_body.add_theme_font_size_override("font_size", 13)
	box.add_child(_body)
	_refresh()

func record_turn(player: Player) -> void:
	_last_turn = player.player_name if player else "none"
	_refresh()

func record_score(breakdown: ScoringEngine.ScoreBreakdown) -> void:
	if breakdown == null:
		return
	_last_score = {
		"atk": breakdown.atk,
		"def": breakdown.def_,
		"crt": breakdown.crt,
		"stance": breakdown.stance_name,
		"structure": breakdown.structure_penalty_percent,
		"constraint": breakdown.constraint_penalty_percent,
		"rhetoric": " ".join(breakdown.rhetoric_flags),
	}
	_refresh()

func record_combat(result: CombatResolver.CombatResult) -> void:
	if result == null:
		return
	_last_combat = {
		"damage": result.damage_dealt,
		"shield": result.shield_gained,
		"heal": result.heal_amount,
		"critical": result.was_crit,
		"crit_chance": result.crit_chance,
	}
	_refresh()

func record_event(event_type: String) -> void:
	_last_event = event_type
	_refresh()

func summary_text() -> String:
	return _body.text

func _refresh() -> void:
	var score = "score pending"
	if not _last_score.is_empty():
		score = "ATK %d / DEF %d / CRT %d\nstance %s | penalty S %.0f%% C %.0f%%\nrhetoric %s" % [
			_last_score["atk"],
			_last_score["def"],
			_last_score["crt"],
			_last_score["stance"],
			float(_last_score["structure"]) * 100.0,
			float(_last_score["constraint"]) * 100.0,
			_last_score["rhetoric"] if not str(_last_score["rhetoric"]).is_empty() else "none",
		]
	var combat = "combat pending"
	if not _last_combat.is_empty():
		combat = "DMG %d / SHD %d / HEAL %d / crit %s %.0f%%" % [
			_last_combat["damage"],
			_last_combat["shield"],
			_last_combat["heal"],
			str(_last_combat["critical"]),
			float(_last_combat["crit_chance"]) * 100.0,
		]
	_body.text = "turn: %s\nseed: %s\nevent: %s\n%s\n%s" % [
		_last_turn,
		str(BattleManager.battle_seed) if Engine.get_main_loop() else "0",
		_last_event,
		score,
		combat,
	]
