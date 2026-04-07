return {
    id = 'echo_codex',
    name = '回声法典',
    quality = 'rare',
    summary = '非普攻攻击技能伤害 +15%，施法距离 +100。',
    pool_weight = 7,
    tags = { 'skill', 'spell_cycle' },
    treasure_type = 'route_amp',
    duration_type = 'permanent',
    theme_tags = { 'skill', 'caster' },
    best_with_tags = { 'arcane', 'flame_arrow', 'frost_arrow', 'thunder' },
    timing_tags = { 'immediate', 'persistent' },
    bonuses = {
      attack_skill = {
        damage_ratio = 0.15,
        range_bonus = 100,
      },
    },
  }
