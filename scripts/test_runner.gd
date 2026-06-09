extends Node

var passed = 0
var failed = 0
var failures: Array[String] = []
var intro_visual_regression_script = preload("res://scripts/intro_visual_regression.gd")
var battle_debug_panel_script = preload("res://scripts/battle_debug_panel.gd")
var battle_codex_panel_script = preload("res://scripts/battle_codex_panel.gd")
var battle_fx_director_script = preload("res://scripts/battle_fx_director.gd")
var ui_layout_audit_script = preload("res://scripts/ui_layout_audit.gd")
var fx_smoke_audit_script = preload("res://scripts/fx_smoke_audit.gd")
var ui_theme_script = preload("res://scripts/ui_theme.gd")
var ui_motion_script = preload("res://scripts/ui_motion.gd")
var hand_fan_layout_script = preload("res://scripts/hand_fan_layout.gd")
var role_meter_script = preload("res://scripts/role_meter.gd")
var battle_objective_script = preload("res://scripts/battle_objective.gd")
var ai_profile_script = preload("res://scripts/ai_profile.gd")
var card_scene = preload("res://scenes/card.tscn")

func _ready() -> void:
	print("=".repeat(40))
	print("Running Core Logic Tests")
	print("=".repeat(40))

	test_structure_validator()
	test_rhyme_detector()
	test_scoring_engine()
	test_constraint_scoring()
	test_judgment_pipeline()
	await test_judgment_llm_contract()
	test_skill_registry_contract()
	test_tactical_stance_system()
	test_combat_crit_cap()
	test_sentence_builder()
	test_resource_services()
	test_embedding_service_contract()
	test_reward_choice_services()
	test_battle_objective_system()
	test_battle_event_choices()
	test_battle_event_choice_effects()
	test_ai_intent_signal_contract()
	test_ai_turn_planning()
	await test_ai_llm_transcript_execution()
	await test_ai_llm_event_choice()
	test_llm_client_contract()
	test_settings_deepseek_ui_contract()
	test_audio_director_contract()
	test_worders_title_contract()
	test_intro_visual_regression()
	test_ui_theme_assets_and_motion_contract()
	test_battle_ui_i18n_keys()
	test_hand_fan_layout_contract()
	await test_card_drag_visual_contract()
	test_role_meter_contract()
	test_ui_layout_audit_contract()
	test_fx_smoke_contract()
	test_battle_recorder_seed_and_replay()
	test_support_panels_contract()
	await test_battle_ui_chat_pruning()

	print("\n" + "=".repeat(40))
	print("RESULTS: %d passed, %d failed" % [passed, failed])
	if failures.size() > 0:
		print("FAILURES:")
		for f in failures:
			print("  - " + f)
	print("=".repeat(40))

func assert_eq(actual, expected, test_name: String) -> void:
	if actual == expected:
		passed += 1
		print("  PASS: " + test_name)
	else:
		failed += 1
		var msg = "%s: expected %s, got %s" % [test_name, str(expected), str(actual)]
		failures.append(msg)
		print("  FAIL: " + msg)

func assert_true(condition: bool, test_name: String) -> void:
	assert_eq(condition, true, test_name)

func assert_gt(actual, threshold, test_name: String) -> void:
	if actual > threshold:
		passed += 1
		print("  PASS: " + test_name)
	else:
		failed += 1
		var msg = "%s: expected > %s, got %s" % [test_name, str(threshold), str(actual)]
		failures.append(msg)
		print("  FAIL: " + msg)

func assert_almost(actual, expected: float, test_name: String, epsilon: float = 0.001) -> void:
	if actual is float or actual is int:
		if abs(float(actual) - expected) <= epsilon:
			passed += 1
			print("  PASS: " + test_name)
			return
		failed += 1
		var msg = "%s: expected %.3f, got %.3f" % [test_name, expected, float(actual)]
		failures.append(msg)
		print("  FAIL: " + msg)
		return
	failed += 1
	var type_msg = "%s: expected %.3f, got %s" % [test_name, expected, str(actual)]
	failures.append(type_msg)
	print("  FAIL: " + type_msg)

func test_structure_validator() -> void:
	print("\n--- StructureValidator ---")
	var sv = StructureValidator
	var r = sv.validate([CardData.SentenceComponent.SUBJECT, CardData.SentenceComponent.PREDICATE])
	assert_eq(r.penalty_percent, 0.0, "complete subject/predicate has no penalty")

	r = sv.validate([CardData.SentenceComponent.SUBJECT])
	assert_eq(r.penalty_percent, 0.20, "missing predicate penalty")

	r = sv.validate([CardData.SentenceComponent.PREDICATE])
	assert_eq(r.penalty_percent, 0.20, "missing subject penalty")

	r = sv.validate([CardData.SentenceComponent.OBJECT])
	assert_eq(r.penalty_percent, 0.20, "missing subject and predicate is one structure penalty")

	r = sv.validate([
		CardData.SentenceComponent.SUBJECT,
		CardData.SentenceComponent.SUBJECT,
		CardData.SentenceComponent.PREDICATE,
	])
	assert_eq(r.penalty_percent, 0.15, "repeated subject penalty")

	r = sv.validate([
		CardData.SentenceComponent.PREDICATE,
		CardData.SentenceComponent.PREDICATE,
	])
	assert_eq(r.penalty_percent, 0.35, "repeated predicate plus missing subject penalty")

func test_rhyme_detector() -> void:
	print("\n--- RhymeDetector ---")
	var rd = RhymeDetector

	assert_true(rd.detect_parallelism([
		CardData.SentenceComponent.ATTRIBUTE,
		CardData.SentenceComponent.ATTRIBUTE,
		CardData.SentenceComponent.ATTRIBUTE,
	]), "parallelism requires three repeated components")

	assert_true(not rd.detect_parallelism([
		CardData.SentenceComponent.ATTRIBUTE,
		CardData.SentenceComponent.ATTRIBUTE,
	]), "two repeated components are not parallelism")

	assert_true(rd.detect_antithesis([
		CardData.SentenceComponent.ATTRIBUTE,
		CardData.SentenceComponent.SUBJECT,
		CardData.SentenceComponent.SUBJECT,
		CardData.SentenceComponent.ATTRIBUTE,
	]), "mirrored components create antithesis")

	assert_true(not rd.detect_antithesis([
		CardData.SentenceComponent.ATTRIBUTE,
		CardData.SentenceComponent.SUBJECT,
	]), "short component lists are not antithesis")

	var rhyme_map = {"a": {"rhyme": "a"}, "b": {"rhyme": "a"}, "c": {"rhyme": "c"}}
	assert_true(rd.detect_rhyme(["a", "b"], rhyme_map), "matching rhyme groups rhyme")
	assert_true(not rd.detect_rhyme(["a", "c"], rhyme_map), "different rhyme groups do not rhyme")
	assert_eq(rd._last_char("cat"), "t", "last character helper")

