# EntryMap Core HUD Redesign Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 在编辑器内重建 EntryMap 常驻主 HUD 骨架，并把现有波次、Boss、资源、挑战、成长入口等 runtime HUD 数据迁移到新的静态节点上。

**Architecture:** 保留 `script/ui/runtime_hud.lua` 作为业务数据和交互状态层，把常驻 HUD 的容器与命名节点落回 `ui/GameHUD.json`。新增一个小型节点解析模块把编辑器节点路径收拢成结构化引用，动态决策面板继续保留为 Lua 动态创建层，不和常驻骨架混在一起。

**Tech Stack:** Y3 编辑器 UI JSON、Lua UI runtime、PowerShell、Python 辅助脚本、Y3 Helper Lua 执行器

---

## File Map

- Create: `script/tools/build_gamehud_tree.py`
  - 从 `ui/GameHUD.json` 生成简化节点树，替代当前不可见的外部 skill 脚本依赖。
- Create: `script/tools/hud_smoke.lua`
  - 进入游戏后检查关键 HUD 节点是否存在，作为最小运行时烟雾验证。
- Create: `script/ui/runtime_hud_nodes.lua`
  - 统一解析 `GameHUD` 下的新节点路径，并封装常用的文本、显隐、填充更新入口。
- Modify: `ui/GameHUD.json`
  - 编辑器主 HUD 骨架，新增 `hud_root`、顶部、左侧、右侧、底部、挑战入口带等命名节点。
- Modify: `script/ui/runtime_hud.lua`
  - 从“动态创建三块永久 HUD”改为“查找编辑器节点 + 填充数据”，保留决策面板动态创建逻辑。
- Modify: `script/ui/runtime_hud_layout.lua`
  - 删除顶部/左侧/底部的静态像素布局常量，仅保留动态决策面板与极少数回退尺寸。
- Modify: `script/ui/res.lua`
  - 如需要，为静态骨架复用的底板和按钮补充语义资源槽。
- Modify: `script/ui/skin.lua`
  - 为迁移后的主按钮和次按钮补齐样式槽，减少 `runtime_hud.lua` 里硬编码图片引用。
- Modify: `script/docs/开发进度与计划/04-UI与交互反馈/UI与交互反馈.md`
  - 实现完成后更新 HUD 状态说明，避免文档继续写成“纯动态挂载”。
- Generated: `ui_tree/GameHUD_Tree.json`
  - 由 `build_gamehud_tree.py` 生成，只读，不手改。

## Task 1: Add Local HUD Tree Builder And Smoke Tooling

**Files:**
- Create: `script/tools/build_gamehud_tree.py`
- Create: `script/tools/hud_smoke.lua`
- Create: `ui_tree/`

- [ ] **Step 1: Create the local `GameHUD` tree builder**

```python
#!/usr/bin/env python
import json
import os
import sys


def simplify(node):
    if not isinstance(node, dict):
        return None
    return {
        "name": node.get("name"),
        "uid": node.get("uid"),
        "type": node.get("type"),
        "children": [
            child_tree
            for child_tree in (simplify(child) for child in node.get("children", []))
            if child_tree is not None
        ],
    }


def main(src_path, dst_path):
    with open(src_path, "r", encoding="utf-8") as src_file:
        data = json.load(src_file)

    tree = simplify(data)
    os.makedirs(os.path.dirname(dst_path), exist_ok=True)

    with open(dst_path, "w", encoding="utf-8") as dst_file:
        json.dump(tree, dst_file, ensure_ascii=False, indent=2)
        dst_file.write("\n")

    print(f"[OK] wrote {dst_path}")


if __name__ == "__main__":
    if len(sys.argv) != 3:
        raise SystemExit(
            "Usage: python script/tools/build_gamehud_tree.py ui/GameHUD.json ui_tree/GameHUD_Tree.json"
        )
    main(sys.argv[1], sys.argv[2])
```

- [ ] **Step 2: Run the tree builder against the current HUD file**

Run:

```powershell
python script/tools/build_gamehud_tree.py ui/GameHUD.json ui_tree/GameHUD_Tree.json
```

Expected:

```text
[OK] wrote ui_tree/GameHUD_Tree.json
```

- [ ] **Step 3: Create the HUD smoke script**

