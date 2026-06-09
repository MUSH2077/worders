extends Panel

var slot_ref: SentenceBuilder.Slot

func _get_drag_data(_at_position: Vector2):
    if slot_ref == null:
        return null
    var preview = Panel.new()
    preview.custom_minimum_size = Vector2(120, 50)
    var style = StyleBoxFlat.new()
    style.bg_color = Color(0.3, 0.3, 0.4, 0.8)
    style.border_width_left = 1; style.border_width_right = 1
    style.border_width_top = 1; style.border_width_bottom = 1
    style.border_color = Color(0.5, 0.5, 0.7, 1)
    preview.add_theme_stylebox_override("panel", style)
    var lbl = Label.new()
    lbl.text = slot_ref.card.card_name
    lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    lbl.add_theme_color_override("font_color", Color(1, 1, 1, 1))
    preview.add_child(lbl)
    set_drag_preview(preview)
    return {"type": "sentence_slot", "slot": slot_ref, "source_node": self}

func _can_drop_data(_at_position: Vector2, data) -> bool:
    return data is Dictionary and data.has("type")

func _drop_data(_at_position: Vector2, data) -> void:
    var scene = get_tree().current_scene
    if scene and scene.has_method("_handle_slot_drop"):
        scene._handle_slot_drop(data, slot_ref)
