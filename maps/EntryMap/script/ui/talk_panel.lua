local UIRoot = require 'ui.ui_root'

local M = {}

local MESSAGE_LIFETIME = 15
local MESSAGE_LIMIT = 18
local SAVE_SLOT = 1

local TALK_CONFIG = {
  code_enable = true,
}

local TALK_FORMATS = {
  [1] = '#03738c[@t] #ffdaa1@p#f29f05<@n> #ffffff@s1',
  [2] = '#f2b705[公告] #ffffff@s1',
  [3] = '#f2b705[骰子] #ffdaa1@p#f29f05<@n> #ffffff掷出了 @s1 点！',
  [998] = '#f2b705[兑换码] #ffdaa1@p#f29f05<@n> #ffffff@s1',
  [999] = '#f2b705[兑换码] #ffdaa1@p#f29f05<@n> #ffffff兑换了#ffdaa1【@s1 x@s2】',
}

local CODE_REWARD_TYPES = {
  ['1'] = {
    type = 'player_attribute',
    value = 'official_res_1',
    display_name = '金币',
  },
  ['2'] = {
    type = 'item_type',
    value = 827060921,
  },
}

local TALK_CODES = {
  ASD111 = {
    reward_key = '1',
    value = 5000,
    is_unique = false,
  },
  ASD222 = {
    reward_key = '2',
    value = 1,
    is_unique = true,
  },
}

local function is_alive(ui)
  return UIRoot.is_alive(ui)
end

local function trim_text(text)
  local value = tostring(text or ''):gsub('\r', ''):gsub('\n', ' ')
  value = value:gsub('^%s+', '')
  value = value:gsub('%s+$', '')
  return value
end

local function replace_token(template, token, value)
  return template:gsub(token, tostring(value or ''))
end

local function format_message(format_id, payload)
  local template = TALK_FORMATS[format_id] or TALK_FORMATS[1]
  local text = template
  text = replace_token(text, '@t', payload.t or '')
  text = replace_token(text, '@p', payload.p or '')
  text = replace_token(text, '@n', payload.n or '')
  for index = 1, 6 do
    text = replace_token(text, '@s' .. tostring(index), payload['s' .. tostring(index)] or '')
  end
  return text
end

local function safe_remove_timer(timer)
  if timer and timer.remove then
    timer:remove()
  end
end

local function safe_remove_prefab(prefab)
  if prefab and prefab.remove then
    prefab:remove()
  end
end

