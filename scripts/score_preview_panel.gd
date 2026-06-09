class_name ScorePreviewPanel extends Panel

const ATK_COLOR := Color(0.95, 0.22, 0.14, 1.0)
const DEF_COLOR := Color(0.28, 0.68, 1.0, 1.0)
const CRT_COLOR := Color(0.98, 0.76, 0.28, 1.0)
const RISK_COLOR := Color(0.95, 0.38, 0.22, 1.0)
const FIT_COLOR := Color(0.36, 0.95, 0.58, 1.0)
const STAT_CAP := 16

var _status_label: Label
var _stance_label: Label
var _mana_label: Label
var _stat_values: Dictionary = {}
var _stat_bars: Dictionary = {}
var _chip_row: HBoxContainer
var _last_signature := ""

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_PASS
	add_theme_stylebox_override("panel", UiTheme.panel_style("tool"))
	_build_layout()

func _build_layout() -> void:
	var margin = MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 14)
	margin.add_theme_constant_override("margin_right", 14)
	margin.add_theme_constant_override("margin_top", 8)
	margin.add_theme_constant_override("margin_bottom", 8)
	add_child(margin)

	var root = VBoxContainer.new()
	root.add_theme_constant_override("separation", 6)
	margin.add_child(root)

	var header = HBoxContainer.new()
	header.add_theme_constant_override("separation", 10)
	root.add_child(header)

	_status_label = _make_chip_label(header, Color(0.98, 0.84, 0.42, 1.0))
	_stance_label = _make_chip_label(header, Color(0.72, 0.86, 1.0, 1.0))
	var spacer = Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(spacer)
	_mana_label = Label.new()
	_mana_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_mana_label.add_theme_font_size_override("font_size", 15)
	_mana_label.add_theme_color_override("font_color", Color(0.98, 0.82, 0.42, 1.0))
	header.add_child(_mana_label)

	var stats = HBoxContainer.new()
	stats.add_theme_constant_override("separation", 12)
	stats.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	root.add_child(stats)

	for key in ["atk", "def", "crt"]:
		stats.add_child(_make_stat_column(key))

	_chip_row = HBoxContainer.new()
	_chip_row.add_theme_constant_override("separation", 6)
	root.add_child(_chip_row)

func _make_chip_label(parent: HBoxContainer, color: Color) -> Label:
	var label = Label.new()
	label.add_theme_font_size_override("font_size", 14)
	label.add_theme_color_override("font_color", color)
	label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.72))
	label.add_theme_constant_override("shadow_offset_y", 2)
	parent.add_child(label)
	return label

func _make_stat_column(key: String) -> VBoxContainer:
	var column = VBoxContainer.new()
	column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	column.add_theme_constant_override("separation", 4)

	var header = HBoxContainer.new()
	header.add_theme_constant_override("separation", 6)
	column.add_child(header)

	var icon = TextureRect.new()
	icon.custom_minimum_size = Vector2(18, 18)
	icon.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.texture = _stat_icon(key)
	header.add_child(icon)

	var title = Label.new()
	title.text = _stat_title(key)
	title.add_theme_font_size_override("font_size", 13)
	title.add_theme_color_override("font_color", _stat_color(key) * Color(1, 1, 1, 0.92))
	header.add_child(title)

	var value = Label.new()
	value.name = "StatValue_%s" % key
	value.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	value.add_theme_font_size_override("font_size", 24)
	value.add_theme_color_override("font_color", _stat_color(key))
	value.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.78))
	value.add_theme_constant_override("shadow_offset_y", 2)
	column.add_child(value)
	_stat_values[key] = value

	var bar = ProgressBar.new()
	bar.custom_minimum_size = Vector2(0, 10)
	bar.show_percentage = false
	bar.max_value = float(STAT_CAP)
	bar.step = 1.0
	bar.value = 0.0
	var fill = StyleBoxFlat.new()
	fill.bg_color = _stat_color(key)
	fill.corner_radius_top_left = 3
	fill.corner_radius_top_right = 3
	fill.corner_radius_bottom_left = 3
	fill.corner_radius_bottom_right = 3
	bar.add_theme_stylebox_override("fill", fill)
	var bg = StyleBoxFlat.new()
	bg.bg_color = Color(0.02, 0.025, 0.04, 0.88)
	bg.corner_radius_top_left = 3
	bg.corner_radius_top_right = 3
	bg.corner_radius_bottom_left = 3
	bg.corner_radius_bottom_right = 3
	bar.add_theme_stylebox_override("background", bg)
	column.add_child(bar)
	_stat_bars[key] = bar

	return column

