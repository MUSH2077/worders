# 文字卡牌对战游戏 — 实现计划

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 将现有 fantasy 卡牌对战项目完全改造为"填词造句"核心玩法的文字卡牌游戏，包含约束卡牌系统、评分引擎、修辞检测、成分攻防映射、AI 三层决策。

**Architecture:** 保留现有 Godot 4.6 Autoload 骨架（Events/CardDatabase/TurnManager/BattleManager/AIController），重写所有游戏逻辑。新增 ScoringEngine、RhymeDetector、StructureValidator、CombatResolver、SentenceBuilder 作为纯逻辑类（RefCounted），UI 层新建造句区域组件。

**Tech Stack:** Godot 4.6.3 GDScript, fastText 中文词嵌入（预留接口）, JSON 数据文件（韵母表、词库）

**Source spec:** `docs/superpowers/specs/2026-05-27-word-card-game-design.md`

---

## File Map

| File | Action | Responsibility |
|------|--------|---------------|
| `scripts/card_data.gd` | Rewrite | CardData Resource with constraint enums |
| `scripts/card_database.gd` | Rewrite | Card pool, constraint helpers |
| `scripts/word_bank.gd` | NEW | Word dictionary by constraint, AI word selection |
| `scripts/scoring_engine.gd` | NEW | Full scoring formula |
| `scripts/rhyme_detector.gd` | NEW | Parallelism, antithesis, rhyme detection |
| `scripts/structure_validator.gd` | NEW | Sentence grammar validation |
| `scripts/sentence_builder.gd` | NEW | Slot management, card→sentence assembly |
| `scripts/combat_resolver.gd` | NEW | ATK/DEF/CRT/heal calculation & application |
| `scripts/events.gd` | Modify | Add new signals for造句 flow |
| `scripts/battle_manager.gd` | Rewrite | New game flow orchestration |
| `scripts/turn_manager.gd` | Modify | Adapt turn phases (DRAW/MAIN/SCORING/RESOLVE/EVENT/END) |
| `scripts/player.gd` | Modify | Add shield, adapt for new combat |
| `scripts/deck.gd` | Modify | Add in-run add/remove cards |
| `scripts/ai_controller.gd` | Rewrite | 3-layer AI: strategy→card selection→word fill |
| `scenes/battle.tscn` | Rewrite | New layout with sentence builder area |
| `scenes/card.tscn` | Modify | Display constraints instead of atk/def |
| `scenes/sentence_slot.tscn` | NEW | Individual slot in sentence builder |
| `scripts/sentence_slot_ui.gd` | NEW | Slot display + click-to-edit |
| `scripts/sentence_builder_ui.gd` | NEW | Container managing slot arrangement |
| `scripts/word_input_dialog.gd` | NEW | Word input popup with constraint hints |
| `scripts/card_ui.gd` | Rewrite | Show constraint badges instead of atk/def |
| `scripts/battle_ui.gd` | Rewrite | New layout orchestration |
| `scripts/hand_ui.gd` | Modify | Adapt for card selection mode |
| `scripts/player_hud.gd` | Modify | Add shield display |
| `resources/pinyin_rhyme_map.json` | NEW | Char→pinyin→rhyme lookup table |
| `resources/word_bank.json` | NEW | Words organized by constraint categories |
| `resources/cards/*.tres` | Replace | New constraint-based card definitions (delete all old) |

---

## Phase 1: Data Foundation

### Task 1.1: Rewrite CardData Resource

**Files:**
- Rewrite: `scripts/card_data.gd`
- Delete: All `resources/cards/*.tres` (10 old files)
- Create: 4 demo fill cards in `resources/cards/`

- [ ] **Step 1: Write new CardData class**

```gdscript
# scripts/card_data.gd
class_name CardData extends Resource

enum CardType { FILL, FUNCTION, EQUIPMENT }
enum PartOfSpeech { NOUN, VERB, ADJECTIVE, ADVERB, PREPOSITION, CONJUNCTION, INTERJECTION, ANY }
enum SentenceComponent { SUBJECT, PREDICATE, OBJECT, ATTRIBUTE, ADVERBIAL, COMPLEMENT, ANY }
enum ContentCategory { COLOR, ANIMAL, EMOTION, ACTION, NATURE, BODY, ARTIFACT, ABSTRACT, TIME, SPACE, ANY }

@export var id: int
@export var card_name: String
@export var card_type: CardType = CardType.FILL
@export var rarity: int = 1
@export var pos_constraint: PartOfSpeech = PartOfSpeech.ANY
@export var comp_constraint: SentenceComponent = SentenceComponent.ANY
@export var content_constraint: ContentCategory = ContentCategory.ANY
@export var base_disorder: float = 10.0
@export var description: String = ""

func get_constraint_count() -> int:
    var count = 0
    if pos_constraint != PartOfSpeech.ANY: count += 1
    if comp_constraint != SentenceComponent.ANY: count += 1
    if content_constraint != ContentCategory.ANY: count += 1
    return count

func get_pos_name() -> String:
    return PartOfSpeech.keys()[pos_constraint]

func get_comp_name() -> String:
    return SentenceComponent.keys()[comp_constraint]

func get_content_name() -> String:
    return ContentCategory.keys()[content_constraint]
```

