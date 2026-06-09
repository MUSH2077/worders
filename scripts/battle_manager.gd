extends Node

const TacticalStanceScript = preload("res://scripts/tactical_stance.gd")
const BattleEventChoiceScript = preload("res://scripts/battle_event_choice.gd")
const BattleObjectiveScript = preload("res://scripts/battle_objective.gd")
const AIProfileScript = preload("res://scripts/ai_profile.gd")

var player1: Player
var player2: Player
var current_player: Player
var sentence_builder: SentenceBuilder = SentenceBuilder.new()
var rhyme_map: Dictionary = {}

const STARTING_MANA = 3
const PLAYER_TURN_SECONDS = 120
const PHASE_SCORE_DELAY = 0.35
const PHASE_RESOLVE_DELAY = 0.70
const PHASE_EVENT_DELAY = 0.65
const PHASE_END_DELAY = 0.55
const SPEED_OPTIONS = [1.0, 2.0, 4.0]

var turn_seconds_left: float = 0.0
var _turn_timer_active := false
var _ending_turn := false
var _last_timer_second := -1
var animation_speed: float = 1.0
var battle_seed: int = 0
var _rhetoric_combo_count: int = 0
var _last_rhetoric_flags: Array[String] = []
var _echo_active: bool = false
var _echo_mult: float = 1.0

func _ready() -> void:
	_load_rhyme_map()
	Events.turn_changed.connect(_on_turn_changed)
	Events.sentence_built.connect(_on_sentence_built)

func _load_rhyme_map() -> void:
	var f = FileAccess.open("res://resources/pinyin_rhyme_map.json", FileAccess.READ)
	if f:
		rhyme_map = JSON.parse_string(f.get_as_text())
		f.close()

func start_battle(seed_value: int = -1) -> void:
	_turn_timer_active = false
	_ending_turn = false
	_last_timer_second = -1
	battle_seed = _resolve_battle_seed(seed_value)
	seed(battle_seed)
	if Engine.get_main_loop() and get_tree().root.has_node("BattleRecorder"):
		BattleRecorder.start_run(battle_seed)
	player1 = _make_player("Player", false)
	player2 = _make_player("AI", true)
	player1.archetype_seal = "rhetoric"
	player2.ai_profile = AIProfileScript.choose_for_seed(battle_seed)
	if player2.ai_profile:
		player2.archetype_seal = player2.ai_profile.archetype
	Events.archetype_seal_changed.emit(player1, player1.archetype_seal)
	Events.archetype_seal_changed.emit(player2, player2.archetype_seal)
	_build_decks()
	_draw_hands()
	TurnManager.start_turn(player1)

func _resolve_battle_seed(seed_value: int) -> int:
	if seed_value >= 0:
		return seed_value
	return int(Time.get_unix_time_from_system()) ^ Time.get_ticks_msec()

func cycle_animation_speed() -> void:
	var index = SPEED_OPTIONS.find(animation_speed)
	if index < 0:
		index = 0
	animation_speed = SPEED_OPTIONS[(index + 1) % SPEED_OPTIONS.size()]
	Events.animation_speed_changed.emit(animation_speed)

func anim_time(seconds_at_current_old_speed: float) -> float:
	return seconds_at_current_old_speed * 2.0 / animation_speed

func wait_anim(seconds_at_current_old_speed: float) -> void:
	await get_tree().create_timer(anim_time(seconds_at_current_old_speed)).timeout

func _process(delta: float) -> void:
	if not _turn_timer_active or _ending_turn:
		return
	if current_player == null or current_player.is_ai:
		return
	if TurnManager.current_phase not in [TurnManager.Phase.DRAW, TurnManager.Phase.MAIN]:
		return
	turn_seconds_left = max(0.0, turn_seconds_left - delta)
	var whole_second = int(ceil(turn_seconds_left))
	if whole_second != _last_timer_second:
		_last_timer_second = whole_second
		Events.turn_timer_changed.emit(whole_second)
	if turn_seconds_left <= 0.0:
		pass_turn("timeout")

