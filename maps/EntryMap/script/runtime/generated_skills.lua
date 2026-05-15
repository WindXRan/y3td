-- 元素技能批量加载器
-- 从 data_csv/element_skills.csv 读取技能定义

local CsvLoader = require 'data.csv_loader'
local SkillHooks = require 'runtime.skill_hooks'
local ELEMENT_VFX = require 'runtime.skills'.ELEMENT_VFX

local M = {}

--- 内建技能定义（备用）
local function load_builtin_defs()
  return {}
end

--- CSV行转技能定义
local function csv_row_to_skill(row)
  if not row.id or row.id == '' or row.id == '__字段说明__' then
    return nil
  end

  local skill = {
    id = row.id,
    name = row.name or row.id,
    element = row.element or 'physical',
    pattern = row.pattern or 'area',
    sub_behavior = row.sub_behavior or 'burst',
    tier = row.tier or 'mid',
    damage_type = row.damage_type or '法术',
  }
  
  if row.id == 'ice_bird' then
    print('[DEBUG] ice_bird CSV row:', row.projectile_key)
  end

  -- 字段映射: CSV字段名 -> {目标表, 目标键}
  local mappings = {
    resource = {
      cooldown = 'cooldown',
      charges = 'charges',
    },
    scale = {
      attack_ratio = 'attack_ratio',
      tick_ratio = 'tick_ratio',
      bounce_ratio = 'bounce_ratio',
    },
    hit_model = {
      radius = 'radius',
      range = 'range',
      width = 'width',
      bounce = 'bounce',
      max_hits = 'max_hits',
    },
    timeline = {
      duration = 'duration',
      tick_interval = 'tick_interval',
      cast_point = 'cast_point',
      impact_delay = 'impact_delay',
    },
    visual = {
      cast_particle = 'cast',
      warning_particle = 'warning',
      impact_particle = 'impact',
      hit_particle = 'hit',
      projectile_key = 'projectile_key',
      projectile_height = 'projectile_height',
      projectile_time = 'projectile_time',
    },
  }

  for target_table, fields in pairs(mappings) do
    skill[target_table] = {}
    for csv_field, target_key in pairs(fields) do
      local val = row[csv_field]
      if val and val ~= '' then
        local num = tonumber(val)
        if num then
          skill[target_table][target_key] = num
        end
      end
    end
  end

  -- 应用元素VFX默认值（当CSV中未配置时）
  local element_vfx = ELEMENT_VFX[skill.element]
  if element_vfx then
    for k, v in pairs(element_vfx) do
      if skill.id == 'ice_bird' then
        print('[DEBUG] ice_bird visual[' .. k .. '] =', skill.visual[k], ', will apply default:', v, ', condition:', skill.visual[k] == nil)
      end
      if skill.visual[k] == nil then
        skill.visual[k] = v
      end
    end
  end

  return skill
end

--- 加载所有技能定义
--- @return table[] 完整的技能定义列表
function M.load_defs()
  local defs = {}
  local csv_rows = CsvLoader.read_rows_optional({path = 'data_csv/element_skills.csv'})

  for _, row in ipairs(csv_rows) do
    local def = csv_row_to_skill(row)
    if def then
      defs[#defs + 1] = def
    end
  end

  return defs
end

--- 创建运行时 API，需要注入 framework 实例
--- @param skill_framework table SkillFramework.create() 的返回值
function M.create(skill_framework)
  local api = {}
  local registered_ids = {}

  --- 批量注册所有技能
  --- @return number 成功注册数量
  --- @return table 已加载的技能定义列表
  function api.register_all()
    local defs = M.load_defs()
    local count = 0
    for _, def in ipairs(defs) do
      local ok, err = skill_framework.register(def)
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
