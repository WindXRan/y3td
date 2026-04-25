---
name: y3-ability-api
description: >
  Y3 Ability 运行时 API 开发指南。用于给单位添加技能、查找技能实例、监听技能施法事件、
  修改技能名称/描述/射程/冷却/层数等运行时行为。

  Use this skill when the user mentions: y3 ability、Ability API、技能实例、给单位加技能、
  查找技能、监听施法事件、修改技能描述、修改技能射程、get_common_attack、add_ability、
  find_ability、get_ability_by_slot、Ability:event、Ability:set_range.

  This skill focuses on runtime Ability instances. For editor object generation or editing,
  use y3-obj-gen or y3-obj-edit instead.
---

# Y3 Ability API Guide

用于 Y3 运行时 `Ability` 实例开发，不是物编技能 JSON。

## 使用前先分清两类“技能”

- `Ability`：运行时技能实例，挂在单位身上，能监听事件、改名字、改描述、改射程、改冷却。
- 物编 `ability`：编辑器里的技能类型数据，负责资源与基础配置。

如果用户要“运行时改技能表现/逻辑”，走本技能。
如果用户要“新建技能物编 / 改技能模板数据”，走 `y3-obj-gen` 或 `y3-obj-edit`。

## 首要检查

开始写代码前，优先读取：

1. 项目内 `y3/doc/API/Ability.md`
2. 项目内 `y3/doc/API/Unit.md`

必要时搜索现成用法：

- `runtime/attack_skills.lua`
- `runtime/session_state.lua`
- `runtime/boot.lua`

## 常用工作流

### 1. 获取技能实例

- 普攻技能：`unit:get_common_attack()`
- 指定技能位：`unit:get_ability_by_slot(type, slot)`
- 指定技能 key：`unit:find_ability(type, id)`
- 新增技能：`unit:add_ability(type, id, slot, level)`

### 2. 修改技能实例

常用运行时 API：

- `ability:set_name(name)`
- `ability:set_description(des)`
- `ability:set_range(value)`
- `ability:add_level(value)`
- `ability:add_cd(value)`
- `ability:add_remaining_cd(value)`
- `ability:complete_cd()`
- `ability:add_stack(value)`
- `ability:enable() / ability:disable()`

写法上先判空，再判 `is_exist()`。

### 3. 监听技能事件

优先使用：

- `ability:event('施法-出手', callback)`
- 其他 Ability 事件请先查 `y3/doc/API/Ability.md`

回调里不要假设 `data` 字段一定存在，先读现有项目例子再接。

## 推荐实现习惯

- 先拿到 `Ability` 实例，再改属性，不要反复查找。
- 和 UI 文案同步时，同时更新 `set_name` / `set_description`。
- 普攻改射程后，注意同步单位当前攻击逻辑与技能说明。
- 技能可能因为英雄重建、切形态、切阶段而失效，缓存实例时要反复做 `is_exist()` 检查。

## 常见坑

- 不要把运行时 `Ability` 当成物编表直接改。
- 不要臆造 `Ability` API；查不到就去 `y3/doc/API/Ability.md` 和 `Unit.md` 搜。
- `Unit:add_ability()` 加的是技能实例，和 CSV / JSON 物编生成不是一回事。
- 普攻通常不是普通主动技能，很多项目里要通过 `get_common_attack()` 取。

## 最小示例

```lua
local ability = hero:get_common_attack()
if ability and ability:is_exist() then
  ability:set_range(900)
  ability:set_name('御剑普攻')
  ability:set_description('当前普攻已被运行时重写。')
  ability:event('施法-出手', function()
    print('普攻出手')
  end)
end
```
