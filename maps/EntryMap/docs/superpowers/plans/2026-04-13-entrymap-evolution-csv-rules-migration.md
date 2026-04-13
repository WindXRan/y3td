# EntryMap Evolution CSV Rules Migration Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Move evolution node config and evolution pick rules to CSV while keeping the existing `mark` runtime contracts and the current `marks.csv` effect data stable.

**Architecture:** Add a dedicated `evolution_nodes` object-table loader that reads both node rows and pool-rule rows, then rewire `entry_objects.mark_nodes` to that loader. Update `runtime/rewards.lua` so evolution selection reads `pool_rule_id` from nodes and executes quality-aware weighted picks with owned-item exclusion, same-round dedupe, and a guaranteed high-quality slot when configured.

**Tech Stack:** Lua, CSV static data, Python/Lua smoke tests, PowerShell, git

---

## File Structure

- Create: `script/data_csv/evolution_nodes.csv`
- Create: `script/data_csv/evolution_pool_rules.csv`
- Create: `script/data/object_tables/evolution_nodes.lua`
- Modify: `script/entry_objects/mark_nodes/init.lua`
- Create: `script/tools/test_evolution_nodes_csv_loader_smoke.lua`
- Create: `script/tools/test_evolution_pool_rules_runtime_smoke.lua`
- Modify: `script/runtime/rewards.lua`
- Modify: `script/tools/verify_csv_object_tables.py`
- Modify: `script/docs/项目模块/05-地图数据与资源/代码与数据流向.md`

### Task 1: Move Evolution Nodes To CSV

**Files:**
- Create: `script/tools/test_evolution_nodes_csv_loader_smoke.lua`
- Create: `script/data_csv/evolution_nodes.csv`
- Create: `script/data_csv/evolution_pool_rules.csv`
- Create: `script/data/object_tables/evolution_nodes.lua`
- Modify: `script/entry_objects/mark_nodes/init.lua`

- [ ] **Step 1: Write the failing test**

Create `script/tools/test_evolution_nodes_csv_loader_smoke.lua`:

```lua
package.path = 'script/?.lua;script/?/init.lua;script/?/?.lua;maps/EntryMap/script/?.lua;maps/EntryMap/script/?/init.lua;maps/EntryMap/script/?/?.lua;' .. package.path

local nodes = require 'data.object_tables.evolution_nodes'

assert(type(nodes.list) == 'table', 'nodes.list should be a table')
assert(type(nodes.by_id) == 'table', 'nodes.by_id should be a table')
assert(type(nodes.by_level) == 'table', 'nodes.by_level should be a table')
assert(type(nodes.pool_rules_by_id) == 'table', 'pool_rules_by_id should be a table')
assert(#nodes.list == 4, 'expected 4 evolution nodes')

local node_lv10 = nodes.by_level[10]
assert(node_lv10 ~= nil, 'level 10 node should exist')
assert(node_lv10.id == 'mark_node_lv10', 'level 10 node id should stay intact')
assert(node_lv10.pool_rule_id == 'mark_pool_global', 'level 10 node should keep pool_rule_id')
assert(node_lv10.ui_title == '10级进化选择', 'level 10 node title should stay intact')

local global_rule = nodes.pool_rules_by_id.mark_pool_global
assert(global_rule ~= nil, 'mark_pool_global should exist')
assert(global_rule.guarantee_high_quality == true, 'global rule should enable high-quality guarantee')
assert(global_rule.choice_count == 3, 'global rule choice_count should be numeric')

print('evolution nodes csv loader smoke ok')
```

- [ ] **Step 2: Run test to verify it fails**

Run: `lua script/tools/test_evolution_nodes_csv_loader_smoke.lua`
Expected: FAIL because `data.object_tables.evolution_nodes` does not exist yet.

- [ ] **Step 3: Write minimal implementation**

Create `script/data_csv/evolution_nodes.csv`:

```csv
id,trigger_level,choice_count,pool_rule_id,queue_priority,ui_title
mark_node_lv10,10,3,mark_pool_global,95,10级进化选择
mark_node_lv20,20,3,mark_pool_global,95,20级进化选择
mark_node_lv30,30,3,mark_pool_global,95,30级进化选择
mark_node_lv40,40,3,mark_pool_global,95,40级进化选择
```

Create `script/data_csv/evolution_pool_rules.csv`:

```csv
pool_rule_id,choice_count,common_weight,rare_weight,epic_weight,guarantee_high_quality,same_round_no_repeat,exclude_owned,enabled
mark_pool_global,3,65,25,10,true,true,true,true
```

Create `script/data/object_tables/evolution_nodes.lua`:

```lua
local CsvLoader = require 'data.csv_loader'
local helpers = require 'entry_objects.helpers'

local node_rows = CsvLoader.read_rows('data_csv/evolution_nodes.csv')
local pool_rule_rows = CsvLoader.read_rows('data_csv/evolution_pool_rules.csv')

local function to_boolean(raw)
  return raw == 'true' or raw == '1'
end

local list = {}
for _, row in ipairs(node_rows) do
  list[#list + 1] = {
    id = row.id,
    trigger_level = tonumber(row.trigger_level) or 0,
    choice_count = tonumber(row.choice_count) or 0,
    pool_rule_id = row.pool_rule_id,
    queue_priority = tonumber(row.queue_priority) or 0,
    ui_title = row.ui_title,
  }
end

table.sort(list, function(a, b)
  return (a.trigger_level or 0) < (b.trigger_level or 0)
end)

local by_level = {}
for _, node in ipairs(list) do
  by_level[node.trigger_level] = node
end

local pool_rules = {}
for _, row in ipairs(pool_rule_rows) do
  pool_rules[row.pool_rule_id] = {
    pool_rule_id = row.pool_rule_id,
    choice_count = tonumber(row.choice_count) or 0,
    common_weight = tonumber(row.common_weight) or 0,
    rare_weight = tonumber(row.rare_weight) or 0,
    epic_weight = tonumber(row.epic_weight) or 0,
    guarantee_high_quality = to_boolean(row.guarantee_high_quality),
    same_round_no_repeat = to_boolean(row.same_round_no_repeat),
    exclude_owned = to_boolean(row.exclude_owned),
    enabled = to_boolean(row.enabled),
  }
end

return {
  list = list,
  by_id = helpers.list_to_map(list),
  by_level = by_level,
  pool_rules_by_id = pool_rules,
}
```

Replace `script/entry_objects/mark_nodes/init.lua` with:

```lua
return require 'data.object_tables.evolution_nodes'
```

- [ ] **Step 4: Run test to verify it passes**

Run: `lua script/tools/test_evolution_nodes_csv_loader_smoke.lua`
Expected: PASS with `evolution nodes csv loader smoke ok`

- [ ] **Step 5: Commit**

```bash
git add script/tools/test_evolution_nodes_csv_loader_smoke.lua script/data_csv/evolution_nodes.csv script/data_csv/evolution_pool_rules.csv script/data/object_tables/evolution_nodes.lua script/entry_objects/mark_nodes/init.lua
git commit -m "feat: migrate evolution nodes to CSV"
```

### Task 2: Read CSV Rules In Evolution Pick Logic

**Files:**
- Create: `script/tools/test_evolution_pool_rules_runtime_smoke.lua`
- Modify: `script/runtime/rewards.lua`

- [ ] **Step 1: Write the failing runtime smoke test**

Create `script/tools/test_evolution_pool_rules_runtime_smoke.lua`:

```lua
package.path = 'script/?.lua;script/?/init.lua;script/?/?.lua;maps/EntryMap/script/?.lua;maps/EntryMap/script/?/init.lua;maps/EntryMap/script/?/?.lua;' .. package.path

local RewardSystem = require 'runtime.rewards'

math.randomseed(12345)

local state = {
  mark_runtime = nil,
  treasure_runtime = nil,
}

local api = RewardSystem.create({
  STATE = state,
  message = function() end,
  round_number = function() return 1 end,
  add_attr_pack = function() end,
  hero_attr_system = { add_bonus_attrs = function() end, remove_bonus_attrs = function() end },
  sync_basic_attack_ability = function() end,
  heal_hero = function() end,
  collect_bond_route_tags = function() return {} end,
})

local runtime = api.create_mark_runtime()
state.mark_runtime = runtime

local picks = api.debug_pick_mark_choices_for_rule('mark_pool_global', 3)
assert(#picks == 3, 'should return 3 evolution picks')

local ids = {}
local has_high_quality = false
for _, def in ipairs(picks) do
  assert(ids[def.id] == nil, 'same round should not repeat picks')
  ids[def.id] = true
  if def.quality == 'rare' or def.quality == 'epic' then
    has_high_quality = true
  end
end
assert(has_high_quality, 'global rule should guarantee at least one rare or epic pick')

runtime.owned_mark_ids[picks[1].id] = true
local next_picks = api.debug_pick_mark_choices_for_rule('mark_pool_global', 3)
for _, def in ipairs(next_picks) do
  assert(def.id ~= picks[1].id, 'owned evolutions should be excluded')
end

print('evolution pool rules runtime smoke ok')
```

- [ ] **Step 2: Run test to verify it fails**

Run: `lua script/tools/test_evolution_pool_rules_runtime_smoke.lua`
Expected: FAIL because `debug_pick_mark_choices_for_rule()` does not exist and the runtime still uses hardcoded evolution picks.

- [ ] **Step 3: Write minimal implementation**

