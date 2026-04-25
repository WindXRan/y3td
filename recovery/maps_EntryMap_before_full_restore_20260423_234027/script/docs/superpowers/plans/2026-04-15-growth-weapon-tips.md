# Growth Weapon Tips Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add one shared growth-weapon tip payload and show it from both the bottom HUD growth-weapon slot and the hero item-bar growth-weapon item.

**Architecture:** Keep growth-weapon state and tip payload construction in `runtime/gear_upgrades.lua`, expose it through `runtime/boot.lua`, and render it through a dedicated `ui/growth_weapon_tip_panel.lua` that both HUD hover and item-bar hover call into. Read current direct stat bonuses from Y3 item-type APIs (`y3.item.attr_pick_by_key` and `y3.item.get_attribute_by_key`) so the runtime does not depend on raw editor JSON files.

**Tech Stack:** Lua 5.4, Y3 runtime APIs, existing runtime HUD modules, local UI hover events, smoke/static tests in `tools/`.

---

## File Map

- Modify: `maps/EntryMap/script/runtime/gear_upgrades.lua`
  - Add shared growth-weapon tip payload builder and item attribute formatting helpers.
- Modify: `maps/EntryMap/script/runtime/boot.lua`
  - Expose growth-weapon tip payload builder to UI systems.
- Modify: `maps/EntryMap/script/ui/runtime_hud.lua`
  - Create the growth-weapon HUD slot if needed, populate icon/text, and wire hover events.
- Create: `maps/EntryMap/script/ui/growth_weapon_tip_panel.lua`
  - Render one shared tip panel for both HUD and item-bar hover.
- Create: `maps/EntryMap/script/ui/growth_weapon_item_tip.lua`
  - Bind local item-bar hover events and route them to the shared tip panel.
- Modify: `maps/EntryMap/script/ui/runtime_hud_panel1_top.lua`
  - Pass tip-panel hooks through the top-level HUD wrapper if needed.
- Modify: `maps/EntryMap/script/tools/test_runtime_gear_upgrades_smoke.py`
  - Add payload assertions.
- Create: `maps/EntryMap/script/tools/test_growth_weapon_tip_payload_smoke.lua`
  - Cover direct attr lines, cost text, affix lines.
- Create: `maps/EntryMap/script/tools/test_growth_weapon_item_tip_static.py`
  - Cover item-bar binding file shape and expected slot coverage.
- Modify: `maps/EntryMap/script/tools/test_runtime_hud_skill_slot_static.py`
  - Extend to cover growth-weapon HUD slot wiring if this is the closest existing HUD static smoke.

### Runtime Contracts

- `runtime.gear_upgrades.build_tip_payload(state, slot, config)` returns:

```lua
{
  slot = 'weapon',
  item_key = 201390082,
  icon_res = y3.item.get_icon_id_by_key(201390082),
  title_text = '洪荒之刃',
  subtitle_text = '成长武器 Lv.1',
  cost_text = '升级所需：100 金币',
  attr_title_text = '当前属性增幅',
  attr_lines = { '物理攻击 +31', '暴击率 +25%' },
  affix_title_text = '当前词缀',
  affix_lines = { '暂无词缀' },
}
```

- `ui/growth_weapon_tip_panel.lua` exports:

```lua
return {
  show_for_anchor = function(anchor_ui, payload) end,
  hide = function() end,
}
```

- `ui/growth_weapon_item_tip.lua` exports:

```lua
return {
  bind = function() end,
  refresh = function() end,
  hide = function() end,
}
```

### Allowed Direct Attribute Keys

Start with a narrow allowlist only:

```lua
local DIRECT_ATTR_KEYS = {
  ['物理攻击'] = true,
  ['法术强度'] = true,
  ['攻击速度'] = true,
  ['暴击率'] = true,
  ['暴击伤害'] = true,
  ['物理吸血'] = true,
  ['法术吸血'] = true,
  ['护甲'] = true,
  ['法术抗性'] = true,
  ['最大气血'] = true,
  ['最大法力值'] = true,
  ['移动速度'] = true,
  ['冷却缩减'] = true,
  ['护甲穿透'] = true,
  ['法术穿透'] = true,
}
```

