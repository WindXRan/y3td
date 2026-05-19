-- 兼容旧热更闭包：部分历史逻辑会按全局名调用这些函数。
-- boot.lua 和 bond_modifier_effects.lua 原本各自有一份重复定义，现已统一到此文件。
-- 先判断全局是否已存在再注入，防止覆盖新版本实现。

if type(_G.collect_units_in_line) ~= 'function' then
  _G.collect_units_in_line = function(_, _, _, _, _, _, fallback_target)
    if fallback_target and fallback_target.is_exist and fallback_target:is_exist() then
      return { fallback_target }
    end
    return {}
  end
end

if type(_G.get_hero) ~= 'function' then
  _G.get_hero = function(env)
    local hero = env and env.STATE and env.STATE.hero
    if hero and hero.is_exist and hero:is_exist() then
      return hero
    end
    return nil
  end
end

if type(_G.get_hero_attr) ~= 'function' then
  _G.get_hero_attr = function(env, name)
    local hero = env and env.STATE and env.STATE.hero
    if not hero or not hero.is_exist or not hero:is_exist() then
      return 0
    end
    local hero_attr_system = env and env.hero_attr_system
    if hero_attr_system and hero_attr_system.get_attr then
      return tonumber(hero_attr_system.get_attr(hero, name)) or 0
    end
    return tonumber(hero:get_attr(name)) or 0
  end
end