Update `script/runtime/rewards.lua` so it reads `pool_rules_by_id` from `entry_objects.mark_nodes`:

```lua
local MARK_POOL_RULES = MarkNodeObjects.pool_rules_by_id or {}
```

Replace the current hardcoded mark pick path with:

```lua
local function build_mark_defs_by_quality(pool_rule)
  local available = build_available_mark_defs(pool_rule)
  local by_quality = {
    common = {},
    rare = {},
    epic = {},
  }

  for _, def in ipairs(available) do
    local quality = def.quality or 'common'
    by_quality[quality] = by_quality[quality] or {}
    by_quality[quality][#by_quality[quality] + 1] = def
  end

  return available, by_quality
end

local function roll_mark_quality(pool_rule, allow_high_quality_only)
  local weights = {
    common = allow_high_quality_only and 0 or (pool_rule.common_weight or 0),
    rare = pool_rule.rare_weight or 0,
    epic = pool_rule.epic_weight or 0,
  }
  -- weighted roll here
end

local function pick_mark_choices_for_rule(pool_rule_id, requested_choice_count)
  local pool_rule = MARK_POOL_RULES[pool_rule_id]
  assert(pool_rule and pool_rule.enabled, string.format('missing enabled mark pool rule: %s', tostring(pool_rule_id)))

  local choice_count = requested_choice_count or pool_rule.choice_count or 3
  local choices = {}
  local used_ids = {}

  while #choices < choice_count do
    local need_high_quality = pool_rule.guarantee_high_quality and #choices == choice_count - 1
    local available, by_quality = build_mark_defs_by_quality(pool_rule)
    -- remove used ids from available buckets
    -- roll quality
    -- weighted pick within chosen quality bucket
    -- fallback to any non-empty bucket if the chosen bucket is empty
    -- append pick and mark used
  end

  return choices
end
```

Expose a test-only helper on the returned API:

```lua
function api.debug_pick_mark_choices_for_rule(pool_rule_id, choice_count)
  return pick_mark_choices_for_rule(pool_rule_id, choice_count)
end
```

Update `try_queue_mark_node_for_level()` to call:

```lua
local choices = pick_mark_choices_for_rule(node.pool_rule_id, node.choice_count or 3)
```

- [ ] **Step 4: Run test to verify it passes**

Run: `lua script/tools/test_evolution_pool_rules_runtime_smoke.lua`
Expected: PASS with `evolution pool rules runtime smoke ok`

- [ ] **Step 5: Commit**

```bash
git add script/tools/test_evolution_pool_rules_runtime_smoke.lua script/runtime/rewards.lua
git commit -m "feat: load evolution pick rules from CSV"
```

### Task 3: Final Verification And Docs

**Files:**
- Modify: `script/tools/verify_csv_object_tables.py`
- Modify: `script/docs/项目模块/05-地图数据与资源/代码与数据流向.md`

- [ ] **Step 1: Extend the static verifier**

Update `script/tools/verify_csv_object_tables.py` with:

```python
require_files(
    "evolution node csv files present",
    [
        "data_csv/evolution_nodes.csv",
        "data_csv/evolution_pool_rules.csv",
        "data/object_tables/evolution_nodes.lua",
    ],
)
```

- [ ] **Step 2: Update the data-flow doc**

Append a concrete note to `script/docs/项目模块/05-地图数据与资源/代码与数据流向.md`:

```md
- 进化本体、进化节点与进化抽取规则现已统一由 `script/data_csv/` 驱动。
- `entry_objects.mark_nodes` 继续保留为稳定入口，但底层来源已切换到 CSV 装配层。
```

- [ ] **Step 3: Run targeted verification**

Run:

```powershell
lua script/tools/test_evolution_nodes_csv_loader_smoke.lua
lua script/tools/test_evolution_pool_rules_runtime_smoke.lua
lua script/tools/test_marks_csv_loader_smoke.lua
py -3 script/tools/verify_csv_object_tables.py
```

Expected:

```text
evolution nodes csv loader smoke ok
evolution pool rules runtime smoke ok
marks csv loader smoke ok
[OK] evolution node csv files present
```

- [ ] **Step 4: Run sanity checks**

Run:

```powershell
git diff -- script/data script/data_csv script/entry_objects/mark_nodes script/runtime/rewards.lua script/tools script/docs
git status --short script/data script/data_csv script/entry_objects/mark_nodes script/runtime/rewards.lua script/tools script/docs
```

Expected: only intended evolution CSV-rule migration files changed.

- [ ] **Step 5: Commit**

```bash
git add script/tools/verify_csv_object_tables.py script/docs/项目模块/05-地图数据与资源/代码与数据流向.md
git commit -m "docs: finalize evolution CSV rule migration"
```
