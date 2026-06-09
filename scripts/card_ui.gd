extends Panel

const NOTO_FONT = preload("res://resources/NotoSansSC.ttf")

signal card_clicked(card_data)
signal drag_started(card_data, source_node)

var _card_data: CardData = null
@export var card_data: CardData:
	get:
		return _card_data
	set(value):
		_debug_log("card_ui SETTER called value=%s type=%s" % [str(value), typeof(value)])
		_card_data = value
		_debug_log("card_ui SETTER after assign _card_data=%s" % str(_card_data))
		_update()

var _hover_tween: Tween
var _base_modulate: Color = Color.WHITE
var _drag_visual_active := false
var _pre_drag_mouse_filter := Control.MOUSE_FILTER_STOP
var _pre_drag_visible := true

func _safe_i18n() -> Node:
	var tree = Engine.get_main_loop() as SceneTree
	if tree and tree.root.has_node("I18n"):
		return tree.root.get_node("I18n")
	return null

func _safe_t(key: String) -> String:
	var i18n = _safe_i18n()
	if i18n:
		return i18n.t(key)
	return key

@onready var name_lbl: Label = $MarginContainer/VBoxContainer/NameLabel
@onready var pos_lbl: Label = $MarginContainer/VBoxContainer/PosLabel
@onready var comp_lbl: Label = $MarginContainer/VBoxContainer/CompLabel
@onready var cont_lbl: Label = $MarginContainer/VBoxContainer/ContentLabel
@onready var dis_lbl: Label = $MarginContainer/VBoxContainer/DisorderLabel

func _debug_log(msg: String) -> void:
	var f = FileAccess.open("user://export_debug.log", FileAccess.READ_WRITE)
	if f:
		f.seek_end()
		f.store_line("%s: %s" % [Time.get_datetime_string_from_system(), msg])
		f.close()

func _ready() -> void:
	_debug_log("card_ui._ready() card_data=%s" % str(_card_data))
	mouse_filter = MOUSE_FILTER_STOP
	_ignore_child_mouse(get_node("MarginContainer"))
	_apply_card_style()
	for lbl in [name_lbl, pos_lbl, comp_lbl, cont_lbl, dis_lbl]:
		lbl.add_theme_font_override("font", NOTO_FONT)
	_debug_log("card_ui._ready() size=%s" % str(size))
	_base_modulate = modulate
	pivot_offset = size * 0.5
	mouse_entered.connect(_on_mouse_entered)
	mouse_exited.connect(_on_mouse_exited)
	var i18n = _safe_i18n()
	if i18n:
		i18n.language_changed.connect(_update)
	_update()
	_debug_log("card_ui._ready() END card=%s" % _card_data.get_display_name() if _card_data else "null")

func _ignore_child_mouse(node: Node) -> void:
	if node is Control:
		node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for child in node.get_children():
		_ignore_child_mouse(child)

func _update() -> void:
	if _card_data == null or not is_node_ready():
		_debug_log("card_ui._update() EARLY RETURN card_data=%s is_node_ready=%s" % [str(_card_data), is_node_ready()])
		return
	_debug_log("card_ui._update() card=%s ready=%s" % [_card_data.get_display_name(), is_node_ready()])
	_apply_card_style()
	name_lbl.text = _card_data.get_display_name()
	pos_lbl.text = _safe_t("card_type") + _card_data.get_type_name()
	if _card_data.card_type == CardData.CardType.FILL:
		comp_lbl.text = _safe_t("card_role") + _card_data.get_comp_name()
		cont_lbl.text = _safe_t("card_theme") + _card_data.get_content_name()
		dis_lbl.text = _safe_t("card_chaos") + str(_card_data.base_disorder)
	else:
		comp_lbl.text = _safe_t("card_effect") + _card_data.get_effect_name()
		cont_lbl.text = _safe_t("card_cost") + str(_card_data.mana_cost)
		dis_lbl.text = _safe_t("card_theme") + _card_data.get_content_name()
	var tightness = clampi(_card_data.get_constraint_count(), 0, 3)
	dis_lbl.modulate = [
		Color(0.62, 0.9, 0.72, 1),
		Color(0.95, 0.86, 0.42, 1),
		Color(1.0, 0.58, 0.28, 1),
		Color(1.0, 0.34, 0.3, 1),
	][tightness]
	tooltip_text = _safe_t("card_tooltip")

func _apply_card_style() -> void:
	var style = UiTheme.card_style(_card_data)
	var palette = _card_palette()
	add_theme_stylebox_override("panel", style)
	if is_node_ready():
		name_lbl.add_theme_color_override("font_color", palette["title"])
		pos_lbl.add_theme_color_override("font_color", Color(0.86, 0.91, 1.0, 0.86))
		comp_lbl.add_theme_color_override("font_color", palette["border"])
		cont_lbl.add_theme_color_override("font_color", palette["accent"])

