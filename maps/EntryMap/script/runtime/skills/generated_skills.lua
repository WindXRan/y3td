-- 元素技能加载器
-- 从 data/tables/skill/element_skills_data.lua 读取技能定义

local SkillData = require 'data.tables.skill.element_skills_data'
local ELEMENT_VFX = require 'runtime.skills.defs'.ELEMENT_VFX

local M = {}

--- 加载所有技能定义（从 Lua 数据表）
--- @return table[] 完整的技能定义列表
function M.load_defs()
  local defs = {}
  for _, row in ipairs(SkillData.list) do
    local skill = {
      id = row.id,
      name = row.name or row.id,
      element = row.element or 'physical',
      pattern = row.pattern or 'area',
      sub_behavior = row.sub_behavior or 'burst',
      tier = row.tier or 'mid',
      damage_type = row.damage_type or '法术',
      desc = row.desc or '',
      resource = {
        cooldown = row.cooldown,
        charges = row.charges,
      },
      scale = {
        attack_ratio = row.attack_ratio,
        tick_ratio = row.tick_ratio,
        bounce_ratio = row.bounce_ratio,
      },
      hit_model = {
        radius = row.radius,
        range = row.range,
        width = row.width,
        bounce = row.bounce,
        max_hits = row.max_hits,
      },
      timeline = {
        duration = row.duration,
        tick_interval = row.tick_interval,
        cast_point = row.cast_point,
        impact_delay = row.impact_delay,
      },
      visual = {},
    }

    -- 从行数据复制已有的 visual 字段
    if row.visual then
      for k, v in pairs(row.visual) do
        skill.visual[k] = v
      end
    end

    -- 应用元素VFX默认值（只补未配置的字段）
    local element_vfx = ELEMENT_VFX[skill.element]
    if element_vfx then
      for k, v in pairs(element_vfx) do
        if skill.visual[k] == nil then
          skill.visual[k] = v
        end
      end
    end

    skill.hooks = {}

    defs[#defs + 1] = skill
  end
  return defs
end

-- 自初始化：从全局获取 skill_framework 实例
local skill_framework = _G.skill_framework_system
if not skill_framework then
  error('[generated_skills] skill_framework required')
end
local api = {}
local registered_ids = {}

--- 批量注册所有技能
--- @return number 成功注册数量
--- @return table 已加载的技能定义列表
function api.register_all()
  local defs = M.load_defs()
  local count = 0
  for _, def in ipairs(defs) do
    local ok = skill_framework.register(def)
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

_G.generated_skills_api = api
_G.SYSTEM = _G.SYSTEM or {}
_G.SYSTEM.generated_skills = api

-- 将 M 的方法合并到 api，统一对外接口
api.load_defs = M.load_defs

return api
