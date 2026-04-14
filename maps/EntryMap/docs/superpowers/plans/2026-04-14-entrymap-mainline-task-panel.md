# EntryMap Mainline Task Panel Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build the in-battle right-side mainline task panel, wire it to the existing mainline task runtime, and make the `自动任务` checkbox behave as a real tracker toggle.

**Architecture:** Keep using `GameHUD.hud_root.right_tracker_panel` as the task card shell, extend `runtime.mainline_tasks` to expose real progress, readable reward text, and tracker state, then refresh the panel from the runtime HUD bridge in `runtime_hud_v2.lua` while preserving the panel1 top remapping in `runtime_hud_panel1_top.lua`.

**Tech Stack:** Lua runtime systems, Y3 UI JSON assets, Python/Lua smoke tests, Git

---

## File Map

- Modify: `maps/EntryMap/script/runtime/mainline_tasks.lua`
  - Add tracker runtime defaults, readable reward name mapping, and summary fields for panel consumption.
- Modify: `maps/EntryMap/script/runtime/boot.lua`
  - Pass any new task panel helpers into the HUD env without disturbing current battle/runtime boot.
- Modify: `maps/EntryMap/script/ui/runtime_hud_v2.lua`
  - Refresh right tracker texts, checkbox state, and click handler.
- Modify: `maps/EntryMap/script/ui/runtime_hud_panel1_top.lua`
  - Stop hiding the right tracker panel when panel1 top is enabled.
- Modify: `maps/EntryMap/ui/GameHUD.json`
  - Restyle `right_tracker_panel` to match the approved card layout.
- Modify: `maps/EntryMap/ui_tree/GameHUD_Tree.json`
  - Regenerate node tree after UI JSON change.
- Modify: `maps/EntryMap/script/tools/test_mainline_task_runtime_smoke.lua`
  - Assert new summary fields and tracker defaults.
- Create: `maps/EntryMap/script/tools/test_runtime_hud_task_panel_static.py`
  - Assert HUD bridge binds and refreshes tracker nodes.
- Modify: `maps/EntryMap/script/tools/test_runtime_hud_panel1_top_binding_static.py`
  - Assert panel1 top no longer hides the right tracker panel.

### Task 1: Lock Runtime Summary And Tracker State

**Files:**
- Modify: `maps/EntryMap/script/runtime/mainline_tasks.lua`
- Modify: `maps/EntryMap/script/tools/test_mainline_task_runtime_smoke.lua`

- [ ] **Step 1: Write the failing smoke expectations**

```lua
local summary = api.get_current_task_summary()
assert(summary.current_count == 0, 'expected summary current_count default')
assert(summary.target_count == 3, 'expected summary target_count passthrough')
assert(summary.progress_text == '击杀虚空行者(0/3)', 'expected player-facing progress text')
assert(summary.reward_line_texts[1] == '格挡 +2', 'expected readable reward text')

local tracker = api.get_tracker_state()
assert(tracker.auto_track_enabled == true, 'expected tracker auto tracking enabled by default')
assert(tracker.snapshot_summary == nil, 'expected tracker snapshot default nil')
```

- [ ] **Step 2: Run test to verify it fails**

Run: `lua maps/EntryMap/script/tools/test_mainline_task_runtime_smoke.lua`

Expected: FAIL because `current_count`, `get_tracker_state`, and the new progress formatting are not implemented yet.

- [ ] **Step 3: Implement minimal runtime support in `mainline_tasks.lua`**

```lua
STATE.mainline_task_runtime = STATE.mainline_task_runtime or {
  chapter_id = 1,
  floor_index = 1,
  completed_task_ids = {},
  hero_card_count = 0,
  progress_by_task_id = {},
  auto_track_enabled = true,
  pinned_task_id = nil,
  snapshot_summary = nil,
}

function api.get_current_progress_count(task_id)
  local runtime = ensure_runtime()
  return tonumber(runtime.progress_by_task_id[task_id or api.get_current_task_id()] or 0) or 0
end

function api.get_tracker_state()
  local runtime = ensure_runtime()
  return {
    auto_track_enabled = runtime.auto_track_enabled ~= false,
    pinned_task_id = runtime.pinned_task_id,
    snapshot_summary = runtime.snapshot_summary,
  }
end
```

