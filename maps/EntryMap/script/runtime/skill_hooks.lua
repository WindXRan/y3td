-- 技能特例 hook 注册表
-- 统一管理所有"技能定义之外的附加行为"，如 fireball 的命中后灼烧。
-- 新增特例时只需在本文件添加条目，generated_skills 在注册时自动查询并挂载。
-- 接口：M.get(skill_id, hook_name) → function | nil

local BuffSystem = require 'runtime.buff_system'

local M = {}

local HOOKS = {
  fireball = {
    OnProjectileHit = function(ctx)
      print('[buff_system] fireball OnProjectileHit 触发, hits=' .. tostring(#(ctx.hits or {})))
      for _, unit in ipairs(ctx.hits or {}) do
        if unit and unit.is_exist and unit:is_exist() then
          local buff = BuffSystem.apply_buff(unit, 'burn', 3.0, 1, ctx.caster)
          print('[buff_system] apply_buff burn on ' .. tostring(unit.handle) .. ' buff=' .. tostring(buff))
        end
      end
    end,
  },
}

--- 查询某技能某 hook 的特例实现
--- @param skill_id string 技能ID
--- @param hook_name string hook 名称 (e.g. 'OnProjectileHit', 'OnFinish')
--- @return function|nil
function M.get(skill_id, hook_name)
  local skill_hooks = HOOKS[tostring(skill_id or '')]
  return skill_hooks and skill_hooks[hook_name] or nil
end

--- 列出所有已注册 hook 的技能ID
--- @return string[]
function M.list_hooked_skill_ids()
  local result = {}
  for id, _ in pairs(HOOKS) do
    result[#result + 1] = id
  end
  table.sort(result)
  return result
end

return M
