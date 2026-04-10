# Hero Attribute System Design

**Date:** 2026-04-10

**Goal**

Build a unified hero attribute system for the current Y3 project so that all attributes shown in the reference panel become writable, stackable, readable, and persistable hero-side attributes. The new system uses the new Chinese attribute names as the canonical standard, while old names remain supported through compatibility aliases during migration.

**Project Context**

The project currently has a small set of unit attributes defined in [attr.json](/c:/Y3TD/Y3GPT/ProjectName002/attr.json) and [maps/EntryMap/attr.json](/c:/Y3TD/Y3GPT/ProjectName002/maps/EntryMap/attr.json), while gameplay logic directly reads and writes a limited set of runtime attributes across [boot.lua](/c:/Y3TD/Y3GPT/ProjectName002/maps/EntryMap/script/runtime/boot.lua), [battlefield.lua](/c:/Y3TD/Y3GPT/ProjectName002/maps/EntryMap/script/runtime/battlefield.lua), [attack_skills.lua](/c:/Y3TD/Y3GPT/ProjectName002/maps/EntryMap/script/runtime/attack_skills.lua), [bonds_chain.lua](/c:/Y3TD/Y3GPT/ProjectName002/maps/EntryMap/script/runtime/bonds_chain.lua), [auto_active_effects.lua](/c:/Y3TD/Y3GPT/ProjectName002/maps/EntryMap/script/runtime/auto_active_effects.lua), and [overview_model.lua](/c:/Y3TD/Y3GPT/ProjectName002/maps/EntryMap/script/runtime/overview_model.lua).

The requested target is broader than the current project state: every attribute shown in the provided panel must become part of a unified hero attribute pipeline that supports:

- direct hero-side read and write
- additive stacking from systems such as bonds, rewards, and temporary effects
- derived formula recomputation
- panel display
- runtime state persistence

## Decisions

### Canonical Naming

Use the new panel names as the canonical names throughout the new system.

Examples:

- `攻击` is canonical, not `物理攻击`
- `生命` is canonical, not `最大生命`
- `物理暴击` is canonical, not `暴击率`
- `物理暴伤` is canonical, not `暴击伤害`

Existing names remain readable and writable during migration through alias normalization, but new code and documentation must use the new names only.

### System Shape

Adopt a single-source attribute registry plus a unified runtime attribute service.

The registry defines:

- canonical name
- category
- display order
- display format
- whether the attribute is a ratio
- whether the attribute is persisted
- whether the attribute participates in derived recomputation
- compatibility aliases

The runtime service handles:

- name normalization
- default initialization
- read and write helpers
- derived recomputation
- kill-growth application
- per-second growth application
- damage multiplier queries
- defense-side damage reduction

### Migration Strategy

Use a compatibility-first migration.

Do not replace every old attribute reference in one pass. Introduce the new system first, keep old names readable through aliases, and then progressively route combat logic and UI through the unified service.

This reduces breakage risk in runtime systems that currently write directly to hero unit attributes.

## Attribute Model

All attributes are still hero-side readable and writable values. The difference is that the new system assigns fixed semantics to groups of attributes.

### Group 1: Core Writable Attributes

These are direct hero attributes and can be changed by rewards, bonds, treasure, buffs, events, or scripted effects.

- `力量`
- `敏捷`
- `智力`
- `攻击`
- `生命`
- `护甲`
- `攻击间隔`
- `攻击范围`
- `命中`
- `物理暴击`
- `物理暴伤`
- `魔法暴击`
- `魔法暴伤`
- `物理伤害`
- `魔法伤害`
- `普攻伤害`
- `技能伤害`
- `所有伤害`
- `最终伤害`
- `无视护甲`
- `护甲穿透`
- `多重数量`
- `多重伤害`
- `弹射次数`
- `弹射伤害`
- `格挡`
- `闪避`
- `生命恢复`
- `伤害减免`
- `闪避恢复`
- `杀敌恢复`
- `控制时长`
- `杀敌经验`
- `杀敌加成`
- `杀敌木材`
- `杀敌金币`
- `每秒经验`
- `每秒木材`
- `每秒金币`
- `每秒杀敌`
- `力量增幅`
- `敏捷增幅`
- `智力增幅`
- `攻击增幅`
- `生命增幅`
- `护甲增幅`
- `每秒攻击`
- `每秒力量`
- `每秒敏捷`
- `每秒智力`
- `每秒生命`
- `杀敌攻击`
- `杀敌力量`
- `杀敌敏捷`
- `杀敌智力`
- `杀敌生命`
- `杀敌护甲`
- `最终力量`
- `最终敏捷`
- `最终智力`
- `最终攻击`
- `最终生命`
- `最终护甲`
- `物系伤害`
- `火系伤害`
- `电系伤害`
- `精控伤害`
- `燃烧伤害`
- `百分比恢复`
- `穿透次数`
- `能量伤害`
- `冰系伤害`
- `风系伤害`
- `挑战伤害`
- `冻结伤害`
- `恢复效果`
- `卡牌增幅`