- [ ] **Step 4: Add readable reward text mapping and player-facing progress text**

```lua
local DISPLAY_KEY_MAP = {
  kill_count = '杀敌数',
  kill_per_sec = '每秒杀敌',
  kill_material_pct = '杀敌木材',
}

local function get_reward_display_name(line)
  return ATTR_KEY_MAP[line.key]
    or RUNTIME_ATTR_KEY_MAP[line.key]
    or DISPLAY_KEY_MAP[line.key]
    or tostring(line.key or '?')
end

local function build_reward_line_text(line)
  local name = get_reward_display_name(line)
  local raw_number = tonumber(line.value) or 0
  local value_text = tostring(round_number and math.abs(raw_number % 1) <= 0.0001 and round_number(raw_number) or line.value)
  if raw_number >= 0 then
    value_text = '+' .. value_text
  end
  return string.format('%s %s', name, value_text)
end

function api.get_current_task_summary()
  local task = api.get_current_task()
  if not task then
    return nil
  end
  local current_count = math.min(api.get_current_progress_count(task.id), task.target_count or 0)
  local reward_line_texts = {}
  for _, line in ipairs(task.reward_lines or {}) do
    reward_line_texts[#reward_line_texts + 1] = build_reward_line_text(line)
  end
  return {
    id = task.id,
    title_text = task.title_text,
    objective_text = task.objective_text,
    current_count = current_count,
    target_count = task.target_count or 0,
    progress_text = string.format('%s(%d/%d)', task.objective_text or '任务', current_count, task.target_count or 0),
    reward_lines = clone_list(task.reward_lines),
    reward_line_texts = reward_line_texts,
  }
end
```

- [ ] **Step 5: Run the runtime smoke test again**

Run: `lua maps/EntryMap/script/tools/test_mainline_task_runtime_smoke.lua`

Expected: PASS with `[OK] mainline task runtime smoke passed`

- [ ] **Step 6: Commit**

```bash
git add maps/EntryMap/script/runtime/mainline_tasks.lua maps/EntryMap/script/tools/test_mainline_task_runtime_smoke.lua
git commit -m "feat: add mainline task panel runtime summary"
```

### Task 2: Wire HUD Refresh And Checkbox Behavior

**Files:**
- Modify: `maps/EntryMap/script/runtime/boot.lua`
- Modify: `maps/EntryMap/script/ui/runtime_hud_v2.lua`
- Create: `maps/EntryMap/script/tools/test_runtime_hud_task_panel_static.py`

- [ ] **Step 1: Write the HUD static test**

```python
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
HUD_PATH = ROOT / "script" / "ui" / "runtime_hud_v2.lua"

content = HUD_PATH.read_text(encoding="utf-8")
assert "runtime_hud.tracker_title" in content
assert "runtime_hud.tracker_objective" in content
assert "runtime_hud.auto_task_checkbox" in content
assert "get_mainline_task_summary" in content
assert "toggle_mainline_task_auto_track" in content
```

- [ ] **Step 2: Run the HUD static test to verify it fails**

Run: `python maps/EntryMap/script/tools/test_runtime_hud_task_panel_static.py`

Expected: FAIL because the runtime HUD does not yet refresh the tracker panel or toggle auto tracking.

- [ ] **Step 3: Expose tracker helpers from boot**

```lua
runtime_hud_system = require('ui.runtime_hud_panel1_top').create({
  STATE = STATE,
  CONFIG = CONFIG,
  y3 = y3,
  get_player = get_player,
  get_mainline_task_summary = function()
    return mainline_task_system.get_current_task_summary()
  end,
  get_mainline_task_tracker_state = function()
    return mainline_task_system.get_tracker_state()
  end,
  toggle_mainline_task_auto_track = function()
    return mainline_task_system.toggle_auto_track()
  end,
})
```

- [ ] **Step 4: Refresh tracker texts and bind the checkbox in `runtime_hud_v2.lua`**

