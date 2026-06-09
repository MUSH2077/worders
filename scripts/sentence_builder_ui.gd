extends HBoxContainer

var builder: SentenceBuilder
var slot_scene = preload("res://scenes/sentence_slot.tscn")

func _ready() -> void:
    mouse_filter = MOUSE_FILTER_STOP

func setup(b: SentenceBuilder) -> void:
    builder = b
    _refresh()

func _refresh() -> void:
    for c in get_children():
        if is_instance_valid(c):
            c.free()
    var ordered = builder.get_ordered_slots()
    for i in range(ordered.size()):
        var slot = ordered[i]
        var s = slot_scene.instantiate()
        add_child(s)
        s.setup(slot)
        s.slot_clicked.connect(func(ref): Events.word_input_requested.emit(ref))
        s.slot_removed.connect(func(ref): _remove_slot(ref))
    if ordered.is_empty():
        var hint = Label.new()
        hint.text = "< 将手牌拖入此处 >"
        hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
        hint.add_theme_color_override("font_color", Color(0.5, 0.5, 0.6, 1))
        add_child(hint)

func add_slot(card: CardData) -> void:
    builder.add_card(card)
    _refresh()

func _remove_slot(slot: SentenceBuilder.Slot) -> void:
    var idx = builder.slots.find(slot)
    if idx >= 0:
        var card = slot.card
        builder.slots.remove_at(idx)
        Events.card_returned.emit(card)
        _refresh()

func _can_drop_data(_at_position: Vector2, data) -> bool:
    if data is CardData:
        return true
    return data is Dictionary and data.has("type")

func _drop_data(_at_position: Vector2, data) -> void:
    if data is CardData:
        builder.add_card(data)
        _refresh()
        Events.card_played.emit(data, BattleManager.current_player)
        var last_idx = builder.slots.size() - 1
        if last_idx >= 0:
            Events.word_input_requested.emit(builder.slots[last_idx])
    elif data is Dictionary and data.get("type", "") == "hand_card":
        var card = data.get("card", null) as CardData
        if card:
            builder.add_card(card)
            _refresh()
            Events.card_played.emit(card, BattleManager.current_player)
