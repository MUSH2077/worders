extends Node

const TacticalStanceScript = preload("res://scripts/tactical_stance.gd")
const AIProfileScript = preload("res://scripts/ai_profile.gd")

enum Difficulty { EASY, NORMAL, HARD }
enum Strategy { AGGRESSIVE, DEFENSIVE, BALANCED }

var difficulty: Difficulty = Difficulty.NORMAL

func execute_turn(player: Player, builder: SentenceBuilder) -> void:
	if LLMClient.is_enabled_for_battle() or not LLMClient.mock_ai_turn_response.is_empty():
		var used_llm = await execute_llm_turn(player, builder)
		if used_llm:
			return
	await execute_script_turn(player, builder)

func execute_script_turn(player: Player, builder: SentenceBuilder) -> void:
	var plan = plan_turn(player, builder)
	var strategy = plan.get("strategy", Strategy.BALANCED)
	var stance = plan.get("stance", TacticalStanceScript.Stance.BALANCED)
	player.current_stance = stance
	var profile = _profile_for_player(player)
	if profile:
		Events.ai_profile_declared.emit(profile.profile_name, profile.archetype, profile.weakness)
	Events.ai_intent_declared.emit(_strategy_name(strategy, profile))
	Events.stance_changed.emit(player, stance)
	Events.ai_stance_declared.emit(_strategy_name(strategy, profile), TacticalStanceScript.key(stance))
	for card in plan.get("special_cards", []):
		if player.hand.has(card) and player.mana >= card.mana_cost:
			BattleManager.play_special_card(card, player)
			await BattleManager.wait_anim(0.26)
	var cards = plan.get("fill_cards", [])
	for card in cards:
		if not player.hand.has(card):
			continue
		var slot = builder.add_card(card)
		player.remove_from_hand(card)
		Events.ai_card_committed.emit(card, builder.get_slot_index(slot))
		await BattleManager.wait_anim(0.28)
	for slot in builder.get_ordered_slots():
		var word = _select_word(slot, strategy)
		slot.word = word
		Events.ai_word_filled.emit(slot, word)
		await BattleManager.wait_anim(0.24)
	_trim_to_mana(player, builder)
	if not builder.is_complete():
		Events.event_triggered.emit("ai_pass")
		_return_unplayed_cards(player, builder)
		await BattleManager.wait_anim(0.35)
		Events.sentence_built.emit(builder.get_sentence_input())
		return
	var cost = builder.get_total_mana_cost()
	player.spend_mana(cost)
	await BattleManager.wait_anim(0.5)
	Events.sentence_built.emit(builder.get_sentence_input())

func execute_llm_turn(player: Player, builder: SentenceBuilder) -> bool:
	var context = build_ai_turn_context(player, builder)
	var plan = await LLMClient.request_ai_turn_plan(context)
	if not plan.get("ok", false):
		Events.ai_llm_plan_failed.emit(str(plan.get("fallback_reason", "request_failed")))
		return false
	return await execute_llm_tool_plan(player, builder, plan.get("tool_calls", []), true)

func execute_llm_tool_plan(player: Player, builder: SentenceBuilder, tool_calls: Array, animate: bool = true, emit_sentence: bool = true) -> bool:
	var initial_cards: Dictionary = {}
	for i in range(player.hand.size()):
		initial_cards[i] = player.hand[i]
	var committed_any = false
	var finished = false
	var had_invalid_critical = false
	for call in tool_calls:
		if not (call is Dictionary):
			continue
		var ok = _execute_llm_tool(call, player, builder, initial_cards)
		if not ok:
			had_invalid_critical = true
			continue
		match str(call.get("name", "")):
			"commit_fill_card":
				committed_any = true
			"finish_turn":
				finished = true
		if animate:
			await BattleManager.wait_anim(0.20)
	_trim_to_mana(player, builder)
	if not committed_any or not builder.is_complete() or had_invalid_critical:
		Events.ai_llm_plan_failed.emit("invalid_or_incomplete_plan")
		_return_unplayed_cards(player, builder)
		return false
	var cost = builder.get_total_mana_cost()
	if not player.spend_mana(cost):
		Events.ai_llm_plan_failed.emit("no_mana")
		_return_unplayed_cards(player, builder)
		return false
	if not finished:
		Events.ai_llm_plan_failed.emit("implicit_finish_turn")
	if animate:
		await BattleManager.wait_anim(0.45)
	if emit_sentence:
		Events.sentence_built.emit(builder.get_sentence_input())
	return true