- [ ] **Step 2: Delete all old card .tres files**

```
Remove-Item resources/cards/sword_strike.tres
Remove-Item resources/cards/shield_block.tres
Remove-Item resources/cards/fireball.tres
Remove-Item resources/cards/healing_light.tres
Remove-Item resources/cards/shadow_blade.tres
Remove-Item resources/cards/thunder_bolt.tres
Remove-Item resources/cards/fortify.tres
Remove-Item resources/cards/poison_dart.tres
Remove-Item resources/cards/berserker_rage.tres
Remove-Item resources/cards/ice_lance.tres
```

- [ ] **Step 3: Create 4 demo fill cards as .tres files**

Create `resources/cards/fill_01_noun_subject_animal.tres`:
```
[gd_resource type="Resource" script_class="CardData" load_steps=2]
[ext_resource type="Script" path="res://scripts/card_data.gd" id="1"]
[resource]
script = ExtResource("1")
id = 1; card_name = "生灵"; card_type = 0; rarity = 1
pos_constraint = 0; comp_constraint = 0; content_constraint = 1
base_disorder = 25.0; description = "名词/主语/动物"
```

Create `resources/cards/fill_02_verb_predicate_action.tres`:
```
[gd_resource type="Resource" script_class="CardData" load_steps=2]
[ext_resource type="Script" path="res://scripts/card_data.gd" id="1"]
[resource]
script = ExtResource("1")
id = 2; card_name = "破坏"; card_type = 0; rarity = 1
pos_constraint = 1; comp_constraint = 1; content_constraint = 3
base_disorder = 25.0; description = "动词/谓语/动作"
```

Create `resources/cards/fill_03_adj_attr_color.tres`:
```
[gd_resource type="Resource" script_class="CardData" load_steps=2]
[ext_resource type="Script" path="res://scripts/card_data.gd" id="1"]
[resource]
script = ExtResource("1")
id = 3; card_name = "色彩"; card_type = 0; rarity = 1
pos_constraint = 2; comp_constraint = 3; content_constraint = 0
base_disorder = 25.0; description = "形容词/定语/颜色"
```

Create `resources/cards/fill_04_any_any_any.tres`:
```
[gd_resource type="Resource" script_class="CardData" load_steps=2]
[ext_resource type="Script" path="res://scripts/card_data.gd" id="1"]
[resource]
script = ExtResource("1")
id = 4; card_name = "万用"; card_type = 0; rarity = 1
pos_constraint = 7; comp_constraint = 6; content_constraint = 10
base_disorder = 5.0; description = "无约束万能牌"
```

- [ ] **Step 4: Commit**

### Task 1.2: Create Pinyin Rhyme Map & Word Bank

**Files:**
- Create: `resources/pinyin_rhyme_map.json`
- Create: `resources/word_bank.json`
- Create: `scripts/word_bank.gd`

- [ ] **Step 1: Create pinyin rhyme map JSON** (sample, expand later)

```json
{
  "红": {"pinyin": "hong", "rhyme": "ong"},
  "龙": {"pinyin": "long", "rhyme": "ong"},
  "哮": {"pinyin": "xiao", "rhyme": "iao"},
  "色": {"pinyin": "se", "rhyme": "e"},
  "跃": {"pinyin": "yue", "rhyme": "ue"},
  "狐": {"pinyin": "hu", "rhyme": "u"},
  "狸": {"pinyin": "li", "rhyme": "i"},
  "燃": {"pinyin": "ran", "rhyme": "an"},
  "烧": {"pinyin": "shao", "rhyme": "ao"},
  "冰": {"pinyin": "bing", "rhyme": "ing"},
  "箱": {"pinyin": "xiang", "rhyme": "iang"},
  "飞": {"pinyin": "fei", "rhyme": "ei"},
  "翔": {"pinyin": "xiang", "rhyme": "iang"},
  "温": {"pinyin": "wen", "rhyme": "en"},
  "暖": {"pinyin": "nuan", "rhyme": "uan"},
  "阳": {"pinyin": "yang", "rhyme": "ang"},
  "光": {"pinyin": "guang", "rhyme": "uang"},
  "照": {"pinyin": "zhao", "rhyme": "ao"},
  "深": {"pinyin": "shen", "rhyme": "en"},
  "巨": {"pinyin": "ju", "rhyme": "u"},
  "撕": {"pinyin": "si", "rhyme": "i"},
  "裂": {"pinyin": "lie", "rhyme": "ie"}
}
```

- [ ] **Step 2: Create word bank JSON**

