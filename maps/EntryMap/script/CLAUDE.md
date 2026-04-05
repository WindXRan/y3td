# CLAUDE.md

本文件用于让进入本仓库的 agent 快速理解当前项目的真实结构、代码主线和修改边界。

## 语言要求

- 始终使用中文回复用户。

## 先看结论

- 当前项目的真实玩法主线只在 `maps/EntryMap/script`
- 当前真实入口是 `maps/EntryMap/script/main.lua`
- `maps/EntryMap/script/entry_runtime.lua` 现在是运行时总协调器，不再是唯一实现文件
- 当前真实玩法配置汇总入口是 `maps/EntryMap/script/entry_config.lua`
- 当前真实对象定义源是 `maps/EntryMap/script/entry_objects`
- 当前真实羁绊主实现是 `maps/EntryMap/script/runtime_bonds.lua`
- 当前真实运行时模块群已经拆出：
  - `maps/EntryMap/script/entry_runtime_battlefield.lua`
  - `maps/EntryMap/script/entry_runtime_progression.lua`
  - `maps/EntryMap/script/entry_runtime_attack_skills.lua`
  - `maps/EntryMap/script/entry_runtime_attack_upgrades.lua`
  - `maps/EntryMap/script/entry_runtime_outgame.lua`
  - `maps/EntryMap/script/entry_runtime_hud.lua`
  - `maps/EntryMap/script/entry_runtime_debug_tools.lua`
  - `maps/EntryMap/script/entry_runtime_debug_actions.lua`
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
5. `maps/EntryMap/script/docs/项目模块/08-局外与长期进度/局外选关与存档骨架.md`
6. `maps/EntryMap/script/docs/项目模块/03-战斗与成长`
7. `maps/EntryMap/script/docs/项目模块/04-UI与调试`
8. `maps/EntryMap/script/entry_objects/README.md`
9. `maps/EntryMap/script/docs/项目模块/07-实现状态与路线图/实现状态与路线图.md`

## 模块到代码位置映射

### 启动与编排

- `maps/EntryMap/script/main.lua`
  - 地图启动入口
  - 设置日志
  - `require 'entry_runtime'`
  - 调用 `bootstrap()`
- `maps/EntryMap/script/entry_runtime.lua`
  - 持有 `STATE`
  - 在 `bootstrap()` 中完成配置校验、会话态初始化、事件/循环注册与局外入口切换
  - 装配各运行时子系统
  - 维护奖励队列、轮次互斥和系统间协调
  - 统一注册键位、开发命令、HUD、局外 UI 与 GM 面板入口
- `maps/EntryMap/script/entry_runtime_outgame.lua`
  - 局外存档加载/修正/保存
  - 章节与模式选择
  - 线性解锁
  - 最近结果回显
  - 战斗结束后回到局外页

### 战场与波次

- `maps/EntryMap/script/entry_runtime_battlefield.lua`
  - 英雄创建
  - 敌人 runtime 信息
  - 5 波推进
  - Boss 登场与切波
  - `Q/W/E/R` 挑战
  - 生成单局 `battle_result`
  - 战场清理入口
  - 配置校验

### 成长与经验

- `maps/EntryMap/script/entry_runtime_progression.lua`
  - 英雄等级
  - 经验获取
  - 引擎等级上限后的自定义成长
  - 技能点同步

### 攻击技能

- `maps/EntryMap/script/entry_objects/attack_skills`
  - 攻击技能静态定义与 VFX
- `maps/EntryMap/script/entry_runtime_attack_skills.lua`
  - 攻击技能实例
  - 自动施放
  - 投射物 / 控制 / 伤害结算
  - 技能栏展示文本
- `maps/EntryMap/script/entry_runtime_attack_upgrades.lua`
  - `G` 三选一
  - 新技能解锁与已有技能强化
  - 候选权重与次数限制

### 羁绊

- `maps/EntryMap/script/runtime_bonds.lua`
  - 羁绊定义聚合
  - 羁绊卡定义聚合
  - `F` 抽卡
  - 自动吞噬/替换建议
  - 静态/动态效果刷新
  - 奖励加成与击杀联动
- `maps/EntryMap/script/entry_objects/bonds`
- `maps/EntryMap/script/entry_objects/bond_cards`

### 宝物 / 烙印 / 奖励队列

- `maps/EntryMap/script/entry_objects/treasures`
  - 宝物静态定义
- `maps/EntryMap/script/entry_objects/marks`
  - 烙印静态定义
- `maps/EntryMap/script/entry_objects/mark_nodes`
  - `10/20/30/40` 级烙印节点
- `maps/EntryMap/script/entry_runtime.lua`
  - 宝物栏 runtime
  - 烙印栏 runtime
  - 奖励队列
  - 待选轮次互斥
  - 宝物 3 选 1 / 替换
  - 烙印 3 选 1

### 配置层

- `maps/EntryMap/script/entry_config.lua`
  - 英雄基础数值
  - 资源规则
  - 点位与区域
  - 挑战恢复规则
  - `entry_objects.waves` / `entry_objects.challenges` 汇总接入
  - `entry_objects.stages` / `entry_objects.stage_modes` 汇总接入
  - `save_slots.outgame_profile`
  - 临时单位标签与物编 ID 映射

### UI 与调试

- `maps/EntryMap/script/entry_runtime_hud.lua`
  - 运行时顶部/底部 HUD
  - 技能、羁绊、挑战按钮
  - 波次、Boss、资源、待领奖励显示
  - 当前章节文本与战斗 HUD 显隐
