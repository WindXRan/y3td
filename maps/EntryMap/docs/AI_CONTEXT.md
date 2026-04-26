# AI Context

This Y3 map is large. To reduce input token usage, do not scan the whole
project by default. Start from the specific task, then read only the smallest
set of files needed.

## Default Reading Rules

- Prefer editing targeted files over rewriting whole files.
- Do not reread a file that has already been read in the current task unless it
  was edited or the exact line context is needed again.
- Keep final output concise. Keep reasoning and validation thorough while
  working.
- Prefer `rg` / `rg --files` to locate files before opening content.
- Keep project-owned code files at or below 400 lines and four nesting levels.
  Before broad code work,
  run `python script/tools/check_code_line_limits.py`.
- Do not read large generated JSON directories unless the user names the
  object type, id, file, UI layer, or exact feature.
- Do not read binary assets, screenshots, exported map packages, cache files,
  or localization tables unless the task explicitly requires them.
- For Lua gameplay work, start with `script/main.lua`, `script/entry_runtime.lua`,
  `script/entry_runtime_outgame.lua`, `script/entry_config.lua`, or a file found
  by `rg` for the requested feature.
- For UI work, locate the relevant `ui/*.json` file first, then read only that
  file and the matching `ui_tree` file if Lua node lookup is needed.
- For object editor work, locate by object id/name first and read only the
  matching file under `ability/`, `modifier/`, `unit/`, `item/`, or `projectile/`.

## High-Cost Areas

Avoid default full reads of:

- `ability/`, `modifier/`, `unit/`, `item/`, `projectile/`
- `ui/`, `ui_tree/`, `editor/`, `editor_table/`
- `global_trigger/`, `ui_trigger/`, `custom_eca/`
- `script/docs/` image references
- `*.gmp`, images, cache folders, and `*language.json`

## Code Standard Scope

The 400-line and four-level nesting limits apply to project-owned code under
`script/runtime/`,
`script/ui/`, and `script/tools/`. Bundled Y3 libraries, helper metadata, and
generated object data under `script/y3/`, `script/y3-helper/`, and
`script/data/object_tables/` are excluded from the default check because
splitting them can break upstream compatibility or generated data sync.

## Recommended Prompt Style

Use targeted requests such as:

```text
只看 script/entry_runtime.lua，修复局内计时逻辑。
```

```text
根据 UI 文件 ui/BattleBottomHUD.json 和对应 ui_tree，绑定按钮点击事件。
```

```text
只检查 ability/134278987.json 的技能数值，不要扫描全部物编。
```
