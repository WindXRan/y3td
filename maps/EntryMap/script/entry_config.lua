local DEBUG_TIME_SCALE = y3.game.is_debug_mode() and 0.2 or 1.0

local function scale(seconds)
  return seconds * DEBUG_TIME_SCALE
end

local function segment(start_sec, interval_sec)
  return {
    start_sec = scale(start_sec),
    interval_sec = scale(interval_sec),
  }
end

local function challenge_batch(time_sec, count)
  return {
    time_sec = scale(time_sec),
    count = count,
  }
end

local M = {
  debug_time_scale = DEBUG_TIME_SCALE,
  player_id = 1,
  enemy_player_id = 31,
  total_enemy_soft_cap = 40,
  hero_init_stats = {
    hp_max = 650,
    attack_phy = 35,
    attack_speed = 80,
    critical_chance = 10,
    critical_dmg = 20,
    vampire_phy = 4,
  },
  debug_hero_bonus_stats = {
    hp_max = 4000,
    attack_phy = 260,
    attack_speed = 220,
    critical_chance = 25,
    critical_dmg = 100,
    vampire_phy = 25,
    attack_range = 200,
  },
  hero_progression = {
    engine_exp_cap_level = 15,
    max_level = 60,
    post_cap_exp_base = 260,
    post_cap_exp_step = 40,
  },

  -- 当前地图里尚未发现专门的主线怪/Boss物编，这里先用现成英雄单位做临时替身，
  -- 目的是先把 5 波主线、Boss 和挑战流程跑通，后续再替换成正式怪物资源。
  temp_unit_labels = {
    hero = '关羽',
    wave_1_main = '刘备',
    wave_2_main = '孟获',
    wave_3_main = '孙尚香',
    wave_4_main = '赵云',
    wave_5_main = '吕布',
    wave_1_boss = '张飞',
    wave_2_boss = '孙策',
    wave_3_boss = '黄月英',
    wave_4_boss = '吕布',
    wave_5_boss = '赵云',
    gold_trial = '孙尚香',
    wood_trial = '孟获',
    exp_trial = '黄忠',
    treasure_trial_boss = '吕布',
    treasure_trial_guard = '刘备',
  },

  unit_ids = {
    hero = 134274912,
    main_monsters = {},
    bosses = {},
    challenges = {
      gold = 134242543,
      wood = 134224570,
      exp = 134275571,
      treasure_boss = 134228855,
      treasure_guard = 134241735,
    },
  },

  points = {
    hero_spawn = { x = -1200, y = 0, z = 0 },
    defense_point = { x = -1050, y = 0, z = 0 },
  },

  areas = {
    main_spawn_wave_1 = { x_min = 1200, x_max = 1480, y_min = -180, y_max = 180, z = 0 },
    main_spawn_wave_2 = { x_min = 1200, x_max = 1480, y_min = -220, y_max = 220, z = 0 },
    main_spawn_wave_3 = { x_min = 1220, x_max = 1500, y_min = -260, y_max = 260, z = 0 },
    main_spawn_wave_4 = { x_min = 1240, x_max = 1520, y_min = -300, y_max = 300, z = 0 },
    main_spawn_wave_5 = { x_min = 1260, x_max = 1540, y_min = -320, y_max = 320, z = 0 },

    boss_spawn_wave_1 = { x_min = 1120, x_max = 1260, y_min = -90, y_max = 90, z = 0 },
    boss_spawn_wave_2 = { x_min = 1140, x_max = 1280, y_min = -110, y_max = 110, z = 0 },
    boss_spawn_wave_3 = { x_min = 1160, x_max = 1300, y_min = -130, y_max = 130, z = 0 },
    boss_spawn_wave_4 = { x_min = 1180, x_max = 1320, y_min = -150, y_max = 150, z = 0 },
    boss_spawn_wave_5 = { x_min = 1200, x_max = 1340, y_min = -170, y_max = 170, z = 0 },

    challenge_spawn_top = { x_min = 1180, x_max = 1450, y_min = 220, y_max = 420, z = 0 },
    challenge_spawn_mid = { x_min = 1220, x_max = 1490, y_min = -80, y_max = 120, z = 0 },
    challenge_spawn_bottom = { x_min = 1180, x_max = 1450, y_min = -420, y_max = -220, z = 0 },
    challenge_treasure_elite_spawn = { x_min = 1240, x_max = 1380, y_min = -60, y_max = 60, z = 0 },
  },

  challenge_rules = {
    max_charges = 3,
    initial_charges = 1,
    recover_sec = scale(120),
  },

  waves = {
    {
      id = 'wave_1',
      index = 1,
      name = '第1波：饥饿地精',
      main_unit_id = 134241735,
      boss_unit_id = 134219749,
      spawn_area_id = 'main_spawn_wave_1',
      boss_spawn_area_id = 'boss_spawn_wave_1',
      boss_spawn_sec = scale(240),
      batch_min = 3,
      batch_max = 4,
      max_alive = 12,
      spawn_segments = {
        segment(0, 3.0),
        segment(60, 2.7),
        segment(150, 2.4),
      },
      post_boss_interval_sec = scale(2.4),
      main_kill_reward = { exp = 10, gold = 4, wood = 0 },
      boss_kill_reward = { exp = 90, gold = 60, wood = 10 },
      boss_special = '无',
      theme = '教学近战',
      boss_timeline_profile_id = 'boss_timeline_wave_1',
      boss_low_hp_profile_id = 'boss_low_hp_wave_1',
    },
    {
      id = 'wave_2',
      index = 2,
      name = '第2波：腐甲步兵',
      main_unit_id = 134224570,
      boss_unit_id = 134279196,
      spawn_area_id = 'main_spawn_wave_2',
      boss_spawn_area_id = 'boss_spawn_wave_2',
      boss_spawn_sec = scale(240),
      batch_min = 4,
      batch_max = 5,
      max_alive = 16,
      spawn_segments = {
        segment(0, 2.6),
        segment(60, 2.3),
        segment(150, 2.1),
      },
      post_boss_interval_sec = scale(2.1),
      main_kill_reward = { exp = 12, gold = 5, wood = 0 },
      boss_kill_reward = { exp = 110, gold = 80, wood = 15 },
      boss_special = '无',
      theme = '耐久压场',
      boss_timeline_profile_id = 'boss_timeline_wave_2',
      boss_low_hp_profile_id = 'boss_low_hp_wave_2',
    },
    {
      id = 'wave_3',
      index = 3,
      name = '第3波：投矛猎手',
      main_unit_id = 134242543,
      boss_unit_id = 134259608,
      spawn_area_id = 'main_spawn_wave_3',
      boss_spawn_area_id = 'boss_spawn_wave_3',
      boss_spawn_sec = scale(240),
      batch_min = 4,
      batch_max = 4,
      max_alive = 18,
      spawn_segments = {
        segment(0, 2.4),
        segment(60, 2.2),
        segment(150, 2.0),
      },
      post_boss_interval_sec = scale(2.0),
      main_kill_reward = { exp = 14, gold = 6, wood = 0 },
      boss_kill_reward = { exp = 140, gold = 100, wood = 20 },
      boss_special = '无',
      theme = '远程干扰',
      boss_timeline_profile_id = 'boss_timeline_wave_3',
      boss_low_hp_profile_id = 'boss_low_hp_wave_3',
    },
    {
      id = 'wave_4',
      index = 4,
      name = '第4波：裂爪兽群',
      main_unit_id = 134222661,
      boss_unit_id = 134228855,
      spawn_area_id = 'main_spawn_wave_4',
      boss_spawn_area_id = 'boss_spawn_wave_4',
      boss_spawn_sec = scale(240),
      batch_min = 5,
      batch_max = 6,
      max_alive = 22,
      spawn_segments = {
        segment(0, 2.0),
        segment(60, 1.8),
        segment(150, 1.6),
      },
      post_boss_interval_sec = scale(1.6),
      main_kill_reward = { exp = 16, gold = 7, wood = 1 },
      boss_kill_reward = { exp = 170, gold = 130, wood = 28 },
      boss_special = '无',
      theme = '高速穿线',
      boss_timeline_profile_id = 'boss_timeline_wave_4',
      boss_low_hp_profile_id = 'boss_low_hp_wave_4',
    },
    {
      id = 'wave_5',
      index = 5,
      name = '第5波：深渊祭仆',
      main_unit_id = 134228855,
      boss_unit_id = 134222661,
      spawn_area_id = 'main_spawn_wave_5',
      boss_spawn_area_id = 'boss_spawn_wave_5',
      boss_spawn_sec = scale(240),
      batch_min = 4,
      batch_max = 5,
      max_alive = 24,
      spawn_segments = {
        segment(0, 1.8),
        segment(60, 1.6),
        segment(150, 1.5),
      },
      post_boss_interval_sec = scale(1.5),
      main_kill_reward = { exp = 18, gold = 8, wood = 1 },
      boss_kill_reward = { exp = 220, gold = 180, wood = 40 },
      boss_special = '胜利结算',
      theme = '终盘高压',
      boss_timeline_profile_id = 'boss_timeline_wave_5',
      boss_low_hp_profile_id = 'boss_low_hp_wave_5',
    },
  },

  challenges = {
    gold_trial = {
      id = 'gold_trial',
      name = '金币挑战',
      hotkey = 'Q',
      unlock_rule = { type = 'wave_started', value = 1, text = '第1波开始后解锁' },
      duration_sec = scale(60),
      cost_charge = 1,
      spawn_area_id = 'challenge_spawn_top',
      reward = { gold = 220, wood = 0, exp = 0, special = nil },
      unit_id = 134242543,
      batches = {
        challenge_batch(0, 7),
        challenge_batch(12, 7),
        challenge_batch(24, 6),
      },
    },
    wood_trial = {
      id = 'wood_trial',
      name = '木材挑战',
      hotkey = 'W',
      unlock_rule = { type = 'bond_draw_count', value = 1, text = '首次完成1次羁绊抽卡后解锁' },
      duration_sec = scale(60),
      cost_charge = 1,
      spawn_area_id = 'challenge_spawn_bottom',
      reward = { gold = 0, wood = 60, exp = 0, special = nil },
      unit_id = 134224570,
      batches = {
        challenge_batch(0, 5),
        challenge_batch(18, 5),
      },
    },
    exp_trial = {
      id = 'exp_trial',
      name = '经验挑战',
      hotkey = 'E',
      unlock_rule = { type = 'hero_level', value = 8, text = '英雄达到8级后解锁' },
      duration_sec = scale(60),
      cost_charge = 1,
      spawn_area_id = 'challenge_spawn_mid',
      reward = { gold = 0, wood = 0, exp = 300, special = nil },
      unit_id = 134275571,
      batches = {
        challenge_batch(0, 6),
        challenge_batch(10, 6),
        challenge_batch(20, 6),
        challenge_batch(30, 6),
      },
    },
    treasure_trial = {
      id = 'treasure_trial',
      name = '宝物挑战',
      hotkey = 'R',
      unlock_rule = { type = 'boss_kill_wave', value = 2, text = '击败第2波Boss后解锁' },
      duration_sec = scale(60),
      cost_charge = 1,
      spawn_area_id = 'challenge_treasure_elite_spawn',
      reward = { gold = 40, wood = 20, exp = 0, special = '宝物候选(占位)' },
      boss_unit_id = 134228855,
      guard_unit_id = 134241735,
      batches = {
        challenge_batch(0, 5),
        challenge_batch(20, 4),
      },
    },
  },
}

for _, wave in ipairs(M.waves) do
  M.unit_ids.main_monsters[wave.id] = wave.main_unit_id
  M.unit_ids.bosses[wave.id] = wave.boss_unit_id
end

return M
