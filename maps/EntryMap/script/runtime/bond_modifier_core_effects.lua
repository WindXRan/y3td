local M = {}

function M.create(deps)
  deps = deps or {}

  local get_attack_value = deps.get_attack_value
  local get_max_hp_value = deps.get_max_hp_value
  local get_three_attr_value = deps.get_three_attr_value
  local get_hero_attr = deps.get_hero_attr
  local get_visual_config = deps.get_visual_config
  local get_hero = deps.get_hero
  local get_game_time = deps.get_game_time
  local has_card_effect = deps.has_card_effect
  local try_chance = deps.try_chance
  local play_bond_sound = deps.play_bond_sound
  local play_particle_on_unit = deps.play_particle_on_unit
  local play_impact_burst = deps.play_impact_burst
  local play_lightning_strike = deps.play_lightning_strike
  local launch_projectile_to_target = deps.launch_projectile_to_target
  local wait_seconds = deps.wait_seconds
  local execute_linear_bond_template = deps.execute_linear_bond_template
  local trigger_dragon_fireball_effect = deps.trigger_dragon_fireball_effect
  local blink_hero_tactical_reposition = deps.blink_hero_tactical_reposition
  local schedule_summon_lifecycle_fx = deps.schedule_summon_lifecycle_fx
  local damage_target = deps.damage_target
  local damage_area = deps.damage_area
  local update_magic_swordsman_runtime_bonus = deps.update_magic_swordsman_runtime_bonus

  local api = {}

  function api.trigger_modifier_basic_attack_effect(env, runtime, bond_name, effect_state, target)
    if not runtime or not target then
      return false
    end
    local function report_cast(count)
      if env and env.report_auto_acceptance_event then
        env.report_auto_acceptance_event({
          scope = 'bond',
          key = bond_name,
          cast = tonumber(count) or 1,
        })
      end
    end
    local function bond_damage_target(unit, amount, damage_type)
      return damage_target(env, unit, amount, damage_type, { scope = 'bond', key = bond_name })
    end
    local function bond_damage_area(center, radius, amount, damage_type, except_unit, max_count)
      return damage_area(env, center, radius, amount, damage_type, except_unit, max_count, { scope = 'bond', key = bond_name })
    end
    local attack = get_attack_value(env)
    local three_attr = get_three_attr_value(env)
    local attack_speed = get_hero_attr(env, '攻击速度')
    local visual_cfg = get_visual_config(bond_name)

    if bond_name == '枪炮师' then
      if try_chance(0.08) then
        report_cast(1)
        local hit = false
        local wave_count = has_card_effect(runtime, '战术后撤') and 2 or 1
        local wave_damage = attack * 3.0 + three_attr * 0.45
        for index = 1, wave_count do
          if index > 1 then
            blink_hero_tactical_reposition(env, target, visual_cfg)
          end
          execute_linear_bond_template(env, target, visual_cfg, {
            bond_name = '枪炮师',
            distance = 1700,
            width = 210,
            projectile_speed = visual_cfg.projectile_speed,
            instant_hit = true,
            target_fx_scale = 1.0,
            target_fx_time = 0.25,
            hit_fx_scale = 0.9,
            hit_fx_time = 0.18,
          }, function(unit)
            hit = bond_damage_target(unit, wave_damage, '物理') or hit
          end)
        end
        return hit
      end
    elseif bond_name == '神射手' then
      if try_chance(0.08) then
        report_cast(1)
        play_bond_sound(env, '神射手', 'cast', get_hero(env))
        launch_projectile_to_target(env, target, visual_cfg)
        play_bond_sound(env, '神射手', 'impact', target)
        play_particle_on_unit(env, target, visual_cfg.particle_key, 0.9, 0.25)
        return bond_damage_target(target, attack * 1.2 + attack_speed * 0.5, '物理')
      end
    elseif bond_name == '游侠' then
      if try_chance(0.08) then
        report_cast(1)
        play_bond_sound(env, '游侠', 'cast', get_hero(env))
        launch_projectile_to_target(env, target, visual_cfg)
        for index = 0, 2 do
          env.y3.ltimer.wait(index * 0.2, function()
            play_bond_sound(env, '游侠', 'impact', target)
            play_particle_on_unit(env, target, visual_cfg.particle_key, 0.75, 0.20)
            bond_damage_area(target, 320, attack * 0.8, '物理')
          end)
        end
        return true
      end
    elseif bond_name == '狂战士' then
      if try_chance(0.30) then
        report_cast(1)
        local current_hp = target.get_hp and (tonumber(target:get_hp()) or 0) or 0
        local target_max_hp = target.get_attr and (tonumber(target:get_attr('生命')) or tonumber(target:get_attr('最大生命')) or current_hp) or current_hp
        play_bond_sound(env, '狂战士', 'cast', get_hero(env))
        play_bond_sound(env, '狂战士', 'impact', target)
        play_particle_on_unit(env, target, visual_cfg.particle_key, 1.1, 0.25)
        return bond_damage_target(target, attack * 0.1 + math.max(0, target_max_hp - current_hp) * 0.05, '物理')
      end
    elseif bond_name == '剑魂' then
      effect_state.counter = (effect_state.counter or 0) + 1
      if effect_state.counter >= 10 then
        report_cast(1)
        effect_state.counter = 0
        play_bond_sound(env, '剑魂', 'cast', get_hero(env))
        launch_projectile_to_target(env, target, visual_cfg)
        wait_seconds(env, 0.04, function()
          launch_projectile_to_target(env, target, visual_cfg)
        end)
        play_bond_sound(env, '剑魂', 'impact', target)
        play_impact_burst(env, target, visual_cfg.particle_key, 1.0)
        return bond_damage_target(target, attack * 1.5, '物理')
      end
    elseif bond_name == '剑宗' then
      if try_chance(0.08) then
        report_cast(1)
        local tick_damage = attack * 0.1 + get_hero_attr(env, '剑意') * 2.0
        play_bond_sound(env, '剑宗', 'cast', get_hero(env))
        play_impact_burst(env, target, visual_cfg.particle_key, 1.05)
        launch_projectile_to_target(env, target, visual_cfg)
        for index = 0, 14 do
          env.y3.ltimer.wait(index * 0.2, function()
            play_bond_sound(env, '剑宗', 'impact', target)
            play_particle_on_unit(env, target, visual_cfg.particle_key, 0.7, 0.15)
            if index % 5 == 4 then
              play_impact_burst(env, target, visual_cfg.particle_key, 0.85)
            end
            bond_damage_area(target, 320, tick_damage, '物理')
          end)
        end
        return true
      end
    elseif bond_name == '龙骑士' then
      report_cast(1)
      local trigger_floor = has_card_effect(runtime, '致命一击') and 0.15 or 0.08
      return trigger_dragon_fireball_effect(env, runtime, target, effect_state, trigger_floor, 1.00, 1.00)
    elseif bond_name == '战斗法师' or bond_name == '战法法师' then
      if try_chance(0.08) then
        report_cast(1)
        play_bond_sound(env, '战斗法师', 'cast', get_hero(env))
        launch_projectile_to_target(env, target, visual_cfg)
        play_bond_sound(env, '战斗法师', 'impact', target)
        play_particle_on_unit(env, target, visual_cfg.particle_key, 1.0, 0.25)
        return bond_damage_area(target, 320, attack * 3.0, '法术')
      end
    elseif bond_name == '魔剑士' then
      local now = get_game_time(env)
      if (effect_state.demon_until or 0) > now then
        report_cast(1)
        play_bond_sound(env, '魔剑士', 'cast', get_hero(env))
        launch_projectile_to_target(env, target, visual_cfg)
        play_bond_sound(env, '魔剑士', 'impact', target)
        play_particle_on_unit(env, target, visual_cfg.particle_key, 0.8, 0.20)
        return bond_damage_target(target, attack * 2.0, '法术')
      end
    end

    return false
  end

  function api.trigger_modifier_periodic_effect(env, runtime, bond_name, effect_state, dt)
    local function report_cast(count)
      if env and env.report_auto_acceptance_event then
        env.report_auto_acceptance_event({
          scope = 'bond',
          key = bond_name,
          cast = tonumber(count) or 1,
        })
      end
    end
    local function bond_damage_target(unit, amount, damage_type)
      return damage_target(env, unit, amount, damage_type, { scope = 'bond', key = bond_name })
    end
    local function bond_damage_area(center, radius, amount, damage_type, except_unit, max_count)
      return damage_area(env, center, radius, amount, damage_type, except_unit, max_count, { scope = 'bond', key = bond_name })
    end
    effect_state.elapsed = (effect_state.elapsed or 0) + (dt or 0)
    if (effect_state.cooldown or 0) > 0 then
      effect_state.cooldown = math.max(0, (effect_state.cooldown or 0) - (dt or 0))
    end
    local attack = get_attack_value(env)
    local visual_cfg = get_visual_config(bond_name)
    local now = get_game_time(env)

    if bond_name == '火法师' and effect_state.elapsed >= 5 then
      report_cast(1)
      effect_state.elapsed = effect_state.elapsed - 5
      local target = env.get_enemies_in_range and env.get_enemies_in_range(env.STATE.hero, 1200, nil, 1)[1] or nil
      if target then
        play_bond_sound(env, '火法师', 'cast', get_hero(env))
        launch_projectile_to_target(env, target, visual_cfg)
        play_bond_sound(env, '火法师', 'impact', target)
        play_particle_on_unit(env, target, visual_cfg.particle_key, 1.0, 0.25)
      end
      return bond_damage_target(target, attack * 1.5, '法术')
    elseif (bond_name == '冰霜法师' or bond_name == '寒冰法师') and effect_state.elapsed >= 5 then
      report_cast(1)
      effect_state.elapsed = effect_state.elapsed - 5
      local target = env.get_enemies_in_range and env.get_enemies_in_range(env.STATE.hero, 1200, nil, 1)[1] or nil
      if target then
        play_bond_sound(env, bond_name, 'cast', get_hero(env))
        launch_projectile_to_target(env, target, visual_cfg)
        local tick_damage = attack * 0.35 + get_max_hp_value(env) * 0.018
        for index = 0, 5 do
          env.y3.ltimer.wait(index * 0.5, function()
            play_bond_sound(env, bond_name, 'impact', target)
            play_particle_on_unit(env, target, visual_cfg.particle_key, 0.75, 0.20)
            bond_damage_area(target, 360, tick_damage, '法术')
          end)
        end
        return true
      end
    elseif bond_name == '猎人' and effect_state.elapsed >= 30 then
      effect_state.elapsed = effect_state.elapsed - 30
      local hero = env and env.STATE and env.STATE.hero
      return schedule_summon_lifecycle_fx(env, hero, visual_cfg, 23, 'magic_deer')
    elseif bond_name == '雷电法王' and effect_state.elapsed >= 1 then
      local repeat_count = math.floor(effect_state.elapsed / 1)
      effect_state.elapsed = effect_state.elapsed - repeat_count * 1

      local target_count = 2
      local bonus_pack = runtime and runtime.modifier_pool_active_runtime_bonuses and runtime.modifier_pool_active_runtime_bonuses['initial_bond_set_雷电法王'] or nil
      if bonus_pack and bonus_pack.lightning_target_count then
        target_count = math.max(target_count, math.floor(tonumber(bonus_pack.lightning_target_count) or 0))
      end
      if has_card_effect(runtime, '雷元爆发') then
        target_count = math.max(target_count, 6)
      end
      local damage_ratio = has_card_effect(runtime, '雷电天赋') and 3.75 or 3.0

      local cast_count = repeat_count * 2
      if cast_count > 0 then
        report_cast(cast_count)
      end
      local hit = false
      for _ = 1, cast_count do
        local hero = env and env.STATE and env.STATE.hero
        local targets = env.get_enemies_in_range and env.get_enemies_in_range(hero, 1200, nil, target_count) or {}
        for _, target in ipairs(targets) do
          if target and target.is_exist and target:is_exist() then
            play_bond_sound(env, '雷电法王', 'cast', get_hero(env))
            play_lightning_strike(env, target, visual_cfg)
            play_bond_sound(env, '雷电法王', 'impact', target)
            hit = bond_damage_target(target, attack * damage_ratio, '法术') or hit
          end
        end
      end
      return hit
    elseif bond_name == '骷髅法师' and effect_state.elapsed >= 30 then
      local repeat_count = math.floor(effect_state.elapsed / 30)
      effect_state.elapsed = effect_state.elapsed - repeat_count * 30
      for _ = 1, repeat_count do
        local hero = env and env.STATE and env.STATE.hero
        schedule_summon_lifecycle_fx(env, hero, visual_cfg, 25, 'skeleton')
      end
      return true
    elseif bond_name == '魔剑士' then
      local demon_active = (effect_state.demon_until or 0) > now
      update_magic_swordsman_runtime_bonus(runtime, demon_active)
    end
    return false
  end

  return api
end

return M