```json
{
  "words": [
    {"text": "龙", "pos": "NOUN", "category": "ANIMAL"},
    {"text": "狐狸", "pos": "NOUN", "category": "ANIMAL"},
    {"text": "大象", "pos": "NOUN", "category": "ANIMAL"},
    {"text": "撕裂", "pos": "VERB", "category": "ACTION"},
    {"text": "咆哮", "pos": "VERB", "category": "ACTION"},
    {"text": "跳跃", "pos": "VERB", "category": "ACTION"},
    {"text": "飞翔", "pos": "VERB", "category": "ACTION"},
    {"text": "照耀", "pos": "VERB", "category": "ACTION"},
    {"text": "绯红的", "pos": "ADJECTIVE", "category": "COLOR"},
    {"text": "深红的", "pos": "ADJECTIVE", "category": "COLOR"},
    {"text": "碧绿的", "pos": "ADJECTIVE", "category": "COLOR"},
    {"text": "温暖的", "pos": "ADJECTIVE", "category": "EMOTION"},
    {"text": "愤怒地", "pos": "ADVERB", "category": "EMOTION"},
    {"text": "燃烧的", "pos": "ADJECTIVE", "category": "NATURE"},
    {"text": "冰箱", "pos": "NOUN", "category": "ARTIFACT"},
    {"text": "阳光", "pos": "NOUN", "category": "NATURE"},
    {"text": "远古", "pos": "ADJECTIVE", "category": "TIME"},
    {"text": "巨龙", "pos": "NOUN", "category": "ANIMAL"}
  ]
}
```

- [ ] **Step 3: Create WordBank autoload class**

```gdscript
# scripts/word_bank.gd
extends Node

class WordEntry:
    var text: String
    var pos: String
    var category: String
    func _init(t: String, p: String, c: String):
        text = t; pos = p; category = c

var _all_words: Array[WordEntry] = []

func _ready() -> void:
    load_from_file()

func load_from_file(path: String = "res://resources/word_bank.json") -> void:
    var file = FileAccess.open(path, FileAccess.READ)
    if file == null:
        push_error("WordBank: cannot open " + path)
        return
    var json = JSON.parse_string(file.get_as_text())
    file.close()
    _all_words.clear()
    for w in json["words"]:
        _all_words.append(WordEntry.new(w["text"], w["pos"], w["category"]))

func get_by_constraints(pos_filter: String, category_filter: String) -> Array[WordEntry]:
    var result: Array[WordEntry] = []
    for w in _all_words:
        if pos_filter != "ANY" and w.pos != pos_filter:
            continue
        if category_filter != "ANY" and w.category != category_filter:
            continue
        result.append(w)
    return result

func get_all_words() -> Array[WordEntry]:
    return _all_words
```

- [ ] **Step 4: Register WordBank as Autoload in project.godot**

Add to autoload list: `WordBank="*res://scripts/word_bank.gd"`

- [ ] **Step 5: Commit**

### Task 1.3: Rewrite CardDatabase

**Files:**
- Rewrite: `scripts/card_database.gd`

- [ ] **Step 1: Rewrite for new card types**

```gdscript
# scripts/card_database.gd
extends Node

var fill_cards: Array[CardData] = []
var function_cards: Array[CardData] = []
var equipment_cards: Array[CardData] = []

func _ready() -> void:
    _load_all_cards()

func _load_all_cards() -> void:
    var dir = DirAccess.open("res://resources/cards/")
    if dir == null: return
    dir.list_dir_begin()
    var file_name = dir.get_next()
    while file_name != "":
        if file_name.ends_with(".tres"):
            var card = load("res://resources/cards/" + file_name) as CardData
            if card:
                match card.card_type:
                    CardData.CardType.FILL: fill_cards.append(card)
                    CardData.CardType.FUNCTION: function_cards.append(card)
                    CardData.CardType.EQUIPMENT: equipment_cards.append(card)
        file_name = dir.get_next()

func get_random_fill_card() -> CardData:
    if fill_cards.is_empty(): return null
    return fill_cards[randi() % fill_cards.size()]

func get_random_cards(count: int) -> Array[CardData]:
    var pool = fill_cards.duplicate()
    pool.shuffle()
    var result: Array[CardData] = []
    for i in range(min(count, pool.size())):
        result.append(pool[i])
    return result
```

- [ ] **Step 2: Commit**

---

## Phase 2: Core Scoring Mechanics

### Task 2.1: Create StructureValidator

**Files:**
- Create: `scripts/structure_validator.gd`

- [ ] **Step 1: Implement structure validation**

```gdscript
# scripts/structure_validator.gd
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
```

- [ ] **Step 2: Commit**

### Task 2.2: Create RhymeDetector

**Files:**
- Create: `scripts/rhyme_detector.gd`

- [ ] **Step 1: Implement parallelism, antithesis, rhyme detection**

