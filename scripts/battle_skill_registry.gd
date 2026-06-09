class_name BattleSkillRegistry extends RefCounted

# Single execution surface for the ally helper. Slash commands typed in chat and
# (later) DeepSeek ally tool calls both route through execute(), so there is one
# permission gate and one set of state mutations that reuse BattleManager APIs.
#
# A SkillResult is intentionally plain data so it can be rendered in chat, logged,
# or returned to an LLM tool call without any UI coupling.

class SkillResult:
	var ok: bool = false
	var command: String = ""
	var message: String = ""
	var kind: String = "info"  # info | fill | play | stance | confirm | suggest | preview | error
	var data: Dictionary = {}
	func to_dict() -> Dictionary:
		return {"ok": ok, "command": command, "message": message, "kind": kind, "data": data}

const COMMANDS = ["help", "suggest", "fill", "play", "stance", "preview", "confirm"]

static func _result(command: String, ok: bool, message: String, kind: String = "info", data: Dictionary = {}) -> SkillResult:
	var r = SkillResult.new()
	r.command = command
	r.ok = ok
	r.message = message
	r.kind = "error" if not ok else kind
	r.data = data
	return r

# Parse a raw "/cmd arg1 arg2" string into { command, args }.
static func parse(raw: String) -> Dictionary:
	var text = raw.strip_edges()
	if text.begins_with("/"):
		text = text.substr(1)
	var parts = text.split(" ", false)
	if parts.is_empty():
		return {"command": "", "args": []}
	var command = str(parts[0]).to_lower()
	var args: Array = []
	for i in range(1, parts.size()):
		args.append(parts[i])
	return {"command": command, "args": args}

static func is_skill_command(raw: String) -> bool:
	var text = raw.strip_edges()
	if not text.begins_with("/"):
		return false
	var parsed = parse(text)
	return COMMANDS.has(parsed.get("command", ""))

# Central permission gate: ally skills only act on the human player's own main turn.
static func _can_act() -> bool:
	if BattleManager.current_player == null or BattleManager.current_player.is_ai:
		return false
	return TurnManager.current_phase in [TurnManager.Phase.DRAW, TurnManager.Phase.MAIN]

static func execute(command: String, args: Array) -> SkillResult:
	command = str(command).to_lower()
	match command:
		"help":
			return _cmd_help()
		"suggest":
			return _cmd_suggest(args)
		"fill":
			return _cmd_fill(args)
		"play":
			return _cmd_play(args)
		"stance":
			return _cmd_stance(args)
		"preview":
			return _cmd_preview()
		"confirm":
			return _cmd_confirm()
	return _result(command, false, "Unknown command: /%s" % command)

static func execute_raw(raw: String) -> SkillResult:
	var parsed = parse(raw)
	return execute(parsed.get("command", ""), parsed.get("args", []))

static func _cmd_help() -> SkillResult:
	return _result("help", true, I18n.t("skill_help_detail"), "info", {"commands": COMMANDS})

static func _cmd_suggest(args: Array) -> SkillResult:
	if BattleManager.current_player == null:
		return _result("suggest", false, "No active battle.")
	var ordered = BattleManager.sentence_builder.get_ordered_slots()
	if ordered.is_empty():
		return _result("suggest", false, "Drag fill cards into the sentence zone first.")
	var target_index = -1
	if args.size() > 0:
		target_index = int(str(args[0]))
	var lines: Array[String] = []
	var data_slots: Array = []
	for i in range(ordered.size()):
		if target_index >= 0 and i != target_index:
			continue
		var slot = ordered[i]
		var words = _suggest_words_for_slot(slot, 3)
		if words.is_empty():
			continue
		lines.append("[%d %s] %s" % [i, slot.card.get_comp_name(), ", ".join(words)])
		data_slots.append({"index": i, "words": words})
	if lines.is_empty():
		return _result("suggest", false, "No suggestions available.")
	return _result("suggest", true, "\n".join(lines), "suggest", {"slots": data_slots})

static func _cmd_fill(args: Array) -> SkillResult:
	if not _can_act():
		return _result("fill", false, "You can only fill words on your own turn.")
	if args.size() < 2:
		return _result("fill", false, "Usage: /fill <slot> <word>")
	var slot_index = int(str(args[0]))
	var word = " ".join(_string_args(args).slice(1)).strip_edges()
	if word.is_empty():
		return _result("fill", false, "Provide a word to fill.")
	var slots = BattleManager.sentence_builder.get_ordered_slots()
	if slot_index < 0 or slot_index >= slots.size():
		return _result("fill", false, "Slot %d does not exist." % slot_index)
	var slot = slots[slot_index]
	slot.word = word
	Events.ai_word_filled.emit(slot, word)
	return _result("fill", true, "Filled slot %d with \"%s\"." % [slot_index, word], "fill", {"slot_index": slot_index, "word": word})