func _card_palette() -> Dictionary:
	var bg = Color(0.07, 0.085, 0.115, 0.96)
	var type_tint = Color(0.0, 0.0, 0.0, 0.0)
	if _card_data:
		match _card_data.card_type:
			CardData.CardType.FILL:
				type_tint = Color(0.02, 0.03, 0.06, 0.0)
			CardData.CardType.FUNCTION:
				type_tint = Color(0.10, -0.02, -0.02, 0.0)
			CardData.CardType.EQUIPMENT:
				type_tint = Color(-0.02, 0.08, 0.04, 0.0)
			CardData.CardType.STATUS:
				type_tint = Color(0.04, -0.02, 0.10, 0.0)
	bg = Color(
		clampf(bg.r + type_tint.r, 0.0, 1.0),
		clampf(bg.g + type_tint.g, 0.0, 1.0),
		clampf(bg.b + type_tint.b, 0.0, 1.0),
		bg.a
	)
	var border = UiTheme.card_color(_card_data)
	var accent = UiTheme.content_color(_card_data.content_constraint) if _card_data else Color(0.86, 0.91, 1, 1)
	return {
		"bg": bg,
		"border": border,
		"accent": accent,
		"title": Color(
			min(1.0, border.r + 0.18),
			min(1.0, border.g + 0.18),
			min(1.0, border.b + 0.18),
			1.0
		),
	}

func _component_color(comp: int) -> Color:
	return UiTheme.component_color(comp)

func _content_color(category: int) -> Color:
	return UiTheme.content_color(category)

func _get_drag_data(_at_position: Vector2):
	_debug_log("_get_drag_data() card=%s" % str(_card_data))
	if _card_data == null:
		return null
	_begin_drag_visual()
	var preview = Panel.new()
	preview.custom_minimum_size = Vector2(160, 200)
	preview.size = Vector2(160, 200)
	var style = StyleBoxFlat.new()
	var palette = _card_palette()
	style.bg_color = palette["bg"]
	style.border_width_left = 2
	style.border_width_right = 2
	style.border_width_top = 2
	style.border_width_bottom = 2
	style.border_color = palette["border"]
	style.corner_radius_top_left = 8
	style.corner_radius_top_right = 8
	style.corner_radius_bottom_left = 8
	style.corner_radius_bottom_right = 8
	preview.add_theme_stylebox_override("panel", style)

	var margin = MarginContainer.new()
	margin.layout_mode = 1
	margin.anchors_preset = PRESET_FULL_RECT
	margin.anchor_right = 1.0
	margin.anchor_bottom = 1.0
	margin.add_theme_constant_override("margin_left", 10)
	margin.add_theme_constant_override("margin_top", 12)
	margin.add_theme_constant_override("margin_right", 10)
	margin.add_theme_constant_override("margin_bottom", 12)
	preview.add_child(margin)

	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 8)
	margin.add_child(vbox)

	var title = Label.new()
	title.text = _card_data.get_display_name()
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_color_override("font_color", palette["title"])
	title.add_theme_font_size_override("font_size", 18)
	title.add_theme_font_override("font", NOTO_FONT)
	vbox.add_child(title)

	var detail = Label.new()
	if _card_data.card_type == CardData.CardType.FILL:
		detail.text = "%s\n%s\n%s" % [_card_data.get_pos_name(), _card_data.get_comp_name(), _card_data.get_content_name()]
	else:
		detail.text = "%s\n%s %d" % [_card_data.get_effect_name(), _safe_t("card_cost"), _card_data.mana_cost]
	detail.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	detail.add_theme_color_override("font_color", palette["accent"])
	detail.add_theme_font_size_override("font_size", 13)
	detail.add_theme_font_override("font", NOTO_FONT)
	vbox.add_child(detail)

	if get_viewport() and get_viewport().gui_is_dragging():
		set_drag_preview(preview)
	else:
		preview.free()
	drag_started.emit(_card_data, self)
	return {"type": "hand_card", "card": _card_data, "source_node": self}

func _notification(what: int) -> void:
	if what == NOTIFICATION_DRAG_END and _drag_visual_active:
		call_deferred("_restore_drag_visual")

func _begin_drag_visual() -> void:
	if _drag_visual_active:
		return
	if _hover_tween:
		_hover_tween.kill()
	_drag_visual_active = true
	_pre_drag_visible = visible
	_pre_drag_mouse_filter = mouse_filter
	visible = false
	mouse_filter = Control.MOUSE_FILTER_IGNORE

func _restore_drag_visual() -> void:
	if not _drag_visual_active:
		return
	_drag_visual_active = false
	visible = _pre_drag_visible
	mouse_filter = _pre_drag_mouse_filter
	modulate = _base_modulate
	scale = Vector2.ONE
	z_index = 0

func _can_drop_data(_at_position: Vector2, data) -> bool:
	return data is Dictionary and data.get("type", "") == "sentence_slot"

func _drop_data(_at_position: Vector2, data) -> void:
	var scene = get_tree().current_scene
	if scene and scene.has_method("_handle_hand_drop"):
		scene._handle_hand_drop(data)

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		_debug_log("_gui_input() btn=%d pressed=%s dbl=%s" % [event.button_index, event.pressed, event.double_click])
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT and event.double_click:
		card_clicked.emit(_card_data)

func _on_mouse_entered() -> void:
	if _hover_tween:
		_hover_tween.kill()
	pivot_offset = size * 0.5
	z_index = 20
	_hover_tween = create_tween()
	_hover_tween.set_parallel(true)
	_hover_tween.tween_property(self, "scale", Vector2(1.045, 1.045), 0.12).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_hover_tween.tween_property(self, "modulate", Color(1.08, 1.06, 1.0, 1), 0.12)

func _on_mouse_exited() -> void:
	if _hover_tween:
		_hover_tween.kill()
	_hover_tween = create_tween()
	_hover_tween.set_parallel(true)
	_hover_tween.tween_property(self, "scale", Vector2.ONE, 0.16).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_hover_tween.tween_property(self, "modulate", _base_modulate, 0.16)
	_hover_tween.set_parallel(false)
	_hover_tween.tween_callback(func(): z_index = 0)
