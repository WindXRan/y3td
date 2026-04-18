local UIRoot = require 'ui.ui_root'

local M = {}

local BAR_SLOT_COUNT = 6
local BAG_ROW_COUNT = 6
local BAG_COL_COUNT = 7
local BAG_SLOT_COUNT = BAG_ROW_COUNT * BAG_COL_COUNT
local PUBLIC_ROW_COUNT = 7
local PUBLIC_COL_COUNT = 7
local PUBLIC_SLOT_COUNT = PUBLIC_ROW_COUNT * PUBLIC_COL_COUNT
local TOTAL_PKG_SLOT_COUNT = BAG_SLOT_COUNT + PUBLIC_SLOT_COUNT

local function is_alive(ui)
  return UIRoot.is_alive(ui)
end

local function safe_set_visible(ui, visible)
  if is_alive(ui) then
    ui:set_visible(visible == true)
  end
end

local function trim_text(text)
  local value = tostring(text or ''):gsub('\r', '')
  value = value:gsub('^%s+', '')
  value = value:gsub('%s+$', '')
  return value
end

local function split_lines(text)
  local lines = {}
  for line in trim_text(text):gmatch('[^\n]+') do
    if line ~= '' then
      lines[#lines + 1] = line
    end
  end
  return lines
end

local function format_number(value)
  local number = tonumber(value) or 0
  if math.abs(number - math.floor(number + 0.0001)) < 0.0001 then
    return tostring(math.floor(number + 0.0001))
  end
  return string.format('%.2f', number):gsub('0+$', ''):gsub('%.+$', '')
end

local function format_attr_line(key, value)
  local number = tonumber(value) or 0
  local prefix = number >= 0 and '+' or ''
  return string.format('%s %s%s', tostring(key), prefix, format_number(number))
end

function M.create(env)
  local STATE = env.STATE
  local y3 = env.y3
  local get_player = env.get_player
  local get_growth_weapon_item_key = env.get_growth_weapon_item_key
  local build_growth_weapon_tip_payload = env.build_growth_weapon_tip_payload
  local try_upgrade_growth_weapon = env.try_upgrade_growth_weapon

  local runtime = {
    visible = true,
    panel_visible = false,
    public_visible = false,
    bound_targets = {},
    slots = {
      bar = {},
      bag = {},
      public = {},
    },
    tip_state = nil,
  }

  local function resolve_slot_type(kind)
    if kind == 'bar' then
      return y3.const.SlotType.BAR
    end
    return y3.const.SlotType.PKG
  end

  local function resolve_bind_index(kind, index)
    if kind == 'public' then
      return BAG_SLOT_COUNT + index - 1
    end
    return index - 1
  end

  local function get_slot_item(hero, kind, index)
    if not hero or not hero.is_exist or not hero:is_exist() then
      return nil
    end
    local slot_type = resolve_slot_type(kind)
    local bind_index = resolve_bind_index(kind, index)
    return hero:get_item_by_slot(slot_type, bind_index) or hero:get_item_by_slot(slot_type, bind_index + 1)
  end

  local function get_hero()
    local hero = STATE and STATE.hero or nil
    if hero and hero.is_exist and hero:is_exist() then
      return hero
    end
    return nil
  end

  local function ensure_capacity(hero)
    if not hero then
      return
    end
    if hero.get_bar_cnt and hero.set_bar_cnt then
      local bar_cnt = tonumber(hero:get_bar_cnt()) or 0
      if bar_cnt < BAR_SLOT_COUNT then
        hero:set_bar_cnt(BAR_SLOT_COUNT)
      end
    end
    if hero.get_pkg_cnt and hero.set_pkg_cnt then
      local bag_cnt = tonumber(hero:get_pkg_cnt()) or 0
      if bag_cnt < TOTAL_PKG_SLOT_COUNT then
        hero:set_pkg_cnt(TOTAL_PKG_SLOT_COUNT)
      end
    end
  end

  local function resolve_slot_path(kind, index)
    if kind == 'bar' then
      return string.format('背包系统.背包系统.独立物品栏.item.%d.slot', index)
    end
    if kind == 'public' then
      local row = math.floor((index - 1) / PUBLIC_COL_COUNT) + 1
      local col = ((index - 1) % PUBLIC_COL_COUNT) + 1
      return string.format('背包系统.背包系统.背包.public.共享仓库.publicStorage.%d.%d.slot', row, col)
    end
    local row = math.floor((index - 1) / BAG_COL_COUNT) + 1
    local col = ((index - 1) % BAG_COL_COUNT) + 1
    return string.format('背包系统.背包系统.背包.仓库.%d.%d.slot', row, col)
  end

  local function resolve_hover_path(kind, index)
    if kind == 'bar' then
      return string.format('背包系统.背包系统.独立物品栏.item.%d.hover_resp', index)
    end
    if kind == 'public' then
      local row = math.floor((index - 1) / PUBLIC_COL_COUNT) + 1
      local col = ((index - 1) % PUBLIC_COL_COUNT) + 1
      return string.format('背包系统.背包系统.背包.public.共享仓库.publicStorage.%d.%d.hover_resp', row, col)
    end
    local row = math.floor((index - 1) / BAG_COL_COUNT) + 1
    local col = ((index - 1) % BAG_COL_COUNT) + 1
    return string.format('背包系统.背包系统.背包.仓库.%d.%d.hover_resp', row, col)
  end

  local function ensure_panel()
    if runtime.root and is_alive(runtime.root) then
      return runtime
    end

    local player = get_player()
    local root = UIRoot.get_inventory_root(y3, player)
    if not root then
      return nil
    end

    runtime.root = root
    runtime.big_panel = UIRoot.resolve_ui(y3, player, '背包系统.背包系统.背包')
    runtime.open_button = UIRoot.resolve_ui(y3, player, '背包系统.背包系统.背包按钮')
    runtime.open_button_tip = UIRoot.resolve_ui(y3, player, '背包系统.背包系统.背包按钮.tip_TEXT')
    runtime.exit_button = UIRoot.resolve_ui(y3, player, '背包系统.背包系统.背包.title.inventoryExit_BTN')
    runtime.public_root = UIRoot.resolve_ui(y3, player, '背包系统.背包系统.背包.public')
    runtime.public_button = UIRoot.resolve_ui(y3, player, '背包系统.背包系统.背包.public.BtnPublicStorage')
    runtime.public_panel = UIRoot.resolve_ui(y3, player, '背包系统.背包系统.背包.public.共享仓库')
    runtime.tip_root = UIRoot.resolve_ui(y3, player, '背包系统.背包系统.物品说明')
    runtime.tip_title = UIRoot.resolve_ui(y3, player, '背包系统.背包系统.物品说明.basic.title.title_TEXT')
    runtime.tip_subtitle = UIRoot.resolve_ui(y3, player, '背包系统.背包系统.物品说明.basic.title.subtitle_TEXT')
    runtime.tip_subtitle_icon = UIRoot.resolve_ui(y3, player, '背包系统.背包系统.物品说明.basic.title.subtitle_TEXT.icon')
    runtime.tip_icon = UIRoot.resolve_ui(y3, player, '背包系统.背包系统.物品说明.basic.avatar.icon')
    runtime.tip_note = UIRoot.resolve_ui(y3, player, '背包系统.背包系统.物品说明.note.note_TEXT')
    runtime.tip_desc = UIRoot.resolve_ui(y3, player, '背包系统.背包系统.物品说明.descr_LIST.1.descr_TEXT')

    for index = 1, BAR_SLOT_COUNT do
      runtime.slots.bar[index] = {
        slot = UIRoot.resolve_ui(y3, player, resolve_slot_path('bar', index)),
        hover = UIRoot.resolve_ui(y3, player, resolve_hover_path('bar', index)),
      }
    end
    for index = 1, BAG_SLOT_COUNT do
      runtime.slots.bag[index] = {
        slot = UIRoot.resolve_ui(y3, player, resolve_slot_path('bag', index)),
        hover = UIRoot.resolve_ui(y3, player, resolve_hover_path('bag', index)),
      }
    end
    for index = 1, PUBLIC_SLOT_COUNT do
      runtime.slots.public[index] = {
        slot = UIRoot.resolve_ui(y3, player, resolve_slot_path('public', index)),
        hover = UIRoot.resolve_ui(y3, player, resolve_hover_path('public', index)),
      }
    end

    if is_alive(runtime.tip_root) then
      runtime.tip_root:set_anchor(0, 0.5)
      runtime.tip_root:set_visible(false)
      runtime.tip_root:set_intercepts_operations(false)
    end
    if is_alive(runtime.tip_subtitle_icon) then
      runtime.tip_subtitle_icon:set_visible(false)
    end
    if is_alive(runtime.open_button_tip) then
      runtime.open_button_tip:set_text('[B]')
    end

    safe_set_visible(runtime.root, runtime.visible)
    safe_set_visible(runtime.big_panel, runtime.panel_visible and runtime.visible)
    safe_set_visible(runtime.public_root, runtime.visible and runtime.panel_visible)
    safe_set_visible(runtime.public_panel, runtime.visible and runtime.panel_visible and runtime.public_visible)

    return runtime
  end

  local function refresh_public_visibility(panel)
    if not panel then
      return
    end
    local show_root = runtime.visible and runtime.panel_visible
    safe_set_visible(panel.public_root, show_root)
    safe_set_visible(panel.public_panel, show_root and runtime.public_visible)
  end

  local function hide_tooltip()
    runtime.tip_state = nil
    safe_set_visible(runtime.tip_root, false)
  end

  local function build_regular_payload(item, kind, index)
    local subtitle
    if kind == 'bar' then
      subtitle = '物品栏 ' .. tostring(index)
    elseif kind == 'public' then
      subtitle = '公共仓库 ' .. tostring(index)
    else
      subtitle = '背包栏 ' .. tostring(index)
    end
    local subtitle_parts = { subtitle }
    local level = item.get_level and item:get_level() or 0
    if level and level > 0 then
      subtitle_parts[#subtitle_parts + 1] = 'Lv.' .. tostring(level)
    end

    local note_parts = {}
    local stack_type = item.get_stack_type and item:get_stack_type() or 0
    if stack_type == 1 then
      note_parts[#note_parts + 1] = string.format(
        '充能 %d/%d',
        item.get_charge and item:get_charge() or 0,
        math.max(1, item.get_max_charge and item:get_max_charge() or 1)
      )
    elseif stack_type == 2 then
      note_parts[#note_parts + 1] = '堆叠 ' .. tostring(item.get_stack and item:get_stack() or 0)
    end

    local lines = split_lines(item.get_description and item:get_description() or '')
    for _, key in ipairs(item.attr_pick and item:attr_pick() or {}) do
      local value = (item.get_attribute and item:get_attribute(key) or 0) + (item.get_bonus_attribute and item:get_bonus_attribute(key) or 0)
      if math.abs(tonumber(value) or 0) > 0.0001 then
        lines[#lines + 1] = format_attr_line(key, value)
      end
    end

    if #lines == 0 then
      lines[1] = '暂无额外说明'
    end

    return {
      title = trim_text(item.get_name and item:get_name() or '未命名物品'),
      subtitle = table.concat(subtitle_parts, '  '),
      icon = item.get_icon and item:get_icon() or nil,
      note = table.concat(note_parts, '  '),
      body = table.concat(lines, '\n'),
    }
  end

  local function build_payload(kind, index)
    local hero = get_hero()
    if not hero then
      return nil
    end

    local item = get_slot_item(hero, kind, index)
    if not item then
      return nil
    end

    local growth_key = type(get_growth_weapon_item_key) == 'function' and get_growth_weapon_item_key() or nil
    if growth_key and item.get_key and item:get_key() == growth_key and type(build_growth_weapon_tip_payload) == 'function' then
      local payload = build_growth_weapon_tip_payload()
      if payload then
        local body_lines = {}
        for _, line in ipairs(payload.attr_lines or {}) do
          body_lines[#body_lines + 1] = tostring(line)
        end
        for _, line in ipairs(payload.affix_lines or {}) do
          local title = line.title and tostring(line.title) or ''
          local body = line.body and tostring(line.body) or ''
          if title ~= '' and body ~= '' then
            body_lines[#body_lines + 1] = title .. '：' .. body
          elseif body ~= '' then
            body_lines[#body_lines + 1] = body
          end
        end
        return {
          title = payload.title_text or '成长武器',
          subtitle = payload.subtitle_text or '',
          icon = payload.icon_res,
          note = payload.cost_text or '',
          body = #body_lines > 0 and table.concat(body_lines, '\n') or '暂无成长详情',
        }
      end
    end

    return build_regular_payload(item, kind, index)
  end

  local function show_tooltip(kind, index, anchor_ui)
    local panel = ensure_panel()
    if not panel or not is_alive(panel.tip_root) then
      return
    end

    local payload = build_payload(kind, index)
    if not payload then
      hide_tooltip()
      return
    end

    runtime.tip_state = {
      kind = kind,
      index = index,
      anchor = anchor_ui,
    }

    if is_alive(panel.tip_title) then
      panel.tip_title:set_text(payload.title or '')
    end
    if is_alive(panel.tip_subtitle) then
      panel.tip_subtitle:set_text(payload.subtitle or '')
    end
    if is_alive(panel.tip_icon) and payload.icon ~= nil then
      panel.tip_icon:set_image(payload.icon)
    end
    if is_alive(panel.tip_note) then
      panel.tip_note:set_text(payload.note or '')
    end
    if is_alive(panel.tip_desc) then
      panel.tip_desc:set_text(payload.body or '')
    end

    if is_alive(anchor_ui) then
      local anchor_x = anchor_ui:get_absolute_x()
      local anchor_y = anchor_ui:get_absolute_y()
      local offset_x = anchor_x > 1280 and -360 or 56
      panel.tip_root:set_absolute_pos(anchor_x + offset_x, anchor_y + 28)
    end
    panel.tip_root:set_visible(runtime.visible == true)
  end

  local function bind_slot(kind, index, slot_ref)
    local slot_ui = slot_ref and slot_ref.slot or nil
    local hover_ui = slot_ref and slot_ref.hover or nil
    local target = hover_ui and is_alive(hover_ui) and hover_ui or slot_ui
    if not is_alive(target) then
      return
    end

    local bind_key = string.format('%s:%d', kind, index)
    if runtime.bound_targets[bind_key] == target then
      return
    end
    runtime.bound_targets[bind_key] = target

    if kind == 'bar' and index == 1 then
      if is_alive(slot_ui) and slot_ui.set_equip_slot_use_operation then
        slot_ui:set_equip_slot_use_operation('无')
      end
      if is_alive(slot_ui) and slot_ui.set_equip_slot_drag_operation then
        slot_ui:set_equip_slot_drag_operation('无')
      end
    end

    target:add_fast_event('鼠标-移入', function()
      show_tooltip(kind, index, target)
    end)
    target:add_fast_event('鼠标-移出', function()
      hide_tooltip()
    end)
    target:add_fast_event('左键-点击', function()
      hide_tooltip()
      if kind == 'bar' and index == 1 and type(try_upgrade_growth_weapon) == 'function' then
        local hero = get_hero()
        local item = hero and get_slot_item(hero, kind, index) or nil
        local growth_key = type(get_growth_weapon_item_key) == 'function' and get_growth_weapon_item_key() or nil
        if growth_key and item and item.get_key and item:get_key() == growth_key then
          try_upgrade_growth_weapon('inventory_click')
        end
      end
    end)
  end

  local function toggle_public_panel(force_visible)
    local panel = ensure_panel()
    if not panel then
      return nil
    end

    if runtime.panel_visible ~= true then
      runtime.panel_visible = true
      safe_set_visible(panel.big_panel, runtime.visible and runtime.panel_visible)
    end

    if force_visible == nil then
      runtime.public_visible = not runtime.public_visible
    else
      runtime.public_visible = force_visible == true
    end

    refresh_public_visibility(panel)
    if runtime.public_visible ~= true and runtime.tip_state and runtime.tip_state.kind == 'public' then
      hide_tooltip()
    end
    return runtime.public_visible
  end

  local function toggle_panel(force_visible)
    local panel = ensure_panel()
    if not panel then
      return nil
    end

    if force_visible == nil then
      runtime.panel_visible = not runtime.panel_visible
    else
      runtime.panel_visible = force_visible == true
    end

    safe_set_visible(panel.big_panel, runtime.visible and runtime.panel_visible)
    if runtime.panel_visible ~= true then
      runtime.public_visible = false
      hide_tooltip()
    end
    refresh_public_visibility(panel)
    return runtime.panel_visible
  end

  local function refresh_panel()
    local panel = ensure_panel()
    if not panel then
      return nil
    end

    safe_set_visible(panel.root, runtime.visible)
    safe_set_visible(panel.big_panel, runtime.visible and runtime.panel_visible)
    refresh_public_visibility(panel)

    local hero = get_hero()
    if not hero then
      hide_tooltip()
      return panel
    end

    ensure_capacity(hero)

    for index = 1, BAR_SLOT_COUNT do
      local slot_ref = panel.slots.bar[index]
      bind_slot('bar', index, slot_ref)
      if is_alive(slot_ref.slot) and slot_ref.slot.set_ui_unit_slot then
        slot_ref.slot:set_ui_unit_slot(hero, y3.const.SlotType.BAR, index - 1)
      end
    end

    for index = 1, BAG_SLOT_COUNT do
      local slot_ref = panel.slots.bag[index]
      bind_slot('bag', index, slot_ref)
      if is_alive(slot_ref.slot) and slot_ref.slot.set_ui_unit_slot then
        slot_ref.slot:set_ui_unit_slot(hero, y3.const.SlotType.PKG, resolve_bind_index('bag', index))
      end
    end

    for index = 1, PUBLIC_SLOT_COUNT do
      local slot_ref = panel.slots.public[index]
      bind_slot('public', index, slot_ref)
      if is_alive(slot_ref.slot) and slot_ref.slot.set_ui_unit_slot then
        slot_ref.slot:set_ui_unit_slot(hero, y3.const.SlotType.PKG, resolve_bind_index('public', index))
      end
    end

    if runtime.tip_state then
      if runtime.tip_state.kind == 'public' and runtime.public_visible ~= true then
        hide_tooltip()
      else
        show_tooltip(runtime.tip_state.kind, runtime.tip_state.index, runtime.tip_state.anchor)
      end
    end
    return panel
  end

  local function set_visible(visible)
    runtime.visible = visible == true
    local panel = ensure_panel()
    if not panel then
      return nil
    end
    safe_set_visible(panel.root, runtime.visible)
    safe_set_visible(panel.big_panel, runtime.visible and runtime.panel_visible)
    refresh_public_visibility(panel)
    if runtime.visible ~= true then
      hide_tooltip()
    else
      refresh_panel()
    end
    return panel
  end

  local function bind_panel_actions()
    local panel = ensure_panel()
    if not panel then
      return
    end

    if is_alive(panel.open_button) and runtime.bound_targets.open_button ~= panel.open_button then
      runtime.bound_targets.open_button = panel.open_button
      panel.open_button:add_fast_event('左键-点击', function()
        toggle_panel()
      end)
    end

    if is_alive(panel.exit_button) and runtime.bound_targets.exit_button ~= panel.exit_button then
      runtime.bound_targets.exit_button = panel.exit_button
      panel.exit_button:add_fast_event('左键-点击', function()
        toggle_panel(false)
      end)
    end

    if is_alive(panel.public_button) and runtime.bound_targets.public_button ~= panel.public_button then
      runtime.bound_targets.public_button = panel.public_button
      panel.public_button:add_fast_event('左键-点击', function()
        toggle_public_panel()
      end)
    end
  end

  return {
    ensure_panel = function()
      local panel = ensure_panel()
      bind_panel_actions()
      return panel
    end,
    refresh_panel = function()
      bind_panel_actions()
      return refresh_panel()
    end,
    toggle_panel = function(force_visible)
      bind_panel_actions()
      return toggle_panel(force_visible)
    end,
    toggle_public_panel = function(force_visible)
      bind_panel_actions()
      return toggle_public_panel(force_visible)
    end,
    set_visible = function(visible)
      bind_panel_actions()
      return set_visible(visible)
    end,
  }
end

return M
