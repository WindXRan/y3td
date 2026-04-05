return {
    id = 'time_rift_hourglass',
    name = '时隙沙漏',
    quality = 'epic',
    summary = '非普攻攻击技能冷却缩减 20%，并额外释放 1 次。',
    pool_weight = 5,
    tags = { 'skill', 'spell_cycle' },
    bonuses = {
      attack_skill = {
        cooldown_reduction = 0.20,
        repeat_count = 1,
      },
    },
  }
