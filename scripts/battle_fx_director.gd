class_name BattleFxDirector extends RefCounted

var owner: Control
var fx_layer: Control

func _init(owner_control: Control = null, layer: Control = null) -> void:
	owner = owner_control
	fx_layer = layer

func bind(owner_control: Control, layer: Control) -> void:
	owner = owner_control
	fx_layer = layer

func play_card_to_slot(card: CardData, from_pos: Vector2, to_pos: Vector2) -> void:
	if not _ready():
		return
	var panel = Panel.new()
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.size = Vector2(126, 160)
	panel.position = from_pos - panel.size * 0.5
	panel.add_theme_stylebox_override("panel", UiTheme.card_style(card))
	var label = _label(card.get_display_name() if card else "", UiTheme.card_color(card), 18)
	label.anchors_preset = Control.PRESET_FULL_RECT
	label.anchor_right = 1.0
	label.anchor_bottom = 1.0
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	panel.add_child(label)
	fx_layer.add_child(panel)
	var tween = UiMotion.apply_speed_scale(owner.create_tween())
	tween.set_parallel(true)
	tween.tween_property(panel, "position", to_pos - panel.size * 0.5, 0.26).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tween.tween_property(panel, "scale", Vector2(0.88, 0.88), 0.26).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(panel, "modulate:a", 0.0, 0.12).set_delay(0.20)
	tween.set_parallel(false)
	tween.tween_callback(panel.queue_free)
	ink_burst(to_pos, UiTheme.card_color(card), 10, "*")

func play_sentence_submit(slots: Array, breakdown: ScoringEngine.ScoreBreakdown) -> void:
	if not _ready():
		return
	var text = _sentence_text(slots)
	if text.is_empty():
		text = "WORDERS"
	var chars = min(text.length(), 24)
	var spacing = 34.0
	var start = Vector2(960.0 - spacing * float(chars - 1) * 0.5, 376.0)
	for i in range(chars):
		var glyph = _label(text.substr(i, 1), _break_color(breakdown), 38)
		glyph.position = start + Vector2(i * spacing, sin(float(i) * 0.75) * 9.0)
		glyph.scale = Vector2(0.4, 0.4)
		glyph.modulate.a = 0.0
		fx_layer.add_child(glyph)
		var tween = UiMotion.apply_speed_scale(owner.create_tween())
		tween.set_parallel(true)
		tween.tween_property(glyph, "scale", Vector2(1, 1), 0.22).set_delay(float(i) * 0.018).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		tween.tween_property(glyph, "modulate:a", 1.0, 0.12).set_delay(float(i) * 0.018)
		tween.tween_property(glyph, "position", glyph.position + Vector2(0, -10), 0.22).set_delay(float(i) * 0.018)
		tween.set_parallel(false)
		tween.tween_interval(0.28)
		tween.tween_callback(func(): _shatter_label(glyph, _break_color(breakdown)))
	ink_burst(Vector2(960, 390), _break_color(breakdown), 18, "墨")

func play_combat_result(result: CombatResolver.CombatResult) -> void:
	if not _ready() or result == null:
		return
	if result.damage_dealt > 0:
		ink_burst(Vector2(1130, 300), UiTheme.CINNABAR, 26, "*")
	if result.shield_gained > 0:
		ink_ring(Vector2(790, 760), UiTheme.PLAYER_BLUE, 20)
	if result.heal_amount > 0:
		rising_ink(Vector2(850, 780), UiTheme.JADE, 14)
	if result.was_crit:
		screen_flash(Color(1.0, 0.82, 0.25, 0.24))

func play_event_choice(choice) -> void:
	if not _ready():
		return
	var text = choice.name if choice != null and choice is BattleEventChoice else "Event"
	var banner = _label(str(text), UiTheme.GOLD, 26)
	banner.position = Vector2(760, 312)
	banner.size = Vector2(400, 54)
	banner.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	banner.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	banner.add_theme_stylebox_override("normal", UiTheme.panel_style("paper"))
	fx_layer.add_child(banner)
	UiMotion.tween_in(banner, "zoom")
	var tween = UiMotion.apply_speed_scale(owner.create_tween())
	tween.tween_interval(0.65)
	tween.tween_property(banner, "modulate:a", 0.0, 0.24)
	tween.tween_callback(banner.queue_free)

