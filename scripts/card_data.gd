class_name CardData extends Resource

enum CardType { FILL, FUNCTION, EQUIPMENT, STATUS }
enum CardEffect { NONE, DRAW, SHIELD, HEAL, MANA, WEAKEN, CLEANSE, STEAL, SEAL, ECHO }
enum PartOfSpeech { NOUN, VERB, ADJECTIVE, ADVERB, PREPOSITION, CONJUNCTION, INTERJECTION, ANY }
enum SentenceComponent { SUBJECT, PREDICATE, OBJECT, ATTRIBUTE, ADVERBIAL, COMPLEMENT, ANY }
enum ContentCategory { COLOR, ANIMAL, EMOTION, ACTION, NATURE, BODY, ARTIFACT, ABSTRACT, TIME, SPACE, ANY }

const TYPE_LABELS = ["Fill", "Function", "Equipment", "Status"]
const EFFECT_LABELS = ["None", "Draw", "Shield", "Heal", "Mana", "Weaken", "Cleanse", "Steal", "Seal", "Echo"]
const POS_LABELS = ["Noun", "Verb", "Adjective", "Adverb", "Preposition", "Conjunction", "Interjection", "Any"]
const COMPONENT_LABELS = ["Subject", "Predicate", "Object", "Attribute", "Adverbial", "Complement", "Any"]
const CONTENT_LABELS = ["Color", "Animal", "Emotion", "Action", "Nature", "Body", "Artifact", "Abstract", "Time", "Space", "Any"]

@export var id: int
@export var card_name: String
@export var card_type: CardType = CardType.FILL
@export var rarity: int = 1
@export var pos_constraint: PartOfSpeech = PartOfSpeech.ANY
@export var comp_constraint: SentenceComponent = SentenceComponent.ANY
@export var content_constraint: ContentCategory = ContentCategory.ANY
@export var base_disorder: float = 10.0
@export var mana_cost: int = 1
@export var effect: CardEffect = CardEffect.NONE
@export var effect_value: int = 0
@export var duration_turns: int = 0
@export var description: String = ""

func get_constraint_count() -> int:
	var count = 0
	if pos_constraint != PartOfSpeech.ANY:
		count += 1
	if comp_constraint != SentenceComponent.ANY:
		count += 1
	if content_constraint != ContentCategory.ANY:
		count += 1
	return count

func get_pos_name() -> String:
	var i18n = _i18n()
	if i18n:
		return i18n.pos_label(pos_constraint)
	return POS_LABELS[pos_constraint]

func get_comp_name() -> String:
	var i18n = _i18n()
	if i18n:
		return i18n.component_label(comp_constraint)
	return COMPONENT_LABELS[comp_constraint]

func get_content_name() -> String:
	var i18n = _i18n()
	if i18n:
		return i18n.content_label(content_constraint)
	return CONTENT_LABELS[content_constraint]

func get_display_name() -> String:
	var i18n = _i18n()
	if i18n:
		return i18n.card_name(self)
	return card_name

func get_type_name() -> String:
	var i18n = _i18n()
	if i18n:
		return i18n.card_type_label(card_type)
	return TYPE_LABELS[card_type]

func get_effect_name() -> String:
	var i18n = _i18n()
	if i18n:
		return i18n.card_effect_label(effect)
	return EFFECT_LABELS[effect]

func _i18n() -> Node:
	var tree = Engine.get_main_loop() as SceneTree
	if tree and tree.root.has_node("I18n"):
		return tree.root.get_node("I18n")
	return null
