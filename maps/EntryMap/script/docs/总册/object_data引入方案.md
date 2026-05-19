# object_data 物编数据驱动体系 —— 引入方案

> 状态：设计稿 | 作者：Lead Programmer | 日期：2026-05-19
>
> 目标：将 xunhuanquan 的 `object_data` 体系引入当前项目，
> 实现纯 Lua 侧的物编对象定义，与现有的 CSV 配表 + Y3 GUI 编辑器体系互补共存。

---

## 1. 背景与现状分析

### 1.1 当前项目的对象定义方式

当前项目（自走棋/羁绊玩法）的物编对象完全依赖 **Y3 GUI 编辑器手工创建**：

| 维度 | 现状 |
|------|------|
| **单位** | 英雄、敌人模板在编辑器中创建，`editor_table/editorunit/` 下存有 JSON |
| **技能** | 在编辑器中创建，`ability/` 下目前只有 1 个技能 JSON (`201347498.json`)，`runtime_editor_ids.lua` 硬编码了 16 个技能 ID 和 20+ 投射物 ID |
| **物品** | 编辑器中创建，`editor_table/editoritem/` 下有 JSON |
| **魔法效果** | 编辑器中创建，`modifier/` 目录、`runtime_editor_ids.lua` 中硬编码了 `modifier` 映射表 |
| **投射物** | 编辑器中创建，`projectile/` 目录下可能为空（资源在 `editor_table/projectileall/`） |
| **配置数据** | CSV 驱动：`data/game_tables.lua` 通过 `CsvLoader` 加载 `data_csv/*.csv`，转换为 Lua 表 |

核心特征：
- **对象 ID 与数据分离**：编辑器负责模型/碰撞/动画等"实物"，代码通过硬编码 ID 引用
- **CSV 配表承载玩法配置**：波次、敌人属性倍率、英雄名册等
- **`runtime_editor_ids.lua`** 作为"ID 字典"：集中管理 `ability.{key=id}` / `projectile.{key=id}` / `modifier.attack_status.{key=id}` 映射

### 1.2 xunhuanquan object_data 体系概述

xunhuanquan 项目（三国策略玩法）的 `object_data/` 是一套 **纯 Lua 物编数据定义与生成系统**：

| 文件 | 职责 | 行数 |
|------|------|------|
| `init.lua` | 工厂函数 `od.unit{}` / `od.ability{}` / `od.item{}` / `od.buff{}` / `od.destructible{}` / `od.projectile{}` / `od.technology{}`，模板继承 (`define_template` / `extend`)，批量注册 (`build_all`)，触发器绑定 (`wire`) | 892 |
| `enums.lua` | 30+ 个枚举表：UnitType, AttackType, ArmorType, DamageType, AbilityCastType, ModifierType 等 | 300 |
| `od_y3_bridge.lua` | 将 object_data 注入 `y3.object.unit[key]` / `y3.object.ability[key]`，支持回调注入和 `auto_create` | 296 |
| `build.py` | Python 构建脚本，JSON → Lua 编译，支持模板继承、分文件管理、触发器发现 | 516 |
| `editor2json.py` | 编辑器 JSON 导出 → object_data JSON 格式，UUID 过滤、名称解析、模板推断 | 477 |
| `json2object.py` | JSON → Lua object_data 格式直接转换 | 352 |

### 1.3 差距与需求分析

当前项目的痛点：
1. **硬编码 ID 散落各处**：`runtime_editor_ids.lua` 必须与编辑器中的 key 严格一致，新增技能需要同时改编辑器和代码
2. **对象属性不可版本化**：编辑器修改后，无法通过 `git diff` 看到"这个技能的伤害从 100 变成了 120"
3. **跨地图迁移困难**：对象定义绑定在 `.gmp` 地图文件中，换图需要手动重建
4. **没有对象模板/继承**：15 个攻击技能共享大量通用字段（冷却、施法类型、指示器），目前只能逐个在编辑器中复制

