-- 元素技能批量加载器
-- 从 data_csv/element_skills.csv 读取技能定义，一键注册到 skill_framework。
-- 策划只需编辑 CSV，无需写 Lua 代码。

local CsvLoader = require 'data.csv_loader'
local Skills = require 'runtime.skills'
local SkillHooks = require 'runtime.skill_hooks'

local M = {}

local OPTIONAL_NUMBER_KEYS = {
  cooldown = true,
  attack_ratio = true,
  radius = true,
  range = true,
  bounce = true,
  charges = true,
  width = true,
  duration = true,
  tick_interval = true,
  cast_point = true,
  impact_delay = true,
  max_hits = true,
  bounce_ratio = true,
}

local OPTIONAL_STRING_KEYS = {
  damage_type = true,
  sub_behavior = true,
  desc = true,
}

local function safe_number(value)
  local n = tonumber(value)
  if n == nil then
    return nil
  end
  return n
end

--- 从 CSV 行构建 override 表（只包含非空字段）
local function build_overrides(row)
  local overrides = {}
  overrides.id = row.id
  overrides.name = row.name

  for key, _ in pairs(OPTIONAL_NUMBER_KEYS) do
    local n = safe_number(row[key])
    if n ~= nil then
      if key == 'cooldown' then
        overrides.resource = overrides.resource or {}
        overrides.resource.cooldown = n
      elseif key == 'charges' then
        overrides.resource = overrides.resource or {}
        overrides.resource.charges = n
      elseif key == 'attack_ratio' then
        overrides.scale = overrides.scale or {}
        overrides.scale.attack_ratio = n
      elseif key == 'radius' then
        overrides.hit_model = overrides.hit_model or {}
        overrides.hit_model.radius = n
      elseif key == 'range' then
        overrides.hit_model = overrides.hit_model or {}
        overrides.hit_model.range = n
      elseif key == 'bounce' then
        overrides.hit_model = overrides.hit_model or {}
        overrides.hit_model.bounce = n
      elseif key == 'width' then
        overrides.hit_model = overrides.hit_model or {}
        overrides.hit_model.width = n
      elseif key == 'max_hits' then
        overrides.hit_model = overrides.hit_model or {}
        overrides.hit_model.max_hits = n
      elseif key == 'duration' then
        overrides.timeline = overrides.timeline or {}
        overrides.timeline.duration = n
      elseif key == 'tick_interval' then
        overrides.timeline = overrides.timeline or {}
        overrides.timeline.tick_interval = n
      elseif key == 'cast_point' then
        overrides.timeline = overrides.timeline or {}
        overrides.timeline.cast_point = n
      elseif key == 'impact_delay' then
        overrides.timeline = overrides.timeline or {}
        overrides.timeline.impact_delay = n
      elseif key == 'bounce_ratio' then
        overrides.scale = overrides.scale or {}
        overrides.scale.bounce_ratio = n
      end
    end
  end

  for key, _ in pairs(OPTIONAL_STRING_KEYS) do
    local value = row[key]
    if value ~= nil and value ~= '' then
      if key == 'damage_type' then
        overrides.damage_type = value
      else
        overrides[key] = value
      end
    end
  end

  -- 额外透传字段
  if row.element and row.element ~= '' then
    overrides.element = row.element
  end
  if row.desc and row.desc ~= '' then
    overrides.desc = row.desc
  end

  return overrides
end

