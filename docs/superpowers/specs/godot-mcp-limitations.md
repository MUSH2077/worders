# Godot MCP 局限与应对

## 能力矩阵

| 操作 | MCP | 应对 |
|------|-----|------|
| 启动/停止项目 | ✅ | — |
| 读控制台日志/崩溃栈 | ✅ | — |
| **点击UI/拖拽/输入** | ❌ | 编辑器手动操作 |
| **截图验证渲染** | ❌ | 用户反馈 |
| **检测"UI不可见但无报错"** | ❌ | 每个节点加显式 font_color |
| 切换运行场景 | ✅ | --scene参数 |
| 多项目并行 | ❌ | stop后切换 |

## 最常见盲区

**节点路径不匹配** — .tscn改结构但.gd的$NodePath未同步。

MCP能捕获(有栈回溯)，但修复后须重跑验证。

**UI不可见** — 无报错但全透明。原因：字体=背景色、Theme未生效、节点出界。

应对：每个Button/Label加 `theme_override_colors/font_color = Color(1,1,1,1)`。

## 开发流程

```
改代码 → godot --scene test_runner.tscn → 28+ passed ✓
改UI → godot → 编辑器中手动验证
新模块 → 先在test_runner.gd加测试 → 再实现
报错 → get_debug_output → 读栈回溯 → 修复
```
