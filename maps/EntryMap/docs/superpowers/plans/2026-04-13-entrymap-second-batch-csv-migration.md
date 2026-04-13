# EntryMap Second Batch CSV Migration Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Migrate `marks`, `stages`, `stage_modes`, `battle_base_config`, and `hero_attr_config` to CSV-backed loaders while keeping existing Lua entry points and runtime consumers stable.

**Architecture:** Continue the established `data_csv -> data.object_tables -> entry_objects/entry_data` pipeline from the first migration batch. Each object family gets a failing smoke test first, then minimal CSV files and loader assembly, then entry-point rewiring, followed by static verification and doc updates.

**Tech Stack:** Lua, CSV static data, Python/Lua smoke tests, PowerShell, git

---

## File Structure

- Create: `script/data/object_tables/marks.lua`
- Create: `script/data/object_tables/stages.lua`
- Create: `script/data/object_tables/stage_modes.lua`
- Create: `script/data/object_tables/hero_attr_config.lua`
- Create: `script/data/object_tables/battle_base_config.lua`
- Create: `script/data_csv/marks.csv`
- Create: `script/data_csv/mark_bonus_attr.csv`
- Create: `script/data_csv/mark_bonus_runtime.csv`
- Create: `script/data_csv/mark_tags.csv`
- Create: `script/data_csv/stages.csv`
- Create: `script/data_csv/stage_modes.csv`
- Create: `script/data_csv/stage_mode_links.csv`
- Create: `script/data_csv/hero_init_stats.csv`
- Create: `script/data_csv/debug_hero_bonus_stats.csv`
- Create: `script/data_csv/panel_default_attrs.csv`
- Create: `script/data_csv/battle_base_rules.csv`
- Modify: `script/entry_objects/marks/init.lua`
- Modify: `script/entry_objects/stages/init.lua`
- Modify: `script/entry_objects/stage_modes/init.lua`
- Modify: `script/entry_data/hero_attr_config.lua`
- Modify: `script/entry_data/battle_base_config.lua`
- Modify: `script/tools/verify_csv_object_tables.py`
- Create: `script/tools/test_marks_csv_loader_smoke.lua`
- Create: `script/tools/test_stages_csv_loader_smoke.lua`
- Create: `script/tools/test_stage_modes_csv_loader_smoke.lua`
- Create: `script/tools/test_hero_attr_config_csv_loader_smoke.lua`
- Create: `script/tools/test_battle_base_config_csv_loader_smoke.lua`
- Modify: `script/docs/项目模块/05-地图数据与资源/代码与数据流向.md`

### Task 1: Migrate Marks To CSV

**Files:**
- Create: `script/tools/test_marks_csv_loader_smoke.lua`
- Create: `script/data_csv/marks.csv`
- Create: `script/data_csv/mark_bonus_attr.csv`
- Create: `script/data_csv/mark_bonus_runtime.csv`
- Create: `script/data_csv/mark_tags.csv`
- Create: `script/data/object_tables/marks.lua`
- Modify: `script/entry_objects/marks/init.lua`

- [ ] **Step 1: Write the failing test**

```lua
local marks = require 'entry_objects.marks'

assert(type(marks) == 'table', 'marks module should return a table')
assert(type(marks.list) == 'table', 'marks.list should be a table')
assert(type(marks.by_id) == 'table', 'marks.by_id should be a table')
assert(#marks.list == 9, 'expected 9 marks')

local battle_scar = marks.by_id.battle_scar_mark
assert(battle_scar ~= nil, 'battle_scar_mark should exist')
assert(battle_scar.quality == 'common', 'battle_scar_mark should keep quality')
assert(battle_scar.pool_weight == 10, 'battle_scar_mark should keep pool_weight')
assert(type(battle_scar.tags) == 'table', 'battle_scar_mark.tags should be a table')
assert(#battle_scar.tags >= 1, 'battle_scar_mark should keep at least one tag')
assert(type(battle_scar.bonuses) == 'table', 'battle_scar_mark.bonuses should be a table')
assert(type(battle_scar.bonuses.runtime) == 'table', 'battle_scar_mark runtime bonuses should be a table')
assert(battle_scar.bonuses.runtime.skill_damage_bonus == 0.12, 'battle_scar_mark runtime bonus should stay intact')

print('marks csv loader smoke ok')
```

- [ ] **Step 2: Run test to verify it fails**

