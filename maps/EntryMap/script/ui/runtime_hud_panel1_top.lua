local BaseHud = require 'ui.runtime_hud_v2'

local M = {}

local function resolve_ui(y3, player, path)
  local ok, ui = pcall(y3.ui.get_ui, player, path)
  if not ok or not ui then
    return nil
  end
  return ui
end

local function is_alive(ui)
  return ui and (not ui.is_removed or not ui:is_removed())
end

local function set_panel1_top_visible(env, visible)
  local y3 = env.y3
  local player = env.get_player()
  local panel1 = resolve_ui(y3, player, 'panel_1')
  local top_root = resolve_ui(y3, player, 'panel_1.tophud')

  if panel1 then
    panel1:set_visible(visible == true)
  end
  if top_root then
    top_root:set_visible(visible == true)
  end
end

local function make_noop_text()
  return {
    set_text = function() end,
    set_text_color = function() end,
  }
end

local function set_text_rgba(node, color)
  if is_alive(node) and color then
    node:set_text_color(color[1], color[2], color[3], color[4] or 255)
  end
end

local function make_text_proxy(node, transform)
  return {
    set_text = function(_, text)
      if is_alive(node) then
        node:set_text(transform and transform(text) or text or '')
      end
    end,
    set_text_color = function(_, color)
      set_text_rgba(node, color)
    end,
  }
end

local function normalize_ratio(value)
  local number = tonumber(value) or 0
  if math.abs(number) > 1 then
    return number / 100
  end
  return number
end

local function format_wave_time_text(text)
  if not text or text == '' then
    return '--s'
  end
  local seconds = text:match('([%d%.]+)%s*秒后登场')
  if seconds then
    return string.format('%ss', tostring(math.floor(tonumber(seconds) or 0)))
  end
  if text:find('已击败', 1, true) then
    return '已击败'
  end
  if text:find('HP ', 1, true) then
    return 'BOSS'
  end
  return text
end

local function format_tips_text(name, state)
  local boss_name = tostring(name or '')
  local boss_state = tostring(state or '')

  if boss_name == '' and boss_state == '' then
    return '准备迎战'
  end
  if boss_state == '' then
    return boss_name
  end
  if boss_state:find('HP ', 1, true) then
    if boss_name ~= '' then
      return boss_name .. ' 交战中'
    end
    return 'Boss 交战中'
  end
  if boss_state:find('已击败', 1, true) then
    if boss_name ~= '' then
      return boss_name .. ' 已击败'
    end
    return 'Boss 已击败'
  end
  if boss_state:match('([%d%.]+)%s*秒后登场') then
    if boss_name ~= '' then
      return boss_name .. ' 即将登场'
    end
    return 'Boss 即将登场'
  end
  if boss_name ~= '' then
    return boss_name .. ' ' .. boss_state
  end
  return boss_state
end

local function format_game_time_text(text)
  local value = tostring(text or '')
  value = value:gsub('^战斗计时%s*', '')
  if value == '' then
    return '00：00'
  end
  return value:gsub(':', '：')
end

local function flush_panel1_boss(runtime_hud)
  if not runtime_hud then
    return
  end
  if is_alive(runtime_hud.panel1_tips_node) then
    local tips_text = runtime_hud.panel1_tip_overlay_text or format_tips_text(
      runtime_hud.panel1_boss_name_text,
      runtime_hud.panel1_boss_state_text
    )
    runtime_hud.panel1_tips_node:set_text(tips_text)
  end
  if is_alive(runtime_hud.panel1_wavetime_node) then
    runtime_hud.panel1_wavetime_node:set_text(format_wave_time_text(runtime_hud.panel1_boss_state_text))
  end
  set_text_rgba(runtime_hud.panel1_tips_node, runtime_hud.panel1_boss_color)
  set_text_rgba(runtime_hud.panel1_wavetime_node, runtime_hud.panel1_boss_color)
end

local function clear_tip_overlay(runtime_hud)
  if not runtime_hud then
    return
  end
  if runtime_hud.panel1_tip_overlay_timer then
    runtime_hud.panel1_tip_overlay_timer:remove()
    runtime_hud.panel1_tip_overlay_timer = nil
  end
  runtime_hud.panel1_tip_overlay_text = nil
  flush_panel1_boss(runtime_hud)
end

local function make_boss_name_proxy(runtime_hud)
  return {
    set_text = function(_, text)
      runtime_hud.panel1_boss_name_text = tostring(text or '')
      flush_panel1_boss(runtime_hud)
    end,
    set_text_color = function(_, color)
      runtime_hud.panel1_boss_color = color
      flush_panel1_boss(runtime_hud)
    end,
  }
end

