local M = {}

local ABILITY_ID = 134258724
local DAMAGE_RATIO = 2.0
local RADIUS = 300

function M.create(env)
  local STATE = env.STATE
  local y3 = env.y3
  local hero_attr_system = env.hero_attr_system
  local get_enemies_in_range = env.get_enemies_in_range
  local deal_skill_damage = env.deal_skill_damage

  local api = {}

  local function is_valid_unit(unit)
    return unit and unit.is_exist and unit:is_exist()
  end

  local function get_attack_value(unit)
    if not is_valid_unit(unit) then
      return 0
    end

    local value = hero_attr_system and hero_attr_system.get_attr(unit, '攻击结算值') or unit:get_attr('攻击结算值')
    value = y3.helper.tonumber(value) or 0
    if value > 0 then
      return value
    end

    value = hero_attr_system and hero_attr_system.get_attr(unit, '攻击') or unit:get_attr('攻击')
    value = y3.helper.tonumber(value) or 0
    if value > 0 then
      return value
    end

    return y3.helper.tonumber(unit:get_attr('物理攻击')) or 0
  end

  local function get_burst_center(source, target)
    if is_valid_unit(target) then
      return target
    end
    if is_valid_unit(source) then
      return source
    end
    return nil
  end

  local function handle_cast(data)
    local ability = data and data.ability
    if not ability or ability:get_key() ~= ABILITY_ID then
      return
    end

    local source = data.unit
    if not is_valid_unit(source) or source ~= STATE.hero or STATE.game_finished then
      return
    end

    local target = data.ability_target_unit
    local center = get_burst_center(source, target)
    if not center then
      return
    end

    if source.play_animation then
      source:play_animation('attack1', 1.0, nil, nil, false, true)
    end

    local damage = get_attack_value(source) * DAMAGE_RATIO
    if damage <= 0 then
      return
    end

    for _, unit in ipairs(get_enemies_in_range(center, RADIUS)) do
      deal_skill_damage(unit, damage, {
        damage_type = '物理',
        damage_form = 'weapon',
        element = 'none',
        damage_label = '开炮',
      }, {
        text_type = 'physics',
      })
    end
  end

  function api.register()
    if STATE.cannon_skill_134258724_bound then
      return
    end
    y3.game:event('施法-出手', function(_, data)
      handle_cast(data)
    end)
    STATE.cannon_skill_134258724_bound = true
  end

  return api
end

return M
