# EntryMap CSV Migration Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 把 EntryMap 首批静态对象从单 Lua 文件迁到 CSV，并保持 runtime 继续通过既有 Lua 入口读取兼容对象结构。

**Architecture:** 新增一层通用 CSV loader 与对象装配模块，负责从 `script/data_csv/*.csv` 读取并组装出 `list`、`by_id`、`by_level` 等结构。`script/entry_objects/*/init.lua` 继续作为 runtime 稳定入口，但内部改为转调新的装配模块；runtime 本身不直接读 CSV，也不重写已有抽取算法。

**Tech Stack:** Lua、CSV、PowerShell、Python 3、Git、EntryMap 现有 `entry_objects` / `runtime` 结构

---

## File Map

- Create: `script/data/csv_loader.lua`
  - 提供通用 CSV 读取、表头解析、类型转换、主键校验、按字段分组等能力。
- Create: `script/data/csv_parsers.lua`
  - 提供 number / string / optional-number / optional-string / boolean 等基础解析器与行转换工具。
- Create: `script/data/object_tables/waves.lua`
  - 读取 `waves.csv`、`wave_spawn_segments.csv`、`wave_rewards.csv`，组装兼容现有波次对象的结构。
- Create: `script/data/object_tables/challenges.lua`
  - 读取 `challenges.csv`，组装兼容现有挑战对象的结构。
- Create: `script/data/object_tables/mark_nodes.lua`
  - 读取 `mark_nodes.csv`，组装 `list` / `by_id` / `by_level`。
- Create: `script/data/object_tables/treasures.lua`
  - 读取宝物主表和 bonus 子表，组装兼容现有 `bonuses` 结构。
- Create: `script/data_csv/waves.csv`
- Create: `script/data_csv/wave_spawn_segments.csv`
- Create: `script/data_csv/wave_rewards.csv`
- Create: `script/data_csv/challenges.csv`
- Create: `script/data_csv/mark_nodes.csv`
- Create: `script/data_csv/treasures.csv`
- Create: `script/data_csv/treasure_bonus_attr.csv`
- Create: `script/data_csv/treasure_bonus_runtime.csv`
- Create: `script/data_csv/treasure_bonus_reward_ratio.csv`
- Create: `script/data_csv/treasure_bonus_passive_income.csv`
- Create: `script/tools/verify_csv_object_tables.py`
  - 运行最小静态验证，检查 CSV 读取、对象数量和关键样例字段。
- Modify: `script/entry_objects/waves/init.lua`
  - 从加载单文件模块改成加载 `script/data/object_tables/waves.lua`。
- Modify: `script/entry_objects/challenges/init.lua`
  - 从加载单文件模块改成加载 `script/data/object_tables/challenges.lua`。
- Modify: `script/entry_objects/mark_nodes/init.lua`
  - 从加载单文件模块改成加载 `script/data/object_tables/mark_nodes.lua`。
- Modify: `script/entry_objects/treasures/init.lua`
  - 从加载单文件模块改成加载 `script/data/object_tables/treasures.lua`。
- Delete: `script/entry_objects/waves/wave_1.lua`
- Delete: `script/entry_objects/waves/wave_2.lua`
- Delete: `script/entry_objects/waves/wave_3.lua`
- Delete: `script/entry_objects/waves/wave_4.lua`
- Delete: `script/entry_objects/waves/wave_5.lua`
- Delete: `script/entry_objects/challenges/gold_trial.lua`
- Delete: `script/entry_objects/challenges/wood_trial.lua`
- Delete: `script/entry_objects/challenges/exp_trial.lua`
- Delete: `script/entry_objects/challenges/treasure_trial.lua`
- Delete: `script/entry_objects/mark_nodes/mark_node_lv10.lua`
- Delete: `script/entry_objects/mark_nodes/mark_node_lv20.lua`
- Delete: `script/entry_objects/mark_nodes/mark_node_lv30.lua`
- Delete: `script/entry_objects/mark_nodes/mark_node_lv40.lua`
- Delete: `script/entry_objects/treasures/*.lua`
  - 首批迁移完成后移除旧宝物单文件，保证 CSV 是唯一数据源。
- Modify: `script/docs/项目模块/05-地图数据与资源/代码与数据流向.md`
  - 更新“对象层”的维护方式，说明首批对象已由 CSV 驱动。

## Task 1: Add CSV Parsing Foundation And Static Verifier

**Files:**
- Create: `script/data/csv_loader.lua`
- Create: `script/data/csv_parsers.lua`
- Create: `script/tools/verify_csv_object_tables.py`