```lua
local function refresh_mainline_task_panel(runtime_hud)
  local summary = env.get_mainline_task_summary and env.get_mainline_task_summary() or nil
  local tracker = env.get_mainline_task_tracker_state and env.get_mainline_task_tracker_state() or { auto_track_enabled = true }

  if runtime_hud.tracker_title then
    runtime_hud.tracker_title:set_text(summary and summary.title_text or '主线任务')
  end
  if runtime_hud.tracker_objective then
    runtime_hud.tracker_objective:set_text(summary and ('任务：' .. tostring(summary.objective_text or '')) or '任务：暂无')
  end
  if runtime_hud.tracker_progress then
    runtime_hud.tracker_progress:set_text(summary and summary.progress_text or '当前无主线任务')
  end
  if runtime_hud.tracker_reward then
    runtime_hud.tracker_reward:set_text(summary and table.concat(summary.reward_line_texts or {}, '\n') or '奖励：暂无')
  end
  if runtime_hud.tracker_hint then
    runtime_hud.tracker_hint:set_text(tracker.auto_track_enabled and '自动任务已开启' or '自动任务已关闭')
  end
  if runtime_hud.auto_task_checkbox then
    runtime_hud.auto_task_checkbox:set_checked(tracker.auto_track_enabled == true)
  end
end
```

- [ ] **Step 5: Attach the checkbox event only once**

```lua
if runtime_hud.auto_task_checkbox and not runtime_hud.auto_task_checkbox_bound then
  runtime_hud.auto_task_checkbox_bound = true
  runtime_hud.auto_task_checkbox:add_fast_event('左键-点击', function()
    if env.toggle_mainline_task_auto_track then
      env.toggle_mainline_task_auto_track()
      refresh_runtime_hud()
    end
  end)
end
```

- [ ] **Step 6: Run the HUD static test**

Run: `python maps/EntryMap/script/tools/test_runtime_hud_task_panel_static.py`

Expected: PASS with no output

- [ ] **Step 7: Commit**

```bash
git add maps/EntryMap/script/runtime/boot.lua maps/EntryMap/script/ui/runtime_hud_v2.lua maps/EntryMap/script/tools/test_runtime_hud_task_panel_static.py
git commit -m "feat: wire mainline task panel into runtime hud"
```

### Task 3: Keep Panel1 Top Compatible With The Right Tracker

**Files:**
- Modify: `maps/EntryMap/script/ui/runtime_hud_panel1_top.lua`
- Modify: `maps/EntryMap/script/tools/test_runtime_hud_panel1_top_binding_static.py`

- [ ] **Step 1: Update the static test to enforce the new behavior**

```python
assert "runtime_hud.right_tracker_panel:set_visible(false)" not in content
assert "right_tracker_panel" in content
```

- [ ] **Step 2: Run the static test to verify it fails**

Run: `python maps/EntryMap/script/tools/test_runtime_hud_panel1_top_binding_static.py`

Expected: FAIL because the file currently hides `right_tracker_panel`.

- [ ] **Step 3: Remove the hard hide from `runtime_hud_panel1_top.lua`**

```lua
if runtime_hud.left_shortcut_panel and not runtime_hud.left_shortcut_panel:is_removed() then
  runtime_hud.left_shortcut_panel:set_visible(false)
end
-- Keep right_tracker_panel visible; it is the approved in-battle task card.
```

- [ ] **Step 4: Re-run the static test**

Run: `python maps/EntryMap/script/tools/test_runtime_hud_panel1_top_binding_static.py`

Expected: PASS with no output

- [ ] **Step 5: Commit**

```bash
git add maps/EntryMap/script/ui/runtime_hud_panel1_top.lua maps/EntryMap/script/tools/test_runtime_hud_panel1_top_binding_static.py
git commit -m "fix: keep mainline task panel visible with panel1 top hud"
```

### Task 4: Restyle The Right Tracker Panel Asset

**Files:**
- Modify: `maps/EntryMap/ui/GameHUD.json`
- Modify: `maps/EntryMap/ui_tree/GameHUD_Tree.json`
- Modify: `maps/EntryMap/script/tools/test_gamehud_legacy_nodes_removed.py`

