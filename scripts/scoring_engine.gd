class_name ScoringEngine extends RefCounted

const ConstraintValidatorScript = preload("res://scripts/constraint_validator.gd")
const TacticalStanceScript = preload("res://scripts/tactical_stance.gd")

const COMBO_PER_EXTRA = 0.2
const COMBO_MAX = 2.0
const RHETORIC_PARALLELISM = 1.3
const RHETORIC_ANTITHESIS = 1.5
const RHETORIC_RHYME = 1.2
const HEAL_RATIO = 0.5
const CRIT_MULT = 1.5
const SEMANTIC_MISMATCH_BONUS = 10.0

const ATK_COMPS = [
    CardData.SentenceComponent.PREDICATE,
    CardData.SentenceComponent.OBJECT,
    CardData.SentenceComponent.COMPLEMENT,
]
const DEF_COMPS = [
    CardData.SentenceComponent.SUBJECT,
    CardData.SentenceComponent.ATTRIBUTE,
]
const CRT_COMPS = [
    CardData.SentenceComponent.ADVERBIAL,
]

class ScoreBreakdown:
    var base_disorder: float = 0.0
    var semantic_bonus: float = 0.0
    var embedding_bonus: float = 0.0
    var embedding_similarity: float = 0.0
    var total_disorder: float = 0.0
    var combo_mult: float = 1.0
    var rhetoric_mult: float = 1.0
    var rhetoric_flags: Array[String] = []
    var structure_penalty_percent: float = 0.0
    var constraint_penalty_percent: float = 0.0
    var constraint_bonus: float = 0.0
    var constraint_flags: Array[String] = []
    var judgment_trace: Array = []
    var penalty_percent: float = 0.0
    var stance_name: String = "balanced"
    var stance_modifiers: Dictionary = TacticalStanceScript.modifiers(TacticalStanceScript.Stance.BALANCED)
    var atk: int = 0
    var def_: int = 0
    var crt: int = 0

class SentenceInput:
    var cards: Array = []
    var words: Array[String] = []
    var components: Array = []
    func length() -> int:
        return cards.size()

static func calculate(sentence: SentenceInput, rhyme_map: Dictionary) -> ScoreBreakdown:
    return _calculate(sentence, rhyme_map, TacticalStanceScript.Stance.BALANCED)

static func calculate_with_stance(sentence: SentenceInput, rhyme_map: Dictionary, stance: int) -> ScoreBreakdown:
    return _calculate(sentence, rhyme_map, stance)

# Re-score using optional DeepSeek (L3) judgment overrides for unknown words.
static func calculate_with_judgment(sentence: SentenceInput, rhyme_map: Dictionary, stance: int, overrides: Dictionary) -> ScoreBreakdown:
    return _calculate(sentence, rhyme_map, stance, overrides)

static func _calculate(sentence: SentenceInput, rhyme_map: Dictionary, stance: int, overrides: Dictionary = {}) -> ScoreBreakdown:
    var b = ScoreBreakdown.new()
    b.stance_name = TacticalStanceScript.key(stance)
    b.stance_modifiers = TacticalStanceScript.modifiers(stance)
    if sentence.length() == 0:
        return b
    _calc_disorder(b, sentence)
    _calc_constraints(b, sentence, stance, overrides)
    _calc_combo(b, sentence)
    _calc_rhetoric(b, sentence, rhyme_map)
    _calc_penalty(b, sentence)
    var raw = (b.total_disorder * b.combo_mult * b.rhetoric_mult
               * (1.0 - b.penalty_percent))
    _calc_allocation(b, sentence, raw)
    _apply_stance_allocation(b)
    return b

static func _calc_disorder(b: ScoreBreakdown, s: SentenceInput) -> void:
    var sum_d = 0.0
    for card in s.cards:
        sum_d += card.base_disorder
    b.base_disorder = sum_d / float(s.cards.size())
    b.semantic_bonus = _calc_semantic_bonus(s)
    _calc_embedding_bonus(b, s)
    _recompute_total_disorder(b)

static func _calc_constraints(b: ScoreBreakdown, s: SentenceInput, stance: int, overrides: Dictionary = {}) -> void:
    var result = ConstraintValidatorScript.validate(s, overrides)
    var modifiers = TacticalStanceScript.modifiers(stance)
    b.constraint_bonus = result.bonus * modifiers.get("constraint_bonus_mult", 1.0)
    b.constraint_penalty_percent = result.penalty_percent * modifiers.get("constraint_penalty_mult", 1.0)
    b.constraint_flags = result.flags
    var trace: Array = []
    for judgment in result.trace:
        trace.append(judgment.to_dict())
    b.judgment_trace = trace
    _recompute_total_disorder(b)