object_data 引入后可以解决：
- **代码即文档**：所有物编对象的属性在 Lua 中可读、可 diff、可 review
- **模板继承**：定义 `attack_skill_base` 模板，15 个技能只写差异字段
- **批量操作**：`od.build_all` 从注册表批量生成，不需要逐个在编辑器中操作
- **回滚安全**：物编数据进入 git 版本控制

---

## 2. 引入方案

### 2.1 文件清单与目录结构

```
maps/EntryMap/script/object_data/          ← 新目录
├── init.lua                               ← 核心工厂模块（从 xunhuanquan 迁移，精简）
├── enums.lua                              ← 枚举定义（从 xunhuanquan 迁移，精简）
├── od_y3_bridge.lua                       ← Y3 桥接层（从 xunhuanquan 迁移，适配本项目的 y3.object 用法）
│
├── definitions/                           ← 物编定义（新目录，替代 runtime_editor_ids.lua 的角色）
│   ├── abilities.lua                      ← 技能定义：普攻 + 15 个攻击技能
│   ├── projectiles.lua                    ← 投射物定义
│   ├── modifiers.lua                      ← 魔法效果定义（status / auto_active / bond 三类）
│   ├── units_hero.lua                     ← 英雄单位模板定义
│   ├── units_enemy.lua                    ← 敌人单位模板定义
│   └── items.lua                          ← 物品定义（局外/局内物品）
│
└── tools/                                 ← 构建工具（从 xunhuanquan 迁移）
    ├── build.py                           ← JSON → Lua 编译器（用于编辑器导入场景）
    ├── editor2json.py                     ← 编辑器 → JSON 转换
    └── json2object.py                     ← JSON → object_data 格式转换
```

### 2.2 每个文件的职责

#### 2.2.1 `init.lua` — 核心工厂模块

**来源**：xunhuanquan `init.lua`，做以下精简：

| 精简项 | 原因 |
|--------|------|
| 删除 `technology` 类型 | 自走棋不需要科技升级系统 |
| 删除 `destructible` 类型（或保留为最小骨架） | 当前项目没有可破坏物玩法 |
| 删减 UNIT_DEFAULTS 中约 30% 字段 | 去掉建造/训练/商店/采集/救援等 RTS 特有字段 |
| 删减 ABILITY_DEFAULTS 中约 20% 字段 | 去掉建造/采集相关字段 |
| 保留 `merge` / `deep_merge` / `shallow_copy` | 核心合并逻辑不变 |
| 保留模板系统 `define_template` / `extend` | 核心继承逻辑不变 |
| 保留 `wire` / `build_all` | 批量注册和触发器绑定保留 |
| 新增 `od.extend_unit` / `od.extend_ability` 语法糖 | 自走棋中"基于模板创建"是主要用法 |

#### 2.2.2 `enums.lua` — 枚举定义

**来源**：xunhuanquan `enums.lua`，做以下精简：

| 保留 | 删除 |
|------|------|
| UnitType, AttackType, ArmorType, DamageType | MoveType（当前只有地面移动） |
| AbilityCastType, AbilityType, AbilityPointerType | BuildSubtype（不求建造） |
| FilterCamp, FilterType, AbilityStage | ProjectileMoveType（都是直线弹道） |
| ModifierType, ModifierCoverType, ModifierEffectType | TechCategory（不求科技） |
| StackType, SlotType, BloodBarType, BloodShowType, BarNameShowType | SourceType（不求资源采集） |
| CommonAttackType, UnitState | MoveLimitation |
| CollisionLayers, TargetAllow, ShieldType | CoverChange |
| - | 部分 War3 特有枚举 |

**新增枚举**（自走棋专用）：
```lua
-- 技能元素属性
M.Element = {
    METAL = 'metal',     -- 金
    WOOD = 'wood',       -- 木
    WATER = 'water',     -- 水
    FIRE = 'fire',       -- 火
    EARTH = 'earth',     -- 土
    NONE = 'none',       -- 无
}

-- 技能伤害形式
M.DamageForm = {
    WEAPON = 'weapon',   -- 兵刃
    SPELL = 'spell',     -- 术法
    PURE = 'pure',       -- 真伤
}

-- 羁绊触发类型
M.BondTrigger = {
    ON_HIT = 'on_hit',
    ON_KILL = 'on_kill',
    ON_CAST = 'on_cast',
    PASSIVE = 'passive',
}

-- 敌人类型（替代 monster_type_config 中的字符串）
M.EnemyType = {
    NORMAL = 'normal',
    ELITE = 'elite',
    BOSS = 'boss',
    CHALLENGE = 'challenge',
}
```

