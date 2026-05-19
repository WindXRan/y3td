local SkillSystem = {}

local skill_framework = require 'runtime.skills.skill_framework'
local attack_skills = require 'runtime.skills.attack_skills'
local generated_skills = require 'runtime.skills.generated_skills'
local auto_active_effects = require 'runtime.effects.auto_active_effects'

SkillSystem.framework = skill_framework
SkillSystem.attack = attack_skills
SkillSystem.generated = generated_skills
SkillSystem.auto_effects = auto_active_effects

local BootCombat = require 'runtime.core.boot_combat'

function SkillSystem.update_attack_skills(dt)
  local STATE = _G.STATE
  if not STATE or not STATE.hero or not STATE.hero:is_exist() or STATE.game_finished or STATE.auto_cast_disabled then
    return
  end

  local runtime = STATE.active_skill_runtime
  if not runtime or not runtime.active_ids or #runtime.active_ids == 0 then
    return
  end

  local now = (y3 and y3.game and y3.game.current_game_run_time and y3.game.current_game_run_time()) or 0
  if runtime.next_cast_ready_time and now < runtime.next_cast_ready_time then
    return
  end

  for _ = 1, #runtime.active_ids do
    if not runtime.cursor or runtime.cursor > #runtime.active_ids then
      runtime.cursor = 1
    end

    local skill_id = runtime.active_ids[runtime.cursor]
    runtime.cursor = runtime.cursor + 1

    local state = skill_framework.get_skill_state(skill_id)
    local cooldown_left = state and tonumber(state.cooldown_left) or 0
    if cooldown_left <= 0 then
      local ok = skill_framework.cast_by_id(skill_id)
      runtime.next_cast_ready_time = now + 0.08
      if ok then
        return
      end
    end
  end
end

function SkillSystem.update_enemy_statuses(dt)
  local STATE = _G.STATE
  if not STATE or not STATE.enemy_info_map or not STATE.hero or not STATE.hero:is_exist() then
    return
  end

  local damage_api = _G.td_damage_api
  local is_active_enemy = BootCombat.is_active_enemy
  local hero_attr_system = _G.hero_attr_system

  local function get_hero_attr(name, fallback_name)
    if not STATE.hero or not STATE.hero:is_exist() then return 0 end
    local attr = hero_attr_system and hero_attr_system.get_attr(STATE.hero, name)
    if attr and attr > 0 then return attr end
    if fallback_name then
      return hero_attr_system and hero_attr_system.get_attr(STATE.hero, fallback_name) or STATE.hero:get_attr(fallback_name) or 0
    end
    return STATE.hero:get_attr(name) or 0
  end

  for unit, info in pairs(STATE.enemy_info_map) do
    if info and info.status then
      local ignite = info.status.ignite
      if ignite then
        ignite.remaining = math.max(0, (ignite.remaining or 0) - dt)
        ignite.tick_cd = (ignite.tick_cd or 1) - dt
        if ignite.remaining <= 0 then
          info.status.ignite = nil
        elseif ignite.tick_cd <= 0 and is_active_enemy(unit) then
          ignite.tick_cd = 1
          if damage_api then
            damage_api.single(unit, get_hero_attr('攻击结算值', '攻击') * (ignite.tick_ratio or 0), '物理', {
              text_type = '物理',
            })
          end
        end
      end

      for _, status_id in ipairs({ 'armor_break', 'shock' }) do
        local entry = info.status[status_id]
        if entry then
          entry.remaining = math.max(0, (entry.remaining or 0) - dt)
          if entry.remaining <= 0 then
            info.status[status_id] = nil
          end
        end
      end
    end
  end
end

SkillSystem.create_skill_instance = skill_framework.create_skill_instance
SkillSystem.apply_passive_effects = skill_framework.apply_passive_effects
SkillSystem.remove_passive_effects = skill_framework.remove_passive_effects
SkillSystem.tick = skill_framework.tick
SkillSystem.cast = skill_framework.cast

SkillSystem.sync_basic_attack_ability = attack_skills.sync_basic_attack_ability
SkillSystem.unlock_attack_skill = attack_skills.unlock_attack_skill
SkillSystem.show_attack_skill_loadout = attack_skills.show_attack_skill_loadout

SkillSystem.register_all = generated_skills.register_all
SkillSystem.load_defs = generated_skills.load_defs
SkillSystem.build_rows = generated_skills.build_rows
SkillSystem.get_skill_by_id = generated_skills.get_skill_by_id

return SkillSystem