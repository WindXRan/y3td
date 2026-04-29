---
name: y3-combat-skill-factory
description: >
  EntryMap 项目专用技能生产 Skill。用于把“技能想法”直接落地为可运行的技能定义、
  运行时逻辑、特效绑定与自动验收指标（空放率/命中率/DPS）。
  
  ALWAYS use this skill when user mentions: 做技能、重做技能、技能手感、技能框架、量产技能、
  龙骑士/雷电法王/冰霜法师/枪炮师技能、技能不造成伤害、命中不一致、特效和伤害范围不一致、
  技能自动验收、技能调优、技能模板。
version: 1.3
updated: 2026-04-29
---

# Y3 Combat Skill Factory

## 目标
为 `maps/EntryMap/script` 提供一条稳定技能产线，产出：
1. 技能定义（组合式，非继承膨胀）
2. 运行时接入（可施法、可观测）
3. 美术绑定（特效/投射物）
4. 自动验收指标（空放率/命中率/伤害）

---

## 作用范围（仅本项目）
- 运行时主路径：
  - `runtime/skill_framework.lua`
  - `runtime/skill_framework_registry.lua`
  - `runtime/skills.lua`
  - `runtime/sample_skills.lua`
  - `runtime/battle_auto_acceptance.lua`
  - `runtime/debug_actions.lua`
  - `runtime/debug_tools.lua`
- 禁止误改：
  - `global_script/*`
  - 根目录 `global_trigger/*`

---

## 输入协议（给 AI 的需求格式）
用户需求至少应包含：
1. `skill_id`：技能唯一ID（如 `dragon_line_breath`）
2. `pattern`：`line_pierce|area_burst|area_tick|chain_bounce`
3. `damage_type`：`物理|法术|真实`
4. `hit_model`：范围参数（range/width/radius/bounce）
5. `scale`：倍率参数（attack_ratio/tick_ratio/bounce_ratio）
6. `visual intent`：表现意图（如“从天而降”“持续风场”“固定长度直线”）

如果用户没给全，按项目默认值补齐并在交付里声明。

---

## 强制规则
1. 只允许三伤害类型：`物理/法术/真实`。
2. AOE 默认不设最大命中数（`max_hits=0`）。
3. 技能定义统一进 `runtime/skills.lua`，禁止散落在多个文件重复定义。
4. 施法调用优先 `skill_framework.cast_by_id`，禁止新功能继续堆老脚本分支。
5. 新技能必须可被 `.esample <id>` 触发，且可由 `.eframe <id>` 看到 telemetry。
6. 特效实际覆盖与伤害覆盖要对齐，偏差需要在交付里显式说明。

---

## 实现流程（MUST）
1. 在 `runtime/skills.lua` 新增或更新技能定义。
2. 在 `runtime/sample_skills.lua` 注册并接入施法入口。
3. 绑定 visual（cast/warning/impact/hit/projectile_key）。
4. 接入 telemetry（使用 `skill_framework.get_telemetry`）。
5. 将关键技能纳入 `battle_auto_acceptance` 的审计口径（scope/key）。
6. 输出变更清单 + 验收命令。

---

## 美术资源ID标准写法（MUST）
每个技能定义都要写完整 `visual`，最少包含：
```lua
visual = {
  cast = 0,                -- 施法时特效（可为 0）
  warning = 0,             -- 预警特效（可为 0）
  impact = 0,              -- 命中/落地特效（可为 0）
  hit = 0,                 -- 受击特效（建议非 0）
  projectile_key = 0,      -- 投射物物编ID；非投射物技能可为 0
  projectile_height = 20,  -- 投射高度
}
```

---

## 技能模板（组合式）
```lua
{
  id = 'example_skill',
  name = '示例技能',
  pattern = 'line_pierce',      -- line_pierce|area_burst|area_tick|chain_bounce
  target_mode = 'unit',         -- unit|point|self|none
  damage_type = '物理',          -- 物理|法术|真实
  timeline = {
    cast_point = 0.10,
    impact_delay = 0.20,
    duration = 0.0,
    tick_interval = 0.0,
  },
  resource = {
    cooldown = 0.8,
    charges = 0,
  },
  hit_model = {
    range = 1200,
    width = 180,
    radius = 260,
    max_hits = 0,               -- 0 = unlimited
    bounce = 4,
  },
  scale = {
    attack_ratio = 1.8,
    tick_ratio = 0.4,
    bounce_ratio = 0.75,
  },
  visual = {
    cast = 0,
    warning = 0,
    impact = 0,
    hit = 0,
    projectile_key = 0,
    projectile_height = 20,
  },
}
```