func _make_player(pname: String, ai: bool) -> Player:
	var p = Player.new()
	p.player_name = pname
	p.is_ai = ai
	p.deck = Deck.new()
	return p

func _build_decks() -> void:
	for i in range(30):
		player1.deck.add_card(_starter_card_for_index(i))
		player2.deck.add_card(_starter_card_for_index(i))
	player1.deck.shuffle()
	player2.deck.shuffle()

func _starter_card_for_index(index: int) -> CardData:
	var card: CardData = null
	if index < 20:
		card = CardDatabase.get_random_fill_card()
	elif index < 25:
		card = CardDatabase.get_random_function_card()
	elif index < 28:
		card = CardDatabase.get_random_equipment_card()
	else:
		card = CardDatabase.get_random_status_card()
	if card == null:
		card = CardDatabase.get_random_fill_card()
	return card

func _draw_hands() -> void:
	for i in range(5):
		player1.hand.append(CardDatabase.get_random_fill_card())
		player2.hand.append(CardDatabase.get_random_fill_card())

func _draw(p: Player) -> void:
	if p.skip_draw_next:
		p.skip_draw_next = false
		return
	for i in range(5):
		var c = p.deck.draw()
		if c:
			p.hand.append(c)

func _on_turn_changed(player: Player) -> void:
	current_player = player
	_ending_turn = false
	_turn_timer_active = false
	_last_timer_second = -1
	player.current_stance = TacticalStanceScript.Stance.BALANCED
	Events.stance_changed.emit(player, player.current_stance)
	if player.turns_taken == 0:
		player.max_mana = max(player.max_mana, STARTING_MANA)
	else:
		player.increase_max_mana()
	player.turns_taken += 1
	player.refresh_mana()
	player.reset_shield()
	_draw(player)
	sentence_builder.clear()
	_offer_objective_for_player(player)
	TurnManager.set_phase(TurnManager.Phase.DRAW)
	if player.is_ai:
		if player.ai_profile:
			Events.ai_profile_declared.emit(player.ai_profile.profile_name, player.ai_profile.archetype, player.ai_profile.weakness)
		await wait_anim(0.5)
		AIController.execute_turn(player, sentence_builder)
	else:
		turn_seconds_left = PLAYER_TURN_SECONDS
		_turn_timer_active = true
		_last_timer_second = PLAYER_TURN_SECONDS
		Events.turn_timer_changed.emit(PLAYER_TURN_SECONDS)

func _on_sentence_built(_input) -> void:
	_turn_timer_active = false
	TurnManager.set_phase(TurnManager.Phase.SCORING)
	var input = sentence_builder.get_sentence_input()
	var overrides = await _maybe_review_words_on_confirm(input)
	var breakdown = preview_sentence(input, current_player, overrides)
	# Echo bonus: if active, amplify stats when rhetoric was used last turn
	if _echo_active and breakdown.rhetoric_flags.size() > 0:
		breakdown.atk = int(breakdown.atk * _echo_mult)
		breakdown.def_ = int(breakdown.def_ * _echo_mult)
		breakdown.crt = int(breakdown.crt * _echo_mult)
	_echo_active = false
	# Rhetoric combo tracking
	var new_flags: Array[String] = []
	for f in breakdown.rhetoric_flags:
		new_flags.append(f)
	if new_flags.size() > 0 and _last_rhetoric_flags.size() > 0:
		var overlap = false
		for f in new_flags:
			if _last_rhetoric_flags.has(f):
				overlap = true
				break
		if overlap:
			_rhetoric_combo_count += 1
		else:
			_rhetoric_combo_count = 0
	else:
		_rhetoric_combo_count = 0
	_last_rhetoric_flags = new_flags
	if _rhetoric_combo_count >= 1:
		var cbm = 1.0 + _rhetoric_combo_count * 0.1
		breakdown.atk = int(breakdown.atk * cbm)
		breakdown.def_ = int(breakdown.def_ * cbm)
		breakdown.crt = int(breakdown.crt * cbm)
		Events.rhetoric_combo_triggered.emit(_rhetoric_combo_count + 1, cbm)
	var objective_state = evaluate_active_objective(current_player, input, breakdown)
	if current_player and current_player.current_objective:
		Events.objective_progress_updated.emit(current_player, current_player.current_objective, objective_state)
	Events.score_calculated.emit(breakdown)
	await wait_anim(PHASE_SCORE_DELAY)
	TurnManager.set_phase(TurnManager.Phase.RESOLVE)
	var opp = player2 if current_player == player1 else player1
	var result = CombatResolver.resolve(current_player, opp, breakdown)
	Events.combat_resolved.emit(result)
	_resolve_active_objective(current_player, input, breakdown, result)
	await wait_anim(PHASE_RESOLVE_DELAY)
	if not opp.is_alive():
		Events.game_over.emit(current_player)
		return
	TurnManager.set_phase(TurnManager.Phase.EVENT)
	await _run_event()
	await wait_anim(PHASE_EVENT_DELAY)
	TurnManager.set_phase(TurnManager.Phase.END)
	await wait_anim(PHASE_END_DELAY)
	_end_turn()