func test_scoring_engine() -> void:
	print("\n--- ScoringEngine ---")
	var se = ScoringEngine
	var input = ScoringEngine.SentenceInput.new()
	var r = se.calculate(input, {})
	assert_eq(r.atk, 0, "empty sentence has no attack")

	var c_subj = _card(25, CardData.SentenceComponent.SUBJECT)
	var c_pred = _card(25, CardData.SentenceComponent.PREDICATE)
	var c_obj = _card(20, CardData.SentenceComponent.OBJECT)
	var c_attr = _card(10, CardData.SentenceComponent.ATTRIBUTE)
	var c_adv = _card(10, CardData.SentenceComponent.ADVERBIAL)

	input = _inp([c_subj, c_pred], ["a", "b"], [
		CardData.SentenceComponent.SUBJECT,
		CardData.SentenceComponent.PREDICATE,
	])
	r = se.calculate(input, {})
	assert_eq(r.combo_mult, 1.0, "two-card combo")
	assert_gt(r.atk, 0, "predicate contributes attack")
	assert_gt(r.def_, 0, "subject contributes defense")
	assert_eq(r.total_disorder, 25.0, "average disorder for matching cards")

	input = _inp([c_subj, c_pred, c_obj], ["a", "b", "c"], [
		CardData.SentenceComponent.SUBJECT,
		CardData.SentenceComponent.PREDICATE,
		CardData.SentenceComponent.OBJECT,
	])
	r = se.calculate(input, {})
	assert_eq(r.combo_mult, 1.2, "three-card combo")

	input = _inp([c_attr, c_attr, c_subj, c_adv, c_pred], ["a", "b", "c", "d", "e"], [
		CardData.SentenceComponent.ATTRIBUTE,
		CardData.SentenceComponent.ATTRIBUTE,
		CardData.SentenceComponent.SUBJECT,
		CardData.SentenceComponent.ADVERBIAL,
		CardData.SentenceComponent.PREDICATE,
	])
	r = se.calculate(input, {})
	assert_eq(r.combo_mult, 1.6, "five-card combo")
	assert_gt(r.crt, 0, "adverbial contributes crit")

	input = _inp([c_pred], ["a"], [CardData.SentenceComponent.PREDICATE])
	r = se.calculate(input, {})
	assert_eq(r.penalty_percent, 0.20, "missing subject penalty in scoring")

	input = _inp([c_attr, c_attr, c_attr, c_subj, c_pred], ["a", "b", "c", "d", "e"], [
		CardData.SentenceComponent.ATTRIBUTE,
		CardData.SentenceComponent.ATTRIBUTE,
		CardData.SentenceComponent.ATTRIBUTE,
		CardData.SentenceComponent.SUBJECT,
		CardData.SentenceComponent.PREDICATE,
	])
	r = se.calculate(input, {})
	assert_eq(r.rhetoric_mult, 1.3, "parallelism rhetoric multiplier")

	var c_animal = _card(25, CardData.SentenceComponent.SUBJECT)
	c_animal.content_constraint = CardData.ContentCategory.ANIMAL
	var c_animal2 = _card(25, CardData.SentenceComponent.PREDICATE)
	c_animal2.content_constraint = CardData.ContentCategory.ANIMAL
	input = _inp([c_animal, c_animal2], ["a", "b"], [
		CardData.SentenceComponent.SUBJECT,
		CardData.SentenceComponent.PREDICATE,
	])
	r = se.calculate(input, {})
	assert_eq(r.semantic_bonus, 0.0, "same content category has no mismatch bonus")

	var c_artifact = _card(25, CardData.SentenceComponent.OBJECT)
	c_artifact.content_constraint = CardData.ContentCategory.ARTIFACT
	input = _inp([c_animal, c_artifact], ["a", "b"], [
		CardData.SentenceComponent.SUBJECT,
		CardData.SentenceComponent.OBJECT,
	])
	r = se.calculate(input, {})
	assert_true(r.semantic_bonus > 0, "different content categories create semantic bonus")
	assert_true(r.total_disorder > r.base_disorder, "semantic bonus raises total disorder")

	input = _inp([c_animal, c_animal2, c_artifact], ["a", "b", "c"], [
		CardData.SentenceComponent.SUBJECT,
		CardData.SentenceComponent.PREDICATE,
		CardData.SentenceComponent.OBJECT,
	])
	r = se.calculate(input, {})
	assert_gt(r.semantic_bonus, 0, "mixed categories create semantic bonus")

	var cards: Array[CardData] = []
	var words: Array[String] = []
	var comps = []
	for i in range(8):
		cards.append(_card(10, CardData.SentenceComponent.ATTRIBUTE))
		words.append("x")
		comps.append(CardData.SentenceComponent.ATTRIBUTE)
	cards.append(c_subj)
	words.append("a")
	comps.append(CardData.SentenceComponent.SUBJECT)
	cards.append(c_pred)
	words.append("b")
	comps.append(CardData.SentenceComponent.PREDICATE)
	input = _inp(cards, words, comps)
	r = se.calculate(input, {})
	assert_eq(r.combo_mult, 2.0, "combo multiplier cap")

	var d_subj = _card(25, CardData.SentenceComponent.SUBJECT)
	d_subj.pos_constraint = CardData.PartOfSpeech.NOUN
	d_subj.content_constraint = CardData.ContentCategory.ANIMAL
	var d_pred = _card(25, CardData.SentenceComponent.PREDICATE)
	input = _inp([d_subj, d_pred], ["龙", "狐狸"], [
		CardData.SentenceComponent.SUBJECT,
		CardData.SentenceComponent.PREDICATE,
	])
	var deltas = se.compute_slot_deltas(input, {}, TacticalStance.Stance.BALANCED)
	assert_eq(deltas.size(), 2, "slot deltas align with sentence length")
	assert_true(deltas[0].has("atk") and deltas[0].has("def") and deltas[0].has("crt"), "slot delta exposes stat keys")
	# Clearing the constrained subject word drops its match bonus, lowering total
	# score, so its marginal contribution is positive on the defense column.
	assert_gt(int(deltas[0].get("def", 0)), 0, "constrained subject word contributes defense")

func test_judgment_pipeline() -> void:
	print("\n--- Judgment Pipeline ---")
	assert_eq(WordBank.resolve_alias("龍"), "龙", "alias resolves to canonical")
	assert_true(WordBank.find_entries("龍").size() > 0, "alias lookup finds canonical entry")
	var c_subj = _card(20, CardData.SentenceComponent.SUBJECT)
	c_subj.pos_constraint = CardData.PartOfSpeech.NOUN
	c_subj.content_constraint = CardData.ContentCategory.ANIMAL
	var c_pred = _card(20, CardData.SentenceComponent.PREDICATE)
	c_pred.pos_constraint = CardData.PartOfSpeech.VERB
	var input = _inp([c_subj, c_pred], ["龙", "zzqxk"], [
		CardData.SentenceComponent.SUBJECT,
		CardData.SentenceComponent.PREDICATE,
	])
	var base = ScoringEngine.calculate(input, {})
	assert_eq(base.judgment_trace.size(), 2, "trace has one entry per slot")
	assert_eq(base.judgment_trace[0]["source"], "word_bank", "known word source is word_bank")
	assert_eq(base.judgment_trace[1]["source"], "unknown", "made-up word source is unknown")
	var overrides = {"zzqxk": {"matched": true, "pos": "VERB", "category": "ANY", "confidence": 0.9}}
	var judged = ScoringEngine.calculate_with_judgment(input, {}, TacticalStance.Stance.BALANCED, overrides)
	assert_gt(judged.constraint_bonus, base.constraint_bonus, "DS override match adds constraint bonus")
	assert_eq(judged.judgment_trace[1]["source"], "deepseek", "override marks slot source deepseek")

func test_judgment_llm_contract() -> void:
	print("\n--- Judgment LLM ---")
	var unique = "测试词%d" % Time.get_ticks_usec()
	LLMClient.mock_word_judgment_response = {"judgments": [{
		"index": 0, "word": unique, "matched": true,
		"inferred_pos": "NOUN", "inferred_category": "ANIMAL", "confidence": 0.8,
	}]}
	var items = [{"index": 0, "word": unique, "expected_pos": "NOUN", "expected_category": "ANIMAL"}]
	var res = await LLMClient.request_word_judgment(items, "zh")
	LLMClient.mock_word_judgment_response = {}
	assert_true(res.get("ok", false), "mock judgment returns ok")
	var js = res.get("judgments", [])
	assert_eq(js.size(), 1, "one judgment returned")
	assert_eq(js[0].get("inferred_pos", ""), "NOUN", "inferred pos preserved and validated")
	assert_true(bool(js[0].get("matched", false)), "high-confidence match accepted")

func test_skill_registry_contract() -> void:
	print("\n--- Skill Registry ---")
	assert_true(BattleSkillRegistry.is_skill_command("/suggest"), "recognizes /suggest")
	assert_true(BattleSkillRegistry.is_skill_command("/fill 0 龙"), "recognizes /fill")
	assert_eq(BattleSkillRegistry.is_skill_command("hello"), false, "plain text not a command")
	assert_eq(BattleSkillRegistry.is_skill_command("/worders x"), false, "worders handled separately")
	var parsed = BattleSkillRegistry.parse("/fill 2 苍狼")
	assert_eq(parsed["command"], "fill", "parse command")
	assert_eq(parsed["args"].size(), 2, "parse args count")
	var help = BattleSkillRegistry.execute("help", [])
	assert_true(help.ok, "help command succeeds")
	var mapped = LLMClient.ally_tool_to_command("fill_slot", {"slot_index": 1, "word": "龙"})
	assert_eq(mapped["command"], "fill", "ally tool maps to fill command")
	assert_eq(mapped["args"].size(), 2, "ally fill mapping carries slot and word")

func _card(disorder: float, comp: int) -> CardData:
	var c = CardData.new()
	c.base_disorder = disorder
	c.comp_constraint = comp
	c.pos_constraint = CardData.PartOfSpeech.ANY
	c.content_constraint = CardData.ContentCategory.ANY
	c.card_name = "Test"
	return c

func _inp(cards: Array[CardData], words: Array[String], comps: Array) -> ScoringEngine.SentenceInput:
	var input = ScoringEngine.SentenceInput.new()
	input.cards = cards
	input.words = words
	input.components = comps
	return input

func test_constraint_scoring() -> void:
	print("\n--- Constraint Scoring ---")
	assert_true(WordBank.has_method("find_entries"), "word bank exposes text lookup")

	var animal_subject = _card(25, CardData.SentenceComponent.SUBJECT)
	animal_subject.pos_constraint = CardData.PartOfSpeech.NOUN
	animal_subject.content_constraint = CardData.ContentCategory.ANIMAL
	var animal_pred = _card(25, CardData.SentenceComponent.PREDICATE)
	animal_pred.pos_constraint = CardData.PartOfSpeech.NOUN
	animal_pred.content_constraint = CardData.ContentCategory.ANIMAL

	var input = _inp([animal_subject, animal_pred], ["龙", "狐狸"], [
		CardData.SentenceComponent.SUBJECT,
		CardData.SentenceComponent.PREDICATE,
	])
	var r = ScoringEngine.calculate(input, {})
	assert_almost(r.get("constraint_bonus"), 4.0, "matching known words add constraint bonus")
	assert_almost(r.get("constraint_penalty_percent"), 0.0, "matching known words have no constraint penalty")
	assert_gt(r.embedding_bonus, 0.0, "matching known words add embedding bonus")
	assert_almost(r.total_disorder, r.base_disorder + r.constraint_bonus + r.embedding_bonus + r.semantic_bonus, "constraint and embedding bonuses raise total disorder")

	input = _inp([animal_subject, animal_pred], ["龙", "冰箱"], [
		CardData.SentenceComponent.SUBJECT,
		CardData.SentenceComponent.PREDICATE,
	])
	r = ScoringEngine.calculate(input, {})
	assert_almost(r.get("constraint_penalty_percent"), 0.08, "known mismatched word adds soft penalty")
	assert_true(r.get("constraint_flags") is Array and r.get("constraint_flags").size() > 0, "mismatched word records constraint flag")

	input = _inp([animal_subject, animal_pred], ["自造词", "狐狸"], [
		CardData.SentenceComponent.SUBJECT,
		CardData.SentenceComponent.PREDICATE,
	])
	r = ScoringEngine.calculate(input, {})
	assert_almost(r.get("constraint_penalty_percent"), 0.0, "unknown word is unverified but not penalized")
	assert_almost(r.get("constraint_bonus"), 2.0, "unknown word receives no constraint bonus")

	input = _inp([animal_subject], ["冰箱"], [CardData.SentenceComponent.SUBJECT])
	r = ScoringEngine.calculate(input, {})
	assert_almost(r.get("structure_penalty_percent"), 0.20, "structure penalty remains separate")
	assert_almost(r.get("constraint_penalty_percent"), 0.08, "constraint penalty remains separate")
	assert_almost(r.penalty_percent, 0.28, "structure and constraint penalties stack")

