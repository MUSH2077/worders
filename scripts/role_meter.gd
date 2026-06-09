class_name RoleMeter extends Panel

const RING_PLAYER = preload("res://resources/art/ui/ui_avatar_ring_player.png")
const RING_AI = preload("res://resources/art/ui/ui_avatar_ring_ai.png")

var _player: Player = null
var _is_ai := false
var _hp_ratio := 1.0
var _shield_ratio := 0.0
var _mana_ratio := 0.0
var _ring_texture: Texture2D = null
var _pulse_tween: Tween = null

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_PASS

func set_player(player: Player, is_ai: bool) -> void:
	_player = player
	_is_ai = is_ai
	_ring_texture = RING_AI if is_ai else RING_PLAYER
	if player:
		_hp_ratio = _safe_ratio(player.hp, player.max_hp)
		_shield_ratio = clampf(float(player.shield) / 30.0, 0.0, 1.0)
		_mana_ratio = _safe_ratio(player.mana, max(player.max_mana, 1))
	_update_labels()
	queue_redraw()

func play_hp_change(_from, _to) -> void:
	_pulse(Color(1.0, 0.22, 0.18, 0.32))

func play_shield_change(_from, _to) -> void:
	_pulse(Color(0.25, 0.68, 1.0, 0.28))

func play_mana_change(_from, _to) -> void:
	_pulse(Color(0.98, 0.72, 0.28, 0.26))

func _draw() -> void:
	var center = _avatar_center()
	var radius = _avatar_radius()
	var ring_rect = Rect2(center - Vector2(radius, radius), Vector2(radius * 2.0, radius * 2.0))
	if _ring_texture:
		draw_texture_rect(_ring_texture, ring_rect, false, Color(1, 1, 1, 0.98))
	draw_circle(center, radius * 0.70, Color(0.014, 0.018, 0.028, 0.78))
	_draw_arc(center, radius * 0.86, -100.0, -100.0 + 340.0 * _hp_ratio, Color(0.95, 0.18, 0.12, 1.0), 7.0)
	_draw_arc(center, radius * 0.75, 210.0, 210.0 + 120.0 * _shield_ratio, Color(0.24, 0.68, 1.0, 0.92), 5.0)
	_draw_mana_beads(center + Vector2(0, radius * 0.68), radius * 0.13)
	_draw_badge(center + Vector2(radius * 0.72, radius * 0.42), _deck_count(), Color(0.95, 0.72, 0.28, 0.92))
	_draw_status_bars()

func _draw_arc(center: Vector2, radius: float, start_deg: float, end_deg: float, color: Color, width: float) -> void:
	if end_deg <= start_deg:
		return
	var points = PackedVector2Array()
	var steps = max(6, int(abs(end_deg - start_deg) / 8.0))
	for i in range(steps + 1):
		var angle = deg_to_rad(lerpf(start_deg, end_deg, float(i) / float(steps)))
		points.append(center + Vector2(cos(angle), sin(angle)) * radius)
	draw_polyline(points, color, width, true)

func _draw_mana_beads(origin: Vector2, bead_radius: float) -> void:
	var max_mana = _player.max_mana if _player else 0
	var mana = _player.mana if _player else 0
	var count = clampi(max_mana, 0, 10)
	if count <= 0:
		return
	var spacing = bead_radius * 2.35
	var start_x = origin.x - spacing * float(count - 1) * 0.5
	for i in range(count):
		var filled = i < mana
		var color = Color(0.95, 0.70, 0.25, 1.0) if filled else Color(0.17, 0.13, 0.09, 0.85)
		draw_circle(Vector2(start_x + spacing * float(i), origin.y), bead_radius, color)
		draw_arc(Vector2(start_x + spacing * float(i), origin.y), bead_radius, 0.0, TAU, 16, Color(1.0, 0.86, 0.46, 0.72), 1.3)

func _draw_badge(pos: Vector2, value: int, color: Color) -> void:
	draw_circle(pos, 18.0, Color(0.025, 0.030, 0.045, 0.95))
	draw_arc(pos, 18.0, 0.0, TAU, 24, color, 2.0)

func _update_labels() -> void:
	var avatar = get_node_or_null("AIAvatarLabel" if _is_ai else "PlayerAvatarLabel") as Label
	var stats = get_node_or_null("AIStatsLabel" if _is_ai else "PlayerStatsLabel") as Label
	var deck_badge = _ensure_label("DeckBadgeLabel")
	var shield_badge = _ensure_label("ShieldBadgeLabel")
	if avatar:
		avatar.text = "AI" if _is_ai else I18n.t("you")
		var center = _avatar_center()
		avatar.position = Vector2(center.x - _avatar_radius() * 0.62, center.y - 24.0)
		avatar.size = Vector2(_avatar_radius() * 1.24, 34)
		avatar.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		avatar.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		avatar.add_theme_font_size_override("font_size", 24 if _is_ai else 26)
		avatar.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.72))
		avatar.add_theme_constant_override("shadow_offset_y", 2)
	if stats:
		stats.visible = false
	if deck_badge:
		deck_badge.text = str(_deck_count())
		deck_badge.position = _avatar_center() + Vector2(_avatar_radius() * 0.48, _avatar_radius() * 0.52) - Vector2(18, 12)
		deck_badge.size = Vector2(36, 24)
		deck_badge.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		deck_badge.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		deck_badge.add_theme_color_override("font_color", Color(1.0, 0.86, 0.46, 1.0))
		deck_badge.add_theme_font_size_override("font_size", 12)
	if shield_badge:
		shield_badge.text = str(_player.shield if _player else 0)
		shield_badge.position = _avatar_center() + Vector2(-_avatar_radius() * 0.73, _avatar_radius() * 0.52) - Vector2(18, 12)
		shield_badge.size = Vector2(36, 24)
		shield_badge.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		shield_badge.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		shield_badge.add_theme_color_override("font_color", Color(0.58, 0.84, 1.0, 1.0))
		shield_badge.add_theme_font_size_override("font_size", 12)
	_update_status_rows()

