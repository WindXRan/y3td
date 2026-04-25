# Mainline Task Reward Completeness Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make the in-battle mainline task system fully execute every reward category currently expressible by the existing mainline task tables.

**Architecture:** Keep `script/data/object_tables/mainline_task_rewards.lua` as the normalization layer that merges `mainline_task_rewards.csv` and `attreffect.csv`, then expand `script/runtime/mainline_tasks.lua` into a complete reward dispatcher for `attr`, `resource`, `state`, `runtime`, and `attack_skill`. Lock the behavior with static coverage tests plus smoke tests that verify reward state actually changes at runtime.

**Tech Stack:** Lua 5.4, Y3 runtime state tables, Python static tests, Lua smoke tests

---

## File Map

- Modify: `script/runtime/mainline_tasks.lua`
  - Add complete reward execution dispatch and stable runtime reward state buckets.
- Modify: `script/data/object_tables/mainline_task_rewards.lua`
  - Expand normalized reward-line mapping so mainline tasks can carry all supported effect kinds without silent gaps.
- Modify: `script/tools/test_mainline_task_runtime_smoke.lua`
  - Add runtime assertions for `state`, `runtime`, and `attack_skill` reward application.
- Create: `script/tools/test_mainline_task_reward_mapping_static.py`
  - Verify mainline task reward kinds/keys allowed by the object-table pipeline also have runtime execution coverage.
- Possibly modify: `script/runtime/boot.lua`
  - Only if the chosen runtime reward state bucket needs boot-time initialization beyond `mainline_task_runtime`.

### Task 1: Lock Missing Reward Coverage With Failing Tests

**Files:**
- Create: `script/tools/test_mainline_task_reward_mapping_static.py`
- Modify: `script/tools/test_mainline_task_runtime_smoke.lua`

- [ ] **Step 1: Write the failing static coverage test**

```python
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
ATTREFFECT_PATH = ROOT / "data" / "object_tables" / "attreffect.lua"
MAINLINE_OBJECT_TABLE_PATH = ROOT / "data" / "object_tables" / "mainline_task_rewards.lua"
MAINLINE_RUNTIME_PATH = ROOT / "runtime" / "mainline_tasks.lua"


def read_text(path: Path) -> str:
    return path.read_text(encoding="utf-8")


def test_mainline_reward_pipeline_accepts_and_executes_supported_kinds() -> None:
    attreffect = read_text(ATTREFFECT_PATH)
    object_table = read_text(MAINLINE_OBJECT_TABLE_PATH)
    runtime = read_text(MAINLINE_RUNTIME_PATH)

    assert "attack_skill = true" in attreffect
    assert "elseif effect.effect_kind == 'attack_skill' then" in object_table

    assert "local function apply_state_reward" in runtime
    assert "local function apply_runtime_reward" in runtime
    assert "local function apply_attack_skill_reward" in runtime

    assert "line.type == 'state'" in runtime
    assert "line.type == 'runtime'" in runtime
    assert "line.type == 'attack_skill'" in runtime


if __name__ == "__main__":
    test_mainline_reward_pipeline_accepts_and_executes_supported_kinds()
    print("mainline task reward mapping static ok")
```

- [ ] **Step 2: Run the static test to verify it fails**

Run: `py script/tools/test_mainline_task_reward_mapping_static.py`
Expected: FAIL because `mainline_task_rewards.lua` and `mainline_tasks.lua` do not yet expose complete `attack_skill` / dispatcher coverage.

- [ ] **Step 3: Extend the runtime smoke with missing reward assertions**

Append a new focused block near the end of `script/tools/test_mainline_task_runtime_smoke.lua`:

```lua
local reward_state = {
  current_mode_def = { mode_id = 'challenge' },
  mainline_task_runtime = {
    active_task_id = '3-10',
    chain_exhausted = false,
    completed_task_ids = {},
    rewarded_task_ids = {},
    hero_card_count = 0,
    progress_by_task_id = {},
    auto_track_enabled = true,
    pinned_task_id = nil,
    snapshot_summary = nil,
  },
  hero = {},
  skill_points = 0,
  skill_runtime = {
    chain_bounces = 0,
    multishot_count = 0,
    skill_echo_chance = 0,
  },
  attack_skill_state = {
    by_id = {
      basic_attack = {
        id = 'basic_attack',
        cooldown_reduction = 0,
        range_bonus = 0,
      },
    },
  },
}

local reward_api = MainlineTaskRuntime.create({
  STATE = reward_state,
  CONFIG = {
    mainline_task_rewards = require 'data.object_tables.mainline_task_rewards',
  },
  round_number = function(value)
    return math.floor((value or 0) + 0.5)
  end,
  message = function() end,
  add_hero_attr_pack = function() end,
  award_rewards = function() end,
  queue_treasure_round = function() end,
})

reward_api.apply_task_rewards({
  id = 'test-reward-pack',
  reward_lines = {
    { type = 'state', key = 'skill_point', value = 1 },
    { type = 'state', key = 'hero_card', value = 2 },
    { type = 'runtime', key = 'chain_bounces', value = 3 },
    { type = 'runtime', key = 'skill_echo_chance', value = 0.25 },
    { type = 'attack_skill', key = 'cooldown_reduction', value = 0.10 },
  }
})

assert(reward_state.skill_points == 1, 'expected state reward to add skill points')
assert(reward_state.mainline_task_runtime.hero_card_count == 2, 'expected state reward to add hero card count')
assert(reward_state.skill_runtime.chain_bounces == 3, 'expected runtime reward to add chain bounces')
assert(reward_state.skill_runtime.skill_echo_chance == 0.25, 'expected runtime reward to add skill echo chance')
assert(reward_state.attack_skill_state.by_id.basic_attack.cooldown_reduction == 0.10, 'expected attack skill reward to affect existing attack skills')
```

- [ ] **Step 4: Run the smoke to verify it fails**

Run: `lua script/tools/test_mainline_task_runtime_smoke.lua`
Expected: FAIL because `apply_task_rewards()` does not yet handle `chain_bounces`, `skill_echo_chance`, or `attack_skill`.

- [ ] **Step 5: Commit the red tests**

```bash
git add script/tools/test_mainline_task_reward_mapping_static.py script/tools/test_mainline_task_runtime_smoke.lua
git commit -m "test: lock missing mainline task reward coverage"
```

### Task 2: Normalize All Supported Reward Lines From The Object Table

**Files:**
- Modify: `script/data/object_tables/mainline_task_rewards.lua`
- Test: `script/tools/test_mainline_task_reward_mapping_static.py`

- [ ] **Step 1: Update the object table to pass through `attack_skill` effects**

Add a dedicated branch inside `build_reward_lines(row)`:

```lua
    elseif effect.effect_kind == 'attack_skill' then
      lines[#lines + 1] = {
        slot = effect.order_index,
        type = 'attack_skill',
        key = effect.effect_key,
        value = effect.value,
      }
```

Place it before the final `else error(...)` branch.

- [ ] **Step 2: Keep runtime keys in canonical form instead of forcing everything through legacy attr aliases**

Adjust the `attr` effect branch so canonical runtime-like keys that are currently stored in `attreffect.lua` as `attr` can still produce `type = 'runtime'` lines:

```lua
    if effect.effect_kind == 'attr' then
      local legacy_attr_key = LEGACY_ATTR_KEY_BY_CANONICAL_ATTR[effect.effect_key]
      if legacy_attr_key ~= nil then
        lines[#lines + 1] = {
          slot = effect.order_index,
          type = 'attr',
          key = legacy_attr_key,
          value = effect.value,
        }
      else
        local legacy_runtime_key = LEGACY_RUNTIME_KEY_BY_CANONICAL_ATTR[effect.effect_key]
        assert(legacy_runtime_key ~= nil, 'unsupported canonical mainline attr key: ' .. tostring(effect.effect_key))
        lines[#lines + 1] = {
          slot = effect.order_index,
          type = 'runtime',
          key = legacy_runtime_key,
          value = effect.value,
        }
      end
```

