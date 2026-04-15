# EntryMap 修仙包装与五行伤害体系重构设计

## 背景

当前 EntryMap 的战斗包装仍然混合了多套语义：

- 玩家可见层同时存在 `物理 / 法术`
- 技能描述层同时存在 `火 / 冰 / 电 / 风 / 能量`
- 第二批技能蓝图继续沿用 `物系物理 / 冰系魔法 / 能量魔法` 这类组合式命名

这套表达对当前原型开发是够用的，但如果项目要整体切到修仙题材，会有三个明显问题：

1. 世界观口径不统一，修仙题材下“能量魔法”“电系魔法”会显得偏西幻
2. 一个字段承载了过多语义，`damage_type` 同时负责伤害形态、属性归属、文案展示
3. 后续进化、羁绊、宝物如果要围绕五行扩展，会缺少稳定的数据骨架

因此本次目标不是只做一轮文案替换，而是把伤害体系拆成更清晰的“双层结构”，同时把玩家可见包装切到修仙 + 五行语义。

## 本次目标

- 把项目玩家可见包装切到修仙语境
- 把现有伤害属性归类统一收口到五行
- 把当前单字段 `damage_type` 拆成结构化字段
- 保留当前系统对“物理 / 法术类乘区”的承载能力
- 为后续五行词条、五行进化、五行羁绊预留稳定数据结构

## 非目标

- 不在本次引入五行相克
- 不在本次给所有敌人补五行抗性
- 不在本次重做全项目数值平衡
- 不在本次一次性翻修所有历史设计文档
- 不把当前技能行为逻辑重写成新的脚本解释器

## 方案对比

### 方案 A：直接把旧属性名替换成五行

做法：

- 把 `物理 / 法术 / 火 / 冰 / 电 / 风 / 能量` 直接映射为 `金木水火土`
- 不拆字段，继续沿用单一 `damage_type`

优点：

- 替换速度快
- 文案层统一明显

缺点：

- 一个字段继续承担过多职责
- 原先很多依赖“物理 / 法术”乘区的逻辑会变得语义混乱
- 后续继续扩展时还会再次返工

### 方案 B：双层体系重构

做法：

- 新增 `damage_form`
- 新增 `element`
- 新增 `damage_label`
- 运行时与数据层逐步从旧 `damage_type` 迁移到新三元组

优点：

- 世界观和运行时职责分离清晰
- 能保留当前系统对“武技 / 术法”差异的依赖
- 后续扩展五行词条和修仙包装更顺

缺点：

- 首轮改造面比纯文案替换更大

## 推荐方案

采用方案 B。

原因：

- 用户明确选择“双层重构”
- 项目现有系统已经在很多地方隐含依赖“物理 / 法术”语义，不能简单硬替换
- 五行在本次只承担“属性归属 + 包装 + 增益标签”，不引入相克，能有效控制风险

## 核心设计

## 一、双层伤害语义

### 1. `damage_form`

用途：

- 表示伤害形态
- 承接当前大量“物理 / 法术”类乘区需求

首版枚举：

- `weapon`
- `spell`
- `dot`
- `summon`

说明：

- `weapon` 对应武技、箭矢、剑气、斩击等
- `spell` 对应术法、雷法、寒法、炎术等
- `dot` 对应持续灼烧、毒伤、场域持续伤害
- `summon` 为后续召唤系预留

### 2. `element`

用途：

- 表示五行属性归属
- 供技能标签、增益词条、羁绊和修仙包装使用

首版枚举：

- `metal`
- `wood`
- `water`
- `fire`
- `earth`
- `none`

说明：

- `none` 用于纯中性伤害或暂未归类内容
- 本次不基于 `element` 做相克计算

### 3. `damage_label`

用途：

- 仅用于玩家可见文案
- 不参与核心判定

首版示例：

- `金行箭罡`
- `木行灵矢`
- `木行天雷`
- `水行寒煞`
- `火行爆炎`
- `土行震罡`

## 二、五行归类规则

本次先按“统一世界观、尽量贴合现有构筑身份”的原则归类：

- `金`：剑气、锋刃、穿透、破甲、切割
- `木`：雷法、牵引、生长、连锁、流转
- `水`：寒冰、冻结、减速、潮汐、控场
- `火`：爆燃、炎爆、陨火、灼烧、高爆发
- `土`：地震、岩刺、护体、镇压、厚重范围伤害

特殊说明：

- 现有“雷”整体并入 `木`
- 现有“风”不单列为基础属性，按技能身份并入 `金` 或 `木`
- 现有“奥术 / 能量”不再作为基础属性长期保留，按技能表现并入 `金 / 木 / 水`

## 三、当前技能第一版映射

### 基础技能

- `basic_attack`
  - `damage_form = weapon`
  - `element = metal`
  - `damage_label = 金行箭罡`
- `arcane_arrow`
  - `damage_form = spell`
  - `element = wood`
  - `damage_label = 木行灵矢`
- `flame_arrow`
  - `damage_form = weapon`
  - `element = fire`
  - `damage_label = 火行爆炎`
- `frost_arrow`
  - `damage_form = spell`
  - `element = water`
  - `damage_label = 水行寒煞`