static func _cmd_play(args: Array) -> SkillResult:
	if not _can_act():
		return _result("play", false, "You can only play cards on your own turn.")
	if args.is_empty():
		return _result("play", false, "Usage: /play <card_id>")
	var card_id = int(str(args[0]))
	var player = BattleManager.current_player
	var card = _find_hand_card(player, card_id)
	if card == null:
		return _result("play", false, "No card with id %d in hand." % card_id)
	if card.card_type != CardData.CardType.FILL:
		return _result("play", false, "/play only commits fill cards. Use the card UI for special cards.")
	var projected = BattleManager.sentence_builder.get_total_mana_cost() + max(1, card.mana_cost)
	if projected > player.mana:
		return _result("play", false, "Not enough mana for that card.")
	var slot = BattleManager.sentence_builder.add_card(card)
	player.remove_from_hand(card)
	Events.ai_card_committed.emit(card, BattleManager.sentence_builder.get_slot_index(slot))
	return _result("play", true, "Committed %s." % card.get_display_name(), "play", {"card_id": card_id})

static func _cmd_stance(args: Array) -> SkillResult:
	if not _can_act():
		return _result("stance", false, "You can only change stance on your own turn.")
	if args.is_empty():
		return _result("stance", false, "Usage: /stance break|guard|harmony|balanced")
	var key = str(args[0]).to_lower()
	var idx = TacticalStance.KEYS.find(key)
	if idx < 0:
		return _result("stance", false, "Unknown stance: %s" % key)
	BattleManager.set_current_stance(idx)
	return _result("stance", true, "Stance set to %s." % key, "stance", {"stance": key})

static func _cmd_preview() -> SkillResult:
	if BattleManager.current_player == null:
		return _result("preview", false, "No active battle.")
	var input = BattleManager.sentence_builder.get_sentence_input()
	if input.length() == 0:
		return _result("preview", false, "The sentence is empty.")
	var b = BattleManager.preview_sentence(input, BattleManager.current_player)
	var msg = "ATK %d · DEF %d · CRT %d | combo x%.1f · rhetoric x%.1f · penalty %.0f%%" % [
		b.atk, b.def_, b.crt, b.combo_mult, b.rhetoric_mult, b.penalty_percent * 100.0,
	]
	return _result("preview", true, msg, "preview", {
		"atk": b.atk, "def": b.def_, "crt": b.crt,
		"combo": b.combo_mult, "rhetoric": b.rhetoric_mult, "penalty": b.penalty_percent,
	})

static func _cmd_confirm() -> SkillResult:
	if not _can_act():
		return _result("confirm", false, "You can only confirm on your own turn.")
	if not BattleManager.sentence_builder.is_complete():
		return _result("confirm", false, "Fill every slot before confirming.")
	if BattleManager.sentence_builder.get_total_mana_cost() > BattleManager.current_player.mana:
		return _result("confirm", false, "Not enough mana to confirm.")
	BattleManager.confirm_sentence()
	return _result("confirm", true, "Sentence confirmed.", "confirm")

static func _string_args(args: Array) -> Array[String]:
	var result: Array[String] = []
	for a in args:
		result.append(str(a))
	return result

static func _find_hand_card(player, card_id: int) -> CardData:
	if player == null:
		return null
	for card in player.hand:
		if card != null and card.id == card_id:
			return card
	return null

static func _suggest_words_for_slot(slot, limit: int) -> Array[String]:
	var words: Array[String] = []
	if slot == null or slot.card == null:
		return words
	var pos_f = CardData.PartOfSpeech.keys()[slot.card.pos_constraint]
	var cat_f = CardData.ContentCategory.keys()[slot.card.content_constraint]
	var rng = RandomNumberGenerator.new()
	rng.seed = BattleManager.battle_seed + TurnManager.current_turn_number * 503 + slot.card.id * 13
	var entries = WordBank.sample_by_constraints(pos_f, cat_f, limit, rng)
	for entry in entries:
		var text = str(entry.text).strip_edges()
		if not text.is_empty() and not words.has(text):
			words.append(text)
	return words