- [ ] **Step 1: Snapshot the current right tracker node names before editing**

```python
import json
from pathlib import Path

data = json.loads(Path("maps/EntryMap/ui/GameHUD.json").read_text(encoding="utf-8"))
assert "right_tracker_panel" in Path("maps/EntryMap/ui_tree/GameHUD_Tree.json").read_text(encoding="utf-8")
```

- [ ] **Step 2: Run the existing HUD node test**

Run: `python maps/EntryMap/script/tools/test_gamehud_legacy_nodes_removed.py`

Expected: PASS before the asset edit, proving the baseline HUD JSON is valid.

- [ ] **Step 3: Update `GameHUD.json` right tracker layout**

```json
{
  "name": "right_tracker_panel",
  "children": [
    { "name": "right_tracker_panel_bg" },
    { "name": "tracker_title" },
    { "name": "tracker_objective" },
    { "name": "tracker_progress" },
    { "name": "tracker_reward" },
    { "name": "tracker_hint" },
    { "name": "auto_task_checkbox" },
    { "name": "auto_task_label" }
  ]
}
```

Edit the positions, colors, font sizes, and panel background so the result matches the approved black-card layout with the cyan divider and the bottom `自动任务` row.

- [ ] **Step 4: Regenerate the UI tree**

Run: `python .codemaker/skills/y3-ui-pipeline/gen_ui_tree.py "c:\Y3TD\Y3GPT\y3td\maps\EntryMap"`

Expected: `maps/EntryMap/ui_tree/GameHUD_Tree.json` updates with the same right tracker node names still present.

- [ ] **Step 5: Run the HUD node test again**

Run: `python maps/EntryMap/script/tools/test_gamehud_legacy_nodes_removed.py`

Expected: PASS after the asset change.

- [ ] **Step 6: Commit**

```bash
git add maps/EntryMap/ui/GameHUD.json maps/EntryMap/ui_tree/GameHUD_Tree.json
git commit -m "feat: restyle mainline task tracker panel"
```

### Task 5: Full Verification

**Files:**
- Test: `maps/EntryMap/script/tools/test_mainline_task_runtime_smoke.lua`
- Test: `maps/EntryMap/script/tools/test_runtime_hud_task_panel_static.py`
- Test: `maps/EntryMap/script/tools/test_runtime_hud_panel1_top_binding_static.py`
- Test: `maps/EntryMap/script/tools/test_gamehud_legacy_nodes_removed.py`

- [ ] **Step 1: Run the runtime smoke**

Run: `lua maps/EntryMap/script/tools/test_mainline_task_runtime_smoke.lua`

Expected: `[OK] mainline task runtime smoke passed`

- [ ] **Step 2: Run the HUD task panel static test**

Run: `python maps/EntryMap/script/tools/test_runtime_hud_task_panel_static.py`

Expected: no output and exit code 0

- [ ] **Step 3: Run the panel1 top binding static test**

Run: `python maps/EntryMap/script/tools/test_runtime_hud_panel1_top_binding_static.py`

Expected: no output and exit code 0

- [ ] **Step 4: Run the HUD node integrity test**

Run: `python maps/EntryMap/script/tools/test_gamehud_legacy_nodes_removed.py`

Expected: no output and exit code 0

- [ ] **Step 5: Review the diff and commit the integrated feature**

```bash
git status --short
git diff -- maps/EntryMap/script/runtime/mainline_tasks.lua maps/EntryMap/script/runtime/boot.lua maps/EntryMap/script/ui/runtime_hud_v2.lua maps/EntryMap/script/ui/runtime_hud_panel1_top.lua maps/EntryMap/ui/GameHUD.json maps/EntryMap/ui_tree/GameHUD_Tree.json maps/EntryMap/script/tools/test_mainline_task_runtime_smoke.lua maps/EntryMap/script/tools/test_runtime_hud_task_panel_static.py maps/EntryMap/script/tools/test_runtime_hud_panel1_top_binding_static.py
git commit -m "feat: add in-battle mainline task panel"
```
