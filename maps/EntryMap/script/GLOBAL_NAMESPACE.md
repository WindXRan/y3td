# 全局命名空间规范

## 概述

本项目采用统一的全局命名空间架构，系统通过 `_G.SYSTEM` 命名空间访问，工具函数通过 `_G.模块名.方法` 的方式调用。

## 命名空间结构

### 核心状态

| 变量名 | 类型 | 说明 |
|-------|------|------|
| `_G.STATE` | table | 运行时状态表，包含英雄、敌人、资源等实时数据 |
| `_G.CONFIG` | table | 配置表，包含关卡、技能、挑战等配置数据 |

### _G.SYSTEM 命名空间

系统服务定位器，所有业务系统都注册在此：

| 子命名空间 | 来源模块 | 职责 |
|-----------|---------|------|
| `SYSTEM.skill` | runtime.skill_system | **技能系统**（合并了框架/攻击技能/生成技能/样本技能） |
| `SYSTEM.battle` | runtime.battle_system | **战场系统**（合并了战场/自动激活效果） |
| `SYSTEM.debug` | runtime.debug_system | **调试系统**（合并了调试动作/调试工具/特效调试） |
| `SYSTEM.ui` | runtime.ui_system | **UI系统**（合并了HUD/UI辅助/武器提示/结算面板） |
| `SYSTEM.outgame` | runtime.outgame_system | **局外系统**（合并了会话状态/局外/英雄选择范围） |
| `SYSTEM.buff` | runtime.buff_system | Buff 系统 |
| `SYSTEM.progression` | runtime.progression | 升级系统 |
| `SYSTEM.reward` | runtime.rewards | 奖励系统 |
| `SYSTEM.audio` | runtime.audio | 音频系统 |
| `SYSTEM.hero_attr` | runtime.hero_attr_system | 英雄属性系统 |
| `SYSTEM.hero_model` | runtime.hero_model | 英雄模型系统 |
| `SYSTEM.damage_api` | runtime.skill_damage_templates | 伤害模板 API |
| `SYSTEM.battle_auto_acceptance` | runtime.battle_auto_acceptance | 战斗自动接受系统 |
| `SYSTEM.gm_bond_effects` | boot.lua (stub) | GM 羁绊效果面板 |
| `SYSTEM.attr_choice` | runtime.rewards | 属性选择系统 |

**合并后的系统数量**：从 26 个减少到 **15 个**

### SYSTEM.skill — 技能系统

```lua
-- 技能系统子模块
SYSTEM.skill.framework   -- skill_framework 核心
SYSTEM.skill.attack      -- attack_skills 运行时
SYSTEM.skill.generated   -- generated_skills 生成器
SYSTEM.skill.samples     -- sample_skills 样本

-- 常用 API
SYSTEM.skill.cast(skill_def)                    -- 施放技能
SYSTEM.skill.unlock_attack_skill(skill_id)     -- 解锁技能
SYSTEM.skill.update_attack_skills(dt)          -- 更新技能
SYSTEM.skill.sync_basic_attack_ability()        -- 同步普攻
```

### SYSTEM.battle — 战场系统

```lua
-- 战场系统子模块
SYSTEM.battle.battlefield   -- battlefield 战场
SYSTEM.battle.auto_effects   -- auto_active_effects 自动效果

-- 常用 API
SYSTEM.battle.get_current_wave()       -- 获取当前波次
SYSTEM.battle.force_spawn_boss()       -- 强制生成Boss
SYSTEM.battle.is_active_enemy(unit)   -- 判断敌人是否活跃
```

### SYSTEM.debug — 调试系统

```lua
-- 调试系统子模块
SYSTEM.debug.actions  -- debug_actions 动作
SYSTEM.debug.tools    -- debug_tools 工具
SYSTEM.debug.effects  -- effect_debug 特效
SYSTEM.debug.gm_bond_effects -- GM羁绊存根

-- 常用 API
SYSTEM.debug.show_debug_hotkey_help()  -- 显示快捷键帮助
SYSTEM.debug.update(dt)                -- 更新调试状态
```

### SYSTEM.ui — UI系统

```lua
-- UI系统子模块
SYSTEM.ui.hud        -- runtime_hud HUD
SYSTEM.ui.helpers    -- runtime_ui_helpers 辅助
SYSTEM.ui.growth_tip -- growth_weapon_item_tip 武器提示
SYSTEM.ui.result     -- result_panel 结算面板
```

### SYSTEM.outgame — 局外系统

```lua
-- 局外系统子模块
SYSTEM.outgame.session    -- session_state 会话状态
SYSTEM.outgame.outgame   -- outgame 局外
SYSTEM.outgame.hero_range -- hero_selection_range 英雄范围

-- 常用 API
SYSTEM.outgame.session.start_selected_stage()  -- 开始选关
SYSTEM.outgame.outgame.refresh_stage_selection() -- 刷新选关
```