#### 2.2.3 `od_y3_bridge.lua` — Y3 桥接层

**来源**：xunhuanquan `od_y3_bridge.lua`，适配要点：

1. **回调注入**：当前项目通过 `y3.object.unit[key].on_create = fn` 设置回调，桥接层需支持从 object_data 的 `on_create` 字段自动注入
2. **auto_create 禁用（默认）**：当前项目对象已存在于编辑器中，不需要 `auto_create`。但保留此能力给新对象
3. **与 `boot.lua` 的 `install_projectile_override_hook` 协作**：桥接层安装后，投射物 key 优先从 object_data 解析
4. **`verify` 诊断功能保留**：用于检查 object_data 定义与编辑器实际数据的一致性

#### 2.2.4 `definitions/` — 物编定义文件

**这是核心产出**，每个文件的结构：

```lua
-- definitions/abilities.lua
local od = require 'object_data'

-- 1. 定义模板
od.define_template('ability', 'attack_skill_base', {
    ability_cast_type = od.AbilityCastType.UNIT_TARGET,
    ability_type = od.AbilityType.COMMON,
    ability_max_level = 1,
    cold_down_time = '{5}',
    can_ps_interrupt = false,
    can_cast_interrupt = true,
    influenced_by_move = false,
    need_turn_to_target = true,
    is_immediate = false,
    can_cache = false,
    is_autocast = false,
    pointer_channel = od.AbilityPointerType.NONE,
    -- ... 更多共用默认值
})

-- 2. 定义具体技能（只写差异字段）
local abilities = {
    basic_attack = od.extend('ability', 'attack_skill_base', {
        key = 201390001,
        name = '普攻',
        -- 从 attack_skills.lua 的 SKILL_DATA 迁移过来
        kv = { damage_ratio = 1.25, element = 'metal', ... }
    }),
    sword_wave = od.extend('ability', 'attack_skill_base', {
        key = 201390002,
        name = '剑气波',
        ability_cast_type = od.AbilityCastType.LINE_TARGET,
        pointer_channel = od.AbilityPointerType.LINE,
        -- ...
    }),
    -- ... 其余 14 个技能
}

return abilities
```

#### 2.2.5 `tools/` — 构建工具

从 xunhuanquan 迁移，基本不变：
- **`build.py`**：当需要从编辑器导出数据时使用（编辑器 → JSON → Lua）
- **`editor2json.py`**：批量导出编辑器中已有的 units/abilities/items 为 JSON
- **`json2object.py`**：JSON 转 Lua object_data 格式

---

## 3. 与现有体系的共存策略

### 3.1 三层架构

```
┌──────────────────────────────────────────────────┐
│  Layer 3: CONFIG (entry_config.lua)               │
│  运行时配置聚合、数据转换、快捷访问                  │
│  依赖 Layer 1 + Layer 2                            │
├──────────────────────────────────────────────────┤
│  Layer 2: data/tables (CSV 配表)                  │
│  玩法数值：波次、英雄名册、属性成长、怪物倍率         │
│  game_tables.lua 汇总                              │
│  依赖 Layer 1                                      │
├──────────────────────────────────────────────────┤
│  Layer 1: object_data (物编定义)  ← 新增          │
│  对象模板：单位/技能/投射物/魔法效果的基础属性        │
│  不依赖任何上层                                     │
└──────────────────────────────────────────────────┘
```

**关键原则**：
- `object_data` 只定义"这个技能是什么"（类型、施法方式、指示器、基础数值）
- `data/tables` 定义"这场战斗中这些数值怎么调"（波次倍率、成长曲线、属性缩放）
- `CONFIG` 做聚合和便利访问（把 object_data 的 key→data 和 game_tables 的 id→row 拼到一起）

