# Growth Weapon Editor UI Swap Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace the code-created growth weapon slot and tip panel with bindings to existing editor-authored `GameHUD` and `物品说明` UI resources.

**Architecture:** Keep `runtime/gear_upgrades.lua` as the single payload source, but stop constructing any new growth-weapon UI in Lua. Instead, bind hover events to an existing `GameHUD` equip slot and fill the existing `物品说明` panel nodes from the shared payload.

**Tech Stack:** Lua runtime UI bindings, editor-authored Y3 UI JSON resources, Python/Lua smoke/static tests.

---

### Task 1: Lock editor UI paths with tests

**Files:**
- Create: `maps/EntryMap/script/tools/test_editor_growth_weapon_ui_paths_static.py`
- Modify: `maps/EntryMap/script/tools/test_runtime_hud_growth_weapon_tip_static.py`

- [ ] Write a failing static test for the chosen editor HUD slot path and `物品说明` node paths.
- [ ] Run it and confirm it fails before code changes.
- [ ] Update existing static coverage so it expects editor-path binding rather than dynamic panel creation.
- [ ] Re-run the static tests until they pass.

### Task 2: Replace dynamic tip panel with editor tip binding

**Files:**
- Delete: `maps/EntryMap/script/ui/growth_weapon_tip_panel.lua`
- Create: `maps/EntryMap/script/ui/growth_weapon_item_tip.lua`
- Modify: `maps/EntryMap/script/ui/runtime_hud.lua`

- [ ] Write a failing test or static assertion for the new editor-tip binding file references.
- [ ] Run it and confirm it fails before implementation.
- [ ] Implement a binder that resolves existing `物品说明` nodes and fills title, subtitle, icon, attr list, and affix area from the shared payload.
- [ ] Remove the dynamic panel creation path from `runtime_hud.lua`.
- [ ] Re-run the new and updated tests until they pass.

### Task 3: Bind the existing editor growth-weapon slot

**Files:**
- Modify: `maps/EntryMap/script/ui/runtime_hud.lua`
- Modify: `maps/EntryMap/script/runtime/boot.lua`

- [ ] Write a failing static test for the chosen existing `GameHUD` equip-slot path used as the growth weapon slot.
- [ ] Run it and confirm it fails before implementation.
- [ ] Bind hover events to the editor-authored slot instead of creating a new Lua slot.
- [ ] Keep the default item-bar hover integration, but route both HUD and bar hover to the same editor-authored tip presenter.
- [ ] Re-run static and smoke tests until they pass.

### Task 4: Full verification

**Files:**
- Modify: `maps/EntryMap/script/tools/test_runtime_gear_upgrades_smoke.py`
- Modify: `maps/EntryMap/script/tools/test_session_state_grants_level1_weapon_smoke.py`

- [ ] Run syntax checks for touched Lua files.
- [ ] Run existing growth weapon smoke tests.
- [ ] Run new static editor-path tests.
- [ ] Confirm the dynamic panel file is no longer referenced.