Do not rename existing legacy keys in this task; keep the change minimal so the runtime task can consume both old and newly-passed kinds.

- [ ] **Step 3: Run the static test to verify object-table coverage now passes its half**

Run: `py script/tools/test_mainline_task_reward_mapping_static.py`
Expected: Still FAIL, but no longer because `mainline_task_rewards.lua` drops `attack_skill`.

- [ ] **Step 4: Run the loader smoke to ensure object-table loading still works**

Run: `lua script/tools/test_mainline_task_rewards_csv_loader_smoke.lua`
Expected: PASS

- [ ] **Step 5: Commit the normalization changes**

```bash
git add script/data/object_tables/mainline_task_rewards.lua script/tools/test_mainline_task_reward_mapping_static.py
git commit -m "feat: normalize all mainline task reward kinds"
```

### Task 3: Expand The Mainline Runtime Reward Dispatcher

**Files:**
- Modify: `script/runtime/mainline_tasks.lua`
- Test: `script/tools/test_mainline_task_runtime_smoke.lua`
- Test: `script/tools/test_mainline_task_reward_mapping_static.py`

- [ ] **Step 1: Introduce stable runtime reward buckets in `mainline_tasks.lua`**

Inside `ensure_runtime()`, keep the existing fields and add a dedicated applied bonus cache:

```lua
      applied_runtime_bonus = {},
      applied_attack_skill_bonus = {},
```

Also add a helper near the top of the module:

```lua
  local function ensure_skill_runtime_bucket()
    STATE.skill_runtime = STATE.skill_runtime or {}
    return STATE.skill_runtime
  end
```

- [ ] **Step 2: Extract state reward execution into a helper**

Add this helper before `api.apply_task_rewards(task)`:

```lua
  local function apply_state_reward(line, runtime)
    if line.key == 'skill_point' then
      STATE.skill_points = (STATE.skill_points or 0) + (tonumber(line.value) or 0)
      return true
    end
    if line.key == 'hero_card' then
      runtime.hero_card_count = (runtime.hero_card_count or 0) + (tonumber(line.value) or 0)
      return true
    end
    return false
  end
```

- [ ] **Step 3: Extract runtime reward execution into a helper**

Add a whitelist map and helper:

```lua
  local DIRECT_SKILL_RUNTIME_KEYS = {
    chain_bounces = true,
    skill_echo_chance = true,
    multishot_count = true,
    multishot_bonus = true,
    boss_damage_bonus = true,
    elite_damage_bonus = true,
    gold_per_sec_bonus = true,
    kill_reward_ratio = true,
  }

  local function apply_runtime_reward(line, runtime, attr_pack)
    if RUNTIME_ATTR_KEY_MAP[line.key] ~= nil then
      return apply_runtime_reward_to_attr_pack(line, attr_pack)
    end
    if DIRECT_SKILL_RUNTIME_KEYS[line.key] then
      local bucket = ensure_skill_runtime_bucket()
      local value = tonumber(line.value) or 0
      bucket[line.key] = (bucket[line.key] or 0) + value
      runtime.applied_runtime_bonus[line.key] = (runtime.applied_runtime_bonus[line.key] or 0) + value
      return true
    end
    error('unsupported mainline runtime reward key: ' .. tostring(line.key))
  end
```

Rename the current `apply_runtime_reward(line, attr_pack)` helper to:

```lua
  local function apply_runtime_reward_to_attr_pack(line, attr_pack)
```

and update its call sites accordingly.

- [ ] **Step 4: Extract attack-skill reward execution into a helper**

Add:

```lua
  local function apply_attack_skill_reward(line, runtime)
    local attack_state = STATE.attack_skill_state
    if not attack_state or not attack_state.by_id then
      return false
    end
    local value = tonumber(line.value) or 0
    for _, skill in pairs(attack_state.by_id) do
      skill[line.key] = (skill[line.key] or 0) + value
    end
    runtime.applied_attack_skill_bonus[line.key] = (runtime.applied_attack_skill_bonus[line.key] or 0) + value
    return true
  end
```

