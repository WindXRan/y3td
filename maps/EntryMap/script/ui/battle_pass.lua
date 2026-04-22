local BattlePass = require 'runtime.battle_pass'
local UIRoot = require 'ui.ui_root'

local M = {}

local PAGE_LOGIN = 'login'
local PAGE_PREMIUM = 'premium'
local PAGE_PASS = 'pass'
local PAGE_ARMORY = 'armory'
local PAGE_SHOP = 'shop'
local PAGE_ACHIEVEMENT = 'achievement'
local PANEL_ROOT_CANDIDATES = { '通行证系统', '存档系统', '局外系统' }
local TOP_TAB_BUTTON_WIDTH = 132
local TOP_TAB_BUTTON_HEIGHT = 42
local TOP_TAB_BUTTON_GAP = 14
local ENABLE_RUNTIME_TOP_NAV = false
local TOP_TAB_DEFS = {
  { page_key = PAGE_PASS, node_name = '按钮', label = '存档', page_field = 'pass_page' },
  { page_key = PAGE_LOGIN, node_name = '按钮_8', label = '登录奖励', page_field = 'login_page' },
  { page_key = PAGE_PREMIUM, node_name = '按钮_9', label = '军令状', page_field = 'premium_page' },
  { page_key = PAGE_ARMORY, node_name = '按钮_10', label = '武库', page_field = 'armory_page' },
  { page_key = PAGE_SHOP, node_name = '按钮_11', label = '商店', page_field = 'shop_page' },
  { page_key = PAGE_ACHIEVEMENT, node_name = '按钮_12', label = '成就', page_field = 'achievement_page' },
}
local PANEL_PATH_ALIASES = {
  ['通行证系统'] = {
    '局外系统.局外系统',
  },
  ['通行证系统.通行证界面'] = {
    '局外系统.局外系统',
  },
  ['通行证系统.按钮区域'] = {
    '局外系统.局外系统.顶部页签',
  },
  ['通行证系统.按钮区域.仓库按钮'] = {
    '局外系统.局外系统.顶部页签.按钮',
  },
  ['通行证系统.按钮区域.仓库按钮.仓库按钮图标'] = {
    '局外系统.局外系统.顶部页签.按钮.文本',
  },
  ['通行证系统.通行证界面.仓库界面关闭按钮'] = {
    '局外系统.局外系统.仓库界面关闭按钮',
  },
  ['通行证系统.通行证界面.左侧区域.登陆奖励'] = {
    '局外系统.局外系统.备用.登陆奖励',
  },
  ['通行证系统.通行证界面.左侧区域.登陆奖励.登录奖励高亮'] = {
    '局外系统.局外系统.备用.登陆奖励.登录奖励高亮',
  },
  ['通行证系统.通行证界面.左侧区域.军令状'] = {
    '局外系统.局外系统.备用.军令状',
  },
  ['通行证系统.通行证界面.左侧区域.军令状.军令状高亮'] = {
    '局外系统.局外系统.备用.军令状.军令状高亮',
  },
  ['通行证系统.通行证界面.左侧区域.征战之路'] = {
    '局外系统.局外系统.顶部页签.按钮',
  },
  ['通行证系统.通行证界面.左侧区域.征战之路.征战之路高亮'] = {
    '局外系统.局外系统.顶部页签.按钮.高亮',
  },
  ['通行证系统.通行证界面.右侧区域.通行证页面'] = {
    '局外系统.局外系统.右侧区域.通行证页面',
  },
  ['通行证系统.通行证界面.右侧区域.通行证页面.标题'] = {
    '局外系统.局外系统.右侧区域.通行证页面.标题',
  },
  ['通行证系统.通行证界面.右侧区域.通行证页面.副标题'] = {
    '局外系统.局外系统.右侧区域.通行证页面.副标题',
  },
  ['通行证系统.通行证界面.右侧区域.通行证页面.当前征战之路经验'] = {
    '局外系统.局外系统.右侧区域.通行证页面.当前征战之路经验',
  },
  ['通行证系统.通行证界面.右侧区域.通行证页面.当前征战之路经验.数字'] = {
    '局外系统.局外系统.右侧区域.通行证页面.当前征战之路经验.数字',
  },
  ['通行证系统.通行证界面.右侧区域.通行证页面.距离下级所需经验'] = {
    '局外系统.局外系统.右侧区域.通行证页面.距离下级所需经验',
  },
  ['通行证系统.通行证界面.右侧区域.通行证页面.距离下级所需经验.数字'] = {
    '局外系统.局外系统.右侧区域.通行证页面.距离下级所需经验.数字',
  },
  ['通行证系统.通行证界面.右侧区域.通行证页面.通行证列表'] = {
    '局外系统.局外系统.右侧区域.通行证页面.通行证列表',
  },
  ['通行证系统.通行证界面.右侧区域.通行证页面.通行证列表.列表背景'] = {
    '局外系统.局外系统.右侧区域.通行证页面.通行证列表.列表背景',
  },
  ['通行证系统.通行证界面.右侧区域.通行证页面.通行证列表.列表背景.通行证进度条'] = {
    '局外系统.局外系统.右侧区域.通行证页面.通行证列表.列表背景.通行证进度条',
  },
  ['通行证系统.通行证界面.右侧区域.通行证页面.通行证列表.列表背景.网格列表'] = {
    '局外系统.局外系统.右侧区域.通行证页面.通行证列表.列表背景.网格列表',
  },
  ['通行证系统.通行证界面.右侧区域.通行证页面.领取按钮'] = {
    '局外系统.局外系统.右侧区域.通行证页面.领取按钮',
  },
  ['通行证系统.通行证界面.右侧区域.通行证页面.通行证Tips'] = {
    '局外系统.局外系统.右侧区域.通行证页面.通行证Tips',
  },
  ['通行证系统.通行证界面.右侧区域.武库页面'] = {
    '局外系统.局外系统.右侧区域.武库',
  },
  ['通行证系统.通行证界面.右侧区域.武库页面.标题'] = {
    '局外系统.局外系统.右侧区域.武库.标题',
  },
  ['通行证系统.通行证界面.右侧区域.武库页面.副标题'] = {
    '局外系统.局外系统.右侧区域.武库.副标题',
  },
  ['通行证系统.通行证界面.右侧区域.商店页面'] = {
    '局外系统.局外系统.右侧区域.商店页面',
  },
  ['通行证系统.通行证界面.右侧区域.商店页面.标题'] = {
    '局外系统.局外系统.右侧区域.商店页面.标题',
  },
  ['通行证系统.通行证界面.右侧区域.商店页面.副标题'] = {
    '局外系统.局外系统.右侧区域.商店页面.副标题',
  },
  ['通行证系统.通行证界面.右侧区域.商店页面.技能碎片.数量数值'] = {
    '局外系统.局外系统.右侧区域.商店页面.技能碎片.数量数值',
  },
  ['通行证系统.通行证界面.右侧区域.成就页面'] = {
    '局外系统.局外系统.右侧区域.成就页面',
  },
  ['通行证系统.通行证界面.右侧区域.成就页面.标题'] = {
    '局外系统.局外系统.右侧区域.成就页面.标题',
  },
  ['通行证系统.通行证界面.右侧区域.成就页面.副标题'] = {
    '局外系统.局外系统.右侧区域.成就页面.副标题',
  },
  ['通行证系统.通行证界面.右侧区域.成就页面.成就积分.数量数值'] = {
    '局外系统.局外系统.右侧区域.成就页面.成就积分.数量数值',
  },
  ['通行证系统.通行证界面.右侧区域.确认购买'] = {
    '局外系统.局外系统.右侧区域.确认购买',
  },
  ['通行证系统.通行证界面.存档数量显示'] = {
    '局外系统.局外系统.存档数量显示',
  },
}
local PASS_TRACK_FREE = 'free'
local PASS_TRACK_PAID = 'paid'
local PASS_LEVEL_CELL_WIDTH = 105
local PASS_LEVEL_CELL_HEIGHT = 105
local PASS_LEVEL_CELL_SPACING = 30
local BIND_FLAG_KEYS = {
  'bound_open_hotspot',
  'bound_open_button',
  'bound_open_icon',
  'bound_close_button',
  'bound_login_tab',
  'bound_premium_tab',
  'bound_pass_tab',
  'bound_claim_button',
  'bound_counter_cycle',
  'bound_debug_paid',
  'bound_debug_add_exp_100',
  'bound_debug_add_exp_500',
  'bound_debug_reset_claims',
  'bound_top_tab_pass',
  'bound_top_tab_login',
  'bound_top_tab_premium',
  'bound_top_tab_armory',
  'bound_top_tab_shop',
  'bound_top_tab_achievement',
  'bound_runtime_top_tab_pass',
  'bound_runtime_top_tab_login',
  'bound_runtime_top_tab_premium',
  'bound_runtime_top_tab_armory',
  'bound_runtime_top_tab_shop',
  'bound_runtime_top_tab_achievement',
}

