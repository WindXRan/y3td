-- 游戏启动后会自动运行此文件

if y3.game.is_debug_mode() then
  y3.config.log.toGame = true
  y3.config.log.level = 'debug'
else
  y3.config.log.toGame = false
  y3.config.log.level = 'info'
end

local runtime
local runtime_load_attempted = false
local bootstrapped = false

local function trace_boot(message)
  print('[EntryMap] ' .. tostring(message))
end

local function load_runtime()
  if runtime_load_attempted then
    return runtime
  end

  runtime_load_attempted = true
  trace_boot('loading entry_runtime')

  local ok, result = xpcall(function()
    return require 'entry_runtime'
  end, debug.traceback)

  if not ok then
    trace_boot('failed to require entry_runtime:\n' .. tostring(result))
    return nil
  end

  runtime = result
  trace_boot('entry_runtime loaded')
  return runtime
end

local function bootstrap_once()
  if bootstrapped then
    return
  end

  local loaded_runtime = load_runtime()
  if not loaded_runtime then
    return
  end
  if type(loaded_runtime.bootstrap) ~= 'function' then
    trace_boot('entry_runtime.bootstrap is missing')
    return
  end

  bootstrapped = true
  trace_boot('calling runtime.bootstrap')

  local ok, err = xpcall(function()
    loaded_runtime.bootstrap()
  end, debug.traceback)

  if not ok then
    bootstrapped = false
    trace_boot('runtime.bootstrap failed:\n' .. tostring(err))
    return
  end

  trace_boot('runtime.bootstrap finished')
end

y3.game:event('游戏-初始化', function()
  bootstrap_once()
end)

y3.ltimer.wait(0, function()
  bootstrap_once()
end)

include '可重载的代码'

if false then

-- 在开发模式下，将日志打印到游戏中
if y3.game.is_debug_mode() then
  y3.config.log.toGame = true
  y3.config.log.level  = 'debug'
else
  y3.config.log.toGame = false
  y3.config.log.level  = 'info'
end

math.randomseed(os.time())

local CONFIG = {
  PLAYER_ID        = 1,
  ENEMY_PLAYER_ID  = 31,

  -- TODO: 换成你自己地图里的英雄和怪物单位物编 ID
  HERO_UNIT_ID     = 134274912,
  ENEMY_IDS        = {
    melee  = 134274912,
    runner = 134274912,
    tank   = 134274912,
    ranged = 134274912,
    boss   = 134274912,
  },

  -- TODO: 按你地图实际布局调整坐标
  HERO_SPAWN       = { x = -1200, y = 0, z = 0 },
  ENEMY_SPAWN      = { x = 1400, y = 0, z = 0 },
  INTER_WAVE_DELAY = 3,

  WAVES            = {
    { name = '试探进攻', unit_key = 'melee', count = 6, interval = 0.8, exp_reward = 18, gold_reward = 6 },
    { name = '持续施压', unit_key = 'melee', count = 8, interval = 0.7, exp_reward = 18, gold_reward = 6 },
    { name = '高速突袭', unit_key = 'runner', count = 10, interval = 0.6, exp_reward = 20, gold_reward = 7 },
    { name = '厚甲前排', unit_key = 'tank', count = 6, interval = 0.9, exp_reward = 24, gold_reward = 9 },
    { name = '混编小队', unit_key = 'melee', count = 12, interval = 0.5, exp_reward = 22, gold_reward = 8 },
    { name = '再度突袭', unit_key = 'runner', count = 12, interval = 0.5, exp_reward = 22, gold_reward = 8 },
    { name = '远程试射', unit_key = 'ranged', count = 8, interval = 0.8, exp_reward = 26, gold_reward = 10 },
    { name = '重装推进', unit_key = 'tank', count = 8, interval = 0.8, exp_reward = 28, gold_reward = 11 },
    { name = '混编压境', unit_key = 'melee', count = 16, interval = 0.45, exp_reward = 26, gold_reward = 10 },
    { name = '敏捷冲锋', unit_key = 'runner', count = 16, interval = 0.45, exp_reward = 28, gold_reward = 11 },
    { name = '法术小队', unit_key = 'ranged', count = 10, interval = 0.7, exp_reward = 30, gold_reward = 12 },
    { name = '钢铁压境', unit_key = 'tank', count = 10, interval = 0.75, exp_reward = 34, gold_reward = 14 },
    { name = '终局前夜', unit_key = 'melee', count = 20, interval = 0.4, exp_reward = 32, gold_reward = 12 },
    { name = '总攻前奏', unit_key = 'ranged', count = 14, interval = 0.55, exp_reward = 36, gold_reward = 15 },
    { name = '守关首领', unit_key = 'boss', count = 1, interval = 0.2, exp_reward = 180, gold_reward = 80 },
  },
}