Use `y3.item.attr_pick_by_key(item_key)` to enumerate keys, then keep only keys in this map and format values with `%` for ratio-like stats.

### Formatting Rules

- Level line: `成长武器 Lv.%d`
- Cost line:
  - Normal: `升级所需：%d 金币`
  - Maxed: `升级所需：已满级`
- Empty attrs: `当前无直接属性增幅`
- Empty affixes: `暂无词缀`
- Affix with summary: `%s：%s`

---

### Task 1: Add Shared Growth-Weapon Tip Payload

**Files:**
- Modify: `maps/EntryMap/script/runtime/gear_upgrades.lua`
- Modify: `maps/EntryMap/script/tools/test_runtime_gear_upgrades_smoke.py`
- Create: `maps/EntryMap/script/tools/test_growth_weapon_tip_payload_smoke.lua`

- [ ] **Step 1: Write the failing Lua smoke for payload content**

Create `maps/EntryMap/script/tools/test_growth_weapon_tip_payload_smoke.lua`:

```lua
package.path = 'maps/EntryMap/script/?.lua;maps/EntryMap/script/?/init.lua;maps/EntryMap/script/?/?.lua;' .. package.path

local gear = require 'runtime.gear_upgrades'

local state = {
  resources = { gold = 9999 },
}

local config = {
  slots = {
    weapon = {
      slot = 'weapon',
      display_name = '成长武器',
      max_level = 100,
      affix_choice_count = 3,
      item_key = 201390082,
    },
  },
  levels_by_level = {
    [1] = { level = 1, gold_cost = 100, is_affix_node = false },
  },
}

local fake_item_api = {
  get_name_by_key = function(item_key)
    assert(item_key == 201390082, 'expected growth weapon item key')
    return '洪荒之刃'
  end,
  get_icon_id_by_key = function(item_key)
    assert(item_key == 201390082, 'expected growth weapon item key')
    return 123456
  end,
  attr_pick_by_key = function(item_key)
    assert(item_key == 201390082, 'expected growth weapon item key')
    return { '物理攻击', '暴击率', '移动速度', '未收录属性' }
  end,
  get_attribute_by_key = function(item_key, key)
    assert(item_key == 201390082, 'expected growth weapon item key')
    local values = {
      ['物理攻击'] = 31,
      ['暴击率'] = 0.25,
      ['移动速度'] = 0,
      ['未收录属性'] = 777,
    }
    return values[key] or 0
  end,
}

gear.ensure_runtime(state, config)
local payload = gear.build_tip_payload(state, 'weapon', config, fake_item_api)

assert(payload ~= nil, 'expected payload')
assert(payload.title_text == '洪荒之刃', 'expected item name as title')
assert(payload.subtitle_text == '成长武器 Lv.1', 'expected level subtitle')
assert(payload.cost_text == '升级所需：100 金币', 'expected upgrade cost text')
assert(payload.icon_res == 123456, 'expected item icon')
assert(type(payload.attr_lines) == 'table' and #payload.attr_lines == 2, 'expected exactly two direct attr lines')
assert(payload.attr_lines[1] == '物理攻击 +31', 'expected flat attack line')
assert(payload.attr_lines[2] == '暴击率 +25%', 'expected crit ratio formatted as percent')
assert(type(payload.affix_lines) == 'table' and payload.affix_lines[1] == '暂无词缀', 'expected empty affix fallback')

print('[OK] growth weapon tip payload smoke passed')
```

- [ ] **Step 2: Run the Lua smoke to verify it fails**

Run:

```powershell
lua .\tools\test_growth_weapon_tip_payload_smoke.lua
```