func test_tactical_stance_system() -> void:
	print("\n--- Tactical Stance ---")
	assert_true(Events.has_signal("stance_changed"), "stance change signal is available")
	assert_true(Events.has_signal("ai_stance_declared"), "AI stance signal is available")
	var p = Player.new()
	assert_true(p.get("current_stance") != null, "player exposes current stance")
	var empty_breakdown = ScoringEngine.ScoreBreakdown.new()
	assert_true(empty_breakdown.get("stance_name") != null, "score breakdown exposes stance name")
	assert_true(empty_breakdown.get("stance_modifiers") is Dictionary, "score breakdown exposes stance modifiers")
	var se_instance = ScoringEngine.new()
	assert_true(se_instance.has_method("calculate_with_stance"), "scoring supports explicit stance")
	if not se_instance.has_method("calculate_with_stance"):
		return
	var c_subj = _card(25, CardData.SentenceComponent.SUBJECT)
	var c_pred = _card(25, CardData.SentenceComponent.PREDICATE)
	c_subj.pos_constraint = CardData.PartOfSpeech.NOUN
	c_pred.pos_constraint = CardData.PartOfSpeech.NOUN
	c_subj.content_constraint = CardData.ContentCategory.ANIMAL
	c_pred.content_constraint = CardData.ContentCategory.ANIMAL
	var input = _inp([c_subj, c_pred], ["龙", "狐狸"], [
		CardData.SentenceComponent.SUBJECT,
		CardData.SentenceComponent.PREDICATE,
	])
	var balanced = se_instance.call("calculate_with_stance", input, {}, 0)
	var break_stance = se_instance.call("calculate_with_stance", input, {}, 1)
	var guard_stance = se_instance.call("calculate_with_stance", input, {}, 2)
	var harmony = se_instance.call("calculate_with_stance", input, {}, 3)
	assert_eq(balanced.stance_name, "balanced", "balanced stance is named")
	assert_gt(break_stance.atk, balanced.atk, "break stance raises attack")
	assert_true(break_stance.def_ < balanced.def_, "break stance lowers defense")
	assert_gt(guard_stance.def_, balanced.def_, "guard stance raises defense")
	assert_true(guard_stance.atk < balanced.atk, "guard stance lowers attack")
	assert_gt(harmony.constraint_bonus, balanced.constraint_bonus, "harmony stance raises constraint bonus")

	input = _inp([c_subj, c_pred], ["龙", "冰箱"], [
		CardData.SentenceComponent.SUBJECT,
		CardData.SentenceComponent.PREDICATE,
	])
	var mismatch_balanced = se_instance.call("calculate_with_stance", input, {}, 0)
	var mismatch_harmony = se_instance.call("calculate_with_stance", input, {}, 3)
	assert_true(mismatch_harmony.constraint_penalty_percent < mismatch_balanced.constraint_penalty_percent, "harmony stance lowers constraint penalty")

func test_combat_crit_cap() -> void:
	print("\n--- Combat Balance ---")
	var cr_instance = CombatResolver.new()
	assert_true(cr_instance.has_method("crit_chance_for_breakdown"), "combat exposes crit chance helper")
	var result = CombatResolver.CombatResult.new()
	assert_true(result.get("crit_chance") != null, "combat result exposes crit chance")
	if not cr_instance.has_method("crit_chance_for_breakdown"):
		return
	var b = ScoringEngine.ScoreBreakdown.new()
	b.crt = 999
	assert_almost(cr_instance.call("crit_chance_for_breakdown", b), 0.65, "crit chance is capped at 65 percent")

func test_sentence_builder() -> void:
	print("\n--- SentenceBuilder ---")
	var b = SentenceBuilder.new()
	var c_pred = _card(25, CardData.SentenceComponent.PREDICATE)
	var c_attr = _card(10, CardData.SentenceComponent.ATTRIBUTE)
	var c_subj = _card(25, CardData.SentenceComponent.SUBJECT)

	var s_pred = b.add_card(c_pred)
	var s_attr = b.add_card(c_attr)
	var s_subj = b.add_card(c_subj)
	assert_eq(b.slots[0], s_attr, "new cards sort by component: attribute first")
	assert_eq(b.slots[1], s_subj, "new cards sort by component: subject second")
	assert_eq(b.slots[2], s_pred, "new cards sort by component: predicate third")

	b.move_slot(s_pred, 0)
	assert_eq(b.slots[0], s_pred, "manual move can put predicate first")
	var input = b.get_sentence_input()
	assert_eq(input.components[0], CardData.SentenceComponent.PREDICATE, "scoring input preserves manual order")

	b.set_word(b.get_slot_index(s_pred), "roar")
	assert_eq(b.slots[0].word, "roar", "word setting follows current slot index")
	b.set_word(b.get_slot_index(s_attr), "ancient")
	b.set_word(b.get_slot_index(s_subj), "dragon")
	assert_eq(b.get_total_mana_cost(), 3, "mana cost uses card costs, not word length")

func test_resource_services() -> void:
	print("\n--- Resource Services ---")
	var a = CardDatabase.get_random_fill_card()
	var b = CardDatabase.get_random_fill_card()
	assert_true(a != null, "card database returns fill cards")
	assert_true(b != null, "card database can return another fill card")
	assert_true(a != b, "card database returns duplicated card instances")
	assert_gt(WordBank.get_all_words().size(), 40, "word bank loads a diverse entry set")
	assert_true(WordBank.has_method("sample_by_constraints"), "word bank exposes randomized sampling")
	var rng = RandomNumberGenerator.new()
	rng.seed = 42
	var sampled = WordBank.sample_by_constraints("NOUN", "EMOTION", 3, rng)
	assert_true(sampled.size() >= 1, "word bank samples noun emotion entries")
	assert_true(WordBank.constraint_coverage("VERB", "EMOTION") >= 1, "word bank covers verb emotion cards")
	for card in CardDatabase.fill_cards:
		var count = card.get_constraint_count()
		if count == 0:
			assert_true(card.base_disorder >= 12.0 and card.base_disorder <= 16.0, "any fill card disorder is in range")
		elif count == 1:
			assert_true(card.base_disorder >= 18.0 and card.base_disorder <= 22.0, "single-constraint fill card disorder is in range")
		elif count == 2:
			assert_true(card.base_disorder >= 22.0 and card.base_disorder <= 26.0, "two-constraint fill card disorder is in range")
		else:
			assert_true(card.base_disorder >= 26.0 and card.base_disorder <= 32.0, "three-constraint fill card disorder is in range")

func test_embedding_service_contract() -> void:
	print("\n--- Embedding Service ---")
	assert_true(ResourceLoader.exists("res://scripts/embedding_service.gd"), "embedding service script exists")
	assert_true(ResourceLoader.exists("res://resources/embedding_vectors.json"), "embedding vector resource exists")
	assert_eq(ProjectSettings.get_setting("autoload/EmbeddingService", ""), "*res://scripts/embedding_service.gd", "embedding service is registered as autoload")
	var embedding_service = get_node_or_null("/root/EmbeddingService")
	assert_true(embedding_service != null, "embedding service autoload is available")
	if embedding_service == null:
		return
	assert_true(embedding_service.has_method("similarity"), "embedding service exposes similarity")
	assert_true(embedding_service.has_method("get_vector"), "embedding service exposes vectors")
	assert_true(embedding_service.has_method("load_model"), "embedding service loads vector models")
	embedding_service.load_model()
	var related = embedding_service.similarity("dragon", "beast")
	var distant = embedding_service.similarity("dragon", "sword")
	assert_true(related > distant, "embedding similarity ranks related words higher")
	assert_true(embedding_service.get_vector("dragon").size() > 0, "embedding service returns known vector")
	var c_a = _card(22, CardData.SentenceComponent.SUBJECT)
	var c_b = _card(22, CardData.SentenceComponent.PREDICATE)
	var related_input = _inp([c_a, c_b], ["dragon", "beast"], [
		CardData.SentenceComponent.SUBJECT,
		CardData.SentenceComponent.PREDICATE,
	])
	var distant_input = _inp([c_a, c_b], ["dragon", "sword"], [
		CardData.SentenceComponent.SUBJECT,
		CardData.SentenceComponent.PREDICATE,
	])
	var related_score = ScoringEngine.calculate(related_input, {})
	var distant_score = ScoringEngine.calculate(distant_input, {})
	assert_gt(related_score.embedding_bonus, 0.0, "related words add embedding bonus")
	assert_true(related_score.embedding_similarity > distant_score.embedding_similarity, "scoring stores embedding similarity")

