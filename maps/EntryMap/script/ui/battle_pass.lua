local BattlePass = require 'runtime.battle_pass'
local UIRoot = require 'ui.ui_root'

local M = {}

local PAGE_LOGIN = 'login'
local PAGE_PREMIUM = 'premium'
local PAGE_PASS = 'pass'
local BIND_FLAG_KEYS = {
  'bound_open_button',
  'bound_open_icon',
  'bound_close_button',
  'bound_login_tab',
  'bound_premium_tab',
  'bound_pass_tab',
  'bound_claim_button',
  'bound_debug_paid',
  'bound_debug_add_exp_100',
  'bound_debug_add_exp_500',
  'bound_debug_reset_claims',
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

local function set_button_enable_if_alive(ui, enabled)
  if UIRoot.is_alive(ui) and ui.set_button_enable then
    ui:set_button_enable(enabled == true)
  end
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

  local runtime = {
    ui = nil,
    panel_open = false,
    current_page = PAGE_PASS,
    ui_warned = false,
    markers = {},
    markers_count = 0,
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

  local function play_click()
    if play_ui_click then
      play_ui_click()
    end
  end

  local function get_ui()
    return runtime.ui
  end

  local function reset_bind_flags()
    for _, key in ipairs(BIND_FLAG_KEYS) do
      runtime[key] = false
    end
  end

  local function clear_markers()
    for _, marker in ipairs(runtime.markers) do
      if marker.prefab and marker.prefab.remove then
        marker.prefab:remove()
      end
    end
    runtime.markers = {}
    runtime.markers_count = 0
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

    root:set_ui_size(105, 84)
    text:set_ui_size(100, 78)
    text:set_anchor(0.5, 0.5)
    text:set_pos(52.5, 42)
    text:set_font_size(13)
    text:set_text_alignment('中', '中')
    text:set_text('Lv.01')

    return {
      prefab = prefab,
      root = root,
      text = text,
    }
  end

  local function ensure_level_markers(ui, count)
    if runtime.markers_count == count then
      local all_alive = true
      for _, marker in ipairs(runtime.markers) do
        if not UIRoot.is_alive(marker.text) then
          all_alive = false
          break
        end
      end
      if all_alive then
        return
      end
    end

    clear_markers()
    for _ = 1, count do
      local marker = create_level_marker(ui.pass_grid)
      if marker then
        runtime.markers[#runtime.markers + 1] = marker
      end
    end
    runtime.markers_count = #runtime.markers
  end

  local function update_level_markers(ui, model)
    ensure_level_markers(ui, #(model.level_items or {}))
    for index, marker in ipairs(runtime.markers) do
      local item = model.level_items and model.level_items[index] or nil
      set_visible_if_alive(marker.root, item ~= nil)
      if item then
        set_text_if_alive(marker.text, item.cell_text)
        set_text_color_if_alive(marker.text, item.cell_color)
      end
    end
  end

  local function set_root_visible(visible)
    local ui = get_ui()
    if not ui then
      return
    end
    set_visible_if_alive(ui.root, visible)
    set_visible_if_alive(ui.button_area, visible)
    set_visible_if_alive(ui.panel_root, visible and runtime.panel_open == true)
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

    set_visible_if_alive(ui.login_highlight, login_selected)
    set_visible_if_alive(ui.premium_highlight, premium_selected)
    set_visible_if_alive(ui.pass_highlight, pass_selected)

    if login_selected then
      set_visible_if_alive(ui.login_page, true)
    elseif premium_selected then
      set_visible_if_alive(ui.premium_page, true)
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
    if not UIRoot.is_alive(ui_node) or runtime[field_name] == true then
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
      if STATE.session_phase == 'outgame' then
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

    local root = resolve_ui('通行证系统')
    local panel_root = resolve_ui('通行证系统.通行证界面')
    local button_area = resolve_ui('通行证系统.按钮区域')
    local open_button = resolve_ui('通行证系统.按钮区域.仓库按钮')
    local open_icon = resolve_ui('通行证系统.按钮区域.仓库按钮.仓库按钮图标')
    local close_button = resolve_ui('通行证系统.通行证界面.仓库界面关闭按钮')
    local item_tip_root = resolve_ui('通行证系统.物品描述')
    local obtain_root = resolve_ui('通行证系统.获得道具底板')

    local login_tab = resolve_ui('通行证系统.通行证界面.左侧区域.登陆奖励')
    local login_highlight = resolve_ui('通行证系统.通行证界面.左侧区域.登陆奖励.登录奖励高亮')
    local premium_tab = resolve_ui('通行证系统.通行证界面.左侧区域.军令状')
    local premium_highlight = resolve_ui('通行证系统.通行证界面.左侧区域.军令状.军令状高亮')
    local pass_tab = resolve_ui('通行证系统.通行证界面.左侧区域.征战之路')
    local pass_highlight = resolve_ui('通行证系统.通行证界面.左侧区域.征战之路.征战之路高亮')

    local login_page = resolve_ui('通行证系统.通行证界面.右侧区域.登陆奖励页面')
    local login_title = resolve_ui('通行证系统.通行证界面.右侧区域.登陆奖励页面.标题')
    local login_subtitle = resolve_ui('通行证系统.通行证界面.右侧区域.登陆奖励页面.副标题')

    local premium_page = resolve_ui('通行证系统.通行证界面.右侧区域.军令状页面')
    local premium_title = resolve_ui('通行证系统.通行证界面.右侧区域.军令状页面.标题')
    local premium_subtitle = resolve_ui('通行证系统.通行证界面.右侧区域.军令状页面.副标题')
    local premium_desc = resolve_ui('通行证系统.通行证界面.右侧区域.军令状页面.介绍文本')

    local pass_page = resolve_ui('通行证系统.通行证界面.右侧区域.通行证页面')
    local pass_title = resolve_ui('通行证系统.通行证界面.右侧区域.通行证页面.标题')
    local pass_subtitle = resolve_ui('通行证系统.通行证界面.右侧区域.通行证页面.副标题')
    local current_exp_value = resolve_ui('通行证系统.通行证界面.右侧区域.通行证页面.当前征战之路经验.数字')
    local exp_to_next_value = resolve_ui('通行证系统.通行证界面.右侧区域.通行证页面.距离下级所需经验.数字')
    local pass_list = resolve_ui('通行证系统.通行证界面.右侧区域.通行证页面.通行证列表')
    local pass_list_bg = resolve_ui('通行证系统.通行证界面.右侧区域.通行证页面.通行证列表.列表背景')
    local pass_progress_bar = resolve_ui('通行证系统.通行证界面.右侧区域.通行证页面.通行证列表.列表背景.通行证进度条')
    local pass_grid = resolve_ui('通行证系统.通行证界面.右侧区域.通行证页面.通行证列表.列表背景.网格列表')
    local claim_button = resolve_ui('通行证系统.通行证界面.右侧区域.通行证页面.领取按钮')
    local pass_tips = resolve_ui('通行证系统.通行证界面.右侧区域.通行证页面.通行证Tips')

    local armory_page = resolve_ui('通行证系统.通行证界面.右侧区域.武库页面')
    local shop_page = resolve_ui('通行证系统.通行证界面.右侧区域.商店页面')
    local achievement_page = resolve_ui('通行证系统.通行证界面.右侧区域.成就页面')
    local confirm_purchase = resolve_ui('通行证系统.通行证界面.右侧区域.确认购买')
    local save_count = resolve_ui('通行证系统.通行证界面.存档数量显示')

    local debug_root = resolve_ui('通行证系统.通行证界面.测试按钮')
    local debug_paid = resolve_ui('通行证系统.通行证界面.测试按钮.付费开关')
    local debug_add_exp_100 = resolve_ui('通行证系统.通行证界面.测试按钮.加经验100')
    local debug_add_exp_500 = resolve_ui('通行证系统.通行证界面.测试按钮.加经验500')
    local debug_reset_claims = resolve_ui('通行证系统.通行证界面.测试按钮.重置领取状态')

    if not root or not panel_root or not open_button or not close_button or not pass_grid then
      if not runtime.ui_warned then
        runtime.ui_warned = true
        message('未找到通行证系统画板节点，请确认 maps/EntryMap/ui/通行证系统.json 已加载。')
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
      current_exp_value = current_exp_value,
      exp_to_next_value = exp_to_next_value,
      pass_list = pass_list,
      pass_list_bg = pass_list_bg,
      pass_progress_bar = pass_progress_bar,
      pass_grid = pass_grid,
      claim_button = claim_button,
      pass_tips = pass_tips,
      armory_page = armory_page,
      shop_page = shop_page,
      achievement_page = achievement_page,
      confirm_purchase = confirm_purchase,
      save_count = save_count,
      debug_root = debug_root,
      debug_paid = debug_paid,
      debug_add_exp_100 = debug_add_exp_100,
      debug_add_exp_500 = debug_add_exp_500,
      debug_reset_claims = debug_reset_claims,
    }

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
    bind_click_once(claim_button, function()
      handle_claim_click()
    end, 'bound_claim_button')

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

    if STATE.session_phase ~= 'outgame' then
      set_root_visible(false)
      return
    end

    local profile = get_profile and get_profile() or nil
    if not profile then
      return
    end

    local model = BattlePass.build_ui_model(profile)

    set_root_visible(true)
    refresh_page_switch(ui)

    set_text_if_alive(ui.pass_title, model.season_name)
    set_text_if_alive(ui.pass_subtitle, string.format('当前进度 Lv.%d / %d', model.current_level, model.max_level))
    set_text_if_alive(ui.current_exp_value, tostring(model.total_exp))
    set_text_if_alive(ui.exp_to_next_value, model.reached_max and '已满级' or tostring(model.exp_to_next))
    set_text_if_alive(ui.pass_tips, model.tips)
    set_visible_if_alive(ui.pass_tips, true)

    set_text_if_alive(ui.login_title, '登录奖励')
    set_text_if_alive(ui.login_subtitle, model.login_reward_summary)

    set_text_if_alive(ui.premium_title, model.premium_name)
    set_text_if_alive(ui.premium_subtitle, string.format('当前状态：%s', model.premium_status))
    set_text_if_alive(ui.premium_desc, model.military_order_summary)

    set_text_if_alive(
      ui.save_count,
      string.format('赛季Lv.%d  至尊:%s', model.current_level, model.paid_unlocked and '开' or '关')
    )

    set_text_if_alive(ui.claim_button, model.claim_button_text)
    set_button_enable_if_alive(ui.claim_button, model.claimable_count > 0)

    set_progress_if_alive(ui.pass_progress_bar, model.total_exp, model.total_exp_max)
    update_level_markers(ui, model)

    if UIRoot.is_alive(ui.pass_list) and ui.pass_list.set_list_view_percent then
      local percent = 0
      if model.max_level > 1 then
        percent = ((model.current_level - 1) / (model.max_level - 1)) * 100
      end
      ui.pass_list:set_list_view_percent(percent)
    end
  end

  function api.enter_outgame()
    runtime.panel_open = false
    runtime.current_page = PAGE_PASS
    ensure_ui()
    api.refresh_ui()
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
  end

  return api
end

return M