func choose_event_choice(player: Player, choices: Array, preferred_archetype: String):
	if choices.is_empty():
		return null
	if LLMClient.is_enabled_for_battle() or not LLMClient.mock_ai_event_response.is_empty():
		var selected = await choose_llm_event_choice(player, choices, preferred_archetype)
		if selected != null:
			return selected
	return _choose_script_event_choice(choices, preferred_archetype)

func choose_llm_event_choice(player: Player, choices: Array, preferred_archetype: String):
	var context = {
		"game": "WORDERS",
		"turn": TurnManager.current_turn_number,
		"phase": TurnManager.Phase.keys()[TurnManager.current_phase],
		"ai": _player_context(player),
		"opponent": _player_context(_get_opponent(player)),
		"preferred_archetype": preferred_archetype,
		"choices": event_choices_context(choices),
	}
	var plan = await LLMClient.request_ai_event_choice(context)
	if not plan.get("ok", false):
		Events.ai_llm_plan_failed.emit(str(plan.get("fallback_reason", "event_request_failed")))
		return null
	for call in plan.get("tool_calls", []):
		if not (call is Dictionary) or str(call.get("name", "")) != "choose_event":
			continue
		var args = call.get("arguments", {})
		if not (args is Dictionary):
			args = {}
		var choice = _choice_from_id(str(args.get("choice_id", "")), choices)
		if choice != null:
			Events.ai_event_choice_declared.emit(choice, str(args.get("reason", "")))
			return choice
	Events.ai_llm_plan_failed.emit("invalid_event_choice")
	return null

func event_choices_context(choices: Array) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for choice in choices:
		if choice == null:
			continue
		result.append({
			"id": choice.id,
			"name": choice.name,
			"description": choice.description,
			"effect_type": choice.effect_type,
			"value": choice.value,
			"preferred_archetype": choice.preferred_archetype,
		})
	return result

func build_ai_turn_context(player: Player, builder: SentenceBuilder) -> Dictionary:
	var opponent = _get_opponent(player)
	var hand: Array[Dictionary] = []
	for i in range(player.hand.size()):
		var card = player.hand[i]
		hand.append(_card_context(card, i))
	return {
		"game": "WORDERS",
		"turn": TurnManager.current_turn_number,
		"phase": TurnManager.Phase.keys()[TurnManager.current_phase],
		"ai": _player_context(player),
		"opponent": _player_context(opponent),
		"profile": _profile_context(player),
		"objective": _objective_context(player),
		"available_mana": player.mana,
		"current_sentence_cost": builder.get_total_mana_cost(),
		"hand": hand,
		"legal_stances": ["balanced", "break", "guard", "harmony"],
		"allowed_emojis": ["🙂", "✨", "🛡️", "🔥", "💚"],
		"rules": [
			"Use fill cards to build a complete sentence, then fill every slot with a word.",
			"Do not exceed available mana after special cards and sentence cost.",
			"Predicate, object, complement favor attack; subject and attribute favor defense; adverbial favors crit.",
			"Matching word constraints improves scoring; known mismatches add soft risk.",
		],
	}