func test_reward_choice_services() -> void:
	print("\n--- Reward Choices ---")
	assert_true(CardDatabase.has_method("get_random_card_by_type"), "card database returns cards by type")
	assert_true(CardDatabase.has_method("get_reward_choices"), "card database returns archetype reward choices")
	if not CardDatabase.has_method("get_reward_choices"):
		return
	var choices = CardDatabase.get_reward_choices(3, "attack")
	assert_eq(choices.size(), 3, "reward choices return requested count")
	for card in choices:
		assert_true(card != null, "reward choice is not null")
	var objective_choices = CardDatabase.get_reward_choices(3, "balanced", {"preferred_archetype": "defense", "reward_type": "SHIELD"})
	assert_eq(objective_choices.size(), 3, "reward choices accept objective context")
	var objective_weight_seen = false
	for card in objective_choices:
		objective_weight_seen = objective_weight_seen or card.comp_constraint in ScoringEngine.DEF_COMPS or card.effect in [CardData.CardEffect.SHIELD, CardData.CardEffect.HEAL]
	assert_true(objective_weight_seen, "objective context biases at least one reward toward the objective")

func test_battle_objective_system() -> void:
	print("\n--- Battle Objectives ---")
	assert_true(ResourceLoader.exists("res://scripts/battle_objective.gd"), "battle objective script exists")
	assert_true(Events.has_signal("objective_offered"), "objective offered signal is available")
	assert_true(Events.has_signal("objective_progress_updated"), "objective progress signal is available")
	assert_true(Events.has_signal("objective_completed"), "objective completed signal is available")
	assert_true(BattleManager.has_method("preview_sentence"), "battle manager previews sentence with seals")
	assert_true(BattleManager.has_method("evaluate_active_objective"), "battle manager evaluates active objective")
	var p = Player.new()
	p.deck = Deck.new()
	p.max_mana = 3
	p.mana = 1
	p.archetype_seal = "attack"
	p.deck.add_card(_card(18, CardData.SentenceComponent.SUBJECT))
	var subj = _card(22, CardData.SentenceComponent.SUBJECT)
	var pred = _card(22, CardData.SentenceComponent.PREDICATE)
	var obj = _card(22, CardData.SentenceComponent.OBJECT)
	var input = _inp([subj, pred, obj], ["dragon", "roar", "sword"], [
		CardData.SentenceComponent.SUBJECT,
		CardData.SentenceComponent.PREDICATE,
		CardData.SentenceComponent.OBJECT,
	])
	var objective = battle_objective_script.make("test_orderly", "objective_orderly_name", "objective_orderly_desc", "balanced", "SUBJECT_PREDICATE_OBJECT", "DRAW", 1, 1)
	p.current_objective = objective
	var breakdown = BattleManager.preview_sentence(input, p)
	var state = BattleManager.evaluate_active_objective(p, input, breakdown)
	assert_true(state.will_complete, "orderly sentence objective detects completion")
	var hand_before = p.hand.size()
	var result = CombatResolver.CombatResult.new()
	BattleManager._resolve_active_objective(p, input, breakdown, result)
	assert_true(p.objective_reward_claimed, "objective reward is marked claimed")
	assert_gt(p.hand.size(), hand_before, "objective draw reward adds a card")
	var hand_after = p.hand.size()
	BattleManager._resolve_active_objective(p, input, breakdown, result)
	assert_eq(p.hand.size(), hand_after, "objective reward triggers only once")
	var break_objective = battle_objective_script.make("test_break", "objective_break_name", "objective_break_desc", "attack", "BREAK_ATK", "EMPOWER", 1, 2)
	p.current_objective = break_objective
	p.objective_reward_claimed = false
	p.current_stance = 1
	breakdown = BattleManager.preview_sentence(input, p)
	state = BattleManager.evaluate_active_objective(p, input, breakdown)
	assert_true(state.has("state"), "objective evaluation returns a visible state")

func test_battle_event_choices() -> void:
	print("\n--- Battle Event Choices ---")
	assert_true(Events.has_signal("event_choices_offered"), "event choices signal is available")
	assert_true(Events.has_signal("event_choice_selected"), "event choice selected signal is available")
	assert_true(BattleManager.has_method("create_event_choices"), "battle manager creates event choices")
	if not BattleManager.has_method("create_event_choices"):
		return
	var choices = BattleManager.create_event_choices("reward", "attack")
	assert_eq(choices.size(), 4, "event creates four choices")
	for choice in choices:
		assert_true(choice.get("id") != "", "event choice has id")
		assert_true(choice.get("effect_type") != "", "event choice has effect")

func test_battle_event_choice_effects() -> void:
	print("\n--- Battle Event Effects ---")
	var p = Player.new()
	p.deck = Deck.new()
	p.max_mana = 3
	p.mana = 1
	var take = BattleManager.create_event_choices("reward", "attack")[0]
	BattleManager._apply_event_choice(take, p)
	assert_gt(p.hand.size(), 0, "take card choice adds a card")

	var fill = _card(24, CardData.SentenceComponent.PREDICATE)
	fill.card_type = CardData.CardType.FILL
	p.hand.clear()
	p.hand.append(fill)
	var empower = BattleManager.create_event_choices("reward", "attack")[1]
	BattleManager._apply_event_choice(empower, p)
	assert_gt(fill.base_disorder, 24.0, "empower choice improves a matching fill card")

	var noise = CardData.new()
	noise.id = 9001
	noise.card_name = "Noise"
	p.hand.clear()
	p.hand.append(noise)
	var cleanse = _choice_by_id(BattleManager.create_event_choices("curse", "defense"), "cleanse")
	BattleManager._apply_event_choice(cleanse, p)
	assert_eq(p.hand.size(), 0, "cleanse choice removes noise")

	p.hand.clear()
	p.mana = 1
	var charge = _choice_by_id(BattleManager.create_event_choices("reward", "rhetoric"), "charge")
	BattleManager._apply_event_choice(charge, p)
	assert_eq(p.mana, 2, "charge choice recovers mana")

	var weak = _card(12, CardData.SentenceComponent.ATTRIBUTE)
	weak.card_type = CardData.CardType.FILL
	p.hand.clear()
	p.hand.append(weak)
	var refine = _choice_by_id(BattleManager.create_event_choices("reward", "rhetoric"), "refine")
	BattleManager._apply_event_choice(refine, p)
	assert_eq(p.hand.size(), 0, "refine choice removes a low-value card")

func _choice_by_id(choices: Array, choice_id: String):
	for choice in choices:
		if choice != null and choice.id == choice_id:
			return choice
	return null

func test_ai_intent_signal_contract() -> void:
	print("\n--- AI Intent ---")
	assert_true(Events.has_signal("ai_intent_declared"), "AI intent signal is available")

func test_ai_turn_planning() -> void:
	print("\n--- AI Turn Planning ---")
	assert_true(AIController.has_method("plan_turn"), "AI exposes transparent turn plan")
	if not AIController.has_method("plan_turn"):
		return
	var p = Player.new()
	p.is_ai = true
	p.mana = 3
	p.max_mana = 3
	p.hand.append(CardDatabase.get_random_fill_card())
	p.hand.append(CardDatabase.get_random_fill_card())
	var special = CardDatabase.get_random_card_by_type(CardData.CardType.EQUIPMENT, {})
	if special:
		p.hand.append(special)
	var plan = AIController.plan_turn(p, SentenceBuilder.new())
	assert_true(plan.has("stance"), "AI plan includes stance")
	assert_true(plan.has("fill_cards"), "AI plan includes fill cards")
	assert_true(plan.has("special_cards"), "AI plan includes special cards")
	assert_true(ResourceLoader.exists("res://scripts/ai_profile.gd"), "AI profile script exists")
	assert_true(Events.has_signal("ai_profile_declared"), "AI profile signal is available")
	assert_true(AIController.has_method("execute_script_turn"), "AI exposes script fallback turn")
	assert_true(AIController.has_method("execute_llm_turn"), "AI exposes LLM turn executor")
	assert_true(AIController.has_method("build_ai_turn_context"), "AI builds LLM turn context")
	assert_true(AIController.has_method("choose_event_choice"), "AI exposes event choice selector")
	var fill = _card(25, CardData.SentenceComponent.SUBJECT)
	fill.id = 7001
	fill.card_type = CardData.CardType.FILL
	fill.mana_cost = 1
	var builder = SentenceBuilder.new()
	p.hand.clear()
	p.hand.append(fill)
	var ctx = AIController.build_ai_turn_context(p, builder)
	assert_eq(ctx.game, "WORDERS", "AI LLM context names WORDERS")
	assert_eq(ctx.hand[0].id, 0, "AI LLM context gives hand card a local id")
	assert_true(ctx.has("profile"), "AI LLM context exposes profile")
	assert_true(ctx.has("objective"), "AI LLM context exposes objective")
	var initial_cards = {0: fill}
	var stance_ok = AIController._execute_llm_tool({"name": "set_stance", "arguments": {"stance": "break"}}, p, builder, initial_cards)
	assert_true(stance_ok, "AI LLM can set legal stance")
	var commit_ok = AIController._execute_llm_tool({"name": "commit_fill_card", "arguments": {"card_id": 0, "target_index": 0}}, p, builder, initial_cards)
	assert_true(commit_ok, "AI LLM can commit legal fill card")
	var fill_ok = AIController._execute_llm_tool({"name": "fill_slot", "arguments": {"slot_index": 0, "word": "word"}}, p, builder, initial_cards)
	assert_true(fill_ok, "AI LLM can fill legal slot")
	var emote_ok = AIController._execute_llm_tool({"name": "send_emote", "arguments": {"emoji": "🔥", "message": "sharp"}}, p, builder, initial_cards)
	assert_true(emote_ok, "AI LLM can send legal emote")
	var finish_ok = AIController._execute_llm_tool({"name": "finish_turn", "arguments": {"reason": "done"}}, p, builder, initial_cards)
	assert_true(finish_ok, "AI LLM can finish planned turn")
	var bad_ok = AIController._execute_llm_tool({"name": "commit_fill_card", "arguments": {"card_id": 999, "target_index": 0}}, p, builder, initial_cards)
	assert_true(not bad_ok, "AI LLM rejects unknown card id")

