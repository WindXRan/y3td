local BaseHud = require 'ui.runtime_hud_v2'
local UIStyle = require 'ui.style'
local UIRoot = require 'ui.ui_root'
local RuntimeHudSchema = require 'ui.runtime_hud_editor_schema'

local M = {}
local TRACKER_REFRESH_INTERVAL = 0.75
local UI_TEXT_CACHE = setmetatable({}, { __mode = 'k' })
local UI_TEXT_COLOR_CACHE = setmetatable({}, { __mode = 'k' })
local UI_IMAGE_COLOR_CACHE = setmetatable({}, { __mode = 'k' })
local UI_VISIBLE_CACHE = setmetatable({}, { __mode = 'k' })

local function resolve_ui(y3, player, path)
  return UIRoot.resolve_ui(y3, player, path)
end

local function resolve_first_ui(y3, player, paths)
  return UIRoot.resolve_first_ui(y3, player, paths)
end

local function is_alive(ui)
  return UIRoot.is_alive(ui)
end

local function set_visible_if_changed(node, visible)
  if not is_alive(node) then
    return
  end
  local final_visible = visible == true
  if UI_VISIBLE_CACHE[node] == final_visible then
    return
  end
  UI_VISIBLE_CACHE[node] = final_visible
  node:set_visible(final_visible)
end

local function set_text_if_changed(node, text)
  if not is_alive(node) then
    return
  end
  local final_text = tostring(text or '')
  if UI_TEXT_CACHE[node] == final_text then
    return
  end
  UI_TEXT_CACHE[node] = final_text
  node:set_text(final_text)
end

local function set_panel1_top_visible(env, visible)
  local y3 = env.y3
  local player = env.get_player()
  local panel1 = resolve_first_ui(y3, player, {
    'panel_1',
    'top',
  })
  local top_root = resolve_first_ui(y3, player, {
    'panel_1.tophud',
    RuntimeHudSchema.top.root_paths[1],
    RuntimeHudSchema.top.root_paths[2],
  })

  if panel1 then
    set_visible_if_changed(panel1, visible == true)
  end
  if top_root then
    set_visible_if_changed(top_root, visible == true)
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
    local color_key = string.format('%s,%s,%s,%s', color[1], color[2], color[3], color[4] or 255)
    if UI_TEXT_COLOR_CACHE[node] == color_key then
      return
    end
    UI_TEXT_COLOR_CACHE[node] = color_key
    node:set_text_color(color[1], color[2], color[3], color[4] or 255)
  end
end

local function set_image_rgba(node, color)
  if not is_alive(node) or not color then
    return
  end
  if node.set_image_color then
    local color_key = string.format('%s,%s,%s,%s', color[1], color[2], color[3], color[4] or 255)
    if UI_IMAGE_COLOR_CACHE[node] == color_key then
      return
    end
    UI_IMAGE_COLOR_CACHE[node] = color_key
    node:set_image_color(color[1], color[2], color[3], color[4] or 255)
  end
end

local function set_checkbox_selected(node, selected)
  if not is_alive(node) or not GameAPI or not GameAPI.set_checkbox_selected then
    return
  end
  GameAPI.set_checkbox_selected(node.player.handle, node.handle, selected == true)
end

