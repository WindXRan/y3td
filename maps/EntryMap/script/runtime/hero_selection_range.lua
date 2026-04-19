local M = {}

local RANGE_EFFECT_ID = 101492
local RANGE_EFFECT_HEIGHT = 6
local RANGE_EFFECT_UPDATE_INTERVAL = 0.10
local RANGE_EFFECT_SCALE_BASE = 150
local RANGE_EFFECT_MIN_SCALE = 0.8

function M.create(env)
  local STATE = env.STATE
  local y3 = env.y3
  local is_battle_active = env.is_battle_active or function()
    return false
  end
  local get_current_basic_attack_range = env.get_current_basic_attack_range or function()
    return 0
  end

  local events_registered = false
  local preview_particle = nil
  local preview_timer = nil

  local function remove_preview_particle()
    if not preview_particle then
      return
    end
    pcall(function()
      preview_particle:remove()
    end)
    preview_particle = nil
  end

  local function stop_preview_timer()
    if not preview_timer then
      return
    end
    pcall(function()
      preview_timer:remove()
    end)
    preview_timer = nil
  end

  local function disable_builtin_preview()
    if not y3
      or not y3.player
      or not y3.player.with_local
      or not y3.ability
      or not y3.ability.set_normal_attack_preview_state
    then
      return false
    end

    local ok = pcall(function()
      y3.player.with_local(function(local_player)
        y3.ability.set_normal_attack_preview_state(local_player, false)
      end)
    end)
    return ok
  end

  local function clear_preview()
    stop_preview_timer()
    remove_preview_particle()
    disable_builtin_preview()
  end

  local function should_show_preview(selected_unit)
    return is_battle_active()
      and STATE.hero
      and STATE.hero.is_exist
      and STATE.hero:is_exist()
      and selected_unit ~= nil
      and selected_unit == STATE.hero
  end

  local function get_preview_scale(range)
    local numeric = y3.helper.tonumber(range) or 0
    if numeric <= 0 then
      numeric = 1
    end
    return math.max(RANGE_EFFECT_MIN_SCALE, numeric / RANGE_EFFECT_SCALE_BASE)
  end

  local function clone_unit_point(unit)
    if not unit or not unit.get_point then
      return nil
    end
    local point = unit:get_point()
    if not point or not point.move then
      return nil
    end
    return point:move()
  end

  local function update_preview_particle(unit)
    local point = clone_unit_point(unit)
    if not point then
      return false
    end

    local scale = get_preview_scale(get_current_basic_attack_range())
    if not preview_particle then
      local ok, particle = pcall(y3.particle.create, {
        type = RANGE_EFFECT_ID,
        target = point,
        scale = scale,
        time = -1,
        height = RANGE_EFFECT_HEIGHT,
      })
      if not ok or not particle then
        return false
      end
      preview_particle = particle
      return true
    end

    pcall(function()
      preview_particle:set_point(point)
    end)
    pcall(function()
      preview_particle:set_scale(scale, scale, scale)
    end)
    pcall(function()
      preview_particle:set_height(RANGE_EFFECT_HEIGHT)
    end)
    return true
  end

  local function get_current_local_selected_unit()
    if not y3 or not y3.player or not y3.player.with_local then
      return nil
    end

    local selected_unit = nil
    pcall(function()
      y3.player.with_local(function(local_player)
        selected_unit = local_player.get_local_selecting_unit and local_player:get_local_selecting_unit() or nil
      end)
    end)
    return selected_unit
  end

  local function refresh_local_preview(selected_unit)
    if not should_show_preview(selected_unit) then
      clear_preview()
      return false
    end

    update_preview_particle(selected_unit)

    if preview_timer then
      return true
    end

    preview_timer = y3.ltimer.loop(RANGE_EFFECT_UPDATE_INTERVAL, function(timer)
      local current_selected_unit = get_current_local_selected_unit()
      if not should_show_preview(current_selected_unit) then
        timer:remove()
        preview_timer = nil
        remove_preview_particle()
        disable_builtin_preview()
        return
      end
      update_preview_particle(current_selected_unit)
    end)
    return true
  end

  local function register_runtime_events()
    if events_registered then
      return
    end
    events_registered = true

    -- 进入对局时英雄会被脚本自动选中，先关闭引擎自带的普攻预览，
    -- 避免在未点击英雄时看到物编里的小范围圈。
    disable_builtin_preview()

    y3.game:event('本地-鼠标-按下单位', y3.const.MouseKey.LEFT, function(_, data)
      if data.unit == STATE.hero then
        refresh_local_preview(data.unit)
      end
    end)

    y3.game:event('本地-选中-单位', function(_, data)
      if data.unit ~= STATE.hero then
        clear_preview()
      end
    end)

    y3.game:event('本地-选中-单位组', function(_, data)
      local selected_unit = data.player and data.player.get_local_selecting_unit and data.player:get_local_selecting_unit() or nil
      if selected_unit ~= STATE.hero then
        clear_preview()
      end
    end)

    y3.game:event('本地-选中-取消', function()
      clear_preview()
    end)
  end

  return {
    register_runtime_events = register_runtime_events,
    refresh_local_preview = refresh_local_preview,
    disable_local_preview = clear_preview,
  }
end

return M
