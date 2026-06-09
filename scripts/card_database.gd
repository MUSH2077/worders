extends Node

var fill_cards: Array[CardData] = []
var function_cards: Array[CardData] = []
var equipment_cards: Array[CardData] = []
var status_cards: Array[CardData] = []

const _ALL_CARDS: Array = [
	preload("res://resources/cards/fill_01_noun_subject_animal.tres"),
	preload("res://resources/cards/fill_02_verb_predicate_action.tres"),
	preload("res://resources/cards/fill_03_adj_attr_color.tres"),
	preload("res://resources/cards/fill_04_any_any_any.tres"),
	preload("res://resources/cards/fill_05_adverb_adverbial_emotion.tres"),
	preload("res://resources/cards/fill_06_noun_object_body.tres"),
	preload("res://resources/cards/fill_07_adj_attr_abstract.tres"),
	preload("res://resources/cards/fill_08_noun_subject_space.tres"),
	preload("res://resources/cards/fill_09_adj_attr_time.tres"),
	preload("res://resources/cards/fill_10_noun_subject_artifact.tres"),
	preload("res://resources/cards/fill_11_noun_subject_nature.tres"),
	preload("res://resources/cards/fill_12_verb_predicate_action2.tres"),
	preload("res://resources/cards/fill_13_adj_attr_nature.tres"),
	preload("res://resources/cards/fill_14_adv_adverbial_any.tres"),
	preload("res://resources/cards/fill_15_noun_object_artifact.tres"),
	preload("res://resources/cards/fill_16_noun_object_body.tres"),
	preload("res://resources/cards/fill_17_adj_attr_abstract2.tres"),
	preload("res://resources/cards/fill_18_verb_predicate_any.tres"),
	preload("res://resources/cards/fill_19_adj_attr_space.tres"),
	preload("res://resources/cards/fill_20_noun_subject_space2.tres"),
	preload("res://resources/cards/fill_21_verb_predicate_emotion.tres"),
	preload("res://resources/cards/fill_22_noun_object_nature.tres"),
	preload("res://resources/cards/fill_23_adj_attr_animal.tres"),
	preload("res://resources/cards/fill_24_adv_adverbial_time.tres"),
	preload("res://resources/cards/fill_25_verb_complement_action.tres"),
	preload("res://resources/cards/fill_26_noun_subject_emotion.tres"),
	preload("res://resources/cards/fill_27_adj_attr_any.tres"),
	preload("res://resources/cards/fill_28_noun_object_any.tres"),
	preload("res://resources/cards/fill_29_any_predicate_action.tres"),
	preload("res://resources/cards/fill_30_any_adverbial_any.tres"),
	preload("res://resources/cards/function_101_quick_draw.tres"),
	preload("res://resources/cards/function_102_mana_spark.tres"),
	preload("res://resources/cards/function_103_cleanse.tres"),
	preload("res://resources/cards/function_104_steal.tres"),
	preload("res://resources/cards/function_105_seal.tres"),
	preload("res://resources/cards/function_106_echo.tres"),
	preload("res://resources/cards/function_107_razor_word.tres"),
	preload("res://resources/cards/function_108_deep_draft.tres"),
	preload("res://resources/cards/equipment_201_guard_rune.tres"),
	preload("res://resources/cards/equipment_202_healing_charm.tres"),
	preload("res://resources/cards/equipment_203_focus_lens.tres"),
	preload("res://resources/cards/equipment_204_bastion_ink.tres"),
	preload("res://resources/cards/equipment_205_verdant_seal.tres"),
	preload("res://resources/cards/status_301_weak_hex.tres"),
	preload("res://resources/cards/status_302_haste.tres"),
	preload("res://resources/cards/status_303_ward.tres"),
	preload("res://resources/cards/status_304_overcharge.tres"),
	preload("res://resources/cards/status_305_bleed_mark.tres"),
]

func _ready() -> void:
	_load_all_cards()

func _load_all_cards() -> void:
	for card in _ALL_CARDS:
		if card == null:
			continue
		match card.card_type:
			CardData.CardType.FILL:
				fill_cards.append(card)
			CardData.CardType.FUNCTION:
				function_cards.append(card)
			CardData.CardType.EQUIPMENT:
				equipment_cards.append(card)
			CardData.CardType.STATUS:
				status_cards.append(card)

func duplicate_card(card: CardData) -> CardData:
	return card.duplicate(true) if card else null

func get_random_fill_card() -> CardData:
	if fill_cards.is_empty():
		return null
	return duplicate_card(fill_cards[randi() % fill_cards.size()])