- [ ] **Step 5: Switch `api.apply_task_rewards(task)` to the new dispatcher**

Replace the current inner reward loop with:

```lua
    for _, line in ipairs(task.reward_lines or {}) do
      if line.type == 'attr' then
        apply_attr_reward(line, attr_pack)
      elseif line.type == 'runtime' then
        apply_runtime_reward(line, runtime, attr_pack)
      elseif line.type == 'resource' then
        reward_pack[line.key] = (reward_pack[line.key] or 0) + (tonumber(line.value) or 0)
      elseif line.type == 'state' then
        assert(apply_state_reward(line, runtime), 'unsupported mainline state reward key: ' .. tostring(line.key))
      elseif line.type == 'special' then
        -- keep the existing treasure / skill_point / hero_card compat handling only if still needed
      elseif line.type == 'attack_skill' then
        assert(apply_attack_skill_reward(line, runtime), 'unsupported mainline attack skill reward key: ' .. tostring(line.key))
      else
        error('unsupported mainline reward type: ' .. tostring(line.type))
      end
    end
```

Keep the existing `special` compatibility branch for old CSV entries such as `treasure_choice`.

- [ ] **Step 6: Run the static and smoke tests to verify they now pass**

Run: `py script/tools/test_mainline_task_reward_mapping_static.py`
Expected: PASS

Run: `lua script/tools/test_mainline_task_runtime_smoke.lua`
Expected: PASS

- [ ] **Step 7: Commit the runtime dispatcher**

```bash
git add script/runtime/mainline_tasks.lua script/tools/test_mainline_task_runtime_smoke.lua script/tools/test_mainline_task_reward_mapping_static.py
git commit -m "feat: execute complete mainline task reward kinds"
```

### Task 4: Full Reward Regression

**Files:**
- Modify: `script/tools/test_mainline_task_runtime_smoke.lua` (if any cleanup is needed)
- Test: `script/tools/test_mainline_task_rewards_csv_loader_smoke.lua`
- Test: `script/tools/test_mainline_task_boot_integration_static.py`

- [ ] **Step 1: Run the reward loader smoke**

Run: `lua script/tools/test_mainline_task_rewards_csv_loader_smoke.lua`
Expected: PASS

- [ ] **Step 2: Run the boot integration static**

Run: `py script/tools/test_mainline_task_boot_integration_static.py`
Expected: PASS

- [ ] **Step 3: Run the packaging statics to ensure the recent copy/runtime rename work stays intact**

Run: `py script/tools/test_runtime_api_packaging_static.py`
Expected: PASS

Run: `py script/tools/test_runtime_copy_packaging_static.py`
Expected: PASS

- [ ] **Step 4: Run the mainline runtime smoke one last time**

Run: `lua script/tools/test_mainline_task_runtime_smoke.lua`
Expected: PASS with `[OK] mainline task runtime smoke passed`

- [ ] **Step 5: Commit the verified end state**

```bash
git add script/runtime/mainline_tasks.lua script/data/object_tables/mainline_task_rewards.lua script/tools/test_mainline_task_runtime_smoke.lua script/tools/test_mainline_task_reward_mapping_static.py
git commit -m "test: verify complete mainline task reward execution"
```

## Self-Review

- Spec coverage:
  - `attr / resource / state / runtime / attack_skill` reward support is covered by Tasks 2 and 3.
  - Static consistency coverage is covered by Task 1 and Task 3.
  - Runtime reward smoke coverage is covered by Task 1 and Task 4.
- Placeholder scan:
  - No `TODO` / `TBD` placeholders remain.
  - Each task includes concrete file paths, commands, and code snippets.
- Type consistency:
  - Runtime helper names are consistent: `apply_state_reward`, `apply_runtime_reward`, `apply_attack_skill_reward`.
  - Reward line kinds stay aligned with the spec and the current object-table schema.