func _execute_llm_tool(call: Dictionary, player: Player, builder: SentenceBuilder, initial_cards: Dictionary) -> bool:
	var name = str(call.get("name", ""))
	var args = call.get("arguments", {})
	if not (args is Dictionary):
		args = {}
	match name:
		"set_stance":
			var stance = _stance_from_key(str(args.get("stance", "balanced")))
			player.current_stance = stance
			var strategy = _strategy_for_stance(stance)
			var profile = _profile_for_player(player)
			Events.ai_intent_declared.emit(_strategy_name(strategy, profile))
			Events.stance_changed.emit(player, stance)
			Events.ai_stance_declared.emit(_strategy_name(strategy, profile), TacticalStanceScript.key(stance))
			return true
		"play_special_card":
			var card = _card_from_llm_id(int(args.get("card_id", -1)), initial_cards)
			if card == null or card.card_type == CardData.CardType.FILL or not player.hand.has(card) or player.mana < card.mana_cost:
				return false
			return BattleManager.play_special_card(card, player)
		"commit_fill_card":
			var fill = _card_from_llm_id(int(args.get("card_id", -1)), initial_cards)
			if fill == null or fill.card_type != CardData.CardType.FILL or not player.hand.has(fill):
				return false
			var target_index = clampi(int(args.get("target_index", builder.slots.size())), 0, 5)
			var projected_cost = builder.get_total_mana_cost() + max(1, fill.mana_cost)
			if projected_cost > player.mana:
				return false
			var slot = builder.add_card(fill, target_index)
			player.remove_from_hand(fill)
			Events.ai_card_committed.emit(fill, builder.get_slot_index(slot))
			return true
		"fill_slot":
			var slot_index = int(args.get("slot_index", -1))
			var word = str(args.get("word", "")).strip_edges()
			if slot_index < 0 or slot_index >= builder.slots.size() or word.is_empty():
				return false
			builder.slots[slot_index].word = word
			Events.ai_word_filled.emit(builder.slots[slot_index], word)
			return true
		"send_emote":
			var emoji = str(args.get("emoji", "🙂"))
			if emoji not in ["🙂", "✨", "🛡️", "🔥", "💚"]:
				return false
			var message = str(args.get("message", "")).strip_edges().left(80)
			Events.ai_emote_sent.emit(emoji, message)
			return true
		"finish_turn":
			return true
	return false

func _card_from_llm_id(card_id: int, initial_cards: Dictionary) -> CardData:
	return initial_cards.get(card_id, null) as CardData

func _choice_from_id(choice_id: String, choices: Array):
	for choice in choices:
		if choice != null and choice.id == choice_id:
			return choice
	return null

func _stance_from_key(key: String) -> int:
	match key.to_lower():
		"break":
			return TacticalStanceScript.Stance.BREAK
		"guard":
			return TacticalStanceScript.Stance.GUARD
		"harmony":
			return TacticalStanceScript.Stance.HARMONY
	return TacticalStanceScript.Stance.BALANCED

func _strategy_for_stance(stance: int) -> Strategy:
	match stance:
		TacticalStanceScript.Stance.BREAK:
			return Strategy.AGGRESSIVE
		TacticalStanceScript.Stance.GUARD:
			return Strategy.DEFENSIVE
	return Strategy.BALANCED

func _player_context(player: Player) -> Dictionary:
	if player == null:
		return {}
	return {
		"hp": player.hp,
		"max_hp": player.max_hp,
		"shield": player.shield,
		"mana": player.mana,
		"max_mana": player.max_mana,
		"hand_count": player.hand.size(),
		"deck_count": player.deck.size() if player.deck else 0,
		"stance": TacticalStanceScript.key(player.current_stance),
		"archetype_seal": player.archetype_seal,
	}

func _profile_context(player: Player) -> Dictionary:
	var profile = _profile_for_player(player)
	if profile == null:
		return {}
	return profile.to_context()

func _objective_context(player: Player) -> Dictionary:
	if player == null or player.current_objective == null:
		return {}
	var objective = player.current_objective
	var state = BattleManager.evaluate_active_objective(player)
	return {
		"id": objective.id,
		"name": objective.name,
		"description": objective.description,
		"archetype": objective.archetype,
		"reward": objective.reward_summary(),
		"state": state.get("state", "empty"),
		"reason": state.get("reason", ""),
	}

func _card_context(card: CardData, llm_id: int) -> Dictionary:
	return {
		"id": llm_id,
		"resource_id": card.id,
		"name": card.get_display_name(),
		"type": CardData.TYPE_LABELS[card.card_type],
		"cost": card.mana_cost,
		"component": CardData.COMPONENT_LABELS[card.comp_constraint],
		"part_of_speech": CardData.POS_LABELS[card.pos_constraint],
		"theme": CardData.CONTENT_LABELS[card.content_constraint],
		"effect": CardData.EFFECT_LABELS[card.effect],
		"effect_value": card.effect_value,
		"word_suggestions": _word_suggestions_for_card(card, 5),
	}

func _word_suggestions_for_card(card: CardData, limit: int) -> Array[String]:
	var pos_f = CardData.PartOfSpeech.keys()[card.pos_constraint]
	var cat_f = CardData.ContentCategory.keys()[card.content_constraint]
	var rng = RandomNumberGenerator.new()
	rng.seed = BattleManager.battle_seed + TurnManager.current_turn_number * 733 + card.id
	var entries = WordBank.sample_by_constraints(pos_f, cat_f, limit, rng)
	var result: Array[String] = []
	for entry in entries:
		result.append(entry.text)
	return result