```gdscript
# scripts/rhyme_detector.gd
class_name RhymeDetector extends RefCounted

static func detect_parallelism(components: Array) -> bool:
    if components.size() < 3: return false
    var max_run = 1; var current_run = 1
    for i in range(1, components.size()):
        if components[i] == components[i - 1]:
            current_run += 1
            max_run = max(max_run, current_run)
        else:
            current_run = 1
    return max_run >= 3

static func detect_antithesis(components: Array) -> bool:
    var n = components.size()
    if n < 4: return false
    var mid = n / 2
    var left: Array = []; var right: Array = []
    for i in range(mid): left.append(components[i])
    for i in range(n - mid): right.append(components[n - 1 - i])
    var mirror_match = true
    for i in range(left.size()):
        if left[i] != right[i]:
            mirror_match = false; break
    var repeat_match = true
    for i in range(mid):
        if i + mid < n and components[i] != components[i + mid]:
            repeat_match = false; break
    return mirror_match or repeat_match

static func detect_rhyme(words: Array, rhyme_map: Dictionary) -> bool:
    if words.size() < 2: return false
    var rhymed = 0; var total = words.size() - 1
    for i in range(total):
        var ca = _last_char(words[i])
        var cb = _last_char(words[i + 1])
        if rhyme_map.has(ca) and rhyme_map.has(cb):
            if rhyme_map[ca]["rhyme"] == rhyme_map[cb]["rhyme"]:
                rhymed += 1
    return float(rhymed) / float(total) >= 0.5

static func _last_char(word: String) -> String:
    if word.is_empty(): return ""
    return word[word.length() - 1]
```

- [ ] **Step 2: Commit**

### Task 2.3: Create ScoringEngine

**Files:**
- Create: `scripts/scoring_engine.gd`

- [ ] **Step 1: Implement full scoring formula**

```gdscript
# scripts/scoring_engine.gd
class_name ScoringEngine extends RefCounted

const COMBO_PER_EXTRA = 0.2; const COMBO_MAX = 2.0
const RHETORIC_PARALLELISM = 1.3; const RHETORIC_ANTITHESIS = 1.5
const RHETORIC_RHYME = 1.2; const HEAL_RATIO = 0.5; const CRIT_MULT = 1.5

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
    var total_disorder: float = 0.0
    var combo_mult: float = 1.0
    var rhetoric_mult: float = 1.0
    var rhetoric_flags: Array[String] = []
    var penalty_percent: float = 0.0
    var atk: int = 0; var def_: int = 0; var crt: int = 0

class SentenceInput:
    var cards: Array[CardData] = []
    var words: Array[String] = []
    var components: Array = []
    func length() -> int: return cards.size()

func calculate(sentence: SentenceInput, rhyme_map: Dictionary) -> ScoreBreakdown:
    var b = ScoreBreakdown.new()
    if sentence.length() == 0: return b
    _calc_disorder(b, sentence)
    _calc_combo(b, sentence)
    _calc_rhetoric(b, sentence, rhyme_map)
    _calc_penalty(b, sentence)
    var raw = (b.total_disorder * b.combo_mult * b.rhetoric_mult
               * (1.0 - b.penalty_percent))
    _calc_allocation(b, sentence, raw)
    return b

func _calc_disorder(b: ScoreBreakdown, s: SentenceInput) -> void:
    var sum_d = 0.0
    for card in s.cards: sum_d += card.base_disorder
    b.base_disorder = sum_d / float(s.cards.size())
    b.total_disorder = b.base_disorder  # +embedding bonus (reserved)

func _calc_combo(b: ScoreBreakdown, s: SentenceInput) -> void:
    var extra = s.length() - 2
    b.combo_mult = min(1.0 + max(extra, 0) * COMBO_PER_EXTRA, COMBO_MAX)

func _calc_rhetoric(b: ScoreBreakdown, s: SentenceInput, rhyme_map: Dictionary) -> void:
    b.rhetoric_mult = 1.0
    if RhymeDetector.detect_antithesis(s.components):
        b.rhetoric_mult = RHETORIC_ANTITHESIS; b.rhetoric_flags.append("对仗")
    elif RhymeDetector.detect_parallelism(s.components):
        b.rhetoric_mult = RHETORIC_PARALLELISM; b.rhetoric_flags.append("排比")
    if RhymeDetector.detect_rhyme(s.words, rhyme_map):
        b.rhetoric_mult *= RHETORIC_RHYME; b.rhetoric_flags.append("押韵")

func _calc_penalty(b: ScoreBreakdown, s: SentenceInput) -> void:
    var v = StructureValidator.validate(s.components)
    b.penalty_percent = v.penalty_percent

func _calc_allocation(b: ScoreBreakdown, s: SentenceInput, raw: float) -> void:
    var atk_n = 0; var def_n = 0; var crt_n = 0
    for comp in s.components:
        if comp in ATK_COMPS: atk_n += 1
        elif comp in DEF_COMPS: def_n += 1
        elif comp in CRT_COMPS: crt_n += 1
    var total = atk_n + def_n + crt_n
    if total == 0: b.atk = int(raw); return
    b.atk = int(raw * float(atk_n) / float(total))
    b.def_ = int(raw * float(def_n) / float(total))
    b.crt = int(raw * float(crt_n) / float(total))
```

- [ ] **Step 2: Commit**

---

## Phase 3: Sentence Builder

### Task 3.1: Create SentenceBuilder

**Files:**
- Create: `scripts/sentence_builder.gd`