### 工具模块

工具函数按功能分类到不同模块：

| 模块名 | 职责 | 函数列表 |
|-------|------|---------|
| `_G.AreaUtils` | 区域相关 | `get_area`, `random_point_in_area` |
| `_G.AttrUtils` | 属性相关 | `set_attr_pack`, `add_attr_pack`, `snapshot_hero_attrs`, `build_runtime_attr_dialog_chunks`, `show_runtime_attr_dialog` |
| `_G.HeroUtils` | 英雄相关 | `get_hero_facing_towards` |
| `_G.BattleUtils` | 战场相关 | `is_active_enemy`, `get_current_wave`, `get_boss_name`, `show_runtime_status`, `get_enemy_runtime_info`, `is_boss_runtime_enemy`, `is_elite_runtime_enemy` |
| `_G.HudUtils` | HUD 相关 | `get_hud_system`, `get_runtime_hud_system_fn`, `set_battle_hud_visible`, `sync_basic_attack_ability` |
| `_G.DebugUtils` | 调试相关 | `debug_message`, `show_debug_hotkey_help`, `is_debug_effect_mounted` |
| `_G.SkillUtils` | 技能相关 | `show_attack_skill_loadout`, `unlock_attack_skill` |
| `_G.AutoEffectUtils` | 自动激活效果 | `notify_auto_active_basic_attack`, `notify_auto_active_skill_cast` |
| `_G.AudioUtils` | 音频相关 | `play_basic_attack_sound`, `play_attack_skill_sound`, `play_ui_click`, `play_enemy_death_sound` |
| `_G.PointUtils` | 点操作相关 | `create_offset_point` |
| `_G.BondUtils` | 羁绊相关 | `update_bond_effects`, `get_bond_runtime_bonus`, `has_bond_route_tag`, `notify_bond_attack_skill_cast` |

### 核心模块导出

| 模块名 | 来源 | 说明 |
|-------|------|------|
| `_G.BondSystem` | runtime.bonds_chain | 羁绊系统核心模块 |
| `_G.BootCombat` | runtime.boot_combat | 战斗工具模块 |
| `_G.AudioResources` | data.tables.audio_resources | 音频资源配置 |

## 使用方式

### 系统模块调用

```lua
-- 使用合并后的 SYSTEM 命名空间
_G.SYSTEM.skill.cast(skill_def)
_G.SYSTEM.battle.get_current_wave()
_G.SYSTEM.debug.show_debug_hotkey_help()
_G.SYSTEM.ui.hud.toggle_attr_panel()

-- 访问子系统
_G.SYSTEM.skill.attack.unlock_attack_skill(skill_id)
_G.SYSTEM.battle.auto_effects.update(dt)
```

### 工具模块调用

```lua
-- 使用模块级调用
_G.AreaUtils.get_area('defense_zone')
_G.BattleUtils.get_current_wave()
_G.AudioUtils.play_ui_click()

-- 缓存局部引用
local BC = _G.BootCombat
local BattleUtils = _G.BattleUtils

BC.get_current_hero()
BattleUtils.show_runtime_status()
```

## 加载顺序

全局命名空间的初始化顺序由 `boot.lua` 控制：

1. **数据表和配置** → CONFIG、AttackSkillObjects
2. **核心状态** → STATE
3. **工具模块** → boot_utils (模块级导出)
4. **业务系统** → 按依赖顺序初始化并注册到 SYSTEM
5. **UI 系统** → HUD、面板等

## 命名规范

- **系统名**：使用小写蛇形命名（`skill_framework`）
- **合并系统名**：使用 PascalCase（`SkillSystem`, `BattleSystem`）
- **模块名**：使用 PascalCase（`AreaUtils`）
- **函数名**：使用小写蛇形命名（`get_current_hero`）
- **常量**：使用大写蛇形命名（`ATTACK_SKILL_DEFS`）
- **状态变量**：使用 PascalCase（`STATE.hero`）

## 扩展指南

### 新增系统注册

在模块末尾添加 SYSTEM 注册：

```lua
-- 单个系统
_G.SYSTEM.my_new_system = my_system

-- 合并系统：在合并模块中添加
local MyNewSystem = {}
MyNewSystem.module_a = require 'module_a'
MyNewSystem.module_b = require 'module_b'
_G.SYSTEM.my_new_system = MyNewSystem
```

### 新增工具模块

在 `boot_utils.lua` 中添加新模块：

```lua
local MyNewUtils = {}

MyNewUtils.my_function = function(...)
    -- 实现
end

_G.MyNewUtils = MyNewUtils
```