```lua
-- script/tools/hud_smoke.lua
local player = y3.player(1)
local required_paths = {
  'GameHUD.hud_root',
  'GameHUD.hud_root.top_battle_cluster',
  'GameHUD.hud_root.left_shortcut_panel',
  'GameHUD.hud_root.right_tracker_panel',
  'GameHUD.hud_root.challenge_strip',
  'GameHUD.hud_root.bottom_action_bar',
  'GameHUD.hud_root.bottom_action_bar.skill_hotbar',
  'GameHUD.hud_root.bottom_action_bar.primary_action_cluster',
  'GameHUD.hud_root.bottom_action_bar.secondary_action_cluster',
}

for _, path in ipairs(required_paths) do
  local ui = y3.ui.get_ui(player, path)
  if not ui then
    error('[HUD_SMOKE] missing ui path: ' .. path)
  end
end

print('[HUD_SMOKE] all required HUD nodes resolved')
```

- [ ] **Step 4: Verify the new tooling files exist and the builder output is tracked**

Run:

```powershell
Get-Item script/tools/build_gamehud_tree.py,script/tools/hud_smoke.lua,ui_tree/GameHUD_Tree.json | Select-Object FullName,Length
```

Expected:

```text
Three rows for build_gamehud_tree.py, hud_smoke.lua, and GameHUD_Tree.json
```

- [ ] **Step 5: Commit the tooling**

```bash
git add script/tools/build_gamehud_tree.py script/tools/hud_smoke.lua ui_tree/GameHUD_Tree.json
git commit -m "chore: add local HUD tree and smoke tooling"
```

## Task 2: Rebuild Top / Left / Right HUD Skeleton In `GameHUD.json`

**Files:**
- Modify: `ui/GameHUD.json`
- Generated: `ui_tree/GameHUD_Tree.json`

- [ ] **Step 1: Run a failing node-presence check for the top/left/right skeleton**

Run:

```powershell
$required = 'hud_root','top_battle_cluster','left_shortcut_panel','right_tracker_panel'
$missing = @()
foreach ($name in $required) {
  if (-not (Select-String -Path 'ui/GameHUD.json' -Pattern ('"name"\s*:\s*"' + [regex]::Escape($name) + '"') -Quiet)) {
    $missing += $name
  }
}
if ($missing.Count -gt 0) { throw ('Missing HUD nodes: ' + ($missing -join ', ')) }
'[OK] top/left/right skeleton present'
```

Expected: FAIL with `Missing HUD nodes: hud_root, top_battle_cluster, left_shortcut_panel, right_tracker_panel`

- [ ] **Step 2: Insert the semantic top/left/right HUD subtree into `ui/GameHUD.json`**

Add this subtree under the `GameHUD` root container instead of reusing anonymous legacy names:

```json
{
  "name": "hud_root",
  "type": 7,
  "children": [
    {
      "name": "top_battle_cluster",
      "type": 7,
      "children": [
        { "name": "stage_chip", "type": 7, "children": [{ "name": "stage_text", "type": 3, "children": [] }] },
        { "name": "timer_block", "type": 7, "children": [{ "name": "timer_text", "type": 3, "children": [] }, { "name": "wave_status_text", "type": 3, "children": [] }] },
        { "name": "wave_medallion", "type": 7, "children": [{ "name": "wave_title", "type": 3, "children": [] }] },
        { "name": "boss_capsule", "type": 7, "children": [{ "name": "boss_name", "type": 3, "children": [] }, { "name": "boss_state", "type": 3, "children": [] }] },
        {
          "name": "resource_cluster",
          "type": 7,
          "children": [
            { "name": "gold_card", "type": 7, "children": [{ "name": "gold_value", "type": 3, "children": [] }] },
            { "name": "wood_card", "type": 7, "children": [{ "name": "wood_value", "type": 3, "children": [] }] },
            { "name": "skill_card", "type": 7, "children": [{ "name": "skill_value", "type": 3, "children": [] }] },
            { "name": "challenge_card", "type": 7, "children": [{ "name": "challenge_value", "type": 3, "children": [] }] }
          ]
        }
      ]
    },
    {
      "name": "left_shortcut_panel",
      "type": 7,
      "children": [
        { "name": "exit_button", "type": 1, "children": [] },
        { "name": "settings_button", "type": 1, "children": [] },
        { "name": "shortcut_title", "type": 3, "children": [] },
        { "name": "shortcut_list", "type": 3, "children": [] }
      ]
    },
    {
      "name": "right_tracker_panel",
      "type": 7,
      "children": [
        { "name": "tracker_title", "type": 3, "children": [] },
        { "name": "tracker_objective", "type": 3, "children": [] },
        { "name": "tracker_progress", "type": 3, "children": [] },
        { "name": "tracker_reward", "type": 3, "children": [] },
        { "name": "tracker_hint", "type": 3, "children": [] },
        { "name": "auto_task_checkbox", "type": 46, "children": [] }
      ]
    }
  ]
}
```

