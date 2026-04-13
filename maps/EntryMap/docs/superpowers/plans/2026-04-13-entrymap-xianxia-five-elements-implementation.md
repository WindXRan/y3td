# EntryMap Xianxia Five-Elements Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Rework EntryMap's player-facing combat packaging into a xianxia five-elements system while migrating runtime damage metadata from a single `damage_type` field to `damage_form + element + damage_label` with compatibility for existing content.

**Architecture:** Keep the current attack-skill runtime intact, but insert a compatibility layer in the attack-skill loader and damage pipeline so old `damage_type` data can still run while new structured metadata is introduced. Migrate the five implemented skills first, then migrate second-batch blueprints and directly-coupled docs/tests, and only after that remove the remaining direct runtime assumptions that treat `damage_type` as the sole source of truth.

**Tech Stack:** Lua runtime modules, CSV object tables, Python static tests, git

---

## File Structure

### Files to Create

- `script/tools/test_attack_skill_damage_metadata_static.py`
  - Static regression test for structured damage metadata in CSV, skill defs, and second-batch blueprints.
- `script/tools/test_xianxia_damage_copy_static.py`
  - Static regression test for player-facing wording migration on core skill copy.

### Files to Modify

- `script/data_csv/attack_skills.csv`
  - Add `damage_form`, `element`, `damage_label` columns and migrate the five implemented skills.
- `script/data/object_tables/attack_skills.lua`
  - Load new metadata, preserve fallback from old `damage_type`, and expose structured fields to runtime.
- `script/entry_objects/attack_skills/basic_attack.lua`
  - Sync direct definition with new structured metadata and xianxia copy.
- `script/entry_objects/attack_skills/arcane_arrow.lua`
  - Same as above.
- `script/entry_objects/attack_skills/flame_arrow.lua`
  - Same as above.
- `script/entry_objects/attack_skills/frost_arrow.lua`
  - Same as above.
- `script/entry_objects/attack_skills/thunder.lua`
  - Same as above.
- `script/runtime/boot.lua`
  - Carry structured damage metadata into skill instances and damage application.
- `script/runtime/attack_skills.lua`
  - Pass structured metadata to damage calls and preserve current cast behavior.
- `script/runtime/hero_attr_system.lua`
  - Split damage multiplier logic into form- and element-based layers while keeping backward compatibility.
- `script/runtime/auto_active_effects.lua`
  - Use `damage_form` instead of string-equality on `damage_type` for jump-text styling.
- `script/entry_objects/attack_skill_blueprints/second_batch_skills.lua`
  - Replace old element wording and add structured damage metadata to each blueprint.
- `script/docs/内容设计/05-技能/技能总表.md`
  - Update visible damage taxonomy to xianxia/five-elements wording.
- `script/docs/内容设计/05-技能/第二批通用攻击技能与进化卡设计.md`
  - Update second-batch damage names and descriptions to five-elements wording.

### Files to Review While Implementing

- `docs/superpowers/specs/2026-04-13-entrymap-xianxia-five-elements-design.md`
- `script/runtime/bonds_chain.lua`
- `script/tools/test_second_batch_blueprint_wiring.py`
- `script/tools/test_runtime_bonds_chain_smoke.py`

---

### Task 1: Lock the New Damage Metadata Contract with Failing Tests

**Files:**
- Create: `script/tools/test_attack_skill_damage_metadata_static.py`
- Create: `script/tools/test_xianxia_damage_copy_static.py`
- Test: `script/tools/test_attack_skill_damage_metadata_static.py`
- Test: `script/tools/test_xianxia_damage_copy_static.py`

- [ ] **Step 1: Write the failing metadata test**