---

## 核心职业默认模板（v1.1）
以下 4 个模板用于快速起盘，优先覆盖当前项目最关键体验。

### 1) 龙骑士（火龙直线穿透）
```lua
{
  id = 'dragon_line_breath',
  name = '火龙直线吐息',
  pattern = 'line_pierce',
  target_mode = 'unit',
  damage_type = '法术',
  timeline = { cast_point = 0.10, impact_delay = 0.18 },
  resource = { cooldown = 0.9, charges = 0 },
  hit_model = { range = 1350, width = 240, max_hits = 0 },
  scale = { attack_ratio = 2.10 },
  visual = {
    cast = 102994,
    warning = 0,
    impact = 104627,
    hit = 104627,
    projectile_key = 201391110, -- bond_visual_editor_ids.lua
    projectile_height = 26,
  },
}
```

### 2) 雷电法王（连锁雷击）
```lua
{
  id = 'thunder_chain_burst',
  name = '连锁雷击',
  pattern = 'chain_bounce',
  target_mode = 'unit',
  damage_type = '法术',
  timeline = { cast_point = 0.05 },
  resource = { cooldown = 0.85, charges = 2 },
  hit_model = { radius = 520, bounce = 5, max_hits = 0 },
  scale = { attack_ratio = 1.55, bounce_ratio = 0.80 },
  visual = {
    cast = 104991,
    warning = 0,
    impact = 104991,
    hit = 104991,
    projectile_key = 201391108, -- bond_visual_editor_ids.lua
    projectile_height = 34,
  },
}
```

### 3) 冰霜法师（暴风雪持续场）
```lua
{
  id = 'frost_blizzard_field',
  name = '暴风雪领域',
  pattern = 'area_tick',
  target_mode = 'point',
  damage_type = '法术',
  timeline = { cast_point = 0.08, duration = 3.8, tick_interval = 0.30 },
  resource = { cooldown = 1.4, charges = 0 },
  hit_model = { radius = 430, max_hits = 0 },
  scale = { tick_ratio = 0.56 },
  visual = {
    cast = 102295,
    warning = 0,
    impact = 102295,
    hit = 102295,
    projectile_key = 201391103, -- bond_visual_editor_ids.lua
    projectile_height = 20,
  },
}
```

### 4) 枪炮师（直线爆轰）
```lua
{
  id = 'gunner_line_blast',
  name = '穿甲爆轰线',
  pattern = 'line_pierce',
  target_mode = 'unit',
  damage_type = '物理',
  timeline = { cast_point = 0.06, impact_delay = 0.16 },
  resource = { cooldown = 0.75, charges = 0 },
  hit_model = { range = 1200, width = 220, max_hits = 0 },
  scale = { attack_ratio = 1.95 },
  visual = {
    cast = 104344,
    warning = 0,
    impact = 104344,
    hit = 104344,
    projectile_key = 201391112, -- bond_visual_editor_ids.lua
    projectile_height = 24,
  },
}
```

---

## 如何查美术资源ID（必须执行）
先查云端索引，再查编辑器全量索引，再查羁绊专属映射，最后查运行时映射与 sample。

## 云端优先策略（MUST）
资源解析优先级固定如下，不可跳级：
1. `maps/EntryMap/script/data/object_tables/cloud_asset_catalog.lua`（云端全量）
2. `maps/EntryMap/script/data/object_tables/editor_asset_catalog.lua`（本地 editor_table 全量）
3. `maps/EntryMap/script/data/object_tables/bond_visual_editor_ids.lua`（项目羁绊定制）
4. `maps/EntryMap/script/data/object_tables/runtime_editor_ids.lua` + `runtime/sample_skills.lua`（运行时映射）

当 1 和 2 都有同名候选时，默认取 1（云端），并在交付里标注 `source=cloud`。

## 云端接口调用（MCP）
用于拉取官方云资源目录（名称/类型/标签/ID），并生成 `cloud_asset_catalog.lua`。
注意：`get_official_editor_model` 仅能覆盖“模型类”，不能当作全资源接口。

### Step 1: 先探测可用接口（MUST）
先列出 `y3editor` 当前可用工具，再决定拉取方案。禁止直接假设某个接口覆盖全资源。

执行要求（必须写进交付）：
1. 先列 `y3editor` 工具清单（tool names）。
2. 从清单中筛出资源检索相关接口（名称包含 `effect`/`particle`/`projectile`/`sound`/`model`/`asset`/`resource`）。
3. 每个类别至少确认 1 个接口；若无则记为 `no_cloud_api`。