local function create_skill_runtime()
  return {
    splash_ratio       = 0,
    splash_radius      = 220,
    chain_chance       = 0,
    chain_bounces      = 0,
    chain_ratio        = 0,
    chain_radius       = 420,
    execute_threshold  = 0,
    medbot_every       = 0,
    medbot_heal        = 0,
    medbot_kills       = 0,
    artillery_interval = 0,
    artillery_ratio    = 0,
    artillery_base     = 0,
    artillery_radius   = 0,
    artillery_cd       = 0,
    bonus_gold_on_kill = 0,
  }
end

local STATE = {
  hero                    = nil,
  monsters                = nil,
  hero_spawn_point        = nil,
  enemy_spawn_point       = nil,
  alive_count             = 0,
  wave_index              = 0,
  wave_spawning           = false,
  waiting_for_next_wave   = false,
  game_finished           = false,
  pending_upgrades        = 0,
  awaiting_upgrade        = false,
  current_upgrade_choices = nil,
  gold                    = 0,
  skill_runtime           = create_skill_runtime(),
}

local function get_player()
  return y3.player(CONFIG.PLAYER_ID)
end

local function get_enemy_player()
  return y3.player(CONFIG.ENEMY_PLAYER_ID)
end

local function message(text)
  print(text)
  get_player():display_message(text)
end

local function make_point(data)
  return y3.point.create(data.x, data.y, data.z or 0)
end

local function has_unit_data(unit_id)
  return y3.object.unit[unit_id] and y3.object.unit[unit_id].data ~= nil
end

local function get_wave_unit_id(wave)
  return CONFIG.ENEMY_IDS[wave.unit_key]
end

local function is_active_monster(unit)
  return unit
    and unit:is_exist()
    and STATE.monsters ~= nil
    and unit:is_in_group(STATE.monsters)
end