- [ ] **Step 1: Implement sentence builder logic**

```gdscript
# scripts/sentence_builder.gd
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
    func _init(c: CardData): card = c
    func is_filled() -> bool: return not word.is_empty()
    func get_component() -> int: return card.comp_constraint

var slots: Array[Slot] = []

func add_card(card: CardData) -> void:
    slots.append(Slot.new(card))

func remove_card_at(index: int) -> void:
    if index >= 0 and index < slots.size(): slots.remove_at(index)

func set_word(index: int, word: String) -> void:
    if index >= 0 and index < slots.size(): slots[index].word = word

func clear() -> void: slots.clear()

func get_ordered_slots() -> Array[Slot]:
    var ordered = slots.duplicate()
    ordered.sort_custom(func(a: Slot, b: Slot):
        var ia = COMPONENT_ORDER.find(a.get_component())
        var ib = COMPONENT_ORDER.find(b.get_component())
        if ia == -1: ia = 999
        if ib == -1: ib = 999
        return ia < ib)
    return ordered

func get_sentence_input() -> ScoringEngine.SentenceInput:
    var input = ScoringEngine.SentenceInput.new()
    var ordered = get_ordered_slots()
    for slot in ordered:
        input.cards.append(slot.card)
        input.words.append(slot.word)
        input.components.append(slot.get_component())
    return input

func get_total_mana_cost(base_cost: float = 0.0, char_coef: float = 1.0) -> int:
    var total = 0.0
    for slot in slots:
        total += base_cost + floor(slot.word.length() * char_coef)
    return int(total)

func is_complete() -> bool:
    if slots.is_empty(): return false
    for slot in slots:
        if not slot.is_filled(): return false
    return true

func get_missing_components() -> Array:
    var present: Dictionary = {}
    for slot in slots: present[slot.get_component()] = true
    var missing: Array = []
    for req in StructureValidator.REQUIRED_COMPONENTS:
        if not present.has(req): missing.append(req)
    return missing
```

- [ ] **Step 2: Commit**

---

## Phase 4: Combat & Turn Systems

### Task 4.1: Create CombatResolver

**Files:**
- Create: `scripts/combat_resolver.gd`

- [ ] **Step 1: Implement combat resolution**

```gdscript
# scripts/combat_resolver.gd
class_name CombatResolver extends RefCounted

class CombatResult:
    var damage_dealt: int = 0
    var shield_gained: int = 0
    var heal_amount: int = 0
    var was_crit: bool = false

static func resolve(attacker: Player, defender: Player,
                    breakdown: ScoringEngine.ScoreBreakdown) -> CombatResult:
    var result = CombatResult.new()
    result.was_crit = randf() < (float(breakdown.crt) / 100.0)
    var atk = breakdown.atk
    if result.was_crit: atk = int(float(atk) * ScoringEngine.CRIT_MULT)
    result.shield_gained = breakdown.def_
    attacker.add_shield(result.shield_gained)
    result.damage_dealt = defender.take_damage(atk)
    result.heal_amount = int(float(breakdown.def_) * ScoringEngine.HEAL_RATIO)
    attacker.heal(result.heal_amount)
    return result
```

- [ ] **Step 2: Commit**

### Task 4.2: Rewrite Player Model

**Files:**
- Rewrite: `scripts/player.gd`

- [ ] **Step 1: Add shield, mana refresh, new combat methods**

```gdscript
# scripts/player.gd
class_name Player extends RefCounted

var player_name: String = ""
var hp: int = 30; var max_hp: int = 30
var shield: int = 0
var mana: int = 0; var max_mana: int = 10
var hand: Array[CardData] = []
var deck: Deck
var is_ai: bool = false

func take_damage(amount: int) -> int:
    if amount <= 0: return 0
    var remaining = amount
    if shield > 0:
        var absorbed = min(shield, remaining)
        shield -= absorbed; remaining -= absorbed
    hp = max(hp - remaining, 0)
    return amount - max(remaining - amount, 0)  # actual dealt

func add_shield(amount: int) -> void: shield += amount
func heal(amount: int) -> void: hp = min(hp + amount, max_hp)
func spend_mana(amount: int) -> bool:
    if amount > mana: return false
    mana -= amount; return true
func refresh_mana() -> void: mana = max_mana
func increase_max_mana() -> void: max_mana = min(max_mana + 1, 10)
func is_alive() -> bool: return hp > 0
func reset_shield() -> void: shield = 0
```

- [ ] **Step 2: Commit**

### Task 4.3: Update Events, TurnManager, Deck

**Files:**
- Modify: `scripts/events.gd` — add signals: `sentence_built`, `score_calculated`, `combat_resolved`, `event_triggered`, `card_added_to_deck`
- Modify: `scripts/turn_manager.gd` — new Phase enum: `DRAW, MAIN, SCORING, RESOLVE, EVENT, END`
- Modify: `scripts/deck.gd` — add `add_card()`, `remove_card()`, `get_random_cards(count)`

- [ ] **Step 1: Update events.gd**