- [ ] **Step 3: Validate the edited JSON and rebuild the node tree**

Run:

```powershell
Get-Content -Raw 'ui/GameHUD.json' | ConvertFrom-Json | Out-Null
python script/tools/build_gamehud_tree.py ui/GameHUD.json ui_tree/GameHUD_Tree.json
```

Expected:

```text
[OK] wrote ui_tree/GameHUD_Tree.json
```

- [ ] **Step 4: Re-run the top/left/right node-presence check**

Run the same PowerShell block from Step 1.

Expected:

```text
[OK] top/left/right skeleton present
```

- [ ] **Step 5: Commit the top/left/right skeleton**

```bash
git add ui/GameHUD.json ui_tree/GameHUD_Tree.json
git commit -m "feat: add top left right HUD skeleton"
```

## Task 3: Add Challenge Strip And Bottom Action Bar Skeleton

**Files:**
- Modify: `ui/GameHUD.json`
- Generated: `ui_tree/GameHUD_Tree.json`

- [ ] **Step 1: Run a failing node-presence check for the challenge strip and bottom action bar**

Run:

```powershell
$required = 'challenge_strip','gold_trial_button','wood_trial_button','exp_trial_button','treasure_trial_button','bottom_action_bar','hero_core_panel','skill_hotbar','skill_slot_1','skill_slot_2','skill_slot_3','skill_slot_4','primary_action_cluster','secondary_action_cluster','treasure_button','focus_clear_button','swallowed_list_button','exp_rail'
$missing = @()
foreach ($name in $required) {
  if (-not (Select-String -Path 'ui/GameHUD.json' -Pattern ('"name"\s*:\s*"' + [regex]::Escape($name) + '"') -Quiet)) {
    $missing += $name
  }
}
if ($missing.Count -gt 0) { throw ('Missing HUD nodes: ' + ($missing -join ', ')) }
'[OK] challenge strip and bottom bar present'
```

Expected: FAIL with the listed node names missing.

- [ ] **Step 2: Add the challenge strip and bottom action subtree**

Append this subtree inside `hud_root.children`:

```json
{
  "name": "challenge_strip",
  "type": 7,
  "children": [
    { "name": "gold_trial_button", "type": 1, "children": [] },
    { "name": "wood_trial_button", "type": 1, "children": [] },
    { "name": "exp_trial_button", "type": 1, "children": [] },
    { "name": "treasure_trial_button", "type": 1, "children": [] }
  ]
}
```

```json
{
  "name": "bottom_action_bar",
  "type": 7,
  "children": [
    {
      "name": "hero_core_panel",
      "type": 7,
      "children": [
        { "name": "hero_portrait", "type": 4, "children": [] },
        { "name": "hero_name", "type": 3, "children": [] },
        { "name": "hero_progress_text", "type": 3, "children": [] },
        { "name": "hero_hp_bg", "type": 4, "children": [] },
        { "name": "hero_hp_fill", "type": 4, "children": [] },
        { "name": "hero_hp_text", "type": 3, "children": [] }
      ]
    },
    {
      "name": "skill_hotbar",
      "type": 7,
      "children": [
        { "name": "skill_slot_1", "type": 7, "children": [{ "name": "skill_slot_1_text", "type": 3, "children": [] }] },
        { "name": "skill_slot_2", "type": 7, "children": [{ "name": "skill_slot_2_text", "type": 3, "children": [] }] },
        { "name": "skill_slot_3", "type": 7, "children": [{ "name": "skill_slot_3_text", "type": 3, "children": [] }] },
        { "name": "skill_slot_4", "type": 7, "children": [{ "name": "skill_slot_4_text", "type": 3, "children": [] }] }
      ]
    },
    {
      "name": "primary_action_cluster",
      "type": 7,
      "children": [
        { "name": "skill_button", "type": 1, "children": [] },
        { "name": "bond_button", "type": 1, "children": [] }
      ]
    },
    {
      "name": "secondary_action_cluster",
      "type": 7,
      "children": [
        { "name": "treasure_button", "type": 1, "children": [] },
        { "name": "focus_clear_button", "type": 1, "children": [] },
        { "name": "swallowed_list_button", "type": 1, "children": [] }
      ]
    },
    {
      "name": "exp_rail",
      "type": 7,
      "children": [
        { "name": "exp_bg", "type": 4, "children": [] },
        { "name": "exp_fill", "type": 4, "children": [] },
        { "name": "exp_text", "type": 3, "children": [] }
      ]
    }
  ]
}
```