### 3.2 与 `runtime_editor_ids.lua` 的关系

**演进路径**：
1. 初期：`runtime_editor_ids.lua` 保留，`definitions/` 中新建定义时同时引用已有 ID
2. 中期：`runtime_editor_ids.lua` 改为从 `definitions/xxx.lua` 自动生成（所有 ID 源在 object_data）
3. 终态：`runtime_editor_ids.lua` 删除，所有引用改为 `require 'object_data.definitions.abilities'` → 取 `.key`

### 3.3 与 `game_tables.lua` 的关系

`game_tables.lua` 继续负责：
- CSV 加载和转换（`CsvLoader` 保持不变）
- `battle_base_config`、`battlefield_scene_config`、`waves`、`challenges`、`stages` 等运行时配置

`object_data` 新增负责：
- 单位模板属性（hp_max, attack_phy, armor_type, move_type 等）
- 技能模板属性（cast_type, cooldown, damage, pointer 等）
- 投射物属性（speed, duration, effect 等）
- 魔法效果属性（modifier_type, layer_max, shield_value 等）

**边界清晰**：`game_tables` 管"这场战斗怎么打"，`object_data` 管"这个对象是什么"。

### 3.4 与 `entry_config.lua` 的关系

`entry_config.lua` 变更为：
```lua
-- 新增：加载 object_data 定义
local AbilityDefs = require 'object_data.definitions.abilities'
local ProjectileDefs = require 'object_data.definitions.projectiles'

-- 现有：加载 CSV 配表
local GameTables = require 'data.game_tables'

-- 聚合：将 object_data 的 key 注入到 unit_ids
M.unit_ids = {
    hero = battlefield_unit_config.fixed_unit_ids.hero,
    -- 新增：从 object_data 解析的技能 key 列表
    skill_keys = {},
}
for name, def in pairs(AbilityDefs) do
    M.unit_ids.skill_keys[name] = def.key
end
```

---

## 4. 在 boot.lua 中的加载阶段

### 4.1 推荐的加载位置

**在 `boot.lua` 的阶段 0（数据表和配置）之前插入 object_data 加载**：

```lua
-- boot.lua 修改（新增阶段 0.5，在现有"数据表和配置"之前）

-- 阶段 0：物编对象定义（无任何运行时依赖，最先加载）
local ObjectDataBridge = require 'object_data.od_y3_bridge'

-- 阶段 0.5：安装 object_data 到 y3.object（必须在 STATE 创建之前）
-- 这确保后续的 y3.object.unit[key] 访问能拿到 object_data 的回调
ObjectDataBridge.install_definitions({
    abilities = require 'object_data.definitions.abilities',
    projectiles = require 'object_data.definitions.projectiles',
    modifiers = require 'object_data.definitions.modifiers',
    units = require 'object_data.definitions.units_hero',
}, { verbose = true })

-- 原有：数据表和配置
local CONFIG = require 'config.entry_config'
-- ... 后续不变
```

### 4.2 加载依赖图

```
object_data/init.lua
    ├── object_data/enums.lua
    └── (无其他依赖)

object_data/definitions/abilities.lua
    └── object_data/init.lua

object_data/definitions/projectiles.lua
    └── object_data/init.lua

object_data/od_y3_bridge.lua
    ├── object_data/init.lua（间接）
    ├── object_data/definitions/*（通过 install_definitions 参数传入）
    └── y3.object.*（引擎 API，运行时可用）

config/entry_config.lua
    ├── data/game_tables.lua（CSV 配表）
    ├── data/tables/*（各类配置表）
    └── object_data/definitions/*（新增依赖）

runtime/boot.lua
    ├── object_data/od_y3_bridge.lua（先加载，阶段 0.5）
    ├── config/entry_config.lua（阶段 1）
    ├── runtime/*（阶段 2+）
    └── ...
```

### 4.3 加载时机论证

**为什么必须在 STATE 创建之前加载？**

