-- skill_handlers.lua — 技能释放事件处理
-- 监听引擎层 技能-释放结束 事件，委托给对应运行时系统

local y3 = y3

y3.game:event('技能-释放结束', function(_, data)
  local ability = data.ability
  if not ability then
    return
  end

  local ability_key = ability:get_key()

  -- 普攻 (ability 100001001)
  if ability_key == 100001001 then
    local hero = y3.hero.get_main_hero()
    if not hero or not hero:is_exist() then
      return
    end

    local as = _G.attack_skills_system
    if as and as.on_basic_attack_cast then
      as.on_basic_attack_cast(hero, data.target_point, data.target_unit)
    end
    return
  end

  -- 其他技能（未来扩展：ability_key 匹配 attack_skills_state.by_id 中的技能）
  local as = _G.attack_skills_system
  if as and as.on_skill_cast then
    local hero = y3.hero.get_main_hero()
    if hero and hero:is_exist() then
      as.on_skill_cast(hero, ability_key, data.target_point, data.target_unit)
    end
  end
end)