func ink_burst(origin: Vector2, color: Color, count: int = 16, glyph: String = "*") -> void:
	if not _ready():
		return
	for i in range(count):
		var spark = _label(glyph, color, randi_range(12, 24))
		spark.position = origin + Vector2(randf_range(-8, 8), randf_range(-8, 8))
		fx_layer.add_child(spark)
		var tween = UiMotion.apply_speed_scale(owner.create_tween())
		tween.set_parallel(true)
		tween.tween_property(spark, "position", spark.position + Vector2(randf_range(-110, 110), randf_range(-60, 72)), randf_range(0.32, 0.54)).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		tween.tween_property(spark, "modulate:a", 0.0, 0.46)
		tween.set_parallel(false)
		tween.tween_callback(spark.queue_free)

func ink_ring(origin: Vector2, color: Color, count: int = 16) -> void:
	for i in range(count):
		var angle = TAU * float(i) / float(max(count, 1))
		var spark = _label("◆", color, 16)
		spark.position = origin
		fx_layer.add_child(spark)
		var tween = UiMotion.apply_speed_scale(owner.create_tween())
		tween.set_parallel(true)
		tween.tween_property(spark, "position", origin + Vector2(cos(angle), sin(angle)) * 88.0, 0.42).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		tween.tween_property(spark, "modulate:a", 0.0, 0.42)
		tween.set_parallel(false)
		tween.tween_callback(spark.queue_free)

func rising_ink(origin: Vector2, color: Color, count: int = 12) -> void:
	for i in range(count):
		var dot = _label("●", color, randi_range(10, 18))
		dot.position = origin + Vector2(randf_range(-28, 28), randf_range(-8, 14))
		fx_layer.add_child(dot)
		var tween = UiMotion.apply_speed_scale(owner.create_tween())
		tween.set_parallel(true)
		tween.tween_property(dot, "position", dot.position + Vector2(randf_range(-18, 18), -78), 0.58).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		tween.tween_property(dot, "modulate:a", 0.0, 0.52)
		tween.set_parallel(false)
		tween.tween_callback(dot.queue_free)

func screen_flash(color: Color) -> void:
	if not _ready():
		return
	var flash = ColorRect.new()
	flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	flash.color = color
	flash.size = Vector2(1920, 1080)
	fx_layer.add_child(flash)
	var tween = UiMotion.apply_speed_scale(owner.create_tween())
	tween.tween_property(flash, "modulate:a", 0.0, 0.24)
	tween.tween_callback(flash.queue_free)

func _ready() -> bool:
	return owner != null and fx_layer != null and is_instance_valid(owner) and is_instance_valid(fx_layer)

func _label(text: String, color: Color, font_size: int) -> Label:
	var label = Label.new()
	label.text = text
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.add_theme_color_override("font_color", color)
	label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.72))
	label.add_theme_constant_override("shadow_offset_x", 2)
	label.add_theme_constant_override("shadow_offset_y", 3)
	label.add_theme_font_size_override("font_size", font_size)
	return label

func _sentence_text(slots: Array) -> String:
	var words: Array[String] = []
	for slot in slots:
		if slot is SentenceBuilder.Slot:
			var word = str(slot.word).strip_edges()
			if not word.is_empty():
				words.append(word)
		elif slot is String and not str(slot).strip_edges().is_empty():
			words.append(str(slot))
	return "".join(words)

func _shatter_label(label: Label, color: Color) -> void:
	if not is_instance_valid(label):
		return
	var center = label.position + Vector2(18, 18)
	label.queue_free()
	ink_burst(center, color, 5, ".")

func _break_color(breakdown: ScoringEngine.ScoreBreakdown) -> Color:
	if breakdown == null:
		return UiTheme.GOLD
	if breakdown.atk >= breakdown.def_ and breakdown.atk >= breakdown.crt:
		return UiTheme.CINNABAR
	if breakdown.def_ >= breakdown.atk and breakdown.def_ >= breakdown.crt:
		return UiTheme.PLAYER_BLUE
	return UiTheme.JADE
