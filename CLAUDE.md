# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project

worders — Godot 4.6.3 文字卡牌对战。玩家 vs AI 拖拽卡牌造句，评分（紊乱×连击×修辞−违规）→ ATK/DEF/CRT，HP 归零判负。

```bash
godot                                    # 运行游戏（主菜单入口）
godot --scene res://scenes/test_runner.tscn  # 单元测试（28 tests）
```

Godot: `C:/Users/wsy13/Documents/godothub/engine/4.6.3-stable/godot.exe`

## Architecture

### Autoloads (init order)
`Events` → `CardDatabase` → `WordBank` → `TurnManager` → `BattleManager` → `AIController`

### Data flow
`drag/click card → SentenceBuilder → fill word → confirm → ScoringEngine → CombatResolver → Player HP/shield → Events → HUD refresh`

### Scenes
`main_menu.tscn` → `settings.tscn` → `battle.tscn` → game over → back to menu

### Core logic (RefCounted, unit-testable)
- **ScoringEngine** — `(base_disorder+semantic)×combo×rhetoric×(1-penalty)` → ATK/DEF/CRT allocation
- **StructureValidator** — missing subject/predicate: -20%, repeated non-repeatable: -15% each
- **RhymeDetector** — parallelism (≥3 consecutive), antithesis (mirror/repeat), rhyme (≥50% finals match)
- **SentenceBuilder** — Slot array, sorted by COMPONENT_ORDER
- **CombatResolver** — CRT probability = `crt/50`, DEF → shield + heal(50%)

### Interaction patterns
- **Click card** → `card_clicked` signal → `_on_card_clicked` → add to builder
- **Drag card** → `_get_drag_data()` returns CardData → drop on Control `_drop_data()` → add to builder
- **Click slot** → `word_input_requested` → dialog → set `slot.word`
- **Right-click slot** → `card_returned` → remove from builder, return to hand
- **Confirm button** → `BattleManager.confirm_sentence()` → scoring → combat → next turn

## Critical Conventions

### .tscn format (violations cause parse failure or invisible UI)
1. Root: `layout_mode = 3`, `anchors_preset = 15`, `anchor_right = 1.0`, `anchor_bottom = 1.0`
2. Children: `layout_mode = 0`, **one property per line, no semicolons**
3. Colors: `Color(r, g, b, a)` constructor only — never `Color.RED` etc.
4. Header: `[gd_scene load_steps=2 format=3]` with correct load_steps count
5. Script: `[ext_resource type="Script" path="..." id="1"]` then `script = ExtResource("1")` on node

### UI visibility
Every Button/Label needs explicit font_color. Project theme exists but is unreliable:
```
theme_override_colors/font_color = Color(1, 1, 1, 1)    # .tscn
label.add_theme_color_override("font_color", Color.WHITE)  # .gd dynamic
```

### Dynamic Control creation
When creating Controls in GDScript, always set position+size and font_color:
```gdscript
var p = Panel.new()
p.custom_minimum_size = Vector2(130, 60)
var style = StyleBoxFlat.new()
style.bg_color = Color(0.2, 0.22, 0.32, 1)
p.add_theme_stylebox_override("panel", style)
```

### Node paths
After any .tscn restructure, sync all `$NodePath` references in .gd scripts. Mismatch = `@implicit_ready` crash.

### Signals
All cross-module communication via `Events` autoload. Define signal in `events.gd`, emit from source, connect in target. No direct cross-module calls for UI updates.

### Testing
Add `test_xxx()` in `test_runner.gd` at the marked location. Pattern:
```gdscript
func test_xxx() -> void:
    print("\n--- XXX ---")
    assert_eq(actual, expected, "description")
```
Run: `godot --scene res://scenes/test_runner.tscn` — must be 28+ passed.

### Card data
`CardData` Resource: 3 enums (PartOfSpeech×8, SentenceComponent×7, ContentCategory×11) all include ANY. More constraints → higher `base_disorder`. Mana cost = `floor(word.length() * 1.0)`.

## Godot MCP

`@coding-solo/godot-mcp` (github.com/Coding-Solo/godot-mcp): can start/stop projects, read stdout/stderr, catch parse errors and crash stacks. **Cannot** click UI, screenshot, simulate input, or detect invisible UI. All visual verification must be done manually in the Godot editor.