func test_ai_llm_transcript_execution() -> void:
	print("\n--- AI LLM Transcript ---")
	assert_true(AIController.has_method("execute_llm_tool_plan"), "AI exposes executable LLM tool-plan runner")
	BattleRecorder.start_run(4242)
	var p = Player.new()
	p.player_name = "AI"
	p.is_ai = true
	p.mana = 3
	p.max_mana = 3
	p.deck = Deck.new()
	var opp = Player.new()
	opp.player_name = "Player"
	opp.deck = Deck.new()
	var fill = _card(25, CardData.SentenceComponent.PREDICATE)
	fill.id = 7101
	fill.card_name = "Strike Word"
	fill.mana_cost = 1
	p.hand.append(fill)
	var builder = SentenceBuilder.new()
	BattleManager.player1 = opp
	BattleManager.player2 = p
	BattleManager.current_player = p
	BattleManager.sentence_builder = builder
	var calls: Array = [
		{"name": "set_stance", "arguments": {"stance": "break"}},
		{"name": "commit_fill_card", "arguments": {"card_id": 0, "target_index": 0, "reason": "attack"}},
		{"name": "fill_slot", "arguments": {"slot_index": 0, "word": "spark", "reason": "predicate"}},
		{"name": "send_emote", "arguments": {"emoji": "🔥", "message": "clear strike"}},
		{"name": "finish_turn", "arguments": {"reason": "ready"}},
	]
	var ok = await AIController.execute_llm_tool_plan(p, builder, calls, false, false)
	assert_true(ok, "AI executes a legal tool-call plan")
	assert_true(builder.is_complete(), "AI tool-call plan creates a complete sentence")
	assert_eq(p.mana, 2, "AI tool-call plan spends sentence mana")
	var snapshot = BattleRecorder.snapshot()
	var types: Array[String] = []
	for entry in snapshot.entries:
		types.append(str(entry["type"]))
	assert_true(types.has("ai_stance"), "transcript records AI stance")
	assert_true(types.has("ai_card"), "transcript records AI card")
	assert_true(types.has("ai_word"), "transcript records AI word")
	assert_true(types.has("ai_emote"), "transcript records AI emote")
	var p2 = Player.new()
	p2.player_name = "AI"
	p2.is_ai = true
	p2.mana = 2
	p2.max_mana = 2
	p2.deck = Deck.new()
	var opp2 = Player.new()
	opp2.deck = Deck.new()
	var fill2 = _card(22, CardData.SentenceComponent.SUBJECT)
	fill2.mana_cost = 1
	p2.hand.append(fill2)
	var builder2 = SentenceBuilder.new()
	BattleManager.player1 = opp2
	BattleManager.player2 = p2
	BattleManager.current_player = p2
	var implicit_finish_calls: Array = [
		{"name": "set_stance", "arguments": {"stance": "guard"}},
		{"name": "commit_fill_card", "arguments": {"card_id": 0, "target_index": 0}},
		{"name": "fill_slot", "arguments": {"slot_index": 0, "word": "stone"}},
	]
	var implicit_ok = await AIController.execute_llm_tool_plan(p2, builder2, implicit_finish_calls, false, false)
	assert_true(implicit_ok, "AI treats complete legal LLM plan as implicit finish")

func test_ai_llm_event_choice() -> void:
	print("\n--- AI LLM Event Choice ---")
	assert_true(LLMClient.has_method("request_ai_event_choice"), "LLM client exposes AI event-choice request")
	assert_true(LLMClient.has_method("build_ai_event_tools"), "LLM client builds event-choice tools")
	var choices = BattleManager.create_event_choices("reward", "attack")
	var tools = LLMClient.build_ai_event_tools({"choices": AIController.event_choices_context(choices)})
	assert_eq(tools.size(), 1, "LLM event choice exposes one tool")
	assert_eq(tools[0].function.name, "choose_event", "LLM event tool chooses event")
	assert_true(tools[0].function.parameters.properties.choice_id.enum.has("empower"), "LLM event tool enum includes legal choice")
	var original_mock = LLMClient.mock_ai_event_response.duplicate()
	LLMClient.mock_ai_event_response = {
		"ok": true,
		"tool_calls": [
			{"name": "choose_event", "arguments": {"choice_id": "empower", "reason": "improve attack line"}}
		]
	}
	var p = Player.new()
	p.is_ai = true
	p.deck = Deck.new()
	var selected = await AIController.choose_event_choice(p, choices, "attack")
	assert_eq(selected.id, "empower", "AI LLM can choose a legal event choice")
	LLMClient.mock_ai_event_response = original_mock

func test_llm_client_contract() -> void:
	print("\n--- LLM Client ---")
	var original_settings = LLMClient.load_settings().duplicate()
	LLMClient.apply_settings(LLMClient.default_settings())
	assert_true(LLMClient.has_method("request_battle_chat"), "LLM client exposes battle chat request")
	assert_true(LLMClient.has_method("request_worders_segmentation"), "LLM client exposes WORDERS segmentation request")
	assert_true(LLMClient.has_method("extract_worders_tokens"), "LLM client extracts WORDERS segmentation tokens")
	assert_true(LLMClient.has_method("build_battle_chat_messages"), "LLM client builds WORDERS chat messages")
	assert_true(LLMClient.has_method("request_ai_turn_plan"), "LLM client exposes AI turn planning")
	assert_true(LLMClient.has_method("save_settings"), "LLM client saves local settings")
	assert_eq(LLMClient.model, "deepseek-v4-pro", "DeepSeek default model uses planned battle model")
	assert_eq(LLMClient.mask_api_key("sk-1234567890"), "sk-1...7890", "LLM masks saved API keys")
	LLMClient.save_settings({
		"enabled": true,
		"api_key": "sk-test-secret",
		"model": "deepseek-v4-flash",
		"base_url": "https://example.invalid/chat/completions",
		"timeout_seconds": 7,
	})
	var saved = LLMClient.load_settings()
	assert_eq(saved.enabled, true, "LLM settings persist enabled flag")
	assert_eq(saved.api_key, "sk-test-secret", "LLM settings persist API key")
	assert_eq(saved.model, "deepseek-v4-flash", "LLM settings persist model")
	assert_eq(saved.timeout_seconds, 7, "LLM settings persist timeout")
	var context = {
		"game": "WORDERS",
		"turn": 2,
		"phase": "MAIN",
		"player": {"hp": 19, "mana": 3},
		"ai": {"hp": 30, "mana": 4},
	}
	var history: Array[Dictionary] = [
		{"role": "user", "content": "What are you doing?"},
		{"role": "assistant", "content": "Watching your sentence."},
	]
	var messages = LLMClient.build_battle_chat_messages("Hello", context, history, "en")
	assert_eq(messages[0].role, "system", "LLM messages start with system prompt")
	assert_true(str(messages[0].content).contains("WORDERS"), "LLM system prompt knows the game name")
	assert_true(str(messages[0].content).contains("word-card duel"), "LLM system prompt explains the duel rules")
	assert_true(str(messages[1].content).contains("Current WORDERS battle state"), "LLM messages include battle context")
	assert_eq(messages[messages.size() - 1].content, "Watching your sentence.", "LLM messages preserve recent chat history")
	var payload = LLMClient.build_chat_payload(messages, 0.5, 123)
	assert_eq(payload.model, "deepseek-v4-flash", "LLM payload uses configured DeepSeek model")
	assert_eq(payload.stream, false, "LLM payload requests non-stream response")
	assert_eq(payload.max_tokens, 123, "LLM payload limits chat response tokens")
	assert_eq(payload.thinking.type, "disabled", "LLM payload disables thinking for fast table chat")
	var mock = {
		"ok": true,
		"data": {
			"choices": [
				{"message": {"role": "assistant", "content": "A sharp sentence."}}
			]
		}
	}
	assert_eq(LLMClient.extract_reply(mock), "A sharp sentence.", "LLM client extracts chat completion text")
	var segmentation_mock = {
		"ok": true,
		"data": {
			"choices": [
				{"message": {"role": "assistant", "content": "{\"tokens\":[\"dragon\",\"storm\",\"dragon\",\"\"],\"reason\":\"test\"}"}}
			]
		}
	}
	var tokens = LLMClient.extract_worders_tokens(segmentation_mock)
	assert_eq(tokens.size(), 2, "LLM WORDERS segmentation cleans duplicate and empty tokens")
	assert_eq(tokens[0], "dragon", "LLM WORDERS segmentation preserves token order")
	assert_true(LLMClient.fallback_battle_reply("mana?", context).contains("WORDERS"), "LLM fallback remains in game context")
	var turn_context = {
		"hand": [
			{"id": 0, "type": "Fill"},
			{"id": 1, "type": "Function"},
		]
	}
	var tools = LLMClient.build_ai_turn_tools(turn_context)
	assert_eq(tools.size(), 6, "LLM AI exposes six fixed battle tools")
	assert_eq(tools[0].function.name, "set_stance", "LLM first battle tool sets stance")
	assert_true(tools[2].function.parameters.properties.card_id.enum.has(0), "LLM fill-card tool enum comes from context")
	assert_true(not tools[2].function.parameters.properties.card_id.enum.has(1), "LLM fill-card tool excludes special cards")
	var tool_mock = {
		"ok": true,
		"data": {
			"choices": [
				{"message": {"tool_calls": [
					{"function": {"name": "set_stance", "arguments": "{\"stance\":\"break\"}"}}
				]}}
			]
		}
	}
	assert_eq(LLMClient.extract_tool_calls(tool_mock)[0].name, "set_stance", "LLM extracts tool calls")
	LLMClient.save_settings(original_settings)

