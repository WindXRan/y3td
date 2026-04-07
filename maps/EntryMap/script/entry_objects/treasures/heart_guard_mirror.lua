return {
    id = 'heart_guard_mirror',
    name = '护心镜',
    quality = 'rare',
    summary = '最大生命 +180，伤害减免 +12%；每 10 秒触发 1 次守护脉冲。',
    pool_weight = 6,
    tags = { 'survival' },
    treasure_type = 'general',
    duration_type = 'permanent',
    theme_tags = { 'survival', 'mitigation' },
    best_with_tags = { 'fortress', 'blessing', 'boss' },
    timing_tags = { 'immediate', 'persistent' },
    bonuses = {
      attr = {
        ['最大生命'] = 180,
        ['伤害减免'] = 12,
      },
    },
  }
