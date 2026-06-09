class_name Deck extends RefCounted

var cards: Array[CardData] = []

func shuffle() -> void:
	cards.shuffle()

func draw() -> CardData:
	if cards.is_empty():
		return null
	var card: CardData = cards.pop_front()
	return card

func add_card(card: CardData) -> void:
	cards.append(card)

func size() -> int:
	return cards.size()

func is_empty() -> bool:
	return cards.is_empty()

func peek_top(n: int = 1) -> Array[CardData]:
	var result: Array[CardData] = []
	for i in range(min(n, cards.size())):
		result.append(cards[i])
	return result

func remove_card(card: CardData) -> bool:
	var idx = cards.find(card)
	if idx >= 0:
		cards.remove_at(idx)
		return true
	return false

func get_random_cards(count: int) -> Array[CardData]:
	var pool = cards.duplicate()
	pool.shuffle()
	var result: Array[CardData] = []
	for i in range(min(count, pool.size())):
		result.append(pool[i])
	return result