local function set_visible_if_alive(ui, visible)
  if UIRoot.is_alive(ui) and ui.set_visible then
    ui:set_visible(visible == true)
  end
end

local function set_text_if_alive(ui, text)
  if UIRoot.is_alive(ui) and ui.set_text then
    ui:set_text(text or '')
  end
end

local function set_text_color_if_alive(ui, color)
  if UIRoot.is_alive(ui) and ui.set_text_color and color then
    ui:set_text_color(color[1], color[2], color[3], color[4] or 255)
  end
end

local function set_font_size_if_alive(ui, size)
  if UIRoot.is_alive(ui) and ui.set_font_size and size then
    ui:set_font_size(size)
  end
end

local function set_image_color_if_alive(ui, color)
  if UIRoot.is_alive(ui) and ui.set_image_color and color then
    ui:set_image_color(color[1], color[2], color[3], color[4] or 255)
  end
end

local function set_button_enable_if_alive(ui, enabled)
  if UIRoot.is_alive(ui) and ui.set_button_enable then
    ui:set_button_enable(enabled == true)
  end
end

local function can_bind_fast_event(ui)
  if not UIRoot.is_alive(ui) then
    return false
  end
  local ok, method = pcall(function()
    return ui.add_fast_event
  end)
  return ok and type(method) == 'function'
end

local function set_progress_if_alive(ui, current, max_value)
  if not UIRoot.is_alive(ui) then
    return
  end
  local final_max = math.max(1, tonumber(max_value) or 1)
  local final_current = math.max(0, math.min(tonumber(current) or 0, final_max))
  if ui.set_max_progress_bar_value then
    ui:set_max_progress_bar_value(final_max)
  end
  if ui.set_current_progress_bar_value then
    ui:set_current_progress_bar_value(final_current, 0)
  end
end