func plan_turn(player: Player, _builder: SentenceBuilder) -> Dictionary:
	var strategy = _choose_strategy(player)
	var stance = _choose_stance(player, strategy)
	var special_cards = _select_special_cards(player, strategy, stance)
	var reserved_mana = 0
	for card in special_cards:
		reserved_mana += max(0, card.mana_cost)
	var fill_cards = _select_sentence_cards(player, strategy, stance, max(0, player.mana - reserved_mana))
	return {
		"strategy": strategy,
		"stance": stance,
		"special_cards": special_cards,
		"fill_cards": fill_cards,
	}

func _trim_to_mana(player: Player, builder: SentenceBuilder) -> void:
	while builder.get_total_mana_cost() > player.mana and not builder.slots.is_empty():
		var slot = builder.slots.pop_back()
		player.hand.append(slot.card)

func _return_unplayed_cards(player: Player, builder: SentenceBuilder) -> void:
	for slot in builder.slots:
		player.hand.append(slot.card)
	builder.clear()

func _choose_script_event_choice(choices: Array, preferred_archetype: String):
	for choice in choices:
		if choice.preferred_archetype == preferred_archetype:
			return choice
	return choices[0]

func _choose_strategy(player: Player) -> Strategy:
	if difficulty == Difficulty.EASY:
		return Strategy.BALANCED
	var opp = _get_opponent(player)
	if opp == null:
		return Strategy.BALANCED
	var hp_r = float(player.hp) / float(player.max_hp)
	var op_r = float(opp.hp) / float(opp.max_hp)
	if hp_r < 0.4:
		return Strategy.DEFENSIVE
	if op_r < 0.4:
		return Strategy.AGGRESSIVE
	var profile = _profile_for_player(player)
	if profile:
		match profile.archetype:
			"attack":
				return Strategy.AGGRESSIVE
			"defense":
				return Strategy.DEFENSIVE
	return Strategy.BALANCED

func _choose_stance(player: Player, strategy: Strategy) -> int:
	var profile = _profile_for_player(player)
	if profile and difficulty != Difficulty.EASY:
		if player.hp < int(float(player.max_hp) * 0.35):
			return TacticalStanceScript.Stance.GUARD
		return profile.preferred_stance
	match strategy:
		Strategy.AGGRESSIVE:
			return TacticalStanceScript.Stance.BREAK
		Strategy.DEFENSIVE:
			return TacticalStanceScript.Stance.GUARD
		_:
			if _has_rhetoric_setup(player):
				return TacticalStanceScript.Stance.HARMONY
	return TacticalStanceScript.Stance.BALANCED

func _get_opponent(p: Player) -> Player:
	if BattleManager.player1 == p:
		return BattleManager.player2
	return BattleManager.player1

func _select_cards(player: Player, strategy: Strategy) -> Array[CardData]:
	return _select_sentence_cards(player, strategy, _choose_stance(player, strategy), player.mana)

func _select_sentence_cards(player: Player, strategy: Strategy, stance: int, available_mana: int) -> Array[CardData]:
	if player.hand.is_empty():
		return []
	var fill_cards: Array[CardData] = []
	for card in player.hand:
		if card.card_type == CardData.CardType.FILL:
			fill_cards.append(card)
	if fill_cards.is_empty():
		return []
	if difficulty == Difficulty.EASY:
		var copy = fill_cards.duplicate()
		copy.shuffle()
		var n = randi() % min(copy.size(), 4) + 1
		return copy.slice(0, n)
	var sorted = fill_cards.duplicate()
	sorted.sort_custom(func(a: CardData, b: CardData):
		return _card_score(a, strategy) > _card_score(b, strategy))
	var best: Array[CardData] = []
	var best_score = -999999.0
	var max_len = min(5, sorted.size())
	for length in range(2, max_len + 1):
		var candidate: Array[CardData] = []
		var mana = 0
		for card in sorted:
			if candidate.size() >= length:
				break
			if mana + card.mana_cost <= available_mana:
				candidate.append(card)
				mana += card.mana_cost
		if candidate.is_empty():
			continue
		var score = _candidate_score(candidate, strategy, stance)
		if score > best_score:
			best_score = score
			best = candidate
	if not best.is_empty():
		return best
	var result: Array[CardData] = []
	var used_mana = 0
	for card in sorted:
		var est = max(1, card.mana_cost)
		if used_mana + est <= available_mana:
			result.append(card)
			used_mana += est
		if result.size() >= 5:
			break
	return result