func _run_event() -> void:
	var tn = TurnManager.current_turn_number
	if tn % 5 == 0:
		Events.event_triggered.emit("curse")
		var curse = CardData.new()
		curse.id = 9000 + tn
		curse.card_name = "Noise"
		curse.pos_constraint = CardData.PartOfSpeech.ANY
		curse.comp_constraint = CardData.SentenceComponent.ANY
		curse.content_constraint = CardData.ContentCategory.ANY
		curse.base_disorder = 1.0
		curse.description = "A low-value interference card."
		current_player.deck.add_card(curse)
		Events.card_added_to_deck.emit(curse)
		await _offer_event_choices("curse", _preferred_archetype(current_player))
	elif tn % 2 == 0:
		Events.event_triggered.emit("reward")
		await _offer_event_choices("reward", _preferred_archetype(current_player))
	else:
		Events.event_triggered.emit("calm")

func _end_turn() -> void:
	_turn_timer_active = false
	_ending_turn = false
	var next_p = player2 if current_player == player1 else player1
	TurnManager.start_turn(next_p)

func confirm_sentence() -> void:
	if _ending_turn:
		return
	if not sentence_builder.is_complete():
		Events.event_triggered.emit("incomplete")
		return
	var cost = sentence_builder.get_total_mana_cost()
	if not current_player.spend_mana(cost):
		Events.event_triggered.emit("no_mana")
		return
	_turn_timer_active = false
	_ending_turn = true
	Events.sentence_built.emit(sentence_builder.get_sentence_input())

func set_current_stance(stance: int) -> void:
	if current_player == null or current_player.is_ai or _ending_turn:
		return
	current_player.current_stance = TacticalStanceScript.normalize(stance)
	Events.stance_changed.emit(current_player, current_player.current_stance)

func pass_turn(reason: String = "manual") -> void:
	if _ending_turn or current_player == null or current_player.is_ai:
		return
	_turn_timer_active = false
	_ending_turn = true
	for slot in sentence_builder.get_ordered_slots():
		current_player.hand.append(slot.card)
	sentence_builder.clear()
	Events.event_triggered.emit("turn_timeout" if reason == "timeout" else "turn_passed")
	TurnManager.set_phase(TurnManager.Phase.END)
	await wait_anim(PHASE_END_DELAY)
	_end_turn()

