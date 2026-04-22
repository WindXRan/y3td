# Runtime HUD Semantics

This file documents the semantic bridge between the current editor UI assets and the Lua runtime HUD bindings.

## Current Battle HUD Layers

- `top.top.layout_2`
  - active top resource / wave / boss / stage / game-time container
- `bottom_bg.bottom_bg`
  - active bottom battle panel shell
- `GameHUD.main.inventory`
  - legacy real item-slot controls (`type_20`)
- `GameHUD.main.skill_list`
  - legacy engine skill-button controls (`type_17`), now treated as compatibility-only

## Bottom Prefab Semantic Mapping

- `技能栏.物品2 .. 物品2_20`
  - decorative slot hosts for runtime skill overlays
- `layout_1.backpack.*`
  - decorative slot hosts for runtime/legacy inventory overlays
- `layout_1.mid.panel.*`
  - preferred rich stat labels
- `layout_1.mid.bg_3.shuxing*`
  - compact stat fallback labels

## Refactor Rule

- Runtime code should bind through `ui.runtime_hud_editor_schema`.
- Editor node names can stay legacy/ugly, but Lua should only depend on semantic schema entries instead of scattering raw paths across files.
