local M = {}

function M.create(deps)
  deps = deps or {}

  local has_card_effect = deps.has_card_effect
  local has_any_card_effect = deps.has_any_card_effect
  local ensure_card_effect_state = deps.ensure_card_effect_state
  local ensure_custom_card_effect_state = deps.ensure_custom_card_effect_state
  local add_hero_attr = deps.add_hero_attr
  local get_hero = deps.get_hero
  local get_hero_attr = deps.get_hero_attr
  local get_attack_value = deps.get_attack_value
  local get_max_hp_value = deps.get_max_hp_value
  local get_game_time = deps.get_game_time
  local get_visual_config = deps.get_visual_config
  local play_particle_on_unit = deps.play_particle_on_unit
  local play_lightning_strike = deps.play_lightning_strike
  local launch_projectile_to_target = deps.launch_projectile_to_target
  local damage_target = deps.damage_target
  local damage_area = deps.damage_area
  local try_chance = deps.try_chance
  local push_stack_expire = deps.push_stack_expire
  local cleanup_stack_expire = deps.cleanup_stack_expire
  local update_card_stack_attr = deps.update_card_stack_attr
  local schedule_summon_lifecycle_fx = deps.schedule_summon_lifecycle_fx
  local trigger_dragon_fireball_effect = deps.trigger_dragon_fireball_effect
  local update_magic_swordsman_runtime_bonus = deps.update_magic_swordsman_runtime_bonus
  local has_active_modifier_bond = deps.has_active_modifier_bond

  local api = {}

  function api.trigger_modifier_card_basic_attack_effects(env, runtime, target)
    if not runtime or not target then
      return false
    end

    local attack = get_attack_value(env)
    local attack_speed = get_hero_attr(env, '攻击速度')
    local max_hp = get_max_hp_value(env)
    local triggered = false
    local now = get_game_time(env)

    if has_card_effect(runtime, 'BBQ') and try_chance(0.08) then
      local visual_cfg = get_visual_config('枪炮师')
      for index = 0, 14 do
        env.y3.ltimer.wait(index * 0.2, function()
          if target and target.is_exist and target:is_exist() then
            play_particle_on_unit(env, target, visual_cfg.particle_key, 0.8, 0.15)
            damage_area(env, target, 320, attack * 0.30, '物理', nil, 5)
          end
        end)
      end
      triggered = true
    end

    if (has_card_effect(runtime, '穿云箭') or has_card_effect(runtime, '穿甲射击')) and try_chance(0.08) then
      local visual_cfg = get_visual_config('神射手')
      launch_projectile_to_target(env, target, visual_cfg)
      play_particle_on_unit(env, target, visual_cfg.particle_key, 0.9, 0.20)
      damage_target(env, target, attack * 1.2 + attack_speed * 0.5, '物理')
      triggered = true
    end

    if has_card_effect(runtime, '嗜血') and env.heal_hero then
      env.heal_hero(max_hp * 0.01)
      triggered = true
    end

    if has_card_effect(runtime, '毒蛇钉刺') and try_chance(0.08) then
      local hero = env and env.STATE and env.STATE.hero
      if hero and hero.is_exist and hero:is_exist() then
        play_particle_on_unit(env, hero, get_visual_config('游侠').particle_key, 1.0, 0.20)
        damage_area(env, hero, 320, attack * 2.0, '物理', nil, 8)
        triggered = true
      end
    end

    if has_any_card_effect(runtime, { '毒箭雨', '敏锐', '坚韧', '毒前雨' }) then
      local chance = has_card_effect(runtime, '毒前雨') and 0.09 or 0.08
      if try_chance(chance) then
        local visual_cfg = get_visual_config('游侠')
        for index = 0, 2 do
          env.y3.ltimer.wait(index * 0.2, function()
            if target and target.is_exist and target:is_exist() then
              play_particle_on_unit(env, target, visual_cfg.particle_key, 0.75, 0.20)
              damage_area(env, target, 320, attack * 0.8, '物理')
            end
          end)
        end
        triggered = true
      end
    end

    if has_card_effect(runtime, '疾风弓') then
      local state = ensure_card_effect_state(runtime, '疾风弓')
      if state then
        push_stack_expire(state, now + 5)
        cleanup_stack_expire(state, now, 10)
        update_card_stack_attr(env, state, 0, 5)
        triggered = true
      end
    end

    if has_card_effect(runtime, '幻影剑舞') and try_chance(0.30) then
      local state = ensure_card_effect_state(runtime, '幻影剑舞')
      if state then
        push_stack_expire(state, now + 5)
        cleanup_stack_expire(state, now, 10)
        update_card_stack_attr(env, state, 20, 2)
        triggered = true
      end
    end

    if has_card_effect(runtime, '斩击') or has_card_effect(runtime, '剑魂') then
      local state = ensure_card_effect_state(runtime, '斩击')
      if state then
        state.counter = (state.counter or 0) + 1
        if state.counter >= 10 then
          state.counter = 0
          play_particle_on_unit(env, target, get_visual_config('剑魂').particle_key, 0.9, 0.20)
          damage_target(env, target, attack * 1.5, '物理')
          triggered = true
        end
      end
    end

    if has_any_card_effect(runtime, { '狂刀斩', '重甲精通', '力量唤醒' }) and try_chance(0.30) then
      local current_hp = target.get_hp and (tonumber(target:get_hp()) or 0) or 0
      local target_max_hp = target.get_attr and (tonumber(target:get_attr('生命')) or tonumber(target:get_attr('最大生命')) or current_hp) or current_hp
      play_particle_on_unit(env, target, get_visual_config('狂战士').particle_key, 1.0, 0.20)
      damage_target(env, target, attack * 0.1 + math.max(0, target_max_hp - current_hp) * 0.05, '物理')
      triggered = true
    end

    if has_any_card_effect(runtime, { '龙族血统', '神龙摆尾', '致命一击' }) then
      local state = ensure_custom_card_effect_state(runtime, 'dragon_fireball_shared')
      if state then
        local floor = has_card_effect(runtime, '致命一击') and 0.15 or 0.10
        local damage_boost = has_card_effect(runtime, '龙族血统') and 1.20 or 1.00
        local radius_boost = has_card_effect(runtime, '神龙摆尾') and 1.20 or 1.00
        if trigger_dragon_fireball_effect(env, runtime, target, state, floor, damage_boost, radius_boost) then
          triggered = true
        end
      end
    end

    return triggered
  end

  function api.trigger_modifier_card_periodic_effects(env, runtime, dt)
    if not runtime then
      return false
    end

    local triggered = false
    if runtime.modifier_card_effect_state then
      for _, state in pairs(runtime.modifier_card_effect_state) do
        if type(state) == 'table' and (state.cooldown or 0) > 0 then
          state.cooldown = math.max(0, (state.cooldown or 0) - (dt or 0))
        end
      end
    end
    if runtime.modifier_card_effect_custom_state then
      for _, state in pairs(runtime.modifier_card_effect_custom_state) do
        if type(state) == 'table' and (state.cooldown or 0) > 0 then
          state.cooldown = math.max(0, (state.cooldown or 0) - (dt or 0))
        end
      end
    end
    local attack = get_attack_value(env)
    local max_hp = get_max_hp_value(env)
    local now = get_game_time(env)

    if has_card_effect(runtime, '连射') then
      local state = ensure_card_effect_state(runtime, '连射')
      if state then
        local target_multishot = 1
        local applied_multishot = state.applied_multishot or 0
        local delta = target_multishot - applied_multishot
        if delta ~= 0 then
          add_hero_attr(env, '多重数量', delta)
          state.applied_multishot = target_multishot
        end
      end
    end

    if has_card_effect(runtime, '火焰炉盾') then
      local state = ensure_card_effect_state(runtime, '火焰炉盾')
      if state then
        state.elapsed = (state.elapsed or 0) + (dt or 0)
        if state.elapsed >= 10 then
          state.elapsed = state.elapsed - 10
          if env.heal_hero then
            env.heal_hero(max_hp * 0.20)
          end
          play_particle_on_unit(env, env and env.STATE and env.STATE.hero, get_visual_config('火法师').particle_key, 1.0, 0.25)
          triggered = true
        end
      end
    end

    if has_card_effect(runtime, '引雷咒') then
      local state = ensure_card_effect_state(runtime, '引雷咒')
      if state then
        state.elapsed = (state.elapsed or 0) + (dt or 0)
        while state.elapsed >= 1 do
          state.elapsed = state.elapsed - 1
          local hero = env and env.STATE and env.STATE.hero
          local target_count = has_card_effect(runtime, '雷元爆发') and 5 or 2
          local damage_ratio = has_card_effect(runtime, '雷电天赋') and 3.75 or 3.0
          for _ = 1, 2 do
            local targets = env.get_enemies_in_range and env.get_enemies_in_range(hero, 1200, nil, target_count) or {}
            for _, target in ipairs(targets) do
              play_lightning_strike(env, target, get_visual_config('雷电法王'))
              damage_target(env, target, attack * damage_ratio, '法术')
              triggered = true
            end
          end
        end
      end
    end

    local function update_hunter_summon_card(card_name, duration_sec)
      local state = ensure_card_effect_state(runtime, card_name)
      if not state then
        return
      end
      state.elapsed = (state.elapsed or 0) + (dt or 0)
      while state.elapsed >= 30 do
        state.elapsed = state.elapsed - 30
        local hero = get_hero(env)
        local summon_kind = 'magic_bear'
        if card_name == '自然之体' then
          summon_kind = 'magic_deer'
        elseif card_name == '召唤猎鹰' then
          summon_kind = 'hawk'
        end
        schedule_summon_lifecycle_fx(env, hero, get_visual_config('猎人'), duration_sec, summon_kind)
        triggered = true
      end
    end
    if has_card_effect(runtime, '自然之体') then
      update_hunter_summon_card('自然之体', 23)
    end
    if has_card_effect(runtime, '猎人') then
      update_hunter_summon_card('猎人', 25)
    end
    if has_card_effect(runtime, '奔袭') then
      update_hunter_summon_card('奔袭', 25)
    end
    if has_card_effect(runtime, '召唤猎鹰') then
      update_hunter_summon_card('召唤猎鹰', 25)
    end

    local function update_skeleton_card(card_name)
      local state = ensure_card_effect_state(runtime, card_name)
      if not state then
        return
      end
      state.elapsed = (state.elapsed or 0) + (dt or 0)
      while state.elapsed >= 30 do
        state.elapsed = state.elapsed - 30
        local hero = get_hero(env)
        schedule_summon_lifecycle_fx(env, hero, get_visual_config('骷髅法师'), 25, 'skeleton')
        triggered = true
      end
    end
    if has_card_effect(runtime, '骷髅复苏') then
      update_skeleton_card('骷髅复苏')
    end
    if has_card_effect(runtime, '骷髅支配') then
      update_skeleton_card('骷髅支配')
    end
    if has_card_effect(runtime, '骷髅恐惧') then
      update_skeleton_card('骷髅恐惧')
    end
    if has_card_effect(runtime, '骷髅压制') then
      update_skeleton_card('骷髅压制')
    end
    if has_card_effect(runtime, '骷髅审判') then
      update_skeleton_card('骷髅审判')
    end

    if has_card_effect(runtime, '疾风弓') then
      local state = ensure_card_effect_state(runtime, '疾风弓')
      if state then
        cleanup_stack_expire(state, now, 10)
        update_card_stack_attr(env, state, 0, 5)
      end
    end
    if has_card_effect(runtime, '幻影剑舞') then
      local state = ensure_card_effect_state(runtime, '幻影剑舞')
      if state then
        cleanup_stack_expire(state, now, 10)
        update_card_stack_attr(env, state, 20, 2)
      end
    end

    if has_card_effect(runtime, '狂化') then
      local state = ensure_card_effect_state(runtime, '狂化')
      if state then
        state.elapsed = (state.elapsed or 0) + (dt or 0)
        if state.elapsed >= 2 then
          state.elapsed = state.elapsed - 2
          state.frenzy_until = now + 5
        end
        local frenzy_active = (state.frenzy_until or 0) > now
        local target_bonus = frenzy_active and 1.0 or 0.0
        local applied_bonus = state.applied_all_damage_bonus or 0.0
        if target_bonus ~= applied_bonus then
          local effect_id = '__card_runtime_狂化'
          runtime.modifier_pool_active_runtime_bonuses = runtime.modifier_pool_active_runtime_bonuses or {}
          runtime.modifier_pool_active_runtime_bonuses[effect_id] = runtime.modifier_pool_active_runtime_bonuses[effect_id] or {}
          runtime.modifier_pool_active_runtime_bonuses[effect_id].all_damage_bonus = target_bonus > 0 and target_bonus or nil
          state.applied_all_damage_bonus = target_bonus
        end
      end
    end

    return triggered
  end

  function api.handle_modifier_card_pre_hurt(env, runtime, data)
    if not runtime or type(data) ~= 'table' then
      return false
    end
    if not has_card_effect(runtime, '狂化') then
      return false
    end

    local state = ensure_card_effect_state(runtime, '狂化')
    if not state then
      return false
    end
    if (state.frenzy_until or 0) <= get_game_time(env) then
      return false
    end

    local damage_instance = data.damage_instance
    if not damage_instance or not damage_instance.get_damage or not damage_instance.set_damage then
      return false
    end

    local current_damage = tonumber(damage_instance:get_damage()) or tonumber(data.damage) or 0
    if current_damage <= 0 then
      return false
    end

    damage_instance:set_damage(current_damage * 2)
    return true
  end

  function api.handle_modifier_enemy_kill(env, runtime, info, get_cards_by_bond)
    if not runtime then
      return false
    end

    local triggered = false
    for _, effect_state in pairs(runtime.modifier_pool_effect_state or {}) do
      local bond_name = effect_state and effect_state.bond_name
      if bond_name and has_active_modifier_bond(runtime, bond_name, get_cards_by_bond) then
        if bond_name == '魔剑士' then
          local effect_id = 'initial_bond_set_魔剑士'
          local can_enter_demon = has_card_effect(runtime, '入魔')
            or (runtime.modifier_pool_active_effects and runtime.modifier_pool_active_effects[effect_id] == true)
          if can_enter_demon then
            effect_state.kill_counter = (effect_state.kill_counter or 0) + 1
            if effect_state.kill_counter >= 5 then
              effect_state.kill_counter = 0
              if try_chance(0.30) then
                effect_state.demon_until = get_game_time(env) + 5
                update_magic_swordsman_runtime_bonus(runtime, true)
                play_particle_on_unit(env, env and env.STATE and env.STATE.hero, get_visual_config('魔剑士').particle_key, 1.0, 0.30)
                triggered = true
              end
            end
          end
        elseif bond_name == '骷髅法师' then
          local _ = info
        end
      end
    end

    if has_card_effect(runtime, '中华傲决') then
      local state = ensure_card_effect_state(runtime, '中华傲决')
      if state then
        state.counter = (state.counter or 0) + 1
        if state.counter >= 100 then
          state.counter = state.counter - 100
          add_hero_attr(env, '剑意', 1)
          play_particle_on_unit(env, env and env.STATE and env.STATE.hero, get_visual_config('剑宗').particle_key, 1.0, 0.25)
          triggered = true
        end
      end
    end

    return triggered
  end

  return api
end

return M
