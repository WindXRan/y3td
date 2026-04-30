return {
  points = {
    hero_spawn = { x = -1200, y = 0, z = 0 },
    defense_point = { x = -1050, y = 0, z = 0 },
  },
  areas = {
    main_spawn_wave_1 = { x_min = 1660, x_max = 1840, y_min = -1040, y_max = 1040, z = 0 },
    main_spawn_wave_2 = { x_min = 1660, x_max = 1840, y_min = -1040, y_max = 1040, z = 0 },
    main_spawn_wave_3 = { x_min = 1660, x_max = 1840, y_min = -1040, y_max = 1040, z = 0 },
    main_spawn_wave_4 = { x_min = 1660, x_max = 1840, y_min = -1040, y_max = 1040, z = 0 },
    main_spawn_wave_5 = { x_min = 1660, x_max = 1840, y_min = -1040, y_max = 1040, z = 0 },
    boss_spawn_wave_1 = { x_min = 1520, x_max = 1660, y_min = -90, y_max = 90, z = 0 },
    boss_spawn_wave_2 = { x_min = 1540, x_max = 1680, y_min = -110, y_max = 110, z = 0 },
    boss_spawn_wave_3 = { x_min = 1560, x_max = 1700, y_min = -130, y_max = 130, z = 0 },
    boss_spawn_wave_4 = { x_min = 1580, x_max = 1720, y_min = -150, y_max = 150, z = 0 },
    boss_spawn_wave_5 = { x_min = 1600, x_max = 1740, y_min = -170, y_max = 170, z = 0 },
    mid_slow_lane_outer = { x_min = -220, x_max = 260, y_min = -520, y_max = 520, z = 0 },
    mid_slow_lane_inner = { x_min = -760, x_max = 40, y_min = -420, y_max = 420, z = 0 },
    hero_front_slow_lane = { x_min = -1220, x_max = -700, y_min = -320, y_max = 320, z = 0 },
    challenge_spawn_top = { x_min = 1580, x_max = 1850, y_min = 220, y_max = 420, z = 0 },
    challenge_spawn_mid = { x_min = 1620, x_max = 1890, y_min = -80, y_max = 120, z = 0 },
    challenge_spawn_bottom = { x_min = 1580, x_max = 1850, y_min = -420, y_max = -220, z = 0 },
    challenge_treasure_elite_spawn = { x_min = 1640, x_max = 1780, y_min = -60, y_max = 60, z = 0 },
  },
  main_enemy_slow_zones = {
    { area_id = 'mid_slow_lane_outer', speed_factor = 0.64 },
    { area_id = 'mid_slow_lane_inner', speed_factor = 0.46 },
    { area_id = 'hero_front_slow_lane', speed_factor = 0.30 },
  },
  save_slots = {
    outgame_profile = 1,
  },
}