- [ ] **Step 1: Write the failing static verifier scaffold**

Create `script/tools/verify_csv_object_tables.py` with a first failing check that expects the new Lua modules to exist:

```python
from pathlib import Path
import sys

ROOT = Path(__file__).resolve().parents[1]

required = [
    ROOT / "data" / "csv_loader.lua",
    ROOT / "data" / "csv_parsers.lua",
]

missing = [str(path) for path in required if not path.exists()]
if missing:
    print("[FAIL] missing files:")
    for item in missing:
        print(item)
    sys.exit(1)

print("[OK] csv foundation files present")
```

- [ ] **Step 2: Run the verifier to confirm it fails before implementation**

Run:

```powershell
python script/tools/verify_csv_object_tables.py
```

Expected:

```text
[FAIL] missing files:
...csv_loader.lua
...csv_parsers.lua
```

- [ ] **Step 3: Create `script/data/csv_parsers.lua`**

Use this minimal parser utility:

```lua
local M = {}

local function trim(value)
  return (tostring(value or ''):gsub('^%s+', ''):gsub('%s+$', ''))
end

function M.required_string(row, field)
  local value = trim(row[field])
  if value == '' then
    error(string.format('[csv] field "%s" is required', field))
  end
  return value
end

function M.optional_string(row, field)
  local value = trim(row[field])
  if value == '' then
    return nil
  end
  return value
end

function M.required_number(row, field)
  local raw = trim(row[field])
  local value = tonumber(raw)
  if not value then
    error(string.format('[csv] field "%s" must be a number, got "%s"', field, raw))
  end
  return value
end

function M.optional_number(row, field)
  local raw = trim(row[field])
  if raw == '' then
    return nil
  end
  local value = tonumber(raw)
  if not value then
    error(string.format('[csv] field "%s" must be a number, got "%s"', field, raw))
  end
  return value
end

return M
```

- [ ] **Step 4: Create `script/data/csv_loader.lua`**

Implement the loader with stable headers and duplicate-key validation:

```lua
local M = {}

local function split_csv_line(line)
  local values = {}
  local current = {}
  local in_quotes = false
  local i = 1
  while i <= #line do
    local ch = line:sub(i, i)
    if ch == '"' then
      local next_ch = line:sub(i + 1, i + 1)
      if in_quotes and next_ch == '"' then
        current[#current + 1] = '"'
        i = i + 1
      else
        in_quotes = not in_quotes
      end
    elseif ch == ',' and not in_quotes then
      values[#values + 1] = table.concat(current)
      current = {}
    else
      current[#current + 1] = ch
    end
    i = i + 1
  end
  values[#values + 1] = table.concat(current)
  return values
end

function M.read_rows(path)
  local file, err = io.open(path, 'r')
  if not file then
    error(string.format('[csv] failed to open %s: %s', path, tostring(err)))
  end

  local headers
  local rows = {}
  local line_no = 0
  for line in file:lines() do
    line_no = line_no + 1
    if line_no == 1 then
      headers = split_csv_line(line)
    elseif line ~= '' then
      local values = split_csv_line(line)
      local row = {}
      for index, header in ipairs(headers) do
        row[header] = values[index] or ''
      end
      rows[#rows + 1] = row
    end
  end
  file:close()

  if not headers or #headers == 0 then
    error(string.format('[csv] missing headers in %s', path))
  end

  return rows
end

function M.index_by(rows, key_field)
  local result = {}
  for _, row in ipairs(rows) do
    local key = row[key_field]
    if not key or key == '' then
      error(string.format('[csv] missing key "%s"', key_field))
    end
    if result[key] then
      error(string.format('[csv] duplicate key "%s" = "%s"', key_field, key))
    end
    result[key] = row
  end
  return result
end

function M.group_by(rows, key_field)
  local result = {}
  for _, row in ipairs(rows) do
    local key = row[key_field]
    if not key or key == '' then
      error(string.format('[csv] missing group key "%s"', key_field))
    end
    result[key] = result[key] or {}
    result[key][#result[key] + 1] = row
  end
  return result
end

return M
```

- [ ] **Step 5: Re-run the verifier and commit the foundation**

Run:

```powershell
python script/tools/verify_csv_object_tables.py
```

Expected:

```text
[OK] csv foundation files present
```

Commit:

```bash
git add script/data/csv_loader.lua script/data/csv_parsers.lua script/tools/verify_csv_object_tables.py
git commit -m "feat: add CSV loader foundation"
```