```python
from pathlib import Path
import csv

ROOT = Path(__file__).resolve().parents[1]
ATTACK_SKILLS_CSV = ROOT / "data_csv" / "attack_skills.csv"
BLUEPRINTS = ROOT / "entry_objects" / "attack_skill_blueprints" / "second_batch_skills.lua"


def read_csv_rows(path: Path):
    with path.open("r", encoding="utf-8-sig", newline="") as f:
        return list(csv.DictReader(f))


def test_attack_skills_csv_exposes_structured_damage_fields():
    rows = read_csv_rows(ATTACK_SKILLS_CSV)
    first = rows[0]
    assert "damage_form" in first, "attack_skills.csv must expose damage_form"
    assert "element" in first, "attack_skills.csv must expose element"
    assert "damage_label" in first, "attack_skills.csv must expose damage_label"


def test_second_batch_blueprints_use_structured_damage_metadata():
    content = BLUEPRINTS.read_text(encoding="utf-8")
    assert "damage_form =" in content, "second batch blueprints must define damage_form"
    assert "element =" in content, "second batch blueprints must define element"
    assert "damage_label =" in content, "second batch blueprints must define damage_label"
```

- [ ] **Step 2: Write the failing xianxia copy test**

```python
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
FILES = [
    ROOT / "entry_objects" / "attack_skills" / "basic_attack.lua",
    ROOT / "entry_objects" / "attack_skills" / "arcane_arrow.lua",
    ROOT / "entry_objects" / "attack_skills" / "flame_arrow.lua",
    ROOT / "entry_objects" / "attack_skills" / "frost_arrow.lua",
    ROOT / "entry_objects" / "attack_skills" / "thunder.lua",
]


def test_core_skill_copy_no_longer_uses_old_element_magic_phrasing():
    banned = ["能量魔法", "电系魔法", "冰系魔法", "火系物理", "物理伤害。"]
    joined = "\n".join(path.read_text(encoding="utf-8") for path in FILES)
    for needle in banned:
        assert needle not in joined, f"old phrasing should be removed: {needle}"
```

- [ ] **Step 3: Run the new tests to confirm they fail**

Run: `py -3 script/tools/test_attack_skill_damage_metadata_static.py`
Expected: FAIL because `attack_skills.csv` and `second_batch_skills.lua` still only expose `damage_type`.

Run: `py -3 script/tools/test_xianxia_damage_copy_static.py`
Expected: FAIL because the five implemented skills still use old wording such as `能量魔法` and `电系魔法`.

- [ ] **Step 4: Commit the failing tests**

```bash
git add script/tools/test_attack_skill_damage_metadata_static.py script/tools/test_xianxia_damage_copy_static.py
git commit -m "test: lock five-element damage metadata contract"
```

---

### Task 2: Add Structured Damage Metadata to the Loader and Implemented Skills

**Files:**
- Modify: `script/data_csv/attack_skills.csv`
- Modify: `script/data/object_tables/attack_skills.lua`
- Modify: `script/entry_objects/attack_skills/basic_attack.lua`
- Modify: `script/entry_objects/attack_skills/arcane_arrow.lua`
- Modify: `script/entry_objects/attack_skills/flame_arrow.lua`
- Modify: `script/entry_objects/attack_skills/frost_arrow.lua`
- Modify: `script/entry_objects/attack_skills/thunder.lua`
- Test: `script/tools/test_attack_skill_damage_metadata_static.py`
- Test: `script/tools/test_xianxia_damage_copy_static.py`

- [ ] **Step 1: Extend `attack_skills.csv` with the new columns and values**

```csv
id,name,default_slot,summary,damage_type,damage_form,element,damage_label,base_damage_ratio,base_cooldown,base_range,base_pierce,base_pierce_width,base_control_lock_time,base_knockback_distance,base_knockback_speed,base_explosion_ratio,base_explosion_radius,base_extra_targets,base_repeat_count
basic_attack,普攻,1,发射 1 支箭矢，造成 100% 攻击的金行箭罡伤害。,物理,weapon,metal,金行箭罡,1.0,1.6,760,,,,,,,,,
arcane_arrow,青木灵矢,,射出 1 支青木灵矢，造成木行灵矢伤害。,法术,spell,wood,木行灵矢,0.8,2.0,900,1,,,,,,,,
flame_arrow,赤炎箭,,射出 1 支赤炎箭，命中后爆炸造成火行爆炎伤害。,物理,weapon,fire,火行爆炎,2.2,6.2,900,,,,,,1.8,220,,
frost_arrow,寒泉箭,,射出 1 支寒泉箭，造成水行寒煞伤害并短暂击退目标。,法术,spell,water,水行寒煞,1.7,4.8,920,0,95,0.20,90,880,,,,
thunder,乙木天雷,,召唤 1 道乙木天雷打击目标，造成木行天雷伤害。,法术,spell,wood,木行天雷,2.0,5.5,950,,,,,,,,1,
```

