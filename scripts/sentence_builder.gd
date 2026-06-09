class_name SentenceBuilder extends RefCounted

const COMPONENT_ORDER = [
    CardData.SentenceComponent.ATTRIBUTE,
    CardData.SentenceComponent.SUBJECT,
    CardData.SentenceComponent.ADVERBIAL,
    CardData.SentenceComponent.PREDICATE,
    CardData.SentenceComponent.COMPLEMENT,
    CardData.SentenceComponent.OBJECT,
]

class Slot:
    var card: CardData
    var word: String = ""
    func _init(c: CardData):
        card = c
    func is_filled() -> bool:
        return not word.is_empty()
    func get_component() -> int:
        return card.comp_constraint

var slots: Array[Slot] = []

func add_card(card: CardData, target_index: int = -1) -> Slot:
    var slot = Slot.new(card)
    if target_index >= 0 and target_index <= slots.size():
        slots.insert(target_index, slot)
    else:
        slots.append(slot)
        sort_slots_by_component()
    return slot

func sort_slots_by_component() -> void:
    slots.sort_custom(func(a: Slot, b: Slot):
        var ia = COMPONENT_ORDER.find(a.get_component())
        var ib = COMPONENT_ORDER.find(b.get_component())
        if ia == -1:
            ia = 999
        if ib == -1:
            ib = 999
        return ia < ib)

func move_slot(slot: Slot, target_index: int) -> void:
    var current_index = slots.find(slot)
    if current_index < 0:
        return
    target_index = clampi(target_index, 0, slots.size())
    if current_index == target_index:
        return
    slots.remove_at(current_index)
    if current_index < target_index:
        target_index -= 1
    target_index = clampi(target_index, 0, slots.size())
    slots.insert(target_index, slot)

func get_slot_index(slot: Slot) -> int:
    return slots.find(slot)

func remove_card_at(index: int) -> void:
    if index >= 0 and index < slots.size():
        slots.remove_at(index)

func set_word(index: int, word: String) -> void:
    if index >= 0 and index < slots.size():
        slots[index].word = word

func clear() -> void:
    slots.clear()

func get_ordered_slots() -> Array[Slot]:
    return slots.duplicate()

func get_sentence_input() -> ScoringEngine.SentenceInput:
    var input = ScoringEngine.SentenceInput.new()
    var ordered = get_ordered_slots()
    for slot in ordered:
        input.cards.append(slot.card)
        input.words.append(slot.word)
        input.components.append(slot.get_component())
    return input

func get_total_mana_cost(_base_cost: float = 0.0, _char_coef: float = 1.0) -> int:
    var total = 0
    for slot in slots:
        total += max(1, slot.card.mana_cost)
    return total

func is_complete() -> bool:
    if slots.is_empty():
        return false
    for slot in slots:
        if not slot.is_filled():
            return false
    return true

func get_missing_components() -> Array:
    var present: Dictionary = {}
    for slot in slots:
        present[slot.get_component()] = true
    var missing: Array = []
    for req in StructureValidator.REQUIRED_COMPONENTS:
        if not present.has(req):
            missing.append(req)
    return missing
