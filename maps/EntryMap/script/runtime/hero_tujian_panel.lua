local UIRoot = require 'ui.ui_root'

local M = {}

local SLOT_NAMES = {
  'heromodel',
  'heromodel_1',
  'heromodel_2',
  'heromodel_3',
  'heromodel_4',
  'heromodel_5',
  'heromodel_5_1',
  'heromodel_5_2',
  'heromodel_5_3',
  'heromodel_5_4',
  'heromodel_5_5',
  'heromodel_5_6',
  'heromodel_5_7',
  'heromodel_5_8',
  'heromodel_5_9',
  'heromodel_5_10',
  'heromodel_5_11',
  'heromodel_5_12',
  'heromodel_5_13',
  'heromodel_5_14',
  'heromodel_5_15',
  'heromodel_5_16',
  'heromodel_5_17',
  'heromodel_5_18',
  'heromodel_5_19',
}

local function is_alive(ui)
  return UIRoot.is_alive(ui)
end

local function call_ui(ui, method, ...)
  if not is_alive(ui) then
    return false
  end
  local fn = ui[method]
  if type(fn) ~= 'function' then
    return false
  end
  local ok = pcall(fn, ui, ...)
  return ok
end

local function set_text(ui, text)
  call_ui(ui, 'set_text', tostring(text or ''))
end

local function set_visible(ui, visible)
  call_ui(ui, 'set_visible', visible == true)
end

local function set_image(ui, image)
  if image ~= nil and image ~= '' and image ~= 0 then
    call_ui(ui, 'set_image', image)
  end
end

local function resolve_model_id(y3, unit_id, preferred_model_id)
  local direct_model_id = tonumber(preferred_model_id)
  if direct_model_id and direct_model_id ~= 0 then
    return direct_model_id
  end
  if not unit_id or not y3 or not y3.unit then
    return nil
  end
  local ok_model, model_id = pcall(y3.unit.get_model_by_key, unit_id)
  if ok_model and model_id and model_id ~= 0 then
    return model_id
  end
  return nil
end

local function set_model_id(ui, model_id)
  if not is_alive(ui) or not model_id then
    return false
  end
  return call_ui(ui, 'set_ui_model_id', model_id)
end

local function set_model_by_unit(ui, y3, unit_id, preferred_model_id)
  if not is_alive(ui) then
    return nil
  end
  local model_id = resolve_model_id(y3, unit_id, preferred_model_id)
  if model_id then
    set_model_id(ui, model_id)
  end
  return model_id
end

local function unpack_args(values)
  if table and table.unpack then
    return table.unpack(values)
  end
  return unpack(values)
end

