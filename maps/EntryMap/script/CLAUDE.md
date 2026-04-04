# CLAUDE.md

本文件用于让进入本仓库的 agent 快速理解当前项目的真实结构、代码主线和修改边界。

## 语言要求

- 始终使用中文回复用户。

## 先看结论

- 当前项目的真实玩法主线只在 `maps/EntryMap/script`
- 当前真实入口是 `maps/EntryMap/script/main.lua`
- 当前真实运行时核心是 `maps/EntryMap/script/entry_runtime.lua`
- 当前真实玩法配置是 `maps/EntryMap/script/entry_config.lua`
- 当前真实羁绊实现是 `maps/EntryMap/script/runtime_bonds.lua`
- `maps/EntryMap/script/docs/项目模块` 是实现级说明源
- `maps/EntryMap/script/docs/design` 是策划设计源，不等于已实现内容

## 错误入口排除

以下内容不要误判为当前玩法主入口：

- `maps/EntryMap/script/可重载的代码.lua`
  - 当前只是热重载示例
- `global_script/global_main.lua`
  - 当前是项目级占位脚本
- 根目录 `global_trigger`
  - 当前只有空索引
- `maps/EntryMap/script/docs/design`
  - 这是设计文档，不是运行时代码

## 推荐阅读顺序

1. `maps/EntryMap/script/CLAUDE.md`
2. `maps/EntryMap/script/docs/项目模块/00-项目总览/项目概览.md`
3. `maps/EntryMap/script/docs/项目模块/01-启动与入口/启动入口链路.md`
4. `maps/EntryMap/script/docs/项目模块/02-运行时主循环/主循环与状态机.md`
5. `maps/EntryMap/script/docs/项目模块/03-战斗与成长`
6. `maps/EntryMap/script/docs/项目模块/07-实现状态与路线图/实现状态与路线图.md`

## 模块到代码位置映射

### 启动与入口

- `maps/EntryMap/script/main.lua`
  - 地图启动入口
  - 设置日志
  - `require 'entry_runtime'`
  - 调用 `bootstrap()`

### 运行时主循环

- `maps/EntryMap/script/entry_runtime.lua`
  - `STATE` 主状态容器
  - 5 波推进
  - 敌人生成
  - 自动战斗
  - G 强化
  - F 羁绊接入
  - 挑战系统
  - 资源/经验/结算
  - GM 面板
  - 开发命令与调试热键

### 配置层

- `maps/EntryMap/script/entry_config.lua`
  - 英雄基础数值
  - 资源规则
  - 5 波配置
  - 区域配置
  - 4 类挑战配置
  - 临时/正式单位 ID 映射

### 羁绊系统

- `maps/EntryMap/script/runtime_bonds.lua`
  - 羁绊定义
  - 羁绊卡定义
  - 抽卡候选
  - 替换/结算
  - 动态效果刷新
  - 奖励加成与击杀联动

### UI 与资源索引

- `maps/EntryMap/script/ui_res.lua`
  - UI 资源 ID 索引
- `maps/EntryMap/ui`
  - HUD/面板 JSON 资产
- `maps/EntryMap/global_trigger`
  - 地图级 UI 触发器与编辑器资产

## 当前实现状态矩阵

### 已实现

- 5 波主线
- 英雄自动攻击
- 攻击技能运行时
- `G` 三选一强化
- `F` 羁绊抽卡
- `runtime_bonds.lua` 羁绊运行时
- `Q/W/E/R` 挑战
- GM 面板
- 基础胜负结算

### 部分实现

- 宝物挑战存在，但奖励仍是“宝物候选(占位)”文本
- 地图已有 UI 资产，但正式战斗 HUD 与中央决策面板未完成
- Boss 配置已有时间轴字段，但没有完整 Boss 时间轴系统
- `entry_runtime.lua` 中有 legacy 包装，说明仍在模块化过渡中

### 未实现

- 成长武器
- 词缀节点
- 宝物正式系统
- 烙印系统
- 奖励队列
- 局外成长 / 存档闭环
- 多英雄
- 多章节 / 长线内容

## 文档分层约定

### 实现级说明源

- `maps/EntryMap/script/docs/项目模块`
  - 描述当前真实代码结构
  - 描述状态归属、边界、修改入口
  - 供 agent 直接执行开发时参考

### 设计级说明源

- `maps/EntryMap/script/docs/design`
  - 描述未来设计目标、配表方案、UI 规划
  - 用于分析“已实现与待实现”
  - 不应直接当成当前代码事实

## 目录边界

### 业务代码目录

- `maps/EntryMap/script`
  - 当前一切玩法逻辑优先看这里

### 框架目录

- `maps/EntryMap/script/y3`
  - Y3 框架库
  - 除非要修框架层，否则谨慎修改

### 地图资源目录

- `maps/EntryMap/unit`
- `maps/EntryMap/ability`
- `maps/EntryMap/item`
- `maps/EntryMap/modifier`
- `maps/EntryMap/projectile`
  - 这些是资源与物编依赖，不是当前玩法主逻辑入口

## UI / 触发器 / 物编 / 配置依赖关系

```text
entry_config.lua
  -> 提供波次/区域/挑战/资源规则

entry_runtime.lua
  -> 消费配置并维护 STATE

runtime_bonds.lua
  -> 为 entry_runtime.lua 提供 F 系统与奖励修正

maps/EntryMap/ui
  -> 提供 HUD 与面板资产

maps/EntryMap/global_trigger
  -> 提供地图级 UI 触发器资产

unit / ability / projectile 等目录
  -> 提供运行时实际使用的单位、技能、投射物资源
```

## 常用开发方式

### 调试运行

- 在 Y3/VSCode 环境中启动游戏并附加调试器
- 游戏内输入 `.rr` 快速重启
- 查看日志：`maps/EntryMap/script/.log`

### 调试热键

- `Ctrl+F1` 帮助
- `Ctrl+F2` 加资源
- `Ctrl+F3` 升级
- `Ctrl+F4` 解锁技能
- `Ctrl+F5` 打开 G 强化
- `Ctrl+F6` 触发 F 抽卡
- `Ctrl+F7` 补满挑战次数
- `Ctrl+F8` 强制刷 Boss
- `Ctrl+F9` 清场
- `Ctrl+F10` 显示/隐藏 GM 面板

## 修改前的工作原则

- 先确认需求属于哪层：
  - 规则层：`entry_config.lua`
  - 行为层：`entry_runtime.lua`
  - 羁绊层：`runtime_bonds.lua`
  - UI 资产层：`maps/EntryMap/ui`
  - 触发器/UI编辑器层：`maps/EntryMap/global_trigger`
- 新系统进入实现前，先回答：
  - 状态放哪
  - 与现有 G/F/挑战如何并存
  - UI 读哪个 runtime
- 尽量不要直接调用 CAPI，优先使用 `y3` 框架封装
- 修改 `y3/` 目录前先确认是否真的在修框架而不是修项目

## 当前最重要的事实

- 当前项目已经是“可玩的单局原型”，不是纯空工程
- 当前文档必须以 `maps/EntryMap/script` 中的实现事实为准
- 当前下一阶段重点不是继续堆单文件逻辑，而是把未来模块按 runtime state、UI 接口、资源依赖逐步模块化