func update_mana_only(cost: int, mana: int) -> void:
	_last_signature = ""
	_status_label.text = I18n.t("score_mana_title")
	_stance_label.text = ""
	_mana_label.text = I18n.t("score_mana") % [cost, mana]
	for key in ["atk", "def", "crt"]:
		_stat_values[key].text = "0"
		_stat_bars[key].value = 0.0
	_clear_chips()
	tooltip_text = I18n.t("score_preview_tooltip")

func update_preview(
	breakdown: ScoringEngine.ScoreBreakdown,
	cost: int,
	mana: int,
	partial: bool,
	animate: bool = true,
) -> void:
	var signature = "%s|%d|%d|%d|%d|%d|%.2f|%.2f" % [
		breakdown.stance_name,
		breakdown.atk,
		breakdown.def_,
		breakdown.crt,
		cost,
		mana,
		breakdown.constraint_penalty_percent,
		breakdown.constraint_bonus,
	]
	var changed = signature != _last_signature
	_last_signature = signature

	_status_label.text = I18n.t("prediction_partial") if partial else I18n.t("prediction_ready")
	_stance_label.text = _stance_label_by_key(breakdown.stance_name)
	_mana_label.text = I18n.t("score_mana") % [cost, mana]

	var peak = maxi(STAT_CAP, maxi(breakdown.atk, maxi(breakdown.def_, breakdown.crt)))
	_set_stat("atk", breakdown.atk, peak)
	_set_stat("def", breakdown.def_, peak)
	_set_stat("crt", breakdown.crt, peak)
	_rebuild_chips(breakdown)

	tooltip_text = _format_tooltip(breakdown, cost, mana, partial)
	if animate and changed:
		_play_refresh_pulse()

func stat_global_center(key: String) -> Vector2:
	var label: Label = _stat_values.get(key)
	if label and is_instance_valid(label):
		return label.get_global_rect().get_center()
	return get_global_rect().get_center()

func play_stat_hit(key: String) -> void:
	var label: Label = _stat_values.get(key)
	if label == null or not is_instance_valid(label):
		return
	var tween = create_tween()
	label.scale = Vector2(1.14, 1.14)
	tween.tween_property(label, "scale", Vector2.ONE, 0.16).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	var bar: ProgressBar = _stat_bars.get(key)
	if bar and is_instance_valid(bar):
		bar.self_modulate = Color(1.2, 1.15, 1.05, 1.0)
		tween.parallel().tween_property(bar, "self_modulate", Color.WHITE, 0.16)

func _set_stat(key: String, value: int, peak: int) -> void:
	_stat_values[key].text = str(value)
	var bar: ProgressBar = _stat_bars[key]
	bar.max_value = float(maxi(peak, 1))
	bar.value = float(value)