- [ ] **Step 3: Validate the JSON again and rebuild `GameHUD_Tree.json`**

Run:

```powershell
Get-Content -Raw 'ui/GameHUD.json' | ConvertFrom-Json | Out-Null
python script/tools/build_gamehud_tree.py ui/GameHUD.json ui_tree/GameHUD_Tree.json
```

Expected:

```text
[OK] wrote ui_tree/GameHUD_Tree.json
```

- [ ] **Step 4: Launch the game, auto-enter, and run the HUD smoke script**

Run:

```powershell
powershell -ExecutionPolicy Bypass -File script/tools/launch_game.ps1
@'
import os, sys
sys.path.insert(0, os.path.join(os.getcwd(), 'script', 'tools'))
from lua_executor import execute_lua_file, print_result
for name in ('quick_enter', 'hud_smoke'):
    result = execute_lua_file(name, timeout=20)
    print_result(result, verbose=True)
    if not result.success:
        raise SystemExit(1)
'@ | python -
```

Expected:

```text
[HUD_SMOKE] all required HUD nodes resolved
```

- [ ] **Step 5: Commit the completed editor skeleton**

```bash
git add ui/GameHUD.json ui_tree/GameHUD_Tree.json
git commit -m "feat: add bottom action bar HUD skeleton"
```

## Task 4: Add Editor Node Resolver And Migrate Top / Left / Right Runtime Binding

**Files:**
- Create: `script/ui/runtime_hud_nodes.lua`
- Modify: `script/ui/runtime_hud.lua`

- [ ] **Step 1: Run a failing module-load check for `ui.runtime_hud_nodes`**

Run:

```powershell
@'
import os, sys
sys.path.insert(0, os.path.join(os.getcwd(), 'script', 'tools'))
from lua_executor import execute_lua, print_result
result = execute_lua("require 'ui.runtime_hud_nodes'", timeout=10)
print_result(result, verbose=True)
raise SystemExit(0 if result.success else 1)
'@ | python -
```

Expected: FAIL with `module 'ui.runtime_hud_nodes' not found`

- [ ] **Step 2: Create `script/ui/runtime_hud_nodes.lua`**

```lua
local M = {}

local REQUIRED_PATHS = {
  root = 'GameHUD.hud_root',
  top = 'GameHUD.hud_root.top_battle_cluster',
  left = 'GameHUD.hud_root.left_shortcut_panel',
  right = 'GameHUD.hud_root.right_tracker_panel',
  challenge_strip = 'GameHUD.hud_root.challenge_strip',
  bottom = 'GameHUD.hud_root.bottom_action_bar',
  stage_text = 'GameHUD.hud_root.top_battle_cluster.stage_chip.stage_text',
  timer_text = 'GameHUD.hud_root.top_battle_cluster.timer_block.timer_text',
  wave_status_text = 'GameHUD.hud_root.top_battle_cluster.timer_block.wave_status_text',
  wave_title = 'GameHUD.hud_root.top_battle_cluster.wave_medallion.wave_title',
  boss_name = 'GameHUD.hud_root.top_battle_cluster.boss_capsule.boss_name',
  boss_state = 'GameHUD.hud_root.top_battle_cluster.boss_capsule.boss_state',
  gold_value = 'GameHUD.hud_root.top_battle_cluster.resource_cluster.gold_card.gold_value',
  wood_value = 'GameHUD.hud_root.top_battle_cluster.resource_cluster.wood_card.wood_value',
  skill_value = 'GameHUD.hud_root.top_battle_cluster.resource_cluster.skill_card.skill_value',
  challenge_value = 'GameHUD.hud_root.top_battle_cluster.resource_cluster.challenge_card.challenge_value',
  shortcut_title = 'GameHUD.hud_root.left_shortcut_panel.shortcut_title',
  shortcut_list = 'GameHUD.hud_root.left_shortcut_panel.shortcut_list',
  tracker_title = 'GameHUD.hud_root.right_tracker_panel.tracker_title',
  tracker_objective = 'GameHUD.hud_root.right_tracker_panel.tracker_objective',
  tracker_progress = 'GameHUD.hud_root.right_tracker_panel.tracker_progress',
  tracker_reward = 'GameHUD.hud_root.right_tracker_panel.tracker_reward',
  tracker_hint = 'GameHUD.hud_root.right_tracker_panel.tracker_hint',
}

local function find_ui(player, y3, path)
  local ok, ui = pcall(y3.ui.get_ui, player, path)
  if not ok or not ui then
    return nil, ('Missing HUD node: %s'):format(path)
  end
  return ui
end

function M.resolve(player, y3)
  local refs = {}
  for key, path in pairs(REQUIRED_PATHS) do
    local ui, err = find_ui(player, y3, path)
    if not ui then
      return nil, err
    end
    refs[key] = ui
  end
  return refs
end

function M.set_text(node, text)
  if node then
    node:set_text(text or '')
  end
end

function M.set_visible(node, visible)
  if node then
    node:set_visible(visible == true)
  end
end

return M
```

