-- runtime/hero_model.lua
-- 英雄模型管理器：统一管理英雄模型的解析、替换与UI绑定。

local M = {}
local y3 = y3
local CONFIG = require 'config.entry_config'

local DEFAULT_MODEL_ID = 3001

local STATE = _G.STATE

  local hero_roster = nil
  if CONFIG and CONFIG.GameTables and CONFIG.GameTables.hero_roster then
    hero_roster = CONFIG.GameTables.hero_roster
  end

  local roster_by_name = {}
  local roster_by_id = {}

  local function build_indexes()
    if not hero_roster or not hero_roster.list then
      return
    end
    for _, entry in ipairs(hero_roster.list) do
      if entry.name and entry.name ~= '' then
        roster_by_name[entry.name] = entry
      end
      if entry.id and entry.id ~= '' then
        roster_by_id[entry.id] = entry
      end
    end
  end
  build_indexes()

  local api = {}

  -- 解析英雄模型ID，按优先级：
  --   1. 进化形态 active_form_model_id（运行时动态设置）
  --   2. 英雄名册 hero_roster.model_id（CSV 配置）
  --   3. 单位键解析 y3.unit.get_model_by_key
  --   4. 默认值 3001
  function api.resolve_model_id(params)
    params = params or {}
    local hero_name = params.hero_name
    local hero_id = params.hero_id
    local unit = params.unit

    -- 1. 进化形态模型（最高优先级）
    local evo_runtime = STATE.evolution_runtime
    if evo_runtime and evo_runtime.active_form_model_id then
      print('[hero_model] resolve_model_id: evo active_form_model_id=' .. tostring(evo_runtime.active_form_model_id))
      return evo_runtime.active_form_model_id
    end

    -- 2. 英雄名册 model_id（按名称或ID查找）
    local roster_entry = nil
    if hero_name then
      roster_entry = roster_by_name[hero_name]
    end
    if not roster_entry and hero_id then
      roster_entry = roster_by_id[hero_id]
    end
    if roster_entry and roster_entry.model_id and roster_entry.model_id ~= 0 then
      print('[hero_model] resolve_model_id: roster model_id=' .. tostring(roster_entry.model_id) .. ' hero=' .. tostring(hero_name or hero_id))
      return roster_entry.model_id
    end

    -- 3. 单位键解析
    if unit and unit.get_key and y3 and y3.unit and y3.unit.get_model_by_key then
      local ok, model_id = pcall(y3.unit.get_model_by_key, unit:get_key())
      if ok and model_id and model_id ~= 0 then
        print('[hero_model] resolve_model_id: unit_key model_id=' .. tostring(model_id))
        return model_id
      end
    end

    print('[hero_model] resolve_model_id: fallback DEFAULT_MODEL_ID=' .. tostring(DEFAULT_MODEL_ID))
    return DEFAULT_MODEL_ID
  end

  -- 获取名册中英雄条目
  function api.get_roster_entry(hero_name, hero_id)
    if hero_name and roster_by_name[hero_name] then
      return roster_by_name[hero_name]
    end
    if hero_id and roster_by_id[hero_id] then
      return roster_by_id[hero_id]
    end
    return nil
  end

  -- 安全替换单位模型
  function api.replace_model(unit, model_id)
    if not unit or not unit.is_exist or not unit:is_exist() then
      print('[hero_model] replace_model: unit invalid or not exist')
      return false
    end
    if not model_id or model_id == 0 then
      print('[hero_model] replace_model: model_id is nil or 0')
      return false
    end
    if not unit.replace_model then
      print('[hero_model] replace_model: unit.replace_model not available, type:', type(unit.replace_model))
      return false
    end
    local ok, err = pcall(unit.replace_model, unit, model_id)
    if not ok then
      print('[hero_model] replace_model pcall failed:', tostring(err))
      return false
    end
    print('[hero_model] replace_model success, model_id=' .. tostring(model_id))
    return true
  end

  -- 安全取消模型替换
  function api.cancel_replace_model(unit, model_id)
    if not unit or not unit.is_exist or not unit:is_exist() then
      return false
    end
    if not model_id or model_id == 0 then
      return false
    end
    if not unit.cancel_replace_model then
      return false
    end
    pcall(unit.cancel_replace_model, unit, model_id)
    return true
  end

  -- 解析并应用模型到英雄单位
  function api.apply_hero_model(hero, params)
    params = params or {}
    local model_id = params.model_id
    if not model_id then
      model_id = api.resolve_model_id({
        hero_name = params.hero_name,
        hero_id = params.hero_id,
        unit = hero,
      })
    end
    if not model_id or model_id == 0 then
      return false
    end
    return api.replace_model(hero, model_id)
  end

  -- 应用进化形态模型
  function api.apply_evolution_model(hero, evolution_def)
    if not hero or not evolution_def then
      return false
    end

    local runtime = STATE.evolution_runtime or {}

    -- 解析目标模型ID
    local target_model_id = nil
    local target_unit_id = evolution_def.hero_unit_id
    local display_name = evolution_def.name

    -- 通过单位键解析
    if not target_model_id and target_unit_id and y3 and y3.unit and y3.unit.get_model_by_key then
      local ok, id = pcall(y3.unit.get_model_by_key, target_unit_id)
      if ok and id and id ~= 0 then
        target_model_id = id
      end
    end

    -- 通过名册按名称查找
    if not target_model_id and display_name and roster_by_name[display_name] then
      local roster_model = roster_by_name[display_name].model_id
      if roster_model and roster_model ~= 0 then
        target_model_id = roster_model
      end
    end

    if not target_model_id then
      return false
    end

    -- 取消旧形态
    if runtime.active_form_model_id
      and runtime.active_form_model_id ~= target_model_id then
      api.cancel_replace_model(hero, runtime.active_form_model_id)
    end

    local ok = api.replace_model(hero, target_model_id)
    if ok then
      runtime.active_form_unit_id = target_unit_id
      runtime.active_form_model_id = target_model_id
    end
    return ok
  end

  -- 获取当前活跃的模型ID
  function api.get_active_model_id()
    local evo_runtime = STATE.evolution_runtime
    if evo_runtime and evo_runtime.active_form_model_id then
      return evo_runtime.active_form_model_id
    end

    if hero_roster and hero_roster.initial_hero then
      local initial = hero_roster.initial_hero
      if initial.model_id and initial.model_id ~= 0 then
        return initial.model_id
      end
    end

    return DEFAULT_MODEL_ID
  end

  -- 获取用于UI显示的模型ID（走与创建时相同的解析逻辑）
  function api.get_ui_model_id(unit, hero_name, hero_id)
    local model_id = api.resolve_model_id({
      hero_name = hero_name,
      hero_id = hero_id,
      unit = unit,
    })
    if model_id and model_id ~= 0 then
      return model_id
    end
    return DEFAULT_MODEL_ID
  end

  -- 将单位模型绑定到UI控件（仅用 set_ui_model_id，不用 set_ui_model_unit）
  function api.bind_ui_model(ui_control, unit, bind_anim, bind_rotation, bind_scale, hero_name, hero_id)
    if not ui_control or not unit then
      return false
    end

    if type(ui_control.set_ui_model_id) == 'function' then
      local model_id = api.resolve_model_id({
        hero_name = hero_name,
        hero_id = hero_id,
        unit = unit,
      })
      if model_id and model_id ~= 0 then
        local ok = pcall(ui_control.set_ui_model_id, ui_control, model_id)
        print('[hero_model] bind_ui_model: set_ui_model_id model_id=' .. tostring(model_id) .. ' ok=' .. tostring(ok))
        return ok
      end
    end

    return false
  end

  _G.hero_model = api

return M
