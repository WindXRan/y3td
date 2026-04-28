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
      local_default_time = 0.25,
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
      effect_name = '羁绊技能',
      activation_template = '%s羁绊技能',
      activation_prompt = '抽取并集齐同一羁绊的卡牌后，可自动吞噬并激活羁绊技能。',
      already_active_template = '羁绊技能已处于激活状态：%s。',
      active_success_template = '已激活羁绊技能：%s。',
    },
    ui = {
      skill_block_title = '[羁绊技能]',
      skill_section_template = '【%s】羁绊技能：',
      skill_section_fallback = '【羁绊】羁绊技能：',
      hud_skill_title = '羁绊技能',
    },
    gm = {
      status_template = '羁绊技能：%s',
      panel_intro = '用于立刻获得单卡特殊效果，或立刻激活整套羁绊技能。',
      activate_button = '激活选中羁绊技能（自动补齐）',
      activation_tab = '羁绊技能',
      mode_activation = '羁绊技能',
      cmd_activate_desc = '立即激活指定羁绊技能：.egmbondeffect <羁绊名>',
      cmd_test_desc = '运行羁绊技能自动化自检：.egmbondtest',
    },
  },
}

return M