Expected: FAIL with `attempt to call field 'build_tip_payload'` or a payload assertion failure because the builder does not exist yet.

- [ ] **Step 3: Extend the existing Python smoke with payload assertions**

Update `maps/EntryMap/script/tools/test_runtime_gear_upgrades_smoke.py` by appending these assertions inside the generated Lua smoke source:

```lua
local fake_item_api = {
  get_name_by_key = function() return '洪荒之刃' end,
  get_icon_id_by_key = function() return 123456 end,
  attr_pick_by_key = function() return { '物理攻击', '暴击率' } end,
  get_attribute_by_key = function(_, key)
    if key == '物理攻击' then return 31 end
    if key == '暴击率' then return 0.25 end
    return 0
  end,
}
local payload = gear.build_tip_payload(state, 'weapon', config.gear_upgrade_config, fake_item_api)
assert(payload.title_text == '洪荒之刃', 'expected payload title text')
assert(payload.cost_text == '升级所需：100 金币', 'expected payload cost text')
assert(payload.attr_lines[1] == '物理攻击 +31', 'expected payload attr line')
assert(payload.affix_lines[1] == '暂无词缀', 'expected payload affix fallback')
```

- [ ] **Step 4: Run the Python smoke to verify it fails for the same reason**

Run:

```powershell
py -3 .\tools\test_runtime_gear_upgrades_smoke.py
```

Expected: FAIL because `build_tip_payload` is missing.

- [ ] **Step 5: Implement the minimal payload builder in `runtime/gear_upgrades.lua`**

Add these focused helpers near the bottom of `maps/EntryMap/script/runtime/gear_upgrades.lua`:

```lua
local RATIO_ATTR_KEYS = {
  ['攻击速度'] = true,
  ['暴击率'] = true,
  ['暴击伤害'] = true,
  ['物理吸血'] = true,
  ['法术吸血'] = true,
  ['冷却缩减'] = true,
}

local DIRECT_ATTR_KEYS = {
  ['物理攻击'] = true,
  ['法术强度'] = true,
  ['攻击速度'] = true,
  ['暴击率'] = true,
  ['暴击伤害'] = true,
  ['物理吸血'] = true,
  ['法术吸血'] = true,
  ['护甲'] = true,
  ['法术抗性'] = true,
  ['最大气血'] = true,
  ['最大法力值'] = true,
  ['移动速度'] = true,
  ['冷却缩减'] = true,
  ['护甲穿透'] = true,
  ['法术穿透'] = true,
}

local function get_item_api(item_api)
  return item_api or y3.item
end

local function format_attr_value(attr_name, value)
  local num = tonumber(value) or 0
  if RATIO_ATTR_KEYS[attr_name] then
    return string.format('%s +%d%%', attr_name, math.floor((num * 100) + 0.5))
  end
  return string.format('%s +%d', attr_name, math.floor(num + 0.5))
end

local function build_attr_lines(item_key, item_api)
  if not item_key then
    return { '当前无直接属性增幅' }
  end
  local keys = item_api.attr_pick_by_key and item_api.attr_pick_by_key(item_key) or {}
  local lines = {}
  for _, key in ipairs(keys or {}) do
    if DIRECT_ATTR_KEYS[key] then
      local value = item_api.get_attribute_by_key and item_api.get_attribute_by_key(item_key, key) or 0
      if tonumber(value) and tonumber(value) ~= 0 then
        lines[#lines + 1] = format_attr_value(key, value)
      end
    end
  end
  if #lines == 0 then
    return { '当前无直接属性增幅' }
  end
  return lines
end

function M.build_tip_payload(state, slot, config, item_api)
  local runtime = M.ensure_runtime(state, config)
  local item = ensure_item(runtime, slot or 'weapon')
  local item_api_impl = get_item_api(item_api)
  local item_key = item.item_key
  local item_name = item_key and item_api_impl.get_name_by_key and item_api_impl.get_name_by_key(item_key) or SLOT_LABELS[slot or 'weapon'] or '成长武器'
  local icon_res = item_key and item_api_impl.get_icon_id_by_key and item_api_impl.get_icon_id_by_key(item_key) or 0
  local cost = M.get_upgrade_cost(slot or 'weapon', item.level, runtime.config)
  local affix_lines = {}
  for _, affix in ipairs(item.affixes or {}) do
    if affix.summary and affix.summary ~= '' then
      affix_lines[#affix_lines + 1] = string.format('%s：%s', affix.display_name or affix.id or '词缀', affix.summary)
    else
      affix_lines[#affix_lines + 1] = affix.display_name or affix.id or '词缀'
    end
  end
  if #affix_lines == 0 then
    affix_lines[1] = '暂无词缀'
  end
  return {
    slot = slot or 'weapon',
    item_key = item_key,
    icon_res = icon_res,
    title_text = item_name,
    subtitle_text = string.format('成长武器 Lv.%d', item.level or 1),
    cost_text = cost == 0 and '升级所需：已满级' or string.format('升级所需：%d 金币', cost or 0),
    attr_title_text = '当前属性增幅',
    attr_lines = build_attr_lines(item_key, item_api_impl),
    affix_title_text = '当前词缀',
    affix_lines = affix_lines,
  }
end
```