local function make_boss_state_proxy(runtime_hud)
  return {
    set_text = function(_, text)
      runtime_hud.panel1_boss_state_text = tostring(text or '')
      flush_panel1_boss(runtime_hud)
    end,
    set_text_color = function(_, color)
      runtime_hud.panel1_boss_color = color
      flush_panel1_boss(runtime_hud)
    end,
  }
end

local function clear_panel1_top_bindings(runtime_hud)
  if not runtime_hud then
    return
  end
  clear_tip_overlay(runtime_hud)
  runtime_hud.panel1_top_bound = false
  runtime_hud.panel1_tips_node = nil
  runtime_hud.panel1_wavetime_node = nil
  runtime_hud.panel1_boss_name_text = nil
  runtime_hud.panel1_boss_state_text = nil
  runtime_hud.panel1_boss_color = nil
  runtime_hud.panel1_tip_overlay_text = nil
  runtime_hud.panel1_tip_overlay_timer = nil
end

local function bind_panel1_top(env, runtime_hud)
  if runtime_hud.top_battle_cluster and not runtime_hud.top_battle_cluster:is_removed() then
    runtime_hud.top_battle_cluster:set_visible(false)
  end
  if runtime_hud.left_shortcut_panel and not runtime_hud.left_shortcut_panel:is_removed() then
    runtime_hud.left_shortcut_panel:set_visible(false)
  end
  if runtime_hud.right_tracker_panel and not runtime_hud.right_tracker_panel:is_removed() then
    runtime_hud.right_tracker_panel:set_visible(false)
  end

  local y3 = env.y3
  local player = env.get_player()
  local wave_node = resolve_ui(y3, player, 'panel_1.tophud.layout_2.wave')
  local wavetime_node = resolve_ui(y3, player, 'panel_1.tophud.layout_2.wavetime')
  local tips_node = resolve_ui(y3, player, 'panel_1.tophud.layout_2.tips')
  local curlevel_node = resolve_ui(y3, player, 'panel_1.tophud.layout_2.curlevel')
  local gametime_node = resolve_ui(y3, player, 'panel_1.tophud.layout_2.gametime')

  if not wave_node or not wavetime_node or not tips_node or not curlevel_node or not gametime_node then
    clear_panel1_top_bindings(runtime_hud)
    set_panel1_top_visible(env, false)
    return false
  end

  set_panel1_top_visible(env, true)
  runtime_hud.panel1_top_bound = true
  runtime_hud.panel1_tips_node = tips_node
  runtime_hud.panel1_wavetime_node = wavetime_node
  runtime_hud.panel1_boss_name_text = runtime_hud.panel1_boss_name_text or ''
  runtime_hud.panel1_boss_state_text = runtime_hud.panel1_boss_state_text or ''
  runtime_hud.panel1_boss_color = runtime_hud.panel1_boss_color or { 255, 255, 255, 255 }

  runtime_hud.stage_text = make_text_proxy(curlevel_node)
  runtime_hud.wave_title = make_text_proxy(wave_node)
  runtime_hud.wave_status = make_noop_text()
  runtime_hud.timer_text = make_text_proxy(gametime_node, format_game_time_text)
  runtime_hud.boss_panel = nil
  runtime_hud.boss_name = make_boss_name_proxy(runtime_hud)
  runtime_hud.boss_state = make_boss_state_proxy(runtime_hud)

  flush_panel1_boss(runtime_hud)
  return true
end

function M.create(env)
  local base = BaseHud.create(env)

  return {
    ensure_hud = function()
      local hud = base.ensure_hud()
      if not hud then
        set_panel1_top_visible(env, false)
        return nil
      end
      bind_panel1_top(env, hud)
      base.refresh_hud()
      return hud
    end,
    refresh_hud = function()
      local hud = env.STATE and env.STATE.runtime_hud
      if hud then
        bind_panel1_top(env, hud)
      end
      local result = base.refresh_hud()
      if hud and hud.panel1_top_bound then
        flush_panel1_boss(hud)
      end
      return result
    end,
    set_visible = function(visible)
      set_panel1_top_visible(env, visible == true)
      return base.set_visible(visible)
    end,
    show_tip_panel = function(text, duration)
      local hud = env.STATE and env.STATE.runtime_hud
      if not hud then
        hud = base.ensure_hud()
        if hud then
          bind_panel1_top(env, hud)
        end
      end
      if hud and hud.panel1_tips_node and is_alive(hud.panel1_tips_node) then
        clear_tip_overlay(hud)
        hud.panel1_tip_overlay_text = text or ''
        flush_panel1_boss(hud)
        if (tonumber(duration) or 0) > 0 then
          hud.panel1_tip_overlay_timer = env.y3.ltimer.wait(duration, function()
            clear_tip_overlay(hud)
          end)
        end
      end
    end,
    clear_tip_panel = function()
      local hud = env.STATE and env.STATE.runtime_hud
      if hud and hud.panel1_top_bound then
        clear_tip_overlay(hud)
      end
    end,
  }
end

return M