- [ ] **Step 3: Refactor `script/ui/runtime_hud.lua` so the permanent HUD uses editor nodes**

At the top of the file, add the new module import:

```lua
local HudNodes = require 'ui.runtime_hud_nodes'
```

Replace the permanent HUD creation block with editor-node resolution, and keep only the dynamic decision root creation:

```lua
local function is_hud_alive(runtime_hud)
  return runtime_hud
    and runtime_hud.root
    and not runtime_hud.root:is_removed()
    and (not runtime_hud.decision_root or not runtime_hud.decision_root:is_removed())
end

local function create_runtime_hud()
  local hud = get_hud_root()
  if not hud then
    return nil
  end

  if is_hud_alive(STATE.runtime_hud) then
    refresh_runtime_hud()
    return STATE.runtime_hud
  end

  local refs, err = HudNodes.resolve(env.get_player(), y3)
  if not refs then
    error(err)
  end

  local decision_root = create_panel(
    hud,
    0,
    0,
    scaled(layout.decision_panel.width, get_hud_scale(hud, y3)),
    scaled(layout.decision_panel.height, get_hud_scale(hud, y3)),
    { 9, 16, 27, 224 },
    { 28, 28, 28, 28 },
    9440,
    runtime_skin.decision_root
  )

  STATE.runtime_hud = {
    root = refs.root,
    top_root = refs.top,
    left_root = refs.left,
    right_root = refs.right,
    challenge_strip = refs.challenge_strip,
    bottom_root = refs.bottom,
    stage_text = refs.stage_text,
    timer_text = refs.timer_text,
    wave_status = refs.wave_status_text,
    wave_title = refs.wave_title,
    boss_name = refs.boss_name,
    boss_state = refs.boss_state,
    gold_value = refs.gold_value,
    wood_value = refs.wood_value,
    skill_value = refs.skill_value,
    challenge_value = refs.challenge_value,
    shortcut_title = refs.shortcut_title,
    shortcut_list = refs.shortcut_list,
    tracker_title = refs.tracker_title,
    tracker_objective = refs.tracker_objective,
    tracker_progress = refs.tracker_progress,
    tracker_reward = refs.tracker_reward,
    tracker_hint = refs.tracker_hint,
    decision_root = decision_root,
  }

  refresh_runtime_hud()
  return STATE.runtime_hud
end
```

Update `refresh_runtime_hud()` to write top/left/right values through `HudNodes.set_text(...)`:

```lua
HudNodes.set_text(runtime_hud.stage_text, get_stage_text())
HudNodes.set_text(runtime_hud.wave_title, get_wave_title_text())
HudNodes.set_text(runtime_hud.wave_status, get_wave_status_text())
HudNodes.set_text(runtime_hud.timer_text, string.format('战斗计时 %s', format_time(STATE.runtime_elapsed or 0)))
HudNodes.set_text(runtime_hud.gold_value, format_compact(STATE.resources and STATE.resources.gold or 0))
HudNodes.set_text(runtime_hud.wood_value, format_compact(STATE.resources and STATE.resources.wood or 0))
HudNodes.set_text(runtime_hud.skill_value, tostring(STATE.skill_points or 0))
HudNodes.set_text(runtime_hud.challenge_value, string.format('%d/%d', STATE.challenge_charges or 0, CONFIG.challenge_rules.max_charges or 0))
HudNodes.set_text(runtime_hud.shortcut_title, '快捷键')
HudNodes.set_text(runtime_hud.shortcut_list, 'F1 选中英雄\nF2 返回阵地\nF4 清除集火\nF 羁绊抽卡\nG 技能加点\nB 打开背包\nTAB 查看属性')
HudNodes.set_text(runtime_hud.tracker_title, get_stage_text())
HudNodes.set_text(runtime_hud.tracker_objective, STATE.active_wave and '清理当前波次敌人' or '等待本局开始')
HudNodes.set_text(runtime_hud.tracker_progress, get_wave_status_text())
HudNodes.set_text(runtime_hud.tracker_reward, get_challenge_summary_text())
HudNodes.set_text(runtime_hud.tracker_hint, ((STATE.skill_points or 0) > 0) and '按 G 消耗技能点' or '按 F 抽取羁绊')
```