- `thunder`
  - `damage_form = spell`
  - `element = wood`
  - `damage_label = 木行天雷`

### 第二批技能蓝图

- `sword_wave` -> `weapon / metal / 金行剑罡`
- `arcane_laser` -> `spell / metal / 金行灵光`
- `arcane_ray` -> `spell / metal / 金行灵束`
- `frost_nova` -> `spell / water / 水行寒潮`
- `chain_lightning` -> `spell / wood / 木行雷链`
- `earthquake` -> `weapon / earth / 土行震罡`
- `tornado` -> `spell / wood / 木行罡风`
- `electro_net` -> `spell / wood / 木行雷网`
- `meteor` -> `spell / fire / 火行陨炎`
- `hurricane` -> `spell / wood / 木行飓流`
- `fireball` -> `spell / fire / 火行炎术`

## 四、数据结构改造

### 1. 基础技能 CSV

目标文件：

- `script/data_csv/attack_skills.csv`

当前字段：

- `damage_type`

改造后字段：

- `damage_form`
- `element`
- `damage_label`

兼容策略：

- 过渡期允许保留旧列 `damage_type`
- loader 优先读取新列
- 若新列不存在，则从旧列映射出默认的 `damage_form / element / damage_label`

### 2. 第二批技能蓝图

目标文件：

- `script/entry_objects/attack_skill_blueprints/second_batch_skills.lua`

当前字段：

- `damage_type = '冰系魔法'`

改造后字段：

- `damage_form = 'spell'`
- `element = 'water'`
- `damage_label = '水行寒潮'`

说明：

- 蓝图文案中的状态描述，也应逐步从“电系魔法伤害”“能量魔法伤害”改为修仙口径

### 3. 基础技能定义

目标文件：

- `script/entry_objects/attack_skills/*.lua`

改造方式：

- 与 CSV 保持一致，输出结构化三元组
- 摘要文案同步切到修仙口径

## 五、运行时设计

### 1. 结算入口

目标文件：

- `script/runtime/boot.lua`
- `script/runtime/attack_skills.lua`

当前状态：

- 多处直接透传 `damage_type`
- `hero_attr_system.get_damage_multiplier(...)` 当前直接吃单一类型字段

改造后：

- 伤害调用链优先传递：
  - `damage_form`
  - `element`
  - `damage_label`
- 旧 `damage_type` 暂时保留为兼容字段

### 2. 倍率拆分

建议把当前伤害倍率拆成两层：

- `form multiplier`
  - 对应武技、术法等大类加成
- `element multiplier`
  - 对应金木水火土加成

本次明确不加入：

- 五行相克倍率
- 目标五行抗性系统
- 相生转化系统

### 3. 展示层

伤害跳字与技能描述优先使用：

- `damage_label`

如果展示逻辑仍需要区分物理样式或法术样式，可由：

- `damage_form`

继续控制视觉类型，而不是重新依赖旧 `damage_type`

## 六、修仙包装改造范围

第一批改造范围限定为以下内容：

1. 基础技能与第二批技能的名称、描述、属性文案
2. 技能数据表和蓝图字段
3. 运行时伤害字段与倍率计算入口
4. 当前技能总表和第二批技能设计文档
5. 与技能属性直接耦合的羁绊、进化、宝物描述

暂不包含：

1. 所有历史设计文档的全量翻修
2. 全怪物五行配置
3. 全局平衡重算
4. 新的复杂五行机制

## 七、兼容策略

为避免一次性切换导致大面积回归，本次采用渐进兼容：

1. 先新增新字段和映射逻辑
2. 再改 loader 与 runtime 优先读取新字段
3. 再批量改基础技能、第二批蓝图与玩家可见文案
4. 最后清理不再使用的旧 `damage_type` 依赖

兼容原则：

- 运行时在过渡期不得要求所有数据同时完成迁移
- 基础技能和蓝图文件允许短期并存新旧字段
- 玩家可见文本优先先统一为修仙与五行口径

## 八、错误处理

- 若新字段缺失且旧字段也无法映射，loader 直接报错
- 若 `element` 写入未定义值，loader 直接报错
- 若 `damage_form` 写入未定义值，loader 直接报错
- 若运行时收到缺失的 `damage_label`，允许按 `element + damage_form` 生成默认展示名

## 九、验证策略

至少覆盖以下检查：

1. `attack_skills.csv` loader smoke
   - 新列可读取
   - 旧列映射仍可工作
2. 基础技能静态检查
   - 五个已实现技能都带 `damage_form / element / damage_label`
3. 第二批蓝图静态检查
   - 全部蓝图都带新的结构化伤害字段
4. runtime smoke
   - 技能施法仍可结算伤害
   - `weapon` 与 `spell` 的既有乘区未失效
   - 五行加成字段可进入结算
5. 文案回归检查
   - 玩家可见技能描述不再出现“能量魔法”“电系魔法”“火系物理”这类旧口径

## 十、验收标准

满足以下条件即可视为本次设计完成：

- 项目伤害体系完成 `damage_form + element + damage_label` 双层拆分
- 基础技能与第二批技能蓝图完成五行归类
- 玩家可见技能描述完成修仙口径替换
- 运行时结算不再只依赖单一 `damage_type`
- 本次实现中未引入五行相克与全局抗性系统
