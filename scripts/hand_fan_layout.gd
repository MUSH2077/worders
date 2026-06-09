class_name HandFanLayout extends Control

signal card_double_clicked(card: CardData)
signal card_drag_started(card: CardData, source_node: Control)

const CARD_SCENE = preload("res://scenes/card.tscn")

var _cards: Array[CardData] = []
var _enabled := true
var _hovered_index := -1
var _card_nodes: Array[Control] = []
var _back_nodes: Array[TextureRect] = []
var _card_back: Texture2D = null

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	resized.connect(_layout_cards)

func set_cards(cards: Array[CardData]) -> void:
	_clear_children()
	_cards = cards.duplicate()
	_card_nodes.clear()
	_hovered_index = -1
	for i in range(_cards.size()):
		var card_node = CARD_SCENE.instantiate() as Control
		card_node.card_data = _cards[i]
		card_node.card_clicked.connect(func(card): card_double_clicked.emit(card))
		if card_node.has_signal("drag_started"):
			card_node.drag_started.connect(func(card, source_node): card_drag_started.emit(card, source_node))
		card_node.mouse_entered.connect(func(): _set_hovered(card_node))
		card_node.mouse_exited.connect(func(): _clear_hovered(card_node))
		add_child(card_node)
		_card_nodes.append(card_node)
	_layout_cards()

func set_card_backs(count: int, texture: Texture2D) -> void:
	_clear_children()
	_cards.clear()
	_card_nodes.clear()
	_back_nodes.clear()
	_card_back = texture
	for i in range(count):
		var back = TextureRect.new()
		back.texture = texture
		back.mouse_filter = Control.MOUSE_FILTER_IGNORE
		back.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		back.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
		back.custom_minimum_size = Vector2(96, 136)
		add_child(back)
		_back_nodes.append(back)
	_layout_backs()

func set_enabled(enabled: bool) -> void:
	_enabled = enabled
	for card in _card_nodes:
		card.mouse_filter = Control.MOUSE_FILTER_STOP if enabled else Control.MOUSE_FILTER_IGNORE

func card_count() -> int:
	return _card_nodes.size() + _back_nodes.size()

func get_card_nodes() -> Array[Control]:
	return _card_nodes.duplicate()

func get_card_rects() -> Array[Rect2]:
	var rects: Array[Rect2] = []
	for card in _card_nodes:
		rects.append(Rect2(card.position, card.size * card.scale))
	for back in _back_nodes:
		rects.append(Rect2(back.position, back.size * back.scale))
	return rects

func _can_drop_data(_at_position: Vector2, data) -> bool:
	return data is Dictionary and data.get("type", "") == "sentence_slot"

func _drop_data(_at_position: Vector2, data) -> void:
	var scene = get_tree().current_scene
	if scene and scene.has_method("_handle_hand_drop"):
		scene._handle_hand_drop(data)

func _clear_children() -> void:
	for child in get_children():
		remove_child(child)
		child.queue_free()
	_card_nodes.clear()
	_back_nodes.clear()

func _set_hovered(card_node: Control) -> void:
	_hovered_index = _card_nodes.find(card_node)
	_layout_cards()

func _clear_hovered(card_node: Control) -> void:
	if _hovered_index == _card_nodes.find(card_node):
		_hovered_index = -1
		_layout_cards()

func _layout_cards() -> void:
	if _card_nodes.is_empty():
		return
	var count = _card_nodes.size()
	var viewport_width = max(size.x, 1.0)
	var card_size = _card_size_for_count(count, viewport_width)
	var center = Vector2(size.x * 0.5, size.y * 0.72)
	var max_angle = clampf(4.0 + float(count) * 2.4, 10.0, 30.0)
	var usable_width = max(size.x - card_size.x - 12.0, card_size.x)
	var base_step = min(card_size.x * 0.76, usable_width / float(max(count - 1, 1)))
	if count > 10:
		base_step = min(base_step, card_size.x * 0.58)
	var start_x = center.x - base_step * float(count - 1) * 0.5
	for i in range(count):
		var card = _card_nodes[i]
		var t = 0.0 if count == 1 else (float(i) / float(count - 1) - 0.5) * 2.0
		var lift = -abs(t) * 22.0
		var hover = i == _hovered_index
		var local_scale = 1.0
		if count > 12:
			local_scale = 0.88
		elif count > 9:
			local_scale = 0.94
		if hover:
			local_scale += 0.18
			lift -= 58.0
		card.size = card_size
		card.custom_minimum_size = card_size
		card.pivot_offset = card_size * 0.5
		card.position = Vector2(start_x + base_step * float(i) - card_size.x * 0.5, center.y + lift - card_size.y * 0.5)
		card.rotation_degrees = t * max_angle if not hover else 0.0
		card.scale = Vector2(local_scale, local_scale)
		card.z_index = 100 + i if hover else i

func _layout_backs() -> void:
	if _back_nodes.is_empty():
		return
	var count = _back_nodes.size()
	var card_size = Vector2(96, 136)
	var step = min(34.0, max(18.0, size.x / float(max(count + 2, 1))))
	var center = Vector2(size.x * 0.5, size.y * 0.62)
	var start_x = center.x - step * float(count - 1) * 0.5
	for i in range(count):
		var back = _back_nodes[i]
		back.size = card_size
		back.position = Vector2(start_x + step * float(i) - card_size.x * 0.5, center.y - card_size.y * 0.5)
		back.rotation_degrees = -12.0 + 24.0 * float(i) / float(max(count - 1, 1))
		back.z_index = i

func _card_size_for_count(count: int, viewport_width: float) -> Vector2:
	if viewport_width <= 900.0:
		return Vector2(122, 158)
	if count > 12:
		return Vector2(126, 164)
	if count > 9:
		return Vector2(138, 178)
	return Vector2(154, 196)
