class_name BattleChatPanel extends RefCounted

static func style_panel(panel: Panel, style: StyleBox) -> void:
	if panel:
		panel.add_theme_stylebox_override("panel", style)

static func make_message_label(sender: String, text: String, color: Color) -> Label:
	var line = Label.new()
	line.text = "%s: %s" % [sender, text]
	line.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	line.add_theme_color_override("font_color", color)
	line.add_theme_font_size_override("font_size", 14)
	return line

# Chat row with an agent-colored accent bar, a sender chip, and a wrapped body.
# accent drives the bar + sender color; body stays light for readability.
static func make_message_row(sender: String, text: String, accent: Color) -> Control:
	var row = HBoxContainer.new()
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_theme_constant_override("separation", 6)

	var bar = ColorRect.new()
	bar.color = accent
	bar.custom_minimum_size = Vector2(3, 0)
	bar.size_flags_vertical = Control.SIZE_EXPAND_FILL
	row.add_child(bar)

	var body = VBoxContainer.new()
	body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override("separation", 1)

	var sender_label = Label.new()
	sender_label.text = sender
	sender_label.add_theme_color_override("font_color", accent)
	sender_label.add_theme_font_size_override("font_size", 12)
	body.add_child(sender_label)

	var message_label = Label.new()
	message_label.text = text
	message_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	message_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	message_label.add_theme_color_override("font_color", Color(0.92, 0.95, 1.0, 1.0))
	message_label.add_theme_font_size_override("font_size", 14)
	body.add_child(message_label)

	row.add_child(body)
	return row

static func prune_log(log: VBoxContainer, max_lines: int) -> void:
	while log and log.get_child_count() >= max_lines:
		var old = log.get_child(0)
		log.remove_child(old)
		old.queue_free()

static func make_bubble(text: String, color: Color, style: StyleBox) -> Panel:
	var bubble = Panel.new()
	bubble.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var emoji_like = text.length() <= 3
	bubble.size = Vector2(92, 48) if emoji_like else Vector2(132, 44)
	bubble.add_theme_stylebox_override("panel", style)
	var label = Label.new()
	label.layout_mode = 1
	label.anchors_preset = Control.PRESET_FULL_RECT
	label.anchor_right = 1.0
	label.anchor_bottom = 1.0
	label.text = text
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_color_override("font_color", color)
	label.add_theme_font_size_override("font_size", 24 if emoji_like else 16)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bubble.add_child(label)
	return bubble