func test_settings_deepseek_ui_contract() -> void:
	print("\n--- DeepSeek Settings UI ---")
	var settings = load("res://scenes/settings.tscn").instantiate()
	add_child(settings)
	assert_true(settings.has_node("DeepSeekEnableCheck"), "settings page has DeepSeek enable switch")
	assert_true(settings.has_node("DeepSeekApiKeyEdit"), "settings page has DeepSeek API key input")
	assert_true(settings.get_node("DeepSeekApiKeyEdit").secret, "DeepSeek API key input is secret")
	assert_true(settings.has_node("DeepSeekModelOption"), "settings page has DeepSeek model selector")
	assert_true(settings.has_node("DeepSeekBaseUrlEdit"), "settings page has DeepSeek base URL input")
	assert_true(settings.has_node("DeepSeekTestButton"), "settings page has DeepSeek test button")
	assert_true(I18n.t("deepseek_enable") != "deepseek_enable", "DeepSeek settings copy is localized")
	settings.queue_free()

func test_audio_director_contract() -> void:
	print("\n--- Audio Director ---")
	assert_true(ResourceLoader.exists("res://scripts/audio_director.gd"), "audio director script exists")
	assert_eq(ProjectSettings.get_setting("autoload/AudioDirector", ""), "*res://scripts/audio_director.gd", "audio director is registered as autoload")
	if ResourceLoader.exists("res://scripts/audio_director.gd"):
		var audio_script = load("res://scripts/audio_director.gd")
		var audio = audio_script.new()
		add_child(audio)
		assert_true(audio.has_method("load_settings"), "audio director loads settings")
		assert_true(audio.has_method("save_settings"), "audio director saves settings")
		assert_true(audio.has_method("play_music"), "audio director can play music")
		assert_true(audio.has_method("play_sfx"), "audio director can play sound effects")
		audio.load_settings()
		audio.set_music_enabled(true)
		audio.set_sfx_enabled(true)
		audio.set_music_volume(0.42)
		audio.set_sfx_volume(0.35)
		assert_almost(audio.music_volume, 0.42, "audio director stores music volume")
		assert_almost(audio.sfx_volume, 0.35, "audio director stores sfx volume")
		audio.play_music("menu")
		assert_eq(audio.current_music_key, "menu", "audio director tracks active music")
		audio.play_sfx("ui_confirm")
		assert_eq(audio.last_sfx_key, "ui_confirm", "audio director tracks played sfx")
		Events.event_triggered.emit("reward")
		assert_eq(audio.last_sfx_key, "event_reward", "audio director maps gameplay event sfx")
		audio.free()
	var audio_settings = load("res://scenes/settings.tscn").instantiate()
	add_child(audio_settings)
	assert_true(audio_settings.has_node("MusicEnableCheck"), "settings page has music toggle")
	assert_true(audio_settings.has_node("SfxEnableCheck"), "settings page has sfx toggle")
	assert_true(audio_settings.has_node("MusicVolumeSlider"), "settings page has music volume slider")
	assert_true(audio_settings.has_node("SfxVolumeSlider"), "settings page has sfx volume slider")
	audio_settings.queue_free()

func test_worders_title_contract() -> void:
	print("\n--- WORDERS Title ---")
	var menu = load("res://scenes/main_menu.tscn").instantiate()
	assert_true(menu.has_method("_make_intro_word_pool"), "main menu exposes intro word pool")
	assert_true(menu.has_method("_intro_uses_brush_written_title"), "intro exposes brush title mode")
	assert_true(not menu.has_method("_make_worders_logo_label"), "intro no longer uses a separate art title label")
	var title = menu.get_node("TitleLabel") as Label
	assert_eq(title.text, "WORDERS", "main menu title is uppercase WORDERS")
	var structure_rect = menu.call("_intro_worders_structure_rect")
	assert_true(menu.call("_intro_uses_brush_written_title"), "intro writes WORDERS with a brush pass")
	assert_true(not menu.call("_intro_has_art_title_overlay"), "intro avoids mismatched art title overlay")
	assert_eq(menu.call("_intro_brush_sequence_count"), menu.call("_intro_word_count"), "brush pass visits every title word")
	assert_eq(menu.call("_intro_word_count"), 336, "intro doubles multilingual words for denser WORDERS fill")
	assert_eq(menu.call("_intro_word_color", 0), Color.WHITE, "intro title words are white")
	var pool = menu.call("_make_intro_word_pool")
	assert_gt(pool.size(), 20, "intro animation has many multilingual words")
	assert_true(menu.call("_intro_duration") >= 6.2, "intro animation is slow enough to read")
	assert_true(menu.has_method("_intro_orbit_position"), "intro animation has an orbit phase")
	assert_true(menu.has_method("_intro_letter_structure_position"), "intro animation targets WORDERS letter strokes")
	assert_true(menu.call("_intro_word_count") >= 120, "intro uses enough words to build letter structures")
	assert_true(not menu.call("_intro_has_radial_ray_burst"), "intro avoids the old radial light tangle")
	var start = menu.call("_intro_start_position", 3)
	var orbit = menu.call("_intro_orbit_position", 3, Vector2(960, 500))
	assert_true(start.distance_to(orbit) > 120.0, "intro words travel through an intermediate orbit")
	var w_pos = menu.call("_intro_letter_structure_position", 0)
	var o_pos = menu.call("_intro_letter_structure_position", 1)
	var s_pos = menu.call("_intro_letter_structure_position", 6)
	assert_true(w_pos.x < o_pos.x and o_pos.x < s_pos.x, "letter structure spans WORDERS from left to right")
	assert_true(w_pos.y < 680.0 and s_pos.y < 680.0, "letter structure is not misplaced near the bottom")
	var final_s_bottom_start = menu.call("_intro_letter_structure_position", 40 * 7 + 6)
	var final_s_bottom_end = menu.call("_intro_letter_structure_position", 47 * 7 + 6)
	assert_true(final_s_bottom_end.y > 590.0, "final S stroke stays on the bottom baseline")
	assert_true(final_s_bottom_end.x < final_s_bottom_start.x, "final S stroke moves left along the bottom")
	assert_true(abs(final_s_bottom_end.y - final_s_bottom_start.y) <= 2.0, "final S stroke is horizontal")
	var first_brush = menu.call("_intro_brush_sequence_position", 0)
	var last_w_brush = menu.call("_intro_brush_sequence_position", 23)
	var first_o_brush = menu.call("_intro_brush_sequence_position", 24)
	assert_true(structure_rect.has_point(first_brush), "brush starts inside title structure")
	assert_true(first_brush.x < first_o_brush.x, "brush writes W before moving to O")
	assert_true(first_brush.distance_to(last_w_brush) > 80.0, "brush follows a visible W stroke path")
	var all_dense_words_inside = true
	for i in range(menu.call("_intro_word_count")):
		all_dense_words_inside = all_dense_words_inside and structure_rect.grow(4.0).has_point(menu.call("_intro_letter_structure_position", i))
	assert_true(all_dense_words_inside, "dense title words stay inside structure")
	menu.queue_free()

func test_intro_visual_regression() -> void:
	print("\n--- Intro Visual Regression ---")
	var menu = load("res://scenes/main_menu.tscn").instantiate()
	var scan = intro_visual_regression_script.scan(menu)
	assert_true(scan.ok, "intro visual regression scan passes")
	assert_eq(scan.word_count, 336, "intro visual scan sees all title glyph words")
	assert_true(scan.dense_inside, "intro visual scan keeps glyphs in title bounds")
	assert_true(scan.s_final_bottom, "intro visual scan catches final S bottom baseline")
	assert_true(scan.s_final_horizontal, "intro visual scan catches final S horizontal stroke")
	assert_true(scan.bounds.size.x > 850.0, "intro visual scan covers WORDERS width")
	menu.queue_free()