func _ensure_label(node_name: String) -> Label:
	var label = get_node_or_null(node_name) as Label
	if label == null:
		label = Label.new()
		label.name = node_name
		label.mouse_filter = Control.MOUSE_FILTER_PASS
		add_child(label)
	return label

func _update_status_rows() -> void:
	var rows = [
		["HP", I18n.t("hp"), _hp_text(), Color(1.0, 0.38, 0.30, 1.0), I18n.t("stat_hp_tooltip")],
		["Shield", I18n.t("shield"), str(_player.shield if _player else 0), Color(0.45, 0.80, 1.0, 1.0), I18n.t("stat_shield_tooltip")],
		["Mana", I18n.t("mana"), _mana_text(), Color(0.98, 0.76, 0.32, 1.0), I18n.t("stat_mana_tooltip")],
		["Deck", I18n.t("deck"), str(_deck_count()), Color(0.92, 0.82, 0.58, 1.0), I18n.t("stat_deck_tooltip")],
	]
	var side_x = _status_left()
	var label_w = clampf(size.x - side_x - 70.0, 56.0, 86.0)
	var value_x = side_x + label_w + 8.0
	var value_w = max(46.0, size.x - value_x - 14.0)
	for i in range(rows.size()):
		var row = rows[i]
		var y = _status_top() + float(i) * _status_row_gap()
		var name_label = _ensure_label("%sLabel" % row[0])
		var value_label = _ensure_label("%sValueLabel" % row[0])
		name_label.text = str(row[1])
		name_label.position = Vector2(side_x, y)
		name_label.size = Vector2(label_w, 22)
		name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
		name_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		name_label.tooltip_text = str(row[4])
		name_label.add_theme_color_override("font_color", row[3])
		name_label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.82))
		name_label.add_theme_constant_override("shadow_offset_y", 2)
		name_label.add_theme_font_size_override("font_size", 15)
		value_label.text = str(row[2])
		value_label.position = Vector2(value_x, y)
		value_label.size = Vector2(value_w, 22)
		value_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		value_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		value_label.tooltip_text = str(row[4])
		value_label.add_theme_color_override("font_color", Color(1.0, 0.98, 0.90, 1.0))
		value_label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.82))
		value_label.add_theme_constant_override("shadow_offset_y", 2)
		value_label.add_theme_font_size_override("font_size", 17)

func _draw_status_bars() -> void:
	if size.x < size.y * 1.35:
		return
	var side_x = _status_left()
	var bar_x = side_x + 74.0
	var bar_w = max(50.0, size.x - bar_x - 14.0)
	var ratios = [_hp_ratio, _shield_ratio, _mana_ratio, 0.0]
	var colors = [
		Color(0.95, 0.18, 0.12, 0.48),
		Color(0.24, 0.68, 1.0, 0.42),
		Color(0.98, 0.72, 0.28, 0.42),
		Color(0.92, 0.82, 0.58, 0.20),
	]
	for i in range(ratios.size()):
		var y = _status_top() + float(i) * _status_row_gap() + 18.0
		var rect = Rect2(Vector2(bar_x, y), Vector2(bar_w, 3.0))
		draw_rect(rect, Color(0.02, 0.025, 0.034, 0.84), true)
		if ratios[i] > 0.0:
			draw_rect(Rect2(rect.position, Vector2(rect.size.x * ratios[i], rect.size.y)), colors[i], true)

func _avatar_center() -> Vector2:
	if size.x >= size.y * 1.35:
		return Vector2(min(size.y * 0.52, 76.0), size.y * 0.5)
	return size * 0.5

func _avatar_radius() -> float:
	var width_limit = size.x * 0.48
	if size.x >= size.y * 1.35:
		width_limit = size.x * 0.22
	return min(size.y * 0.44, width_limit)

func _status_left() -> float:
	return max(_avatar_center().x + _avatar_radius() + 18.0, size.x * 0.43)

func _status_top() -> float:
	return max(14.0, size.y * 0.12)

func _status_row_gap() -> float:
	return max(25.0, (size.y - _status_top() - 18.0) / 4.0)

func _hp_text() -> String:
	if _player == null:
		return "0/0"
	return "%d/%d" % [_player.hp, _player.max_hp]

func _mana_text() -> String:
	if _player == null:
		return "0/0"
	return "%d/%d" % [_player.mana, _player.max_mana]

func _pulse(color: Color) -> void:
	if _pulse_tween:
		_pulse_tween.kill()
	self_modulate = Color(1, 1, 1, 1)
	_pulse_tween = create_tween()
	_pulse_tween.tween_property(self, "self_modulate", Color(1.0 + color.r, 1.0 + color.g, 1.0 + color.b, 1.0), 0.08)
	_pulse_tween.tween_property(self, "self_modulate", Color.WHITE, 0.18)

func _safe_ratio(value: int, max_value: int) -> float:
	if max_value <= 0:
		return 0.0
	return clampf(float(value) / float(max_value), 0.0, 1.0)

func _deck_count() -> int:
	if _player == null or _player.deck == null:
		return 0
	return _player.deck.size()
