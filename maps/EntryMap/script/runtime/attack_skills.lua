-- attack_skills.lua — 攻击技能运行时系统
-- 管理普攻及技能槽位的冷却、溅射、计数追踪

local M = {}

local STATE
local y3 = _G.y3

local BASIC_ATTACK_ABILITY_KEY = 100001001
local ATTACK_INTERVAL = 1.0
local ATTACK_RANGE = 2000

local function init_state()
  STATE = _G.STATE
  if not STATE then
    return
  end

  STATE.attack_skill_state = STATE.attack_skill_state or {
    by_id = {},
    basic_attack_meta = {
      attack_count = 0,
      last_cast_time = 0,
    },
  }
end

function M.update(dt)
  if not STATE or STATE.session_phase ~= 'battle' then
    return
  end

  M.try_auto_attack()
end

function M.try_auto_attack()
  local STATE = _G.STATE
  local y3 = _G.y3

  if not STATE or not STATE.hero or not STATE.hero:is_exist() then
    return
  end

  local hero = STATE.hero
  local meta = STATE.attack_skill_state and STATE.attack_skill_state.basic_attack_meta

  if not meta then
    return
  end

  local current_time = os.clock()
  local last_time = meta.last_cast_time or 0

  if current_time - last_time < ATTACK_INTERVAL then
    return
  end

  local player = y3.player(1)
  local enemies = y3.selector.create()
    :is_enemy(player)
    :in_range(hero, ATTACK_RANGE)
    :sort_type('由近到远')
    :pick()

  if #enemies > 0 then
    local enemy = enemies[1]
    if enemy and enemy:is_exist() then
      local enemy_pos = enemy.get_point and enemy:get_point()
      if enemy_pos then
        M.on_basic_attack_cast(hero, enemy_pos, enemy)
      end
    end
  end
end

function M.on_basic_attack_cast(hero, target_point, target_unit)
  if not hero or not hero:is_exist() then
    return
  end

  init_state()
  local skill_state = STATE.attack_skill_state
  local meta = skill_state.basic_attack_meta

  meta.attack_count = meta.attack_count + 1
  meta.last_cast_time = os.clock()

  if hero.play_animation then
    hero:play_animation('attack1', 1)
  end
end

function M.get_attack_count()
  if not STATE or not STATE.attack_skill_state then
    return 0
  end
  return STATE.attack_skill_state.basic_attack_meta.attack_count
end

return M
