extends Panel

signal slot_clicked(slot_ref)
signal slot_removed(slot_ref)

var slot_ref: SentenceBuilder.Slot = null

@onready var comp_lbl: Label = $CompLabel
@onready var word_lbl: Label = $WordLabel

func setup(slot: SentenceBuilder.Slot) -> void:
    slot_ref = slot
    comp_lbl.text = slot.card.get_comp_name()
    word_lbl.text = slot.word if slot.is_filled() else "___"

func set_word(w: String) -> void:
    word_lbl.text = w

func _gui_input(event: InputEvent) -> void:
    if event is InputEventMouseButton and event.pressed:
        if event.button_index == MOUSE_BUTTON_LEFT:
            slot_clicked.emit(slot_ref)
        elif event.button_index == MOUSE_BUTTON_RIGHT:
            slot_removed.emit(slot_ref)