当前 `boot.lua` 中有：
```lua
install_projectile_override_hook()  -- 拦截 y3.projectile.create
```

object_data 桥接层的回调注入需要在 `y3.object.*` 被业务代码访问之前完成。如果业务代码在 STATE 初始化时就开始调用 `y3.object.ability[key].on_cast_start = fn`，那么桥接层必须已经安装好。

---

## 5. 迁移路径

### 5.1 阶段零：基础设施（1-2 天）

**目标**：object_data 核心可用，但不改变任何现有行为。

| 任务 | 说明 |
|------|------|
| 创建 `object_data/` 目录 | 放入 init.lua, enums.lua（精简版）, od_y3_bridge.lua（适配版） |
| 创建 `object_data/tools/` | 复制 build.py, editor2json.py, json2object.py |
| 在 boot.lua 阶段 0.5 加载 bridge | 但不加载任何 definitions，桥接层空跑 |
| 验证 | 确保现有功能完全不受影响（回归测试：波次推进、技能释放、羁绊抽卡） |

### 5.2 阶段一：技能 + 投射物迁移（2-3 天）

**目标**：技能定义和投射物定义从硬编码 ID 迁移到 object_data。

**迁移对象**：`runtime_editor_ids.lua` 中的 `ability` 和 `projectile` 表。

| 任务 | 说明 |
|------|------|
| 创建 `definitions/abilities.lua` | 定义 `attack_skill_base` 模板 + 16 个技能（basic_attack + 15 个攻击技能） |
| 创建 `definitions/projectiles.lua` | 定义 `basic_projectile` 模板 + 20+ 个投射物 |
| 修改 `CONFIG.unit_ids` | 技能 key 从此处解析，不再硬编码 |
| 修改 `data/tables/skill/attack_skills.lua` | 技能数据中的 `projectile_key` 改为从 object_data 引用 |
| `runtime_editor_ids.lua` 中的 ability/projectile 表标记 `@deprecated` | 兼容期保留，新代码用 object_data |

**这是最优先的迁移目标**，因为：
- 技能数量多（16 个），模板继承收益最大
- 当前 `runtime_editor_ids.lua` 中技能 ID 最分散
- 技能定义的"名字 → key"映射最需要版本化

### 5.3 阶段二：魔法效果迁移（1-2 天）

**目标**：Buff/Modifier 定义迁移。

| 任务 | 说明 |
|------|------|
| 创建 `definitions/modifiers.lua` | 定义 `attack_status`（ignite/armor_break/shock）、`auto_active_effect`（rapid_overdrive 等）、`bond_status` 三类 |
| 修改 `bond_modifier_pool.lua` | 改为引用 object_data 的 modifier key |
| `runtime_editor_ids.lua` 中 modifier 表标记 `@deprecated` | |

### 5.4 阶段三：单位模板迁移（2-3 天）

**目标**：英雄和敌人单位的基础属性模板化。

| 任务 | 说明 |
|------|------|
| 创建 `definitions/units_hero.lua` | 英雄单位模板（基础属性、物品栏、技能槽位等） |
| 创建 `definitions/units_enemy.lua` | 敌人单位模板（normal/elite/boss/challenge 四种） |
| 修改 `battlefield.lua` | 创建敌人时从 object_data 读取基础属性，再用 game_tables 的倍率覆盖 |
| 修改 `hero_model.lua` | `resolve_model_id` 可以从 object_data 的 unit 定义中读取 model 信息 |

**注意**：单位迁移风险最高，因为涉及战场创建逻辑。建议在技能迁移稳定运行后再进行。

### 5.5 阶段四：工具链与自动生成（可选，1 天）

**目标**：打通编辑器 → object_data 的自动导出链路。

| 任务 | 说明 |
|------|------|
| 运行 `editor2json.py` | 从 `editor_table/editorunit/` 和 `editor_table/editoritem/` 导出 JSON |
| 运行 `json2object.py` | 转成 Lua 后检查与手写的 definitions 是否一致 |
| 配置 Makefile/脚本 | 一键 `make sync-objects` 同步编辑器和 object_data |