local function get_monsters_in_range(center, radius, except_unit)
  local result = {}
  local picked = y3.selector.create()
    :is_enemy(get_player())
    :in_range(center, radius)
    :sort_type('由近到远')
    :pick()

  for _, unit in ipairs(picked) do
    if unit ~= except_unit and is_active_monster(unit) then
      result[#result + 1] = unit
    end
  end

  return result
end

local function deal_skill_damage(target, amount, damage_type)
  if not STATE.hero or not STATE.hero:is_exist() or not is_active_monster(target) then
    return
  end

  local final_damage = math.floor(amount or 0)
  if final_damage <= 0 then
    return
  end

  STATE.hero:damage({
    target        = target,
    damage        = final_damage,
    type          = damage_type or '法术',
    common_attack = false,
    no_miss       = true,
  })
end

local function heal_hero(amount)
  if amount <= 0 or not STATE.hero or not STATE.hero:is_exist() then
    return
  end

  local max_hp = STATE.hero:get_attr('最大生命')
  local old_hp = STATE.hero:get_hp()
  STATE.hero:add_hp(amount)

  if STATE.hero:get_hp() > old_hp then
    message(string.format('急救生效，英雄生命恢复至 %.0f/%.0f。', STATE.hero:get_hp(), max_hp))
  end
end

local function mark_monster_removed(monster)
  if not monster or monster:kv_load('entry_removed', 'boolean') then
    return false
  end
  monster:kv_save('entry_removed', true)
  STATE.monsters:remove_unit(monster)
  if STATE.alive_count > 0 then
    STATE.alive_count = STATE.alive_count - 1
  end
  return true
end

local function finish_game(is_win, reason)
  if STATE.game_finished then
    return
  end

  STATE.game_finished = true

  if is_win then
    message('游戏胜利！' .. (reason and (' ' .. reason) or ''))
  else
    message('游戏失败！' .. (reason and (' ' .. reason) or ''))
  end

  message(string.format(
    '结算：波次 %d/%d，金币 %d，英雄剩余生命 %.0f。',
    STATE.wave_index,
    #CONFIG.WAVES,
    STATE.gold,
    STATE.hero and STATE.hero:is_exist() and STATE.hero:get_hp() or 0
  ))
end

local function show_status()
  local skill = STATE.skill_runtime
  message(string.format(
    '状态：第 %d/%d 波，场上敌人 %d，金币 %d，英雄生命 %.0f。塔防技：溅射%.0f%%，电弧%s，处决%.0f%%。',
    STATE.wave_index,
    #CONFIG.WAVES,
    STATE.alive_count,
    STATE.gold,
    STATE.hero and STATE.hero:is_exist() and STATE.hero:get_hp() or 0,
    skill.splash_ratio * 100,
    skill.chain_bounces > 0 and string.format('%d跳', skill.chain_bounces) or '未解锁',
    skill.execute_threshold * 100
  ))
end

local UPGRADE_POOL = {
  {
    key = 'attack_1',
    name = '力量打击',
    desc = '物理攻击 +18。',
    apply = function(state)
      state.hero:add_attr('物理攻击', 18)
    end,
  },
  {
    key = 'attack_2',
    name = '重击训练',
    desc = '物理攻击 +28。',
    apply = function(state)
      state.hero:add_attr('物理攻击', 28)
    end,
  },
  {
    key = 'attack_speed_1',
    name = '高速连射',
    desc = '攻击速度 +35%。',
    apply = function(state)
      state.hero:add_attr('攻击速度', 35)
    end,
  },
  {
    key = 'attack_speed_2',
    name = '节奏压制',
    desc = '攻击速度 +50%。',
    apply = function(state)
      state.hero:add_attr('攻击速度', 50)
    end,
  },
  {
    key = 'crit_chance',
    name = '致命专注',
    desc = '暴击率 +10%。',
    apply = function(state)
      state.hero:add_attr('暴击率', 10)
    end,
  },
  {
    key = 'crit_damage',
    name = '暴虐收割',
    desc = '暴击伤害 +30%。',
    apply = function(state)
      state.hero:add_attr('暴击伤害', 30)
    end,
  },
  {
    key = 'hp_max',
    name = '生命强化',
    desc = '最大生命 +180，并回复 180 生命。',
    apply = function(state)
      state.hero:add_attr('最大生命', 180)
      state.hero:add_hp(180)
    end,
  },
  {
    key = 'regen',
    name = '呼吸法',
    desc = '生命恢复 +4。',
    apply = function(state)
      state.hero:add_attr('生命恢复', 4)
    end,
  },
  {
    key = 'lifesteal',
    name = '战斗续航',
    desc = '物理吸血 +6%。',
    apply = function(state)
      state.hero:add_attr('物理吸血', 6)
    end,
  },
  {
    key = 'splash_shell',
    name = '爆裂弹头',
    desc = '普攻会对目标周围造成 35% 溅射伤害。',
    apply = function(state)
      state.skill_runtime.splash_ratio = state.skill_runtime.splash_ratio + 0.35
      state.skill_runtime.splash_radius = math.max(state.skill_runtime.splash_radius, 220)
    end,
  },
  {
    key = 'splash_shell_plus',
    name = '高能爆裂弹头',
    desc = '额外获得 25% 溅射伤害，溅射范围扩大。',
    apply = function(state)
      state.skill_runtime.splash_ratio = state.skill_runtime.splash_ratio + 0.25
      state.skill_runtime.splash_radius = math.max(state.skill_runtime.splash_radius, 280)
    end,
  },
  {
    key = 'chain_arc',
    name = '连锁电弧',
    desc = '普攻有 25% 概率弹射 2 个目标，造成 45% 法术伤害。',
    apply = function(state)
      state.skill_runtime.chain_chance = state.skill_runtime.chain_chance + 0.25
      state.skill_runtime.chain_bounces = math.max(state.skill_runtime.chain_bounces, 2)
      state.skill_runtime.chain_ratio = math.max(state.skill_runtime.chain_ratio, 0.45)
      state.skill_runtime.chain_radius = math.max(state.skill_runtime.chain_radius, 420)
    end,
  },
  {
    key = 'chain_arc_plus',
    name = '超载电弧',
    desc = '电弧触发率 +15%，额外弹射 1 次，伤害提高。',
    apply = function(state)
      state.skill_runtime.chain_chance = state.skill_runtime.chain_chance + 0.15
      state.skill_runtime.chain_bounces = state.skill_runtime.chain_bounces + 1
      state.skill_runtime.chain_ratio = math.max(state.skill_runtime.chain_ratio, 0.65)
      state.skill_runtime.chain_radius = math.max(state.skill_runtime.chain_radius, 480)
    end,
  },
  {
    key = 'execute_protocol',
    name = '处决协议',
    desc = '敌人生命低于 12% 时，普攻命中后会立即处决。',
    apply = function(state)
      state.skill_runtime.execute_threshold = math.max(state.skill_runtime.execute_threshold, 0.12)
    end,
  },
  {
    key = 'med_drone',
    name = '急救无人机',
    desc = '每击杀 18 个敌人，自动为英雄回复 80 生命。',
    apply = function(state)
      state.skill_runtime.medbot_every = 18
      state.skill_runtime.medbot_heal = state.skill_runtime.medbot_heal + 80
    end,
  },
  {
    key = 'pierce',
    name = '穿甲箭头',
    desc = '物理穿透 +14。',
    apply = function(state)
      state.hero:add_attr('物理穿透', 14)
    end,
  },
  {
    key = 'damage_bonus',
    name = '杀意高涨',
    desc = '伤害加成 +8%。',
    apply = function(state)
      state.hero:add_attr('伤害加成', 8)
    end,
  },
  {
    key = 'damage_reduce',
    name = '铁壁姿态',
    desc = '受伤减免 +6%。',
    apply = function(state)
      state.hero:add_attr('受伤减免', 6)
    end,
  },
  {
    key = 'attack_range',
    name = '警戒扩展',
    desc = '攻击范围 +120。',
    apply = function(state)
      state.hero:add_attr('攻击范围', 120)
    end,
  },
  {
    key = 'orbital_barrage',
    name = '轨道轰炸',
    desc = '每 6 秒对随机敌群降下轰炸，造成范围法术伤害。',
    apply = function(state)
      state.skill_runtime.artillery_interval = 6
      state.skill_runtime.artillery_base = state.skill_runtime.artillery_base + 40
      state.skill_runtime.artillery_ratio = state.skill_runtime.artillery_ratio + 0.9
      state.skill_runtime.artillery_radius = math.max(state.skill_runtime.artillery_radius, 240)
      state.skill_runtime.artillery_cd = 0
    end,
  },
  {
    key = 'bounty_radar',
    name = '赏金雷达',
    desc = '每次击杀额外获得 2 金币。',
    apply = function(state)
      state.skill_runtime.bonus_gold_on_kill = state.skill_runtime.bonus_gold_on_kill + 2
    end,
  },
  {
    key = 'steel_skin',
    name = '钢铁皮肤',
    desc = '最大生命 +160，受伤减免 +4%。',
    apply = function(state)
      state.hero:add_attr('最大生命', 160)
      state.hero:add_attr('受伤减免', 4)
      state.hero:add_hp(160)
    end,
  },
  {
    key = 'bounty',
    name = '赏金时间',
    desc = '立即获得 60 金币。',
    apply = function(state)
      state.gold = state.gold + 60
    end,
  },
}

local function trigger_td_skills_on_hit(data)
  if STATE.game_finished or not data.is_normal_hit or data.source_unit ~= STATE.hero then
    return
  end

  local skill = STATE.skill_runtime
  local target = data.target_unit
  if not is_active_monster(target) then
    return
  end

  if skill.splash_ratio > 0 then
    for _, unit in ipairs(get_monsters_in_range(target, skill.splash_radius, target)) do
      deal_skill_damage(unit, data.damage * skill.splash_ratio, '物理')
    end
  end

  if skill.chain_bounces > 0 and skill.chain_chance > 0 and math.random() <= skill.chain_chance then
    local bounced = 0
    for _, unit in ipairs(get_monsters_in_range(target, skill.chain_radius, target)) do
      deal_skill_damage(unit, data.damage * skill.chain_ratio, '法术')
      bounced = bounced + 1
      if bounced >= skill.chain_bounces then
        break
      end
    end
  end

  if skill.execute_threshold > 0 and target:is_exist() and target:get_hp() > 0 then
    local max_hp = target:get_attr('最大生命')
    if max_hp > 0 and target:get_hp() / max_hp <= skill.execute_threshold then
      target:kill_by(STATE.hero)
    end
  end
end

local function pick_upgrade_choices(count)
  local pool = {}
  for _, upgrade in ipairs(UPGRADE_POOL) do
    pool[#pool + 1] = upgrade
  end

  local choices = {}
  local total = math.min(count, #pool)
  for _ = 1, total, 1 do
    local index = math.random(1, #pool)
    choices[#choices + 1] = pool[index]
    table.remove(pool, index)
  end

  return choices
end

local function show_upgrade_choices()
  if STATE.game_finished or STATE.pending_upgrades <= 0 then
    return
  end

  STATE.pending_upgrades = STATE.pending_upgrades - 1
  STATE.awaiting_upgrade = true
  STATE.current_upgrade_choices = pick_upgrade_choices(3)

  message('升级完成，请按 1 / 2 / 3 选择一个强化：')
  for index, upgrade in ipairs(STATE.current_upgrade_choices) do
    message(string.format('%d. %s %s', index, upgrade.name, upgrade.desc))
  end
end

local function apply_upgrade(index)
  if not STATE.awaiting_upgrade then
    return
  end

  local upgrade = STATE.current_upgrade_choices and STATE.current_upgrade_choices[index]
  if not upgrade then
    return
  end

  upgrade.apply(STATE)
  STATE.awaiting_upgrade = false
  STATE.current_upgrade_choices = nil

  message('已选择强化：' .. upgrade.name)

  if STATE.pending_upgrades > 0 then
    show_upgrade_choices()
  end
end

local function on_monster_dead(monster, wave)
  if not mark_monster_removed(monster) then
    return
  end

  if STATE.hero and STATE.hero:is_exist() then
    STATE.hero:add_exp(wave.exp_reward or 0)
  end

  STATE.gold = STATE.gold + (wave.gold_reward or 0) + STATE.skill_runtime.bonus_gold_on_kill

  if STATE.skill_runtime.medbot_every > 0 and STATE.skill_runtime.medbot_heal > 0 then
    STATE.skill_runtime.medbot_kills = STATE.skill_runtime.medbot_kills + 1
    if STATE.skill_runtime.medbot_kills >= STATE.skill_runtime.medbot_every then
      STATE.skill_runtime.medbot_kills = STATE.skill_runtime.medbot_kills - STATE.skill_runtime.medbot_every
      heal_hero(STATE.skill_runtime.medbot_heal)
    end
  end
end

local function spawn_monster(wave)
  local monster = y3.unit.create_unit(get_enemy_player(), get_wave_unit_id(wave), STATE.enemy_spawn_point, 180.0)
  STATE.monsters:add_unit(monster)
  STATE.alive_count = STATE.alive_count + 1

  monster:attack_move(STATE.hero_spawn_point)

  monster:event('单位-死亡', function(_, data)
    on_monster_dead(data.unit or monster, wave)
  end)
end

local function start_next_wave()
  if STATE.game_finished or STATE.wave_spawning or STATE.awaiting_upgrade then
    return
  end

  local next_wave = CONFIG.WAVES[STATE.wave_index + 1]
  if not next_wave then
    if STATE.alive_count == 0 then
      finish_game(true, '所有波次已完成。')
    end
    return
  end

  STATE.wave_index = STATE.wave_index + 1
  STATE.wave_spawning = true

  message(string.format('第 %d 波开始：%s', STATE.wave_index, next_wave.name))

  y3.timer.count_loop(next_wave.interval, next_wave.count, function(timer, count)
    if STATE.game_finished then
      timer:remove()
      return
    end

    spawn_monster(next_wave)

    if count >= next_wave.count then
      STATE.wave_spawning = false
      message(string.format('第 %d 波敌人已全部出场。', STATE.wave_index))
    end
  end)
end

local function schedule_next_wave(delay)
  if STATE.game_finished or STATE.waiting_for_next_wave or STATE.wave_index >= #CONFIG.WAVES then
    return
  end

  STATE.waiting_for_next_wave = true
  message(string.format('%d 秒后进入第 %d 波。', delay, STATE.wave_index + 1))

  y3.ltimer.wait(delay, function()
    STATE.waiting_for_next_wave = false

    if STATE.game_finished or STATE.awaiting_upgrade or STATE.wave_spawning or STATE.alive_count > 0 then
      return
    end

    start_next_wave()
  end)
end

local function create_hero()
  local hero = get_player():create_unit(CONFIG.HERO_UNIT_ID, STATE.hero_spawn_point, 0)
  get_player():select_unit(hero)

  hero:set_name('守关英雄')
  hero:add_attr('最大生命', 650)
  hero:set_hp(650)
  hero:add_attr('物理攻击', 35)
  hero:add_attr('攻击速度', 80)
  hero:add_attr('暴击率', 10)
  hero:add_attr('暴击伤害', 20)
  hero:add_attr('物理吸血', 4)
  hero:add_attr('攻击范围', 250)

  hero:event('单位-死亡', function()
    finish_game(false, '英雄倒下。')
  end)

  hero:event('单位-造成伤害后', function(_, data)
    trigger_td_skills_on_hit(data)
  end)

  return hero
end

local function validate_config()
  local missing = {}
  local checked = {}

  local function check_unit(name, unit_id)
    if unit_id == nil then
      missing[#missing + 1] = string.format('%s: 未配置', name)
      return
    end
    if checked[unit_id] then
      return
    end
    checked[unit_id] = true
    if not has_unit_data(unit_id) then
      missing[#missing + 1] = string.format('%s: %d', name, unit_id)
    end
  end

  check_unit('HERO_UNIT_ID', CONFIG.HERO_UNIT_ID)
  for name, unit_id in pairs(CONFIG.ENEMY_IDS) do
    check_unit('ENEMY_IDS.' .. name, unit_id)
  end
  for index, wave in ipairs(CONFIG.WAVES) do
    check_unit('WAVES[' .. tostring(index) .. '].unit_key=' .. tostring(wave.unit_key), get_wave_unit_id(wave))
  end

  if #missing == 0 then
    return true
  end

  message('原型未启动：以下单位物编 ID 不存在，请先替换 main.lua 顶部 CONFIG 中的配置。')
  for _, line in ipairs(missing) do
    message(line)
  end

  return false
end

local function register_runtime_events()
  y3.game:event('单位-升级', function(_, data)
    if STATE.game_finished or data.unit ~= STATE.hero then
      return
    end

    STATE.pending_upgrades = STATE.pending_upgrades + 1
    message('英雄升级，当前等级：' .. tostring(STATE.hero:get_level()))

    if not STATE.awaiting_upgrade then
      show_upgrade_choices()
    end
  end)

  y3.game:event('键盘-按下', y3.const.KeyboardKey['KEY_1'], function()
    apply_upgrade(1)
  end)

  y3.game:event('键盘-按下', y3.const.KeyboardKey['KEY_2'], function()
    apply_upgrade(2)
  end)

  y3.game:event('键盘-按下', y3.const.KeyboardKey['KEY_3'], function()
    apply_upgrade(3)
  end)

  y3.game:event('键盘-按下', y3.const.KeyboardKey['SPACE'], function()
    show_status()
  end)
end

local function start_runtime_loops()
  y3.ltimer.loop(0.5, function(timer)
    if STATE.game_finished then
      timer:remove()
      return
    end

    if not STATE.wave_spawning and STATE.alive_count == 0 and not STATE.waiting_for_next_wave and not STATE.awaiting_upgrade then
      if STATE.wave_index >= #CONFIG.WAVES then
        finish_game(true, '所有波次已完成。')
        timer:remove()
        return
      end
      schedule_next_wave(CONFIG.INTER_WAVE_DELAY)
    end
  end)

  y3.ltimer.loop(1, function(timer)
    if STATE.game_finished then
      timer:remove()
      return
    end

    local skill = STATE.skill_runtime
    if skill.artillery_interval <= 0 or skill.artillery_radius <= 0 or skill.artillery_ratio <= 0 then
      return
    end

    skill.artillery_cd = skill.artillery_cd + 1
    if skill.artillery_cd < skill.artillery_interval then
      return
    end
    skill.artillery_cd = 0

    local anchor = STATE.monsters:get_random()
    if not is_active_monster(anchor) then
      return
    end

    local damage = skill.artillery_base + STATE.hero:get_attr('物理攻击') * skill.artillery_ratio
    for _, unit in ipairs(get_monsters_in_range(anchor, skill.artillery_radius)) do
      deal_skill_damage(unit, damage, '法术')
    end
  end)
end

local function init_game()
  if not validate_config() then
    return
  end

  STATE.monsters = y3.unit_group.create()
  STATE.hero_spawn_point = make_point(CONFIG.HERO_SPAWN)
  STATE.enemy_spawn_point = make_point(CONFIG.ENEMY_SPAWN)
  STATE.alive_count = 0
  STATE.wave_index = 0
  STATE.wave_spawning = false
  STATE.waiting_for_next_wave = false
  STATE.game_finished = false
  STATE.pending_upgrades = 0
  STATE.awaiting_upgrade = false
  STATE.current_upgrade_choices = nil
  STATE.gold = 0
  STATE.skill_runtime = create_skill_runtime()

  get_player():set_hostility(get_enemy_player(), true)
  get_enemy_player():set_hostility(get_player(), true)

  STATE.hero = create_hero()

  message('MVP 原型已启动。按 Space 查看状态，升级后按 1 / 2 / 3 选择强化。')

  schedule_next_wave(2)
  start_runtime_loops()
end

register_runtime_events()

y3.game:event('游戏-初始化', function()
  init_game()
end)

-- 此文件内的代码可以被热重载
include '可重载的代码'
end
