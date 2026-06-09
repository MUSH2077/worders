extends Node

const DEFAULT_MODEL_PATH := "res://resources/embedding_vectors.json"
const DEFAULT_DIMENSIONS := 8
const SIMILARITY_THRESHOLD := 0.42
const MAX_EMBEDDING_BONUS := 6.0

var model_path := DEFAULT_MODEL_PATH
var model_source := "none"
var dimensions := DEFAULT_DIMENSIONS
var _vectors: Dictionary = {}

func _ready() -> void:
	load_model()

func load_model(path: String = DEFAULT_MODEL_PATH) -> Dictionary:
	model_path = path
	_vectors.clear()
	model_source = "profile_fallback"
	dimensions = DEFAULT_DIMENSIONS
	var file = FileAccess.open(path, FileAccess.READ)
	if file == null:
		return model_status()
	var parsed = JSON.parse_string(file.get_as_text())
	file.close()
	if parsed == null or not parsed.has("vectors"):
		return model_status()
	dimensions = int(parsed.get("dimensions", DEFAULT_DIMENSIONS))
	model_source = str(parsed.get("source", path))
	var raw_vectors = parsed.get("vectors", {})
	for key in raw_vectors.keys():
		var vector: Array[float] = []
		for value in raw_vectors[key]:
			vector.append(float(value))
		if vector.size() > 0:
			_vectors[str(key).strip_edges().to_lower()] = _normalize(vector)
	return model_status()

func model_status() -> Dictionary:
	return {
		"path": model_path,
		"source": model_source,
		"dimensions": dimensions,
		"vector_count": _vectors.size(),
		"fallback": "word_bank_profile",
	}

func get_vector(word: String) -> Array[float]:
	var key = word.strip_edges().to_lower()
	if key.is_empty():
		return []
	if _vectors.has(key):
		return (_vectors[key] as Array[float]).duplicate()
	var profile = _profile_vector_for_word(word)
	if profile.is_empty():
		return []
	return _normalize(profile)

func similarity(word_a: String, word_b: String) -> float:
	var a = get_vector(word_a)
	var b = get_vector(word_b)
	return cosine(a, b)

func cosine(a: Array[float], b: Array[float]) -> float:
	if a.is_empty() or b.is_empty():
		return 0.0
	var size = mini(a.size(), b.size())
	var dot = 0.0
	var mag_a = 0.0
	var mag_b = 0.0
	for i in range(size):
		dot += a[i] * b[i]
		mag_a += a[i] * a[i]
		mag_b += b[i] * b[i]
	if mag_a <= 0.00001 or mag_b <= 0.00001:
		return 0.0
	return clampf(dot / (sqrt(mag_a) * sqrt(mag_b)), -1.0, 1.0)

func sentence_similarity(words: Array[String]) -> float:
	if words.size() < 2:
		return 0.0
	var total = 0.0
	var pairs = 0
	for i in range(words.size() - 1):
		var sim = similarity(words[i], words[i + 1])
		if sim > 0.0:
			total += sim
			pairs += 1
	if pairs == 0:
		return 0.0
	return total / float(pairs)

# All-pairs average similarity, used as an informational whole-sentence
# coherence read-out. Unlike sentence_similarity it is not limited to adjacent
# words, so it reflects global topic consistency rather than local pairing.
func sentence_coherence(words: Array[String]) -> float:
	if words.size() < 2:
		return 0.0
	var total = 0.0
	var pairs = 0
	for i in range(words.size()):
		for j in range(i + 1, words.size()):
			var sim = similarity(words[i], words[j])
			if sim > 0.0:
				total += sim
				pairs += 1
	if pairs == 0:
		return 0.0
	return total / float(pairs)

func bonus_for_words(words: Array[String]) -> Dictionary:
	var sim = sentence_similarity(words)
	var bonus = 0.0
	if sim > SIMILARITY_THRESHOLD:
		bonus = ((sim - SIMILARITY_THRESHOLD) / (1.0 - SIMILARITY_THRESHOLD)) * MAX_EMBEDDING_BONUS
	return {
		"similarity": sim,
		"coherence": sentence_coherence(words),
		"bonus": clampf(bonus, 0.0, MAX_EMBEDDING_BONUS),
	}

func _profile_vector_for_word(word: String) -> Array[float]:
	if not is_instance_valid(WordBank):
		return []
	var entries = WordBank.find_entries(word)
	if entries.is_empty():
		return []
	var vector: Array[float] = []
	for i in range(DEFAULT_DIMENSIONS):
		vector.append(0.0)
	for entry in entries:
		var category_index = _category_axis(entry.category)
		var pos_index = _pos_axis(entry.pos)
		vector[category_index] += 1.0
		vector[pos_index] += 0.35
	return vector

func _category_axis(category: String) -> int:
	match category:
		"ANIMAL":
			return 0
		"ACTION":
			return 1
		"ARTIFACT", "BODY":
			return 2
		"COLOR":
			return 3
		"NATURE", "SPACE":
			return 4
		"TIME":
			return 5
		"EMOTION":
			return 6
		"ABSTRACT":
			return 7
		_:
			return 7

func _pos_axis(pos: String) -> int:
	match pos:
		"NOUN":
			return 0
		"VERB":
			return 1
		"ADJECTIVE":
			return 3
		"ADVERB":
			return 6
		_:
			return 7

func _normalize(vector: Array[float]) -> Array[float]:
	var mag = 0.0
	for value in vector:
		mag += value * value
	if mag <= 0.00001:
		return vector
	var denom = sqrt(mag)
	var normalized: Array[float] = []
	for value in vector:
		normalized.append(value / denom)
	return normalized
