local BaseHud = require 'ui.runtime_hud_v2'
local RuntimeAttrTabPanel = require 'ui.runtime_attr_tab_panel'
local UIStyle = require 'ui.style'

local M = {}

local function resolve_ui(y3, player, path)
  local ok, ui = pcall(y3.ui.get_ui, player, path)
  if not ok or not ui then
    return nil
  end
  return ui
end

local function resolve_first_ui(y3, player, paths)
  for _, path in ipairs(paths or {}) do
    local ui = resolve_ui(y3, player, path)
    if ui then
      return ui
    end
  end
  return nil
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

local function set_image_rgba(node, color)
  if not is_alive(node) or not color then
    return
  end
  if node.set_image_color then
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
    runtime_hud.right_tracker_panel:set_visible(true)
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
    runtime_hud.tracker_shortcut_chip_label:set_text(shortcut_text)
    set_text_rgba(runtime_hud.tracker_shortcut_chip_label, visual_state.chip_text)
  end
  if is_alive(runtime_hud.tracker_shortcut_chip_key) then
    runtime_hud.tracker_shortcut_chip_key:set_text(visual_state.key)
    set_text_rgba(runtime_hud.tracker_shortcut_chip_key, visual_state.chip_text)
  end
  if is_alive(runtime_hud.tracker_shortcut_chip_arrow) then
    runtime_hud.tracker_shortcut_chip_arrow:set_text(visual_state.arrow)
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
  local wave_node = resolve_ui(y3, player, 'panel_1.tophud.layout_2.wave')
  local wavetime_node = resolve_ui(y3, player, 'panel_1.tophud.layout_2.wavetime')
  local tips_node = resolve_ui(y3, player, 'panel_1.tophud.layout_2.tips')
  local curlevel_node = resolve_ui(y3, player, 'panel_1.tophud.layout_2.curlevel')
  local gametime_node = resolve_ui(y3, player, 'panel_1.tophud.layout_2.gametime')

  if not wave_node or not wavetime_node or not tips_node or not curlevel_node or not gametime_node then
    clear_panel1_top_bindings(runtime_hud)
    set_panel1_top_visible(env, false)
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

  runtime_hud.stage_text = make_text_proxy(curlevel_node)
  runtime_hud.wave_title = make_text_proxy(wave_node)
  runtime_hud.wave_status = make_noop_text()
  runtime_hud.timer_text = make_text_proxy(gametime_node, format_game_time_text)
  runtime_hud.boss_panel = nil
  runtime_hud.boss_name = make_boss_name_proxy(runtime_hud)
  runtime_hud.boss_state = make_boss_state_proxy(runtime_hud)

  flush_panel1_boss(runtime_hud)
  refresh_tracker_panel(env, runtime_hud)
  return true
end

function M.create(env)
  local base = BaseHud.create(env)
  local attr_tab_panel = RuntimeAttrTabPanel.create({
    STATE = env.STATE,
    y3 = env.y3,
    get_player = env.get_player,
    get_runtime_overview_model = env.get_runtime_overview_model,
  })

  return {
    ensure_hud = function()
      local hud = base.ensure_hud()
      if not hud then
        set_panel1_top_visible(env, false)
        return nil
      end
      bind_panel1_top(env, hud)
      base.refresh_hud()
      if attr_tab_panel and attr_tab_panel.ensure_panel then
        attr_tab_panel.ensure_panel()
      end
      return hud
    end,
    refresh_hud = function()
      local hud = env.STATE and env.STATE.runtime_hud
      if hud then
        bind_panel1_top(env, hud)
      end
      local result = base.refresh_hud()
      if hud then
        flush_panel1_boss(hud)
        refresh_tracker_panel(env, hud)
      end
      if attr_tab_panel and attr_tab_panel.refresh_panel then
        attr_tab_panel.refresh_panel()
      end
      return result
    end,
    set_visible = function(visible)
      local hud = env.STATE and env.STATE.runtime_hud
      if hud and hud.right_tracker_panel and is_alive(hud.right_tracker_panel) then
        hud.right_tracker_panel:set_visible(visible == true)
      end
      set_panel1_top_visible(env, visible == true)
      if visible ~= true and attr_tab_panel and attr_tab_panel.hide_panel then
        attr_tab_panel.hide_panel()
      end
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
    hide_attr_panel = function()
      return attr_tab_panel and attr_tab_panel.hide_panel and attr_tab_panel.hide_panel() or nil
    end,
    refresh_attr_panel = function()
      return attr_tab_panel and attr_tab_panel.refresh_panel and attr_tab_panel.refresh_panel() or nil
    end,
    show_attr_panel = function(tab_key)
      return attr_tab_panel and attr_tab_panel.show_tab and attr_tab_panel.show_tab(tab_key) or nil
    end,
    toggle_attr_panel = function(force_visible)
      return attr_tab_panel and attr_tab_panel.toggle_panel and attr_tab_panel.toggle_panel(force_visible) or nil
    end,
  }
end

return M