function M.create(env)
  local STATE = env.STATE
  local y3 = env.y3
  local message = env.message
  local get_player = env.get_player
  local get_profile = env.get_profile
  local mark_profile_dirty = env.mark_profile_dirty
  local rebuild_hero_attr_bonus_stats = env.rebuild_hero_attr_bonus_stats
  local play_ui_click = env.play_ui_click
  local get_nav_host = env.get_nav_host

  local outgame_panel = nil

  local runtime = {
    ui = nil,
    panel_open = false,
    current_page = PAGE_PASS,
    ui_warned = false,
    markers = {},
    markers_count = 0,
    pass_grid_owned = false,
  }
  local api = {}

  local debug_mode = y3
    and y3.game
    and y3.game.is_debug_mode
    and y3.game.is_debug_mode()
    or false

  local function resolve_ui(path)
    return UIRoot.resolve_ui(y3, get_player(), path)
  end

  local function resolve_panel_ui(path)
    for _, alias in ipairs(PANEL_PATH_ALIASES[tostring(path or '')] or {}) do
      local ui = resolve_ui(alias)
      if ui then
        return ui
      end
    end
    for _, root_name in ipairs(PANEL_ROOT_CANDIDATES) do
      local candidate = tostring(path or ''):gsub('^通行证系统', root_name, 1)
      local ui = resolve_ui(candidate)
      if ui then
        return ui
      end
    end
    return nil
  end

  local function play_click()
    if play_ui_click then
      play_ui_click()
    end
  end

  local function is_panel_session_available()
    return STATE.session_phase == 'outgame' or STATE.session_phase == 'battle'
  end

  local function get_ui()
    return runtime.ui
  end

  local function ensure_open_hotspot(ui)
    if not ui or not UIRoot.is_alive(ui.button_area) then
      return nil
    end
    if UIRoot.is_alive(ui.open_button) and ui.open_button ~= ui.button_area then
      return nil
    end
    if can_bind_fast_event(runtime.open_hotspot) then
      return runtime.open_hotspot
    end
    if not ui.button_area.create_child then
      return nil
    end

    local ok, hotspot = pcall(ui.button_area.create_child, ui.button_area, '图片')
    if not ok or not hotspot then
      return nil
    end

    local width = math.max(1, math.floor((ui.button_area.get_width and ui.button_area:get_width() or 200) + 0.5))
    local height = math.max(1, math.floor((ui.button_area.get_height and ui.button_area:get_height() or 100) + 0.5))

    if hotspot.set_image then
      hotspot:set_image(999)
    end
    if hotspot.set_anchor then
      hotspot:set_anchor(0.5, 0.5)
    end
    if hotspot.set_pos then
      hotspot:set_pos(width * 0.5, height * 0.5)
    end
    if hotspot.set_ui_size then
      hotspot:set_ui_size(width, height)
    end
    if hotspot.set_intercepts_operations then
      hotspot:set_intercepts_operations(true)
    end
    set_image_color_if_alive(hotspot, { 255, 255, 255, 0 })

    runtime.open_hotspot = hotspot
    return hotspot
  end

  local function ensure_save_count_label(ui)
    if not ui or not UIRoot.is_alive(ui.save_count) then
      return nil
    end
    if UIRoot.is_alive(ui.save_count_label) then
      return ui.save_count_label
    end

    local ok, method = pcall(function()
      return ui.save_count.set_text
    end)
    if ok and type(method) == 'function' then
      ui.save_count_label = ui.save_count
      return ui.save_count_label
    end
    if not ui.save_count.create_child then
      return ui.save_count
    end

    local ok_create, label = pcall(ui.save_count.create_child, ui.save_count, '文本')
    if not ok_create or not label then
      return ui.save_count
    end

    local width = math.max(1, math.floor((ui.save_count.get_width and ui.save_count:get_width() or 676) + 0.5))
    local height = math.max(1, math.floor((ui.save_count.get_height and ui.save_count:get_height() or 100) + 0.5))

    if label.set_anchor then
      label:set_anchor(0.5, 0.5)
    end
    if label.set_pos then
      label:set_pos(width * 0.5, height * 0.5)
    end
    if label.set_ui_size then
      label:set_ui_size(math.max(260, width - 24), math.max(30, height - 16))
    end
    if label.set_font_size then
      label:set_font_size(16)
    end
    if label.set_text_alignment then
      label:set_text_alignment('中', '中')
    end
    if label.set_text_color then
      label:set_text_color(233, 236, 244, 255)
    end
    if label.set_intercepts_operations then
      label:set_intercepts_operations(false)
    end

    ui.save_count_label = label
    return label
  end

  local function refresh_open_entry_label(ui)
    if not ui then
      return
    end
    set_text_if_alive(ui.open_button, '存档')
    set_text_if_alive(ui.open_icon, '存档')
  end

  local function ensure_runtime_top_nav(ui)
    if ENABLE_RUNTIME_TOP_NAV ~= true then
      return nil
    end
    local host = get_nav_host and get_nav_host() or nil
    if not UIRoot.is_alive(host) and STATE.session_phase == 'battle' then
      host = UIRoot.get_overlay_parent(y3, get_player())
    end
    if not UIRoot.is_alive(host) and outgame_panel and outgame_panel.get_battle_pass_nav_host then
      host = outgame_panel.get_battle_pass_nav_host()
    end
    host = UIRoot.is_alive(host) and host or ui and ui.root or nil
    if not UIRoot.is_alive(host) or not host.create_child then
      return nil
    end
    if ui.runtime_top_nav and UIRoot.is_alive(ui.runtime_top_nav.root) and ui.runtime_top_nav.host == host then
      return ui.runtime_top_nav
    end

    if ui.runtime_top_nav and UIRoot.is_alive(ui.runtime_top_nav.root) and ui.runtime_top_nav.root.remove then
      ui.runtime_top_nav.root:remove()
      ui.runtime_top_nav = nil
    end

    local ok_root, nav_root = pcall(host.create_child, host, '图片')
    if not ok_root or not nav_root then
      return nil
    end

    if nav_root.set_image then
      nav_root:set_image(999)
    end
    if nav_root.set_image_color then
      nav_root:set_image_color(255, 255, 255, 0)
    end
    if nav_root.set_anchor then
      nav_root:set_anchor(0.5, 0.5)
    end
    if nav_root.set_z_order then
      nav_root:set_z_order(60)
    end
    if nav_root.set_intercepts_operations then
      nav_root:set_intercepts_operations(false)
    end

    local buttons = {}
    for _, def in ipairs(TOP_TAB_DEFS) do
      local ok_button, button = pcall(nav_root.create_child, nav_root, '按钮')
      if ok_button and button then
        if button.set_ui_size then
          button:set_ui_size(TOP_TAB_BUTTON_WIDTH, TOP_TAB_BUTTON_HEIGHT)
        end
        if button.set_font_size then
          button:set_font_size(18)
        end
        if button.set_text_color then
          button:set_text_color(235, 240, 248, 255)
        end
        if button.set_z_order then
          button:set_z_order(61)
        end
        buttons[#buttons + 1] = {
          page_key = def.page_key,
          label = def.label,
          page_field = def.page_field,
          button = button,
        }
      end
    end

    ui.runtime_top_nav = {
      host = host,
      root = nav_root,
      buttons = buttons,
    }
    return ui.runtime_top_nav
  end

  local function layout_runtime_top_nav(ui)
    local nav = ensure_runtime_top_nav(ui)
    if not nav or not UIRoot.is_alive(nav.root) then
      return
    end

    local enabled_buttons = {}
    for _, tab in ipairs(nav.buttons or {}) do
      if tab.enabled ~= false then
        enabled_buttons[#enabled_buttons + 1] = tab
      end
    end

    local count = #enabled_buttons
    local width = math.max(1, count * TOP_TAB_BUTTON_WIDTH + math.max(0, count - 1) * TOP_TAB_BUTTON_GAP)
    local height = TOP_TAB_BUTTON_HEIGHT
    local host = nav.host
    local root_width = UIRoot.is_alive(host) and host.get_width and host:get_width() or 1600
    local root_height = UIRoot.is_alive(ui.root) and ui.root.get_height and ui.root:get_height() or 900
    if UIRoot.is_alive(host) and host.get_height then
      root_height = host:get_height() or root_height
    end

    if nav.root.set_ui_size then
      nav.root:set_ui_size(width, height)
    end
    if nav.root.set_pos then
      local pos_x = math.max((width * 0.5) + 24, 110)
      local pos_y = root_height - 40
      nav.root:set_pos(pos_x, pos_y)
    end

    local start_x = TOP_TAB_BUTTON_WIDTH * 0.5
    for index, tab in ipairs(enabled_buttons) do
      if UIRoot.is_alive(tab.button) and tab.button.set_pos then
        tab.button:set_pos(start_x + (index - 1) * (TOP_TAB_BUTTON_WIDTH + TOP_TAB_BUTTON_GAP), height * 0.5)
      end
    end
  end

  local function refresh_top_tabs(ui)
    if not ui then
      return
    end

    for _, tab in ipairs(ui.top_tabs or {}) do
      local enabled = tab.enabled ~= false
      local selected = runtime.current_page == tab.page_key
      set_visible_if_alive(tab.button, false)
      set_visible_if_alive(tab.highlight, false)
      if enabled then
        set_text_if_alive(tab.button, tab.label)
        set_text_if_alive(tab.text, tab.label)
      end
    end

    for _, extra in ipairs(ui.top_tabs_extra or {}) do
      set_visible_if_alive(extra, false)
    end

    local nav = ensure_runtime_top_nav(ui)
    if nav then
      for _, tab in ipairs(nav.buttons or {}) do
        local enabled = tab.enabled ~= false
        local selected = runtime.current_page == tab.page_key
        set_visible_if_alive(tab.button, enabled)
        if enabled then
          set_text_if_alive(tab.button, tab.label)
          set_button_enable_if_alive(tab.button, true)
          set_image_color_if_alive(
            tab.button,
            selected and { 84, 138, 226, 255 } or { 40, 58, 92, 236 }
          )
          set_text_color_if_alive(
            tab.button,
            selected and { 245, 248, 255, 255 } or { 220, 232, 246, 255 }
          )
        end
      end
      layout_runtime_top_nav(ui)
    end
  end

  local function reset_bind_flags()
    for _, key in ipairs(BIND_FLAG_KEYS) do
      runtime[key] = false
    end
  end

  local function clear_markers()
    for _, marker in ipairs(runtime.markers) do
      local entries = { marker.level_marker, marker.free_cell, marker.paid_cell }
      for _, entry in ipairs(entries) do
        if entry and entry.prefab and entry.prefab.remove then
          entry.prefab:remove()
        end
      end
    end
    runtime.markers = {}
    runtime.markers_count = 0
  end

  local function prepare_pass_grid_for_lua(ui)
    if not UIRoot.is_alive(ui and ui.pass_grid) or not ui.pass_grid.get_childs then
      return
    end
    if runtime.pass_grid_owned then
      return
    end

    local ok, children = pcall(ui.pass_grid.get_childs, ui.pass_grid)
    if not ok or type(children) ~= 'table' then
      return
    end

    clear_markers()
    for _, child in ipairs(children) do
      if UIRoot.is_alive(child) and child.remove then
        child:remove()
      end
    end

    runtime.pass_grid_owned = true
  end

  local function is_pass_grid_marker_alive(marker)
    if type(marker) ~= 'table' then
      return false
    end
    local entries = { marker.level_marker, marker.free_cell, marker.paid_cell }
    for _, entry in ipairs(entries) do
      if not entry or not UIRoot.is_alive(entry.root) then
        return false
      end
    end
    return true
  end

  local function has_valid_pass_grid_markers(expected_count)
    if runtime.markers_count ~= expected_count then
      return false
    end
    for _, marker in ipairs(runtime.markers) do
      if not is_pass_grid_marker_alive(marker) then
        return false
      end
    end
    return true
  end

  local function ensure_pass_grid_markers(ui, level_items)
    local expected_count = #(level_items or {})
    if has_valid_pass_grid_markers(expected_count) then
      return
    end

    clear_markers()
    for _, item in ipairs(level_items or {}) do
      local level_marker = create_level_marker(ui.pass_grid)
      local free_cell = create_reward_cell(ui.pass_grid)
      local paid_cell = create_reward_cell(ui.pass_grid)
      if level_marker and free_cell and paid_cell then
        runtime.markers[#runtime.markers + 1] = {
          level = tonumber(item.level) or 0,
          level_marker = level_marker,
          free_cell = free_cell,
          paid_cell = paid_cell,
        }
      else
        local cleanup_entries = { level_marker, free_cell, paid_cell }
        for _, entry in ipairs(cleanup_entries) do
          if entry and entry.prefab and entry.prefab.remove then
            entry.prefab:remove()
          end
        end
      end
    end

    runtime.markers_count = #runtime.markers
  end

  local function create_level_marker(parent)
    local ok, prefab = pcall(y3.ui_prefab.create, get_player(), '通行证第几级', parent)
    if not ok or not prefab then
      return nil
    end

    local root = prefab:get_child()
    local text = prefab:get_child('文本')
    if not root or not text then
      if prefab.remove then
        prefab:remove()
      end
      return nil
    end

    root:set_anchor(0.5, 0.5)
    root:set_pos(PASS_LEVEL_CELL_WIDTH * 0.5, PASS_LEVEL_CELL_HEIGHT * 0.5)
    root:set_ui_size(PASS_LEVEL_CELL_WIDTH, PASS_LEVEL_CELL_HEIGHT)
    text:set_ui_size(PASS_LEVEL_CELL_WIDTH - 8, 42)
    text:set_anchor(0.5, 0.5)
    text:set_pos(PASS_LEVEL_CELL_WIDTH * 0.5, PASS_LEVEL_CELL_HEIGHT * 0.5)
    text:set_font_size(16)
    text:set_text_alignment('中', '中')
    text:set_text('Lv.01')

    return {
      prefab = prefab,
      root = root,
      text = text,
    }
  end

  local function create_reward_cell(parent)
    local ok, prefab = pcall(y3.ui_prefab.create, get_player(), '商品图标', parent)
    if not ok or not prefab then
      return nil
    end

    local root = prefab:get_child()
    local frame = prefab:get_child('卡框')
    local claimed_text = prefab:get_child('已领取遮罩.文本')
    local claimed_mask = prefab:get_child('已领取遮罩')
    local claimable_frame = prefab:get_child('可领取框')
    local lock_mask = prefab:get_child('遮罩')
    local lock_icon = prefab:get_child('遮罩.锁定')
    local icon = prefab:get_child('图标')
    local card_clip = prefab:get_child('卡图裁剪')
    local quantity_bg = prefab:get_child('数量背景')
    local skill_icon = prefab:get_child('技能图标')
    local selected = prefab:get_child('选中框')
    local text

    if root and root.create_child then
      local ok_text, label = pcall(root.create_child, root, '文本')
      if ok_text then
        text = label
      end
    end

    if not root or not frame or not text then
      if prefab.remove then
        prefab:remove()
      end
      return nil
    end

    root:set_anchor(0.5, 0.5)
    root:set_pos(PASS_LEVEL_CELL_WIDTH * 0.5, PASS_LEVEL_CELL_HEIGHT * 0.5)
    root:set_ui_size(PASS_LEVEL_CELL_WIDTH, PASS_LEVEL_CELL_HEIGHT)
    frame:set_ui_size(110, 110)
    text:set_anchor(0.5, 0.5)
    text:set_pos(PASS_LEVEL_CELL_WIDTH * 0.5, PASS_LEVEL_CELL_HEIGHT * 0.5)
    text:set_ui_size(PASS_LEVEL_CELL_WIDTH - 16, PASS_LEVEL_CELL_HEIGHT - 16)
    text:set_text_alignment('中', '中')
    text:set_font_size(13)
    if text.set_intercepts_operations then
      text:set_intercepts_operations(false)
    end
    if claimed_text then
      claimed_text:set_text('已领')
      claimed_text:set_font_size(18)
      claimed_text:set_text_alignment('中', '中')
    end

    set_visible_if_alive(icon, false)
    set_visible_if_alive(card_clip, false)
    set_visible_if_alive(quantity_bg, false)
    set_visible_if_alive(skill_icon, false)
    set_visible_if_alive(selected, false)
    set_visible_if_alive(claimed_mask, false)
    set_visible_if_alive(claimable_frame, false)
    set_visible_if_alive(lock_mask, false)

    return {
      prefab = prefab,
      root = root,
      frame = frame,
      text = text,
      claimed_mask = claimed_mask,
      claimable_frame = claimable_frame,
      lock_mask = lock_mask,
      lock_icon = lock_icon,
    }
  end

  local function get_reward_cell_label(item, track, compact_mode)
    if not item then
      return ''
    end

    local short_label = track == PASS_TRACK_PAID and item.paid_short_label or item.free_short_label
    local full_label = track == PASS_TRACK_PAID and item.paid_label or item.free_label
    local title = track == PASS_TRACK_PAID and '付费' or '免费'
    local label = compact_mode and short_label or full_label
    label = tostring(label or short_label or full_label or '无')
    return string.format('%s\n%s', title, label)
  end

  local function get_reward_frame_color(track, status)
    if status == 'claimed' then
      return { 178, 178, 178, 255 }
    end
    if status == 'locked' or status == 'premium_locked' then
      return { 144, 144, 144, 255 }
    end
    if track == PASS_TRACK_PAID then
      return { 255, 222, 138, 255 }
    end
    return { 173, 214, 255, 255 }
  end

  local function get_reward_text_color(track, status)
    if status == 'claimed' then
      return { 222, 222, 222, 255 }
    end
    if status == 'locked' or status == 'premium_locked' then
      return { 196, 196, 196, 255 }
    end
    if track == PASS_TRACK_PAID then
      return { 255, 243, 205, 255 }
    end
    return { 232, 241, 255, 255 }
  end

  local function update_reward_cell(cell, item, track, compact_mode)
    if not cell or not item then
      return
    end

    local status = track == PASS_TRACK_PAID and item.paid_status or item.free_status
    set_visible_if_alive(cell.root, true)
    set_text_if_alive(cell.text, get_reward_cell_label(item, track, compact_mode))
    set_font_size_if_alive(cell.text, compact_mode and 12 or 13)
    set_text_color_if_alive(cell.text, get_reward_text_color(track, status))
    set_image_color_if_alive(cell.frame, get_reward_frame_color(track, status))
    set_visible_if_alive(cell.claimable_frame, status == 'claimable')
    set_visible_if_alive(cell.claimed_mask, status == 'claimed')
    set_visible_if_alive(cell.lock_mask, status == 'locked' or status == 'premium_locked')
    set_visible_if_alive(cell.lock_icon, status == 'premium_locked')
  end

  local function update_pass_grid(ui, model, compact_mode)
    local level_items = model.level_items or {}
    ensure_pass_grid_markers(ui, level_items)

    for index, marker in ipairs(runtime.markers) do
      local item = level_items[index]
      local visible = item ~= nil
      if marker.level_marker then
        set_visible_if_alive(marker.level_marker.root, visible)
      end
      if marker.free_cell then
        set_visible_if_alive(marker.free_cell.root, visible)
      end
      if marker.paid_cell then
        set_visible_if_alive(marker.paid_cell.root, visible)
      end
      if item then
        set_text_if_alive(marker.level_marker.text, string.format('Lv.%02d', tonumber(item.level) or 0))
        set_text_color_if_alive(marker.level_marker.text, item.cell_color)
        update_reward_cell(marker.free_cell, item, PASS_TRACK_FREE, compact_mode)
        update_reward_cell(marker.paid_cell, item, PASS_TRACK_PAID, compact_mode)
      end
    end
  end

  local function is_battle_compact_mode()
    return STATE.session_phase == 'battle'
  end

  local function get_compact_pass_subtitle(model)
    local exp_to_next_text = model.reached_max and '已满级' or tostring(model.exp_to_next)
    return string.format(
      '当前 Lv.%d/%d · 经验 %d · 下级 %s',
      tonumber(model.current_level) or 1,
      tonumber(model.max_level) or 1,
      tonumber(model.total_exp) or 0,
      exp_to_next_text
    )
  end

  local function get_compact_pass_tips(model)
    return string.format(
      '免费可领 %d · 付费可领 %d · 激活「%s」后可同步领取付费轨道',
      tonumber(model.free_claimable_count) or 0,
      tonumber(model.paid_claimable_count) or 0,
      tostring(model.premium_name or '至尊征战之路')
    )
  end

  local function get_pass_list_visible_columns(ui)
    local list_width = 950
    if UIRoot.is_alive(ui and ui.pass_list) and ui.pass_list.get_width then
      list_width = math.max(PASS_LEVEL_CELL_WIDTH, ui.pass_list:get_width() or list_width)
    end

    local stride = PASS_LEVEL_CELL_WIDTH + PASS_LEVEL_CELL_SPACING
    return math.max(1, math.floor((list_width + PASS_LEVEL_CELL_SPACING) / stride))
  end

  local function get_pass_list_percent(ui, model, compact_mode)
    if compact_mode or not model then
      return 0
    end

    local max_level = math.max(1, tonumber(model.max_level) or 1)
    if max_level <= 1 then
      return 0
    end

    local current_level = math.max(1, math.min(max_level, tonumber(model.current_level) or 1))
    local visible_columns = get_pass_list_visible_columns(ui)
    local scrollable_columns = math.max(0, max_level - visible_columns)
    if scrollable_columns <= 0 then
      return 0
    end

    local first_visible_level = math.max(1, current_level - visible_columns + 1)
    return math.max(0, math.min(((first_visible_level - 1) / scrollable_columns) * 100, 100))
  end

  local function set_root_visible(visible)
    local ui = get_ui()
    if not ui then
      return
    end
    set_visible_if_alive(ui.root, visible)
    set_visible_if_alive(ui.button_area, visible)
    set_visible_if_alive(ui.panel_root, visible and runtime.panel_open == true)
    if visible and runtime.panel_open == true then
      set_visible_if_alive(ui.activity_panel_root, false)
    end
    set_visible_if_alive(ui.item_tip_root, false)
    set_visible_if_alive(ui.obtain_root, false)
  end

  local function hide_all_right_pages(ui)
    set_visible_if_alive(ui.login_page, false)
    set_visible_if_alive(ui.premium_page, false)
    set_visible_if_alive(ui.pass_page, false)
    set_visible_if_alive(ui.armory_page, false)
    set_visible_if_alive(ui.shop_page, false)
    set_visible_if_alive(ui.achievement_page, false)
    set_visible_if_alive(ui.confirm_purchase, false)
  end

  local function refresh_page_switch(ui)
    hide_all_right_pages(ui)

    local login_selected = runtime.current_page == PAGE_LOGIN
    local premium_selected = runtime.current_page == PAGE_PREMIUM
    local pass_selected = runtime.current_page == PAGE_PASS
    local armory_selected = runtime.current_page == PAGE_ARMORY
    local shop_selected = runtime.current_page == PAGE_SHOP
    local achievement_selected = runtime.current_page == PAGE_ACHIEVEMENT

    set_visible_if_alive(ui.login_highlight, login_selected)
    set_visible_if_alive(ui.premium_highlight, premium_selected)
    set_visible_if_alive(ui.pass_highlight, pass_selected)
    refresh_top_tabs(ui)

    if login_selected then
      set_visible_if_alive(ui.login_page, true)
    elseif premium_selected then
      set_visible_if_alive(ui.premium_page, true)
    elseif armory_selected then
      set_visible_if_alive(ui.armory_page, true)
    elseif shop_selected then
      set_visible_if_alive(ui.shop_page, true)
    elseif achievement_selected then
      set_visible_if_alive(ui.achievement_page, true)
    else
      set_visible_if_alive(ui.pass_page, true)
    end

    set_visible_if_alive(ui.claim_button, pass_selected)
  end

  local function open_panel(page_key)
    runtime.panel_open = true
    runtime.current_page = page_key or runtime.current_page or PAGE_PASS
    local ui = get_ui()
    if ui then
      set_visible_if_alive(ui.activity_panel_root, false)
      set_visible_if_alive(ui.panel_root, true)
    end
  end

  local function close_panel()
    runtime.panel_open = false
    local ui = get_ui()
    if ui then
      set_visible_if_alive(ui.panel_root, false)
    end
  end

  local function commit_profile(profile)
    if rebuild_hero_attr_bonus_stats then
      rebuild_hero_attr_bonus_stats(profile)
    end
    if mark_profile_dirty then
      mark_profile_dirty()
    end
  end

  local function apply_daily_profile_refresh(profile)
    if not profile then
      return nil
    end
    local summary = BattlePass.refresh_daily_state(profile)
    if summary and summary.dirty then
      commit_profile(profile)
    end
    local text = BattlePass.build_daily_refresh_message(summary)
    if text and text ~= '' then
      message(text)
    end
    return summary
  end

  local function cycle_showcase_page()
    local sequence = {
      PAGE_PASS,
      PAGE_LOGIN,
      PAGE_PREMIUM,
      PAGE_ARMORY,
      PAGE_SHOP,
      PAGE_ACHIEVEMENT,
    }
    local current = runtime.current_page or PAGE_PASS
    local index = 1
    for candidate_index, page in ipairs(sequence) do
      if page == current then
        index = candidate_index
        break
      end
    end
    local next_index = index + 1
    if next_index > #sequence then
      next_index = 1
    end
    open_panel(sequence[next_index])
  end

  local function handle_claim_click()
    local profile = get_profile and get_profile() or nil
    if not profile then
      return
    end
    local summary = BattlePass.claim_available(profile)
    if (summary.claimed_count or 0) > 0 then
      commit_profile(profile)
    end
    message(BattlePass.build_claim_message(summary))
  end

  local function handle_toggle_paid()
    local profile = get_profile and get_profile() or nil
    if not profile then
      return
    end
    BattlePass.ensure_profile_defaults(profile)
    local new_value = not (profile.battle_pass and profile.battle_pass.paid_unlocked == true)
    if BattlePass.set_paid_unlocked(profile, new_value) then
      commit_profile(profile)
    end
    if new_value then
      message('已激活至尊征战之路（调试开关）。')
    else
      message('已关闭至尊征战之路（调试开关）。')
    end
  end

  local function handle_add_exp(amount)
    local profile = get_profile and get_profile() or nil
    if not profile then
      return
    end
    local summary = BattlePass.add_exp(profile, amount, 'debug')
    if (summary.added_exp or 0) > 0 and mark_profile_dirty then
      mark_profile_dirty()
    end
    message(BattlePass.build_gain_message(summary))
  end

  local function handle_reset_claims()
    local profile = get_profile and get_profile() or nil
    if not profile then
      return
    end
    local cleared = BattlePass.reset_claims(profile)
    commit_profile(profile)
    message(string.format('已重置征战之路领取状态，本次共清空 %d 条记录。', cleared))
  end

  local function bind_click_once(ui_node, callback, field_name)
    if runtime[field_name] == true or not can_bind_fast_event(ui_node) then
      return
    end
    runtime[field_name] = true
    ui_node:add_fast_event('左键-点击', function()
      play_click()
      callback()
      local panel = get_ui()
      if panel then
        refresh_page_switch(panel)
      end
      if is_panel_session_available() then
        api.refresh_ui()
      end
    end)
  end

  local function ensure_ui()
    local ui = get_ui()
    if ui
      and UIRoot.is_alive(ui.root)
      and UIRoot.is_alive(ui.panel_root)
      and UIRoot.is_alive(ui.open_button)
      and UIRoot.is_alive(ui.pass_grid)
    then
      return ui
    end

    clear_markers()
    reset_bind_flags()
    runtime.pass_grid_owned = false

    local root = resolve_panel_ui('通行证系统')
    local panel_root = resolve_panel_ui('通行证系统.通行证界面')
    local button_area = resolve_panel_ui('通行证系统.按钮区域')
    local open_button = resolve_panel_ui('通行证系统.按钮区域.仓库按钮')
    local open_icon = resolve_panel_ui('通行证系统.按钮区域.仓库按钮.仓库按钮图标')
    local activity_panel_root = resolve_ui('签到系统.活动')
    local close_button = resolve_panel_ui('通行证系统.通行证界面.仓库界面关闭按钮')
    local item_tip_root = resolve_panel_ui('通行证系统.物品描述')
    local obtain_root = resolve_panel_ui('通行证系统.获得道具底板')

    local login_tab = resolve_panel_ui('通行证系统.通行证界面.左侧区域.登陆奖励')
    local login_highlight = resolve_panel_ui('通行证系统.通行证界面.左侧区域.登陆奖励.登录奖励高亮')
    local premium_tab = resolve_panel_ui('通行证系统.通行证界面.左侧区域.军令状')
    local premium_highlight = resolve_panel_ui('通行证系统.通行证界面.左侧区域.军令状.军令状高亮')
    local pass_tab = resolve_panel_ui('通行证系统.通行证界面.左侧区域.征战之路')
    local pass_highlight = resolve_panel_ui('通行证系统.通行证界面.左侧区域.征战之路.征战之路高亮')

    local login_page = resolve_panel_ui('通行证系统.通行证界面.右侧区域.登陆奖励页面')
    local login_title = resolve_panel_ui('通行证系统.通行证界面.右侧区域.登陆奖励页面.标题')
    local login_subtitle = resolve_panel_ui('通行证系统.通行证界面.右侧区域.登陆奖励页面.副标题')

    local premium_page = resolve_panel_ui('通行证系统.通行证界面.右侧区域.军令状页面')
    local premium_title = resolve_panel_ui('通行证系统.通行证界面.右侧区域.军令状页面.标题')
    local premium_subtitle = resolve_panel_ui('通行证系统.通行证界面.右侧区域.军令状页面.副标题')
    local premium_desc = resolve_panel_ui('通行证系统.通行证界面.右侧区域.军令状页面.介绍文本')

    local pass_page = resolve_panel_ui('通行证系统.通行证界面.右侧区域.通行证页面')
    local pass_title = resolve_panel_ui('通行证系统.通行证界面.右侧区域.通行证页面.标题')
    local pass_subtitle = resolve_panel_ui('通行证系统.通行证界面.右侧区域.通行证页面.副标题')
    local current_exp_group = resolve_panel_ui('通行证系统.通行证界面.右侧区域.通行证页面.当前征战之路经验')
    local current_exp_value = resolve_panel_ui('通行证系统.通行证界面.右侧区域.通行证页面.当前征战之路经验.数字')
    local exp_to_next_group = resolve_panel_ui('通行证系统.通行证界面.右侧区域.通行证页面.距离下级所需经验')
    local exp_to_next_value = resolve_panel_ui('通行证系统.通行证界面.右侧区域.通行证页面.距离下级所需经验.数字')
    local pass_list = resolve_panel_ui('通行证系统.通行证界面.右侧区域.通行证页面.通行证列表')
    local pass_list_bg = resolve_panel_ui('通行证系统.通行证界面.右侧区域.通行证页面.通行证列表.列表背景')
    local pass_progress_bar = resolve_panel_ui('通行证系统.通行证界面.右侧区域.通行证页面.通行证列表.列表背景.通行证进度条')
    local pass_grid = resolve_panel_ui('通行证系统.通行证界面.右侧区域.通行证页面.通行证列表.列表背景.网格列表')
    local claim_button = resolve_panel_ui('通行证系统.通行证界面.右侧区域.通行证页面.领取按钮')
    local pass_tips = resolve_panel_ui('通行证系统.通行证界面.右侧区域.通行证页面.通行证Tips')

    local armory_page = resolve_panel_ui('通行证系统.通行证界面.右侧区域.武库页面')
    local armory_title = resolve_panel_ui('通行证系统.通行证界面.右侧区域.武库页面.标题')
    local armory_subtitle = resolve_panel_ui('通行证系统.通行证界面.右侧区域.武库页面.副标题')
    local shop_page = resolve_panel_ui('通行证系统.通行证界面.右侧区域.商店页面')
    local shop_title = resolve_panel_ui('通行证系统.通行证界面.右侧区域.商店页面.标题')
    local shop_subtitle = resolve_panel_ui('通行证系统.通行证界面.右侧区域.商店页面.副标题')
    local shop_skill_fragments = resolve_panel_ui('通行证系统.通行证界面.右侧区域.商店页面.技能碎片.数量数值')
    local achievement_page = resolve_panel_ui('通行证系统.通行证界面.右侧区域.成就页面')
    local achievement_title = resolve_panel_ui('通行证系统.通行证界面.右侧区域.成就页面.标题')
    local achievement_subtitle = resolve_panel_ui('通行证系统.通行证界面.右侧区域.成就页面.副标题')
    local achievement_points_value = resolve_panel_ui('通行证系统.通行证界面.右侧区域.成就页面.成就积分.数量数值')
    local confirm_purchase = resolve_panel_ui('通行证系统.通行证界面.右侧区域.确认购买')
    local save_count = resolve_panel_ui('通行证系统.通行证界面.存档数量显示')

    local debug_root = resolve_panel_ui('通行证系统.通行证界面.测试按钮')
    local debug_paid = resolve_panel_ui('通行证系统.通行证界面.测试按钮.付费开关')
    local debug_add_exp_100 = resolve_panel_ui('通行证系统.通行证界面.测试按钮.加经验100')
    local debug_add_exp_500 = resolve_panel_ui('通行证系统.通行证界面.测试按钮.加经验500')
    local debug_reset_claims = resolve_panel_ui('通行证系统.通行证界面.测试按钮.重置领取状态')
    local top_tabs = {}
    for _, def in ipairs(TOP_TAB_DEFS) do
      top_tabs[#top_tabs + 1] = {
        page_key = def.page_key,
        label = def.label,
        page_field = def.page_field,
        button = resolve_ui('局外系统.局外系统.顶部页签.' .. def.node_name),
        highlight = resolve_ui('局外系统.局外系统.顶部页签.' .. def.node_name .. '.高亮'),
        text = resolve_ui('局外系统.局外系统.顶部页签.' .. def.node_name .. '.文本'),
        enabled = true,
      }
    end
    local top_tabs_extra = {
      resolve_ui('局外系统.局外系统.顶部页签.按钮_13'),
      resolve_ui('局外系统.局外系统.顶部页签.按钮_14'),
    }

    if not root or not panel_root or not open_button or not close_button or not pass_grid then
      if not runtime.ui_warned then
        runtime.ui_warned = true
        message('未找到存档/通行证系统画板节点，请确认 maps/EntryMap/ui/通行证系统.json 或 存档系统.json 已加载。')
      end
      runtime.ui = nil
      return nil
    end

    runtime.ui = {
      root = root,
      panel_root = panel_root,
      button_area = button_area,
      open_button = open_button,
      open_icon = open_icon,
      activity_panel_root = activity_panel_root,
      close_button = close_button,
      item_tip_root = item_tip_root,
      obtain_root = obtain_root,
      login_tab = login_tab,
      login_highlight = login_highlight,
      premium_tab = premium_tab,
      premium_highlight = premium_highlight,
      pass_tab = pass_tab,
      pass_highlight = pass_highlight,
      login_page = login_page,
      login_title = login_title,
      login_subtitle = login_subtitle,
      premium_page = premium_page,
      premium_title = premium_title,
      premium_subtitle = premium_subtitle,
      premium_desc = premium_desc,
      pass_page = pass_page,
      pass_title = pass_title,
      pass_subtitle = pass_subtitle,
      current_exp_group = current_exp_group,
      current_exp_value = current_exp_value,
      exp_to_next_group = exp_to_next_group,
      exp_to_next_value = exp_to_next_value,
      pass_list = pass_list,
      pass_list_bg = pass_list_bg,
      pass_progress_bar = pass_progress_bar,
      pass_grid = pass_grid,
      claim_button = claim_button,
      pass_tips = pass_tips,
      armory_page = armory_page,
      armory_title = armory_title,
      armory_subtitle = armory_subtitle,
      shop_page = shop_page,
      shop_title = shop_title,
      shop_subtitle = shop_subtitle,
      shop_skill_fragments = shop_skill_fragments,
      achievement_page = achievement_page,
      achievement_title = achievement_title,
      achievement_subtitle = achievement_subtitle,
      achievement_points_value = achievement_points_value,
      confirm_purchase = confirm_purchase,
      save_count = save_count,
      save_count_label = nil,
      debug_root = debug_root,
      debug_paid = debug_paid,
      debug_add_exp_100 = debug_add_exp_100,
      debug_add_exp_500 = debug_add_exp_500,
      debug_reset_claims = debug_reset_claims,
      top_tabs = top_tabs,
      top_tabs_extra = top_tabs_extra,
    }

    runtime.ui.open_hotspot = ensure_open_hotspot(runtime.ui)
    runtime.ui.save_count_label = ensure_save_count_label(runtime.ui)
    for _, tab in ipairs(runtime.ui.top_tabs or {}) do
      if tab.page_field and tab.page_field ~= '' and tab.page_key ~= PAGE_PASS then
        tab.enabled = UIRoot.is_alive(runtime.ui[tab.page_field])
      end
    end
    local runtime_top_nav = ensure_runtime_top_nav(runtime.ui)
    if runtime_top_nav then
      for _, tab in ipairs(runtime_top_nav.buttons or {}) do
        if tab.page_field and tab.page_field ~= '' and tab.page_key ~= PAGE_PASS then
          tab.enabled = UIRoot.is_alive(runtime.ui[tab.page_field])
        end
      end
    end
    refresh_open_entry_label(runtime.ui)
    refresh_top_tabs(runtime.ui)
    set_visible_if_alive(activity_panel_root, false)
    set_visible_if_alive(button_area, true)

    bind_click_once(runtime.ui.open_hotspot, function()
      open_panel(PAGE_PASS)
    end, 'bound_open_hotspot')
    bind_click_once(open_button, function()
      open_panel(PAGE_PASS)
    end, 'bound_open_button')
    bind_click_once(open_icon, function()
      open_panel(PAGE_PASS)
    end, 'bound_open_icon')
    bind_click_once(close_button, function()
      close_panel()
    end, 'bound_close_button')
    bind_click_once(login_tab, function()
      open_panel(PAGE_LOGIN)
    end, 'bound_login_tab')
    bind_click_once(premium_tab, function()
      open_panel(PAGE_PREMIUM)
    end, 'bound_premium_tab')
    bind_click_once(pass_tab, function()
      open_panel(PAGE_PASS)
    end, 'bound_pass_tab')
    for _, tab in ipairs(runtime.ui.top_tabs or {}) do
      local field_name = 'bound_top_tab_' .. tostring(tab.page_key)
      if tab.enabled ~= false then
        bind_click_once(tab.button, function()
          open_panel(tab.page_key)
        end, field_name)
      end
    end
    for _, tab in ipairs((runtime.ui.runtime_top_nav and runtime.ui.runtime_top_nav.buttons) or {}) do
      local field_name = 'bound_runtime_top_tab_' .. tostring(tab.page_key)
      if tab.enabled ~= false then
        bind_click_once(tab.button, function()
          open_panel(tab.page_key)
        end, field_name)
      end
    end
    bind_click_once(claim_button, function()
      handle_claim_click()
    end, 'bound_claim_button')
    bind_click_once(save_count, function()
      cycle_showcase_page()
    end, 'bound_counter_cycle')

    if debug_mode then
      bind_click_once(debug_paid, function()
        handle_toggle_paid()
      end, 'bound_debug_paid')
      bind_click_once(debug_add_exp_100, function()
        handle_add_exp(100)
      end, 'bound_debug_add_exp_100')
      bind_click_once(debug_add_exp_500, function()
        handle_add_exp(500)
      end, 'bound_debug_add_exp_500')
      bind_click_once(debug_reset_claims, function()
        handle_reset_claims()
      end, 'bound_debug_reset_claims')
    end

    set_visible_if_alive(debug_root, debug_mode)
    set_visible_if_alive(item_tip_root, false)
    set_visible_if_alive(obtain_root, false)
    set_visible_if_alive(panel_root, false)

    return runtime.ui
  end

  function api.refresh_ui()
    local ui = ensure_ui()
    if not ui then
      return
    end

    if not is_panel_session_available() then
      set_root_visible(false)
      return
    end

    local profile = get_profile and get_profile() or nil
    if not profile then
      return
    end

    refresh_open_entry_label(ui)
    apply_daily_profile_refresh(profile)
    local model = BattlePass.build_ui_model(profile)
    local compact_mode = is_battle_compact_mode()

    set_root_visible(true)
    refresh_page_switch(ui)

    set_text_if_alive(ui.pass_title, model.season_name)
    set_text_if_alive(
      ui.pass_subtitle,
      compact_mode
        and get_compact_pass_subtitle(model)
        or string.format('当前进度 Lv.%d / %d', model.current_level, model.max_level)
    )
    set_visible_if_alive(ui.pass_subtitle, not compact_mode)
    set_visible_if_alive(ui.current_exp_group, not compact_mode)
    set_visible_if_alive(ui.exp_to_next_group, not compact_mode)
    set_text_if_alive(ui.current_exp_value, tostring(model.total_exp))
    set_text_if_alive(ui.exp_to_next_value, model.reached_max and '已满级' or tostring(model.exp_to_next))
    set_text_if_alive(ui.pass_tips, compact_mode and get_compact_pass_tips(model) or model.tips)
    set_visible_if_alive(ui.pass_tips, not compact_mode)

    set_text_if_alive(ui.login_title, '登录奖励')
    set_text_if_alive(ui.login_subtitle, model.login_reward_summary)

    set_text_if_alive(ui.premium_title, model.military_order_title)
    set_text_if_alive(ui.premium_subtitle, model.military_order_subtitle)
    set_text_if_alive(ui.premium_desc, model.military_order_summary)

    set_text_if_alive(
      ui.save_count_label or ui.save_count,
      model.save_counter_text
    )

    set_text_if_alive(ui.claim_button, model.claim_button_text)
    set_button_enable_if_alive(ui.claim_button, model.claimable_count > 0)

    set_text_if_alive(ui.armory_title, model.armory_title)
    set_text_if_alive(ui.armory_subtitle, model.armory_subtitle)
    set_text_if_alive(ui.shop_title, model.shop_title)
    set_text_if_alive(ui.shop_subtitle, model.shop_subtitle)
    set_text_if_alive(ui.shop_skill_fragments, tostring(model.skill_fragments))
    set_text_if_alive(ui.achievement_title, model.achievement_title)
    set_text_if_alive(ui.achievement_subtitle, model.achievement_subtitle)
    set_text_if_alive(ui.achievement_points_value, tostring(model.achievement_points))

    prepare_pass_grid_for_lua(ui)
    set_progress_if_alive(ui.pass_progress_bar, model.total_exp, model.total_exp_max)
    update_pass_grid(ui, model, compact_mode)

    if UIRoot.is_alive(ui.pass_list) and ui.pass_list.set_list_view_percent then
      ui.pass_list:set_list_view_percent(get_pass_list_percent(ui, model, compact_mode))
    end
  end

  function api.enter_outgame()
    runtime.panel_open = false
    runtime.current_page = PAGE_PASS
    ensure_ui()
    api.refresh_ui()
  end

  function api.open_panel(page_key)
    if not is_panel_session_available() then
      return false
    end
    ensure_ui()
    open_panel(page_key or PAGE_PASS)
    api.refresh_ui()
    return true
  end

  function api.leave_outgame()
    runtime.panel_open = false
    set_root_visible(false)
  end

  function api.set_ui_visible(visible)
    if visible ~= true then
      runtime.panel_open = false
    end
    ensure_ui()
    set_root_visible(visible == true)
    local ui = get_ui()
    if ui and ui.runtime_top_nav and UIRoot.is_alive(ui.runtime_top_nav.root) then
      set_visible_if_alive(ui.runtime_top_nav.root, visible == true)
    end
  end

  function api.set_outgame_panel(panel)
    outgame_panel = panel
    return outgame_panel
  end

  return api
end

return M