- [ ] **Step 6: Run both payload tests to verify they pass**

Run:

```powershell
lua .\tools\test_growth_weapon_tip_payload_smoke.lua
py -3 .\tools\test_runtime_gear_upgrades_smoke.py
```

Expected:

- `[OK] growth weapon tip payload smoke passed`
- `runtime gear upgrades smoke ok`

- [ ] **Step 7: Commit the payload-builder slice**

```powershell
git add maps/EntryMap/script/runtime/gear_upgrades.lua maps/EntryMap/script/tools/test_growth_weapon_tip_payload_smoke.lua maps/EntryMap/script/tools/test_runtime_gear_upgrades_smoke.py
git commit -m "feat: add growth weapon tip payload builder"
```

---

### Task 2: Create a Shared Growth-Weapon Tip Panel

**Files:**
- Create: `maps/EntryMap/script/ui/growth_weapon_tip_panel.lua`
- Modify: `maps/EntryMap/script/runtime/boot.lua`

- [ ] **Step 1: Write the failing panel API stub test**

Create `maps/EntryMap/script/tools/test_growth_weapon_tip_panel_static.py`:

```python
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
TARGET = ROOT / 'ui' / 'growth_weapon_tip_panel.lua'

text = TARGET.read_text(encoding='utf-8')
assert 'show_for_anchor' in text, 'expected show_for_anchor export'
assert 'hide = function' in text or 'function api.hide' in text, 'expected hide export'
assert '当前属性增幅' in text, 'expected attr section rendering'
assert '当前词缀' in text, 'expected affix section rendering'
print('growth weapon tip panel static ok')
```

- [ ] **Step 2: Run the static test to verify it fails**

Run:

```powershell
py -3 .\tools\test_growth_weapon_tip_panel_static.py
```

Expected: FAIL because `ui/growth_weapon_tip_panel.lua` does not exist yet.

- [ ] **Step 3: Create `ui/growth_weapon_tip_panel.lua` with a minimal shared panel**

Create `maps/EntryMap/script/ui/growth_weapon_tip_panel.lua`:

```lua
local M = {}

function M.create(env)
  local y3 = env.y3
  local get_player = env.get_player
  local panel_root
  local title_node
  local subtitle_node
  local cost_node
  local attr_title_node
  local attr_nodes = {}
  local affix_title_node
  local affix_nodes = {}

  local function ensure_panel()
    if panel_root and not panel_root:is_removed() then
      return panel_root
    end
    local player = get_player()
    panel_root = y3.ui.get_ui(player, '物品说明')
    panel_root:set_follow_mouse(true, 12, 12)
    panel_root:set_visible(false)
    title_node = panel_root:get_child('shopTip.basic.title.title_TEXT')
    subtitle_node = panel_root:get_child('shopTip.basic.title.subtitle_TEXT')
    cost_node = panel_root:get_child('shopTip.note.note_TEXT')
    attr_title_node = panel_root:get_child('shopTip.attr_title_TEXT')
    affix_title_node = panel_root:get_child('shopTip.affix_title_TEXT')
    attr_nodes = {
      panel_root:get_child('shopTip.attr_1_TEXT'),
      panel_root:get_child('shopTip.attr_2_TEXT'),
      panel_root:get_child('shopTip.attr_3_TEXT'),
    }
    affix_nodes = {
      panel_root:get_child('shopTip.affix_1_TEXT'),
      panel_root:get_child('shopTip.affix_2_TEXT'),
      panel_root:get_child('shopTip.affix_3_TEXT'),
    }
    return panel_root
  end

  local function set_lines(nodes, lines)
    for index, node in ipairs(nodes) do
      if node then
        node:set_text(lines[index] or '')
        node:set_visible(lines[index] ~= nil)
      end
    end
  end

  return {
    show_for_anchor = function(anchor_ui, payload)
      local panel = ensure_panel()
      if not panel or not payload then
        return
      end
      panel:set_visible(true)
      if title_node then title_node:set_text(payload.title_text or '') end
      if subtitle_node then subtitle_node:set_text(payload.subtitle_text or '') end
      if cost_node then cost_node:set_text(payload.cost_text or '') end
      if attr_title_node then attr_title_node:set_text(payload.attr_title_text or '当前属性增幅') end
      if affix_title_node then affix_title_node:set_text(payload.affix_title_text or '当前词缀') end
      set_lines(attr_nodes, payload.attr_lines or { '当前无直接属性增幅' })
      set_lines(affix_nodes, payload.affix_lines or { '暂无词缀' })
      if anchor_ui and anchor_ui.get_absolute_x and anchor_ui.get_absolute_y then
        panel:set_absolute_pos(anchor_ui:get_absolute_x() + 14, anchor_ui:get_absolute_y() - 6)
      end
    end,
    hide = function()
      if panel_root and not panel_root:is_removed() then
        panel_root:set_visible(false)
      end
    end,
  }
end

return M
```

- [ ] **Step 4: Expose the shared panel dependencies from `runtime/boot.lua`**

Add these env fields where `ui.runtime_hud_panel1_top` is created in `maps/EntryMap/script/runtime/boot.lua`:

```lua
  build_growth_weapon_tip_payload = function(slot)
    return GearUpgrades.build_tip_payload(STATE, slot or 'weapon', CONFIG.gear_upgrade_config)
  end,
```

Also prepare to reuse the same builder in the item-tip bridge:

```lua
local growth_weapon_item_tip_system = require('ui.growth_weapon_item_tip').create({
  STATE = STATE,
  y3 = y3,
  get_player = get_player,
  build_growth_weapon_tip_payload = function(slot)
    return GearUpgrades.build_tip_payload(STATE, slot or 'weapon', CONFIG.gear_upgrade_config)
  end,
})
```

- [ ] **Step 5: Run the static test to verify it passes**

Run:

```powershell
py -3 .\tools\test_growth_weapon_tip_panel_static.py
```

Expected: `growth weapon tip panel static ok`

- [ ] **Step 6: Commit the shared tip panel slice**

```powershell
git add maps/EntryMap/script/ui/growth_weapon_tip_panel.lua maps/EntryMap/script/runtime/boot.lua maps/EntryMap/script/tools/test_growth_weapon_tip_panel_static.py
git commit -m "feat: add shared growth weapon tip panel"
```

---

### Task 3: Wire the Bottom HUD Growth-Weapon Slot