func test_ui_theme_assets_and_motion_contract() -> void:
	print("\n--- UI Theme Assets ---")
	assert_true(ui_theme_script.panel_style("ink") is StyleBox, "UI theme returns ink panel style")
	assert_true(ui_theme_script.button_style("primary") is StyleBox, "UI theme returns primary button style")
	var card = _card(18, CardData.SentenceComponent.PREDICATE)
	card.card_type = CardData.CardType.FILL
	assert_eq(ui_theme_script.card_color(card), ui_theme_script.component_color(CardData.SentenceComponent.PREDICATE), "card color follows sentence component")
	for key in ui_theme_script.asset_keys():
		var path = ui_theme_script.asset_path(key)
		assert_true(ResourceLoader.exists(path), "UI asset exists: " + key)
		assert_true(ui_theme_script.asset_texture(key) != null, "UI asset loads: " + key)
	var button = Button.new()
	add_child(button)
	ui_theme_script.apply_button(button, "primary")
	assert_true(button.has_theme_stylebox_override("normal"), "UI theme applies button style")
	var tween = ui_motion_script.tween_in(button, "zoom")
	assert_true(tween != null, "UI motion creates tween")
	button.queue_free()

func test_battle_ui_i18n_keys() -> void:
	print("\n--- Battle UI I18n Keys ---")
	var old_language = I18n.language
	var keys = [
		"attack_short", "defense_short", "crit_short", "risk_short", "fit_short",
		"semantic_short", "flags_short", "rhetoric_short", "score_preview_tooltip", "score_mana_title",
		"stance_tooltip", "stat_hp_tooltip", "stat_shield_tooltip", "stat_mana_tooltip",
		"stat_deck_tooltip", "confirm_play_tooltip", "start_words_tooltip",
		"auto_words_tooltip", "clear_tooltip", "end_turn_tooltip", "codex_battle_stats",
		"codex_stat_hp_desc", "codex_stat_shield_desc", "codex_stat_mana_desc",
		"codex_stat_allocation_desc", "codex_stat_stance_desc"
	]
	for lang in [I18n.LANG_EN, I18n.LANG_ZH]:
		I18n.language = lang
		for key in keys:
			var text = I18n.t(key)
			assert_true(text != key and not text.strip_edges().is_empty(), "i18n key %s exists for %s" % [key, lang])
	I18n.language = old_language

func test_hand_fan_layout_contract() -> void:
	print("\n--- Hand Fan Layout ---")
	for count in [0, 1, 5, 10, 15]:
		var layout = hand_fan_layout_script.new()
		layout.size = Vector2(980, 236)
		add_child(layout)
		var cards: Array[CardData] = []
		for i in range(count):
			var card = _card(12 + i, CardData.SentenceComponent.SUBJECT)
			card.card_name = "Fan %d" % i
			cards.append(card)
		layout.set_cards(cards)
		assert_eq(layout.card_count(), count, "fan layout creates all cards count %d" % count)
		var in_bounds = true
		for rect in layout.get_card_rects():
			in_bounds = in_bounds and rect.position.x >= -24.0 and rect.end.x <= layout.size.x + 24.0
			in_bounds = in_bounds and rect.position.y >= -92.0 and rect.end.y <= layout.size.y + 64.0
		assert_true(in_bounds, "fan layout keeps cards accessible count %d" % count)
		layout.queue_free()
	var backs = hand_fan_layout_script.new()
	backs.size = Vector2(720, 180)
	add_child(backs)
	backs.set_card_backs(8, load("res://resources/art/card_back.png"))
	assert_eq(backs.card_count(), 8, "fan layout can show opponent card backs")
	backs.queue_free()

func test_card_drag_visual_contract() -> void:
	print("\n--- Card Drag Visual Contract ---")
	var card = card_scene.instantiate()
	add_child(card)
	card.card_data = _card(20, CardData.SentenceComponent.PREDICATE)
	await get_tree().process_frame
	var payload = card._get_drag_data(Vector2.ZERO)
	assert_true(payload is Dictionary, "card drag returns a payload")
	assert_eq(card.visible, false, "source card hides while drag preview is active")
	if card.has_method("_restore_drag_visual"):
		card._restore_drag_visual()
	assert_eq(card.visible, true, "source card restores after canceled drag")
	card.queue_free()

func test_role_meter_contract() -> void:
	print("\n--- Role Meter ---")
	var player = Player.new()
	player.player_name = "Tester"
	player.hp = 18
	player.max_hp = 30
	player.shield = 7
	player.mana = 2
	player.max_mana = 3
	var meter = role_meter_script.new()
	meter.size = Vector2(320, 140)
	var avatar = Label.new()
	avatar.name = "PlayerAvatarLabel"
	meter.add_child(avatar)
	var stats = Label.new()
	stats.name = "PlayerStatsLabel"
	meter.add_child(stats)
	add_child(meter)
	meter.set_player(player, false)
	var hp_label = meter.get_node_or_null("HPLabel") as Label
	var hp_value = meter.get_node_or_null("HPValueLabel") as Label
	var shield_label = meter.get_node_or_null("ShieldLabel") as Label
	var shield_value = meter.get_node_or_null("ShieldValueLabel") as Label
	var mana_label = meter.get_node_or_null("ManaLabel") as Label
	var mana_value = meter.get_node_or_null("ManaValueLabel") as Label
	var deck_label = meter.get_node_or_null("DeckLabel") as Label
	var deck_value = meter.get_node_or_null("DeckValueLabel") as Label
	assert_true(hp_label != null and hp_label.text == I18n.t("hp"), "role meter labels hp")
	assert_true(hp_value != null and hp_value.text.contains("18/30"), "role meter shows hp value")
	assert_true(shield_label != null and shield_label.text == I18n.t("shield"), "role meter labels shield")
	assert_true(shield_value != null and shield_value.text == "7", "role meter shows shield value")
	assert_true(mana_label != null and mana_label.text == I18n.t("mana"), "role meter labels mana")
	assert_true(mana_value != null and mana_value.text.contains("2/3"), "role meter shows mana value")
	assert_true(deck_label != null and deck_label.text == I18n.t("deck"), "role meter labels deck")
	assert_true(deck_value != null and deck_value.text == "0", "role meter shows deck value")
	assert_true(hp_label.tooltip_text == I18n.t("stat_hp_tooltip"), "role meter exposes hp tooltip")
	meter.play_hp_change(30, 18)
	meter.play_shield_change(0, 7)
	meter.play_mana_change(0, 2)
	meter.queue_free()

func test_ui_layout_audit_contract() -> void:
	print("\n--- UI Layout Audit ---")
	for scene_path in ["res://scenes/main_menu.tscn", "res://scenes/settings.tscn", "res://scenes/how_to_play.tscn", "res://scenes/battle.tscn"]:
		for viewport in [Vector2(1366, 768), Vector2(1920, 1080), Vector2(2560, 1440)]:
			var scene = load(scene_path).instantiate()
			add_child(scene)
			var audit = ui_layout_audit_script.scan(scene, viewport)
			assert_true(audit.ok, "layout audit passes %s at %s" % [scene_path, str(viewport)])
			scene.queue_free()

func test_fx_smoke_contract() -> void:
	print("\n--- FX Smoke ---")
	var root = Control.new()
	root.size = Vector2(1920, 1080)
	var fx_layer = Control.new()
	fx_layer.name = "FxLayer"
	fx_layer.size = Vector2(1920, 1080)
	root.add_child(fx_layer)
	add_child(root)
	var audit = fx_smoke_audit_script.scan(fx_layer)
	assert_true(audit.ok, "FX smoke creates transient nodes")
	assert_gt(audit.created, 0, "FX smoke creates visible feedback")
	var director = battle_fx_director_script.new(root, fx_layer)
	assert_true(director != null, "battle FX director can be constructed")
	root.queue_free()

func test_battle_recorder_seed_and_replay() -> void:
	print("\n--- Battle Recorder ---")
	BattleManager.start_battle(13579)
	assert_eq(BattleManager.battle_seed, 13579, "battle manager accepts deterministic seed")
	assert_eq(BattleRecorder.current_seed, 13579, "battle recorder stores deterministic seed")
	Events.event_triggered.emit("test_event")
	var summary = BattleRecorder.latest_summary()
	assert_true(summary.entries >= 2, "battle recorder stores replay entries")
	var path = BattleRecorder.export_latest()
	assert_true(FileAccess.file_exists(path), "battle recorder exports latest replay")

func test_support_panels_contract() -> void:
	print("\n--- Support Panels ---")
	var debug_panel = battle_debug_panel_script.new()
	add_child(debug_panel)
	var breakdown = ScoringEngine.ScoreBreakdown.new()
	breakdown.atk = 7
	breakdown.def_ = 3
	breakdown.crt = 2
	breakdown.stance_name = "break"
	debug_panel.record_score(breakdown)
	assert_true(debug_panel.summary_text().contains("ATK 7"), "debug panel summarizes score")
	debug_panel.queue_free()
	var codex = battle_codex_panel_script.new()
	add_child(codex)
	codex.refresh()
	assert_true(codex.build_text().contains("WORDERS"), "codex panel explains WORDERS")
	assert_true(codex.build_text().contains("Fill"), "codex panel lists card categories")
	codex.queue_free()
	var battle = load("res://scenes/battle.tscn").instantiate()
	add_child(battle)
	assert_true(battle.has_node("DebugToggleButton"), "battle UI has debug toggle")
	assert_true(battle.has_node("CodexButton"), "battle UI has codex button")
	assert_true(battle.has_node("BattleDebugPanel"), "battle UI owns debug panel")
	assert_true(battle.has_node("BattleCodexPanel"), "battle UI owns codex panel")
	battle.queue_free()

