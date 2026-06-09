class_name FxSmokeAudit extends RefCounted

static func scan(fx_layer: Control) -> Dictionary:
	var result = {"ok": false, "created": 0, "errors": []}
	if fx_layer == null:
		result.errors.append("missing_fx_layer")
		return result
	var owner = fx_layer.get_parent() as Control
	if owner == null:
		result.errors.append("missing_owner")
		return result
	var director = BattleFxDirector.new(owner, fx_layer)
	var before = fx_layer.get_child_count()
	var card = CardData.new()
	card.card_name = "Smoke"
	card.comp_constraint = CardData.SentenceComponent.PREDICATE
	director.play_card_to_slot(card, Vector2(100, 100), Vector2(220, 160))
	var breakdown = ScoringEngine.ScoreBreakdown.new()
	breakdown.atk = 8
	director.play_sentence_submit(["墨", "战"], breakdown)
	var combat = CombatResolver.CombatResult.new()
	combat.damage_dealt = 3
	combat.shield_gained = 2
	combat.heal_amount = 1
	director.play_combat_result(combat)
	result.created = fx_layer.get_child_count() - before
	result.ok = result.created > 0 and result.errors.is_empty()
	return result