Run: `lua script/tools/test_marks_csv_loader_smoke.lua`
Expected: FAIL because `marks` still loads single-file Lua objects and does not expose the CSV-assembled structure expected by the new smoke test.

- [ ] **Step 3: Write minimal implementation**

Create `script/data/object_tables/marks.lua` to:

```lua
local CsvLoader = require 'data.csv_loader'
local helpers = require 'entry_objects.helpers'

local mark_rows = CsvLoader.read_rows('data_csv/marks.csv')
local bonus_attr_rows = CsvLoader.read_rows('data_csv/mark_bonus_attr.csv')
local bonus_runtime_rows = CsvLoader.read_rows('data_csv/mark_bonus_runtime.csv')
local tag_rows = CsvLoader.read_rows('data_csv/mark_tags.csv')

local bonus_attr_groups = CsvLoader.group_by(bonus_attr_rows, 'mark_id')
local bonus_runtime_groups = CsvLoader.group_by(bonus_runtime_rows, 'mark_id')
local tag_groups = CsvLoader.group_by(tag_rows, 'mark_id')

local function to_number_if_possible(raw)
  if raw == nil or raw == '' then
    return raw
  end
  return tonumber(raw) or raw
end

local function build_bonus(mark_id)
  local bonuses = {
    runtime = {},
    attack_skill = {},
  }
  for _, row in ipairs(bonus_attr_groups[mark_id] or {}) do
    bonuses.attr = bonuses.attr or {}
    bonuses.attr[row.attr] = to_number_if_possible(row.value)
  end
  for _, row in ipairs(bonus_runtime_groups[mark_id] or {}) do
    local target = row.bucket == 'attack_skill' and bonuses.attack_skill or bonuses.runtime
    target[row.runtime_key] = to_number_if_possible(row.value)
  end
  return bonuses
end

local list = {}
for _, row in ipairs(mark_rows) do
  local tags = {}
  for _, tag_row in ipairs(tag_groups[row.id] or {}) do
    tags[#tags + 1] = tag_row.tag
  end

  list[#list + 1] = {
    id = row.id,
    name = row.name,
    quality = row.quality,
    pool_weight = tonumber(row.pool_weight) or 0,
    summary = row.summary,
    tags = tags,
    bonuses = build_bonus(row.id),
  }
end

return {
  list = list,
  by_id = helpers.list_to_map(list),
}
```

Populate the CSV files from the current `script/entry_objects/marks/*.lua` definitions and replace `script/entry_objects/marks/init.lua` with:

```lua
return require 'data.object_tables.marks'
```

- [ ] **Step 4: Run test to verify it passes**

Run: `lua script/tools/test_marks_csv_loader_smoke.lua`
Expected: PASS with `marks csv loader smoke ok`

- [ ] **Step 5: Commit**

```bash
git add script/tools/test_marks_csv_loader_smoke.lua script/data_csv/marks.csv script/data_csv/mark_bonus_attr.csv script/data_csv/mark_bonus_runtime.csv script/data_csv/mark_tags.csv script/data/object_tables/marks.lua script/entry_objects/marks/init.lua
git commit -m "feat: migrate marks to CSV"
```

### Task 2: Migrate Stages And Stage Modes To CSV

**Files:**
- Create: `script/tools/test_stages_csv_loader_smoke.lua`
- Create: `script/tools/test_stage_modes_csv_loader_smoke.lua`
- Create: `script/data_csv/stages.csv`
- Create: `script/data_csv/stage_modes.csv`
- Create: `script/data_csv/stage_mode_links.csv`
- Create: `script/data/object_tables/stages.lua`
- Create: `script/data/object_tables/stage_modes.lua`
- Modify: `script/entry_objects/stages/init.lua`
- Modify: `script/entry_objects/stage_modes/init.lua`

- [ ] **Step 1: Write the failing tests**

Create `script/tools/test_stages_csv_loader_smoke.lua`:

```lua
local stages = require 'entry_objects.stages'

assert(type(stages.list) == 'table', 'stages.list should be a table')
assert(type(stages.by_id) == 'table', 'stages.by_id should be a table')
assert(#stages.list >= 3, 'expected at least 3 stages')
assert(stages.by_id.stage_1_1 ~= nil, 'stage_1_1 should exist')

print('stages csv loader smoke ok')
```

Create `script/tools/test_stage_modes_csv_loader_smoke.lua`:

```lua
local stage_modes = require 'entry_objects.stage_modes'

assert(type(stage_modes.list) == 'table', 'stage_modes.list should be a table')
assert(type(stage_modes.by_id) == 'table', 'stage_modes.by_id should be a table')
assert(stage_modes.by_id.standard ~= nil, 'standard mode should exist')
assert(stage_modes.by_id.challenge ~= nil, 'challenge mode should exist')

print('stage_modes csv loader smoke ok')
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `lua script/tools/test_stages_csv_loader_smoke.lua`
Expected: FAIL because the old stage object loader does not yet use CSV assembly.

Run: `lua script/tools/test_stage_modes_csv_loader_smoke.lua`
Expected: FAIL because the old mode object loader does not yet use CSV assembly.

- [ ] **Step 3: Write minimal implementation**

Create `script/data/object_tables/stages.lua` and `script/data/object_tables/stage_modes.lua` following the same pattern:

```lua
local CsvLoader = require 'data.csv_loader'
local helpers = require 'entry_objects.helpers'

local stage_rows = CsvLoader.read_rows('data_csv/stages.csv')
local stage_mode_rows = CsvLoader.read_rows('data_csv/stage_modes.csv')
local stage_mode_link_rows = CsvLoader.read_rows('data_csv/stage_mode_links.csv')

local mode_groups = CsvLoader.group_by(stage_mode_link_rows, 'stage_id')

local function to_number_if_possible(raw)
  if raw == nil or raw == '' then
    return raw
  end
  return tonumber(raw) or raw
end

