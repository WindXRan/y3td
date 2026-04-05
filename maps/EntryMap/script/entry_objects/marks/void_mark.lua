return {
  id = 'void_mark',
  name = '虚空烙印',
  quality = 'epic',
  pool_weight = 4,
  tags = { 'attack_spell', 'boss', 'cooldown' },
  summary = '所有攻击技能伤害 +28%，冷却缩减 12%，对精英与 Boss 伤害 +12%。',
  bonuses = {
    runtime = {
      skill_damage_bonus = 0.28,
      boss_damage_bonus = 0.12,
      elite_damage_bonus = 0.12,
    },
    attack_skill = {
      cooldown_reduction = 0.12,
    },
  },
}