function M.create(env)
  local y3 = env.y3
  local STATE = env.STATE
  local get_player = env.get_player
  local get_reward_unit = env.get_reward_unit

  local runtime = {
    visible = true,
    panels = {},
  }

  local function clear_input_text(panel)
    if panel and panel.input_field and is_alive(panel.input_field) and panel.input_field.set_text then
      panel.input_field:set_text('')
    end
  end

  local function try_bind_current_chatbox(panel)
    if not panel
      or not panel.player
      or not panel.input_field
      or not is_alive(panel.input_field)
      or not GameAPI
      or not GameAPI.set_cur_chatbox then
      return false
    end
    local ok = pcall(GameAPI.set_cur_chatbox, panel.player.handle, panel.input_field.handle)
    return ok
  end

  local function ensure_input_prefab(panel)
    if not panel or not is_alive(panel.input_bg) then
      return false
    end
    if panel.input_prefab and panel.input_field and is_alive(panel.input_field) then
      return true
    end

    panel.input_bg:set_visible(false)
    local ok, prefab_or_err = pcall(y3.ui_prefab.create, panel.player, 'talk_sys_dym_txtBox', panel.input_bg)
    if not ok or not prefab_or_err then
      return false
    end

    local prefab = prefab_or_err
    local field = prefab:get_child('talk_sys_dym_label_input')
    if not field then
      safe_remove_prefab(prefab)
      return false
    end

    panel.input_prefab = prefab
    panel.input_field = field
    panel.input_open = false
    clear_input_text(panel)
    try_bind_current_chatbox(panel)
    return true
  end

  local function get_player_label(player)
    local player_id = player and player.get_id and player:get_id() or 0
    return string.format('%dP ', player_id + 1)
  end

  local function get_player_name(player)
    if player and player.get_name then
      local name = trim_text(player:get_name())
      if name ~= '' then
        return name
      end
    end
    local player_id = player and player.get_id and player:get_id() or 0
    return string.format('玩家%d', player_id + 1)
  end

  local function ensure_panel_for_player(player)
    local key = player:get_id()
    local panel = runtime.panels[key]
    if panel and panel.root and is_alive(panel.root) then
      return panel
    end

    local root = UIRoot.get_talk_root(y3, player)
    if not root then
      return nil
    end

    panel = {
      player = player,
      root = root,
      input_bg = UIRoot.resolve_ui(y3, player, 'talk_sys_panel.talk_sys_input_img_bg'),
      list_bg = UIRoot.resolve_ui(y3, player, 'talk_sys_panel.talk_sys_list_img_bg'),
      list = UIRoot.resolve_ui(y3, player, 'talk_sys_panel.talk_sys_list_img_bg.talk_sys_list'),
      entries = {},
      input_prefab = nil,
      input_field = nil,
      input_open = false,
    }
    runtime.panels[key] = panel

    if is_alive(panel.input_bg) then
      panel.input_bg:set_visible(false)
    end
    ensure_input_prefab(panel)
    try_bind_current_chatbox(panel)
    if is_alive(panel.root) then
      panel.root:set_visible(runtime.visible == true)
    end
    return panel
  end

  local function remove_entry(panel, entry)
    for index, current in ipairs(panel.entries) do
      if current == entry then
        safe_remove_timer(current.timer)
        safe_remove_prefab(current.prefab)
        table.remove(panel.entries, index)
        break
      end
    end
  end

  local function show_text_for_player(player, text, duration)
    local panel = ensure_panel_for_player(player)
    if not panel or not is_alive(panel.list) then
      return nil
    end

    local prefab = y3.ui_prefab.create(player, 'talk_sys_dym_label', panel.list)
    local root = prefab and prefab:get_child() or nil
    local label = prefab and prefab:get_child('talk_sys_dym_label_say') or nil
    if not root or not label then
      return nil
    end

    label:set_text(text or '')
    if panel.list.set_list_view_percent then
      panel.list:set_list_view_percent(100)
    end

    local entry = {
      prefab = prefab,
      timer = nil,
    }
    panel.entries[#panel.entries + 1] = entry
    while #panel.entries > MESSAGE_LIMIT do
      remove_entry(panel, panel.entries[1])
    end

    entry.timer = y3.ltimer.wait(duration or MESSAGE_LIFETIME, function()
      remove_entry(panel, entry)
    end)
    return entry
  end

  local function show_local_text(player, format_id, payload)
    return show_text_for_player(player, format_message(format_id, payload))
  end

  local function broadcast_text(source_player, format_id, payload)
    local group = y3.player_group.get_ally_player_group_by_player(source_player)
    for target_player in group:pairs() do
      if target_player and target_player.is_alive and target_player:is_alive() then
        show_local_text(target_player, format_id, payload)
      end
    end
  end

  local function close_input(panel)
    if not panel then
      return
    end
    if panel.input_field and is_alive(panel.input_field) and panel.input_field.set_input_field_not_focus then
      panel.input_field:set_input_field_not_focus()
    end
    panel.input_open = false
    clear_input_text(panel)
    if is_alive(panel.input_bg) then
      panel.input_bg:set_visible(false)
    end
    try_bind_current_chatbox(panel)
  end

  local function resolve_reward_target()
    if type(get_reward_unit) == 'function' then
      return get_reward_unit()
    end
    return STATE and STATE.hero or nil
  end

  local function show_code_result(player, ok, text, item_name, item_count)
    local payload = {
      t = '兑换码',
      p = get_player_label(player),
      n = get_player_name(player),
      s1 = ok and (item_name or '') or text,
      s2 = tostring(item_count or 1),
    }
    return show_local_text(player, ok and 999 or 998, payload)
  end

  local function try_redeem_code(player, raw_code)
    local code = trim_text(raw_code):upper()
    if code == '' then
      return false
    end

    local code_entry = TALK_CODES[code]
    if not code_entry then
      return false
    end

    local save_data = y3.save_data.load_table_with_cover_disable(player, SAVE_SLOT)
    if code_entry.is_unique and save_data[code] then
      show_code_result(player, false, '该兑换码已经领取过了。')
      return true
    end

    local reward_def = CODE_REWARD_TYPES[code_entry.reward_key]
    if not reward_def then
      show_code_result(player, false, '兑换码奖励配置缺失。')
      return true
    end

    local reward_name
    if reward_def.type == 'player_attribute' then
      player:add(reward_def.value, code_entry.value or 0)
      reward_name = reward_def.display_name or tostring(reward_def.value)
    elseif reward_def.type == 'item_type' then
      local hero = resolve_reward_target()
      if not hero or not hero.is_exist or not hero:is_exist() or not hero.add_item then
        show_code_result(player, false, '当前没有可发放奖励的英雄。')
        return true
      end
      reward_name = y3.item.get_name_by_key(reward_def.value)
      for _ = 1, math.max(1, math.floor(tonumber(code_entry.value) or 1)) do
        hero:add_item(reward_def.value, '物品栏')
      end
    else
      show_code_result(player, false, '暂不支持该兑换码奖励类型。')
      return true
    end

    if code_entry.is_unique then
      save_data[code] = true
    end

    show_code_result(player, true, nil, reward_name, code_entry.value)
    return true
  end

  local function submit_input()
    local player = get_player()
    local panel = ensure_panel_for_player(player)
    if not panel or not panel.input_field or not is_alive(panel.input_field) then
      return false
    end

    local text = trim_text(panel.input_field:get_input_field_content())
    close_input(panel)
    if text == '' then
      return false
    end

    if TALK_CONFIG.code_enable and try_redeem_code(player, text) then
      return true
    end

    local payload = {
      t = '队伍',
      p = get_player_label(player),
      n = get_player_name(player),
      s1 = text,
    }
    broadcast_text(player, 1, payload)
    return true
  end

  local function open_input()
    local player = get_player()
    local panel = ensure_panel_for_player(player)
    if not panel or not is_alive(panel.input_bg) or not ensure_input_prefab(panel) then
      return false
    end
    if panel.input_open == true and panel.input_field and is_alive(panel.input_field) then
      try_bind_current_chatbox(panel)
      panel.input_field:set_input_field_focus()
      return true
    end

    panel.input_bg:set_visible(true)
    panel.input_open = true
    clear_input_text(panel)
    try_bind_current_chatbox(panel)
    if panel.input_field and panel.input_field.set_input_field_focus then
      panel.input_field:set_input_field_focus()
    end
    y3.ltimer.wait_frame(1, function()
      if not panel.input_open or runtime.visible ~= true then
        return
      end
      if not panel.input_field or not is_alive(panel.input_field) then
        return
      end
      try_bind_current_chatbox(panel)
      if panel.input_field.set_input_field_focus then
        panel.input_field:set_input_field_focus()
      end
    end)
    return true
  end

  local function toggle_input()
    if runtime.visible ~= true then
      return false
    end
    local player = get_player()
    local panel = ensure_panel_for_player(player)
    if not panel then
      return false
    end
    if panel.input_open == true and panel.input_field and is_alive(panel.input_field) then
      return submit_input()
    end
    return open_input()
  end

  local function set_visible(visible)
    runtime.visible = visible == true
    if runtime.visible == true then
      ensure_panel_for_player(get_player())
    end
    for _, panel in pairs(runtime.panels) do
      if is_alive(panel.root) then
        panel.root:set_visible(runtime.visible)
      end
      if runtime.visible == true then
        if panel.input_open == true and is_alive(panel.input_bg) then
          panel.input_bg:set_visible(true)
        elseif is_alive(panel.input_bg) then
          panel.input_bg:set_visible(false)
        end
        try_bind_current_chatbox(panel)
      else
        close_input(panel)
      end
    end
  end

  local function push_system_text(text, players)
    local payload = {
      s1 = text or '',
    }
    if players then
      for _, player in ipairs(players) do
        if player then
          show_local_text(player, 2, payload)
        end
      end
      return
    end
    show_local_text(get_player(), 2, payload)
  end

  return {
    ensure_panel = ensure_panel_for_player,
    toggle_input = toggle_input,
    set_visible = set_visible,
    push_system_text = push_system_text,
    try_redeem_code = function(code)
      return try_redeem_code(get_player(), code)
    end,
    push_player_text = function(player, format_id, payload)
      return show_local_text(player, format_id, payload)
    end,
  }
end

return M