local stage_list = {}
for _, row in ipairs(stage_rows) do
  local mode_ids = {}
  for _, mode_row in ipairs(mode_groups[row.stage_id] or {}) do
    mode_ids[#mode_ids + 1] = mode_row.mode_id
  end
  stage_list[#stage_list + 1] = {
    id = row.id,
    stage_id = row.stage_id,
    display_name = row.display_name,
    order_index = tonumber(row.order_index) or 0,
    content_source_stage_id = row.content_source_stage_id,
    mode_ids = mode_ids,
    preview_note = row.preview_note ~= '' and row.preview_note or nil,
  }
end

table.sort(stage_list, function(a, b)
  return (a.order_index or 0) < (b.order_index or 0)
end)

local stage_mode_list = {}
for _, row in ipairs(stage_mode_rows) do
  stage_mode_list[#stage_mode_list + 1] = {
    id = row.id,
    mode_id = row.mode_id,
    display_name = row.display_name,
    unlock_rule = row.unlock_rule,
    ui_badge_text = row.ui_badge_text,
    battle_config_key = row.battle_config_key,
    result_bucket = row.result_bucket,
  }
end
```

Finish the two return blocks as:

```lua
return {
  list = stage_list,
  by_id = helpers.list_to_map(stage_list),
}
```

and

```lua
return {
  list = stage_mode_list,
  by_id = helpers.list_to_map(stage_mode_list),
}
```

Create `script/data_csv/stage_mode_links.csv` so each stage-to-mode relation stays one row per link instead of storing delimited values, then rewire:

```lua
return require 'data.object_tables.stages'
```

and

```lua
return require 'data.object_tables.stage_modes'
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `lua script/tools/test_stages_csv_loader_smoke.lua`
Expected: PASS with `stages csv loader smoke ok`

Run: `lua script/tools/test_stage_modes_csv_loader_smoke.lua`
Expected: PASS with `stage_modes csv loader smoke ok`

- [ ] **Step 5: Commit**

```bash
git add script/tools/test_stages_csv_loader_smoke.lua script/tools/test_stage_modes_csv_loader_smoke.lua script/data_csv/stages.csv script/data_csv/stage_modes.csv script/data_csv/stage_mode_links.csv script/data/object_tables/stages.lua script/data/object_tables/stage_modes.lua script/entry_objects/stages/init.lua script/entry_objects/stage_modes/init.lua
git commit -m "feat: migrate stages and modes to CSV"
```

### Task 3: Migrate Hero Attribute Config To CSV

**Files:**
- Create: `script/tools/test_hero_attr_config_csv_loader_smoke.lua`
- Create: `script/data_csv/hero_init_stats.csv`
- Create: `script/data_csv/debug_hero_bonus_stats.csv`
- Create: `script/data_csv/panel_default_attrs.csv`
- Create: `script/data/object_tables/hero_attr_config.lua`
- Modify: `script/entry_data/hero_attr_config.lua`

- [ ] **Step 1: Write the failing test**

```lua
local cfg = require 'entry_data.hero_attr_config'

assert(type(cfg.panel_default_attrs) == 'table', 'panel_default_attrs should be a table')
assert(type(cfg.hero_init_stats) == 'table', 'hero_init_stats should be a table')
assert(type(cfg.debug_hero_bonus_stats) == 'table', 'debug_hero_bonus_stats should be a table')
assert(type(cfg.panel_default_attrs['攻击白字']) == 'number', 'panel default attr should remain numeric')
assert(type(cfg.hero_init_stats['生命白字']) == 'number', 'hero init stat should remain numeric')
assert(type(cfg.debug_hero_bonus_stats['攻击范围']) == 'number', 'debug hero bonus stat should remain numeric')

print('hero_attr_config csv loader smoke ok')
```

- [ ] **Step 2: Run test to verify it fails**

Run: `lua script/tools/test_hero_attr_config_csv_loader_smoke.lua`
Expected: FAIL because the test expects the new CSV-backed entry path, which does not exist yet.

- [ ] **Step 3: Write minimal implementation**

Create `script/data/object_tables/hero_attr_config.lua`:

```lua
local CsvLoader = require 'data.csv_loader'

local function read_scalar_map(path)
  local rows = CsvLoader.read_rows(path)
  local result = {}
  for _, row in ipairs(rows) do
    result[row.key] = tonumber(row.value) or row.value
  end
  return result
end

return {
  panel_default_attrs = read_scalar_map('data_csv/panel_default_attrs.csv'),
  hero_init_stats = read_scalar_map('data_csv/hero_init_stats.csv'),
  debug_hero_bonus_stats = read_scalar_map('data_csv/debug_hero_bonus_stats.csv'),
}
```

Before returning, merge `panel_default_attrs` into `hero_init_stats` to preserve the current contract:

```lua
local panel_default_attrs = read_scalar_map('data_csv/panel_default_attrs.csv')
local hero_init_stats = read_scalar_map('data_csv/hero_init_stats.csv')
for key, value in pairs(panel_default_attrs) do
  if hero_init_stats[key] == nil then
    hero_init_stats[key] = value
  end
end

return {
  panel_default_attrs = panel_default_attrs,
  hero_init_stats = hero_init_stats,
  debug_hero_bonus_stats = read_scalar_map('data_csv/debug_hero_bonus_stats.csv'),
}
```

Replace `script/entry_data/hero_attr_config.lua` with:

```lua
return require 'data.object_tables.hero_attr_config'
```

- [ ] **Step 4: Run test to verify it passes**

Run: `lua script/tools/test_hero_attr_config_csv_loader_smoke.lua`
Expected: PASS with `hero_attr_config csv loader smoke ok`

- [ ] **Step 5: Commit**

```bash
git add script/tools/test_hero_attr_config_csv_loader_smoke.lua script/data_csv/panel_default_attrs.csv script/data_csv/hero_init_stats.csv script/data_csv/debug_hero_bonus_stats.csv script/data/object_tables/hero_attr_config.lua script/entry_data/hero_attr_config.lua
git commit -m "feat: migrate hero attr config to CSV"
```

### Task 4: Migrate Battle Base Config To CSV

**Files:**
- Create: `script/tools/test_battle_base_config_csv_loader_smoke.lua`
- Create: `script/data_csv/battle_base_rules.csv`
- Create: `script/data/object_tables/battle_base_config.lua`
- Modify: `script/entry_data/battle_base_config.lua`

- [ ] **Step 1: Write the failing test**

```lua
local cfg = require 'entry_data.battle_base_config'

assert(type(cfg) == 'table', 'battle_base_config should return a table')
assert(type(cfg.hero_init_stats) == 'table', 'hero_init_stats should still be embedded')
assert(type(cfg.global_rules) == 'table', 'global_rules should remain a table')
assert(type(cfg.progression_rules) == 'table', 'progression_rules should remain a table')
assert(type(cfg.resource_rules) == 'table', 'resource_rules should remain a table')
assert(type(cfg.challenge_rules) == 'table', 'challenge_rules should remain a table')
assert(type(cfg.global_rules.player_id) == 'number', 'player_id should remain numeric')
assert(type(cfg.challenge_rules.recover_sec) == 'number', 'recover_sec should remain numeric')

print('battle_base_config csv loader smoke ok')
```

- [ ] **Step 2: Run test to verify it fails**

Run: `lua script/tools/test_battle_base_config_csv_loader_smoke.lua`
Expected: FAIL because the new CSV-backed structure is not wired yet.

- [ ] **Step 3: Write minimal implementation**

Create `script/data/object_tables/battle_base_config.lua`:

```lua
local CsvLoader = require 'data.csv_loader'
local hero_attr_config = require 'data.object_tables.hero_attr_config'

local function read_rule_groups(path)
  local rows = CsvLoader.read_rows(path)
  local result = {}
  for _, row in ipairs(rows) do
    result[row.group] = result[row.group] or {}
    result[row.group][row.key] = tonumber(row.value) or row.value
  end
  return result
end

local groups = read_rule_groups('data_csv/battle_base_rules.csv')

return {
  global_rules = groups.global_rules or {},
  hero_init_stats = hero_attr_config.hero_init_stats,
  debug_hero_bonus_stats = hero_attr_config.debug_hero_bonus_stats,
  debug_apply_hero_bonus_on_spawn = (groups.flags or {}).debug_apply_hero_bonus_on_spawn == 1,
  progression_rules = groups.progression_rules or {},
  resource_rules = groups.resource_rules or {},
  challenge_rules = groups.challenge_rules or {},
}
```

Replace `script/entry_data/battle_base_config.lua` with:

```lua
return require 'data.object_tables.battle_base_config'
```

- [ ] **Step 4: Run test to verify it passes**

Run: `lua script/tools/test_battle_base_config_csv_loader_smoke.lua`
Expected: PASS with `battle_base_config csv loader smoke ok`

- [ ] **Step 5: Commit**

```bash
git add script/tools/test_battle_base_config_csv_loader_smoke.lua script/data_csv/battle_base_rules.csv script/data/object_tables/battle_base_config.lua script/entry_data/battle_base_config.lua
git commit -m "feat: migrate battle base config to CSV"
```

### Task 5: Final Verification And Docs

**Files:**
- Modify: `script/tools/verify_csv_object_tables.py`
- Modify: `script/docs/项目模块/05-地图数据与资源/代码与数据流向.md`

- [ ] **Step 1: Update the verifier**

Extend `script/tools/verify_csv_object_tables.py` so it checks for:

```python
required_second_batch = [
    "data_csv/marks.csv",
    "data_csv/mark_bonus_attr.csv",
    "data_csv/mark_bonus_runtime.csv",
    "data_csv/mark_tags.csv",
    "data_csv/stages.csv",
    "data_csv/stage_modes.csv",
    "data_csv/hero_init_stats.csv",
    "data_csv/debug_hero_bonus_stats.csv",
    "data_csv/panel_default_attrs.csv",
    "data_csv/battle_base_rules.csv",
]
```

and prints:

```python
print("[OK] second batch csv files present")
```

- [ ] **Step 2: Update the data-flow doc**

Append a concrete note to `script/docs/项目模块/05-地图数据与资源/代码与数据流向.md`:

```md
- 第二批静态对象 `marks`、`stages`、`stage_modes` 与全局基础数值已迁到 `script/data_csv/`。
- `script/data/object_tables/*` 继续负责把 CSV 装配回 runtime 兼容的 Lua table。
- `attack_upgrades` 暂未纳入 CSV 化范围，仍由运行时逻辑模块维护。
```

- [ ] **Step 3: Run targeted verification**

Run:

```powershell
lua script/tools/test_marks_csv_loader_smoke.lua
lua script/tools/test_stages_csv_loader_smoke.lua
lua script/tools/test_stage_modes_csv_loader_smoke.lua
lua script/tools/test_hero_attr_config_csv_loader_smoke.lua
lua script/tools/test_battle_base_config_csv_loader_smoke.lua
python script/tools/verify_csv_object_tables.py
```

Expected:

```text
marks csv loader smoke ok
stages csv loader smoke ok
stage_modes csv loader smoke ok
hero_attr_config csv loader smoke ok
battle_base_config csv loader smoke ok
[OK] second batch csv files present
```

- [ ] **Step 4: Run final sanity checks**

Run:

```powershell
git diff --check
git status --short script/data script/data_csv script/entry_objects script/entry_data script/tools script/docs
```

Expected: no whitespace errors and only intended second-batch CSV migration files modified.

- [ ] **Step 5: Commit**

```bash
git add script/tools/verify_csv_object_tables.py script/docs/项目模块/05-地图数据与资源/代码与数据流向.md
git commit -m "docs: finalize second batch CSV migration wiring"
```
