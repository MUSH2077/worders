extends Node

class WordEntry:
    var text: String
    var pos: String
    var category: String
    func _init(t: String, p: String, c: String):
        text = t; pos = p; category = c

var _all_words: Array[WordEntry] = []
var _aliases: Dictionary = {}

func _ready() -> void:
    load_from_file()

func load_from_file(path: String = "res://resources/word_bank.json") -> void:
    var file = FileAccess.open(path, FileAccess.READ)
    if file == null:
        push_error("WordBank: cannot open " + path)
        return
    var json = JSON.parse_string(file.get_as_text())
    file.close()
    if json == null or not json.has("words"):
        push_error("WordBank: invalid word bank json at " + path)
        return
    _all_words.clear()
    _aliases.clear()
    for w in json["words"]:
        _all_words.append(WordEntry.new(w["text"], w["pos"], w["category"]))
    var raw_aliases = json.get("aliases", {})
    if raw_aliases is Dictionary:
        for variant in raw_aliases.keys():
            var canonical = str(raw_aliases[variant]).strip_edges()
            var clean_variant = str(variant).strip_edges()
            if not clean_variant.is_empty() and not canonical.is_empty():
                _aliases[clean_variant] = canonical

# Maps a surface variant (simplified/traditional, suffix form, synonym) to its
# canonical word-bank entry text. Returns the input unchanged when no alias exists.
func resolve_alias(text: String) -> String:
    var clean = text.strip_edges()
    if clean.is_empty():
        return clean
    return str(_aliases.get(clean, clean))

func has_alias(text: String) -> bool:
    return _aliases.has(text.strip_edges())

func get_by_constraints(pos_filter: String, category_filter: String) -> Array[WordEntry]:
    var result: Array[WordEntry] = []
    for w in _all_words:
        if pos_filter != "ANY" and w.pos != pos_filter:
            continue
        if category_filter != "ANY" and w.category != category_filter:
            continue
        result.append(w)
    return result

func sample_by_constraints(
    pos_filter: String,
    category_filter: String,
    limit: int,
    rng: RandomNumberGenerator,
    exclude: Array[String] = []
) -> Array[WordEntry]:
    var pool = get_by_constraints(pos_filter, category_filter)
    if pool.is_empty() and not (pos_filter == "ANY" and category_filter == "ANY"):
        pool = get_by_constraints(pos_filter, "ANY")
    if pool.is_empty():
        pool = get_by_constraints("ANY", category_filter)
    if pool.is_empty():
        pool = get_by_constraints("ANY", "ANY")
    var filtered: Array[WordEntry] = []
    for entry in pool:
        if entry == null:
            continue
        if exclude.has(entry.text):
            continue
        filtered.append(entry)
    if filtered.is_empty():
        return filtered
    filtered.shuffle()
    if rng != null:
        for i in range(filtered.size() - 1, 0, -1):
            var j = rng.randi_range(0, i)
            var tmp = filtered[i]
            filtered[i] = filtered[j]
            filtered[j] = tmp
    if limit <= 0 or filtered.size() <= limit:
        return filtered
    return filtered.slice(0, limit)

func constraint_coverage(pos_filter: String, category_filter: String) -> int:
    return get_by_constraints(pos_filter, category_filter).size()

func find_entries(text: String) -> Array[WordEntry]:
    var clean = text.strip_edges()
    var result: Array[WordEntry] = []
    if clean.is_empty():
        return result
    for w in _all_words:
        if w.text == clean:
            result.append(w)
    if result.is_empty():
        var canonical = resolve_alias(clean)
        if canonical != clean:
            for w in _all_words:
                if w.text == canonical:
                    result.append(w)
    return result

func get_all_words() -> Array[WordEntry]:
    return _all_words