## Task 2: Migrate Waves To CSV And Keep `CONFIG.waves` Compatible

**Files:**
- Create: `script/data/object_tables/waves.lua`
- Create: `script/data_csv/waves.csv`
- Create: `script/data_csv/wave_spawn_segments.csv`
- Create: `script/data_csv/wave_rewards.csv`
- Modify: `script/entry_objects/waves/init.lua`
- Delete: `script/entry_objects/waves/wave_1.lua`
- Delete: `script/entry_objects/waves/wave_2.lua`
- Delete: `script/entry_objects/waves/wave_3.lua`
- Delete: `script/entry_objects/waves/wave_4.lua`
- Delete: `script/entry_objects/waves/wave_5.lua`
- Modify: `script/tools/verify_csv_object_tables.py`

- [ ] **Step 1: Extend the verifier with a failing waves-CSV presence check**

Append this block to `script/tools/verify_csv_object_tables.py`:

```python
wave_files = [
    ROOT / "data_csv" / "waves.csv",
    ROOT / "data_csv" / "wave_spawn_segments.csv",
    ROOT / "data_csv" / "wave_rewards.csv",
]
missing_wave_files = [str(path) for path in wave_files if not path.exists()]
if missing_wave_files:
    print("[FAIL] missing wave csv files:")
    for item in missing_wave_files:
        print(item)
    sys.exit(1)
```

- [ ] **Step 2: Run the verifier and confirm it now fails on missing wave CSV files**

Run:

```powershell
python script/tools/verify_csv_object_tables.py
```

Expected:

```text
[FAIL] missing wave csv files:
...waves.csv
...wave_spawn_segments.csv
...wave_rewards.csv
```

- [ ] **Step 3: Create the wave CSV files from the current five Lua objects**

Create `script/data_csv/waves.csv`:

```csv
id,index,name,main_unit_id,boss_unit_id,spawn_area_id,boss_spawn_area_id,boss_spawn_sec,batch_min,batch_max,max_alive,post_boss_interval_sec,main_spawn_hp,boss_special,theme,boss_timeline_profile_id,boss_low_hp_profile_id
wave_1,1,第1波：饥饿地精,134280097,134219749,main_spawn_wave_1,boss_spawn_wave_1,48,3,4,10,0.54,1,无,教学近战,boss_timeline_wave_1,boss_low_hp_wave_1
wave_2,2,第2波：荒原游匪,134280098,134279196,main_spawn_wave_2,boss_spawn_wave_2,54,3,5,11,0.54,1,无,远近混编,boss_timeline_wave_2,boss_low_hp_wave_2
wave_3,3,第3波：禁地异兽,134280099,134259608,main_spawn_wave_3,boss_spawn_wave_3,60,4,5,12,0.54,1,无,压力提升,boss_timeline_wave_3,boss_low_hp_wave_3
wave_4,4,第4波：裂谷重甲,134280100,134228855,main_spawn_wave_4,boss_spawn_wave_4,66,4,6,13,0.54,1,无,精英压场,boss_timeline_wave_4,boss_low_hp_wave_4
wave_5,5,第5波：终局魔军,134280101,134222661,main_spawn_wave_5,boss_spawn_wave_5,72,5,6,14,0.54,1,无,终盘决战,boss_timeline_wave_5,boss_low_hp_wave_5
```

Create `script/data_csv/wave_spawn_segments.csv`:

```csv
wave_id,order,start_sec,interval_sec
wave_1,1,0,0.68
wave_1,2,12,0.60
wave_1,3,30,0.54
wave_2,1,0,0.66
wave_2,2,16,0.58
wave_2,3,36,0.52
wave_3,1,0,0.64
wave_3,2,18,0.56
wave_3,3,40,0.50
wave_4,1,0,0.62
wave_4,2,18,0.54
wave_4,3,42,0.48
wave_5,1,0,0.60
wave_5,2,20,0.52
wave_5,3,44,0.46
```

Create `script/data_csv/wave_rewards.csv`:

```csv
wave_id,main_exp,main_gold,main_wood,boss_exp,boss_gold,boss_wood
wave_1,8,4,0,80,55,10
wave_2,10,5,0,100,75,14
wave_3,12,6,1,130,95,20
wave_4,14,7,1,160,125,28
wave_5,16,8,2,210,165,40
```

- [ ] **Step 4: Create `script/data/object_tables/waves.lua` and switch the init module**

Use this object-table module:

```lua
local CsvLoader = require 'data.csv_loader'
local CsvParsers = require 'data.csv_parsers'
local helpers = require 'entry_objects.helpers'

local ROOT = 'script/data_csv/'

local wave_rows = CsvLoader.read_rows(ROOT .. 'waves.csv')
local segment_rows = CsvLoader.read_rows(ROOT .. 'wave_spawn_segments.csv')
local reward_rows = CsvLoader.read_rows(ROOT .. 'wave_rewards.csv')

local segment_groups = CsvLoader.group_by(segment_rows, 'wave_id')
local reward_by_wave = CsvLoader.index_by(reward_rows, 'wave_id')

local list = {}
for _, row in ipairs(wave_rows) do
  local id = CsvParsers.required_string(row, 'id')
  local reward_row = reward_by_wave[id]
  if not reward_row then
    error(string.format('[waves] missing reward row for %s', id))
  end

  local segments = {}
  local rows = segment_groups[id] or {}
  table.sort(rows, function(a, b)
    return CsvParsers.required_number(a, 'order') < CsvParsers.required_number(b, 'order')
  end)
  for _, segment_row in ipairs(rows) do
    segments[#segments + 1] = {
      start_sec = CsvParsers.required_number(segment_row, 'start_sec'),
      interval_sec = CsvParsers.required_number(segment_row, 'interval_sec'),
    }
  end

  list[#list + 1] = {
    id = id,
    index = CsvParsers.required_number(row, 'index'),
    name = CsvParsers.required_string(row, 'name'),
    main_unit_id = CsvParsers.required_number(row, 'main_unit_id'),
    boss_unit_id = CsvParsers.required_number(row, 'boss_unit_id'),
    spawn_area_id = CsvParsers.required_string(row, 'spawn_area_id'),
    boss_spawn_area_id = CsvParsers.required_string(row, 'boss_spawn_area_id'),
    boss_spawn_sec = CsvParsers.required_number(row, 'boss_spawn_sec'),
    batch_min = CsvParsers.required_number(row, 'batch_min'),
    batch_max = CsvParsers.required_number(row, 'batch_max'),
    max_alive = CsvParsers.required_number(row, 'max_alive'),
    post_boss_interval_sec = CsvParsers.required_number(row, 'post_boss_interval_sec'),
    main_spawn_hp = CsvParsers.required_number(row, 'main_spawn_hp'),
    main_attr_overrides = { ['最大生命'] = 1 },
    spawn_segments = segments,
    main_kill_reward = {
      exp = CsvParsers.required_number(reward_row, 'main_exp'),
      gold = CsvParsers.required_number(reward_row, 'main_gold'),
      wood = CsvParsers.required_number(reward_row, 'main_wood'),
    },
    boss_kill_reward = {
      exp = CsvParsers.required_number(reward_row, 'boss_exp'),
      gold = CsvParsers.required_number(reward_row, 'boss_gold'),
      wood = CsvParsers.required_number(reward_row, 'boss_wood'),
    },
    boss_special = CsvParsers.required_string(row, 'boss_special'),
    theme = CsvParsers.required_string(row, 'theme'),
    boss_timeline_profile_id = CsvParsers.required_string(row, 'boss_timeline_profile_id'),
    boss_low_hp_profile_id = CsvParsers.required_string(row, 'boss_low_hp_profile_id'),
  }
end

return {
  list = list,
  by_id = helpers.list_to_map(list),
}
```

Replace `script/entry_objects/waves/init.lua` with:

```lua
return require 'data.object_tables.waves'
```

- [ ] **Step 5: Verify wave compatibility, delete old wave files, and commit**

Extend `script/tools/verify_csv_object_tables.py` with this waves sanity check:

```python
waves_csv = (ROOT / "data_csv" / "waves.csv").read_text(encoding="utf-8")
if "wave_1" not in waves_csv or "wave_5" not in waves_csv:
    print("[FAIL] expected wave ids missing from waves.csv")
    sys.exit(1)
print("[OK] wave csv files present")
```

Run:

```powershell
python script/tools/verify_csv_object_tables.py
```

Expected:

```text
[OK] csv foundation files present
[OK] wave csv files present
```

Then remove:

```powershell
Remove-Item script\entry_objects\waves\wave_1.lua,script\entry_objects\waves\wave_2.lua,script\entry_objects\waves\wave_3.lua,script\entry_objects\waves\wave_4.lua,script\entry_objects\waves\wave_5.lua
```

Commit:

```bash
git add script/data/object_tables/waves.lua script/data_csv/waves.csv script/data_csv/wave_spawn_segments.csv script/data_csv/wave_rewards.csv script/entry_objects/waves/init.lua script/tools/verify_csv_object_tables.py
git add -u script/entry_objects/waves
git commit -m "feat: migrate wave objects to CSV"
```

## Task 3: Migrate Challenges And Mark Nodes To CSV

**Files:**
- Create: `script/data/object_tables/challenges.lua`
- Create: `script/data/object_tables/mark_nodes.lua`
- Create: `script/data_csv/challenges.csv`
- Create: `script/data_csv/mark_nodes.csv`
- Modify: `script/entry_objects/challenges/init.lua`
- Modify: `script/entry_objects/mark_nodes/init.lua`
- Delete: `script/entry_objects/challenges/gold_trial.lua`
- Delete: `script/entry_objects/challenges/wood_trial.lua`
- Delete: `script/entry_objects/challenges/exp_trial.lua`
- Delete: `script/entry_objects/challenges/treasure_trial.lua`
- Delete: `script/entry_objects/mark_nodes/mark_node_lv10.lua`
- Delete: `script/entry_objects/mark_nodes/mark_node_lv20.lua`
- Delete: `script/entry_objects/mark_nodes/mark_node_lv30.lua`
- Delete: `script/entry_objects/mark_nodes/mark_node_lv40.lua`
- Modify: `script/tools/verify_csv_object_tables.py`

- [ ] **Step 1: Add failing checks for `challenges.csv` and `mark_nodes.csv`**

Append to `script/tools/verify_csv_object_tables.py`:

```python
for rel in ("data_csv/challenges.csv", "data_csv/mark_nodes.csv"):
    path = ROOT / rel
    if not path.exists():
        print(f"[FAIL] missing {rel}")
        sys.exit(1)
```

- [ ] **Step 2: Run the verifier and confirm the new checks fail**

Run:

```powershell
python script/tools/verify_csv_object_tables.py
```

Expected:

```text
[FAIL] missing data_csv/challenges.csv
```

- [ ] **Step 3: Create `challenges.csv` and `mark_nodes.csv`**

Create `script/data_csv/challenges.csv`:

```csv
id,name,cost_charge,spawn_area_id,unit_id,boss_unit_id,guard_unit_id,reward_gold,reward_wood,reward_exp,reward_special
gold_trial,金币试炼,1,challenge_spawn_top,134242543,,,260,0,0,
wood_trial,木材试炼,1,challenge_spawn_bottom,134224570,,,0,90,0,
exp_trial,经验试炼,1,challenge_spawn_mid,134275571,,,0,0,280,
treasure_trial,宝物试炼,1,challenge_treasure_elite_spawn,,134228855,134241735,60,30,0,
```

Create `script/data_csv/mark_nodes.csv`:

```csv
id,trigger_level,choice_count,queue_priority,ui_title
mark_node_lv10,10,3,95,10级烙印选择
mark_node_lv20,20,3,95,20级烙印选择
mark_node_lv30,30,3,95,30级烙印选择
mark_node_lv40,40,3,95,40级烙印选择
```

- [ ] **Step 4: Create object-table modules and switch both init files**

Create `script/data/object_tables/challenges.lua`:

```lua
local CsvLoader = require 'data.csv_loader'
local CsvParsers = require 'data.csv_parsers'
local helpers = require 'entry_objects.helpers'

local rows = CsvLoader.read_rows('script/data_csv/challenges.csv')
local list = {}

for _, row in ipairs(rows) do
  list[#list + 1] = {
    id = CsvParsers.required_string(row, 'id'),
    name = CsvParsers.required_string(row, 'name'),
    cost_charge = CsvParsers.required_number(row, 'cost_charge'),
    spawn_area_id = CsvParsers.required_string(row, 'spawn_area_id'),
    reward = {
      gold = CsvParsers.required_number(row, 'reward_gold'),
      wood = CsvParsers.required_number(row, 'reward_wood'),
      exp = CsvParsers.required_number(row, 'reward_exp'),
      special = CsvParsers.optional_string(row, 'reward_special'),
    },
    unit_id = CsvParsers.optional_number(row, 'unit_id'),
    boss_unit_id = CsvParsers.optional_number(row, 'boss_unit_id'),
    guard_unit_id = CsvParsers.optional_number(row, 'guard_unit_id'),
  }
end

return {
  list = list,
  by_id = helpers.list_to_map(list),
}
```

Create `script/data/object_tables/mark_nodes.lua`:

