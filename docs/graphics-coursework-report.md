# WORDERS 文字卡牌对战游戏 — 图形学课程设计报告

**项目名称：** WORDERS（文字卡牌对战）  
**开发引擎：** Godot 4.6.3-stable  
**开发语言：** GDScript  
**分辨率：** 1920×1080  
**文档日期：** 2026-06-09  

---

## 目录

1. [研究目的与意义](#1-研究目的与意义)
2. [开发环境与软件工具](#2-开发环境与软件工具)
3. [游戏概述](#3-游戏概述)
4. [系统设计与实现](#4-系统设计与实现)
5. [功能模块与类结构](#5-功能模块与类结构)
6. [游戏规则](#6-游戏规则)
7. [游戏难度与进阶系统](#7-游戏难度与进阶系统)
8. [场景、界面与动画制作](#8-场景界面与动画制作)
9. [游戏玩法说明](#9-游戏玩法说明)
10. [与同类游戏的对比与创新](#10-与同类游戏的对比与创新)
11. [运行截图](#11-运行截图)
12. [总结与展望](#12-总结与展望)

---

## 1. 研究目的与意义

### 1.1 研究目的

本课题旨在设计并实现一款以**中文填词造句**为核心机制的文字卡牌对战游戏。具体目标包括：

1. **图形界面与交互设计**：在 Godot 引擎中构建完整的 2D UI 对战界面，实现卡牌拖拽、槽位排序、实时评分预览等可视化交互。
2. **游戏逻辑与评分系统**：将语言学概念（词性、句子成分、修辞手法）转化为可计算的数值系统，使“造句质量”可量化并驱动战斗结算。
3. **语义计算集成**：引入本地词向量嵌入（Embedding）服务，评估相邻词语的语义搭配，使评分不仅依赖规则，还体现“语义连贯 vs 荒诞”的对比。
4. **智能对手与辅助 Agent**：集成大语言模型（DeepSeek API）作为 AI 对手与 Ally 助手，探索“规则引擎 + LLM”混合架构在文字游戏中的可行性。
5. **软件工程实践**：采用 Autoload 单例、信号总线、RefCounted 纯逻辑类分离等模式，保证核心逻辑可单元测试、UI 可独立迭代。

### 1.2 研究意义

| 维度 | 意义 |
|------|------|
| **教育意义** | 将语法、修辞知识游戏化，玩家在造句过程中自然接触主谓宾结构、排比对仗等概念。 |
| **技术意义** | 探索 2D UI 游戏 + NLP 轻量语义 + LLM 辅助的混合架构，为文字类独立游戏提供可参考的实现路径。 |
| **图形学意义** | 以 UI 动画（Tween）、粒子式墨迹特效、响应式布局为主，展示无 3D 角色情况下仍可通过动效与视觉层次营造“水墨书卷”风格的对战氛围。 |
| **创新意义** | 区别于传统 TCG/CCG 的“数值对撞”，本游戏以**句子评分 → ATK/DEF/CRT 分配 → HP 结算**构成独特核心循环。 |

---

## 2. 开发环境与软件工具

### 2.1 主要软件

| 软件 | 版本 | 用途 |
|------|------|------|
| **Godot Engine** | 4.6.3-stable | 游戏引擎：场景编辑、UI 布局、脚本逻辑、渲染、打包 |
| **GDScript** | — | 全部游戏逻辑与 UI 控制脚本 |
| **DeepSeek API** | Chat Completions | AI 对手出牌、聊天、分词、可选词语复核（L3 判别） |
| **Cursor / VS Code** | — | 代码编辑与 AI 辅助开发 |
| **Git** | — | 版本管理 |

### 2.2 辅助工具与资源

| 工具/资源 | 用途 |
|-----------|------|
| **fastText 词向量（预处理）** | 离线生成 `embedding_vectors.json`，供运行时语义评分 |
| **PNG 美术素材** | UI 面板、卡牌边框、背景、墨迹特效（存放于 `resources/art/`） |
| **JSON 数据文件** | 词库、拼音韵脚表、嵌入向量、卡牌 Resource |
| **Godot Theme** | `resources/default_theme.tres` 全局 UI 主题 |

### 2.3 运行方式

```bash
# 启动游戏（主菜单入口）
godot --path .

# 或使用项目内可执行文件
worders.exe

# 运行单元测试（无界面）
godot --headless --path . res://scenes/test_runner.tscn --quit-after 900
```

Godot 可执行文件路径（本机）：`C:/Users/wsy13/Documents/godothub/engine/4.6.3-stable/godot.exe`

---

## 3. 游戏概述

### 3.1 游戏类型

**1v1 回合制文字卡牌对战**：玩家与 AI 轮流从手牌中选择填词牌，拖入造句区并填写词语，确认后由评分引擎计算战斗力，转化为攻击/防御/暴击并结算 HP。

### 3.2 核心循环

```
抽牌 → 选牌（拖入造句槽）→ 填词（受卡牌约束）→ 实时预览评分
     → 确认出牌 → 评分（紊乱×连击×修辞−违规）→ 战斗结算
     → 局内事件/目标 → 对手回合 → 循环直至一方 HP 归零
```

### 3.3 视觉风格

采用**水墨书卷 + 金边 UI** 的 2D 平面风格：深色墨底面板、金色描边按钮、朱砂强调色、玩家蓝/AI 橙角色色区分。无 3D 人物模型，以头像环、卡牌、文字气泡和墨迹粒子表现对战氛围。

---

## 4. 系统设计与实现

### 4.1 总体架构

```
┌─────────────────────────────────────────────────────────────┐
│                        场景层 (Scenes)                       │
│  main_menu → settings / how_to_play → battle → game over   │
└──────────────────────────┬──────────────────────────────────┘
                           │ 信号 / 节点引用
┌──────────────────────────▼──────────────────────────────────┐
│                     UI 控制层 (Control Scripts)              │
│  battle_ui, card_ui, hand_ui, score_preview_panel, ...     │
└──────────────────────────┬──────────────────────────────────┘
                           │ Events 信号总线
┌──────────────────────────▼──────────────────────────────────┐
│                   Autoload 全局单例层                         │
│  BattleManager, TurnManager, AIController, LLMClient, ...   │
└──────────────────────────┬──────────────────────────────────┘
                           │
┌──────────────────────────▼──────────────────────────────────┐
│              纯逻辑层 (RefCounted，可单元测试)                 │
│  ScoringEngine, SentenceBuilder, CombatResolver, ...         │
└─────────────────────────────────────────────────────────────┘
```

### 4.2 设计原则

1. **逻辑与表现分离**：评分、战斗、造句等核心逻辑为 `RefCounted` 类，不依赖场景树，可在 `test_runner.gd` 中直接测试。
2. **信号驱动 UI 更新**：跨模块通信统一通过 `Events` Autoload 发信号，避免 UI 脚本直接调用 BattleManager 的内部状态。
3. **软约束评分**：词语与卡牌约束不完全匹配时不禁止出牌，而是通过加分/风险惩罚体现，降低挫败感。
4. **可选 LLM 增强**：DeepSeek 用于 AI 出牌与聊天；词语 L3 复核、分词、Ally 技能为可配置增强层，离线时回退到脚本 AI。

### 4.3 数据流（一次出牌）

```
玩家拖牌 → SentenceBuilder.add_slot()
        → ConstraintValidator 校验约束 → UI 显示贡献芯片
        → 填词 → ScoringEngine.preview() → ScorePreviewPanel 刷新
        → 点击确认 → BattleManager.confirm_sentence()
        → ScoringEngine.score() → CombatResolver.resolve()
        → Player.take_damage / add_shield / heal
        → Events 广播 → battle_ui 播放动画、刷新 HUD
        → TurnManager 切换阶段 → AIController 或下一玩家回合
```

### 4.4 评分公式（概要）

```
总分 = (基础紊乱 + 语义嵌入加成) × 连击倍率 × 修辞加成 × (1 − 违规惩罚)
ATK / DEF / CRT 由句子成分权重 + 姿态修正分配
```

- **紊乱度**：卡牌基础分 + 词嵌入相邻相似度（搭配合理则降低紊乱）
- **连击倍率**：句子越长倍率越高（≥3 词起算）
- **修辞加成**：排比、对仗、押韵（基于拼音韵脚表检测）
- **违规惩罚**：缺主语/谓语、重复不可重复成分等

---

## 5. 功能模块与类结构

### 5.1 模块总览

| 模块 | 职责 | 主要类/脚本 |
|------|------|-------------|
| **主菜单与导航** | 入口、设置、玩法说明 | `main_menu.gd`, `how_to_play.gd`, `settings_ui.gd` |
| **战斗流程** | 开局、回合、确认出牌、胜负 | `battle_manager.gd`, `turn_manager.gd`, `player.gd`, `deck.gd` |
| **造句系统** | 槽位管理、排序、填词 | `sentence_builder.gd`, `sentence_slot_ui.gd`, `word_input_dialog.gd` |
| **卡牌系统** | 卡牌数据、牌库、手牌 UI | `card_data.gd`, `card_database.gd`, `card_ui.gd`, `hand_ui.gd` |
| **评分引擎** | 紊乱、连击、修辞、成分分配 | `scoring_engine.gd`, `structure_validator.gd`, `rhyme_detector.gd`, `constraint_validator.gd` |
| **战斗结算** | ATK/DEF/CRT → 伤害/护盾/治疗 | `combat_resolver.gd` |
| **语义服务** | 词向量、句子连贯度 | `embedding_service.gd`, `word_bank.gd` |
| **AI 系统** | 脚本 AI + LLM 对手 | `ai_controller.gd`, `ai_profile.gd`, `llm_client.gd` |
| **Ally 技能** | 斜杠命令、自动组句 | `battle_skill_registry.gd` |
| **局内事件** | 偶数回合选择、每五回合诅咒 | `battle_event_choice.gd`, `battle_objective.gd` |
| **姿态系统** | 破势/守势/合律/平衡 | `tactical_stance.gd`, `role_meter.gd` |
| **UI 与动效** | 主题、动画、特效 | `battle_ui.gd`, `ui_theme.gd`, `ui_motion.gd`, `battle_fx_director.gd`, `score_preview_panel.gd`, `slot_contribution_chip.gd` |
| **聊天面板** | 双 Agent（Enemy / Ally） | `battle_chat_panel.gd` |
| **国际化** | 中英文切换 | `i18n.gd` |
| **音频** | BGM / SFX | `audio_director.gd` |
| **测试** | 单元测试入口 | `test_runner.gd` |

### 5.2 Autoload 单例（启动顺序）

| 单例 | 文件 | 说明 |
|------|------|------|
| `I18n` | `i18n.gd` | 多语言字符串 |
| `Events` | `events.gd` | 全局信号定义 |
| `CardDatabase` | `card_database.gd` | 加载全部 `.tres` 卡牌 |
| `WordBank` | `word_bank.gd` | 词库与别名 |
| `EmbeddingService` | `embedding_service.gd` | 词向量语义 |
| `TurnManager` | `turn_manager.gd` | 回合阶段机 |
| `BattleManager` | `battle_manager.gd` | 对战总控 |
| `AIController` | `ai_controller.gd` | AI 决策 |
| `LLMClient` | `llm_client.gd` | DeepSeek API |
| `BattleRecorder` | `battle_recorder.gd` | 对战记录 |
| `AudioDirector` | `audio_director.gd` | 音频播放 |

### 5.3 核心类说明

#### CardData（卡牌资源）

- **枚举**：`PartOfSpeech`（8 种词性）、`SentenceComponent`（7 种句子成分）、`ContentCategory`（11 种内容类别）
- **类型**：填词牌 / 功能牌 / 装备牌 / 状态牌
- **字段**：`base_disorder`（基础紊乱值）、约束组合、法力消耗规则

#### SentenceBuilder

- 维护 `Slot` 数组，按 `COMPONENT_ORDER` 自动排序
- 每个 Slot 绑定一张 `CardData` 与用户填写的 `word`

#### ScoringEngine

- 输入：`SentenceInput`（槽位 + 词语 + 姿态 + 上下文）
- 输出：`ScoreBreakdown`（ATK、DEF、CRT、紊乱、连击、修辞标志、`judgment_trace` 等）

#### Player

- 属性：HP（30）、护盾、法力（起始 3，上限 10）、手牌、牌库
- 状态：当前姿态、流派印记、回合目标、AI 档案

#### AIProfile

- 三种对手人格：`Rush Poet`（攻击）、`Harmony Scholar`（修辞）、`Ward Scribe`（防御）
- 按对战种子 `battle_seed` 选择，影响 AI 姿态偏好与 LLM 系统提示

### 5.4 场景文件结构

| 场景 | 路径 | 说明 |
|------|------|------|
| 主菜单 | `scenes/main_menu.tscn` | 游戏入口 |
| 设置 | `scenes/settings.tscn` | API Key、判别模式、语言 |
| 玩法说明 | `scenes/how_to_play.tscn` | 规则文本 |
| **对战主场景** | `scenes/battle.tscn` | 核心游戏界面 |
| 卡牌预制 | `scenes/card.tscn` | 单张卡牌 UI |
| 造句槽 | `scenes/sentence_slot.tscn` | 单个造句槽位 |
| 玩家 HUD | `scenes/player_hud.tscn` | HP/法力/护盾 |
| 测试 | `scenes/test_runner.tscn` | 无界面单元测试 |

### 5.5 卡牌规模

- **填词牌**：30 张（`fill_01` ~ `fill_30`）
- **功能牌**：8 张（抽牌、回蓝、净化、偷牌等）
- **装备牌**：5 张（持续增益）
- **状态牌**：5 张（ debuff / buff）

---

## 6. 游戏规则

### 6.1 胜利条件

先使对方 **HP 降至 0** 的一方获胜。初始 HP 为 **30**。

### 6.2 回合流程

1. **抽牌阶段**：从牌库抽牌补满手牌（默认上限 7）
2. **主阶段**：
   - 将填词牌拖入造句区（最多 7 槽）
   - 双击槽位或点击输入框填写词语
   - 可拖槽调整语序以触发不同修辞
   - 功能/装备/状态牌可双击或拖放立即生效
   - 选择战术姿态（平衡 / 破势 / 守势 / 合律）
3. **确认出牌**：
   - 消耗与填词字数相关的法力
   - 评分 → 战斗结算（攻击扣血、防御加护盾、暴击概率伤害）
   - 触发本回合局内事件（若有）
4. **结束回合**：切换至 AI；玩家也可手动结束或等待倒计时

### 6.3 法力规则

```
cost = floor(词语字数 × 1.0)   （按槽内填词总字数计）
起始法力 = 3，每回合刷新；可通过事件/装备提升上限（最高 10）
```

### 6.4 战斗属性分配

| 句子成分 | 倾向 |
|----------|------|
| 谓语、宾语、补语 | 攻击 (ATK) |
| 主语、定语 | 防御/护盾 (DEF)，部分治疗 |
| 状语 | 暴击 (CRT) |

暴击触发概率 ≈ `CRT / 50`，防御转化为护盾并附带 50% 数值的治疗。

### 6.5 约束规则（软约束）

- 每张填词牌带有**词性 / 句子成分 / 内容类别**约束（可为“无约束”）
- **完全匹配**：小幅奖励
- **词库已知但不匹配**：增加风险惩罚
- **未知词**：仍可出牌；若开启 L3 判别，确认后异步请求 DeepSeek 复核并缓存结果

### 6.6 修辞检测

- **排比**：连续 ≥3 个结构相似的槽位
- **对仗**：相邻成分镜像或重复模式
- **押韵**：相邻词拼音韵脚匹配率 ≥50%（依赖 `pinyin_rhyme_map.json`）

### 6.7 特殊机制

- **偶数回合**：出现二选一事件（抽牌、回蓝、增益等）
- **每 5 回合**：诅咒压力 + 补偿选择
- **回合目标**：每回合随机目标（如 S+P+O 完整句、无约束风险句等），完成获得奖励
- **聊天指令**：`/help`、`/suggest`、`/fill`、`/play`、`/worders`（自动分词组句）等

---

## 7. 游戏难度与进阶系统

### 7.1 难度来源

| 因素 | 说明 |
|------|------|
| **AI 人格** | 三种 AI 档案按种子轮换，攻击型/修辞型/防御型策略不同 |
| **约束宽度** | 窄约束牌紊乱值高、难填但收益大；宽约束灵活但基础分低 |
| **姿态博弈** | 破势高攻低防、守势高防低攻、合律强化约束匹配 |
| **法力管理** | 长句高消耗，需平衡句子长度与资源 |
| **事件压力** | 诅咒回合与随机事件增加局势变数 |
| **时间限制** | 玩家回合 120 秒倒计时（可手动结束） |

### 7.2 进阶路径（单局内）

1. **入门**：使用“无约束”填词牌 + 自动补词，熟悉 S+P 最低句型
2. **进阶**：主动凑 S+P+O、利用排比/押韵提高修辞倍率
3. **高级**：根据 AI 档案切换姿态（如对 Rush Poet 用 Guard）
4. **专家**：窄约束高紊乱牌 + 合律姿态 + 嵌入语义搭配最优化
5. **辅助进阶**：Ally 聊天 `/worders` 自动分词组句，玩家仅确认出牌

### 7.3 动画速度

对战内可切换 **1× / 2× / 4×** 动画速度，便于复盘与快速对战。

---

## 8. 场景、界面与动画制作

### 8.1 场景创建方式

全部场景在 **Godot 编辑器** 中可视化搭建：

1. 根节点使用 `Control`，全屏锚点（`anchors_preset = 15`）
2. 子节点采用 `VBoxContainer` / `HBoxContainer` / `Panel` / `ScrollContainer` 布局
3. 脚本通过 `@onready var` 绑定节点路径
4. 动态创建的 UI（手牌、槽位、聊天气泡）在 GDScript 中 `new()` 并 `add_child()`

**无 3D 场景、无骨骼动画角色**。对战呈现为 2D UI 层叠结构。

### 8.2 人物/角色表现

本游戏不采用传统“角色精灵图”，而以以下元素代表对战双方：

| 元素 | 实现 |
|------|------|
| 玩家/AI 头像环 | PNG 素材 `ui_avatar_ring_player.png` / `ui_avatar_ring_ai.png` |
| 名称与 HP 条 | `player_hud.tscn` + `Label` / `ProgressBar` |
| 角色色 | 玩家蓝 `PLAYER_BLUE`、AI 橙 `AI_ORANGE`（`ui_theme.gd` 常量） |
| AI 思考状态 | `battle_ui.gd` 中 Tween 闪烁 “...” 指示 |

### 8.3 美术资源制作

| 类别 | 路径 | 说明 |
|------|------|------|
| 主菜单背景 | `resources/art/ui/menu_background_ink_polished.png` | 水墨风格，AI 辅助生成 + 人工裁剪 |
| 对战背景叠加 | `resources/art/ui/battle_background_ink_overlay.png` | 半透明墨韵层 |
| UI 面板 | `ui_panel_ink_dark.png`, `ui_panel_paper_gold.png` | 九宫格 StyleBox 贴图 |
| 按钮 | `ui_button_ink_gold.png`, `ui_button_cinnabar.png` | 正常/悬停/按下三态由 StyleBox 模拟 |
| 卡牌边框 | `card_frame_fill/function/equipment/status.png` | 四类卡牌视觉区分 |
| 墨迹特效 | `fx_ink_red/blue/green/gold/black.png` | 攻击/护盾/治疗/暴击时粒子贴图 |
| 事件卷轴 | `ui_event_scroll.png` | 偶数回合事件面板 |

未到位素材时使用 **StyleBoxFlat 纯色圆角面板 + Unicode 符号**（❤️ 🛡️ ⚡）作为占位，见 `docs/superpowers/specs/asset-list.md`。

### 8.4 动画实现

**不使用 AnimationPlayer 骨骼动画**，全部采用 **Godot Tween** 程序化动画：

| 动画 | 实现位置 | 效果 |
|------|----------|------|
| 卡牌悬停放大 | `card_ui.gd` | scale 1.0 → 1.045 |
| 卡牌拖入槽位 | `battle_ui.gd` | 位置 + 缩放补间 |
| 确认出牌句子飞出 | `battle_ui.gd` `_animate_sentence_submit()` | 槽位文字上浮、缩放飞入评分面板 |
| 数值飞入 | `battle_ui.gd` `_spawn_score_stat_fly_ins()` | ATK/DEF/CRT 数字飞向 HUD |
| 攻击/暴击墨迹 | `battle_fx_director.gd` | 粒子式 TextureRect 飞散 |
| 聊天气泡 | `battle_ui.gd` | 上浮淡出 |
| UI 入场 | `ui_motion.gd` | rise / pulse 预设 |
| 低 HP 屏闪 | `battle_ui.gd` | 红色 modulate 脉冲 |

动画速度受 `BattleManager.animation_speed` 统一缩放。

### 8.5 主题与字体

- 全局主题：`resources/default_theme.tres`
- 运行时样式：`UiTheme` 静态类提供 `panel_style()` / `button_style()` / `apply_input()` 等
- 所有 `Label`/`Button` 必须显式设置 `font_color`，避免引擎默认主题导致不可见

---

## 9. 游戏玩法说明

### 9.1 启动与设置

1. 运行 `worders.exe` 或 Godot 打开项目
2. 主菜单 → **开始对战** 进入 `battle.tscn`
3. （可选）**设置** 中配置 DeepSeek API Key、词语判别模式、语言（中/英）
4. **玩法说明** 菜单内可查看完整规则摘要

### 9.2 基本操作

| 操作 | 方法 |
|------|------|
| 打出填词牌 | 从手牌**拖拽**到造句区 |
| 填写词语 | **双击**槽位，或点击“选词”按钮 |
| 调整语序 | **拖拽**造句区内槽位 |
| 退回卡牌 | **右键**槽位 |
| 使用功能牌 | **双击**或拖至指定区域 |
| 切换姿态 | 点击姿态按钮（平衡/破势/守势/合律） |
| 确认出牌 | 点击 **确认出牌**（预览面板显示预计 ATK/DEF/CRT） |
| 结束回合 | 点击 **结束回合** |
| 聊天辅助 | 打开 Ally 标签，输入 `/help` 或 `/worders 句子` |

### 9.3 界面区域说明（battle.tscn）

```
┌──────────────────────────────────────────────────────────┐
│  [AI HUD]                          [计时器] [姿态] [速度] │
├──────────────────────────────────────────────────────────┤
│                                                          │
│              造句区（槽位 + 贡献芯片 + 预览）              │
│                                                          │
├──────────────────────────────────────────────────────────┤
│  [评分预览 ATK/DEF/CRT/紊乱/连击/语义]                    │
├──────────────────────────────────────────────────────────┤
│  [手牌扇形布局]              [确认] [结束回合] [自动补词]   │
├──────────────────────────────────────────────────────────┤
│  [聊天面板 Enemy|Ally]  [图鉴] [调试]                     │
└──────────────────────────────────────────────────────────┘
```

### 9.4 推荐新手流程

1. 拖 2~3 张牌（至少含主语+谓语）
2. 点击 **自动补词** 或双击填词
3. 查看预览面板 ATK/DEF 变化
4. 确认出牌，观察战斗动画与 HP 变化
5. 第二回合起尝试切换 **守势** 应对 AI 攻击

---

## 10. 与同类游戏的对比与创新

### 10.1 同类游戏参考

| 游戏/类型 | 特点 | 与本项目关系 |
|-----------|------|--------------|
| **炉石传说 / 杀戮尖塔** | 传统 TCG/ Roguelike 卡牌，数值与效果驱动 | 借鉴回合制与手牌管理，但**核心动作是造句而非打出效果牌** |
| **文字游戏 / 填字** | 静态解谜，无对战 | 本游戏将填词与**实时 PvE 对战**结合 |
| **AI 文字冒险** | 纯 LLM 对话，无规则引擎 | 本游戏以**规则引擎为主、LLM 为辅**，保证可预测竞技性 |

### 10.2 主要改进与创新

| 创新点 | 说明 |
|--------|------|
| **造句即战斗** | 句子质量直接映射 ATK/DEF/CRT，而非卡牌费用交换 |
| **三维软约束** | 词性 + 句子成分 + 内容语义，约束越窄收益越高 |
| **嵌入语义评分** | 本地词向量评估搭配合理性，“温暖的阳光” vs “燃烧的冰箱” |
| **修辞战斗化** | 排比/对仗/押韵转化为可堆叠的战斗倍率 |
| **姿态系统** | 破势/守势/合律改变同一句话的风险收益结构 |
| **双 Agent 聊天** | Enemy 嘲讽 + Ally 助手，Ally 可 `/worders` 自动分词组句 |
| **L3 可选词语判别** | DeepSeek 异步复核未知词，结果缓存，不阻塞出牌 |
| **结构化评分追踪** | `judgment_trace` 每槽可见匹配/风险原因，提高透明度 |
| **水墨 UI + 程序化墨迹** | 无 3D 资源仍通过 2D 动效营造风格化对战反馈 |

---

## 11. 运行截图

> **说明：** 请在 Godot 编辑器中运行游戏或使用 `worders.exe` 截取以下界面，将图片放入 `docs/screenshots/` 目录并替换下方占位路径。

### 11.1 主菜单

![主菜单](screenshots/01_main_menu.png)

*图 11-1：主菜单 — 水墨背景、开始对战 / 设置 / 玩法说明入口*

**截图步骤：** 启动游戏 → 主菜单全屏截图（1920×1080）

---

### 11.2 对战主界面

![对战界面](screenshots/02_battle_main.png)

*图 11-2：对战主界面 — 手牌、造句区、评分预览、AI/玩家 HUD*

**截图步骤：** 开始对战 → 拖入 2~3 张牌并填词 → 截取完整 UI

---

### 11.3 确认出牌与战斗动画

![战斗结算](screenshots/03_combat_resolve.png)

*图 11-3：确认出牌后 — 句子飞出、数值飞入、墨迹特效*

**截图步骤：** 点击确认出牌 → 在 ATK 数字飞入或墨迹特效播放时截图

---

### 11.4 评分预览面板

![评分预览](screenshots/04_score_preview.png)

*图 11-4：评分预览 — 紊乱度、连击、语义(Sem)、ATK/DEF/CRT、槽位贡献芯片*

**截图步骤：** 填词后、确认前 → 展开预览面板特写

---

### 11.5 设置界面

![设置](screenshots/05_settings.png)

*图 11-5：设置 — API Key、词语判别模式、Judgment 范围、语言切换*

---

### 11.6 双 Agent 聊天

![聊天](screenshots/06_dual_chat.png)

*图 11-6：Enemy / Ally 双标签聊天，Ally `/worders` 自动组句*

---

### 11.7 游戏结束

![胜负](screenshots/07_game_over.png)

*图 11-7：胜利或失败面板*

---

### 11.8 单元测试通过（可选）

![测试](screenshots/08_tests_passed.png)

*图 11-8：headless 模式运行 test_runner，全部测试通过*

```bash
godot --headless --path . res://scenes/test_runner.tscn --quit-after 900
```

---

## 12. 总结与展望

### 12.1 完成情况

本项目完成了从主菜单到对战结算的完整游戏循环，包含 48 张卡牌、评分引擎、AI 对手、语义嵌入、双 Agent 聊天、斜杠技能、国际化与 35+ 单元测试。图形方面以 **2D UI + Tween 动画 + 水墨美术** 为主，符合轻量独立游戏开发路线。

### 12.2 不足与改进方向

| 方向 | 说明 |
|------|------|
| 美术 | 部分区域仍使用 StyleBox 占位，可替换为统一水墨 UI 套件 |
| 音效 | 音效系统框架已有，素材可进一步补齐 |
| 联机 | 当前仅 PvE，可扩展 PvP 网络对战 |
| 进度 | 可增加战役模式、Deck Building 元进度 |
| 3D | 若课程要求 3D，可引入书卷/墨滴 3D 粒子或简单 3D 背景 |

### 12.3 参考文献与资料

1. Godot 4.x 官方文档：https://docs.godotengine.org/  
2. 项目设计文档：`docs/superpowers/specs/2026-05-27-word-card-game-design.md`  
3. 嵌入模型集成说明：`docs/embedding-model-integration.md`  
4. 美术素材清单：`docs/superpowers/specs/asset-list.md`  
5. fastText 词向量：https://fasttext.cc/docs/en/pretrained-vectors.html  
6. DeepSeek API 文档：https://platform.deepseek.com/api-docs/  

---

**附录：项目目录结构（核心部分）**

```
worders/
├── project.godot          # 引擎配置、Autoload 列表
├── scenes/                # 场景文件 (.tscn)
├── scripts/               # GDScript 逻辑 (.gd)
├── resources/
│   ├── cards/             # 卡牌 Resource (.tres)
│   ├── art/               # PNG 美术素材
│   ├── word_bank.json     # 词库
│   ├── embedding_vectors.json
│   └── default_theme.tres
├── docs/                  # 设计文档与本报告
└── worders.exe            # Windows 导出可执行文件
```

---

*文档版本：1.0 | 生成日期：2026-06-09*
