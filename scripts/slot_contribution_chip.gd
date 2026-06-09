class_name SlotContributionChip extends HBoxContainer

const ATK_COLOR := Color(0.95, 0.22, 0.14, 1.0)
const DEF_COLOR := Color(0.28, 0.68, 1.0, 1.0)
const CRT_COLOR := Color(0.98, 0.76, 0.28, 1.0)

func _ready() -> void:
	alignment = BoxContainer.ALIGNMENT_CENTER
	add_theme_constant_override("separation", 4)
	mouse_filter = Control.MOUSE_FILTER_IGNORE

func set_deltas(delta: Dictionary) -> void:
	for child in get_children():
		child.queue_free()
	if delta.is_empty():
		visible = false
		return
	_add_badge(I18n.t("attack_short"), int(delta.get("atk", 0)), ATK_COLOR)
	_add_badge(I18n.t("defense_short"), int(delta.get("def", 0)), DEF_COLOR)
	_add_badge(I18n.t("crit_short"), int(delta.get("crt", 0)), CRT_COLOR)
	visible = get_child_count() > 0

func _add_badge(prefix: String, value: int, color: Color) -> void:
	if value == 0:
		return
	var badge = Label.new()
	badge.text = "%s%s%d" % [prefix, "+" if value > 0 else "", value]
	badge.add_theme_font_size_override("font_size", 11)
	badge.add_theme_color_override("font_color", color)
	badge.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.72))
	badge.add_theme_constant_override("shadow_offset_y", 1)
	add_child(badge)
