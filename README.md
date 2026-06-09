# WORDERS

**WORDERS** 是一款以中文填词造句为核心玩法的 1v1 文字卡牌对战游戏。玩家与 AI 轮流从手牌中选择填词牌、填写词语、构造句子；句子经评分引擎转化为攻击力 / 防御 / 暴击，先耗尽对方 HP 者获胜。

![Godot 4.6](https://img.shields.io/badge/Godot-4.6.3-blue)
![Platform](https://img.shields.io/badge/Platform-Windows-lightgrey)
![License](https://img.shields.io/badge/License-MIT-green)

## 下载

Windows 预编译包请从 [GitHub Releases](https://github.com/MUSH2077/worders/releases) 下载：

| 文件 | 说明 |
|------|------|
| `worders.exe` | 游戏主程序（双击运行） |
| `worders.pck` | 资源包（需与 exe 放在同一目录） |

> 首次运行若提示缺少文件，请确保 `worders.exe` 与 `worders.pck` 在同一文件夹内。

## 快速开始（源码）

### 环境要求

- [Godot Engine 4.6.3-stable](https://godotengine.org/download) 或更高 4.6.x
- （可选）DeepSeek API Key — 用于 AI 对手、聊天与词语判别

### 运行

```bash
# 打开 Godot 编辑器，导入本项目，按 F5 运行
# 或命令行：
godot --path .
```

### 单元测试

```bash
godot --headless --path . res://scenes/test_runner.tscn --quit-after 900
```

## 玩法概要

1. 将**填词牌**从手牌拖入造句区
2. **双击槽位**填写词语，或使用自动补词
3. 拖动槽位调整语序，触发排比 / 对仗 / 押韵等修辞加成
4. 点击**确认出牌** → 评分 → 战斗结算
5. 切换**姿态**（破势 / 守势 / 合律 / 平衡）改变风险收益
6. 在 Ally 聊天中输入 `/help` 查看斜杠命令（如 `/worders` 自动组句）

完整规则见游戏内「玩法说明」，或 [课程设计文档](docs/graphics-coursework-report.md)。

## 核心特性

- **造句即战斗** — 句子质量映射 ATK / DEF / CRT
- **三维软约束** — 词性 + 句子成分 + 内容类别，约束越窄收益越高
- **本地语义评分** — 词向量嵌入评估词语搭配合理性
- **修辞战斗化** — 排比、对仗、押韵转化为战斗倍率
- **双 Agent 聊天** — Enemy 对手 + Ally 助手，支持斜杠技能
- **可选 LLM 判别** — DeepSeek 异步复核未知词语（设置页配置）
- **中英文 UI** — 主菜单可切换语言

## 项目结构

```
worders/
├── scenes/          # Godot 场景（主菜单、对战、设置等）
├── scripts/         # GDScript 逻辑
├── resources/       # 卡牌、词库、美术素材、主题
├── docs/            # 设计文档与课程报告
└── project.godot    # 项目配置
```

## 从源码导出

1. Godot 编辑器 → **项目 → 导出**
2. 添加 **Windows Desktop** 预设
3. 导出为 `worders.exe`（资源可嵌入 exe 或单独导出 `.pck`）
4. 发布时请将 exe 上传至 GitHub Releases，**不要**提交进 Git（GitHub 单文件上限 100 MB）

## 设置（可选）

进入 **设置** 页面可配置：

- DeepSeek API Key
- 词语判别模式（关闭 / 仅记录 / 影响评分）
- 判别范围与超时

未配置 API Key 时，游戏使用本地脚本 AI，仍可正常对战。

## 文档

- [图形学课程设计报告](docs/graphics-coursework-report.md)
- [游戏设计文档](docs/superpowers/specs/2026-05-27-word-card-game-design.md)
- [嵌入模型集成说明](docs/embedding-model-integration.md)

## 技术栈

| 组件 | 技术 |
|------|------|
| 引擎 | Godot 4.6.3 |
| 语言 | GDScript |
| AI 对手 | DeepSeek Chat API（可选） |
| 语义评分 | 本地 EmbeddingService + word_bank |
| 测试 | test_runner.gd（headless） |

## 许可证

MIT License — 详见 [LICENSE](LICENSE)（如未包含则随项目发布补充）。