func play_special_card(card: CardData, player: Player) -> bool:
	if card == null or player == null:
		return false
	if player != current_player or card.card_type == CardData.CardType.FILL:
		return false
	if not player.hand.has(card):
		return false
	if not player.spend_mana(card.mana_cost):
		Events.event_triggered.emit("no_mana")
		return false
	player.remove_from_hand(card)
	match card.effect:
		CardData.CardEffect.DRAW:
			for _i in range(maxi(1, card.effect_value)):
				_draw(player)
			Events.card_drawn.emit(player)
		CardData.CardEffect.SHIELD:
			player.add_shield(card.effect_value)
		CardData.CardEffect.HEAL:
			player.heal(card.effect_value)
		CardData.CardEffect.MANA:
			player.mana = min(player.max_mana, player.mana + card.effect_value)
			Events.player_mana_changed.emit(player, player.mana, player.max_mana)
		CardData.CardEffect.WEAKEN:
			var target = player2 if player == player1 else player1
			target.take_damage(card.effect_value)
			if not target.is_alive():
				Events.game_over.emit(player)
		CardData.CardEffect.CLEANSE:
			_remove_noise_card(player)
		CardData.CardEffect.STEAL:
			var steal_target = player2 if player == player1 else player1
			if not steal_target.hand.is_empty():
				var idx = randi() % steal_target.hand.size()
				var stolen = steal_target.hand[idx]
				steal_target.hand.remove_at(idx)
				player.hand.append(stolen)
		CardData.CardEffect.SEAL:
			var seal_target = player2 if player == player1 else player1
			seal_target.skip_draw_next = true
		CardData.CardEffect.ECHO:
			_echo_active = true
			_echo_mult = 1.0 + card.effect_value * 0.15
	Events.card_effect_resolved.emit(card, player, CardData.CardEffect.keys()[card.effect], card.effect_value)
	return true

func preview_sentence(input: ScoringEngine.SentenceInput, player: Player = null, overrides: Dictionary = {}) -> ScoringEngine.ScoreBreakdown:
	var stance = player.current_stance if player else TacticalStanceScript.Stance.BALANCED
	var breakdown: ScoringEngine.ScoreBreakdown
	if overrides.is_empty():
		breakdown = ScoringEngine.calculate_with_stance(input, rhyme_map, stance)
	else:
		breakdown = ScoringEngine.calculate_with_judgment(input, rhyme_map, stance, overrides)
	_apply_archetype_seal(breakdown, input, player)
	return breakdown

# Optional L3 review of unknown words on confirm. Returns judgment overrides only
# when the player enabled "judgment affects score"; otherwise reviews are async,
# annotate the log, and never block the scoring/combat animation.
func _maybe_review_words_on_confirm(input: ScoringEngine.SentenceInput) -> Dictionary:
	if current_player == null or current_player.is_ai:
		return {}
	if not LLMClient.should_judge_on_confirm():
		return {}
	var items = _build_judgment_items(input)
	if items.is_empty():
		return {}
	if LLMClient.judgment_affects_score:
		Events.event_triggered.emit("judgment_review")
		var res = await LLMClient.request_word_judgment(items, I18n.language)
		if res.get("ok", false):
			var judgments = res.get("judgments", [])
			Events.word_judgment_completed.emit(judgments, true)
			return _judgments_to_overrides(judgments)
		return {}
	_review_words_async(items)
	return {}

func _review_words_async(items: Array) -> void:
	var res = await LLMClient.request_word_judgment(items, I18n.language)
	if res.get("ok", false):
		Events.word_judgment_completed.emit(res.get("judgments", []), false)

func _build_judgment_items(input: ScoringEngine.SentenceInput) -> Array:
	var items: Array = []
	for i in range(input.words.size()):
		var word = str(input.words[i]).strip_edges()
		if word.is_empty() or i >= input.cards.size():
			continue
		var card = input.cards[i]
		var is_unknown = WordBank.find_entries(word).is_empty()
		if LLMClient.judgment_scope == "unknown_only" and not is_unknown:
			continue
		items.append({
			"index": i,
			"word": word,
			"expected_pos": CardData.PartOfSpeech.keys()[card.pos_constraint],
			"expected_category": CardData.ContentCategory.keys()[card.content_constraint],
		})
	return items

func _judgments_to_overrides(judgments: Array) -> Dictionary:
	var overrides: Dictionary = {}
	for j in judgments:
		if not (j is Dictionary):
			continue
		var word = str(j.get("word", "")).strip_edges().to_lower()
		if word.is_empty():
			continue
		overrides[word] = {
			"matched": bool(j.get("matched", false)),
			"pos": str(j.get("inferred_pos", "ANY")),
			"category": str(j.get("inferred_category", "ANY")),
			"confidence": float(j.get("confidence", 0.0)),
		}
	return overrides

