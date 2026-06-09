extends Node

const MAX_ENTRIES := 360
const REPLAY_DIR := "user://battle_replays"
const LATEST_REPLAY := "user://battle_replays/latest_worders_replay.json"

var current_seed: int = 0
var entries: Array[Dictionary] = []
var session_active := false
var last_export_path := ""
var _connected := false

func _ready() -> void:
	_connect_events()

func start_run(seed_value: int) -> void:
	_connect_events()
	current_seed = seed_value
	session_active = true
	entries.clear()
	record("battle_start", {"seed": current_seed})

func stop_run() -> void:
	if not session_active:
		return
	record("battle_stop", {})
	session_active = false
	export_latest()

func record(event_type: String, payload: Dictionary = {}) -> void:
	if not session_active and event_type != "battle_start":
		return
	var entry = {
		"t": Time.get_datetime_string_from_system(),
		"turn": TurnManager.current_turn_number if Engine.get_main_loop() else 0,
		"phase": TurnManager.Phase.keys()[TurnManager.current_phase] if Engine.get_main_loop() else "NONE",
		"type": event_type,
		"payload": _safe_payload(payload),
	}
	entries.append(entry)
	while entries.size() > MAX_ENTRIES:
		entries.remove_at(0)

func latest_summary() -> Dictionary:
	return {
		"seed": current_seed,
		"entries": entries.size(),
		"last_type": entries.back()["type"] if not entries.is_empty() else "",
		"path": last_export_path,
	}

func snapshot() -> Dictionary:
	return {
		"game": "WORDERS",
		"seed": current_seed,
		"entries": entries.duplicate(true),
	}

func export_latest() -> String:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(REPLAY_DIR))
	var f = FileAccess.open(LATEST_REPLAY, FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify(snapshot(), "\t"))
		f.close()
		last_export_path = LATEST_REPLAY
	return last_export_path

func _connect_events() -> void:
	if _connected or not Engine.get_main_loop():
		return
	_connected = true
	Events.turn_changed.connect(func(player): record("turn_changed", {"player": _player_name(player)}))
	Events.phase_changed.connect(func(phase_name): record("phase_changed", {"phase": phase_name}))
	Events.ai_intent_declared.connect(func(strategy_name): record("ai_intent", {"strategy": strategy_name}))
	Events.ai_stance_declared.connect(func(strategy_name, stance_name): record("ai_stance", {"strategy": strategy_name, "stance": stance_name}))
	Events.ai_card_committed.connect(func(card, slot_index): record("ai_card", {"card": _card_name(card), "slot": slot_index}))
	Events.ai_word_filled.connect(func(_slot, word): record("ai_word", {"word": word}))
	Events.ai_emote_sent.connect(func(emoji, message): record("ai_emote", {"emoji": emoji, "message": message}))
	Events.score_calculated.connect(func(breakdown): record("score", _score_payload(breakdown)))
	Events.combat_resolved.connect(func(result): record("combat", _combat_payload(result)))
	Events.event_triggered.connect(func(event_type): record("event", {"event": event_type}))
	Events.event_choice_selected.connect(func(choice): record("event_choice", {"choice": choice.id if choice else ""}))
	Events.game_over.connect(func(winner):
		record("game_over", {"winner": _player_name(winner)})
		export_latest())

func _safe_payload(payload: Dictionary) -> Dictionary:
	var safe := {}
	for key in payload.keys():
		var value = payload[key]
		if value is CardData:
			safe[key] = _card_name(value)
		elif value is Player:
			safe[key] = _player_name(value)
		elif value is Object:
			safe[key] = str(value)
		else:
			safe[key] = value
	return safe

func _player_name(player) -> String:
	return player.player_name if player and player is Player else "none"

func _card_name(card) -> String:
	return card.get_display_name() if card and card is CardData else "none"

func _score_payload(breakdown) -> Dictionary:
	if breakdown == null:
		return {}
	return {
		"atk": breakdown.atk,
		"def": breakdown.def_,
		"crt": breakdown.crt,
		"stance": breakdown.stance_name,
		"structure_penalty": breakdown.structure_penalty_percent,
		"constraint_penalty": breakdown.constraint_penalty_percent,
		"flags": breakdown.rhetoric_flags,
	}

func _combat_payload(result) -> Dictionary:
	if result == null:
		return {}
	return {
		"damage": result.damage_dealt,
		"shield": result.shield_gained,
		"heal": result.heal_amount,
		"critical": result.was_crit,
		"crit_chance": result.crit_chance,
	}