local function make_text_proxy(node, transform)
  return {
    set_text = function(_, text)
      if is_alive(node) then
        set_text_if_changed(node, transform and transform(text) or text or '')
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
    set_text_if_changed(runtime_hud.panel1_tips_node, tips_text)
  end
  if is_alive(runtime_hud.panel1_wavetime_node) then
    set_text_if_changed(runtime_hud.panel1_wavetime_node, format_wave_time_text(runtime_hud.panel1_boss_state_text))
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

local function has_panel1_top_runtime(env)
  local y3 = env.y3
  local player = env.get_player()
  return resolve_first_ui(y3, player, {
    'top.top.layout_2',
    'top.top',
    'top',
    'panel_1.tophud.layout_2',
    'panel_1.tophud',
  }) ~= nil
end

local function resolve_tracker_nodes(env, runtime_hud)
  local y3 = env.y3
  local player = env.get_player()
  runtime_hud.right_tracker_panel = resolve_first_ui(y3, player, {
    'MainlineTaskPanel',
    'MainlineTaskPanel.爬塔挑战',
  })
  runtime_hud.tracker_shortcut_chip_bg = resolve_ui(y3, player, 'MainlineTaskPanel.tracker_shortcut_chip_bg')
  runtime_hud.tracker_shortcut_chip_label = resolve_first_ui(y3, player, {
    'MainlineTaskPanel.tracker_shortcut_chip_label',
    'MainlineTaskPanel.爬塔挑战.layout.scroll_view_1.快捷键C',
  })
  runtime_hud.tracker_shortcut_chip_key = resolve_ui(y3, player, 'MainlineTaskPanel.tracker_shortcut_chip_key')
  runtime_hud.tracker_shortcut_chip_arrow = resolve_ui(y3, player, 'MainlineTaskPanel.tracker_shortcut_chip_arrow')
  runtime_hud.tracker_card_border = resolve_first_ui(y3, player, {
    'MainlineTaskPanel.tracker_card_border',
    'MainlineTaskPanel.爬塔挑战.layout.image',
  })
  runtime_hud.tracker_title = resolve_first_ui(y3, player, {
    'MainlineTaskPanel.tracker_title',
    'MainlineTaskPanel.爬塔挑战.layout.scroll_view_1.第X层',
  })
  runtime_hud.tracker_objective = resolve_first_ui(y3, player, {
    'MainlineTaskPanel.tracker_objective',
    'MainlineTaskPanel.爬塔挑战.layout.scroll_view_1.目标',
  })
  runtime_hud.tracker_progress = resolve_first_ui(y3, player, {
    'MainlineTaskPanel.tracker_progress',
    'MainlineTaskPanel.爬塔挑战.layout.scroll_view_1.具体目标',
  })
  runtime_hud.tracker_reward_label = resolve_first_ui(y3, player, {
    'MainlineTaskPanel.tracker_reward_label',
    'MainlineTaskPanel.爬塔挑战.layout.scroll_view_1.奖励',
  })
  runtime_hud.tracker_reward = resolve_first_ui(y3, player, {
    'MainlineTaskPanel.tracker_reward',
    'MainlineTaskPanel.爬塔挑战.layout.scroll_view_1.具体奖励',
  })
  runtime_hud.tracker_hint = resolve_ui(y3, player, 'MainlineTaskPanel.tracker_hint')
  runtime_hud.auto_task_checkbox = resolve_first_ui(y3, player, {
    'MainlineTaskPanel.auto_task_checkbox',
    'MainlineTaskPanel.爬塔挑战.layout.scroll_view_1.layout_14.check_box',
  })
  runtime_hud.auto_task_label = resolve_first_ui(y3, player, {
    'MainlineTaskPanel.auto_task_label',
    'MainlineTaskPanel.爬塔挑战.layout.scroll_view_1.layout_14.自动挑战',
  })
end

local function get_task_panel_summary(env)
  local tracker_state = env.battle_objective_runtime and env.battle_objective_runtime.get_tracker_state and env.battle_objective_runtime.get_tracker_state() or nil
  if tracker_state and tracker_state.auto_track_enabled == false and tracker_state.snapshot_summary then
    return tracker_state.snapshot_summary, tracker_state
  end
  local summary = env.battle_objective_runtime and env.battle_objective_runtime.get_summary and env.battle_objective_runtime.get_summary() or nil
  return summary, tracker_state
end

local function build_reward_text(summary)
  if not summary or not summary.reward_line_texts or #summary.reward_line_texts == 0 then
    return '暂无'
  end
  return table.concat(summary.reward_line_texts, '\n')
end

local function build_tracker_hint(summary, tracker_state)
  if tracker_state and tracker_state.auto_track_enabled == false then
    return '目标追踪已关闭，面板停留在最近一次层数挑战'
  end
  if summary and summary.state_text and summary.timer_text and summary.timer_text ~= '' then
    return tostring(summary.state_text) .. ' · ' .. tostring(summary.timer_text)
  end
  if summary and summary.state_text then
    return tostring(summary.state_text)
  end
  return '正在同步当前层挑战数据'
end

local function get_tracker_visual_state(summary)
  if not summary then
    return {
      border = { 92, 120, 154, 180 },
      chip = { 58, 88, 116, 220 },
      chip_text = { 220, 232, 246, 255 },
      label = '同步中',
      key = '',
      arrow = '',
    }
  end
  if summary.is_running then
    return {
      border = { 71, 182, 255, 220 },
      chip = { 36, 112, 168, 228 },
      chip_text = { 242, 247, 255, 255 },
      label = '挑战中',
      key = 'C',
      arrow = '>',
    }
  end
  if summary.can_start then
    return {
      border = { 83, 201, 124, 220 },
      chip = { 48, 132, 84, 228 },
      chip_text = { 242, 250, 244, 255 },
      label = '开启挑战',
      key = 'C',
      arrow = '>',
    }
  end
  if summary.is_completed then
    return {
      border = { 255, 212, 73, 220 },
      chip = { 158, 118, 34, 228 },
      chip_text = { 255, 246, 214, 255 },
      label = '已完成',
      key = '',
      arrow = '',
    }
  end
  return {
    border = { 92, 120, 154, 180 },
    chip = { 58, 88, 116, 220 },
    chip_text = { 220, 232, 246, 255 },
    label = '爬塔挑战',
    key = 'C',
    arrow = '>',
  }
end

local function refresh_tracker_panel(env, runtime_hud)
  resolve_tracker_nodes(env, runtime_hud)
  if runtime_hud.right_tracker_panel and not runtime_hud.right_tracker_panel:is_removed() then
    set_visible_if_changed(runtime_hud.right_tracker_panel, true)
  end

  local summary, tracker_state = get_task_panel_summary(env)
  local auto_track_enabled = not tracker_state or tracker_state.auto_track_enabled ~= false
  local visual_state = get_tracker_visual_state(summary)

  if is_alive(runtime_hud.tracker_card_border) then
    set_image_rgba(runtime_hud.tracker_card_border, visual_state.border)
  end
  if is_alive(runtime_hud.tracker_shortcut_chip_bg) then
    set_image_rgba(runtime_hud.tracker_shortcut_chip_bg, visual_state.chip)
  end
  if is_alive(runtime_hud.tracker_shortcut_chip_label) then
    local shortcut_text = visual_state.label
    if not is_alive(runtime_hud.tracker_shortcut_chip_key) and visual_state.key and visual_state.key ~= '' then
      shortcut_text = string.format('%s  快捷键%s', visual_state.label, visual_state.key)
    end
    set_text_if_changed(runtime_hud.tracker_shortcut_chip_label, shortcut_text)
    set_text_rgba(runtime_hud.tracker_shortcut_chip_label, visual_state.chip_text)
  end
  if is_alive(runtime_hud.tracker_shortcut_chip_key) then
    set_text_if_changed(runtime_hud.tracker_shortcut_chip_key, visual_state.key)
    set_text_rgba(runtime_hud.tracker_shortcut_chip_key, visual_state.chip_text)
  end
  if is_alive(runtime_hud.tracker_shortcut_chip_arrow) then
    set_text_if_changed(runtime_hud.tracker_shortcut_chip_arrow, visual_state.arrow)
    set_text_rgba(runtime_hud.tracker_shortcut_chip_arrow, visual_state.chip_text)
  end

  if is_alive(runtime_hud.tracker_title) then
    UIStyle.apply_text(runtime_hud.tracker_title, 'runtime_hud.panel1.tracker_title', summary and summary.title_text or '爬塔挑战同步中')
    set_text_rgba(runtime_hud.tracker_title, { 244, 247, 255, 255 })
  end
  if is_alive(runtime_hud.tracker_objective) then
    UIStyle.apply_text(runtime_hud.tracker_objective, 'runtime_hud.panel1.tracker_objective', summary and ('目标：' .. tostring(summary.objective_text or '')) or '目标：等待任务数据')
    set_text_rgba(runtime_hud.tracker_objective, { 143, 239, 76, 255 })
  end
  if is_alive(runtime_hud.tracker_progress) then
    UIStyle.apply_text(runtime_hud.tracker_progress, 'runtime_hud.panel1.tracker_progress', summary and summary.progress_text or '当前无层数挑战')
    set_text_rgba(runtime_hud.tracker_progress, { 224, 232, 240, 255 })
  end
  if is_alive(runtime_hud.tracker_reward_label) then
    UIStyle.apply_text(runtime_hud.tracker_reward_label, 'runtime_hud.panel1.tracker_reward_label', '奖励：')
    set_text_rgba(runtime_hud.tracker_reward_label, { 255, 212, 73, 255 })
  end
  if is_alive(runtime_hud.tracker_reward) then
    UIStyle.apply_text(runtime_hud.tracker_reward, 'runtime_hud.panel1.tracker_reward', summary and build_reward_text(summary) or '等待任务奖励数据')
    set_text_rgba(runtime_hud.tracker_reward, { 143, 226, 91, 255 })
  end
  if is_alive(runtime_hud.tracker_hint) then
    UIStyle.apply_text(runtime_hud.tracker_hint, 'runtime_hud.panel1.tracker_hint', build_tracker_hint(summary, tracker_state))
    set_text_rgba(runtime_hud.tracker_hint, { 159, 175, 198, 220 })
  end
  if is_alive(runtime_hud.auto_task_label) then
    UIStyle.apply_text(runtime_hud.auto_task_label, 'runtime_hud.panel1.auto_task_label', '自动挑战')
    set_text_rgba(runtime_hud.auto_task_label, { 241, 243, 240, 255 })
  end
  if is_alive(runtime_hud.auto_task_checkbox) then
    set_checkbox_selected(runtime_hud.auto_task_checkbox, auto_track_enabled)
    if not runtime_hud.auto_task_checkbox_bound then
      runtime_hud.auto_task_checkbox_bound = true
      runtime_hud.auto_task_checkbox:add_fast_event('左键-点击', function()
        if env.battle_objective_runtime and env.battle_objective_runtime.toggle_auto_track then
          env.battle_objective_runtime.toggle_auto_track()
          refresh_tracker_panel(env, runtime_hud)
        end
      end)
    end
  end
end

local function bind_panel1_top(env, runtime_hud)
  if runtime_hud.top_battle_cluster and not runtime_hud.top_battle_cluster:is_removed() then
    runtime_hud.top_battle_cluster:set_visible(false)
  end
  if runtime_hud.left_shortcut_panel and not runtime_hud.left_shortcut_panel:is_removed() then
    runtime_hud.left_shortcut_panel:set_visible(false)
  end

  local y3 = env.y3
  local player = env.get_player()
  local wave_node = resolve_first_ui(y3, player, {
    'panel_1.tophud.layout_2.wave',
    'top.top.layout_2.第X波',
  })
  local wavetime_node = resolve_first_ui(y3, player, {
    'panel_1.tophud.layout_2.wavetime',
    'top.top.layout_2.bg.BOSS倒计时',
  })
  local tips_node = resolve_first_ui(y3, player, {
    'panel_1.tophud.layout_2.tips',
    'top.top.layout_2.bg.boss',
  })
  local curlevel_node = resolve_first_ui(y3, player, {
    'panel_1.tophud.layout_2.curlevel',
    'top.top.layout_2.bg.关卡',
  })
  local gametime_node = resolve_first_ui(y3, player, {
    'panel_1.tophud.layout_2.gametime',
    'top.top.layout_2.bg.游戏时长',
  })

  if not wave_node and not wavetime_node and not tips_node and not curlevel_node and not gametime_node then
    clear_panel1_top_bindings(runtime_hud)
    set_panel1_top_visible(env, has_panel1_top_runtime(env))
    refresh_tracker_panel(env, runtime_hud)
    return false
  end

  set_panel1_top_visible(env, true)
  runtime_hud.panel1_top_bound = true
  runtime_hud.panel1_tips_node = tips_node
  runtime_hud.panel1_wavetime_node = wavetime_node
  runtime_hud.panel1_boss_name_text = runtime_hud.panel1_boss_name_text or ''
  runtime_hud.panel1_boss_state_text = runtime_hud.panel1_boss_state_text or ''
  runtime_hud.panel1_boss_color = runtime_hud.panel1_boss_color or { 255, 255, 255, 255 }

  runtime_hud.stage_text = curlevel_node and make_text_proxy(curlevel_node) or make_noop_text()
  runtime_hud.wave_title = wave_node and make_text_proxy(wave_node) or make_noop_text()
  runtime_hud.wave_status = make_noop_text()
  runtime_hud.timer_text = gametime_node and make_text_proxy(gametime_node, format_game_time_text) or make_noop_text()
  runtime_hud.boss_panel = nil
  runtime_hud.boss_name = make_boss_name_proxy(runtime_hud)
  runtime_hud.boss_state = make_boss_state_proxy(runtime_hud)

  flush_panel1_boss(runtime_hud)
  refresh_tracker_panel(env, runtime_hud)
  runtime_hud.panel1_tracker_refresh_at = env.STATE and env.STATE.runtime_elapsed or 0
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
        if hud.panel1_top_bound ~= true
          or not is_alive(hud.panel1_tips_node)
          or not is_alive(hud.panel1_wavetime_node)
        then
          bind_panel1_top(env, hud)
        end
      end
      local result = base.refresh_hud()
      if hud then
        flush_panel1_boss(hud)
        local now_elapsed = env.STATE and env.STATE.runtime_elapsed or 0
        local last_refresh = tonumber(hud.panel1_tracker_refresh_at) or -TRACKER_REFRESH_INTERVAL
        if (now_elapsed - last_refresh) >= TRACKER_REFRESH_INTERVAL then
          hud.panel1_tracker_refresh_at = now_elapsed
          refresh_tracker_panel(env, hud)
        end
      end
      return result
    end,
    set_visible = function(visible)
      local hud = env.STATE and env.STATE.runtime_hud
      if hud and hud.right_tracker_panel and is_alive(hud.right_tracker_panel) then
        set_visible_if_changed(hud.right_tracker_panel, visible == true)
      end
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