### 5.6 迁移优先级总结

```
优先级 1（立即）：阶段零 + 阶段一（技能投射物）
  理由：收益最大、风险可控、不改变战场核心逻辑

优先级 2（尽快）：阶段二（魔法效果）
  理由：羁绊系统依赖 modifier，但变更范围小

优先级 3（规划中）：阶段三（单位模板）
  理由：改动面广，需在技能迁移验证通过后进行

优先级 4（按需）：阶段四（工具链）
  理由：锦上添花，不是必需
```

---

## 6. 与 xunhuanquan 原版的差异

### 6.1 结构性差异

| 维度 | xunhuanquan（三国策略） | 当前项目（自走棋/羁绊） |
|------|--------------------------|--------------------------|
| **玩法核心** | 英雄 + 建筑 + 生物 + 科技，完整 RTS 体系 | 单一英雄 + 敌人波次，自动战斗 |
| **单位类型** | 英雄/建筑/生物/可破坏物 四类俱全 | 只有英雄 + 敌人（普通/精英/Boss） |
| **技能体系** | 英雄技能 + 通用技能 + 被动 + 物品技能 | 攻击技能（autocast）+ 羁绊触发效果 |
| **物品系统** | 消耗品 + 装备 + 商店 + 合成 | 局外宝箱 + 局内待定，无商店/合成 |
| **科技系统** | 完整的三线科技树 | 无（羁绊体系替代了科技的角色） |
| **建造/训练** | 核心机制 | 无 |

### 6.2 init.lua 的主要删减

| 删除项 | 原因 |
|--------|------|
| `od.technology()` + `TECH_DEFAULTS` | 自走棋无科技系统 |
| `od.destructible()` + `DEST_DEFAULTS` | 当前无此玩法（可保留骨架备用） |
| UNIT_DEFAULTS 中的建造/训练字段（~30 个） | `build_time`, `build_res_cost_list`, `train_list`, `sell_list` 等 |
| UNIT_DEFAULTS 中的商店字段（~10 个） | `is_shop`, `sell_list`, `shop_range`, `init_stock` 等 |
| UNIT_DEFAULTS 中的采集/救援字段（~10 个） | `collection_*`, `rescue_*` 等 |
| ABILITY_DEFAULTS 中的建造字段 | `ability_build_subtype`, `build_list`, `building_attack_range_sfx` 等 |
| ABILITY_DEFAULTS 中的采集字段 | `collection_*`, `auto_pick`, `pick_count` 等 |
| ITEM_DEFAULTS 中的合成字段 | `compose_list`（暂无合成系统） |

### 6.3 enums.lua 的主要调整

| 调整 | 说明 |
|------|------|
| 删除 `TechCategory` | 无科技 |
| 删除 `BuildSubtype` | 无建造 |
| 删除 `ProjectileMoveType` | 当前弹道都是直线（保留枚举骨架，值精简） |
| 删除 `MoveType`（或只保留 LAND） | 无空军/水军 |
| 删除 `SourceType` | 无资源采集 |
| 新增 `Element`（五行） | 技能元素属性：金/木/水/火/土 |
| 新增 `DamageForm` | 伤害形式：兵刃/术法/真伤 |
| 新增 `BondTrigger` | 羁绊触发类型 |
| 新增 `EnemyType` | 敌人类型：普通/精英/Boss/挑战 |

### 6.4 od_y3_bridge.lua 的适配

| 修改点 | 说明 |
|--------|------|
| `install_definitions` 新方法 | 封装 `require` + `install`，boot.lua 一行调用 |
| 默认 `auto_create = false` | 当前项目对象已在编辑器中存在 |
| 与 `boot.lua` 的 projectile hook 协作 | bridge 安装后，`y3.projectile.create` 优先从 object_data 取 key |
| `verify` 添加 `--ci` 模式 | CI 中对比 object_data 和编辑器数据，不一致时报错 |

### 6.5 模板策略差异

xunhuanquan 的模板系统定义了 `hero_base` / `creep_melee` / `creep_ranged` / `building_defense` / `building_shop` 等大量模板。