- [ ] **Step 2: Teach the attack-skill object table to build structured metadata with fallback**

```lua
local LEGACY_DAMAGE_TYPE_MAP = {
  ['物理'] = { damage_form = 'weapon', element = 'none', damage_label = '兵刃伤害' },
  ['法术'] = { damage_form = 'spell', element = 'none', damage_label = '术法伤害' },
}

local function build_damage_meta(row)
  local damage_form = row.damage_form
  local element = row.element
  local damage_label = row.damage_label

  if damage_form and damage_form ~= '' and element and element ~= '' and damage_label and damage_label ~= '' then
    return damage_form, element, damage_label
  end

  local fallback = LEGACY_DAMAGE_TYPE_MAP[row.damage_type]
  if fallback then
    return fallback.damage_form, fallback.element, fallback.damage_label
  end

  error(string.format('attack skill %s missing damage metadata', tostring(row.id)))
end

for _, row in ipairs(skill_rows) do
  local damage_form, element, damage_label = build_damage_meta(row)
  local def = {
    id = row.id,
    name = row.name,
    summary = row.summary,
    damage_type = row.damage_type,
    damage_form = damage_form,
    element = element,
    damage_label = damage_label,
    vfx = build_vfx(row.id),
  }
```

- [ ] **Step 3: Sync the five implemented Lua skill defs to match the new contract**

```lua
local M = {
  id = 'thunder',
  name = '乙木天雷',
  summary = '召唤 1 道乙木天雷打击目标，造成木行天雷伤害。',
  damage_type = '法术',
  damage_form = 'spell',
  element = 'wood',
  damage_label = '木行天雷',
  base_damage_ratio = 2.0,
  base_cooldown = 5.5,
  base_range = 950,
  base_extra_targets = 0,
}
```

- [ ] **Step 4: Re-run the static tests**

Run: `py -3 script/tools/test_attack_skill_damage_metadata_static.py`
Expected: PASS

Run: `py -3 script/tools/test_xianxia_damage_copy_static.py`
Expected: PASS

- [ ] **Step 5: Commit the data and loader migration**

```bash
git add script/data_csv/attack_skills.csv script/data/object_tables/attack_skills.lua script/entry_objects/attack_skills/basic_attack.lua script/entry_objects/attack_skills/arcane_arrow.lua script/entry_objects/attack_skills/flame_arrow.lua script/entry_objects/attack_skills/frost_arrow.lua script/entry_objects/attack_skills/thunder.lua
git commit -m "feat: add structured damage metadata to attack skills"
```

---

### Task 3: Thread Structured Damage Metadata Through Runtime Damage Calculation

**Files:**
- Modify: `script/runtime/boot.lua`
- Modify: `script/runtime/attack_skills.lua`
- Modify: `script/runtime/hero_attr_system.lua`
- Modify: `script/runtime/auto_active_effects.lua`
- Test: `script/tools/test_runtime_bonds_chain_smoke.py`

- [ ] **Step 1: Add a runtime helper that resolves structured damage info**

```lua
local function resolve_skill_damage_meta(skill)
  return {
    damage_type = skill.damage_type or '法术',
    damage_form = skill.damage_form or (skill.damage_type == '物理' and 'weapon' or 'spell'),
    element = skill.element or 'none',
    damage_label = skill.damage_label or (skill.damage_type == '物理' and '兵刃伤害' or '术法伤害'),
  }
end
```

- [ ] **Step 2: Copy structured metadata into attack skill runtime instances**

```lua
return {
  id = def.id,
  name = def.name,
  slot = slot or def.default_slot or 0,
  summary = def.summary,
  damage_type = def.damage_type,
  damage_form = def.damage_form,
  element = def.element,
  damage_label = def.damage_label,
  level = 1,
  unlocked = true,
  damage_ratio = def.base_damage_ratio or 0,
}
```

- [ ] **Step 3: Update damage application to use form and element multipliers**

