class_name BattleCodexPanel extends AcceptDialog

var _body := RichTextLabel.new()

func _ready() -> void:
	title = I18n.t("codex_title") if Engine.get_main_loop() else "Card Codex"
	size = Vector2(820, 680)
	ok_button_text = I18n.t("back") if Engine.get_main_loop() else "Back"
	_body.layout_mode = 1
	_body.anchors_preset = Control.PRESET_FULL_RECT
	_body.anchor_right = 1.0
	_body.anchor_bottom = 1.0
	_body.offset_left = 18
	_body.offset_top = 18
	_body.offset_right = -18
	_body.offset_bottom = -58
	_body.bbcode_enabled = true
	_body.fit_content = false
	_body.scroll_active = true
	_body.add_theme_color_override("default_color", Color(0.88, 0.92, 1.0, 0.98))
	add_child(_body)
	refresh()

func refresh() -> void:
	if _body == null:
		return
	_body.text = build_text()

func build_text() -> String:
	var lines: Array[String] = []
	lines.append("[center][font_size=28][color=#FFD66D]WORDERS[/color][/font_size][/center]\n")
	lines.append("[b]%s[/b]" % _localized("codex_archetypes", "Archetypes"))
	lines.append("破句流 / Break: 谓语、宾语、补语，爆发攻击，高风险。")
	lines.append("守句流 / Guard: 主语、定语，护盾与治疗稳定。")
	lines.append("修辞流 / Harmony: 状语、押韵、排比、对仗，依赖排序和约束。\n")
	lines.append("[b]%s[/b]" % _localized("codex_constraints", "Constraints"))
	lines.append("词性、句子成分、主题完全匹配会给小奖励；已知词不匹配会产生软惩罚；未知词允许自由发挥。\n")
	lines.append("[b]%s[/b]" % _localized("codex_battle_stats", "Battle Stats"))
	lines.append("- %s" % _localized("codex_stat_hp_desc", "HP is health. A player loses when HP reaches 0."))
	lines.append("- %s" % _localized("codex_stat_shield_desc", "Shield absorbs damage before HP and is mainly produced by DEF."))
	lines.append("- %s" % _localized("codex_stat_mana_desc", "Mana pays sentence costs. If the staged sentence costs too much, it cannot be confirmed."))
	lines.append("- %s" % _localized("codex_stat_allocation_desc", "Predicate, Object, and Complement cards favor ATK; Subject and Attribute favor DEF; Adverbial favors CRT."))
	lines.append("- %s\n" % _localized("codex_stat_stance_desc", "Stances adjust attack, defense, critical setup, healing, and risk before combat resolves."))
	lines.append("[b]%s[/b]" % _localized("codex_card_counts", "Card Library"))
	lines.append(_count_line("Fill", CardDatabase.fill_cards))
	lines.append(_count_line("Function", CardDatabase.function_cards))
	lines.append(_count_line("Equipment", CardDatabase.equipment_cards))
	lines.append(_count_line("Status", CardDatabase.status_cards))
	lines.append("\n[b]%s[/b]" % _localized("codex_examples", "Examples"))
	for card in (CardDatabase.fill_cards + CardDatabase.function_cards + CardDatabase.equipment_cards + CardDatabase.status_cards).slice(0, 12):
		lines.append("- %s · %s · %s/%s/%s · cost %d" % [
			card.get_display_name(),
			card.get_type_name(),
			card.get_pos_name(),
			card.get_comp_name(),
			card.get_content_name(),
			card.mana_cost,
		])
	return "\n".join(lines)

func _count_line(label: String, cards: Array) -> String:
	return "- %s: %d" % [label, cards.size()]

func _localized(key: String, fallback: String) -> String:
	var text = I18n.t(key) if Engine.get_main_loop() else key
	return fallback if text == key else text