当前项目的模板更简洁：
```lua
-- 技能模板：只需 1 个
od.define_template('ability', 'attack_skill_base', {...})

-- 单位模板：只需 2 个
od.define_template('unit', 'hero_base', {...})
od.define_template('unit', 'enemy_base', {...})

-- 如有需要，敌人可再分
od.define_template('unit', 'enemy_melee', {extends='enemy_base', attack_range=150})
od.define_template('unit', 'enemy_ranged', {extends='enemy_base', attack_range=500})
```

---

## 7. 风险与注意事项

### 7.1 技术风险

| 风险 | 等级 | 缓解措施 |
|------|------|---------|
| **object_data 与编辑器实际数据不一致** | 中 | `od_y3_bridge.verify()` 做 CI 检查；`editor2json.py` 做自动同步 |
| **boot.lua 加载顺序错误导致 nil 引用** | 中 | object_data 在阶段 0.5（最早），不依赖任何业务模块 |
| **模板继承链过深导致调试困难** | 低 | 限制模板继承不超过 2 级（base → template → instance） |
| **`y3.object` 的 `__setter` 行为与回调注入冲突** | 低 | bridge 安装后立即做冒烟测试 |
| **现有功能回归** | 低 | 阶段零空跑 bridge 验证无影响；每阶段独立测试 |

### 7.2 流程风险

| 风险 | 等级 | 缓解措施 |
|------|------|---------|
| **团队成员不熟悉 object_data 用法** | 中 | 在 definitions/ 第一个文件中写详细注释；在 CLAUDE.md 中引用本文档 |
| **编辑器修改后忘记同步 object_data** | 中 | CI 中添加 verify 步骤；`make sync-objects` 做一键同步 |
| **两套体系并行导致困惑** | 低 | 明确的废弃标记（`@deprecated`）；`runtime_editor_ids.lua` 顶部加警告注释 |

---

## 8. 验证标准

引入完成后，以下检查点必须通过：

- [x] `require 'object_data'` 不报错
- [x] `od.unit{key=99999}` 返回正确的默认值合并结果
- [x] `od.extend('ability', 'attack_skill_base', {key=99999})` 继承并覆盖模板
- [x] `od_y3_bridge.install_definitions(...)` 不改变现有 `y3.object.*` 行为
- [x] 现有波次推进、技能释放、羁绊抽卡功能不受影响
- [x] `runtime_editor_ids.lua` 中的值可以通过 `definitions/abilities.lua` 等文件重新推导

---

## 9. 附录：与 xunhuanquan 原版文件的逐文件对比

| xunhuanquan 文件 | 当前项目对应 | 迁移方式 |
|------------------|-------------|---------|
| `init.lua` (892行) | `object_data/init.lua` (~600行) | 复制 + 删减 RTS 特有字段 |
| `enums.lua` (300行) | `object_data/enums.lua` (~250行) | 复制 + 删减无用枚举 + 新增自走棋枚举 |
| `od_y3_bridge.lua` (296行) | `object_data/od_y3_bridge.lua` (~350行) | 复制 + 新增 `install_definitions` + 适配 |
| `build.py` (516行) | `object_data/tools/build.py` | 直接复制 |
| `editor2json.py` (477行) | `object_data/tools/editor2json.py` | 直接复制 |
| `json2object.py` (352行) | `object_data/tools/json2object.py` | 直接复制 |
| (无对应) | `definitions/abilities.lua` | **新建**：从 `runtime_editor_ids.lua` + `attack_skills.lua` 提取 |
| (无对应) | `definitions/projectiles.lua` | **新建**：从 `runtime_editor_ids.lua` 提取 |
| (无对应) | `definitions/modifiers.lua` | **新建**：从 `runtime_editor_ids.lua` 提取 |
| (无对应) | `definitions/units_hero.lua` | **新建**：从编辑器数据提取 |
| (无对应) | `definitions/units_enemy.lua` | **新建**：从编辑器数据 + `monster_type_config` 提取 |
| (无对应) | `definitions/items.lua` | **新建**（按需） |
