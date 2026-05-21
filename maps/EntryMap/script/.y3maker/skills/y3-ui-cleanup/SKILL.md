---
name: y3-ui-cleanup
description: |
  删除指定的UI面板文件，更新UI配置索引，并触发游戏热更。
  触发词：删除UI、清理UI、移除旧UI、UI热更
---

# Y3 UI 清理工具

## 🎯 功能说明

删除指定的UI面板文件，更新 `ui_config.json` 索引，并触发游戏热更。

## 📋 执行流程

```
用户请求删除UI
    │
    ▼
┌─────────────────────────────────────────────────────────────┐
│ 环节 1: 删除 UI JSON 文件                                   │
│                                                             │
│ 输入: UI面板名称列表（不含.json后缀）                         │
│ 输出: 删除 ui/{panel_name}.json 文件                        │
└─────────────────────────────────────────────────────────────┘
    │
    ▼
┌─────────────────────────────────────────────────────────────┐
│ 环节 2: 更新 UI 配置索引                                    │
│                                                             │
│ 输入: ui/ui_config.json                                     │
│ 输出: 从 panels 数组中移除已删除的UI面板                     │
└─────────────────────────────────────────────────────────────┘
    │
    ▼
┌─────────────────────────────────────────────────────────────┐
│ 环节 3: 触发游戏热更                                        │
│                                                             │
│ 执行: y3.editor.hotfix.ui()                                 │
│ 效果: 游戏内UI实时更新                                      │
└─────────────────────────────────────────────────────────────┘
```

## 📝 使用方式

### 删除单个UI面板

```bash
# 删除 DifficultyHUD.json
python -c "
import os
import json

ui_name = 'DifficultyHUD'
ui_dir = 'ui/'

# 删除UI文件
file_path = ui_dir + ui_name + '.json'
if os.path.exists(file_path):
    os.remove(file_path)
    print(f'Deleted: {file_path}')

# 更新配置索引
config_path = ui_dir + 'ui_config.json'
if os.path.exists(config_path):
    with open(config_path, 'r', encoding='utf-8') as f:
        config = json.load(f)
    if 'panels' in config:
        config['panels'] = [p for p in config['panels'] if p.get('name') != ui_name]
        with open(config_path, 'w', encoding='utf-8') as f:
            json.dump(config, f, ensure_ascii=False, indent=2)
        print('Updated ui_config.json')
"
```

### 删除多个UI面板

```bash
# 删除多个UI面板
python -c "
import os
import json

ui_names = ['DifficultyHUD', 'ArchiveMain', 'Choice_Panel', 'top']
ui_dir = 'ui/'

for name in ui_names:
    file_path = ui_dir + name + '.json'
    if os.path.exists(file_path):
        os.remove(file_path)
        print(f'Deleted: {file_path}')

config_path = ui_dir + 'ui_config.json'
if os.path.exists(config_path):
    with open(config_path, 'r', encoding='utf-8') as f:
        config = json.load(f)
    if 'panels' in config:
        config['panels'] = [p for p in config['panels'] if p.get('name') not in ui_names]
        with open(config_path, 'w', encoding='utf-8') as f:
            json.dump(config, f, ensure_ascii=False, indent=2)
        print('Updated ui_config.json')
"
```

### 触发热更

在游戏内 Lua 控制台执行：
```lua
y3.editor.hotfix.ui()
```

## 🎯 触发关键词

- 删除UI、清理UI、移除旧UI
- UI热更、热更新UI
- 删除画板、移除面板

## 📁 目录结构

```
maps/EntryMap/
├── ui/
│   ├── ui_config.json      # UI配置索引
│   ├── OutgamePanel.json   # 保留的UI
│   └── ...
└── script/.y3maker/skills/
    └── y3-ui-cleanup/
        └── SKILL.md        # 本文件
```

## ⚠️ 注意事项

1. **谨慎操作**：删除的UI文件无法恢复，请确认后再执行
2. **热更时机**：删除后必须触发热更才能生效
3. **索引更新**：务必同步更新 `ui_config.json`，否则可能导致错误

---

*最后更新: 2026-05-15*