func get_random_function_card() -> CardData:
	if function_cards.is_empty():
		return null
	return duplicate_card(function_cards[randi() % function_cards.size()])

func get_random_equipment_card() -> CardData:
	if equipment_cards.is_empty():
		return null
	return duplicate_card(equipment_cards[randi() % equipment_cards.size()])

func get_random_status_card() -> CardData:
	if status_cards.is_empty():
		return null
	return duplicate_card(status_cards[randi() % status_cards.size()])

func get_random_card_by_type(card_type: int, rarity_weights: Dictionary = {}) -> CardData:
	var pool = _pool_for_type(card_type)
	if pool.is_empty():
		return null
	return duplicate_card(_weighted_pick(pool, rarity_weights))

func get_reward_choices(count: int, preferred_archetype: String = "balanced", objective_context: Dictionary = {}) -> Array[CardData]:
	var pool = fill_cards + function_cards + equipment_cards + status_cards
	var effective_archetype = str(objective_context.get("preferred_archetype", preferred_archetype))
	var preferred: Array[CardData] = []
	var objective_preferred: Array[CardData] = []
	for card in pool:
		if _card_matches_archetype(card, effective_archetype):
			preferred.append(card)
		if _card_matches_objective(card, objective_context):
			objective_preferred.append(card)
	var combined = objective_preferred + preferred + pool
	combined.shuffle()
	var result: Array[CardData] = []
	var used_ids: Dictionary = {}
	for card in combined:
		if card == null or used_ids.has(card.id):
			continue
		result.append(duplicate_card(card))
		used_ids[card.id] = true
		if result.size() >= count:
			break
	return result

func _card_matches_objective(card: CardData, objective_context: Dictionary) -> bool:
	if objective_context.is_empty() or card == null:
		return false
	var reward_type = str(objective_context.get("reward_type", ""))
	match reward_type:
		"DRAW":
			return card.effect == CardData.CardEffect.DRAW or card.card_type == CardData.CardType.FILL
		"MANA":
			return card.effect == CardData.CardEffect.MANA or card.comp_constraint == CardData.SentenceComponent.ADVERBIAL
		"EMPOWER":
			return card.comp_constraint in ScoringEngine.ATK_COMPS
		"SHIELD", "HEAL":
			return card.comp_constraint in ScoringEngine.DEF_COMPS or card.effect in [CardData.CardEffect.SHIELD, CardData.CardEffect.HEAL]
	return false

func get_random_starter_card() -> CardData:
	var roll = randi() % 10
	if roll < 6:
		return get_random_fill_card()
	if roll < 8:
		return get_random_function_card()
	if roll == 8:
		return get_random_equipment_card()
	return get_random_status_card()

func get_random_cards(count: int) -> Array[CardData]:
	var pool = fill_cards + function_cards + equipment_cards + status_cards
	pool.shuffle()
	var result: Array[CardData] = []
	for i in range(min(count, pool.size())):
		result.append(duplicate_card(pool[i]))
	return result

func _pool_for_type(card_type: int) -> Array[CardData]:
	match card_type:
		CardData.CardType.FILL:
			return fill_cards
		CardData.CardType.FUNCTION:
			return function_cards
		CardData.CardType.EQUIPMENT:
			return equipment_cards
		CardData.CardType.STATUS:
			return status_cards
	return []

func _weighted_pick(pool: Array[CardData], rarity_weights: Dictionary) -> CardData:
	if rarity_weights.is_empty():
		return pool[randi() % pool.size()]
	var total = 0.0
	for card in pool:
		total += float(rarity_weights.get(card.rarity, 1.0))
	var roll = randf() * max(total, 0.001)
	var acc = 0.0
	for card in pool:
		acc += float(rarity_weights.get(card.rarity, 1.0))
		if roll <= acc:
			return card
	return pool.back()

func _card_matches_archetype(card: CardData, archetype: String) -> bool:
	match archetype:
		"attack":
			return card.comp_constraint in ScoringEngine.ATK_COMPS or card.effect in [
				CardData.CardEffect.WEAKEN,
				CardData.CardEffect.STEAL,
				CardData.CardEffect.SEAL,
			]
		"defense":
			return card.comp_constraint in ScoringEngine.DEF_COMPS or card.effect in [
				CardData.CardEffect.SHIELD,
				CardData.CardEffect.HEAL,
				CardData.CardEffect.CLEANSE,
			]
		"rhetoric":
			return card.comp_constraint in ScoringEngine.CRT_COMPS or card.effect in [
				CardData.CardEffect.ECHO,
				CardData.CardEffect.DRAW,
				CardData.CardEffect.MANA,
			]
	return true
