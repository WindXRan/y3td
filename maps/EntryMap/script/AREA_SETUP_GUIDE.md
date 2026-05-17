# 编辑器区域物件配置指南

## 概述

项目已支持使用编辑器已放置的物件来定义刷怪区域和出生点，无需修改代码或CSV配置。

## 物件命名规范

### 点类型物件 (Prefab)

| 物件名称 | 用途 | 建议类型 |
|----------|------|----------|
| `hero_spawn` | 英雄出生点 | 标记点/空物件 |
| `defense_point` | 防守目标点 | 标记点/空物件 |

### 区域类型物件 (Area)

| 物件名称 | 用途 | 是否必需 |
|----------|------|----------|
| `spawn_area` | **唯一刷怪区域**（所有波次共用） | **是** |

## 自动减速机制

> **已移除编辑器配置的减速区域**，改为基于英雄距离的自动减速：
> - 敌人进入英雄 **1000 范围**内时自动减速至 **50%**
> - 离开范围后自动恢复正常速度

### 减速参数（可配置）

```lua
local editor_object_api = require('script/runtime/editor_object_api')

-- 设置减速半径（默认1000）
editor_object_api.set_hero_proximity_slow_radius(1200)

-- 设置减速因子（默认0.5，即50%速度）
editor_object_api.set_hero_proximity_slow_factor(0.6)

-- 启用/禁用减速功能
editor_object_api.enable_hero_proximity_slow(true)
```

## 配置优先级

系统会按照以下顺序查找区域定义：

1. **单一刷怪区域** (`spawn_area`) - 如果存在，所有波次共用
2. **按波次命名的区域** (`main_spawn_wave_1` 等)
3. **调试工具覆盖** - 开发调试用
4. **CSV配置** - 兜底

## 使用方法

### 1. 在编辑器中放置刷怪区域

1. 在物件面板找到「区域」类型
2. 拖放到地图上合适位置
3. 调整区域大小和位置
4. 修改物件名称为 `spawn_area`

### 2. 在编辑器中放置出生点

1. 在物件面板找到「空物件」或「标记点」类型
2. 拖放到地图上英雄出生位置
3. 修改物件名称为 `hero_spawn`
4. 同样放置防守点，命名为 `defense_point`

### 3. 测试验证

运行游戏后，系统会自动：
- 在 `spawn_area` 区域内随机生成敌人
- 将英雄生成在 `hero_spawn` 位置
- 敌人会自动向 `defense_point` 移动
- 敌人进入英雄1000范围内会自动减速

## 启动减速监控

在英雄生成后需要启动减速监控：

```lua
local editor_object_api = require('script/runtime/editor_object_api')

-- 自动连接战场
local battlefield = editor_object_api.auto_connect_battlefield()

-- 在英雄生成后启动减速监控
local hero = create_hero(battlefield.hero_spawn.point)
battlefield.proximity_slow.start(hero)

-- 或者手动启动
editor_object_api.start_hero_proximity_slow_monitor(hero)
```

## 降级机制

如果编辑器中找不到物件，系统会自动使用CSV配置：

```lua
-- 找不到编辑器区域时，使用CSV配置
if not editor_area then
    return CONFIG.areas[area_id]
end
```

这样确保了兼容性和容错性。

## 推荐配置清单

| 物件名称 | 类型 | 建议位置 |
|----------|------|----------|
| `spawn_area` | Area（矩形） | 地图右侧，敌人进攻起点 |
| `hero_spawn` | Point | 地图左侧，英雄初始位置 |
| `defense_point` | Point | 英雄前方，需要守护的位置 |

## 核心 API 参考

```lua
local editor_object_api = require('script/runtime/editor_object_api')

-- 查找物件
local spawn_area = editor_object_api.find_area_by_name('spawn_area')
local hero_spawn = editor_object_api.find_prefab_by_name('hero_spawn')

-- 获取坐标点
local point = editor_object_api.get_prefab_point('defense_point')

-- 在区域内随机生成点
local random_point = editor_object_api.random_point_in_area('spawn_area')

-- 自动连接战场
local battlefield = editor_object_api.auto_connect_battlefield()

-- 启动减速监控
battlefield.proximity_slow.start(hero_unit)
```