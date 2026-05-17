local M = {}

function M.create(deps)
  local STATE = deps.STATE
  local hero_attr_system = deps.hero_attr_system
  local message = deps.message
  local logger = deps.logger('BattleLogic')

  local function deal_skill_damage(target, amount, damage_info, visual)
    if not target or not target.is_exist or not target:is_exist() then
      return 0
    end
    local final_damage = amount or 0
    if damage_info and damage_info.damage_type then
      local multiplier = 1
      if deps.get_damage_bonus_multiplier then
        multiplier = deps.get_damage_bonus_multiplier(target, damage_info) or 1
      end
      final_damage = final_damage * multiplier
    end
    target:add_hp(-final_damage)
    if visual and deps.emit_damage_debug_visual then
      deps.emit_damage_debug_visual(visual, target)
    end
    logger.debug('Skill damage dealt', { target = target:get_name(), damage = final_damage })
    return final_damage
  end

  local function heal_hero(amount)
    if amount <= 0 then
      return
    end
    if not STATE.battle.hero or not STATE.battle.hero:is_exist() then
      return
    end
    local before = STATE.battle.hero:get_hp()
    STATE.battle.hero:add_hp(amount)
    local after = STATE.battle.hero:get_hp()
    if after > before then
      message(string.format('急救生效，英雄生命恢复至 %.0f。', after))
      logger.info('Hero healed', { amount = amount, before = before, after = after })
    end
    return after - before
  end

  local function get_hero_attack()
    if not STATE.battle.hero or not STATE.battle.hero:is_exist() then return 0 end
    return hero_attr_system.get_attack(STATE.battle.hero) or STATE.battle.hero:get_attr('攻击') or 0
  end

  local function get_current_hero()
    return STATE.battle.hero
  end

  local function get_enemies_in_range(center, radius, except_unit, max_count)
    local sys = deps.battlefield_system
    if not sys then return {} end
    return sys.get_enemies_in_range(center, radius, except_unit, max_count) or {}
  end

  local function get_enemies_on_line(origin, impact, max_dist, line_width, max_hits, except_unit)
    local sys = deps.battlefield_system
    if not sys then return {} end
    return sys.get_enemies_on_line(origin, impact, max_dist, line_width, max_hits, except_unit) or {}
  end

  local function get_hero_point()
    local hero = get_current_hero()
    if not hero or not hero:is_exist() then return STATE.battle.defense_point end
    return hero:get_point()
  end

  local function is_active_enemy(unit)
    local sys = deps.battlefield_system
    if not sys then return false end
    return sys.is_active_enemy(unit) or false
  end

  local function add_hero_attr_pack(unit, attr_pack)
    if not unit or not attr_pack then return end
    for attr_name, value in pairs(attr_pack) do
      if value ~= nil and value ~= 0 then
        hero_attr_system.add_attr(unit, attr_name, value)
      end
    end
    hero_attr_system.rebuild_derived_attrs(unit)
    logger.debug('Hero attributes updated', { unit = unit:get_name(), attrs = attr_pack })
  end

  local function snapshot_hero_attrs()
    if not STATE.battle.hero or not STATE.battle.hero:is_exist() then return nil end
    return hero_attr_system.snapshot(STATE.battle.hero, STATE)
  end

  local function get_bond_runtime_bonus(key)
    local evolution_runtime = STATE.subsystems.evolution
    local evolution_bonus = 0
    if evolution_runtime and evolution_runtime.applied and evolution_runtime.applied.runtime then
      evolution_bonus = evolution_runtime.applied.runtime[key] or 0
    end
    local bond_system = deps.bond_system
    local bond_bonus = 0
    if bond_system then
      bond_bonus = bond_system.get_runtime_bonus(STATE, key) or 0
    end
    return bond_bonus + evolution_bonus
  end

  local function get_combat_bonus(key)
    return get_bond_runtime_bonus(key)
  end

  return {
    deal_skill_damage = deal_skill_damage,
    heal_hero = heal_hero,
    get_hero_attack = get_hero_attack,
    get_current_hero = get_current_hero,
    get_enemies_in_range = get_enemies_in_range,
    get_enemies_on_line = get_enemies_on_line,
    get_hero_point = get_hero_point,
    is_active_enemy = is_active_enemy,
    add_hero_attr_pack = add_hero_attr_pack,
    snapshot_hero_attrs = snapshot_hero_attrs,
    get_bond_runtime_bonus = get_bond_runtime_bonus,
    get_combat_bonus = get_combat_bonus,
  }
end

return M