func _select_special_cards(player: Player, strategy: Strategy, _stance: int) -> Array[CardData]:
	var candidates: Array[CardData] = []
	for card in player.hand:
		if card.card_type != CardData.CardType.FILL and card.mana_cost <= player.mana:
			candidates.append(card)
	if candidates.is_empty():
		return []
	candidates.sort_custom(func(a: CardData, b: CardData):
		return _special_card_score(a, strategy) > _special_card_score(b, strategy))
	var best = candidates[0]
	if _special_card_score(best, strategy) <= 0.0:
		return []
	return [best]

func _card_score(card: CardData, strategy: Strategy) -> float:
	var s = card.base_disorder
	match strategy:
		Strategy.AGGRESSIVE:
			if card.comp_constraint in ScoringEngine.ATK_COMPS:
				s += 10
		Strategy.DEFENSIVE:
			if card.comp_constraint in ScoringEngine.DEF_COMPS:
				s += 10
	return s

func _special_card_score(card: CardData, strategy: Strategy) -> float:
	var s = 0.0
	match strategy:
		Strategy.AGGRESSIVE:
			if card.effect in [CardData.CardEffect.WEAKEN, CardData.CardEffect.STEAL, CardData.CardEffect.SEAL]:
				s += 20
		Strategy.DEFENSIVE:
			if card.effect in [CardData.CardEffect.SHIELD, CardData.CardEffect.HEAL, CardData.CardEffect.CLEANSE]:
				s += 20
		_:
			if card.effect in [CardData.CardEffect.DRAW, CardData.CardEffect.MANA, CardData.CardEffect.ECHO]:
				s += 18
	s += float(card.effect_value) - float(card.mana_cost)
	return s

func _candidate_score(cards: Array[CardData], strategy: Strategy, stance: int) -> float:
	var input = ScoringEngine.SentenceInput.new()
	for card in cards:
		input.cards.append(card)
		input.components.append(card.comp_constraint)
		input.words.append(_select_word_for_card(card))
	var preview = ScoringEngine.calculate_with_stance(input, BattleManager.rhyme_map, stance)
	match strategy:
		Strategy.AGGRESSIVE:
			return preview.atk + preview.crt * 0.5
		Strategy.DEFENSIVE:
			return preview.def_ + preview.atk * 0.25
	return preview.atk + preview.def_ + preview.crt * 0.4

func _has_rhetoric_setup(player: Player) -> bool:
	var adverbial_count = 0
	for card in player.hand:
		if card.card_type == CardData.CardType.FILL and card.comp_constraint == CardData.SentenceComponent.ADVERBIAL:
			adverbial_count += 1
		if card.effect == CardData.CardEffect.ECHO:
			return true
	return adverbial_count >= 1

func _select_word(slot: SentenceBuilder.Slot, _strategy: Strategy) -> String:
	return _select_word_for_card(slot.card)

func _select_word_for_card(card: CardData) -> String:
	var pos_f = CardData.PartOfSpeech.keys()[card.pos_constraint]
	var cat_f = CardData.ContentCategory.keys()[card.content_constraint]
	var rng = RandomNumberGenerator.new()
	rng.seed = BattleManager.battle_seed + TurnManager.current_turn_number * 811 + card.id * 17
	var cand = WordBank.sample_by_constraints(pos_f, cat_f, 1, rng)
	if cand.is_empty():
		return "word"
	return cand[0].text

func _profile_for_player(player: Player):
	if player == null:
		return null
	if player.ai_profile != null:
		return player.ai_profile
	if player.is_ai:
		player.ai_profile = AIProfileScript.choose_for_seed(BattleManager.battle_seed + TurnManager.current_turn_number)
		if player.ai_profile:
			player.archetype_seal = player.ai_profile.archetype
	return player.ai_profile

func _strategy_name(strategy: Strategy, profile = null) -> String:
	var base = Strategy.keys()[strategy]
	if profile == null:
		return base
	return "%s/%s" % [base, profile.profile_name]