- [ ] **Step 4: Launch the game and verify the migrated top/left/right layer does not throw runtime errors**

Run:

```powershell
powershell -ExecutionPolicy Bypass -File script/tools/launch_game.ps1
@'
import os, sys
sys.path.insert(0, os.path.join(os.getcwd(), 'script', 'tools'))
from lua_executor import execute_lua_file, print_result
for name in ('quick_enter', 'hud_smoke'):
    result = execute_lua_file(name, timeout=20)
    print_result(result, verbose=True)
    if not result.success:
        raise SystemExit(1)
'@ | python -
```

Expected:

```text
[HUD_SMOKE] all required HUD nodes resolved
```

- [ ] **Step 5: Commit the top/left/right runtime migration**

```bash
git add script/ui/runtime_hud_nodes.lua script/ui/runtime_hud.lua
git commit -m "feat: bind top left right HUD to editor nodes"
```

## Task 5: Bind Challenge Strip, Bottom Action Bar, Skill Slots, And EXP Rail

**Files:**
- Modify: `script/ui/runtime_hud_nodes.lua`
- Modify: `script/ui/runtime_hud.lua`
- Modify: `script/ui/runtime_hud_layout.lua`
- Modify: `script/ui/res.lua`
- Modify: `script/ui/skin.lua`

- [ ] **Step 1: Add the bottom node references to `runtime_hud_nodes.lua` and `runtime_hud.lua`**

Extend the resolver table with bottom-bar and challenge-strip paths:

```lua
gold_trial_button = 'GameHUD.hud_root.challenge_strip.gold_trial_button',
wood_trial_button = 'GameHUD.hud_root.challenge_strip.wood_trial_button',
exp_trial_button = 'GameHUD.hud_root.challenge_strip.exp_trial_button',
treasure_trial_button = 'GameHUD.hud_root.challenge_strip.treasure_trial_button',
hero_name = 'GameHUD.hud_root.bottom_action_bar.hero_core_panel.hero_name',
hero_progress_text = 'GameHUD.hud_root.bottom_action_bar.hero_core_panel.hero_progress_text',
hero_hp_fill = 'GameHUD.hud_root.bottom_action_bar.hero_core_panel.hero_hp_fill',
hero_hp_text = 'GameHUD.hud_root.bottom_action_bar.hero_core_panel.hero_hp_text',
skill_slot_1_text = 'GameHUD.hud_root.bottom_action_bar.skill_hotbar.skill_slot_1.skill_slot_1_text',
skill_slot_2_text = 'GameHUD.hud_root.bottom_action_bar.skill_hotbar.skill_slot_2.skill_slot_2_text',
skill_slot_3_text = 'GameHUD.hud_root.bottom_action_bar.skill_hotbar.skill_slot_3.skill_slot_3_text',
skill_slot_4_text = 'GameHUD.hud_root.bottom_action_bar.skill_hotbar.skill_slot_4.skill_slot_4_text',
skill_button = 'GameHUD.hud_root.bottom_action_bar.primary_action_cluster.skill_button',
bond_button = 'GameHUD.hud_root.bottom_action_bar.primary_action_cluster.bond_button',
treasure_button = 'GameHUD.hud_root.bottom_action_bar.secondary_action_cluster.treasure_button',
focus_clear_button = 'GameHUD.hud_root.bottom_action_bar.secondary_action_cluster.focus_clear_button',
swallowed_list_button = 'GameHUD.hud_root.bottom_action_bar.secondary_action_cluster.swallowed_list_button',
exp_fill = 'GameHUD.hud_root.bottom_action_bar.exp_rail.exp_fill',
exp_text = 'GameHUD.hud_root.bottom_action_bar.exp_rail.exp_text',
```