```lua
function api.get_damage_multiplier(hero, damage_kind, source_kind, element)
  local multiplier = 1

  if damage_kind == 'weapon' then
    multiplier = multiplier * (1 + normalize_ratio(api.get_attr(hero, '物理伤害')))
  elseif damage_kind == 'spell' or damage_kind == 'dot' or damage_kind == 'summon' then
    multiplier = multiplier * (1 + normalize_ratio(api.get_attr(hero, '魔法伤害')))
  end

  if element == 'metal' then
    multiplier = multiplier * (1 + normalize_ratio(api.get_attr(hero, '金行伤害')))
  elseif element == 'wood' then
    multiplier = multiplier * (1 + normalize_ratio(api.get_attr(hero, '木行伤害')))
  elseif element == 'water' then
    multiplier = multiplier * (1 + normalize_ratio(api.get_attr(hero, '水行伤害')))
  elseif element == 'fire' then
    multiplier = multiplier * (1 + normalize_ratio(api.get_attr(hero, '火行伤害')))
  elseif element == 'earth' then
    multiplier = multiplier * (1 + normalize_ratio(api.get_attr(hero, '土行伤害')))
  end

  if source_kind == 'normal_attack' then
    multiplier = multiplier * (1 + normalize_ratio(api.get_attr(hero, '普攻伤害')))
  elseif source_kind == 'skill' then
    multiplier = multiplier * (1 + normalize_ratio(api.get_attr(hero, '技能伤害')))
  end

  multiplier = multiplier * (1 + normalize_ratio(api.get_attr(hero, '所有伤害')))
  multiplier = multiplier * (1 + normalize_ratio(api.get_attr(hero, '最终伤害')))
  return multiplier
end
```

- [ ] **Step 4: Switch jump-text styling to `damage_form` instead of old type-only checks**

```lua
local function resolve_damage_text_type(damage_form, visual)
  if visual and visual.text_type then
    return visual.text_type
  end
  if damage_form == 'weapon' then
    return 'physics'
  end
  return 'magic'
end
```

- [ ] **Step 5: Run the existing runtime smoke**

Run: `py -3 script/tools/test_runtime_bonds_chain_smoke.py`
Expected: PASS with no regressions around boot wiring, attack skill setup, or bond runtime assumptions.

- [ ] **Step 6: Commit the runtime compatibility layer**

```bash
git add script/runtime/boot.lua script/runtime/attack_skills.lua script/runtime/hero_attr_system.lua script/runtime/auto_active_effects.lua
git commit -m "feat: thread five-element damage metadata through runtime"
```

---

### Task 4: Migrate Second-Batch Blueprints and Core Docs to Five-Elements Wording

**Files:**
- Modify: `script/entry_objects/attack_skill_blueprints/second_batch_skills.lua`
- Modify: `script/docs/内容设计/05-技能/技能总表.md`
- Modify: `script/docs/内容设计/05-技能/第二批通用攻击技能与进化卡设计.md`
- Test: `script/tools/test_attack_skill_damage_metadata_static.py`
- Test: `script/tools/test_second_batch_blueprint_wiring.py`

- [ ] **Step 1: Add structured damage metadata to each second-batch blueprint**

```lua
{
  id = 'chain_lightning',
  name = '雷链',
  damage_form = 'spell',
  element = 'wood',
  damage_label = '木行雷链',
  archetype = '连锁清怪扩散',
  base = {
    damage_ratio = 1.20,
    cooldown = 5.5,
    bounce = 5,
  },
  evolution = {
    id = 'eternal_thunder_chain',
    name = '永续雷链',
    summary = '雷链进阶为木行连锁主核，后续弹射稳定清场。',
  },
}
```

- [ ] **Step 2: Replace old elemental wording in second-batch card summaries**

```lua
{ id = 'chain_lightning_state', name = '感雷蔓引', lane = 'state', rarity = '稀有', summary = '命中附加感雷，使目标受到木行伤害 +18%。' }
{ id = 'earthquake_form', name = '岩脉突刺', lane = 'form', rarity = '优秀', summary = '中心生成岩刺带，持续造成土行震罡伤害。' }
{ id = 'arcane_ray_state', name = '裂灵崩光', lane = 'state', rarity = '稀有', summary = '命中会施加脆化，使目标受到金行灵束伤害 +18%，持续 4 秒。' }
```