### Group 2: Growth Attributes

These are still normal hero attributes, but the system gives them event-driven meaning.

- `每秒攻击`
- `每秒力量`
- `每秒敏捷`
- `每秒智力`
- `每秒生命`
- `每秒经验`
- `每秒金币`
- `每秒木材`
- `每秒杀敌`
- `杀敌攻击`
- `杀敌力量`
- `杀敌敏捷`
- `杀敌智力`
- `杀敌生命`
- `杀敌护甲`
- `杀敌经验`
- `杀敌金币`
- `杀敌木材`
- `杀敌加成`

### Group 3: Derived Output Attributes

These remain stored hero-side, not merely displayed, but are recomputed by the attribute service from the canonical inputs.

- `最终力量`
- `最终敏捷`
- `最终智力`
- `最终攻击`
- `最终生命`
- `最终护甲`

These values are written back onto the hero after recomputation so that all gameplay systems can read them directly.

## Compatibility Aliases

The first implementation stage must support at least the following alias normalization:

| Old Name | Canonical Name |
|---|---|
| `物理攻击` | `攻击` |
| `最大生命` | `生命` |
| `暴击率` | `物理暴击` |
| `暴击伤害` | `物理暴伤` |
| `物理吸血` | `物理吸血` |

Additional aliases can be added as they are discovered during migration.

The rule is simple:

- new code writes canonical names only
- old code may continue to read and write old names
- the runtime service normalizes old names to canonical names

## Categories And UI Sections

The registry must classify attributes into the same five panel groups used by the target design:

- `伤害属性`
- `防守属性`
- `资源属性`
- `增幅属性`
- `其他属性`

Each attribute definition must include:

- `category`
- `display_name`
- `order`
- `format`

Supported display formats:

- integer
- fixed1
- fixed2
- percent
- percent_or_zero

The attribute panel must become registry-driven instead of manually listing a small hard-coded subset.

## Unified Formula Rules

### Ratio Normalization

Ratio-like attributes accept both percent-style values and decimal-style values.

Examples:

- `13` means `13%`
- `0.13` also means `13%`

This matches the current project behavior pattern used in UI helpers.

### Derived Primary Stats

The new system computes derived primary outputs in this order:

1. `最终力量 = 力量 * (1 + 力量增幅) * (1 + 最终力量)`
2. `最终敏捷 = 敏捷 * (1 + 敏捷增幅) * (1 + 最终敏捷)`
3. `最终智力 = 智力 * (1 + 智力增幅) * (1 + 最终智力)`

Interpretation:

- `力量`, `敏捷`, `智力` are the base pools
- `力量增幅`, `敏捷增幅`, `智力增幅` scale those pools
- `最终力量`, `最终敏捷`, `最终智力` act as final-stage percent multipliers during recomputation, and the resolved values are then written back to the hero

Implementation detail:

The runtime service must distinguish between the raw final multiplier inputs and the resolved final output values to avoid self-referential recomputation loops. The registry should therefore store metadata identifying which attributes are final-stage inputs and which are resolved outputs.

### Derived Combat Values

Recommended default formulas:

`攻击结算值 = (攻击 + 最终力量 * 0.1 + 最终敏捷 * 0.1 + 最终智力 * 0.1) * (1 + 攻击增幅) * (1 + 最终攻击)`

`生命结算值 = (生命 + 最终力量 * 1.0) * (1 + 生命增幅) * (1 + 最终生命)`

`护甲结算值 = (护甲 + 最终敏捷 * 0.0) * (1 + 护甲增幅) * (1 + 最终护甲)`

Reasons for these defaults:

- the project already describes multiple routes where each point of Strength, Agility, or Intelligence can contribute extra attack
- Strength-to-life is useful immediately and matches the desired panel semantics
- Agility-to-armor is kept at zero initially to avoid silently changing the current project balance before the new system is verified

The actual resolved results are written back to:

- `最终攻击`
- `最终生命`
- `最终护甲`

### Damage Multipliers

Damage uses a layered multiplier model.

Base damage source:

- normal attacks use `最终攻击`
- skill scripts may provide explicit base values
- adaptive sources may choose the most appropriate stat-based source if explicitly designed to do so

Attacker-side multiplier order:

`伤害结果 = 基础伤害 * (1 + 类型伤害) * (1 + 来源伤害) * (1 + 所有伤害) * (1 + 最终伤害)`

Where:

- `类型伤害` is one of `物理伤害`, `魔法伤害`, `火系伤害`, `冰系伤害`, `风系伤害`, `电系伤害`, `能量伤害`, `燃烧伤害`, `冻结伤害`, `挑战伤害`, or other explicitly routed kinds
- `来源伤害` is `普攻伤害` for basic attacks or `技能伤害` for skill-driven damage
- `所有伤害` always applies
- `最终伤害` applies last on the attacker side

### Critical Strikes

Critical logic is source-specific:

- physical sources use `物理暴击` and `物理暴伤`
- magic sources use `魔法暴击` and `魔法暴伤`

Critical resolution occurs after attacker-side multiplier construction and before defender-side mitigation.

### Defense-Side Mitigation

The defense pipeline should be:

1. apply `无视护甲` and `护甲穿透` against the target armor
2. apply physical armor mitigation for physical damage
3. apply `伤害减免`
4. resolve block, dodge, or other special defensive checks if the damage kind allows them

Rules:

- `护甲` only participates in physical mitigation
- `伤害减免` applies to all relevant damage kinds
- `格挡` and `闪避` are event-driven defensive checks, not simple linear multipliers
- `控制时长` is a control-effect scalar and is not part of direct damage mitigation

### Recovery

The following attributes affect recovery systems:

- `生命恢复`
- `百分比恢复`
- `恢复效果`
- `杀敌恢复`
- `闪避恢复`

First-stage support requirement:

- these attributes must be writable, persistable, and displayable
- direct hero healing logic must at minimum be able to query them through the runtime service

### Per-Second Growth

On each periodic tick:

- `每秒攻击` adds into `攻击`
- `每秒力量` adds into `力量`
- `每秒敏捷` adds into `敏捷`
- `每秒智力` adds into `智力`
- `每秒生命` adds into `生命`
- `每秒经验` adds into player or session experience state
- `每秒金币` adds into resource state
- `每秒木材` adds into resource state
- `每秒杀敌` adds into kill-related state

After any primary combat stat changes, the runtime service must trigger derived recomputation.

### Kill Growth

On each valid kill:

- `杀敌攻击` adds into `攻击`
- `杀敌力量` adds into `力量`
- `杀敌敏捷` adds into `敏捷`
- `杀敌智力` adds into `智力`
- `杀敌生命` adds into `生命`
- `杀敌护甲` adds into `护甲`
- `杀敌经验` increases kill-derived experience reward
- `杀敌金币` increases kill-derived gold reward
- `杀敌木材` increases kill-derived wood reward
- `杀敌加成` increases kill-derived scaling through the existing reward pipeline

After any combat stat changes from kills, the runtime service must trigger derived recomputation.

## Proposed Runtime File Layout

### New Files

Create:

- `maps/EntryMap/script/runtime/hero_attr_defs.lua`
- `maps/EntryMap/script/runtime/hero_attr_system.lua`
- `docs/hero-attributes.md`

### Existing Files To Integrate

Modify:

- `maps/EntryMap/script/runtime/boot.lua`
- `maps/EntryMap/script/runtime/battlefield.lua`
- `maps/EntryMap/script/runtime/attack_skills.lua`
- `maps/EntryMap/script/runtime/bonds_chain.lua`
- `maps/EntryMap/script/runtime/auto_active_effects.lua`
- `maps/EntryMap/script/runtime/overview_model.lua`
- `maps/EntryMap/script/ui/runtime_hud_panel1_top.lua`
- optionally `maps/EntryMap/attr.json`

## Runtime Service Responsibilities

### `hero_attr_defs.lua`

Must provide:

- complete attribute registry
- category membership
- display order
- display formats
- alias table
- flags such as `is_ratio`, `persist`, `derived_input`, `derived_output`

### `hero_attr_system.lua`

Must provide:

- canonical name normalization
- default attribute pack generation
- hero initialization
- safe get and set wrappers
- additive updates
- derived recomputation
- kill growth application
- per-second growth application
- damage multiplier resolution
- defense mitigation resolution

