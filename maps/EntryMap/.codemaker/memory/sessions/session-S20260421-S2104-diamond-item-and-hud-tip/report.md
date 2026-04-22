# 会话补充记录

- 排查发现英雄创建时在 `runtime/battlefield.lua` 中被加了 `禁止普攻` 状态，已移除该状态以恢复英雄普攻能力。
- 排查发现底部技能栏与装备栏为空，主要原因是 `ui/runtime_hud.lua` 仍绑定旧 `GameHUD` 路径；已开始迁移到底部 `bottom_bg` prefab，当前已将 `growth_weapon_slot` 与 `skill_slots[1..4]` 优先改为使用 `bottom_bg` 的节点来源。
- 根据用户提供的属性成长规则截图，已在 `runtime/hero_attr_system.lua` 中直接替换三维推导公式：
  - 每 1 点力量：+0.5 攻击、+100 生命、+1 生命恢复
  - 每 1 点敏捷：+0.5 攻击、+0.1% 物理伤害
  - 每 1 点智力：+0.5 攻击、+0.1% 魔法伤害
- 普攻表现调整：在 `runtime/attack_skills.lua` 中去掉基础普攻 fallback 的统一火焰特效（cast/impact/explosion/charge/chain 全置空），避免怪异受击表现。
- 普攻逻辑调整：基础普攻不再强制走投射物分支，`basic_attack` 的 `is_attack_skill_projectile_enabled` 改为 `false`，并移除从 `simple_common_atk.ability_animations` 读取动画名的逻辑，统一回退为默认 `attack1` 动画。
- 开局多重调整：基础普攻默认额外多重 `+2`，即总共 3 发。
- 当前后续重点：继续完成 `bottom_bg` 技能栏/装备栏的完整渲染迁移，并为基础普攻补一套正常的专属命中表现，而不是继续依赖 fallback。