```lua
local CsvLoader = require 'data.csv_loader'
local CsvParsers = require 'data.csv_parsers'
local helpers = require 'entry_objects.helpers'

local rows = CsvLoader.read_rows('script/data_csv/mark_nodes.csv')
local list = {}
local by_level = {}

for _, row in ipairs(rows) do
  local node = {
    id = CsvParsers.required_string(row, 'id'),
    trigger_level = CsvParsers.required_number(row, 'trigger_level'),
    choice_count = CsvParsers.required_number(row, 'choice_count'),
    queue_priority = CsvParsers.required_number(row, 'queue_priority'),
    ui_title = CsvParsers.required_string(row, 'ui_title'),
  }
  list[#list + 1] = node
  by_level[node.trigger_level] = node
end

return {
  list = list,
  by_id = helpers.list_to_map(list),
  by_level = by_level,
}
```

Replace both init files with:

```lua
return require 'data.object_tables.challenges'
```

```lua
return require 'data.object_tables.mark_nodes'
```

- [ ] **Step 5: Re-run verification, remove old files, and commit**

Extend the verifier:

```python
challenges_csv = (ROOT / "data_csv" / "challenges.csv").read_text(encoding="utf-8")
mark_nodes_csv = (ROOT / "data_csv" / "mark_nodes.csv").read_text(encoding="utf-8")
if "gold_trial" not in challenges_csv or "treasure_trial" not in challenges_csv:
    print("[FAIL] expected challenge ids missing")
    sys.exit(1)
if "mark_node_lv10" not in mark_nodes_csv or "mark_node_lv40" not in mark_nodes_csv:
    print("[FAIL] expected mark node ids missing")
    sys.exit(1)
print("[OK] challenge and mark node csv files present")
```

Run:

```powershell
python script/tools/verify_csv_object_tables.py
```

Expected:

```text
[OK] challenge and mark node csv files present
```

Then remove:

```powershell
Remove-Item script\entry_objects\challenges\gold_trial.lua,script\entry_objects\challenges\wood_trial.lua,script\entry_objects\challenges\exp_trial.lua,script\entry_objects\challenges\treasure_trial.lua
Remove-Item script\entry_objects\mark_nodes\mark_node_lv10.lua,script\entry_objects\mark_nodes\mark_node_lv20.lua,script\entry_objects\mark_nodes\mark_node_lv30.lua,script\entry_objects\mark_nodes\mark_node_lv40.lua
```

Commit:

```bash
git add script/data/object_tables/challenges.lua script/data/object_tables/mark_nodes.lua script/data_csv/challenges.csv script/data_csv/mark_nodes.csv script/entry_objects/challenges/init.lua script/entry_objects/mark_nodes/init.lua script/tools/verify_csv_object_tables.py
git add -u script/entry_objects/challenges script/entry_objects/mark_nodes
git commit -m "feat: migrate challenges and mark nodes to CSV"
```

## Task 4: Migrate Treasures To CSV With Bonus Subtables

**Files:**
- Create: `script/data/object_tables/treasures.lua`
- Create: `script/data_csv/treasures.csv`
- Create: `script/data_csv/treasure_bonus_attr.csv`
- Create: `script/data_csv/treasure_bonus_runtime.csv`
- Create: `script/data_csv/treasure_bonus_reward_ratio.csv`
- Create: `script/data_csv/treasure_bonus_passive_income.csv`
- Modify: `script/entry_objects/treasures/init.lua`
- Delete: `script/entry_objects/treasures/*.lua`
- Modify: `script/tools/verify_csv_object_tables.py`

- [ ] **Step 1: Add a failing treasure-CSV presence check**

Append to `script/tools/verify_csv_object_tables.py`:

```python
for rel in (
    "data_csv/treasures.csv",
    "data_csv/treasure_bonus_attr.csv",
    "data_csv/treasure_bonus_runtime.csv",
    "data_csv/treasure_bonus_reward_ratio.csv",
    "data_csv/treasure_bonus_passive_income.csv",
):
    path = ROOT / rel
    if not path.exists():
        print(f"[FAIL] missing {rel}")
        sys.exit(1)
```

- [ ] **Step 2: Run the verifier and confirm it fails before the treasure tables exist**

Run:

```powershell
python script/tools/verify_csv_object_tables.py
```

Expected:

```text
[FAIL] missing data_csv/treasures.csv
```

- [ ] **Step 3: Create the treasure CSV files**

Create `script/data_csv/treasures.csv` with one row per current treasure:

```csv
id,name,quality,pool_weight,summary
hunter_badge,猎手徽记,common,10,普攻伤害 +12%，攻击范围 +60。
feather_quiver,羽矢箭袋,common,9,攻击速度与分裂输出提升。
field_bandage,战地绷带,common,8,最大生命与续航能力提升。
coin_casket,金币匣,common,8,金币奖励 +25%，每秒额外获得 1 金币；每 5.5 秒触发 1 次金币爆鸣。
echo_codex,回响秘典,common,7,奥术系输出与法术触发效率提升。
gale_tailfeather,疾风尾羽,common,7,风系技能范围与频率提升。
thunder_pin,惊雷别针,common,7,电系伤害与感电效率提升。
heart_guard_mirror,心卫镜,rare,6,提高生存与护盾类收益，并触发守护脉冲。
harvest_flask,丰收药瓶,rare,6,掉落收益提升，并按节奏触发收割效果。
time_rift_hourglass,时隙沙漏,rare,5,提升冷却效率与时序收益。
dragonblood_ring,龙血戒,rare,5,强化生命与持续作战能力。
crown_fragment,王冠残片,epic,4,大幅提高核心战斗属性。
battle_horn,战号角,rare,8,提高挑战与短爆发收益。
charged_talisman,蓄能符,rare,6,强化技能能量与节奏爆发。
challenge_banner,试炼战旗,epic,4,强化挑战收益与试炼表现。
emergency_ration,应急口粮,rare,6,低压时提供恢复与容错。
boss_edict,王令敕文,epic,4,强化对精英与 Boss 的终盘压制能力。
```

Create `script/data_csv/treasure_bonus_reward_ratio.csv`:

```csv
treasure_id,key,value
coin_casket,gold,0.25
harvest_flask,gold,0.15
harvest_flask,wood,0.15
challenge_banner,gold,0.20
challenge_banner,wood,0.20
challenge_banner,exp,0.20
```

Create `script/data_csv/treasure_bonus_passive_income.csv`:

```csv
treasure_id,key,value
coin_casket,gold,1
harvest_flask,wood,1
```

Create `script/data_csv/treasure_bonus_attr.csv`:

```csv
treasure_id,attr_name,value
hunter_badge,攻击白字,18
hunter_badge,攻击范围,60
field_bandage,生命白字,260
dragonblood_ring,生命白字,420
crown_fragment,攻击白字,36
crown_fragment,生命白字,320
boss_edict,挑战伤害,18
```

Create `script/data_csv/treasure_bonus_runtime.csv`:

```csv
treasure_id,key,value
feather_quiver,normal_attack_bonus_ratio,0.12
feather_quiver,split_count,1
echo_codex,burst_ratio,0.20
gale_tailfeather,field_radius,80
thunder_pin,shock_bonus,0.18
heart_guard_mirror,guardian_pulse,1
harvest_flask,harvest_blade,1
time_rift_hourglass,cooldown_reduction,0.12
battle_horn,boss_bonus_ratio,0.18
charged_talisman,bonus_gold_on_kill,1
challenge_banner,challenge_bonus_ratio,0.20
emergency_ration,heal_ratio,0.08
boss_edict,boss_bonus_ratio,0.30
```

Create an empty but tracked `script/data_csv/treasure_bonus_skill_runtime.csv` only if current treasure files prove it is needed; otherwise do not add extra tables beyond the four defined in the spec.

- [ ] **Step 4: Implement `script/data/object_tables/treasures.lua` and switch the init file**

Use this loader shape:

```lua
local CsvLoader = require 'data.csv_loader'
local CsvParsers = require 'data.csv_parsers'
local helpers = require 'entry_objects.helpers'

local treasure_rows = CsvLoader.read_rows('script/data_csv/treasures.csv')
local attr_rows = CsvLoader.read_rows('script/data_csv/treasure_bonus_attr.csv')
local runtime_rows = CsvLoader.read_rows('script/data_csv/treasure_bonus_runtime.csv')
local reward_rows = CsvLoader.read_rows('script/data_csv/treasure_bonus_reward_ratio.csv')
local income_rows = CsvLoader.read_rows('script/data_csv/treasure_bonus_passive_income.csv')

local attr_groups = CsvLoader.group_by(attr_rows, 'treasure_id')
local runtime_groups = CsvLoader.group_by(runtime_rows, 'treasure_id')
local reward_groups = CsvLoader.group_by(reward_rows, 'treasure_id')
local income_groups = CsvLoader.group_by(income_rows, 'treasure_id')

local function rows_to_pack(rows, key_field)
  local pack = {}
  for _, row in ipairs(rows or {}) do
    pack[CsvParsers.required_string(row, key_field)] = CsvParsers.required_number(row, 'value')
  end
  if next(pack) == nil then
    return nil
  end
  return pack
end

local list = {}
for _, row in ipairs(treasure_rows) do
  local id = CsvParsers.required_string(row, 'id')
  list[#list + 1] = {
    id = id,
    name = CsvParsers.required_string(row, 'name'),
    quality = CsvParsers.required_string(row, 'quality'),
    pool_weight = CsvParsers.required_number(row, 'pool_weight'),
    summary = CsvParsers.required_string(row, 'summary'),
    bonuses = {
      attr = rows_to_pack(attr_groups[id], 'attr_name'),
      runtime = rows_to_pack(runtime_groups[id], 'key'),
      reward_ratio = rows_to_pack(reward_groups[id], 'key'),
      passive_income = rows_to_pack(income_groups[id], 'key'),
    },
  }
end

return {
  list = list,
  by_id = helpers.list_to_map(list),
}
```

Replace `script/entry_objects/treasures/init.lua` with:

```lua
return require 'data.object_tables.treasures'
```

- [ ] **Step 5: Verify, delete old treasure files, and commit**

Extend the verifier:

```python
treasures_csv = (ROOT / "data_csv" / "treasures.csv").read_text(encoding="utf-8")
for token in ("coin_casket", "challenge_banner", "boss_edict"):
    if token not in treasures_csv:
        print(f"[FAIL] missing treasure row for {token}")
        sys.exit(1)
print("[OK] treasure csv files present")
```

Run:

```powershell
python script/tools/verify_csv_object_tables.py
```

Expected:

```text
[OK] treasure csv files present
```

Then delete all current treasure single-file definitions:

```powershell
Get-ChildItem script\entry_objects\treasures\*.lua | Where-Object { $_.Name -ne 'init.lua' } | Remove-Item
```

Commit:

```bash
git add script/data/object_tables/treasures.lua script/data_csv/treasures.csv script/data_csv/treasure_bonus_attr.csv script/data_csv/treasure_bonus_runtime.csv script/data_csv/treasure_bonus_reward_ratio.csv script/data_csv/treasure_bonus_passive_income.csv script/entry_objects/treasures/init.lua script/tools/verify_csv_object_tables.py
git add -u script/entry_objects/treasures
git commit -m "feat: migrate treasure objects to CSV"
```

## Task 5: Finalize Loader Integration, Update Docs, And Run Verification

**Files:**
- Modify: `script/docs/项目模块/05-地图数据与资源/代码与数据流向.md`
- Modify: `script/tools/verify_csv_object_tables.py`
- Review: `script/runtime/battlefield.lua`
- Review: `script/runtime/rewards.lua`
- Review: `script/config/entry_config.lua`

- [ ] **Step 1: Update the data-flow doc to reflect the new source of truth**

Append a concrete note to `script/docs/项目模块/05-地图数据与资源/代码与数据流向.md`:

```md
- `waves`、`challenges`、`treasures`、`mark_nodes` 的静态内容已迁到 `script/data_csv/`。
- `script/data/object_tables/*` 负责把 CSV 装配成 runtime 继续使用的 Lua 对象结构。
- `script/entry_objects/*/init.lua` 保留为稳定入口，不再直接汇总单对象 Lua 文件。
```

- [ ] **Step 2: Add a final verifier summary block**

Finish `script/tools/verify_csv_object_tables.py` with:

```python
print("[OK] static CSV migration checks passed")
```

- [ ] **Step 3: Run the final static verification**

Run:

```powershell
python script/tools/verify_csv_object_tables.py
```

Expected:

```text
[OK] csv foundation files present
[OK] wave csv files present
[OK] challenge and mark node csv files present
[OK] treasure csv files present
[OK] static CSV migration checks passed
```

- [ ] **Step 4: Run the final repository sanity checks**

Run:

```powershell
git diff --check
git status --short script/data script/data_csv script/entry_objects script/tools/verify_csv_object_tables.py script/docs/项目模块/05-地图数据与资源/代码与数据流向.md
```

Expected:

```text
No whitespace errors; only the intended CSV migration files appear in the scoped status output
```

- [ ] **Step 5: Commit the docs and verification finish**

```bash
git add script/docs/项目模块/05-地图数据与资源/代码与数据流向.md script/tools/verify_csv_object_tables.py
git commit -m "docs: document entry object CSV migration"
```