### Step 2: 按类别分别拉取（MUST）
需要分别拉：`projectile`、`particle/effect`、`sound`、`model`。
若某类别无云端接口，则回退本地 `editor_table` 对应类别。

调用模板（示意，按你当前 MCP 网关语法执行）：
```yaml
use_mcp_tool:
  server_name: "y3editor"
  tool_name: "<按探测结果选择>"
  arguments: {}
```

说明：
1. `get_official_editor_model`：仅模型类（`model`）。
2. 其它类别必须使用对应接口；若接口不存在则标记 `source=local_editor_table_fallback`。
3. 拉取结果落盘后，转换为 `cloud_asset_catalog.lua`，供技能查表。

### Step 3: 关键词找特效（MUST）
当用户给“暴风雪/箭雨/雷击/血爆”等描述时，先做关键词检索，不直接拍脑袋选 ID。

检索策略：
1. 用中文关键词 + 英文关键词各搜一遍（如 `暴风雪/blizzard`，`雷击/lightning`）。
2. 先看云端结果，再看本地 `editor_asset_catalog.lua`。
3. 候选至少给 3 个，标注来源（cloud/local）、类别（particle/projectile/sound）、ID。

### Step 4: 结果落盘格式（MUST）
把最终选中的资源写入：
1. `cloud_asset_catalog.lua`（云端原始/清洗后的索引）
2. `runtime_editor_ids.lua` 或 `bond_visual_editor_ids.lua`（项目运行时映射）

并在交付里给出：
1. 查询关键词
2. 调用的 MCP 接口名
3. 候选 ID 列表
4. 最终采用 ID + 理由

0. 云端资源ID索引（首选）
```powershell
rg -n "source = 'cloud'|categories|projectile|particle|sound|model" maps/EntryMap/script/data/object_tables/cloud_asset_catalog.lua
```

1. 编辑器全量资源ID索引（次选，覆盖 `editor_table/*`）
```powershell
rg -n "categories|projectileall|modifierall|abilityall|soundall" maps/EntryMap/script/data/object_tables/editor_asset_catalog.lua
```

查看某一类的数量与 ID 列表（示例：projectileall）：
```powershell
rg -n "['\"]projectileall['\"]|count =|ids = \\{" maps/EntryMap/script/data/object_tables/editor_asset_catalog.lua
```

2. 羁绊专属投射物/粒子（项目定制）
```powershell
rg -n "龙骑士|雷电法王|冰霜法师|寒冰法师|枪炮师" maps/EntryMap/script/data/object_tables/bond_visual_editor_ids.lua
```

3. 通用 projectile/ability 物编ID（运行时映射）
```powershell
rg -n "projectile =|arcane_laser|meteor|chain_lightning|frost_nova|fireball" maps/EntryMap/script/data/object_tables/runtime_editor_ids.lua
```

4. sample 技能内已有视觉组合（复用）
```powershell
rg -n "SAMPLE_VISUALS|line_lance|meteor_grid|blizzard|chain_arc" maps/EntryMap/script/runtime/sample_skills.lua
```

查不到时处理（硬失败，MUST）：
1. 任一必需资源（`cast/warning/impact/hit/projectile_key`）未解析到合法 ID，立即报错并中止，不允许自动兜底。
2. 云端无该类接口时，标记 `no_cloud_api` 并中止该技能生产，不允许静默回退。
3. 交付必须给出失败原因：缺失接口名、检索关键词、已尝试候选、缺失字段名。
4. 仅在用户显式同意“允许本地回退”后，才可切到 `editor_table` 本地索引继续。

---

## 快速模式（一句话需求）
当用户只说“做一个XX技能”时，按以下默认落地：
1. 从上述 4 个核心模板中选最接近的一项。
2. 在 `runtime/skills.lua` 创建新技能定义（复制模板改名改参数）。
3. 在 `runtime/sample_skills.lua` 注册并接 `.esample <id>`。
4. 用 `.eframe <id>` 回传 telemetry 基线（cast/hit/empty_rate）。

---

## 验收命令（开发期）
1. 列技能：`.esample list`
2. 施放技能：`.esample <skill_id>`
3. 查看统计：`.eframe <skill_id>`

推荐合格线（可按技能类型微调）：
- `empty_cast_rate <= 5%`
- `avg_hits_per_cast` 与设计目标一致
- `total_damage` 按预期递增且无“0伤害触发”

---

## 交付格式（MUST）
1. 变更文件列表（绝对路径）
2. 每个技能的定义参数摘要（pattern/hit_model/scale/visual）
3. 验收命令与结果摘要（至少包含 `.eframe` 指标）
4. 剩余风险（如特效资源待替换、性能上限待压测）
