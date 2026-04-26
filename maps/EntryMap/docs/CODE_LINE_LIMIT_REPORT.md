# Code Line Limit Report

Run:

```bash
python script/tools/check_code_line_limits.py
```

The check enforces:

- Files must be no more than 400 lines.
- Lua and Python files must stay within four nesting levels.

Current project-owned code files over 400 lines: none.

Current Lua/Python files over four nesting levels:

| Nesting | File |
|---:|---|
| 13 | `script/ui/runtime_hud.lua` |
| 9 | `script/tools/file_listener.py` |
| 8 | `script/tools/log_listener.py` |
| 6 | `script/tools/game_run_check.py` |
| 5 | `script/ui/outgame.lua` |
| 5 | `script/tools/test_bond_stage_tiers_static.py` |
| 5 | `script/tools/sync_runtime_editor_objects.py` |
| 5 | `script/tools/lua_executor.py` |
| 5 | `script/tools/install_y3helper_runlua.py` |
| 5 | `script/tools/game_control.py` |
| 5 | `script/tools/config.py` |
| 5 | `script/tools/build_bond_choice_panels.py` |
| 5 | `script/runtime/rewards.lua` |
| 5 | `script/runtime/mainline_tasks.lua` |
| 5 | `script/runtime/gear_upgrades.lua` |
| 5 | `script/runtime/bonds_chain.lua` |
| 5 | `script/runtime/battlefield.lua` |
| 5 | `script/runtime/attack_skills.lua` |
| 5 | `script/data/csv_loader.lua` |

Excluded from the default line-limit check:

- Bundled Y3 library and API metadata: `script/y3/`
- Helper metadata: `script/y3-helper/`
- Generated object table data: `script/data/object_tables/`
- Visual/reference docs: `script/docs/`

Refactor order should start with UI/runtime files that are frequently edited,
then tools and smoke tests. Split one module at a time and run the relevant
smoke tests after each split.

Completed splits:

- `script/tools/heartbeat_monitor.py` -> `script/tools/heartbeat_comm.py`
- `script/tools/rebuild_outgame_ui.py` -> `script/tools/ui_node_builders.py`
- `script/ui/outgame.lua` static definitions -> `script/ui/outgame_defs.lua`
- `script/ui/outgame.lua` archive state -> `script/ui/outgame_archive_state.lua`
- `script/ui/outgame.lua` UI safe ops -> `script/ui/ui_safe_ops.lua`
- `script/ui/outgame.lua` stage index -> `script/ui/outgame_stage_index.lua`
- `script/tools/test_runtime_editor_object_sync.py` constants -> `script/tools/runtime_editor_object_sync_defs.py`
- `script/tools/test_basic_attack_extra_targets_smoke.py` inline Lua smoke scripts -> shared fixture builder
