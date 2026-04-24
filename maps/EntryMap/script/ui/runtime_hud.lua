local UIRoot = require 'ui.ui_root'

local M = {}

local NOTICE_DURATION = 8
local BOND_SLOT_COUNT = 8

local function is_ui_alive(ui)
  return UIRoot.is_alive(ui)
end

function M.create(env)
  local STATE = env.STATE
  local CONFIG = env.CONFIG or {}
  local y3 = env.y3
  local get_player = env.get_player
  local hero_attr_system = env.hero_attr_system
  local message = env.message or function() end
  local show_upgrade_choices = env.show_upgrade_choices
  local try_bond_draw = env.try_bond_draw
  local show_bond_progress = env.show_bond_progress
  local try_evolution_entry = env.try_evolution_entry
  local try_treasure_entry = env.try_treasure_entry
  local try_start_challenge = env.try_start_challenge
  local open_save_panel = env.open_save_panel
  local try_upgrade_growth_weapon = env.try_upgrade_growth_weapon
  local show_runtime_status = env.show_runtime_status
  local build_runtime_attr_dialog_chunks = env.build_runtime_attr_dialog_chunks
  local build_growth_weapon_tip_payload = env.build_growth_weapon_tip_payload
  local get_bond_slot_icon = env.get_bond_slot_icon
  local play_ui_click = env.play_ui_click
  local ensure_hud
  local refresh_hud

  local function get_player_safe()
    return get_player and get_player() or nil
  end

  local function ensure_preferences()
    STATE.ui_preferences = STATE.ui_preferences or {}
    local prefs = STATE.ui_preferences
    if prefs.hide_damage_text == nil then
      prefs.hide_damage_text = false
    end
    if prefs.hide_hit_effects == nil then
      prefs.hide_hit_effects = false
    end
    if prefs.big_cursor == nil then
      prefs.big_cursor = false
    end
    if prefs.soft_paused == nil then
      prefs.soft_paused = false
    end
    return prefs
  end

  local function get_runtime()
    STATE.runtime_hud = STATE.runtime_hud or {
      nodes = {},
      bound_events = {},
      visible = true,
      attr_panel_visible = false,
      tip_title_text = '',
      tip_body_text = '',
      tip_panel = nil,
      tip_panel_title = nil,
      tip_panel_body = nil,
      tip_expires_at = 0,
      attr_panel = nil,
      attr_panel_title = nil,
      attr_panel_body = nil,
      attr_panel_hint = nil,
      big_cursor = nil,
    }
    return STATE.runtime_hud
  end

  local function resolve_ui(path)
    local runtime = get_runtime()
    local cached = runtime.nodes[path]
    if is_ui_alive(cached) then
      return cached
    end
    local player = get_player_safe()
    if not player then
      return nil
    end
    local ui = UIRoot.resolve_ui(y3, player, path)
    runtime.nodes[path] = ui
    return ui
  end

  local function call_ui(ui, method_name, ...)
    if not is_ui_alive(ui) then
      return false
    end
    local method = ui[method_name]
    if type(method) ~= 'function' then
      return false
    end
    return pcall(method, ui, ...)
  end

  local function set_visible_if_alive(ui, visible)
    call_ui(ui, 'set_visible', visible == true)
  end

  local function set_text_if_alive(ui, text)
    call_ui(ui, 'set_text', text or '')
  end

  local function set_text_color_if_alive(ui, color)
    if color then
      call_ui(ui, 'set_text_color', color[1], color[2], color[3], color[4] or 255)
    end
  end

  local function set_image_if_alive(ui, image)
    if image ~= nil then
      call_ui(ui, 'set_image', image)
    end
  end

  local function set_image_color_if_alive(ui, color)
    if color then
      call_ui(ui, 'set_image_color', color[1], color[2], color[3], color[4] or 255)
    end
  end

  local function set_progress_if_alive(ui, current, max_value)
    if not is_ui_alive(ui) then
      return
    end
    local final_max = math.max(1, math.floor((tonumber(max_value) or 1) + 0.5))
    local final_current = math.max(0, math.min(final_max, math.floor((tonumber(current) or 0) + 0.5)))
    call_ui(ui, 'set_max_progress_bar_value', final_max)
    call_ui(ui, 'set_current_progress_bar_value', final_current, 0)
  end

  local function set_percent_pos_if_alive(ui, x, y)
    local player = get_player_safe()
    if not player or not is_ui_alive(ui) or not GameAPI or not GameAPI.set_ui_comp_pos_percent then
      return
    end
    pcall(GameAPI.set_ui_comp_pos_percent, player.handle, ui.handle, x, y)
  end

  local function compact_number(value)
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
    return tostring(math.floor(number + 0.5))
  end

  local function format_time(seconds)
    local total = math.max(0, math.floor((tonumber(seconds) or 0) + 0.5))
    local minute = total // 60
    local second = total % 60
    return string.format('%02d:%02d', minute, second)
  end

  local function percent_number(value)
    local number = tonumber(value) or 0
    if math.abs(number) <= 1 then
      number = number * 100
    end
    return number
  end

  local function format_percent(value)
    return string.format('%d%%', math.floor(percent_number(value) + 0.5))
  end

  local function format_signed_percent_pair(value_a, value_b)
    local total = percent_number(value_a) + percent_number(value_b)
    return string.format('%+d%%', math.floor(total + (total >= 0 and 0.5 or -0.5)))
  end

  local function count_entries(source)
    if type(source) ~= 'table' then
      return 0
    end
    local count = 0
    for _ in pairs(source) do
      count = count + 1
    end
    return count
  end

  local function get_attr(name, fallback_name)
    if not STATE.hero or not STATE.hero.is_exist or not STATE.hero:is_exist() then
      return 0
    end
    local value = hero_attr_system and hero_attr_system.get_attr(STATE.hero, name) or STATE.hero:get_attr(name)
    value = tonumber(value) or 0
    if value ~= 0 or not fallback_name then
      return value
    end
    local fallback = hero_attr_system and hero_attr_system.get_attr(STATE.hero, fallback_name) or STATE.hero:get_attr(fallback_name)
    return tonumber(fallback) or 0
  end

  local function get_hero_level()
    return math.max(1, math.floor(tonumber(STATE.hero_progress and STATE.hero_progress.level) or 1))
  end

  local function get_hero_name()
    if STATE.hero and STATE.hero.get_name and STATE.hero:is_exist() then
      local name = STATE.hero:get_name()
      if name and name ~= '' then
        return name
      end
    end
    return '英雄'
  end

  local function get_hero_icon()
    if STATE.hero and STATE.hero.get_icon and STATE.hero:is_exist() then
      return STATE.hero:get_icon()
    end
    return nil
  end

  local function get_player_name()
    local player = get_player_safe()
    if player and player.get_name then
      local name = player:get_name()
      if name and name ~= '' then
        return name
      end
    end
    return '玩家'
  end

  local function get_pending_choice_notice()
    if STATE.awaiting_upgrade and STATE.current_upgrade_choices and #STATE.current_upgrade_choices > 0 then
      return '强化待选', '按 1 / 2 / 3 完成当前 G 三选一。'
    end
    if STATE.gear_state and STATE.gear_state.awaiting_choice and STATE.gear_state.current_choices then
      return '武器待选', '成长武器词缀待选，按 1 / 2 / 3 选择。'
    end
    if STATE.bond_runtime and STATE.bond_runtime.awaiting_choice and STATE.bond_runtime.current_choices then
      return '羁绊待选', 'F 抽卡候选已生成，按 1 / 2 / 3 选择。'
    end
    local evolution_runtime = STATE.evolution_runtime or STATE.mark_runtime
    if evolution_runtime and evolution_runtime.awaiting_choice and evolution_runtime.current_choices then
      return '进化待选', '击杀奖励已到位，按 1 / 2 / 3 完成进化选择。'
    end
    if STATE.treasure_runtime then
      if STATE.treasure_runtime.awaiting_choice and STATE.treasure_runtime.current_choices then
        return '宝物待选', '宝物 3 选 1 已到位，按 1 / 2 / 3 选择。'
      end
      if STATE.treasure_runtime.awaiting_replace and STATE.treasure_runtime.pending_replace_choice then
        return '宝物替换', '当前宝物栏已满，请选择替换槽位。'
      end
    end
    return nil, nil
  end

  local function get_notice_text()
    local runtime = get_runtime()
    if runtime.tip_panel and runtime.tip_expires_at and runtime.tip_expires_at > (STATE.runtime_elapsed or 0) then
      return runtime.tip_title_text ~= '' and runtime.tip_title_text or '系统提示', runtime.tip_body_text or ''
    end
    local pending_title, pending_text = get_pending_choice_notice()
    if pending_title and pending_text then
      return pending_title, pending_text
    end

    local entries = STATE.battle_event_feed and STATE.battle_event_feed.entries or nil
    if entries and #entries > 0 then
      local entry = entries[#entries]
      if entry and entry.text and entry.text ~= '' then
        if entry.style == 'reward' then
          return '奖励提示', entry.text
        end
        if entry.style == 'warning' then
          return '战斗警报', entry.text
        end
        if entry.style == 'rare' then
          return '稀有事件', entry.text
        end
        if entry.style == 'positive' then
          return '进度更新', entry.text
        end
        return '系统消息', entry.text
      end
    end

    return '操作提示', 'F 抽卡，I 查看已吞卡牌，H 查看进化，P 打开存档。'
  end

  local function build_status_text()
    local prefs = ensure_preferences()
    local pending_title, _ = get_pending_choice_notice()
    if pending_title then
      return '状态：' .. pending_title
    end
    local damage_text = prefs.hide_damage_text and '跳字关' or '跳字开'
    local effect_text = prefs.hide_hit_effects and '特效关' or '特效开'
    local pause_text = prefs.soft_paused and '已暂停' or '进行中'
    return string.format('状态：%s | %s | %s', pause_text, damage_text, effect_text)
  end

  local function build_station_hint()
    return 'F 抽卡  I 已吞  H 进化  P 存档'
  end

  local function build_hotkey_help_text()
    return table.concat({
      'G / 强化：攻击技能三选一',
      'F / 抽卡：羁绊三选一',
      'I / 已吞：查看已吞羁绊',
      'H / 进化：查看真身 / 杀敌奖励',
      'V / 宝物：查看宝物入口',
      'Q / W / E / R：试炼入口',
      '1 / 2 / 3：选择当前轮次',
      'TAB / T：属性面板',
      'SPACE：打印状态概览',
      'P：打开存档',
    }, '\n')
  end

  local function ensure_overlay_widgets()
    local runtime = get_runtime()
    local player = get_player_safe()
    local hud = player and UIRoot.get_overlay_parent(y3, player) or nil
    if not hud then
      return
    end

    if not is_ui_alive(runtime.attr_panel) then
      local panel = hud:create_child('图片')
      panel:set_image(999)
      panel:set_ui_size(860, 500)
      panel:set_anchor(0.5, 0.5)
      set_percent_pos_if_alive(panel, 50, 56)
      panel:set_image_color(8, 14, 22, 232)
      panel:set_z_order(9400)
      panel:set_intercepts_operations(true)

      local title = panel:create_child('文本')
      title:set_ui_size(780, 34)
      title:set_pos(430, 455)
      title:set_font_size(24)
      title:set_text_color(240, 245, 255, 255)
      title:set_text_alignment('左', '中')

      local body = panel:create_child('文本')
      body:set_ui_size(790, 370)
      body:set_pos(430, 245)
      body:set_font_size(16)
      body:set_text_color(218, 228, 241, 255)
      body:set_text_alignment('左', '中')

      local hint = panel:create_child('文本')
      hint:set_ui_size(790, 24)
      hint:set_pos(430, 34)
      hint:set_font_size(14)
      hint:set_text('再次按 TAB / T 可关闭')
      hint:set_text_color(136, 160, 188, 255)
      hint:set_text_alignment('右', '中')

      panel:add_fast_event('左键-点击', function()
        local active_runtime = get_runtime()
        active_runtime.attr_panel_visible = false
        set_visible_if_alive(active_runtime.attr_panel, false)
      end)

      runtime.attr_panel = panel
      runtime.attr_panel_title = title
      runtime.attr_panel_body = body
      runtime.attr_panel_hint = hint
      set_visible_if_alive(panel, false)
    end

    if not is_ui_alive(runtime.tip_panel) then
      local panel = hud:create_child('图片')
      panel:set_image(999)
      panel:set_ui_size(760, 220)
      panel:set_anchor(0.5, 0.5)
      set_percent_pos_if_alive(panel, 50, 70)
      panel:set_image_color(11, 20, 31, 228)
      panel:set_z_order(9390)
      panel:set_intercepts_operations(true)

      local title = panel:create_child('文本')
      title:set_ui_size(680, 30)
      title:set_pos(380, 184)
      title:set_font_size(22)
      title:set_text_color(245, 248, 255, 255)
      title:set_text_alignment('左', '中')

      local body = panel:create_child('文本')
      body:set_ui_size(690, 132)
      body:set_pos(380, 98)
      body:set_font_size(16)
      body:set_text_color(216, 226, 239, 255)
      body:set_text_alignment('左', '中')

      local hint = panel:create_child('文本')
      hint:set_ui_size(680, 22)
      hint:set_pos(380, 24)
      hint:set_font_size(14)
      hint:set_text('点击任意位置关闭')
      hint:set_text_color(140, 164, 194, 255)
      hint:set_text_alignment('右', '中')

      panel:add_fast_event('左键-点击', function()
        local active_runtime = get_runtime()
        active_runtime.tip_expires_at = 0
        set_visible_if_alive(active_runtime.tip_panel, false)
      end)

      runtime.tip_panel = panel
      runtime.tip_panel_title = title
      runtime.tip_panel_body = body
      runtime.tip_panel_hint = hint
      set_visible_if_alive(panel, false)
    end

    if not is_ui_alive(runtime.big_cursor) then
      local text = hud:create_child('文本')
      text:set_ui_size(60, 60)
      text:set_text('◎')
      text:set_font_size(28)
      text:set_text_color(255, 233, 158, 235)
      text:set_text_alignment('中', '中')
      text:set_z_order(9380)
      text:set_intercepts_operations(false)
      call_ui(text, 'set_follow_mouse', true, 12, -10)
      runtime.big_cursor = text
      set_visible_if_alive(text, false)
    end
  end

  local function resolve_attr_row(index)
    return {
      root = resolve_ui(string.format('BattleBottomHUD.layout.left_station.player_attr_list.player_attr_bg_%d', index)),
      label = resolve_ui(string.format('BattleBottomHUD.layout.left_station.player_attr_list.player_attr_bg_%d.label', index)),
      value = resolve_ui(string.format('BattleBottomHUD.layout.left_station.player_attr_list.player_attr_bg_%d.value', index)),
      delta = resolve_ui(string.format('BattleBottomHUD.layout.left_station.player_attr_list.player_attr_bg_%d.delta', index)),
      icon = resolve_ui(string.format('BattleBottomHUD.layout.left_station.player_attr_list.player_attr_bg_%d.icon', index)),
    }
  end

  local function bind_click_once(key, ui, callback)
    local runtime = get_runtime()
    if runtime.bound_events[key] == ui and is_ui_alive(ui) then
      return
    end
    if not is_ui_alive(ui) or not ui.add_fast_event then
      return
    end
    runtime.bound_events[key] = ui
    call_ui(ui, 'set_intercepts_operations', true)
    ui:add_fast_event('左键-点击', function()
      if play_ui_click then
        play_ui_click()
      end
      callback()
    end)
  end

  local function show_tip_panel(text, duration, title)
    ensure_hud()
    local runtime = get_runtime()
    runtime.tip_expires_at = (STATE.runtime_elapsed or 0) + math.max(1, tonumber(duration) or NOTICE_DURATION)
    runtime.tip_title_text = title or '系统提示'
    runtime.tip_body_text = tostring(text or '')
    set_text_if_alive(runtime.tip_panel_title, title or '系统提示')
    set_text_if_alive(runtime.tip_panel_body, tostring(text or ''))
    set_visible_if_alive(runtime.tip_panel, runtime.visible ~= false)
  end

  local function refresh_tip_panel_visibility()
    local runtime = get_runtime()
    local should_show = runtime.tip_expires_at and runtime.tip_expires_at > (STATE.runtime_elapsed or 0)
    set_visible_if_alive(runtime.tip_panel, runtime.visible ~= false and should_show)
  end

  local function toggle_big_cursor()
    local prefs = ensure_preferences()
    prefs.big_cursor = not prefs.big_cursor
    local runtime = get_runtime()
    set_visible_if_alive(runtime.big_cursor, runtime.visible ~= false and prefs.big_cursor)
    show_tip_panel(
      prefs.big_cursor and '大鼠标已开启，鼠标位置会显示辅助圈。' or '大鼠标已关闭。',
      4,
      '鼠标辅助'
    )
  end

  local function toggle_damage_text()
    local prefs = ensure_preferences()
    prefs.hide_damage_text = not prefs.hide_damage_text
    show_tip_panel(
      prefs.hide_damage_text and '已屏蔽跳字。' or '已恢复跳字显示。',
      4,
      '本地显示'
    )
  end

  local function toggle_hit_effects()
    local prefs = ensure_preferences()
    prefs.hide_hit_effects = not prefs.hide_hit_effects
    show_tip_panel(
      prefs.hide_hit_effects and '已屏蔽局内技能特效。' or '已恢复局内技能特效。',
      4,
      '本地显示'
    )
  end

  local function toggle_pause()
    local prefs = ensure_preferences()
    prefs.soft_paused = not prefs.soft_paused
    if prefs.soft_paused then
      y3.game.enable_soft_pause()
      show_tip_panel('对局已暂停，再点一次继续。', 4, '战斗控制')
    else
      y3.game.resume_soft_pause()
      show_tip_panel('对局已继续。', 4, '战斗控制')
    end
  end

  local function toggle_attr_panel()
    ensure_hud()
    local runtime = get_runtime()
    runtime.attr_panel_visible = not runtime.attr_panel_visible
    if runtime.attr_panel_visible then
      local chunks = build_runtime_attr_dialog_chunks and build_runtime_attr_dialog_chunks() or {
        string.format('等级：%d', get_hero_level()),
        string.format('攻击：%s', compact_number(get_attr('攻击结算值', '攻击'))),
        string.format('护甲：%s', compact_number(get_attr('护甲结算值', '护甲'))),
        string.format('力量：%s', compact_number(get_attr('最终力量', '力量'))),
        string.format('智力：%s', compact_number(get_attr('最终智力', '智力'))),
        string.format('敏捷：%s', compact_number(get_attr('最终敏捷', '敏捷'))),
      }
      set_text_if_alive(runtime.attr_panel_title, '属性总览')
      set_text_if_alive(runtime.attr_panel_body, table.concat(chunks, '\n\n'))
    end
    set_visible_if_alive(runtime.attr_panel, runtime.visible ~= false and runtime.attr_panel_visible)
    return runtime.attr_panel_visible
  end

  local function refresh_button_texts()
    local prefs = ensure_preferences()

    set_text_if_alive(resolve_ui('top.top.left_buttons.btn_pause'), prefs.soft_paused and '继续' or '暂停')
    set_text_if_alive(resolve_ui('top.top.left_buttons.btn_powerup'), '强化')
    set_text_if_alive(resolve_ui('top.top.left_buttons.btn_hotkey'), '键位')

    set_text_if_alive(resolve_ui('BattleBottomHUD.layout.left_station.toggle_damage.button'),
      prefs.hide_damage_text and '恢复跳字' or '屏蔽跳字')
    set_text_if_alive(resolve_ui('BattleBottomHUD.layout.left_station.toggle_sfx.button'),
      prefs.hide_hit_effects and '恢复特效' or '屏蔽特效')
    set_text_if_alive(resolve_ui('BattleBottomHUD.layout.left_station.toggle_cursor.button'),
      prefs.big_cursor and '关闭大鼠标' or '大鼠标')

    set_text_if_alive(resolve_ui('BattleBottomHUD.layout.right_station.card_panel.draw_button.button'), '抽卡')
    set_text_if_alive(resolve_ui('BattleBottomHUD.layout.right_station.card_panel.reward_button.button'), '已吞')
    set_text_if_alive(resolve_ui('BattleBottomHUD.layout.right_station.card_panel.kill_reward_button.button'), '进化')
    set_text_if_alive(resolve_ui('BattleBottomHUD.layout.right_station.card_panel.fish_button.button'), '存档')

    set_text_if_alive(resolve_ui('BattleBottomHUD.layout.right_station.card_panel.draw_button.hotkey'), 'F')
    set_text_if_alive(resolve_ui('BattleBottomHUD.layout.right_station.card_panel.reward_button.hotkey'), 'I')
    set_text_if_alive(resolve_ui('BattleBottomHUD.layout.right_station.card_panel.kill_reward_button.hotkey'), 'H')
    set_text_if_alive(resolve_ui('BattleBottomHUD.layout.right_station.card_panel.fish_button.hotkey'), 'P')
  end

  ensure_hud = function()
    ensure_preferences()
    ensure_overlay_widgets()

    bind_click_once('top_pause', resolve_ui('top.top.left_buttons.btn_pause'), function()
      toggle_pause()
      refresh_hud()
    end)
    bind_click_once('top_powerup', resolve_ui('top.top.left_buttons.btn_powerup'), function()
      if show_upgrade_choices then
        show_upgrade_choices()
      end
      refresh_hud()
    end)
    bind_click_once('top_hotkey', resolve_ui('top.top.left_buttons.btn_hotkey'), function()
      show_tip_panel(build_hotkey_help_text(), 10, '快捷键')
    end)

    bind_click_once('toggle_damage', resolve_ui('BattleBottomHUD.layout.left_station.toggle_damage.button'), function()
      toggle_damage_text()
      refresh_hud()
    end)
    bind_click_once('toggle_effects', resolve_ui('BattleBottomHUD.layout.left_station.toggle_sfx.button'), function()
      toggle_hit_effects()
      refresh_hud()
    end)
    bind_click_once('toggle_cursor', resolve_ui('BattleBottomHUD.layout.left_station.toggle_cursor.button'), function()
      toggle_big_cursor()
      refresh_hud()
    end)

    bind_click_once('draw_button', resolve_ui('BattleBottomHUD.layout.right_station.card_panel.draw_button.button'), function()
      if try_bond_draw then
        try_bond_draw()
      end
      refresh_hud()
    end)
    bind_click_once('reward_button', resolve_ui('BattleBottomHUD.layout.right_station.card_panel.reward_button.button'), function()
      if show_bond_progress then
        show_bond_progress()
      else
        show_tip_panel('当前没有已吞卡牌面板可展示。', 4, '羁绊进度')
      end
      refresh_hud()
    end)
    bind_click_once('kill_reward_button', resolve_ui('BattleBottomHUD.layout.right_station.card_panel.kill_reward_button.button'), function()
      if try_evolution_entry then
        try_evolution_entry()
      end
      refresh_hud()
    end)
    bind_click_once('fish_button', resolve_ui('BattleBottomHUD.layout.right_station.card_panel.fish_button.button'), function()
      if open_save_panel and open_save_panel() ~= false then
        return
      end
      if show_runtime_status then
        show_runtime_status()
      end
    end)

    bind_click_once('gold_trial', resolve_ui('BattleBottomHUD.layout.center_hub.challenge_row.gold_trial'), function()
      if try_start_challenge then
        try_start_challenge('gold_trial')
      end
      refresh_hud()
    end)
    bind_click_once('treasure_trial', resolve_ui('BattleBottomHUD.layout.center_hub.challenge_row.treasure_trial'), function()
      if try_start_challenge then
        try_start_challenge('treasure_trial')
      end
      refresh_hud()
    end)
    bind_click_once('growth_weapon_slot', resolve_ui('BattleBottomHUD.layout.center_hub.growth_weapon_slot'), function()
      if try_upgrade_growth_weapon then
        try_upgrade_growth_weapon('hud_click')
      end
      refresh_hud()
    end)

    refresh_button_texts()
    return get_runtime()
  end

  local function refresh_top_panel()
    set_text_if_alive(resolve_ui('top.top.金币.image_3.label_2'), compact_number(STATE.resources and STATE.resources.gold or 0))
    set_text_if_alive(resolve_ui('top.top.木材.image_3.label_2'), compact_number(STATE.resources and STATE.resources.wood or 0))
    set_text_if_alive(resolve_ui('top.top.人口.image_3.label_2'), compact_number(STATE.total_kills or 0))

    set_text_if_alive(resolve_ui('top.top.金币.delta'), string.format('+%s/s', compact_number(get_attr('每秒金币'))))
    set_text_if_alive(resolve_ui('top.top.木材.delta'), string.format('+%s/s', compact_number(get_attr('每秒木材'))))
    set_text_if_alive(resolve_ui('top.top.人口.delta'), string.format('敌 %d', math.max(0, tonumber(STATE.total_enemy_alive) or 0)))

    local notice_title, notice_text = get_notice_text()
    set_text_if_alive(resolve_ui('top.top.system_notice.notice_title'), notice_title)
    set_text_if_alive(resolve_ui('top.top.system_notice.notice_text'), notice_text)

    local stage_name = STATE.current_stage_def and (STATE.current_stage_def.display_label or STATE.current_stage_def.display_name) or '当前章节'
    local mode_name = STATE.current_mode_def and STATE.current_mode_def.display_name or '战斗模式'
    local wave_name = STATE.active_wave and STATE.active_wave.wave and STATE.active_wave.wave.name
      or (STATE.current_wave_index and STATE.current_wave_index > 0 and string.format('第%d波', STATE.current_wave_index) or '未开始')
    local phase_title = ({ get_pending_choice_notice() })[1] or (STATE.session_phase == 'battle' and '战斗中' or '准备中')
    local threat_text
    if STATE.active_wave and STATE.active_wave.wave and STATE.active_wave.wave.boss_spawn_sec and STATE.active_wave.boss_spawned ~= true then
      threat_text = string.format('Boss %.1fs', math.max(0, (STATE.active_wave.wave.boss_spawn_sec or 0) - (STATE.active_wave.elapsed or 0)))
    else
      threat_text = string.format('敌人 %d', math.max(0, tonumber(STATE.total_enemy_alive) or 0))
    end

    set_text_if_alive(resolve_ui('top.tophud.layout_2.curlevel'), stage_name)
    set_text_if_alive(resolve_ui('top.tophud.layout_2.curlevel_sub'), mode_name)
    set_text_if_alive(resolve_ui('top.tophud.layout_2.gametime'), format_time(STATE.runtime_elapsed or 0))
    set_text_if_alive(resolve_ui('top.tophud.layout_2.wave'), wave_name)
    set_text_if_alive(resolve_ui('top.tophud.layout_2.phase_text'), phase_title)
    set_text_if_alive(resolve_ui('top.tophud.layout_2.threat_text'), threat_text)

    set_text_if_alive(resolve_ui('top.top.scoreboard.title'), '玩家状态')
    set_text_if_alive(resolve_ui('top.top.scoreboard.player_name'), get_player_name())
    set_text_if_alive(resolve_ui('top.top.scoreboard.player_power'), compact_number(get_attr('攻击结算值', '攻击')))
    set_text_if_alive(resolve_ui('top.top.scoreboard.player_state'), STATE.session_phase == 'battle' and '战斗中' or '局外')
    set_text_if_alive(resolve_ui('top.top.scoreboard.player_level'), tostring(get_hero_level()))
    set_text_if_alive(resolve_ui('top.top.scoreboard.player_equip'),
      tostring(STATE.treasure_runtime and STATE.treasure_runtime.active_slots and #STATE.treasure_runtime.active_slots or 0))
    set_text_if_alive(resolve_ui('top.top.scoreboard.player_swallow'),
      tostring(STATE.bond_runtime and count_entries(STATE.bond_runtime.completed_root_sets) or 0))

    for index = 2, 4 do
      set_text_if_alive(resolve_ui(string.format('top.top.scoreboard.player_name_%d', index)), '-')
      set_text_if_alive(resolve_ui(string.format('top.top.scoreboard.player_power_%d', index)), '-')
      set_text_if_alive(resolve_ui(string.format('top.top.scoreboard.player_state_%d', index)), '-')
      set_text_if_alive(resolve_ui(string.format('top.top.scoreboard.player_level_%d', index)), '-')
      set_text_if_alive(resolve_ui(string.format('top.top.scoreboard.player_equip_%d', index)), '-')
      set_text_if_alive(resolve_ui(string.format('top.top.scoreboard.player_swallow_%d', index)), '-')
    end
  end

  local function refresh_attr_rows()
    local rows = {
      { label = '攻击', value = compact_number(get_attr('攻击结算值', '攻击')), delta = format_signed_percent_pair(get_attr('攻击增幅'), get_attr('最终攻击')) },
      { label = '护甲', value = compact_number(get_attr('护甲结算值', '护甲')), delta = format_signed_percent_pair(get_attr('护甲增幅'), get_attr('最终护甲')) },
      { label = '力量', value = compact_number(get_attr('最终力量', '力量')), delta = format_signed_percent_pair(get_attr('力量增幅'), get_attr('最终力量增幅')) },
      { label = '智力', value = compact_number(get_attr('最终智力', '智力')), delta = format_signed_percent_pair(get_attr('智力增幅'), get_attr('最终智力增幅')) },
      { label = '敏捷', value = compact_number(get_attr('最终敏捷', '敏捷')), delta = format_signed_percent_pair(get_attr('敏捷增幅'), get_attr('最终敏捷增幅')) },
      { label = '暴击', value = format_percent(get_attr('物理暴击')), delta = '爆伤 ' .. format_percent(get_attr('物理暴伤')) },
    }

    for index, row_data in ipairs(rows) do
      local row = resolve_attr_row(index)
      set_visible_if_alive(row.root, true)
      set_text_if_alive(row.label, row_data.label)
      set_text_if_alive(row.value, row_data.value)
      set_text_if_alive(row.delta, row_data.delta)
      set_text_color_if_alive(row.delta, { 131, 210, 255, 255 })
    end
  end

  local function refresh_hero_panel()
    local current_hp = STATE.hero and STATE.hero.is_exist and STATE.hero:is_exist() and (tonumber(STATE.hero:get_hp()) or 0) or 0
    local max_hp = math.max(1, get_attr('生命结算值', '生命'))
    local exp_current = tonumber(STATE.hero_progress and STATE.hero_progress.exp) or 0
    local exp_max = tonumber(STATE.hero_progress and STATE.hero_progress.exp_to_next) or 1
    if exp_max <= 0 then
      exp_max = math.max(1, exp_current)
    end

    set_image_if_alive(resolve_ui('BattleBottomHUD.layout.center_hub.hero_panel.hero_portrait'), get_hero_icon())
    set_text_if_alive(resolve_ui('BattleBottomHUD.layout.center_hub.hero_panel.hero_name'), get_hero_name())
    set_text_if_alive(resolve_ui('BattleBottomHUD.layout.center_hub.hero_panel.hero_level'), string.format('等级：%d', get_hero_level()))
    set_progress_if_alive(resolve_ui('BattleBottomHUD.layout.center_hub.hero_panel.hero_hp_fill'), current_hp, max_hp)
    set_text_if_alive(resolve_ui('BattleBottomHUD.layout.center_hub.hero_panel.hero_hp_text'),
      string.format('%s/%s', compact_number(current_hp), compact_number(max_hp)))

    set_text_if_alive(resolve_ui('BattleBottomHUD.layout.center_hub.hero_panel.hero_attack_row.label'), '攻击')
    set_text_if_alive(resolve_ui('BattleBottomHUD.layout.center_hub.hero_panel.hero_attack_row.value'), compact_number(get_attr('攻击结算值', '攻击')))
    set_text_if_alive(resolve_ui('BattleBottomHUD.layout.center_hub.hero_panel.hero_defense_row.label'), '护甲')
    set_text_if_alive(resolve_ui('BattleBottomHUD.layout.center_hub.hero_panel.hero_defense_row.value'), compact_number(get_attr('护甲结算值', '护甲')))
    set_text_if_alive(resolve_ui('BattleBottomHUD.layout.center_hub.hero_panel.hero_power_row.label'), '力量')
    set_text_if_alive(resolve_ui('BattleBottomHUD.layout.center_hub.hero_panel.hero_power_row.value'), compact_number(get_attr('最终力量', '力量')))
    set_text_if_alive(resolve_ui('BattleBottomHUD.layout.center_hub.hero_panel.hero_agility_row.label'), '敏捷')
    set_text_if_alive(resolve_ui('BattleBottomHUD.layout.center_hub.hero_panel.hero_agility_row.value'), compact_number(get_attr('最终敏捷', '敏捷')))

    set_progress_if_alive(resolve_ui('BattleBottomHUD.layout.center_hub.exp_bar.fill'), exp_current, exp_max)
    set_text_if_alive(resolve_ui('BattleBottomHUD.layout.center_hub.exp_bar.exp_text'),
      string.format('%s/%s', compact_number(exp_current), compact_number(exp_max)))
  end

  local function refresh_challenge_row()
    local gold_charge = STATE.challenge_charge_map and STATE.challenge_charge_map.gold_trial or STATE.challenge_charges or 0
    local treasure_charge = STATE.challenge_charge_map and STATE.challenge_charge_map.treasure_trial or STATE.challenge_charges or 0
    set_text_if_alive(resolve_ui('BattleBottomHUD.layout.center_hub.challenge_row.gold_trial.title'), '金币挑战')
    set_text_if_alive(resolve_ui('BattleBottomHUD.layout.center_hub.challenge_row.gold_trial.count'), tostring(math.max(0, tonumber(gold_charge) or 0)))
    set_text_if_alive(resolve_ui('BattleBottomHUD.layout.center_hub.challenge_row.treasure_trial.title'), '宝物挑战')
    set_text_if_alive(resolve_ui('BattleBottomHUD.layout.center_hub.challenge_row.treasure_trial.count'), tostring(math.max(0, tonumber(treasure_charge) or 0)))
    set_text_if_alive(resolve_ui('BattleBottomHUD.layout.center_hub.challenge_row.climb_layer.title'), '当前波次')
    set_text_if_alive(resolve_ui('BattleBottomHUD.layout.center_hub.challenge_row.climb_layer.count'),
      tostring(math.max(0, tonumber(STATE.current_wave_index) or 0)))
    set_text_if_alive(resolve_ui('BattleBottomHUD.layout.center_hub.challenge_row.realm_progress.title'), '存活敌人')
    set_text_if_alive(resolve_ui('BattleBottomHUD.layout.center_hub.challenge_row.realm_progress.count'),
      tostring(math.max(0, tonumber(STATE.total_enemy_alive) or 0)))
  end

  local function refresh_growth_weapon_slot()
    local payload = build_growth_weapon_tip_payload and build_growth_weapon_tip_payload() or nil
    local weapon_level = STATE.gear_state
      and STATE.gear_state.items
      and STATE.gear_state.items.weapon
      and STATE.gear_state.items.weapon.level
      or 0
    set_image_if_alive(resolve_ui('BattleBottomHUD.layout.center_hub.growth_weapon_slot.icon'),
      payload and payload.icon_res or nil)
    set_text_if_alive(resolve_ui('BattleBottomHUD.layout.center_hub.growth_weapon_slot.title'),
      payload and payload.title_text or '成长武器')
    set_text_if_alive(resolve_ui('BattleBottomHUD.layout.center_hub.growth_weapon_slot.weapon_level'),
      weapon_level > 0 and ('Lv.' .. tostring(weapon_level)) or '点击升级')
  end

  local function refresh_skill_bar()
    for slot = 1, 4 do
      local skill = STATE.attack_skill_state and STATE.attack_skill_state.slots and STATE.attack_skill_state.slots[slot] or nil
      local prefix = string.format('BattleBottomHUD.layout.center_hub.skill_bar.skill_slot_%d', slot)
      set_image_if_alive(resolve_ui(prefix .. '.icon'), skill and (skill.ui_icon or skill.icon) or nil)
      if slot == 1 then
        set_text_if_alive(resolve_ui(prefix .. '.key'), '普')
      else
        set_text_if_alive(resolve_ui(prefix .. '.key'), tostring(slot))
      end
      if skill then
        set_text_if_alive(resolve_ui(prefix .. '.label'), tostring(skill.name or skill.id or ('技能' .. slot)))
        if tonumber(skill.cooldown_remaining) and skill.cooldown_remaining > 0 then
          set_text_if_alive(resolve_ui(prefix .. '.cooldown'), string.format('%.1fs', skill.cooldown_remaining))
        else
          set_text_if_alive(resolve_ui(prefix .. '.cooldown'), '就绪')
        end
      else
        set_text_if_alive(resolve_ui(prefix .. '.label'), '未解锁')
        set_text_if_alive(resolve_ui(prefix .. '.cooldown'), '')
      end
    end
  end

  local function refresh_left_station()
    set_text_if_alive(resolve_ui('BattleBottomHUD.layout.left_station.player_name'), get_player_name())
    set_text_if_alive(resolve_ui('BattleBottomHUD.layout.left_station.map_badge'),
      STATE.current_stage_def and (STATE.current_stage_def.display_label or STATE.current_stage_def.display_name) or '当前章节')
    set_text_if_alive(resolve_ui('BattleBottomHUD.layout.left_station.station_note'), '本地功能')
    refresh_attr_rows()
  end

  local function refresh_action_area()
    set_text_if_alive(resolve_ui('BattleBottomHUD.layout.center_hub.status_text'), build_status_text())
    set_text_if_alive(resolve_ui('BattleBottomHUD.layout.right_station.card_panel.station_hint'), build_station_hint())
  end

  local function refresh_bond_slots()
    for slot = 1, BOND_SLOT_COUNT do
      local prefix = string.format('BattleBottomHUD.layout.right_station.card_panel.card_slot_%d', slot)
      local icon_ui = resolve_ui(prefix .. '.icon')
      local icon = get_bond_slot_icon and get_bond_slot_icon(slot) or nil
      set_visible_if_alive(resolve_ui(prefix), slot <= 7 or slot == 8)
      if icon then
        set_visible_if_alive(icon_ui, true)
        set_image_if_alive(icon_ui, icon)
      else
        set_visible_if_alive(icon_ui, false)
      end
    end
  end

  refresh_hud = function()
    ensure_hud()
    local runtime = get_runtime()
    refresh_button_texts()
    refresh_top_panel()
    refresh_left_station()
    refresh_hero_panel()
    refresh_challenge_row()
    refresh_growth_weapon_slot()
    refresh_skill_bar()
    refresh_action_area()
    refresh_bond_slots()

    set_visible_if_alive(runtime.big_cursor, runtime.visible ~= false and ensure_preferences().big_cursor)
    set_visible_if_alive(runtime.attr_panel, runtime.visible ~= false and runtime.attr_panel_visible)
    refresh_tip_panel_visibility()
    return runtime
  end

  local function set_visible(visible)
    local runtime = get_runtime()
    runtime.visible = visible == true
    set_visible_if_alive(resolve_ui('top'), visible)
    set_visible_if_alive(resolve_ui('BattleBottomHUD'), visible)
    set_visible_if_alive(runtime.attr_panel, visible == true and runtime.attr_panel_visible)
    set_visible_if_alive(runtime.tip_panel, visible == true and runtime.tip_expires_at > (STATE.runtime_elapsed or 0))
    set_visible_if_alive(runtime.big_cursor, visible == true and ensure_preferences().big_cursor)
  end

  return {
    ensure_hud = ensure_hud,
    refresh_hud = refresh_hud,
    set_visible = set_visible,
    show_tip_panel = show_tip_panel,
    toggle_attr_panel = toggle_attr_panel,
  }
end

return M
