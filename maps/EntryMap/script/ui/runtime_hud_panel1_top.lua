local BaseHud = require 'ui.runtime_hud_v2'

local M = {}

local EVENT_FEED_COLORS = {
  neutral = { 228, 236, 246, 255 },
  positive = { 176, 232, 188, 255 },
  reward = { 255, 220, 142, 255 },
  warning = { 255, 172, 118, 255 },
  rare = { 222, 198, 255, 255 },
}

local EVENT_FEED_LAYOUT = {
  max_visible = 4,
  width = 520,
  font_size = 18,
  line_height = 22,
  line_gap = 4,
  padding_x = 10,
  left = 26,
  bottom = 158,
}

local function resolve_ui(y3, player, path)
  local ok, ui = pcall(y3.ui.get_ui, player, path)
  if not ok or not ui then
    return nil
  end
  return ui
end

local function hide_panel1_root(env)
  local y3 = env.y3
  local player = env.get_player()
  local panel1 = resolve_ui(y3, player, 'panel_1')
  if panel1 then
    panel1:set_visible(false)
  end
  local top_root = resolve_ui(y3, player, 'panel_1.tophud')
  if top_root then
    top_root:set_visible(false)
  end
end

local function is_alive(ui)
  return ui and (not ui.is_removed or not ui:is_removed())
end

local function make_noop_text()
  return {
    set_text = function() end,
    set_text_color = function() end,
  }
end

local function make_text_proxy(node, transform)
  return {
    set_text = function(_, text)
      if node and not node:is_removed() then
        node:set_text(transform and transform(text) or text)
      end
    end,
    set_text_color = function() end,
  }
end

local function make_value_proxy(node, getter)
  return {
    set_text = function() end,
    set_text_color = function() end,
    sync = function()
      if is_alive(node) then
        node:set_text(tostring(getter() or ''))
      end
    end,
  }
end

local function set_text_rgba(node, color)
  if is_alive(node) then
    node:set_text_color(color[1], color[2], color[3], color[4] or 255)
  end
end

local function normalize_ratio(value)
  local number = tonumber(value) or 0
  if math.abs(number) > 1 then
    return number / 100
  end
  return number
end

local function format_compact_number(value)
  local number = tonumber(value) or 0
  local abs_number = math.abs(number)
  if abs_number >= 1000000 then
    local text = string.format('%.1fm', number / 1000000)
    return text:gsub('%.0m$', 'm')
  end
  if abs_number >= 10000 then
    local text = string.format('%.1fk', number / 1000)
    return text:gsub('%.0k$', 'k')
  end
  if math.abs(number - math.floor(number)) < 0.001 then
    return tostring(math.floor(number))
  end
  return string.format('%.1f', number)
end

local function format_percent_text(value)
  local ratio = normalize_ratio(value)
  if math.abs(ratio) < 0.0001 then
    return ''
  end
  return string.format('%+.0f', ratio * 100)
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

local function bind_panel1_top(env, runtime_hud)
  hide_panel1_root(env)
  if runtime_hud then
    runtime_hud.panel1_top_bound = false
    runtime_hud.panel1_event_feed = nil
    runtime_hud.panel1_resource_sync = nil
    runtime_hud.panel1_flush_tips = nil
    runtime_hud.panel1_flush_battle_event_feed = nil
    runtime_hud.panel1_set_tip_overlay = nil
    runtime_hud.panel1_clear_tip_overlay = nil
  end
  return false
end

function M.create(env)
  local base = BaseHud.create(env)

  return {
    ensure_hud = function()
      hide_panel1_root(env)
      local hud = base.ensure_hud()
      if not hud then
        return nil
      end
      if bind_panel1_top(env, hud) then
        base.refresh_hud()
      end
      return hud
    end,
    refresh_hud = function()
      local hud = env.STATE and env.STATE.runtime_hud
      hide_panel1_root(env)
      if hud then
        bind_panel1_top(env, hud)
      end
      local result = base.refresh_hud()
      if hud and hud.gold_value and hud.gold_value.sync then
        hud.gold_value:sync()
      end
      if hud and hud.wood_value and hud.wood_value.sync then
        hud.wood_value:sync()
      end
      if hud and hud.skill_value and hud.skill_value.sync then
        hud.skill_value:sync()
      end
      if hud and hud.panel1_resource_sync then
        hud.panel1_resource_sync(false)
      end
      if hud and hud.panel1_flush_battle_event_feed then
        hud.panel1_flush_battle_event_feed()
      end
      return result
    end,
    set_visible = function(visible)
      hide_panel1_root(env)
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
      if hud and hud.panel1_set_tip_overlay then
        hud.panel1_set_tip_overlay(text, duration)
      end
    end,
    clear_tip_panel = function()
      local hud = env.STATE and env.STATE.runtime_hud
      if hud and hud.panel1_clear_tip_overlay then
        hud.panel1_clear_tip_overlay()
      end
    end,
  }
end

return M
