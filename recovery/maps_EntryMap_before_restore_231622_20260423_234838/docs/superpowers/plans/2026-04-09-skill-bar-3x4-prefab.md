# Skill Bar 3x4 Prefab Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add a reusable `3x4` skill-bar prefab for the Y3 editor and register it in the editor prefab tree.

**Architecture:** Create one standalone editor prefab at `ui/prefab/skill_bar_3x4.json` with a stable node naming scheme for 12 slots. Register its prefab key in `editor/uiprefabtreegroupinfo.json`, and validate the resource with a small JSON-structure test.

**Tech Stack:** Y3 UI prefab JSON, editor prefab tree JSON, Python pytest

---

### Task 1: Add a failing prefab validation test

**Files:**
- Create: `script/tools/test_skill_bar_3x4_prefab.py`

- [ ] **Step 1: Write the failing test**
- [ ] **Step 2: Run the test and verify it fails because the prefab is missing**

### Task 2: Add the prefab and register it

**Files:**
- Create: `ui/prefab/skill_bar_3x4.json`
- Modify: `editor/uiprefabtreegroupinfo.json`

- [ ] **Step 1: Create the prefab root and 12 skill slots**
- [ ] **Step 2: Register the prefab key in the editor prefab tree**

### Task 3: Verify structure

**Files:**
- Test: `script/tools/test_skill_bar_3x4_prefab.py`

- [ ] **Step 1: Re-run the prefab validation test**
- [ ] **Step 2: Confirm the prefab can be discovered from the editor registry**
