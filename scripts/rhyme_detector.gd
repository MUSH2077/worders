class_name RhymeDetector extends RefCounted

static func detect_parallelism(components: Array) -> bool:
    if components.size() < 3:
        return false
    var max_run = 1
    var current_run = 1
    for i in range(1, components.size()):
        if components[i] == components[i - 1]:
            current_run += 1
            max_run = max(max_run, current_run)
        else:
            current_run = 1
    return max_run >= 3

static func detect_antithesis(components: Array) -> bool:
    var n = components.size()
    if n < 4:
        return false
    var mid = n / 2.0
    var left: Array = []
    var right: Array = []
    for i in range(mid):
        left.append(components[i])
    for i in range(n - mid):
        right.append(components[n - 1 - i])
    var mirror_match = true
    for i in range(left.size()):
        if left[i] != right[i]:
            mirror_match = false
            break
    var repeat_match = true
    for i in range(mid):
        if i + mid < n and components[i] != components[i + mid]:
            repeat_match = false
            break
    return mirror_match or repeat_match

static func detect_rhyme(words: Array, rhyme_map: Dictionary) -> bool:
    if words.size() < 2:
        return false
    var rhymed = 0
    var total = words.size() - 1
    for i in range(total):
        var ca = _last_char(words[i])
        var cb = _last_char(words[i + 1])
        if rhyme_map.has(ca) and rhyme_map.has(cb):
            if rhyme_map[ca]["rhyme"] == rhyme_map[cb]["rhyme"]:
                rhymed += 1
    return float(rhymed) / float(total) >= 0.5

static func _last_char(word: String) -> String:
    if word.is_empty():
        return ""
    return word[word.length() - 1]