func evaluate_active_objective(player: Player = null, input: ScoringEngine.SentenceInput = null, breakdown: ScoringEngine.ScoreBreakdown = null, context: Dictionary = {}) -> Dictionary:
	if player == null:
		player = current_player
	if player == null or player.current_objective == null:
		return {}
	if input == null:
		input = sentence_builder.get_sentence_input()
	if breakdown == null:
		breakdown = preview_sentence(input, player)
	return player.current_objective.evaluate(input, breakdown, player, context)

func choose_player_archetype(archetype: String) -> void:
	if player1 == null:
		return
	if archetype not in ["attack", "defense", "rhetoric", "balanced"]:
		archetype = "balanced"
	player1.archetype_seal = archetype
	Events.archetype_seal_changed.emit(player1, archetype)

func _offer_objective_for_player(player: Player) -> void:
	if player == null:
		return
	if player.current_objective != null and not player.objective_reward_claimed:
		Events.objective_offered.emit(player, player.current_objective)
		return
	var preferred = player.archetype_seal if not player.archetype_seal.is_empty() else _preferred_archetype(player)
	player.current_objective = BattleObjectiveScript.choose_for_turn(TurnManager.current_turn_number + player.turns_taken, preferred)
	player.objective_reward_claimed = false
	Events.objective_offered.emit(player, player.current_objective)

func _resolve_active_objective(player: Player, input: ScoringEngine.SentenceInput, breakdown: ScoringEngine.ScoreBreakdown, result: CombatResolver.CombatResult) -> void:
	if player == null or player.current_objective == null or player.objective_reward_claimed:
		return
	var state = evaluate_active_objective(player, input, breakdown, {"actual_damage": result.damage_dealt})
	Events.objective_progress_updated.emit(player, player.current_objective, state)
	if not bool(state.get("will_complete", false)):
		return
	var objective = player.current_objective
	player.objective_reward_claimed = true
	player.completed_objective_ids.append(objective.id)
	var reward_text = _apply_objective_reward(objective, player)
	Events.objective_completed.emit(player, objective, reward_text)
	player.current_objective = null

func _apply_objective_reward(objective, player: Player) -> String:
	match objective.reward_type:
		"DRAW":
			for _i in range(max(1, objective.reward_value)):
				_draw(player)
			Events.card_drawn.emit(player)
		"MANA":
			player.mana = min(player.max_mana, player.mana + objective.reward_value)
			Events.player_mana_changed.emit(player, player.mana, player.max_mana)
		"EMPOWER":
			if not _empower_card(player, objective.archetype, objective.reward_value):
				player.add_shield(objective.reward_value * 2)
		"SHIELD":
			player.add_shield(objective.reward_value)
		"HEAL":
			player.heal(objective.reward_value)
	return objective.reward_summary()

func _apply_archetype_seal(breakdown: ScoringEngine.ScoreBreakdown, input: ScoringEngine.SentenceInput, player: Player) -> void:
	if breakdown == null or input == null or player == null:
		return
	match player.archetype_seal:
		"attack":
			if input.components.has(CardData.SentenceComponent.PREDICATE):
				breakdown.atk += 1
			if breakdown.stance_name == "break":
				breakdown.atk += 1
		"defense":
			if input.components.has(CardData.SentenceComponent.SUBJECT) or input.components.has(CardData.SentenceComponent.ATTRIBUTE):
				breakdown.def_ += 1
		"rhetoric":
			if breakdown.constraint_bonus > 0.0:
				breakdown.crt += 2
			if breakdown.rhetoric_flags.size() > 0:
				breakdown.crt += 1
		_:
			pass

func create_event_choices(event_type: String, preferred_archetype: String = "balanced") -> Array:
	var choices: Array = []
	choices.append(BattleEventChoiceScript.make(
		"take_card",
		"event_choice_take_card",
		"event_choice_take_card_desc",
		"ADD_CARD",
		1,
		preferred_archetype
	))
	choices.append(BattleEventChoiceScript.make(
		"empower",
		"event_choice_empower",
		"event_choice_empower_desc",
		"EMPOWER",
		2,
		preferred_archetype
	))
	choices.append(BattleEventChoiceScript.make(
		"refine",
		"event_choice_refine",
		"event_choice_refine_desc",
		"REFINE",
		1,
		preferred_archetype
	))
	if event_type == "curse":
		choices.append(BattleEventChoiceScript.make(
			"cleanse",
			"event_choice_cleanse",
			"event_choice_cleanse_desc",
			"CLEANSE",
			1,
			"defense"
		))
	else:
		choices.append(BattleEventChoiceScript.make(
			"charge",
			"event_choice_charge",
			"event_choice_charge_desc",
			"CHARGE",
			1,
			"rhetoric"
		))
	return choices

