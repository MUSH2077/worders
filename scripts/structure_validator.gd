class_name StructureValidator extends RefCounted

const REQUIRED_COMPONENTS = [
    CardData.SentenceComponent.SUBJECT,
    CardData.SentenceComponent.PREDICATE,
]
const NON_REPEATABLE = [
    CardData.SentenceComponent.SUBJECT,
    CardData.SentenceComponent.PREDICATE,
]

class ValidationResult:
    var has_subject: bool = false
    var has_predicate: bool = false
    var repeat_violations: int = 0
    var penalty_percent: float = 0.0

static func validate(components: Array) -> ValidationResult:
    var result = ValidationResult.new()
    for comp in components:
        if comp == CardData.SentenceComponent.SUBJECT:
            result.has_subject = true
        if comp == CardData.SentenceComponent.PREDICATE:
            result.has_predicate = true
    if not result.has_subject or not result.has_predicate:
        result.penalty_percent += 0.20
    var counted: Dictionary = {}
    for comp in components:
        if comp in NON_REPEATABLE:
            var key = str(comp)
            counted[key] = counted.get(key, 0) + 1
    for key in counted:
        if counted[key] > 1:
            result.repeat_violations += counted[key] - 1
    result.penalty_percent += result.repeat_violations * 0.15
    return result