## Integration Plan By Subsystem

### Hero Creation

When the hero is created in [battlefield.lua](/c:/Y3TD/Y3GPT/ProjectName002/maps/EntryMap/script/runtime/battlefield.lua), initialize the full attribute pack, then resolve derived outputs before starting combat.

### Boot And Shared Damage Helpers

The shared damage path in [boot.lua](/c:/Y3TD/Y3GPT/ProjectName002/maps/EntryMap/script/runtime/boot.lua) should delegate attacker-side and defender-side multiplier logic to the new attribute system instead of directly relying on ad hoc stat reads.

### Bonds

The bond system in [bonds_chain.lua](/c:/Y3TD/Y3GPT/ProjectName002/maps/EntryMap/script/runtime/bonds_chain.lua) should continue awarding direct stats, but must route all writes through canonical attribute names. Per-second and kill-growth effects should reuse the central service rather than maintaining separate special-case logic.

### Temporary Effects

[auto_active_effects.lua](/c:/Y3TD/Y3GPT/ProjectName002/maps/EntryMap/script/runtime/auto_active_effects.lua) currently applies temporary bonus packs directly to unit attributes. This remains valid, but name normalization and derived recomputation must go through the central service.

### Attack Skills

[attack_skills.lua](/c:/Y3TD/Y3GPT/ProjectName002/maps/EntryMap/script/runtime/attack_skills.lua) should migrate from reading old attack names toward canonical values, and should use the central service for skill or attack damage multipliers.

### UI

[overview_model.lua](/c:/Y3TD/Y3GPT/ProjectName002/maps/EntryMap/script/runtime/overview_model.lua) should stop hand-picking a tiny set of stats. Instead, it should query the registry and generate grouped sections by category.

[runtime_hud_panel1_top.lua](/c:/Y3TD/Y3GPT/ProjectName002/maps/EntryMap/script/ui/runtime_hud_panel1_top.lua) should read the canonical resource-growth attributes through the central service.

## Persistence

The design requires unified persistence, but the project currently mixes unit-state reads with runtime `STATE` tables.

Use a dual-layer persistence model:

- hero unit attributes remain the live source for combat
- `STATE.hero_attr_runtime` stores a normalized snapshot for process-level recovery and later save integration

Persist at minimum:

- base core attributes
- growth attributes
- resolved derived outputs
- resource-growth attributes

Do not rely exclusively on panel display caches for persistence.

## Validation Requirements

The implementation must verify:

- new hero initialization writes every registered attribute
- old names correctly normalize to canonical names
- derived recomputation produces stable values
- per-second growth updates the correct canonical pools
- kill growth updates the correct canonical pools
- damage helpers correctly apply attacker-side and defender-side multipliers
- the attribute panel displays grouped canonical values in the expected order

## Approach Options Considered

### Option 1: Unified Registry Plus Compatibility Layer

This is the chosen approach.

Pros:

- lowest migration risk
- supports gradual integration
- keeps old systems functioning while new names become canonical
- centralizes formulas and UI formatting

Cons:

- requires alias maintenance during migration
- introduces a normalization layer before full cleanup

### Option 2: One-Pass Full Rename And Rewrite

Pros:

- clean end state immediately

Cons:

- high breakage risk
- touches too many runtime systems at once
- harder to verify incrementally

### Option 3: Panel-Only Expansion

Pros:

- quick to deliver

Cons:

- does not meet the requirement that all attributes be hero-side writable, stackable, and persistable

## Open Scope Boundaries

To keep the implementation tractable, the first implementation stage will fully support:

- canonical registry
- aliases
- initialization
- persistence snapshot
- growth application
- UI display
- core combat formulas for attack, life, armor, physical damage, magic damage, skill damage, all damage, and final damage

Element-specific or specialty stats such as `火系伤害`, `电系伤害`, `冻结伤害`, `卡牌增幅`, and `穿透次数` will be registered immediately and become writable, persistable, and displayable in stage one. They may remain lightly integrated into actual combat routing until the relevant gameplay effects explicitly consume them.

This does not violate the requirement because the hero-side unified attribute layer still exists for all of them from the start.

## Implementation Readiness

This spec is ready to hand off into a detailed implementation plan. The implementation should use the canonical new attribute names everywhere new code is written, keep old names only as read and write compatibility aliases, and migrate combat and UI subsystems incrementally through the central attribute service.