func test_battle_ui_chat_pruning() -> void:
	print("\n--- Battle UI ---")
	var battle = load("res://scenes/battle.tscn").instantiate()
	add_child(battle)
	assert_eq(BattleManager.current_player.mana, 3, "battle starts player at 3 mana")
	assert_eq(BattleManager.PLAYER_TURN_SECONDS, 120, "player turn timer is two minutes")
	for i in range(battle.CHAT_LOG_MAX_LINES + 8):
		battle._add_chat_message("T", str(i), Color.WHITE)
	assert_true(battle.chat_log.get_child_count() <= battle.CHAT_LOG_MAX_LINES, "chat log prunes old messages without blocking")
	assert_true(battle.has_node("ChatPanel/ChatScroll"), "chat log is scrollable")
	var llm_context = battle._build_llm_battle_context()
	assert_eq(llm_context.game, "WORDERS", "battle chat context names WORDERS")
	assert_true(llm_context.rules_summary.size() >= 3, "battle chat context includes core rules")
	assert_true(battle.has_method("_handle_worders_command"), "battle UI exposes WORDERS command handler")
	assert_true(battle.has_method("_segment_worders_text"), "battle UI exposes WORDERS local segmentation")
	assert_true(battle.has_method("_assign_words_to_empty_slots"), "battle UI exposes WORDERS slot assignment")
	assert_true(battle.has_node("StartWordsButton"), "battle UI has start words button")
	if battle.has_method("_segment_worders_text"):
		var local_tokens = battle._segment_worders_text("dragon, storm dragon sword")
		assert_eq(local_tokens.size(), 3, "WORDERS local segmentation removes duplicates")
		assert_eq(local_tokens[0], "dragon", "WORDERS local segmentation preserves order")
	var no_slot_children = battle.chat_log.get_child_count()
	if battle.has_method("_handle_worders_command"):
		await battle._handle_worders_command("/WORDERS dragon storm")
		assert_true(battle.chat_log.get_child_count() >= no_slot_children, "WORDERS command with no slots only reports status")
	var fill_subject = _card(20, CardData.SentenceComponent.SUBJECT)
	fill_subject.pos_constraint = CardData.PartOfSpeech.NOUN
	fill_subject.content_constraint = CardData.ContentCategory.ANIMAL
	var fill_pred = _card(20, CardData.SentenceComponent.PREDICATE)
	fill_pred.pos_constraint = CardData.PartOfSpeech.VERB
	fill_pred.content_constraint = CardData.ContentCategory.ACTION
	var locked_slot = BattleManager.sentence_builder.add_card(fill_subject, 0)
	locked_slot.word = "locked"
	var empty_slot = BattleManager.sentence_builder.add_card(fill_pred, 1)
	if battle.has_method("_assign_words_to_empty_slots"):
		var assignment = battle._assign_words_to_empty_slots(["dragon", "roar", "sword"])
		assert_eq(locked_slot.word, "locked", "WORDERS assignment does not overwrite filled slots")
		assert_true(not empty_slot.word.strip_edges().is_empty(), "WORDERS assignment fills an empty slot")
		assert_true(assignment.get("filled", []).size() >= 1, "WORDERS assignment reports filled words")
	if battle.has_method("_handle_worders_command"):
		empty_slot.word = ""
		var before_history = battle._chat_history.size()
		await battle._handle_worders_command("/worders dragon roar sword")
		assert_eq(battle._chat_history.size(), before_history, "WORDERS command does not enter normal chat history")
		assert_true(not empty_slot.word.strip_edges().is_empty(), "WORDERS command fills sentence slot")
		empty_slot.word = ""
		battle.chat_input.text = "/WORDERS dragon roar sword"
		await battle._send_chat_from_input()
		assert_eq(battle._chat_history.size(), before_history, "WORDERS chat input is intercepted before normal chat")
		assert_true(not empty_slot.word.strip_edges().is_empty(), "WORDERS chat input fills sentence slot")
		empty_slot.word = ""
		var old_mock = LLMClient.mock_worders_segmentation_response.duplicate()
		LLMClient.mock_worders_segmentation_response = {
			"ok": true,
			"data": {
				"choices": [
					{"message": {"role": "assistant", "content": "{\"tokens\":[\"roar\",\"dragon\",\"roar\"],\"reason\":\"mock\"}"}}
				]
			}
		}
		await battle._handle_worders_command("/worders anything")
		assert_true(not empty_slot.word.strip_edges().is_empty(), "WORDERS command can use LLM segmentation tokens")
		LLMClient.mock_worders_segmentation_response = old_mock
	BattleManager.sentence_builder.clear()
	var staged_card = _card(20, CardData.SentenceComponent.SUBJECT)
	staged_card.card_type = CardData.CardType.FILL
	staged_card.mana_cost = 1
	BattleManager.current_player.hand.append(staged_card)
	battle._play_card_from_hand(staged_card)
	await get_tree().process_frame
	assert_true(battle.get_node_or_null("WordInputDialog") == null, "dragging a fill card stages without opening word dialog")
	BattleManager.sentence_builder.clear()
	var flow_slot_a = BattleManager.sentence_builder.add_card(_card(20, CardData.SentenceComponent.SUBJECT), 0)
	var flow_slot_b = BattleManager.sentence_builder.add_card(_card(20, CardData.SentenceComponent.PREDICATE), 1)
	battle._refresh_slots()
	assert_true(battle.get_node("StartWordsButton").disabled == false, "start words button enables when empty slots exist")
	battle._start_word_fill_sequence()
	await get_tree().process_frame
	var flow_dialog = battle.get_node_or_null("WordInputDialog")
	assert_true(flow_dialog != null, "start words opens the first word dialog")
	var flow_input = flow_dialog.find_child("WordInputLineEdit", true, false) if flow_dialog else null
	if flow_input:
		flow_input.text = "dragon"
		flow_input.text_submitted.emit("dragon")
	await get_tree().process_frame
	await get_tree().process_frame
	assert_eq(flow_slot_a.word, "dragon", "first Enter in word flow fills first slot")
	flow_dialog = battle.get_node_or_null("WordInputDialog")
	assert_true(flow_dialog != null, "word flow advances to the next dialog")
	flow_input = flow_dialog.find_child("WordInputLineEdit", true, false) if flow_dialog else null
	if flow_input:
		flow_input.text = "roar"
		flow_input.text_submitted.emit("roar")
	await get_tree().process_frame
	await get_tree().process_frame
	assert_eq(flow_slot_b.word, "roar", "second Enter in word flow fills second slot")
	assert_true(battle.get_node_or_null("WordInputDialog") == null, "word flow closes after final slot")
	assert_true(not battle._word_fill_active, "word flow deactivates after final slot")
	BattleManager.sentence_builder.clear()
	var slot = SentenceBuilder.Slot.new(_card(20, CardData.SentenceComponent.SUBJECT))
	battle._on_word_input(slot)
	await get_tree().process_frame
	var dialog = battle.get_node_or_null("WordInputDialog")
	assert_true(dialog != null, "word input dialog has stable node name")
	if dialog:
		assert_true(dialog.min_size.x >= 680 and dialog.min_size.y >= 430, "word input dialog is large enough for readable content")
	var input = dialog.find_child("WordInputLineEdit", true, false) if dialog else null
	assert_true(input != null, "word input dialog exposes line edit")
	if input:
		assert_true(input.get_theme_font_size("font_size") >= 22, "word input line edit uses readable font size")
		assert_true(input.custom_minimum_size.y >= 50, "word input line edit has enough height")
		input.text = "testword"
		input.text_submitted.emit("testword")
		await get_tree().process_frame
		assert_eq(slot.word, "testword", "pressing enter accepts word input")
	assert_true(battle.has_method("_candidate_words_for_slot"), "battle UI exposes smart word candidates")
	assert_true(battle.has_method("_word_candidate_label"), "battle UI exposes scored word candidate labels")
	var rec_slot = SentenceBuilder.Slot.new(_card(20, CardData.SentenceComponent.SUBJECT))
	if battle.has_method("_candidate_words_for_slot"):
		var candidates = battle._candidate_words_for_slot(rec_slot, 3)
		assert_gt(candidates.size(), 0, "smart word candidates are available")
		assert_true(candidates.size() <= 3, "smart word candidates stay compact")
		var seen_words := {}
		for word in candidates:
			assert_true(not seen_words.has(word), "smart word candidates are unique")
			seen_words[word] = true
	battle._on_word_input(rec_slot)
	await get_tree().process_frame
	var candidate_list = battle.find_child("WordCandidateButtons", true, false)
	assert_true(candidate_list != null, "word input dialog exposes candidate list")
	if candidate_list:
		assert_true(candidate_list.custom_minimum_size.x >= 560.0, "candidate list has enough width")
		assert_true(candidate_list.get_child_count() >= 2, "candidate list separates title and buttons")
	var candidate_button = battle.find_child("WordCandidateButton", true, false)
	assert_true(candidate_button != null, "word input dialog exposes one-click candidate buttons")
	if candidate_button:
		assert_true(candidate_button.custom_minimum_size.x >= 560.0, "candidate button is full width to avoid clipped text")
		assert_true(candidate_button.custom_minimum_size.y >= 44.0, "candidate button has enough height")
		assert_true(candidate_button.has_method("apply_preview"), "candidate button renders visual score preview")
		candidate_button.pressed.emit()
		await get_tree().process_frame
		assert_true(not rec_slot.word.strip_edges().is_empty(), "clicking a candidate fills the slot")
		assert_true(battle.get_node_or_null("WordInputDialog") == null, "clicking a candidate closes word dialog")
	battle.queue_free()