func _rebuild_chips(breakdown: ScoringEngine.ScoreBreakdown) -> void:
	_clear_chips()
	_add_chip(
		I18n.t("risk_short") + " S%.0f C%.0f" % [
			breakdown.structure_penalty_percent * 100.0,
			breakdown.constraint_penalty_percent * 100.0,
		],
		RISK_COLOR if breakdown.constraint_penalty_percent > 0.0 or breakdown.structure_penalty_percent > 0.0 else Color(0.62, 0.68, 0.78, 0.92),
	)
	if breakdown.constraint_bonus > 0.0:
		_add_chip("%s +%.0f" % [I18n.t("fit_short"), breakdown.constraint_bonus], FIT_COLOR)
	if breakdown.embedding_similarity > 0.0:
		_add_chip("%s %.0f%%" % [I18n.t("semantic_short"), breakdown.embedding_similarity * 100.0], Color(0.72, 0.84, 1.0, 0.95))
	if not breakdown.rhetoric_flags.is_empty():
		_add_chip("%s %s" % [I18n.t("rhetoric_short"), ", ".join(breakdown.rhetoric_flags)], Color(0.98, 0.82, 0.42, 1.0))
	elif breakdown.constraint_flags.size() > 0:
		_add_chip("%s %d" % [I18n.t("flags_short"), breakdown.constraint_flags.size()], Color(0.86, 0.90, 1.0, 0.92))

func _add_chip(text: String, color: Color) -> void:
	var chip = PanelContainer.new()
	var chip_style = StyleBoxFlat.new()
	chip_style.bg_color = Color(0.03, 0.04, 0.06, 0.82)
	chip_style.border_color = color * Color(1, 1, 1, 0.55)
	chip_style.set_border_width_all(1)
	chip_style.set_content_margin_all(6)
	chip_style.corner_radius_top_left = 6
	chip_style.corner_radius_top_right = 6
	chip_style.corner_radius_bottom_left = 6
	chip_style.corner_radius_bottom_right = 6
	chip.add_theme_stylebox_override("panel", chip_style)
	var label = Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", 12)
	label.add_theme_color_override("font_color", color)
	chip.add_child(label)
	_chip_row.add_child(chip)

func _clear_chips() -> void:
	if _chip_row == null:
		return
	for child in _chip_row.get_children():
		child.queue_free()

func _play_refresh_pulse() -> void:
	var tween = create_tween()
	self_modulate = Color(1.08, 1.06, 0.98, 1.0)
	tween.tween_property(self, "self_modulate", Color.WHITE, 0.18)

func _stat_color(key: String) -> Color:
	match key:
		"atk":
			return ATK_COLOR
		"def":
			return DEF_COLOR
		"crt":
			return CRT_COLOR
	return Color.WHITE

func _stat_title(key: String) -> String:
	match key:
		"atk":
			return I18n.t("attack_short")
		"def":
			return I18n.t("defense_short")
		"crt":
			return I18n.t("crit_short")
	return key.to_upper()

func _stat_icon(key: String) -> Texture2D:
	match key:
		"atk":
			return UiTheme.asset_texture("fx_ink_red")
		"def":
			return UiTheme.asset_texture("fx_ink_blue")
		"crt":
			return UiTheme.asset_texture("fx_ink_gold")
	return null

func _stance_label_by_key(key: String) -> String:
	match key:
		"break":
			return I18n.t("stance_break")
		"guard":
			return I18n.t("stance_guard")
		"harmony":
			return I18n.t("stance_harmony")
	return I18n.t("stance_balanced")

func _format_tooltip(
	breakdown: ScoringEngine.ScoreBreakdown,
	cost: int,
	mana: int,
	partial: bool,
) -> String:
	var flags = ", ".join(breakdown.rhetoric_flags)
	if flags.is_empty():
		flags = I18n.t("none_label")
	return I18n.t("prediction_format") % [
		I18n.t("prediction_partial") if partial else I18n.t("prediction_ready"),
		I18n.t("attack_short"),
		breakdown.atk,
		I18n.t("defense_short"),
		breakdown.def_,
		I18n.t("crit_short"),
		breakdown.crt,
		I18n.t("mana"),
		cost,
		mana,
		I18n.t("risk_short"),
		breakdown.structure_penalty_percent * 100.0,
		breakdown.constraint_penalty_percent * 100.0,
		I18n.t("fit_short"),
		breakdown.constraint_bonus,
		I18n.t("semantic_short"),
		breakdown.embedding_similarity * 100.0,
		I18n.t("flags_short"),
		breakdown.constraint_flags.size(),
		I18n.t("rhetoric_short"),
		flags,
	]
