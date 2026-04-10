# Hero Attributes

## Canonical Names

The unified hero attribute system uses the new panel names as canonical names.

- `攻击`
- `生命`
- `护甲`
- `力量`
- `敏捷`
- `智力`
- `物理暴击`
- `物理暴伤`
- `魔法暴击`
- `魔法暴伤`
- `物理伤害`
- `魔法伤害`
- `技能伤害`
- `所有伤害`
- `最终伤害`

## Compatibility Aliases

Legacy names remain readable during migration:

- `物理攻击 -> 攻击`
- `最大生命 -> 生命`
- `暴击率 -> 物理暴击`
- `暴击伤害 -> 物理暴伤`
- `命中率 -> 命中`
- `BOSS伤害 -> 挑战伤害`
- `精英伤害 -> 精控伤害`
- `冻伤伤害 -> 冻结伤害`

## Derived Formulas

- `最终力量 = 力量 * (1 + 力量增幅) * (1 + 最终力量增幅)`
- `最终敏捷 = 敏捷 * (1 + 敏捷增幅) * (1 + 最终敏捷增幅)`
- `最终智力 = 智力 * (1 + 智力增幅) * (1 + 最终智力增幅)`
- `最终攻击` 是最终结算乘区百分比属性。
- `攻击结算值 = (攻击 + 最终力量 * 0.1 + 最终敏捷 * 0.1 + 最终智力 * 0.1) * (1 + 攻击增幅) * (1 + 最终攻击)`
- `最终生命` 是最终结算乘区百分比属性。
- `最终护甲` 是最终结算乘区百分比属性。
- `生命结算值 = (生命 + 最终力量) * (1 + 生命增幅) * (1 + 最终生命)`
- `护甲结算值 = 护甲 * (1 + 护甲增幅) * (1 + 最终护甲)`

## Runtime Modules

- Registry: `maps/EntryMap/script/runtime/hero_attr_defs.lua`
- Service: `maps/EntryMap/script/runtime/hero_attr_system.lua`

## Current Integration

- Hero creation initializes canonical attributes through the service.
- Reward-side hero attribute packs now rebuild derived values after application.
- Attack skill core damage reads use `攻击结算值`.
- Overview summary now prefers canonical final values.
- Runtime snapshots are stored in `STATE.hero_attr_runtime`.
