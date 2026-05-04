local M = {
  attack = {
    visual = {
      animation_speed = 0.5,
    },
    debug = {
      damage_area_effect_id = 101492,
      damage_area_height = 8,
      damage_area_scale_base = 110,
    },
    projectile = {
      flight_height = 100,
      near_hit_tolerance = 48,
      bow_speed_factor = 1.55,
      default_speed = 1000,
      default_target_distance = 60,
      default_time = 3.0,
      local_default_time = 0.15,
    },
    cooldown = {
      skill_min_cooldown = 0.4,
      basic_attack_fallback_interval = 0.6,
      basic_attack_min_interval = 0.15,
      attack_speed_floor = 20,
      interval_offset_override_threshold = 0.3,
    },
    search = {
      secondary_radius_min = 260,
      secondary_radius_ratio = 0.45,
    },
  },
  bond = {
    labels = {
      effect_name = '技能系统',
      activation_template = '%s技能系统',
      activation_prompt = '抽取并集齐同一技能的卡牌后，可自动吞噬并激活技能系统。',
      already_active_template = '技能系统已处于激活状态：%s。',
      active_success_template = '已激活技能系统：%s。',
    },
    ui = {
      skill_block_title = '[技能系统]',
      skill_section_template = '【%s】技能系统：',
      skill_section_fallback = '【技能】技能系统：',
      hud_skill_title = '技能系统',
    },
    gm = {
      status_template = '技能系统：%s',
      panel_intro = '用于立刻获得单卡特殊效果，或立刻激活整套技能系统。',
      activate_button = '激活选中技能系统（自动补齐）',
      activation_tab = '技能系统',
      mode_activation = '技能系统',
      cmd_activate_desc = '立即激活指定技能系统：.egmbondeffect <技能名>',
      cmd_test_desc = '运行技能系统自动化自检：.egmbondtest',
    },
  },
}

return M