function M.create(env)
  local STATE = env.STATE
  local y3 = env.y3
  local get_player = env.get_player
  local message = env.message or function() end
  local play_ui_click = env.play_ui_click
  local get_all_hero_growth = env.get_all_hero_growth
  local get_hero_growth = env.get_hero_growth
  local try_hero_star_up = env.try_hero_star_up
  local try_hero_awaken = env.try_hero_awaken
  local get_awaken_stone = env.get_awaken_stone

  local cache = {
    root = nil,
    slot_nodes = nil,
    detail = nil,
    bound = false,
    slot_model_ids = {},
    detail_model_id = nil,
  }

  local function get_runtime_hud()
    STATE.runtime_hud = STATE.runtime_hud or {}
    return STATE.runtime_hud
  end

  local function resolve_root()
    local runtime_hud = get_runtime_hud()
    local root = runtime_hud.hero_tujian_root
    if not is_alive(root) then
      cache.root = nil
      cache.slot_nodes = nil
      cache.detail = nil
      cache.bound = false
      cache.slot_model_ids = {}
      cache.detail_model_id = nil
      return nil
    end
    if cache.root ~= root then
      cache.root = root
      cache.slot_nodes = nil
      cache.detail = nil
      cache.bound = false
      cache.slot_model_ids = {}
      cache.detail_model_id = nil
    end
    return cache.root
  end

  local function resolve_slot_nodes(root)
    if cache.slot_nodes then
      return cache.slot_nodes
    end
    local slots = {}
    for _, slot_name in ipairs(SLOT_NAMES) do
      local slot_root = UIRoot.resolve_child(root, 'grid_view_1.' .. slot_name)
      if is_alive(slot_root) then
        slots[#slots + 1] = {
          root = slot_root,
          model = UIRoot.resolve_child(slot_root, 'model'),
          name = UIRoot.resolve_child(slot_root, 'label'),
          star_1 = UIRoot.resolve_child(slot_root, 'yixing'),
          star_2 = UIRoot.resolve_child(slot_root, 'erxing'),
          star_3 = UIRoot.resolve_child(slot_root, 'sanxing'),
          bound = false,
        }
      end
    end
    cache.slot_nodes = slots
    return slots
  end

  local function resolve_detail_nodes(root)
    if cache.detail then
      return cache.detail
    end
    cache.detail = {
      header_tip = UIRoot.resolve_child(root, 'tip1'),
      awaken_cost_tip = UIRoot.resolve_child(root, 'tip2'),
      star_cost_tip = UIRoot.resolve_child(root, 'tip'),
      owned_tip = UIRoot.resolve_child(root, 'yongyou'),
      hero_name = UIRoot.resolve_child(root, 'scroll_view_2.label_4'),
      hero_skill = UIRoot.resolve_child(root, 'scroll_view_2.label_4_2'),
      star_effect = UIRoot.resolve_child(root, 'scroll_view_2.label_4_4'),
      awaken_effect = UIRoot.resolve_child(root, 'scroll_view_2.label_4_5_1'),
      detail_model = UIRoot.resolve_child(root, 'image_2'),
      detail_star_1 = UIRoot.resolve_child(root, 'scroll_view_2.xingji.yixing'),
      detail_star_2 = UIRoot.resolve_child(root, 'scroll_view_2.xingji.erxing'),
      detail_star_3 = UIRoot.resolve_child(root, 'scroll_view_2.xingji.sanxing'),
      awaken_button = UIRoot.resolve_child(root, 'juexing'),
      star_up_button = UIRoot.resolve_child(root, 'shengxing'),
      awaken_button_bound = false,
      star_up_button_bound = false,
    }
    return cache.detail
  end

  local function resolve_growth_list()
    local list = get_all_hero_growth and get_all_hero_growth() or {}
    if type(list) ~= 'table' then
      return {}
    end
    return list
  end

  local function resolve_selected_growth(list)
    local runtime_hud = get_runtime_hud()
    local selected_id = runtime_hud.hero_tujian_selected_id
    if selected_id then
      for _, row in ipairs(list) do
        if row and row.hero_id == selected_id then
          return row
        end
      end
    end
    local first = list[1]
    if first then
      runtime_hud.hero_tujian_selected_id = first.hero_id
      return first
    end
    runtime_hud.hero_tujian_selected_id = nil
    return nil
  end

  local function apply_star_icons(star_1, star_2, star_3, star)
    local value = math.max(0, math.floor(tonumber(star) or 0))
    local on_color = { 255, 255, 255, 255 }
    local off_color = { 120, 120, 120, 160 }
    call_ui(star_1, 'set_image_color', unpack_args(value >= 1 and on_color or off_color))
    call_ui(star_2, 'set_image_color', unpack_args(value >= 2 and on_color or off_color))
    call_ui(star_3, 'set_image_color', unpack_args(value >= 3 and on_color or off_color))
  end

  local function bind_slot_click(slot, growth)
    if slot.bound or not is_alive(slot.root) or type(slot.root.add_fast_event) ~= 'function' then
      return
    end
    slot.bound = true
    slot.root:add_fast_event('左键-点击', function()
      if play_ui_click then
        play_ui_click()
      end
      local runtime_hud = get_runtime_hud()
      runtime_hud.hero_tujian_selected_id = growth.hero_id
    end)
  end

  local function refresh_slots(root, list, selected)
    local slots = resolve_slot_nodes(root)
    for index, slot in ipairs(slots) do
      local growth = list[index]
      set_visible(slot.root, growth ~= nil)
      if growth then
        set_text(slot.name, growth.hero_name)
        apply_star_icons(slot.star_1, slot.star_2, slot.star_3, growth.star)
        local model_id = resolve_model_id(y3, growth.unit_id, growth.hero_model)
        if cache.slot_model_ids[index] ~= model_id then
          cache.slot_model_ids[index] = model_id
          if model_id then
            set_model_id(slot.model, model_id)
          end
        end
        bind_slot_click(slot, growth)
        local is_selected = selected and growth.hero_id == selected.hero_id
        call_ui(slot.root, 'set_image_color', is_selected and 255 or 190, is_selected and 255 or 190, is_selected and 255 or 190, 255)
      end
    end
  end

  local function bind_action_buttons(detail)
    if is_alive(detail.awaken_button) and not detail.awaken_button_bound and type(detail.awaken_button.add_fast_event) == 'function' then
      detail.awaken_button_bound = true
      detail.awaken_button:add_fast_event('左键-点击', function()
        local runtime_hud = get_runtime_hud()
        local hero_id = runtime_hud.hero_tujian_selected_id
        if not hero_id then
          return
        end
        if play_ui_click then
          play_ui_click()
        end
        local ok, msg
        if try_hero_awaken then
          ok, msg = try_hero_awaken(hero_id)
        else
          ok, msg = false, '未接入觉醒接口'
        end
        if ok then
          message('觉醒成功：' .. tostring(hero_id))
        else
          message(tostring(msg or '觉醒失败'))
        end
      end)
    end

    if is_alive(detail.star_up_button) and not detail.star_up_button_bound and type(detail.star_up_button.add_fast_event) == 'function' then
      detail.star_up_button_bound = true
      detail.star_up_button:add_fast_event('左键-点击', function()
        local runtime_hud = get_runtime_hud()
        local hero_id = runtime_hud.hero_tujian_selected_id
        if not hero_id then
          return
        end
        if play_ui_click then
          play_ui_click()
        end
        local ok, msg
        if try_hero_star_up then
          ok, msg = try_hero_star_up(hero_id)
        else
          ok, msg = false, '未接入升星接口'
        end
        if ok then
          message('升星成功：' .. tostring(hero_id))
        else
          message(tostring(msg or '升星失败'))
        end
      end)
    end
  end

  local function refresh_detail(root, selected, total_count)
    local detail = resolve_detail_nodes(root)
    bind_action_buttons(detail)

    local awaken_stone = get_awaken_stone and (tonumber(get_awaken_stone()) or 0) or 0
    local proficiency = selected and (tonumber(selected.proficiency) or 0) or 0
    set_text(detail.header_tip, string.format('觉醒石：%d  熟练度：%d', awaken_stone, proficiency))
    set_text(detail.awaken_cost_tip, string.format('消耗%d觉醒石', selected and (selected.awaken_cost or 1) or 1))
    set_text(detail.star_cost_tip, string.format('消耗%d熟练度', selected and (selected.next_star_cost or 0) or 0))
    set_text(detail.owned_tip, string.format('拥有英雄：%d', tonumber(total_count) or 0))

    if not selected then
      set_text(detail.hero_name, '英雄名称')
      set_text(detail.hero_skill, '')
      set_text(detail.star_effect, '')
      set_text(detail.awaken_effect, '')
      set_visible(detail.awaken_button, false)
      set_visible(detail.star_up_button, false)
      return
    end

    local latest = get_hero_growth and get_hero_growth(selected.hero_id) or selected
    selected = latest or selected

    set_text(detail.hero_name, selected.hero_name or '英雄名称')
    set_text(detail.hero_skill, selected.talent_skill or '')
    set_text(detail.star_effect, selected.star_effect or '')
    set_text(detail.awaken_effect, selected.awaken_effect or '')
    apply_star_icons(detail.detail_star_1, detail.detail_star_2, detail.detail_star_3, selected.star)
    local detail_model_id = resolve_model_id(y3, selected.unit_id, selected.hero_model)
    if cache.detail_model_id ~= detail_model_id then
      cache.detail_model_id = detail_model_id
      if detail_model_id then
        set_model_id(detail.detail_model, detail_model_id)
      end
    end

    call_ui(detail.star_up_button, 'set_button_enable', selected.next_star_cost ~= nil and selected.next_star_cost > 0 and selected.proficiency >= selected.next_star_cost)
    call_ui(detail.awaken_button, 'set_button_enable', selected.awakened ~= true and (selected.star or 0) >= (selected.max_star or 3) and awaken_stone >= (selected.awaken_cost or 1))
    set_visible(detail.star_up_button, true)
    set_visible(detail.awaken_button, true)
  end

  local function refresh()
    local runtime_hud = get_runtime_hud()
    if runtime_hud.hero_tujian_visible ~= true then
      return
    end
    local root = resolve_root()
    if not root then
      return
    end
    local list = resolve_growth_list()
    local selected = resolve_selected_growth(list)
    refresh_slots(root, list, selected)
    refresh_detail(root, selected, #list)
  end

  return {
    refresh = refresh,
  }
end

return M