Add to existing signals list:
```gdscript
signal sentence_built(sentence_input)
signal score_calculated(breakdown)
signal combat_resolved(result)
signal event_triggered(event_type)
signal card_added_to_deck(card)
```

- [ ] **Step 2: Update turn_manager.gd**

Change Phase enum from `DRAW/MAIN/BATTLE/END` to:
```gdscript
enum Phase { DRAW, MAIN, SCORING, RESOLVE, EVENT, END }
```

- [ ] **Step 3: Update deck.gd**

Add methods to Deck class:
```gdscript
func add_card(card: CardData) -> void: cards.append(card)
func remove_card(card: CardData) -> bool:
    var idx = cards.find(card)
    if idx >= 0: cards.remove_at(idx); return true
    return false
func get_random_cards(count: int) -> Array[CardData]:
    var pool = cards.duplicate(); pool.shuffle()
    var result: Array[CardData] = []
    for i in range(min(count, pool.size())): result.append(pool[i])
    return result
```

- [ ] **Step 4: Commit**

### Task 4.4: Rewrite BattleManager

**Files:**
- Rewrite: `scripts/battle_manager.gd`

- [ ] **Step 1: Implement new game flow**

```gdscript
# scripts/battle_manager.gd
extends Node

var player1: Player; var player2: Player; var current_player: Player
var sentence_builder: SentenceBuilder = SentenceBuilder.new()
var rhyme_map: Dictionary = {}

func _ready() -> void:
    _load_rhyme_map()
    Events.turn_changed.connect(_on_turn_changed)
    Events.sentence_built.connect(_on_sentence_built)

func _load_rhyme_map() -> void:
    var f = FileAccess.open("res://resources/pinyin_rhyme_map.json", FileAccess.READ)
    if f: rhyme_map = JSON.parse_string(f.get_as_text()); f.close()

func start_battle() -> void:
    player1 = _make_player("玩家", false)
    player2 = _make_player("AI", true)
    _build_decks(); _draw_hands()
    TurnManager.start_turn(player1)

func _make_player(name: String, ai: bool) -> Player:
    var p = Player.new(); p.player_name = name; p.is_ai = ai
    p.deck = Deck.new(); return p

func _build_decks() -> void:
    for i in range(15):
        player1.deck.add_card(CardDatabase.get_random_fill_card())
        player2.deck.add_card(CardDatabase.get_random_fill_card())
    player1.deck.shuffle(); player2.deck.shuffle()

func _draw_hands() -> void:
    for i in range(3): _draw(player1); _draw(player2)

func _draw(p: Player) -> void:
    var c = p.deck.draw()
    if c: p.hand.append(c)

func _on_turn_changed(player: Player) -> void:
    current_player = player
    player.increase_max_mana(); player.refresh_mana(); player.reset_shield()
    _draw(player); sentence_builder.clear()
    TurnManager.set_phase(TurnManager.Phase.DRAW)
    if player.is_ai:
        await get_tree().create_timer(0.5).timeout
        AIController.execute_turn(player, sentence_builder)

func _on_sentence_built(_input) -> void:
    TurnManager.set_phase(TurnManager.Phase.SCORING)
    var breakdown = ScoringEngine.calculate(sentence_builder.get_sentence_input(), rhyme_map)
    Events.score_calculated.emit(breakdown)
    TurnManager.set_phase(TurnManager.Phase.RESOLVE)
    var opp = player2 if current_player == player1 else player1
    var result = CombatResolver.resolve(current_player, opp, breakdown)
    Events.combat_resolved.emit(result)
    if not opp.is_alive():
        Events.game_over.emit(current_player); return
    TurnManager.set_phase(TurnManager.Phase.EVENT)
    _run_event()
    TurnManager.set_phase(TurnManager.Phase.END)
    _end_turn()

func _run_event() -> void:
    var tn = TurnManager.current_turn_number
    if tn % 3 == 0: Events.event_triggered.emit("shop")
    elif tn % 5 == 0: Events.event_triggered.emit("curse")
    elif tn % 2 == 0: Events.event_triggered.emit("reward")

func _end_turn() -> void:
    var next_p = player2 if current_player == player1 else player1
    TurnManager.start_turn(next_p)

func confirm_sentence() -> void:
    if not sentence_builder.is_complete(): return
    var cost = sentence_builder.get_total_mana_cost()
    if not current_player.spend_mana(cost): return
    Events.sentence_built.emit(sentence_builder.get_sentence_input())
```

- [ ] **Step 2: Commit**

---

## Phase 5: AI Controller

### Task 5.1: Rewrite AIController

**Files:**
- Rewrite: `scripts/ai_controller.gd`

- [ ] **Step 1: Implement 3-layer AI**