static func _recompute_total_disorder(b: ScoreBreakdown) -> void:
    b.total_disorder = b.base_disorder + b.semantic_bonus + b.embedding_bonus + b.constraint_bonus

static func _calc_semantic_bonus(s: SentenceInput) -> float:
    if s.length() < 2:
        return 0.0
    var mismatches = 0
    var pairs = s.length() - 1
    for i in range(pairs):
        var cat_a = s.cards[i].content_constraint
        var cat_b = s.cards[i + 1].content_constraint
        if cat_a != CardData.ContentCategory.ANY and cat_b != CardData.ContentCategory.ANY:
            if cat_a != cat_b:
                mismatches += 1
    var ratio = float(mismatches) / float(pairs)
    return ratio * SEMANTIC_MISMATCH_BONUS

static func _calc_embedding_bonus(b: ScoreBreakdown, s: SentenceInput) -> void:
    b.embedding_bonus = 0.0
    b.embedding_similarity = 0.0
    if s.words.size() < 2:
        return
    var service = _embedding_service()
    if service == null or not service.has_method("bonus_for_words"):
        return
    var payload = service.bonus_for_words(s.words)
    b.embedding_similarity = float(payload.get("similarity", 0.0))
    b.embedding_bonus = float(payload.get("bonus", 0.0))

static func _embedding_service() -> Node:
    var loop = Engine.get_main_loop()
    if loop == null or not (loop is SceneTree):
        return null
    return (loop as SceneTree).root.get_node_or_null("/root/EmbeddingService")

static func _calc_combo(b: ScoreBreakdown, s: SentenceInput) -> void:
    var extra = s.length() - 2
    b.combo_mult = min(1.0 + max(extra, 0) * COMBO_PER_EXTRA, COMBO_MAX)

static func _calc_rhetoric(b: ScoreBreakdown, s: SentenceInput, rhyme_map: Dictionary) -> void:
    b.rhetoric_mult = 1.0
    if RhymeDetector.detect_antithesis(s.components):
        b.rhetoric_mult = RHETORIC_ANTITHESIS
        b.rhetoric_flags.append("对仗")
    elif RhymeDetector.detect_parallelism(s.components):
        b.rhetoric_mult = RHETORIC_PARALLELISM
        b.rhetoric_flags.append("排比")
    if RhymeDetector.detect_rhyme(s.words, rhyme_map):
        b.rhetoric_mult *= RHETORIC_RHYME
        b.rhetoric_flags.append("押韵")

static func _calc_penalty(b: ScoreBreakdown, s: SentenceInput) -> void:
    var v = StructureValidator.validate(s.components)
    b.structure_penalty_percent = v.penalty_percent
    b.penalty_percent = b.structure_penalty_percent + b.constraint_penalty_percent

static func _calc_allocation(b: ScoreBreakdown, s: SentenceInput, raw: float) -> void:
    var atk_n = 0
    var def_n = 0
    var crt_n = 0
    for comp in s.components:
        if comp in ATK_COMPS:
            atk_n += 1
        elif comp in DEF_COMPS:
            def_n += 1
        elif comp in CRT_COMPS:
            crt_n += 1
    var total = atk_n + def_n + crt_n
    if total == 0:
        b.atk = int(raw)
        return
    b.atk = int(raw * float(atk_n) / float(total))
    b.def_ = int(raw * float(def_n) / float(total))
    b.crt = int(raw * float(crt_n) / float(total))

static func _apply_stance_allocation(b: ScoreBreakdown) -> void:
    b.atk = max(0, int(round(float(b.atk) * b.stance_modifiers.get("atk_mult", 1.0))))
    b.def_ = max(0, int(round(float(b.def_) * b.stance_modifiers.get("def_mult", 1.0))))
    b.crt = max(0, int(round(float(b.crt) * b.stance_modifiers.get("crt_mult", 1.0))))

static func duplicate_sentence(sentence: SentenceInput) -> SentenceInput:
    var copy = SentenceInput.new()
    copy.cards = sentence.cards.duplicate()
    copy.words = sentence.words.duplicate()
    copy.components = sentence.components.duplicate()
    return copy

static func compute_slot_deltas(sentence: SentenceInput, rhyme_map: Dictionary, stance: int) -> Array:
    var deltas: Array = []
    if sentence.length() == 0:
        return deltas
    var full = calculate_with_stance(sentence, rhyme_map, stance)
    for i in range(sentence.length()):
        if str(sentence.words[i]).strip_edges().is_empty():
            deltas.append({"atk": 0, "def": 0, "crt": 0})
            continue
        var reduced = duplicate_sentence(sentence)
        reduced.words[i] = ""
        var partial = calculate_with_stance(reduced, rhyme_map, stance)
        deltas.append({
            "atk": full.atk - partial.atk,
            "def": full.def_ - partial.def_,
            "crt": full.crt - partial.crt,
        })
    return deltas