Mirror those refs into `STATE.runtime_hud` so `refresh_runtime_hud()` can update them directly.

- [ ] **Step 2: Replace the old challenge-button creation block with editor-button wiring**

In `runtime_hud.lua`, remove the `create_button(...)` calls for `gold_trial`, `wood_trial`, `exp_trial`, `treasure_trial`, `skill_button`, and `bond_button`, and replace them with editor-node callbacks:

```lua
local function bind_button(node, callback)
  if node and callback then
    node:add_fast_event('左键-点击', callback)
  end
end

bind_button(refs.gold_trial_button, function()
  env.try_start_challenge('gold_trial')
  refresh_runtime_hud()
end)
bind_button(refs.wood_trial_button, function()
  env.try_start_challenge('wood_trial')
  refresh_runtime_hud()
end)
bind_button(refs.exp_trial_button, function()
  env.try_start_challenge('exp_trial')
  refresh_runtime_hud()
end)
bind_button(refs.treasure_trial_button, function()
  env.try_treasure_entry()
  refresh_runtime_hud()
end)
bind_button(refs.skill_button, function()
  env.show_upgrade_choices()
  refresh_runtime_hud()
end)
bind_button(refs.bond_button, function()
  env.try_bond_draw()
  refresh_runtime_hud()
end)
bind_button(refs.treasure_button, function()
  if env.try_treasure_entry then
    env.try_treasure_entry()
  end
  refresh_runtime_hud()
end)
bind_button(refs.swallowed_list_button, function()
  if env.show_bond_progress then
    env.show_bond_progress()
  end
end)
```

- [ ] **Step 3: Fill hero, skill-slot, and EXP-rail runtime data**

Add focused helpers to `runtime_hud.lua`:

```lua
local function get_skill_slot_text(slot)
  local skill = STATE.attack_skill_state and STATE.attack_skill_state.slots and STATE.attack_skill_state.slots[slot] or nil
  if not skill then
    return string.format('%d号位\n未解锁', slot)
  end
  return string.format('%s\nLv%d', skill.name or ('技能' .. slot), skill.level or 1)
end

local function get_fill_ratio(current, total)
  if not total or total <= 0 then
    return 0
  end
  return math.max(0, math.min(1, (current or 0) / total))
end
```

Then update `refresh_runtime_hud()`:

```lua
HudNodes.set_text(runtime_hud.hero_name, (STATE.hero and STATE.hero:get_name()) or '英雄')
HudNodes.set_text(runtime_hud.hero_progress_text, env.get_hero_progress_text())
HudNodes.set_text(runtime_hud.hero_hp_text, get_hero_hp_text())
HudNodes.set_text(runtime_hud.skill_slot_1_text, get_skill_slot_text(1))
HudNodes.set_text(runtime_hud.skill_slot_2_text, get_skill_slot_text(2))
HudNodes.set_text(runtime_hud.skill_slot_3_text, get_skill_slot_text(3))
HudNodes.set_text(runtime_hud.skill_slot_4_text, get_skill_slot_text(4))
HudNodes.set_text(runtime_hud.exp_text, env.get_hero_progress_text())

local progress = STATE.hero_progress or {}
local exp_ratio = get_fill_ratio(progress.exp or 0, progress.exp_to_next or 0)
runtime_hud.exp_fill:set_ui_size(math.max(1, math.floor(320 * exp_ratio)), runtime_hud.exp_fill:get_height())

local hp_ratio = 0
if STATE.hero and STATE.hero:is_exist() then
  hp_ratio = get_fill_ratio(STATE.hero:get_hp(), STATE.hero:get_attr('最大生命'))
end
runtime_hud.hero_hp_fill:set_ui_size(math.max(1, math.floor(180 * hp_ratio)), runtime_hud.hero_hp_fill:get_height())
```

Treat unsupported secondary actions explicitly rather than silently pretending they work:

```lua
runtime_hud.focus_clear_button:set_text('集火 F4')
runtime_hud.focus_clear_button:set_button_enable(false)
runtime_hud.swallowed_list_button:set_text('链路 I')
runtime_hud.treasure_button:set_text((env.has_pending_treasure_choice and env.has_pending_treasure_choice()) and '宝物 继续' or '宝物')
```

- [ ] **Step 4: Trim `runtime_hud_layout.lua` down to the dynamic overlay data and add any missing style slots**