```gdscript
# scripts/ai_controller.gd
extends Node

enum Difficulty { EASY, NORMAL, HARD }
var difficulty: Difficulty = Difficulty.NORMAL
enum Strategy { AGGRESSIVE, DEFENSIVE, BALANCED }

func execute_turn(player: Player, builder: SentenceBuilder) -> void:
    var strategy = _choose_strategy(player)
    var cards = _select_cards(player, strategy)
    for card in cards: builder.add_card(card)
    for i in range(builder.slots.size()):
        var word = _select_word(builder.slots[i], strategy)
        builder.set_word(i, word)
    await get_tree().create_timer(0.5).timeout
    Events.sentence_built.emit(builder.get_sentence_input())

func _choose_strategy(player: Player) -> Strategy:
    if difficulty == Difficulty.EASY: return Strategy.BALANCED
    var opp = _get_opponent(player)
    if opp == null: return Strategy.BALANCED
    var hp_r = float(player.hp) / float(player.max_hp)
    var op_r = float(opp.hp) / float(opp.max_hp)
    if hp_r < 0.4: return Strategy.DEFENSIVE
    if op_r < 0.4: return Strategy.AGGRESSIVE
    return Strategy.BALANCED

func _get_opponent(player: Player) -> Player:
    if BMBattleManager.player1 == player: return BMBattleManager.player2
    return BMBattleManager.player1

func _select_cards(player: Player, strategy: Strategy) -> Array[CardData]:
    if player.hand.is_empty(): return []
    if difficulty == Difficulty.EASY:
        var copy = player.hand.duplicate(); copy.shuffle()
        var n = randi() % min(copy.size(), 4) + 1
        return copy.slice(0, n)
    var sorted = player.hand.duplicate()
    sorted.sort_custom(func(a: CardData, b: CardData):
        return _card_score(a, strategy) > _card_score(b, strategy))
    var result: Array[CardData] = []
    var used = 0
    for card in sorted:
        var est = 2  # estimate 2 chars per word
        if used + est <= player.mana:
            result.append(card); used += est
        if result.size() >= 5: break
    return result

func _card_score(card: CardData, strategy: Strategy) -> float:
    var s = card.base_disorder
    match strategy:
        Strategy.AGGRESSIVE:
            if card.comp_constraint in ScoringEngine.ATK_COMPS: s += 10
        Strategy.DEFENSIVE:
            if card.comp_constraint in ScoringEngine.DEF_COMPS: s += 10
    return s

func _select_word(slot: SentenceBuilder.Slot, _strategy: Strategy) -> String:
    var pos_f = CardData.PartOfSpeech.keys()[slot.card.pos_constraint]
    var cat_f = CardData.ContentCategory.keys()[slot.card.content_constraint]
    var cand = WordBank.get_by_constraints(pos_f, cat_f)
    if cand.is_empty(): cand = WordBank.get_by_constraints("ANY", "ANY")
    if cand.is_empty(): return "龙"
    if difficulty == Difficulty.EASY: return cand[randi() % cand.size()].text
    return cand[0].text  # first match (can be improved with embedding later)
```

- [ ] **Step 2: Commit**

---

## Phase 6: UI Reconstruction

### Task 6.1: Rewrite Card UI

**Files:**
- Rewrite: `scripts/card_ui.gd`
- Modify: `scenes/card.tscn`

- [ ] **Step 1: Card UI shows constraint badges**

```gdscript
# scripts/card_ui.gd
extends Panel
signal card_clicked(card_data)

@export var card_data: CardData:
    set(value): card_data = value; _update()

@onready var name_lbl: Label = $Margin/VBox/Name
@onready var pos_lbl: Label = $Margin/VBox/Pos
@onready var comp_lbl: Label = $Margin/VBox/Comp
@onready var cont_lbl: Label = $Margin/VBox/Content
@onready var dis_lbl: Label = $Margin/VBox/Disorder

func _update() -> void:
    if card_data == null: return
    name_lbl.text = card_data.card_name
    pos_lbl.text = "词性: " + card_data.get_pos_name()
    comp_lbl.text = "成分: " + card_data.get_comp_name()
    cont_lbl.text = "扩展: " + card_data.get_content_name()
    dis_lbl.text = "紊乱: " + str(card_data.base_disorder)
    var tightness = card_data.get_constraint_count()
    dis_lbl.modulate = [Color.GREEN, Color.YELLOW, Color.ORANGE, Color.RED][tightness]

func _gui_input(event: InputEvent) -> void:
    if event is InputEventMouseButton and event.pressed:
        card_clicked.emit(card_data)
```

- [ ] **Step 2: Update card.tscn scene**

Replace atk/def/cost labels with pos/comp/content/disorder labels in VBox.

- [ ] **Step 3: Commit**

### Task 6.2: Create Sentence Builder UI

**Files:**
- Create: `scenes/sentence_slot.tscn` + `scripts/sentence_slot_ui.gd`
- Create: `scripts/sentence_builder_ui.gd`
- Create: `scripts/word_input_dialog.gd`

- [ ] **Step 1: SentenceSlotUI**