- `maps/EntryMap/script/entry_runtime_debug_tools.lua`
  - GM 面板
  - 校准命令
  - 调试热键说明
- `maps/EntryMap/script/entry_runtime_debug_actions.lua`
  - 调试加资源、升级、解锁技能、刷 Boss、清场等动作
- `maps/EntryMap/script/ui_res.lua`
  - UI 资源 ID 索引
- `maps/EntryMap/ui`
  - HUD/面板 JSON 资产
- `maps/EntryMap/global_trigger`
  - 地图级 UI 触发器与编辑器资产

## 当前实现状态矩阵

### 已实现

- 局外选关页与章节/模式选择
- `1-1`、`1-2`、`1-3` 三章卡片
- `standard` / `challenge` 双模式身份、解锁与最近结果记录
- `1-2`、`1-3` 以 `content_source_stage_id = 1-1` 暂复用首章战斗内容
- `outgame_profile` 存档骨架与线性解锁规则
- 5 波主线与 Boss 切波
- 英雄自动战斗
- 4 槽攻击技能运行时
- `G` 三选一强化
- `F` 羁绊抽卡
- `runtime_bonds.lua` 羁绊运行时
- `Q/W/E/R` 四类挑战
- 宝物 3 选 1与 3 宝物位替换
- `10/20/30/40` 级烙印节点与烙印 3 选 1
- 奖励队列与待选轮次互斥
- 运行时 HUD
- GM 面板、开发命令与调试热键
- 基础胜负结算

### 部分实现

- 局外系统当前只完成选关、解锁、最近结果与基础存档骨架，未接长期养成资源
- 宝物、烙印、`G/F` 已进入真实 runtime，但当前主要还是文本提示加 HUD 按钮，不是正式中央决策面板
- 地图已有 UI 资产与运行时 HUD，但背包、奖励记录、正式结算页还没做完
- Boss 配置已有扩展空间，但没有完整 Boss 时间轴系统
- 当前主怪/Boss/挑战怪很多仍是临时替身物编，不是最终怪物资源

### 未实现

- 成长武器
- 词缀节点
- 正式中央决策面板与背包页
- 长期局外成长、局外货币与完整结算写回
- 多英雄
- 多章节专属战斗内容与更完整模式差异

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

### 对象定义目录

- `maps/EntryMap/script/entry_objects`
  - 当前静态玩法对象的主落点
  - 波次、挑战、攻击技能、羁绊、宝物、烙印都先看这里

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
entry_objects/*
  -> 提供波次/挑战/攻击技能/羁绊/宝物/烙印的静态对象

entry_config.lua
  -> 汇总点位/区域/资源规则/挑战规则/对象列表

entry_runtime.lua
  -> 持有 STATE 并协调局外/战斗双阶段

entry_runtime_battlefield.lua
  -> 主线波次/挑战/战场/单局结果

entry_runtime_progression.lua
  -> 等级/经验/技能点

entry_runtime_attack_skills.lua
  -> 攻击技能实例与施放

entry_runtime_attack_upgrades.lua
  -> G 三选一

runtime_bonds.lua
  -> F 系统 / 羁绊效果 / 奖励修正

entry_runtime_outgame.lua
  -> 选关 UI / 解锁 / 存档骨架 / 战斗回流

entry_runtime_hud.lua
  -> 战斗 HUD

maps/EntryMap/ui
  -> 提供 HUD 与面板挂载点

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
- `Ctrl+F3` 升 3 级
- `Ctrl+F4` 解锁技能
- `Ctrl+F5` 打开 G 强化
- `Ctrl+F6` 触发 F 抽卡
- `Ctrl+F7` 补满挑战次数
- `Ctrl+F8` 强制刷 Boss
- `Ctrl+F9` 清场
- `Ctrl+F10` 显示/隐藏 GM 面板

### 常用开发命令

- `.epos`
- `.eset hero`
- `.eset defense`
- `.earea 区域名 [宽] [高] [偏移X] [偏移Y]`
- `.eblink hero|defense`
- `.edump`

## 修改前的工作原则

- 先确认需求属于哪层：
  - 全局规则层：`entry_config.lua`
  - 静态对象层：`entry_objects/*`
  - 战场层：`entry_runtime_battlefield.lua`
  - 成长层：`entry_runtime_progression.lua`
  - 攻击技能层：`entry_runtime_attack_skills.lua` / `entry_runtime_attack_upgrades.lua`
  - 羁绊层：`runtime_bonds.lua`
  - 奖励队列与轮次协调层：`entry_runtime.lua`
  - HUD 层：`entry_runtime_hud.lua`
  - 调试层：`entry_runtime_debug_tools.lua` / `entry_runtime_debug_actions.lua`
  - UI 资产层：`maps/EntryMap/ui`
  - 触发器/UI编辑器层：`maps/EntryMap/global_trigger`
- 新系统进入实现前，先回答：
  - 状态放哪
  - 是否进入奖励队列 / 待选轮次互斥
  - 与现有 `G/F/烙印/宝物/挑战` 如何并存
  - UI 读哪个 runtime
- 尽量不要直接调用 CAPI，优先使用 `y3` 框架封装
- 修改 `y3/` 目录前先确认是否真的在修框架而不是修项目

## 当前最重要的事实

- 当前项目已经是“可玩的单局原型”，不是纯空工程
- 当前文档必须以 `maps/EntryMap/script` 中的实现事实为准
- 上一次 pull 已经把运行时进一步模块化，并把宝物、烙印、奖励队列接进真实 runtime
- 当前下一阶段重点不是回退成单文件实现，而是继续沿着模块边界补正式 UI 和剩余系统