Keep only the decision overlay metrics in `script/ui/runtime_hud_layout.lua`:

```lua
local M = {}

M.decision_panel = {
  width = 1040,
  height = 246,
  percent_y = 61,
  badge_width = 64,
  badge_height = 20,
  option_width = 312,
  option_height = 126,
  option_y = 44,
  option_x = { 22, 364, 706 },
}

return M
```

If `res.lua` or `skin.lua` need explicit secondary-button or editor-frame slots, add them there instead of hardcoding image ids in `runtime_hud.lua`.

- [ ] **Step 5: Launch, auto-enter, smoke-test, and visually verify the migrated bottom layer**

Run:

```powershell
powershell -ExecutionPolicy Bypass -File script/tools/launch_game.ps1
@'
import os, sys
sys.path.insert(0, os.path.join(os.getcwd(), 'script', 'tools'))
from lua_executor import execute_lua_file, print_result
for name in ('quick_enter', 'hud_smoke'):
    result = execute_lua_file(name, timeout=20)
    print_result(result, verbose=True)
    if not result.success:
        raise SystemExit(1)
'@ | python -
```

Then manually confirm in the running game window:

- 顶部只剩一个新的中轴 HUD，不再出现旧的三块漂浮条
- 左侧快捷键面板可见
- 右侧追踪器可见
- 底部角色区出现英雄名、血量、四个技能槽、`技能 G`、`羁绊 F`
- 左下挑战入口带出现四个试炼按钮

Commit:

```bash
git add script/ui/runtime_hud.lua script/ui/runtime_hud_layout.lua script/ui/res.lua script/ui/skin.lua script/ui/runtime_hud_nodes.lua
git commit -m "feat: migrate bottom HUD bindings to editor nodes"
```

## Task 6: Update Progress Docs And Run Final Verification

**Files:**
- Modify: `script/docs/开发进度与计划/04-UI与交互反馈/UI与交互反馈.md`
- Generated: `ui_tree/GameHUD_Tree.json`

- [ ] **Step 1: Update the HUD progress doc to describe the new hybrid architecture**

Replace the old “纯动态挂载 `GameHUD`”表述 with a concrete note that the permanent HUD is now editor-authored and Lua-bound:

```md
- 主 HUD 已改为“编辑器骨架 + Lua 数据绑定”的混合结构。
- `ui/GameHUD.json` 承载顶部战斗栏、左侧快捷提示、右侧目标追踪、底部角色操作区与挑战入口带。
- `script/ui/runtime_hud.lua` 继续负责波次、Boss、资源、成长按钮、挑战状态与待选恢复逻辑。
- 中央三选一决策层仍保持 Lua 动态创建，不和常驻 HUD 结构混写。
```

- [ ] **Step 2: Rebuild the node tree one last time**

Run:

```powershell
python script/tools/build_gamehud_tree.py ui/GameHUD.json ui_tree/GameHUD_Tree.json
```

Expected:

```text
[OK] wrote ui_tree/GameHUD_Tree.json
```

- [ ] **Step 3: Run the final syntax and JSON validation pass**

Run:

```powershell
Get-Content -Raw 'ui/GameHUD.json' | ConvertFrom-Json | Out-Null
git diff --check
```

Expected:

```text
No JSON parse errors and no whitespace errors
```

- [ ] **Step 4: Run the final in-game smoke pass**

Run:

```powershell
powershell -ExecutionPolicy Bypass -File script/tools/launch_game.ps1
@'
import os, sys
sys.path.insert(0, os.path.join(os.getcwd(), 'script', 'tools'))
from lua_executor import execute_lua_file, print_result
for name in ('quick_enter', 'hud_smoke'):
    result = execute_lua_file(name, timeout=20)
    print_result(result, verbose=True)
    if not result.success:
        raise SystemExit(1)
'@ | python -
```

Expected:

```text
[HUD_SMOKE] all required HUD nodes resolved
```

- [ ] **Step 5: Commit the finished migration**

```bash
git add ui/GameHUD.json ui_tree/GameHUD_Tree.json script/tools/build_gamehud_tree.py script/tools/hud_smoke.lua script/ui/runtime_hud.lua script/ui/runtime_hud_layout.lua script/ui/runtime_hud_nodes.lua script/ui/res.lua script/ui/skin.lua script/docs/开发进度与计划/04-UI与交互反馈/UI与交互反馈.md
git commit -m "feat: migrate core HUD to editor-authored layout"
```