```gdscript
# scripts/sentence_slot_ui.gd
extends Panel
signal slot_clicked(index)
var slot_index: int = -1

@onready var comp_lbl: Label = $CompLabel
@onready var word_lbl: Label = $WordLabel

func setup(index: int, card: CardData) -> void:
    slot_index = index
    comp_lbl.text = card.get_comp_name()
    word_lbl.text = "___"

func set_word(w: String) -> void: word_lbl.text = w

func _gui_input(event: InputEvent) -> void:
    if event is InputEventMouseButton and event.pressed:
        slot_clicked.emit(slot_index)
```

- [ ] **Step 2: SentenceBuilderUI**

```gdscript
# scripts/sentence_builder_ui.gd
extends HBoxContainer
var builder: SentenceBuilder
var slot_scene = preload("res://scenes/sentence_slot.tscn")

func setup(b: SentenceBuilder) -> void:
    builder = b; _refresh()

func _refresh() -> void:
    for c in get_children(): c.queue_free()
    var ordered = builder.get_ordered_slots()
    for i in range(ordered.size()):
        var s = slot_scene.instantiate()
        add_child(s)
        s.setup(i, ordered[i].card)
        s.slot_clicked.connect(func(idx): Events.word_input_requested.emit(idx, builder.slots[idx].card))

func add_slot(card: CardData) -> void:
    builder.add_card(card); _refresh()
```

- [ ] **Step 3: WordInputDialog**

```gdscript
# scripts/word_input_dialog.gd
extends AcceptDialog
signal word_submitted(slot_index, word)
var _slot_idx: int = -1

@onready var line_edit: LineEdit = $VBox/LineEdit
@onready var hint_lbl: Label = $VBox/Hint

func setup(idx: int, card: CardData) -> void:
    _slot_idx = idx
    hint_lbl.text = "%s | %s | %s" % [card.get_pos_name(), card.get_comp_name(), card.get_content_name()]
    line_edit.text = ""; line_edit.grab_focus()

func _on_confirmed() -> void:
    word_submitted.emit(_slot_idx, line_edit.text)
```

- [ ] **Step 4: Commit**

### Task 6.3: Rewrite Battle UI & Update HUD

**Files:**
- Rewrite: `scripts/battle_ui.gd`, `scenes/battle.tscn`
- Modify: `scripts/hand_ui.gd`, `scripts/player_hud.gd`

- [ ] **Step 1: New battle.tscn layout**

```
Control (battle_ui.gd)
├── PhaseLabel
├── OpponentHUD
├── SentenceBuilderUI (HBoxContainer)
├── ScorePreview (Label)
├── PlayerHand (ScrollContainer > HBoxContainer)
├── BottomBar
│   ├── PlayerHUD (with ShieldLabel)
│   └── ConfirmButton
└── WordInputDialog
```

- [ ] **Step 2: BattleUI script**

```gdscript
# scripts/battle_ui.gd
extends Control

@onready var builder_ui = $SentenceBuilderUI
@onready var score_lbl = $ScorePreview
@onready var confirm_btn = $BottomBar/ConfirmButton
@onready var word_dlg: AcceptDialog = $WordInputDialog

func _ready() -> void:
    confirm_btn.pressed.connect(func(): BMBattleManager.confirm_sentence())
    Events.word_input_requested.connect(func(idx, card):
        word_dlg.setup(idx, card); word_dlg.popup_centered())
    Events.score_calculated.connect(func(b):
        score_lbl.text = "ATK:%d DEF:%d CRT:%d | %.0f x%.1f %s" % [
            b.atk, b.def_, b.crt, b.total_disorder, b.combo_mult,
            " ".join(b.rhetoric_flags)])
    builder_ui.setup(BMBattleManager.sentence_builder)

func _on_card_clicked(card: CardData) -> void:
    builder_ui.add_slot(card)
```

- [ ] **Step 3: Update PlayerHUD** — add `ShieldLabel` in `player_hud.gd` that shows `player.shield`

- [ ] **Step 4: Update HandUI** — wire `card_clicked` signal to `battle_ui._on_card_clicked()`

- [ ] **Step 5: Commit**

---

## Phase 7: Integration & Verification

### Task 7.1: Final Wiring

- [ ] Verify autoload order in `project.godot`: Events → CardDatabase → WordBank → TurnManager → BattleManager → AIController
- [ ] Verify `main.tscn` / `main.gd` transitions to `battle.tscn` correctly
- [ ] Run project: `mcp__godot__run_project` with `"c:/Users/wsy13/Documents/godothub/project/worders"`

### Task 7.2: Test Checklist

- [ ] Cards display with constraint badges (not atk/def)
- [ ] Click card in hand → added to sentence builder slot
- [ ] Click slot → word input dialog opens with constraint hints
- [ ] Type word → mana cost preview shown (based on character count)
- [ ] Confirm → scoring runs, score breakdown shown
- [ ] Combat resolves: ATK applied, DEF as shield, CRT rolls
- [ ] AI turn executes automatically
- [ ] Game over triggers when HP ≤ 0
- [ ] Scoring formula produces correct values for known inputs (unit test mentally)

### Task 7.3: Commit Final Integration

```
git add -A
git commit -m "feat: complete word card game rewrite - constraint cards, scoring engine, sentence builder, AI, new UI"
```