func _offer_event_choices(event_type: String, preferred_archetype: String) -> void:
	var choices = create_event_choices(event_type, preferred_archetype)
	if current_player == null or choices.is_empty():
		return
	if current_player.is_ai:
		var ai_choice = await AIController.choose_event_choice(current_player, choices, preferred_archetype)
		Events.event_choice_selected.emit(ai_choice)
		_apply_event_choice(ai_choice, current_player)
		return
	Events.event_choices_offered.emit(choices)
	var selected = await Events.event_choice_selected
	if selected:
		_apply_event_choice(selected, current_player)

func _choose_ai_event_choice(choices: Array, preferred_archetype: String):
	for choice in choices:
		if choice.preferred_archetype == preferred_archetype:
			return choice
	return choices[0]

func _apply_event_choice(choice, player: Player) -> void:
	if choice == null or player == null:
		return
	match choice.effect_type:
		"ADD_CARD":
			var objective_context = {}
			if player.current_objective:
				objective_context = {
					"preferred_archetype": player.current_objective.archetype,
					"reward_type": player.current_objective.reward_type,
				}
			var rewards = CardDatabase.get_reward_choices(max(1, choice.value), choice.preferred_archetype, objective_context)
			for card in rewards:
				player.hand.append(card)
				Events.card_drawn.emit(player)
		"EMPOWER":
			if not _empower_card(player, choice.preferred_archetype, choice.value):
				player.add_shield(choice.value * 2)
		"CLEANSE":
			if not _remove_noise_card(player):
				player.heal(choice.value * 2)
		"CHARGE":
			player.mana = min(player.max_mana, player.mana + choice.value)
			Events.player_mana_changed.emit(player, player.mana, player.max_mana)
		"REFINE":
			if not _remove_low_value_card(player):
				_empower_card(player, choice.preferred_archetype, choice.value)
	Events.event_triggered.emit("event_choice_%s" % choice.id)

func _empower_card(player: Player, preferred_archetype: String, amount: int) -> bool:
	for zone in [player.hand, player.deck.cards]:
		for card in zone:
			if card is CardData and card.card_type == CardData.CardType.FILL:
				if preferred_archetype == "balanced" or CardDatabase._card_matches_archetype(card, preferred_archetype):
					card.base_disorder = min(card.base_disorder + float(amount), 32.0)
					Events.card_added_to_deck.emit(card)
					return true
	return false

func _preferred_archetype(player: Player) -> String:
	if player == null:
		return "balanced"
	if not player.archetype_seal.is_empty() and player.archetype_seal != "balanced":
		return player.archetype_seal
	return TacticalStanceScript.preferred_archetype(player.current_stance)

func _remove_noise_card(player: Player) -> bool:
	for zone in [player.hand, player.deck.cards]:
		for i in range(zone.size()):
			var card = zone[i] as CardData
			if card and (card.id >= 9000 or card.card_name == "Noise"):
				zone.remove_at(i)
				return true
	return false

func _remove_low_value_card(player: Player) -> bool:
	var best_zone = null
	var best_index = -1
	var best_score = INF
	for zone in [player.hand, player.deck.cards]:
		for i in range(zone.size()):
			var card = zone[i] as CardData
			if card == null:
				continue
			if card.id >= 9000 or card.card_name == "Noise":
				continue
			var score = card.base_disorder + float(card.rarity) * 2.0
			if card.card_type != CardData.CardType.FILL:
				score += 8.0
			if score < best_score:
				best_score = score
				best_zone = zone
				best_index = i
	if best_zone != null and best_index >= 0:
		best_zone.remove_at(best_index)
		return true
	return false