--- 从 CSV 加载所有技能定义
--- @return table[] 完整的技能定义列表
function M.load_defs()
  local defs = {}

  -- 内建技能（自定义粒子，不适合进 CSV）
  for _, builtin in ipairs(M.load_builtin_defs()) do
    defs[#defs + 1] = builtin
  end

  local rows = CsvLoader.read_rows_optional('data_csv/element_skills.csv')
  for _, row in ipairs(rows) do
    local element = row.element or 'physical'
    local pattern = row.pattern or 'area_burst'
    local tier = row.tier or 'mid'
    local mapped = Skills.PATTERN_SUB_BEHAVIOR[pattern]
    local sub_behavior = row.sub_behavior
    if mapped then
      pattern = mapped.pattern
      if sub_behavior == nil or sub_behavior == '' then
        sub_behavior = mapped.sub_behavior
      end
    end

    if not row.id or row.id == '' then
      goto continue
    end

    local overrides = build_overrides(row)
    overrides.pattern = pattern
    overrides.sub_behavior = sub_behavior
    local def = Skills.build_element_skill(element, pattern, tier, overrides)
    if def then
      -- 从 hook 注册表自动挂载特例行为
      for _, hook_name in ipairs({ 'OnSpellStart', 'OnProjectileHit', 'OnTick', 'OnFinish' }) do
        local hook_fn = SkillHooks.get(def.id, hook_name)
        if hook_fn then
          print('[skill_hooks] 注册 ' .. def.id .. ' ' .. hook_name .. ' hook')
          def.hooks = def.hooks or {}
          def.hooks[hook_name] = hook_fn
        end
      end
      defs[#defs + 1] = def
    end

    ::continue::
  end
  return defs
end

--- 内建技能定义（非 CSV 驱动，使用自定义粒子资源）
--- @return table[]
function M.load_builtin_defs()
  return {
    {
      id = 'custom_area_dot',
      name = '持续伤害领域',
      pattern = 'area',
      sub_behavior = 'tick',
      target_mode = 'point',
      damage_type = '法术',
      timeline = {
        duration = 5.0,
        tick_interval = 0.5,
        cast_point = 0.10,
        impact_delay = 0.20,
      },
      hit_model = {
        radius = 200,
        range = 1200,
      },
      scale = {
        tick_ratio = 0.4,
      },
      resource = {
        cooldown = 1.2,
      },
      visual = {
        cast = 103615,
        warning = 103615,
        impact = 103615,
        hit = 103615,
      },
    },
    {
      id = 'custom_area_burst',
      name = '瞬间爆发领域',
      pattern = 'area',
      sub_behavior = 'burst',
      target_mode = 'point',
      damage_type = '法术',
      timeline = {
        cast_point = 0.10,
        impact_delay = 0.24,
      },
      hit_model = {
        radius = 200,
        range = 1200,
      },
      scale = {
        attack_ratio = 1.8,
      },
      resource = {
        cooldown = 0.95,
      },
      visual = {
        cast = 104733,
        warning = 104733,
        impact = 104733,
        hit = 104733,
      },
    },
  }
end

--- 创建运行时 API，需要注入 framework 实例
--- @param skill_framework table SkillFramework.create() 的返回值
function M.create(skill_framework)
  local api = {}
  local registered_ids = {}

  --- 批量注册 CSV 中所有技能
  --- @return number 成功注册数量
  --- @return table 已加载的技能定义列表
  function api.register_all()
    local defs = M.load_defs()
    local count = 0
    for _, def in ipairs(defs) do
      local ok, _ = skill_framework.register(def)
      if ok then
        registered_ids[def.id] = true
        count = count + 1
      end
    end
    return count, defs
  end

  --- 按 ID 施放技能
  function api.cast(id, cast_params)
    if not registered_ids[id] then
      return false, string.format('[generated] 未注册技能：%s', tostring(id))
    end
    return skill_framework.cast_by_id(id, cast_params)
  end

  --- 列出所有已注册的技能 ID
  function api.list_ids()
    local result = {}
    for id, _ in pairs(registered_ids) do
      result[#result + 1] = id
    end
    table.sort(result)
    return result
  end

  --- 打印已注册技能列表
  function api.print_list()
    local ids = api.list_ids()
    if #ids == 0 then
      return '没有已注册的元素技能。'
    end
    return table.concat(ids, ', ')
  end

  return api
end

return M