**Files:**
- Modify: `maps/EntryMap/script/ui/runtime_hud.lua`
- Modify: `maps/EntryMap/script/ui/runtime_hud_panel1_top.lua`
- Modify: `maps/EntryMap/script/tools/test_runtime_hud_skill_slot_static.py`

- [ ] **Step 1: Add a failing HUD static assertion**

Extend `maps/EntryMap/script/tools/test_runtime_hud_skill_slot_static.py` with:

```python
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
text = (ROOT / 'ui' / 'runtime_hud.lua').read_text(encoding='utf-8')
assert 'growth_weapon_slot' in text, 'expected growth weapon HUD slot wiring'
assert 'build_growth_weapon_tip_payload' in text, 'expected growth weapon tip payload usage'
assert 'growth_weapon_tip_panel.show_for_anchor' in text, 'expected hover tip hook'
print('runtime hud growth weapon slot static ok')
```

- [ ] **Step 2: Run the static test to verify it fails**

Run:

```powershell
py -3 .\tools\test_runtime_hud_skill_slot_static.py
```

Expected: FAIL on `growth_weapon_slot` assertions.

- [ ] **Step 3: Add a shared tip panel instance and HUD slot model in `ui/runtime_hud.lua`**

At the top of `maps/EntryMap/script/ui/runtime_hud.lua`, require the new panel and create it beside `BondTipPanel`:

```lua
local GrowthWeaponTipPanel = require 'ui.growth_weapon_tip_panel'

local growth_weapon_tip_panel = GrowthWeaponTipPanel.create({
  y3 = y3,
  get_player = env.get_player,
})
```

Create a small helper near the bond tip helpers:

```lua
local function hide_growth_weapon_tip()
  if growth_weapon_tip_panel and growth_weapon_tip_panel.hide then
    growth_weapon_tip_panel.hide()
  end
end

local function show_growth_weapon_tip(anchor_ui)
  if not anchor_ui or not env.build_growth_weapon_tip_payload then
    hide_growth_weapon_tip()
    return
  end
  local payload = env.build_growth_weapon_tip_payload('weapon')
  if not payload then
    hide_growth_weapon_tip()
    return
  end
  growth_weapon_tip_panel.show_for_anchor(anchor_ui, payload)
end
```

- [ ] **Step 4: Create the growth-weapon slot in the HUD bottom bar**

Inside `create_runtime_hud()` in `maps/EntryMap/script/ui/runtime_hud.lua`, create a slot between the challenge buttons and skill buttons:

```lua
local growth_weapon_slot = create_panel(
  right_root,
  scaled(618, scale),
  scaled(28, scale),
  scaled(44, scale),
  scaled(44, scale),
  { 18, 28, 42, 220 },
  theme.insets.soft,
  9403,
  runtime_skin.top_bar_icon
)
growth_weapon_slot:set_anchor(0.5, 0.5)
growth_weapon_slot:set_intercepts_operations(true)

local growth_weapon_icon = create_panel(
  right_root,
  scaled(618, scale),
  scaled(28, scale),
  scaled(36, scale),
  scaled(36, scale),
  { 255, 255, 255, 255 },
  { 4, 4, 4, 4 },
  9404
)
growth_weapon_icon:set_anchor(0.5, 0.5)
growth_weapon_icon:set_intercepts_operations(false)

local growth_weapon_level = create_text(
  right_root,
  scaled(618, scale),
  scaled(6, scale),
  scaled(56, scale),
  scaled(10, scale),
  scaled(9, scale),
  { 236, 242, 250, 255 },
  '中',
  '中',
  9405
)
growth_weapon_level:set_anchor(0.5, 0.5)
```

Store them in `STATE.runtime_hud`:

```lua
      growth_weapon_slot = {
        root = growth_weapon_slot,
        icon = growth_weapon_icon,
        level = growth_weapon_level,
      },
```

- [ ] **Step 5: Refresh the slot and wire hover events**

In `refresh_runtime_hud()` inside `maps/EntryMap/script/ui/runtime_hud.lua`, add:

```lua
local weapon_slot = runtime_hud.growth_weapon_slot
if weapon_slot and env.build_growth_weapon_tip_payload then
  local payload = env.build_growth_weapon_tip_payload('weapon')
  weapon_slot.payload = payload
  if payload and weapon_slot.icon then
    weapon_slot.icon:set_image(payload.icon_res or ui_res.common.empty)
    weapon_slot.icon:set_visible(true)
  end
  if payload and weapon_slot.level then
    weapon_slot.level:set_text(payload.subtitle_text or '')
  end
end
```

Then wire events once at creation:

```lua
growth_weapon_slot:add_fast_event('鼠标-移入', function()
  show_growth_weapon_tip(growth_weapon_slot)
end)
growth_weapon_slot:add_fast_event('鼠标-移出', function()
  hide_growth_weapon_tip()
end)
growth_weapon_slot:add_fast_event('左键-点击', function()
  hide_growth_weapon_tip()
end)
```

Also hide this panel whenever the HUD is hidden by adding `hide_growth_weapon_tip()` beside `hide_bond_tip()` in the `set_visible` path.

- [ ] **Step 6: Run the HUD static test to verify it passes**

Run:

```powershell
py -3 .\tools\test_runtime_hud_skill_slot_static.py
```

Expected: `runtime hud growth weapon slot static ok`

- [ ] **Step 7: Commit the HUD slot slice**

```powershell
git add maps/EntryMap/script/ui/runtime_hud.lua maps/EntryMap/script/ui/runtime_hud_panel1_top.lua maps/EntryMap/script/tools/test_runtime_hud_skill_slot_static.py
git commit -m "feat: add growth weapon HUD hover tip"
```

---

### Task 4: Wire the Hero Item-Bar Growth-Weapon Hover

**Files:**
- Create: `maps/EntryMap/script/ui/growth_weapon_item_tip.lua`
- Modify: `maps/EntryMap/script/runtime/boot.lua`
- Create: `maps/EntryMap/script/tools/test_growth_weapon_item_tip_static.py`

- [ ] **Step 1: Write the failing static test for item-bar hover binding**

Create `maps/EntryMap/script/tools/test_growth_weapon_item_tip_static.py`:

```python
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
text = (ROOT / 'ui' / 'growth_weapon_item_tip.lua').read_text(encoding='utf-8')
for slot in range(1, 7):
    assert f'equip_slot_bg_{slot}' in text, f'expected item-bar slot {slot} binding'
assert 'get_item_by_slot' in text, 'expected hovered item lookup'
assert 'build_growth_weapon_tip_payload' in text, 'expected growth weapon payload builder usage'
assert 'show_for_anchor' in text, 'expected shared tip panel usage'
print('growth weapon item tip static ok')
```

- [ ] **Step 2: Run the static test to verify it fails**

Run:

```powershell
py -3 .\tools\test_growth_weapon_item_tip_static.py
```

Expected: FAIL because `ui/growth_weapon_item_tip.lua` does not exist yet.

- [ ] **Step 3: Create `ui/growth_weapon_item_tip.lua`**

Create `maps/EntryMap/script/ui/growth_weapon_item_tip.lua`:

```lua
local GrowthWeaponTipPanel = require 'ui.growth_weapon_tip_panel'

local M = {}

function M.create(env)
  local y3 = env.y3
  local STATE = env.STATE
  local get_player = env.get_player
  local tip_panel = GrowthWeaponTipPanel.create({
    y3 = y3,
    get_player = get_player,
  })

  local root = y3.local_ui.create('GameHUD')
  local bound = false

  local function hide()
    tip_panel.hide()
  end

  local function hovered_item(slot_index, local_player)
    local hero = STATE.hero or local_player:get_local_selecting_unit()
    if not hero then
      return nil
    end
    return hero:get_item_by_slot(y3.const.SlotType.BAR, slot_index - 1)
  end

  local function show(ui, local_player, slot_index)
    local item = hovered_item(slot_index, local_player)
    if not item or not item:is_exist() then
      hide()
      return
    end
    local payload = env.build_growth_weapon_tip_payload and env.build_growth_weapon_tip_payload('weapon') or nil
    if not payload or payload.item_key ~= item:get_key() then
      hide()
      return
    end
    tip_panel.show_for_anchor(ui, payload)
  end

  local function bind()
    if bound then
      return
    end
    bound = true
    for slot = 1, 6 do
      local child_name = string.format('item.equip_slot_bg_%d', slot)
      root:on_event(child_name, '鼠标-移入', function(ui, local_player)
        show(ui, local_player, slot)
      end)
      root:on_event(child_name, '鼠标-移出', function()
        hide()
      end)
    end
  end

  return {
    bind = bind,
    refresh = function() end,
    hide = hide,
  }
end

return M
```

- [ ] **Step 4: Register the item-bar hover binder in `runtime/boot.lua`**

In `maps/EntryMap/script/runtime/boot.lua`, create and start the system:

```lua
local growth_weapon_item_tip_system

growth_weapon_item_tip_system = require('ui.growth_weapon_item_tip').create({
  STATE = STATE,
  y3 = y3,
  get_player = get_player,
  build_growth_weapon_tip_payload = function(slot)
    return GearUpgrades.build_tip_payload(STATE, slot or 'weapon', CONFIG.gear_upgrade_config)
  end,
})
```

Call `growth_weapon_item_tip_system.bind()` inside `M.bootstrap()` after `register_runtime_events()` and before gameplay starts:

```lua
  if growth_weapon_item_tip_system and growth_weapon_item_tip_system.bind then
    growth_weapon_item_tip_system.bind()
  end
```

- [ ] **Step 5: Run the static item-bar test to verify it passes**

Run:

```powershell
py -3 .\tools\test_growth_weapon_item_tip_static.py
```

Expected: `growth weapon item tip static ok`

- [ ] **Step 6: Run the full verification set**

Run:

```powershell
lua .\tools\test_growth_weapon_tip_payload_smoke.lua
py -3 .\tools\test_runtime_gear_upgrades_smoke.py
py -3 .\tools\test_growth_weapon_tip_panel_static.py
py -3 .\tools\test_runtime_hud_skill_slot_static.py
py -3 .\tools\test_growth_weapon_item_tip_static.py
py -3 .\tools\test_session_state_grants_level1_weapon_smoke.py
```

Expected:

- `[OK] growth weapon tip payload smoke passed`
- `runtime gear upgrades smoke ok`
- `growth weapon tip panel static ok`
- `runtime hud growth weapon slot static ok`
- `growth weapon item tip static ok`
- `session state grants level1 weapon smoke ok` (no traceback)

- [ ] **Step 7: Commit the item-bar slice**

```powershell
git add maps/EntryMap/script/ui/growth_weapon_item_tip.lua maps/EntryMap/script/runtime/boot.lua maps/EntryMap/script/tools/test_growth_weapon_item_tip_static.py
git commit -m "feat: add growth weapon item bar tip"
```

---

## Self-Review

### Spec Coverage

- Shared payload builder: Task 1
- Current direct attr bonuses only: Task 1
- HUD growth-weapon tip: Task 3
- Item-bar growth-weapon tip: Task 4
- Shared panel and shared content source: Task 2 + Task 4

No uncovered spec sections remain.

### Placeholder Scan

- No `TODO` / `TBD`
- Every task contains exact file paths
- Every code-edit step includes concrete code blocks
- Every verification step includes explicit commands and expected results

### Type Consistency

- Shared builder name stays `build_tip_payload`
- Shared panel API stays `show_for_anchor` / `hide`
- Shared env hook stays `build_growth_weapon_tip_payload`
- Item-bar bridge API stays `bind` / `refresh` / `hide`