- [ ] **Step 3: Update the two core skill docs to match the new taxonomy**

```md
| `arcane_arrow` | `青木灵矢` | `射出 1 支青木灵矢，造成木行灵矢伤害。` | `术法 / 木` |
| `frost_arrow` | `寒泉箭` | `射出 1 支寒泉箭，造成水行寒煞伤害并短暂击退目标。` | `术法 / 水` |
| `thunder` | `乙木天雷` | `召唤 1 道乙木天雷打击目标，造成木行天雷伤害。` | `术法 / 木` |
```

- [ ] **Step 4: Re-run static blueprint checks**

Run: `py -3 script/tools/test_attack_skill_damage_metadata_static.py`
Expected: PASS

Run: `py -3 script/tools/test_second_batch_blueprint_wiring.py`
Expected: PASS because the blueprints remain exported through `entry_objects.attack_skills`.

- [ ] **Step 5: Commit the blueprint and doc migration**

```bash
git add script/entry_objects/attack_skill_blueprints/second_batch_skills.lua script/docs/内容设计/05-技能/技能总表.md script/docs/内容设计/05-技能/第二批通用攻击技能与进化卡设计.md
git commit -m "feat: migrate skill blueprints to xianxia five-elements wording"
```

---

### Task 5: Final Verification and Follow-Up Boundary Checks

**Files:**
- Review: `docs/superpowers/specs/2026-04-13-entrymap-xianxia-five-elements-design.md`
- Review: `docs/superpowers/plans/2026-04-13-entrymap-xianxia-five-elements-implementation.md`
- Test: `script/tools/test_attack_skill_damage_metadata_static.py`
- Test: `script/tools/test_xianxia_damage_copy_static.py`
- Test: `script/tools/test_second_batch_blueprint_wiring.py`
- Test: `script/tools/test_runtime_bonds_chain_smoke.py`

- [ ] **Step 1: Run the full targeted verification set**

Run: `py -3 script/tools/test_attack_skill_damage_metadata_static.py`
Expected: PASS

Run: `py -3 script/tools/test_xianxia_damage_copy_static.py`
Expected: PASS

Run: `py -3 script/tools/test_second_batch_blueprint_wiring.py`
Expected: PASS

Run: `py -3 script/tools/test_runtime_bonds_chain_smoke.py`
Expected: PASS

- [ ] **Step 2: Review for forbidden scope creep**

```text
Confirm the diff does not introduce:
- 五行相克计算
- 全怪物五行配置
- 新脚本解释器
- 非技能核心文档的全量翻修
```

- [ ] **Step 3: Review remaining old wording in touched areas**

Run: `rg -n "能量魔法|电系魔法|冰系魔法|火系物理|风系魔法|物系物理" script/data_csv script/entry_objects/attack_skills script/entry_objects/attack_skill_blueprints script/docs/内容设计/05-技能 -S`
Expected: Only untouched historical records remain outside the planned migration surface; no matches remain in the modified attack-skill data and core skill docs.

- [ ] **Step 4: Commit the verification pass if any cleanup was needed**

```bash
git add script tools docs
git commit -m "chore: verify xianxia five-elements migration"
```

---

## Self-Review

### Spec coverage

- Dual-layer metadata contract: covered by Tasks 1-3.
- Five implemented skills migrated first: covered by Task 2.
- Runtime compatibility and multiplier split without克制: covered by Task 3.
- Second-batch blueprint and visible skill copy migration: covered by Task 4.
- No five-element counter system and no full-doc rewrite: enforced in Task 5.

### Placeholder scan

- No `TODO`, `TBD`, or “similar to above” placeholders remain.
- Each task includes concrete files, code snippets, commands, and expected outcomes.

### Type consistency

- Structured metadata names stay consistent across all tasks: `damage_form`, `element`, `damage_label`.
- Runtime multiplier signature stays consistent in the plan: `get_damage_multiplier(hero, damage_kind, source_kind, element)`.

