class_name ConstraintValidator extends RefCounted

const MATCH_BONUS = 2.0
const MISMATCH_PENALTY = 0.08
const MAX_CONSTRAINT_PENALTY = 0.30

# Source of a per-slot judgment, shared by local rules, optional DeepSeek review,
# and the prediction UI so every layer reads one trace.
const SOURCE_EMPTY = "empty"
const SOURCE_WORD_BANK = "word_bank"
const SOURCE_ALIAS = "alias"
const SOURCE_UNKNOWN = "unknown"

class SlotJudgment:
	var index: int = 0
	var word: String = ""
	var source: String = SOURCE_EMPTY
	var has_constraint: bool = false
	var pos_ok: bool = true
	var content_ok: bool = true
	var matched: bool = false
	var flags: Array[String] = []
	func to_dict() -> Dictionary:
		return {
			"index": index,
			"word": word,
			"source": source,
			"has_constraint": has_constraint,
			"pos_ok": pos_ok,
			"content_ok": content_ok,
			"matched": matched,
			"flags": flags.duplicate(),
		}

class ConstraintResult:
	var bonus: float = 0.0
	var penalty_percent: float = 0.0
	var flags: Array[String] = []
	var trace: Array[SlotJudgment] = []
	func unknown_indices() -> Array[int]:
		var result: Array[int] = []
		for j in trace:
			if j.source == SOURCE_UNKNOWN:
				result.append(j.index)
		return result

const SOURCE_DEEPSEEK = "deepseek"

# overrides: optional { word(lower) : { matched:bool, pos:String, category:String, confidence:float } }
# Supplies DeepSeek (L3) verdicts for words the local bank cannot resolve.
static func validate(sentence: ScoringEngine.SentenceInput, overrides: Dictionary = {}) -> ConstraintResult:
	var result = ConstraintResult.new()
	for i in range(sentence.cards.size()):
		var card = sentence.cards[i]
		var word = sentence.words[i].strip_edges() if i < sentence.words.size() else ""
		var judgment = SlotJudgment.new()
		judgment.index = i
		judgment.word = word
		if card == null or word.is_empty():
			judgment.source = SOURCE_EMPTY
			result.trace.append(judgment)
			continue
		var has_pos_constraint = card.pos_constraint != CardData.PartOfSpeech.ANY
		var has_content_constraint = card.content_constraint != CardData.ContentCategory.ANY
		judgment.has_constraint = has_pos_constraint or has_content_constraint
		var entries = WordBank.find_entries(word)
		if entries.is_empty():
			var override = _lookup_override(overrides, word)
			if not override.is_empty():
				_apply_override(result, judgment, card, override, has_pos_constraint, has_content_constraint)
				result.trace.append(judgment)
				continue
			judgment.source = SOURCE_UNKNOWN
			judgment.flags.append("%s:UNKNOWN" % word)
			result.flags.append("%s:UNKNOWN" % word)
			result.trace.append(judgment)
			continue
		judgment.source = SOURCE_ALIAS if WordBank.has_alias(word) else SOURCE_WORD_BANK
		var pos_ok = _matches_pos(card, entries)
		var content_ok = _matches_content(card, entries)
		judgment.pos_ok = pos_ok
		judgment.content_ok = content_ok
		if pos_ok and content_ok:
			judgment.matched = true
			if judgment.has_constraint:
				result.bonus += MATCH_BONUS
		else:
			result.penalty_percent += MISMATCH_PENALTY
			judgment.flags.append("%s:MISMATCH" % word)
			result.flags.append("%s:MISMATCH" % word)
		result.trace.append(judgment)
	result.penalty_percent = min(result.penalty_percent, MAX_CONSTRAINT_PENALTY)
	return result

static func _lookup_override(overrides: Dictionary, word: String) -> Dictionary:
	if overrides.is_empty():
		return {}
	var key = word.strip_edges().to_lower()
	var entry = overrides.get(key, overrides.get(word.strip_edges(), null))
	if entry is Dictionary:
		return entry
	return {}

static func _apply_override(result: ConstraintResult, judgment: SlotJudgment, card: CardData, override: Dictionary, has_pos_constraint: bool, has_content_constraint: bool) -> void:
	judgment.source = SOURCE_DEEPSEEK
	var inferred_pos = str(override.get("pos", "ANY"))
	var inferred_category = str(override.get("category", "ANY"))
	var pos_ok = true
	var content_ok = true
	if has_pos_constraint:
		var expected_pos = CardData.PartOfSpeech.keys()[card.pos_constraint]
		pos_ok = inferred_pos == expected_pos
	if has_content_constraint:
		var expected_cat = CardData.ContentCategory.keys()[card.content_constraint]
		content_ok = inferred_category == expected_cat
	var matched = bool(override.get("matched", false)) and pos_ok and content_ok
	judgment.pos_ok = pos_ok
	judgment.content_ok = content_ok
	judgment.matched = matched
	if matched:
		if judgment.has_constraint:
			result.bonus += MATCH_BONUS
	elif judgment.has_constraint:
		result.penalty_percent += MISMATCH_PENALTY
		judgment.flags.append("%s:DS_MISMATCH" % judgment.word)
		result.flags.append("%s:DS_MISMATCH" % judgment.word)
		result.penalty_percent = min(result.penalty_percent, MAX_CONSTRAINT_PENALTY)

static func _matches_pos(card: CardData, entries: Array[WordBank.WordEntry]) -> bool:
	if card.pos_constraint == CardData.PartOfSpeech.ANY:
		return true
	var expected = CardData.PartOfSpeech.keys()[card.pos_constraint]
	for entry in entries:
		if entry.pos == expected:
			return true
	return false

static func _matches_content(card: CardData, entries: Array[WordBank.WordEntry]) -> bool:
	if card.content_constraint == CardData.ContentCategory.ANY:
		return true
	var expected = CardData.ContentCategory.keys()[card.content_constraint]
	for entry in entries:
		if entry.category == expected:
			return true
	return false
