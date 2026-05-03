local M = {}

local DEFAULT_ICON = 906565
local GRID_BASE_PATHS = {
  'ArchiveMain.layout_1.scroll_view_main.scroll_view_1.ArchiveGridView.grid_view_1.',
  'ArchiveMain.存档生涯商城.scroll_view.ArchiveGridView.grid_view_1.',
  'ArchiveMain.存档生涯商城.文本详情.ArchiveGridView.grid_view_1.',
}
local GRID_ROOT_PATHS = {
  'ArchiveMain.layout_1.scroll_view_main.scroll_view_1.ArchiveGridView.grid_view_1',
  'ArchiveMain.存档生涯商城.scroll_view.ArchiveGridView.grid_view_1',
  'ArchiveMain.存档生涯商城.文本详情.ArchiveGridView.grid_view_1',
}
local TIP_ROOT_PATHS = {
  'ArchiveMain.layout_1.scroll_view_main.scroll_view_1.ArchiveTips',
  'ArchiveMain.存档生涯商城.scroll_view.ArchiveTips',
  'ArchiveMain.存档生涯商城.文本详情.ArchiveTips',
  'ArchiveMain.存档生涯商城.scroll_view',
  'ArchiveMain.存档生涯商城.文本详情',
}
local TIP_SCROLL_PATHS = {
  'ArchiveMain.layout_1.scroll_view_main.scroll_view_1.ArchiveTips.scroll_view',
  'ArchiveMain.存档生涯商城.scroll_view.ArchiveTips.scroll_view',
  'ArchiveMain.存档生涯商城.文本详情.ArchiveTips.scroll_view',
  'ArchiveMain.存档生涯商城.文本详情',
  'ArchiveMain.存档生涯商城.scroll_view',
}
local PRIMARY_TAB_BASE_PATHS = {
  'ArchiveMain.layout_1.scroll_view_main.page_grid.ArchivePageOne',
  'ArchiveMain.存档生涯商城.page_grid.ArchivePageOne',
}
local SECONDARY_TAB_BASE_PATHS = {
  'ArchiveMain.layout_1.scroll_view_main.page2_grid.ArchivePageTwo',
  'ArchiveMain.存档生涯商城.page2_grid.ArchivePageTwo',
}
local SECONDARY_TAB_GRID_PATHS = {
  'ArchiveMain.layout_1.scroll_view_main.page2_grid',
  'ArchiveMain.存档生涯商城.page2_grid',
}
local CAREER_TAB_LABELS = { '成就', '英雄图鉴', '羁绊图鉴', '称号' }
local CAREER_TAB_DETAILS = {
  ['成就'] = {
    title = '成就总览',
    owned = '完成你的阶段目标',
    detail_title = '[进度说明]',
    detail = '这里展示成就点、阶段奖励与最近完成记录。',
    special_title = '[当前状态]',
    special = '点击左侧页签切换不同生涯模块。',
    obtain_title = '[获取方式]',
    obtain = '通关、累计养成与收集行为都会推进成就。',
  },
  ['英雄图鉴'] = {
    title = '英雄图鉴',
    owned = '已解锁英雄信息',
    detail_title = '[图鉴说明]',
    detail = '这里展示英雄解锁、星级与专精进度。',
    special_title = '[当前状态]',
    special = '选中英雄后可查看详细成长条目。',
    obtain_title = '[获取方式]',
    obtain = '通过关卡奖励、活动与商店兑换获取英雄。',
  },
  ['羁绊图鉴'] = {
    title = '羁绊图鉴',
    owned = '羁绊收集与激活',
    detail_title = '[图鉴说明]',
    detail = '这里展示羁绊激活条件、层级与效果说明。',
    special_title = '[当前状态]',
    special = '满足队伍条件后可在局内触发羁绊效果。',
    obtain_title = '[获取方式]',
    obtain = '通过收集对应英雄并达成编队条件激活。',
  },
  ['称号'] = {
    title = '称号系统',
    owned = '称号收集进度',
    detail_title = '[称号说明]',
    detail = '这里展示称号属性、佩戴状态与获取记录。',
    special_title = '[当前状态]',
    special = '佩戴中的称号会在局外信息中展示。',
    obtain_title = '[获取方式]',
    obtain = '通过成就节点、活动和挑战任务解锁称号。',
  },
}
local SLOT_BOUND = setmetatable({}, { __mode = 'k' })
local SLOT_SPEC_KEY = setmetatable({}, { __mode = 'k' })

local function is_ui_alive(ui)
  return ui and (not ui.is_removed or not ui:is_removed())
end

local function resolve_ui(player, path)
  if not player or not path then
    return nil
  end
  local ok, ui = pcall(y3.ui.get_ui, player, path)
  if ok then
    return ui
  end
  return nil
end

local function resolve_ui_first(player, paths)
  if type(paths) ~= 'table' then
    return nil, nil
  end
  for _, path in ipairs(paths) do
    local ui = resolve_ui(player, path)
    if is_ui_alive(ui) then
      return ui, path
    end
  end
  return nil, nil
end

local function set_visible(ui, visible)
  if is_ui_alive(ui) and ui.set_visible then
    ui:set_visible(visible == true)
  end
end

local function set_text(ui, text)
  if is_ui_alive(ui) and ui.set_text then
    ui:set_text(text or '')
  end
end

local function set_image(ui, image)
  if is_ui_alive(ui) and ui.set_image and image ~= nil and image ~= '' then
    ui:set_image(image)
  end
end

local function set_image_color(ui, color)
  if is_ui_alive(ui) and ui.set_image_color and color then
    ui:set_image_color(color[1], color[2], color[3], color[4] or 255)
  end
end

local function set_text_color(ui, color)
  if is_ui_alive(ui) and ui.set_text_color and color then
    ui:set_text_color(color[1], color[2], color[3], color[4] or 255)
  end
end

local function set_font_size(ui, size)
  if is_ui_alive(ui) and ui.set_font_size and size then
    ui:set_font_size(size)
  end
end

local function set_text_alignment(ui, horizontal, vertical)
  if is_ui_alive(ui) and ui.set_text_alignment then
    ui:set_text_alignment(horizontal or '左', vertical or '中')
  end
end

local function set_intercepts(ui, intercepts)
  if is_ui_alive(ui) and ui.set_intercepts_operations then
    ui:set_intercepts_operations(intercepts == true)
  end
end

local function get_ui_child(ui, path)
  if not (is_ui_alive(ui) and ui.get_child and path) then
    return nil
  end
  local ok, child = pcall(ui.get_child, ui, path)
  if ok and is_ui_alive(child) then
    return child
  end
  return nil
end

local function get_prefab_child(prefab_instance, path)
  local prefab = prefab_instance and prefab_instance.prefab or nil
  if not (prefab and prefab.get_child and path) then
    return nil
  end
  local ok, child = pcall(prefab.get_child, prefab, path)
  if ok and is_ui_alive(child) then
    return child
  end
  return nil
end

local function create_prefab(player, parent, prefab_name, child_index)
  if not (y3 and y3.ui_prefab and y3.ui_prefab.create and player and parent) then
    return nil
  end
  local ok, prefab = pcall(y3.ui_prefab.create, player, prefab_name, parent)
  if not ok or not prefab then
    return nil
  end
  local root = prefab.get_child and prefab:get_child() or nil
  if is_ui_alive(root) and parent.insert_ui_gridview_comp then
    pcall(parent.insert_ui_gridview_comp, parent, root, child_index)
  end
  return {
    prefab = prefab,
    root = root,
  }
end

local function get_static_slot_names()
  local names = { 'ArchiveDaoJv' }
  for index = 1, 12 do
    names[#names + 1] = 'ArchiveDaoJv_' .. index
  end
  names[#names + 1] = 'ArchiveDaoJv_13_1'
  for index = 1, 12 do
    names[#names + 1] = string.format('ArchiveDaoJv_%d_1_1', index)
  end
  for index = 1, 9 do
    names[#names + 1] = string.format('ArchiveDaoJv_12_1_1_%d', index)
  end
  return names
end

local function hide_static_slots(player)
  for _, name in ipairs(get_static_slot_names()) do
    for _, base_path in ipairs(GRID_BASE_PATHS) do
      set_visible(resolve_ui(player, base_path .. name), false)
    end
  end
end

local function get_text(ui)
  if is_ui_alive(ui) and ui.get_text then
    local ok, value = pcall(ui.get_text, ui)
    if ok then
      return tostring(value or '')
    end
  end
  return ''
end

local function collect_tab_paths(base_path, max_extra)
  local paths = { base_path }
  for index = 1, max_extra or 8 do
    paths[#paths + 1] = string.format('%s_%d', base_path, index)
  end
  return paths
end

local function resolve_tip(player)
  local _, tip_path = resolve_ui_first(player, TIP_SCROLL_PATHS)
  tip_path = tip_path or TIP_SCROLL_PATHS[1]
  return {
    root = resolve_ui_first(player, TIP_ROOT_PATHS),
    title = resolve_ui(player, tip_path .. '.标题'),
    owned = resolve_ui(player, tip_path .. '.是否拥有'),
    detail_title = resolve_ui(player, tip_path .. '.详情效果标题'),
    detail = resolve_ui(player, tip_path .. '.详情效果内容'),
    special_title = resolve_ui(player, tip_path .. '.特殊效果标题'),
    special = resolve_ui(player, tip_path .. '.特殊效果内容'),
    obtain_title = resolve_ui(player, tip_path .. '.获取方式标题'),
    obtain = resolve_ui(player, tip_path .. '.获取方式内容'),
  }
end

local function get_primary(state)
  return state.archive_panel_shop_primary
end

local function get_category(state)
  return state.archive_panel_shop_category
end

local function clear_runtime_secondary_tabs(shop)
  if type(shop.runtime_secondary_tabs) ~= 'table' then
    shop.runtime_secondary_tabs = {}
    return
  end
  for _, entry in ipairs(shop.runtime_secondary_tabs) do
    if is_ui_alive(entry.root) and entry.root.remove then
      pcall(entry.root.remove, entry.root)
    end
  end
  shop.runtime_secondary_tabs = {}
end

local function create_runtime_secondary_tab(ui, options, category)
  local shop = ui and ui.shop
  if not shop or not is_ui_alive(shop.secondary_tab_grid_root) then
    return nil
  end
  local player = options and options.player or nil
  if not player then
    return nil
  end
  local prefab = create_prefab(player, shop.secondary_tab_grid_root, 'ArchivePageTwo')
  if not prefab or not is_ui_alive(prefab.root) then
    return nil
  end
  local root = prefab.root
  local bg = get_ui_child(root, 'button_1') or get_ui_child(root, 'button') or root
  local label = get_ui_child(root, 'label_1') or get_ui_child(root, 'label')
  local entry = {
    category = category,
    root = root,
    bg = bg,
    label = label,
    raw_label = get_text(label),
    runtime = true,
  }
  set_text(entry.label, category or '')
  if is_ui_alive(bg) then
    set_intercepts(bg, true)
    bg:add_fast_event('左键-按下', function()
      local section = tostring(options.state.archive_panel_section or '')
      if section ~= 'shop' and section ~= 'archive' then
        return
      end
      if not entry.category then
        return
      end
      if tostring(options.state.archive_panel_shop_category or '') == tostring(entry.category or '') then
        return
      end
      if options.play_ui_click then
        options.play_ui_click()
      end
      options.state.archive_panel_shop_category = entry.category
      options.state.archive_panel_shop_item = nil
      M.refresh(ui, options)
    end)
  end
  shop.runtime_secondary_tabs[#shop.runtime_secondary_tabs + 1] = entry
  shop.secondary_tabs[#shop.secondary_tabs + 1] = entry
  return entry
end

local function get_all_category_label(options)
  return tostring((options and options.all_category_label) or '全部')
end

local function resolve_partition_from_section(state)
  local section = tostring(state and state.archive_panel_section or '')
  if section == 'shop' then
    return '商城'
  elseif section == 'archive' then
    return '存档'
  elseif section == 'career' then
    return '生涯'
  end
  return nil
end

local function get_primary_tabs(state, options, specs)
  local tabs = {}
  local seen = {}
  local partition_expect = resolve_partition_from_section(state)

  local function try_add(primary)
    if not primary or primary == '' or seen[primary] == true then
      return
    end
    if partition_expect and partition_expect ~= '' then
      local has_match = false
      for _, spec in ipairs(specs or {}) do
        if spec.primary == primary and tostring(spec.partition or '') == partition_expect then
          has_match = true
          break
        end
      end
      if not has_match then
        return
      end
    end
    seen[primary] = true
    tabs[#tabs + 1] = primary
  end

  for _, primary in ipairs(options.primary_tabs or {}) do
    try_add(primary)
  end
  for _, spec in ipairs(specs or {}) do
    if partition_expect and partition_expect ~= '' then
      if tostring(spec.partition or '') == partition_expect then
        try_add(spec.primary)
      end
    else
      try_add(spec.primary)
    end
  end
  return tabs
end

local function get_categories_for_primary(state, options, specs, primary)
  local categories = {}
  local seen = {}
  local all_category = get_all_category_label(options)
  local partition_expect = resolve_partition_from_section(state)
  local by_primary = options.categories_by_primary or {}
  for _, category in ipairs(by_primary[primary] or {}) do
    if category and category ~= '' and seen[category] ~= true then
      seen[category] = true
      categories[#categories + 1] = category
    end
  end
  -- 始终合并 specs 里的真实分类，避免仅显示“全部”。
  for _, spec in ipairs(specs or {}) do
    local partition_ok = true
    if partition_expect and partition_expect ~= '' then
      partition_ok = tostring(spec.partition or '') == partition_expect
    end
    if partition_ok and spec.primary == primary then
      local list = spec.categories or { spec.category }
      for _, category in ipairs(list or {}) do
        if category and category ~= '' and seen[category] ~= true then
          seen[category] = true
          categories[#categories + 1] = category
        end
      end
    end
  end
  -- 约定：全量分类固定排在第一个（标签由配置给定）。
  local all_index = nil
  for i, c in ipairs(categories) do
    if c == all_category then
      all_index = i
      break
    end
  end
  if all_index and all_index > 1 then
    table.remove(categories, all_index)
    table.insert(categories, 1, all_category)
  end
  return categories
end

local function ensure_selection(state, options, specs)
  local primary_tabs = get_primary_tabs(state, options, specs)
  if (not state.archive_panel_shop_primary) or state.archive_panel_shop_primary == '' then
    state.archive_panel_shop_primary = primary_tabs[1]
  end
  local categories = get_categories_for_primary(state, options, specs, state.archive_panel_shop_primary)
  local current_category = state.archive_panel_shop_category
  local exists = false
  for _, category in ipairs(categories) do
    if category == current_category then
      exists = true
      break
    end
  end
  if not exists then
    state.archive_panel_shop_category = categories[1]
    state.archive_panel_shop_item = nil
  end
  return primary_tabs, categories
end

local function get_visible_items(state, specs)
  local section = tostring(state and state.archive_panel_section or '')
  local partition_expect = nil
  if section == 'shop' then
    partition_expect = '商城'
  elseif section == 'archive' then
    partition_expect = '存档'
  elseif section == 'career' then
    partition_expect = '生涯'
  end

  local primary = get_primary(state)
  if section == 'career' then
    primary = tostring(state and state.archive_panel_career_tab or CAREER_TAB_LABELS[1])
  end
  local category = get_category(state)
  local all_category = get_all_category_label(state and state.archive_shop_options)
  local items = {}
  for _, spec in ipairs(specs or {}) do
    local partition_ok = true
    if partition_expect and partition_expect ~= '' then
      local partition = tostring(spec.partition or '')
      partition_ok = partition == '' or partition == partition_expect
    end
    local primary_ok = (not primary or primary == '' or spec.primary == primary)
    local category_ok = true
    if category and category ~= '' and category ~= all_category then
      category_ok = false
      local spec_categories = spec.categories or { spec.category }
      for _, one in ipairs(spec_categories or {}) do
        if one == category then
          category_ok = true
          break
        end
      end
    end
    if partition_ok and primary_ok and category_ok then
      items[#items + 1] = spec
    end
  end
  return items
end

local function is_owned(spec)
  local text = tostring((spec and spec.owned_text) or ''):gsub('^%s+', ''):gsub('%s+$', '')
  if text == '' or text == '未拥有' or text == '否' or text == 'false' or text == 'FALSE' then
    return false
  end
  local number = tonumber(text)
  if number ~= nil then
    return number > 0
  end
  if text == '0' then
    return false
  end
  return true
end

local function refresh_tip(state, shop, spec)
  if not spec then
    return false
  end
  state.archive_panel_shop_item = spec.key
  local tip = shop.tip or {}
  local quality = tostring(spec.quality or '')
  local title_color = { 255, 232, 120, 255 }
  if quality == 'SSR' then
    title_color = { 255, 220, 72, 255 }
  elseif quality == 'SR' then
    title_color = { 238, 158, 255, 255 }
  elseif quality == 'R' then
    title_color = { 105, 214, 255, 255 }
  elseif quality == 'N' then
    title_color = { 220, 226, 238, 255 }
  end

  set_visible(tip.root, true)
  set_text(tip.title, spec.title)
  set_text(tip.owned, spec.owned_text ~= '' and spec.owned_text or '未拥有')
  set_text(tip.detail_title, '[详情效果]')
  set_text(tip.detail, table.concat(spec.attr_lines or {}, '\n'))
  set_text(tip.special_title, '[特殊效果]')
  set_text(tip.special, spec.special_effect ~= '' and spec.special_effect or '暂无')
  set_text(tip.obtain_title, '[获取方式]')
  set_text(tip.obtain, spec.obtain ~= '' and spec.obtain or '暂无')

  set_font_size(tip.title, 24)
  set_text_color(tip.title, title_color)
  set_text_alignment(tip.title, '左', '中')

  set_font_size(tip.owned, 14)
  set_text_color(tip.owned, { 162, 166, 178, 255 })
  set_text_alignment(tip.owned, '中', '中')

  set_font_size(tip.detail_title, 15)
  set_text_color(tip.detail_title, { 255, 232, 44, 255 })
  set_text_alignment(tip.detail_title, '左', '中')
  set_font_size(tip.detail, 16)
  set_text_color(tip.detail, { 44, 255, 112, 255 })
  set_text_alignment(tip.detail, '左', '上')

  set_font_size(tip.special_title, 15)
  set_text_color(tip.special_title, { 255, 232, 44, 255 })
  set_text_alignment(tip.special_title, '左', '中')
  set_font_size(tip.special, 15)
  set_text_color(tip.special, { 146, 219, 255, 255 })
  set_text_alignment(tip.special, '左', '上')

  set_font_size(tip.obtain_title, 15)
  set_text_color(tip.obtain_title, { 255, 232, 44, 255 })
  set_text_alignment(tip.obtain_title, '左', '中')
  set_font_size(tip.obtain, 14)
  set_text_color(tip.obtain, { 178, 183, 194, 255 })
  set_text_alignment(tip.obtain, '左', '上')
  return true
end

local function normalize_key(text)
  return tostring(text or ''):gsub('%s+', ''):gsub('商城', '')
end

local function get_spec_owned_display(spec, fallback)
  local text = tostring((spec and spec.owned_text) or ''):gsub('^%s+', ''):gsub('%s+$', '')
  if text ~= '' then
    return text
  end
  return tostring(fallback or '')
end

local function resolve_active_group_key(shop, state, all_category)
  local section = tostring(state and state.archive_panel_section or '')
  local active_group_key = normalize_key(get_category(state))
  local primary_group_key = normalize_key(get_primary(state))
  if section == 'career' then
    active_group_key = normalize_key(tostring(state and state.archive_panel_career_tab or CAREER_TAB_LABELS[1]))
  end
  if active_group_key == '' or active_group_key == normalize_key(all_category) then
    if section == 'career' then
      active_group_key = normalize_key(tostring(state and state.archive_panel_career_tab or CAREER_TAB_LABELS[1]))
    else
      active_group_key = primary_group_key
    end
  end
  if active_group_key == '' then
    active_group_key = normalize_key((shop.middle_groups and shop.middle_groups[1] and shop.middle_groups[1].name) or '')
  end
  local group_exists = false
  for _, group in ipairs(shop.middle_groups or {}) do
    if normalize_key(group.name) == active_group_key then
      group_exists = true
      break
    end
  end
  if not group_exists then
    local primary_group_exists = false
    if primary_group_key ~= '' then
      for _, group in ipairs(shop.middle_groups or {}) do
        if normalize_key(group.name) == primary_group_key then
          primary_group_exists = true
          break
        end
      end
    end
    if primary_group_exists then
      active_group_key = primary_group_key
    else
      active_group_key = normalize_key((shop.middle_groups and shop.middle_groups[1] and shop.middle_groups[1].name) or '')
    end
  end
  return active_group_key
end

local function get_group_template(options, group_name, visible_items)
  local mode = ''
  local first = type(visible_items) == 'table' and visible_items[1] or nil
  if first then
    mode = tostring(first.render_mode or '')
  end
  if mode == 'icon_num' then
    return { icon = true, num = true, label = 'title' }
  elseif mode == 'num' then
    return { num = true, label = 'title' }
  elseif mode == 'lv' then
    return { lv = true, label = 'quality' }
  elseif mode == 'icon' then
    return { icon = true, label = 'title' }
  end
  local templates = options and options.group_templates or nil
  local tpl = templates and templates[group_name] or nil
  if type(tpl) ~= 'table' then
    return { icon = true, label = 'title' }
  end
  return tpl
end

local function find_best_spec(items, wanted_key)
  if type(items) ~= 'table' or #items == 0 then
    return nil
  end
  if wanted_key and wanted_key ~= '' then
    for _, spec in ipairs(items) do
      if spec.key == wanted_key then
        return spec
      end
    end
  end
  return items[1]
end

local function refresh_career_tip(state, shop)
  local tip = shop and shop.tip or nil
  if not tip then
    return
  end
  local tab = tostring(state and state.archive_panel_career_tab or CAREER_TAB_LABELS[1])
  if tab == '' then
    tab = CAREER_TAB_LABELS[1]
    if state then
      state.archive_panel_career_tab = tab
    end
  end
  local detail = CAREER_TAB_DETAILS[tab] or CAREER_TAB_DETAILS[CAREER_TAB_LABELS[1]]
  set_visible(tip.root, true)
  set_text(tip.title, detail.title or '')
  set_text(tip.owned, detail.owned or '')
  set_text(tip.detail_title, detail.detail_title or '')
  set_text(tip.detail, detail.detail or '')
  set_text(tip.special_title, detail.special_title or '')
  set_text(tip.special, detail.special or '')
  set_text(tip.obtain_title, detail.obtain_title or '')
  set_text(tip.obtain, detail.obtain or '')
end

local function pick_group_spec(items, group_name)
  local key = normalize_key(group_name)
  for _, spec in ipairs(items or {}) do
    if normalize_key(spec.primary) == key then
      return spec
    end
  end
  for _, spec in ipairs(items or {}) do
    if normalize_key(spec.category) == key then
      return spec
    end
  end
  return items and items[1] or nil
end

local function select_spec_by_group(options, group_name)
  local state = options and options.state or nil
  if not state then
    return nil
  end
  local specs = options.specs or {}
  local visible_items = get_visible_items(state, specs)
  local spec = pick_group_spec(visible_items, group_name)
  if spec then
    state.archive_panel_shop_item = spec.key
  end
  return spec
end

local function refresh_middle_shop_groups(shop, state, in_shop_section, visible_items, options)
  local section = tostring(state and state.archive_panel_section or '')
  local in_shop_like_section = in_shop_section or section == 'archive'
  local groups = shop.middle_groups or {}
  local all_category = get_all_category_label(options)
  local active_group_key = resolve_active_group_key(shop, state, all_category)
  for _, group in ipairs(groups) do
    local group_key = normalize_key(group.name)
    local is_active_group = active_group_key ~= '' and group_key == active_group_key
    set_visible(group.root, in_shop_like_section and is_active_group)
    if in_shop_like_section and is_active_group then
      local spec = pick_group_spec(visible_items, group.name)
      local tpl = get_group_template(options, group.name, visible_items)
      local show_icon = tpl.icon == true
      local show_lv = tpl.lv == true
      local show_num = tpl.num == true
      set_visible(group.icon, show_icon)
      set_visible(group.lv, show_lv)
      set_visible(group.num, show_num)
      set_visible(group.label, true)

      if show_icon and is_ui_alive(group.icon) then
        local icon = spec and (spec.icon or spec.default_icon) or 906565
        set_image(group.icon, icon)
      end

      if is_ui_alive(group.label) then
        if show_icon then
          set_text(group.label, spec and tostring(spec.title or group.name) or group.name)
        elseif show_lv then
          local quality = spec and tostring(spec.quality or '') or ''
          set_text(group.label, quality ~= '' and ('品质 ' .. quality) or '地图等级')
        elseif show_num then
          set_text(group.label, spec and tostring(spec.title or group.name) or group.name)
        else
          set_text(group.label, group.name)
        end
      end

      if show_lv and is_ui_alive(group.lv) then
        local level_text = spec and tostring(spec.quality or '') or ''
        set_text(group.lv, level_text ~= '' and level_text or 'LV.1')
      end

      if show_num and is_ui_alive(group.num) then
        set_text(group.num, get_spec_owned_display(spec, #(visible_items or {})))
      end
    else
      set_visible(group.icon, false)
      set_visible(group.lv, false)
      set_visible(group.num, false)
    end
  end
end

local function resolve_group_slot(player, base, index)
  local candidates = {}
  if index == 1 then
    -- 首格优先使用编号格子，避免命中分组容器 bg 导致“首个商品变大”。
    candidates = { 'bg_7', 'bg_1', 'bg' }
  else
    candidates = {
      'bg_' .. tostring(index + 6),
      'bg_' .. tostring(index - 1),
      'bg_' .. tostring(index),
    }
  end

  for _, node in ipairs(candidates) do
    local root = resolve_ui(player, base .. '.' .. node)
    if is_ui_alive(root) then
      local icon = resolve_ui(player, base .. '.' .. node .. '.image')
      local label = resolve_ui(player, base .. '.' .. node .. '.label')
      local lv = resolve_ui(player, base .. '.' .. node .. '.lv')
      local num = resolve_ui(player, base .. '.' .. node .. '.num')
      if is_ui_alive(icon) or is_ui_alive(label) or is_ui_alive(lv) or is_ui_alive(num) then
        return {
          root = root,
          icon = icon,
          label = label,
          lv = lv,
          num = num,
        }
      end
    end
  end
  return nil
end

local function apply_group_slot(slot, group_name, spec, index, total)
  if not is_ui_alive(slot and slot.root) then
    return
  end
  local tpl = get_group_template(slot.options, group_name, { spec })
  set_visible(slot.root, true)
  local show_icon = tpl.icon == true
  local show_lv = tpl.lv == true
  local show_num = tpl.num == true
  set_visible(slot.icon, show_icon)
  set_visible(slot.lv, show_lv)
  set_visible(slot.num, show_num)
  set_visible(slot.label, true)
  if is_ui_alive(slot.root) and slot.root.set_image and spec and spec.bg then
    set_image(slot.root, spec.bg)
  end
  if show_icon then
    set_image(slot.icon, spec and (spec.icon or spec.default_icon) or DEFAULT_ICON)
    set_text(slot.label, spec and tostring(spec.title or group_name) or group_name)
  end
  if show_lv then
    local quality = spec and tostring(spec.quality or '') or ''
    if tpl.label == 'quality' then
      set_text(slot.label, quality ~= '' and ('品质 ' .. quality) or '地图等级')
    else
      set_text(slot.label, spec and tostring(spec.title or group_name) or group_name)
    end
    set_text(slot.lv, 'LV.' .. tostring(index))
  end
  if show_num then
    set_text(slot.label, spec and tostring(spec.title or '当前筛选') or '当前筛选')
    set_text(slot.num, get_spec_owned_display(spec, total))
  end
end

local function clear_runtime_group_items(group)
  if type(group.runtime_items) ~= 'table' then
    group.runtime_items = {}
    return
  end
  for _, item in ipairs(group.runtime_items) do
    if is_ui_alive(item.root) and item.root.remove then
      pcall(item.root.remove, item.root)
    end
  end
  group.runtime_items = {}
end

local function create_runtime_group_item(group, spec, index, options, total)
  if not (is_ui_alive(group.root) and group.root.create_child) then
    return nil
  end
  local tpl = get_group_template(options, group.name, { spec })
  local cell = group.root:create_child('布局')
  if not is_ui_alive(cell) then
    return nil
  end
  if cell.set_ui_size then
    cell:set_ui_size(84, 82)
  end
  if cell.set_anchor then
    cell:set_anchor(0.5, 0.5)
  end
  local bg = cell:create_child('图片')
  if is_ui_alive(bg) then
    if bg.set_image and spec and spec.bg then
      bg:set_image(spec.bg)
    end
    if bg.set_ui_size then
      bg:set_ui_size(84, 82)
    end
    if bg.set_pos then
      bg:set_pos(42, 41)
    end
  end
  local icon = nil
  local label = nil
  local lv = nil
  local num = nil

  if tpl.icon == true then
    icon = cell:create_child('图片')
    if is_ui_alive(icon) then
      if icon.set_image then
        icon:set_image(spec.icon or spec.default_icon or DEFAULT_ICON)
      end
      if icon.set_ui_size then
        icon:set_ui_size(52, 52)
      end
      if icon.set_pos then
        icon:set_pos(42, 49)
      end
    end
    label = cell:create_child('文本')
    if is_ui_alive(label) then
      if label.set_text then
        label:set_text(tostring(spec.title or '未命名商品'))
      end
      if label.set_font_size then
        label:set_font_size(14)
      end
      if label.set_text_alignment then
        label:set_text_alignment('中', '中')
      end
      if label.set_ui_size then
        label:set_ui_size(82, 24)
      end
      if label.set_pos then
        label:set_pos(42, 12)
      end
    end
  end
  if tpl.lv == true then
    label = cell:create_child('文本')
    if is_ui_alive(label) then
      if label.set_text then
        label:set_text('地图等级')
      end
      if label.set_font_size then
        label:set_font_size(16)
      end
      if label.set_text_alignment then
        label:set_text_alignment('中', '中')
      end
      if label.set_ui_size then
        label:set_ui_size(82, 30)
      end
      if label.set_pos then
        label:set_pos(42, 52)
      end
    end
    lv = cell:create_child('文本')
    if is_ui_alive(lv) then
      if lv.set_text then
        lv:set_text('LV.' .. tostring(index))
      end
      if lv.set_font_size then
        lv:set_font_size(20)
      end
      if lv.set_text_alignment then
        lv:set_text_alignment('中', '中')
      end
      if lv.set_ui_size then
        lv:set_ui_size(82, 30)
      end
      if lv.set_pos then
        lv:set_pos(42, 24)
      end
    end
  end
  if tpl.num == true then
    label = cell:create_child('文本')
    if is_ui_alive(label) then
      if label.set_text then
        label:set_text(tostring(spec.title or group.name or '当前筛选'))
      end
      if label.set_font_size then
        label:set_font_size(14)
      end
      if label.set_text_alignment then
        label:set_text_alignment('中', '中')
      end
      if label.set_ui_size then
        label:set_ui_size(82, 28)
      end
      if label.set_pos then
        label:set_pos(42, 50)
      end
    end
    num = cell:create_child('文本')
    if is_ui_alive(num) then
      if num.set_text then
        num:set_text(get_spec_owned_display(spec, total or index))
      end
      if num.set_font_size then
        num:set_font_size(18)
      end
      if num.set_text_alignment then
        num:set_text_alignment('中', '中')
      end
      if num.set_ui_size then
        num:set_ui_size(82, 26)
      end
      if num.set_pos then
        num:set_pos(42, 22)
      end
    end
  end
  if group.root.insert_ui_gridview_comp then
    pcall(group.root.insert_ui_gridview_comp, group.root, cell, index)
  end
  return { root = cell, spec = spec, icon = icon, label = label, lv = lv, num = num }
end

local function count_static_slots(player, group, max_probe)
  local limit = math.max(1, tonumber(max_probe) or 256)
  local count = 0
  for i = 1, limit do
    local slot = resolve_group_slot(player, group.base, i)
    if not is_ui_alive(slot and slot.root) then
      break
    end
    count = i
  end
  return count
end

local function bind_slot_click(slot, ui, options)
  if not is_ui_alive(slot and slot.root) then
    return
  end
  if SLOT_BOUND[slot.root] == true then
    return
  end
  SLOT_BOUND[slot.root] = true
  set_intercepts(slot.root, true)
  slot.root:add_fast_event('左键-按下', function()
    local section = tostring(options.state.archive_panel_section or '')
    if section ~= 'shop' and section ~= 'archive' and section ~= 'career' then
      return
    end
    local spec_key = SLOT_SPEC_KEY[slot.root]
    if not spec_key or spec_key == '' then
      return
    end
    options.state.archive_panel_shop_item = spec_key
    local selected_spec = nil
    for _, one in ipairs(options.specs or {}) do
      if one.key == spec_key then
        selected_spec = one
        break
      end
    end
    if options.play_ui_click then
      options.play_ui_click()
    end
    -- 点击条目只刷新右侧详情，避免触发列表重算导致其它条目被误隐藏。
    if selected_spec then
      refresh_tip(options.state, ui.shop, selected_spec)
    end
  end)
end

local function refresh_group_dynamic_items(ui, shop, options, visible_items)
  local player = options and options.player or nil
  local state = options and options.state or nil
  local all_category = get_all_category_label(options)
  if not player then
    return
  end
  local active_group_key = resolve_active_group_key(shop, state, all_category)
  for _, group in ipairs(shop.middle_groups or {}) do
    local active = normalize_key(group.name) == active_group_key
    -- 列表项只受“分区+一级页签+二级页签”控制，不再按分组名二次过滤，
    -- 否则点击刷新后会出现同页签内商品被误隐藏的问题。
    local group_items = visible_items or {}

    local static_slot_count = count_static_slots(player, group, math.max(32, #group_items + 4))
    local use_runtime_only = static_slot_count <= 1
    local effective_static_slot_count = use_runtime_only and 0 or static_slot_count
    local overflow_count = math.max(0, #group_items - effective_static_slot_count)
    local need_runtime_creation = overflow_count > 0

    if active and is_ui_alive(group.root) then
      if group.root.set_ui_gridview_scroll then
        pcall(group.root.set_ui_gridview_scroll, group.root, true)
      end
      if need_runtime_creation then
        local signature = tostring(get_primary(state) or '') .. '|' .. tostring(get_category(state) or '') .. '|' .. tostring(#group_items) .. '|' .. tostring(effective_static_slot_count)
        if group.runtime_signature ~= signature then
          group.runtime_signature = signature
          clear_runtime_group_items(group)
          for i = 1, overflow_count do
            local spec_index = effective_static_slot_count + i
            local item = create_runtime_group_item(group, group_items[spec_index], spec_index, options, #group_items)
            if item then
              SLOT_SPEC_KEY[item.root] = item.spec and item.spec.key or nil
              bind_slot_click(item, ui, options)
              group.runtime_items[#group.runtime_items + 1] = item
            end
          end
        end
      end
    else
      group.runtime_signature = nil
      clear_runtime_group_items(group)
    end

    local max_slots = math.max(12, effective_static_slot_count)
    for i = 1, max_slots do
      local slot = resolve_group_slot(player, group.base, i)
      if is_ui_alive(slot and slot.root) then
        if use_runtime_only and i == 1 then
          SLOT_SPEC_KEY[slot.root] = nil
          set_visible(slot.root, false)
          goto continue_slot
        end
        if active and (not use_runtime_only) and i <= effective_static_slot_count and i <= #group_items then
          local spec = group_items[i]
          slot.options = options
          apply_group_slot(slot, group.name, spec, i, #group_items)
          SLOT_SPEC_KEY[slot.root] = spec and spec.key or nil
          bind_slot_click(slot, ui, options)
        else
          SLOT_SPEC_KEY[slot.root] = nil
          set_visible(slot.root, false)
        end
      end
      ::continue_slot::
    end
  end
end

local function schedule_next_tick_shop_refresh(ui, options, signature)
  local shop = ui and ui.shop
  if not shop then
    return
  end
  shop.deferred_refresh_signature = signature
  if shop.deferred_refresh_pending == true then
    return
  end
  if not (y3 and y3.ltimer and y3.ltimer.wait) then
    return
  end
  shop.deferred_refresh_pending = true
  y3.ltimer.wait(0, function()
    local s = ui and ui.shop
    if not s then
      return
    end
    s.deferred_refresh_pending = false
    local section = tostring((options.state and options.state.archive_panel_section) or '')
    if section ~= 'shop' and section ~= 'archive' then
      return
    end
    M.refresh(ui, options)
  end)
end

function M.refresh(ui, options)
  local shop = ui and ui.shop
  if not shop then
    return false
  end
  local state = options.state
  state.archive_shop_options = options
  local section = tostring(state and state.archive_panel_section or '')
  local in_main_section = section == 'main' or section == 'archive' or section == 'career' or section == 'shop'
  local in_shop_section = section == 'shop'
  local in_shop_like_section = in_shop_section or section == 'archive' or section == 'career'
  local in_career_section = section == 'career'
  local in_archive_section = section == 'archive'
  local specs = options.specs or {}
  local primary_tabs, categories = ensure_selection(state, options, specs)
  if in_shop_like_section then
    local primary_valid = false
    for _, p in ipairs(primary_tabs or {}) do
      if p == state.archive_panel_shop_primary then
        primary_valid = true
        break
      end
    end
    if not primary_valid then
      state.archive_panel_shop_primary = primary_tabs and primary_tabs[1] or state.archive_panel_shop_primary
      categories = get_categories_for_primary(state, options, specs, state.archive_panel_shop_primary)
      state.archive_panel_shop_category = categories[1]
      state.archive_panel_shop_item = nil
    end
  end
  local visible_items = get_visible_items(state, specs)
  if not in_shop_like_section then
    state.archive_panel_shop_item = nil
  end

  -- 商品网格与具体样式改为中间内容静态节点承载，这里不再动态刷 icon 列表。
  for _, entry in ipairs(shop.items or {}) do
    set_visible(entry.root, false)
  end

  for index, entry in ipairs(shop.primary_tabs or {}) do
    local current_primary = primary_tabs[index]
    entry.primary = current_primary
    set_visible(entry.root, in_main_section)
    if in_shop_like_section then
      set_visible(entry.root, current_primary ~= nil)
      set_text(entry.label, current_primary or entry.raw_label or '')
      local selected = current_primary ~= nil and current_primary == get_primary(state)
      set_image_color(entry.bg, selected and { 183, 137, 48, 244 } or { 64, 68, 80, 230 })
      set_text_color(entry.label, selected and { 255, 247, 232, 255 } or { 218, 222, 232, 255 })
    elseif in_career_section then
      local index = entry.index or 0
      local tab_label = CAREER_TAB_LABELS[index]
      local selected = (state.archive_panel_career_tab or CAREER_TAB_LABELS[1]) == tab_label
      set_visible(entry.root, tab_label ~= nil)
      if tab_label then
        set_text(entry.label, tab_label)
      end
      set_image_color(entry.bg, selected and { 183, 137, 48, 244 } or { 64, 68, 80, 230 })
      set_text_color(entry.label, selected and { 255, 247, 232, 255 } or { 218, 222, 232, 255 })
    else
      if entry.raw_label and entry.raw_label ~= '' then
        set_text(entry.label, entry.raw_label)
      end
      set_image_color(entry.bg, { 64, 68, 80, 230 })
      set_text_color(entry.label, { 218, 222, 232, 255 })
    end
  end
  -- 二级页签槽位不足时，动态补齐，确保 UB/UR/全部都可见。
  local static_count = shop.secondary_static_count or #(shop.secondary_tabs or {})
  local total_needed = #categories
  local current_total = #(shop.secondary_tabs or {})
  if total_needed > current_total then
    for i = current_total + 1, total_needed do
      create_runtime_secondary_tab(ui, options, categories[i])
    end
  elseif total_needed < current_total and current_total > static_count then
    clear_runtime_secondary_tabs(shop)
    while #(shop.secondary_tabs or {}) > static_count do
      table.remove(shop.secondary_tabs)
    end
  end

  for index, entry in ipairs(shop.secondary_tabs or {}) do
    local category = categories[index]
    entry.category = category
    set_visible(entry.root, in_main_section and ((in_shop_like_section and category ~= nil) or (not in_shop_like_section and not in_career_section)))
    if in_shop_like_section and category then
      set_text(entry.label, category)
    elseif (not in_shop_like_section) and entry.raw_label and entry.raw_label ~= '' then
      set_text(entry.label, entry.raw_label)
    end
  end

  for _, entry in ipairs(shop.secondary_tabs or {}) do
    if in_shop_like_section then
      local selected = entry.category == get_category(state)
      set_image_color(entry.bg, selected and { 183, 137, 48, 244 } or { 64, 68, 80, 230 })
      set_text_color(entry.label, selected and { 255, 247, 232, 255 } or { 218, 222, 232, 255 })
    elseif not in_career_section then
      set_image_color(entry.bg, { 64, 68, 80, 230 })
      set_text_color(entry.label, { 218, 222, 232, 255 })
    else
      set_visible(entry.root, false)
    end
  end

  refresh_middle_shop_groups(shop, state, in_shop_like_section, visible_items, options)
  if in_shop_like_section then
    refresh_group_dynamic_items(ui, shop, options, visible_items)
  end

  if shop.tip then
    local tip = shop.tip
    set_visible(tip.root, in_shop_section or in_career_section)
    if in_shop_section or in_archive_section then
      local selected_spec = find_best_spec(visible_items, state.archive_panel_shop_item)
      if selected_spec then
        refresh_tip(state, shop, selected_spec)
      else
        state.archive_panel_shop_item = nil
      end
      if not selected_spec then
        set_text(tip.title, '')
        set_text(tip.owned, '')
        set_text(tip.detail_title, '')
        set_text(tip.detail, '')
        set_text(tip.special_title, '')
        set_text(tip.special, '')
        set_text(tip.obtain_title, '')
        set_text(tip.obtain, '')
      end
    elseif in_career_section then
      local selected_spec = find_best_spec(visible_items, state.archive_panel_shop_item)
      if selected_spec then
        refresh_tip(state, shop, selected_spec)
      else
        refresh_career_tip(state, shop)
      end
    else
      set_text(tip.title, '')
      set_text(tip.owned, '')
      set_text(tip.detail_title, '')
      set_text(tip.detail, '')
      set_text(tip.special_title, '')
      set_text(tip.special, '')
      set_text(tip.obtain_title, '')
      set_text(tip.obtain, '')
    end
  end

  if in_shop_like_section then
    local current_signature = table.concat({
      tostring(state.archive_panel_shop_primary or ''),
      tostring(state.archive_panel_shop_category or ''),
      tostring(#(visible_items or {})),
    }, '|')
    if shop.last_render_signature ~= current_signature then
      shop.last_render_signature = current_signature
      schedule_next_tick_shop_refresh(ui, options, current_signature)
    end
  else
    shop.last_render_signature = nil
  end
  return true
end

function M.ensure(ui, options)
  if not (ui and ui.variant == 'archive_main_v2') then
    return false
  end
  if ui.shop_initialized == true then
    return true
  end

  local player = options.player
  local specs = options.specs or {}
  local grid = nil
  ui.shop = {
    grid = grid,
    tip = resolve_tip(player),
    items = {},
    primary_tabs = {},
    secondary_tabs = {},
    runtime_secondary_tabs = {},
    secondary_static_count = 0,
    secondary_tab_grid_root = nil,
    deferred_refresh_pending = false,
    deferred_refresh_signature = nil,
    last_render_signature = nil,
    middle_groups = {},
  }

  local group_name_aliases = {
    ['仓库'] = { '仓库' },
    ['商品'] = { '商品' },
    ['皮肤'] = { '皮肤' },
    ['翅膀'] = { '翅膀' },
    ['地图等级'] = { '地图等级' },
    ['荣誉等级'] = { '荣誉等级', '典藏积分' },
    ['成就'] = { '成就' },
    ['英雄图鉴'] = { '英雄图鉴' },
    ['羁绊图鉴'] = { '羁绊图鉴' },
    ['称号'] = { '称号' },
  }
  for _, name in ipairs({ '仓库', '商品', '皮肤', '翅膀', '地图等级', '荣誉等级', '成就', '英雄图鉴', '羁绊图鉴', '称号' }) do
    local aliases = group_name_aliases[name] or { name }
    local base = nil
    local root = nil
    for _, alias in ipairs(aliases) do
      local base_candidates = {
        'ArchiveMain.存档生涯商城.中间内容.商城.' .. alias,
        'ArchiveMain.存档生涯商城.中间内容.存档.' .. alias,
        'ArchiveMain.存档生涯商城.中间内容.生涯.' .. alias,
        'ArchivePanel.存档生涯商城.中间内容.商城.' .. alias,
        'ArchivePanel.存档生涯商城.中间内容.存档.' .. alias,
        'ArchivePanel.存档生涯商城.中间内容.生涯.' .. alias,
      }
      for _, one_base in ipairs(base_candidates) do
        base = one_base
        root = resolve_ui(player, one_base)
        if is_ui_alive(root) then
          break
        end
      end
      if is_ui_alive(root) then
        break
      end
    end
    if is_ui_alive(root) then
      ui.shop.middle_groups[#ui.shop.middle_groups + 1] = {
        name = name,
        base = base,
        root = root,
        icon = resolve_ui(player, base .. '.bg.image'),
        label = resolve_ui(player, base .. '.bg.label'),
        lv = resolve_ui(player, base .. '.bg.lv'),
        num = resolve_ui(player, base .. '.bg.num'),
      }
      local entry = ui.shop.middle_groups[#ui.shop.middle_groups]
      local click_target = resolve_ui(player, base .. '.bg') or root
      if is_ui_alive(click_target) then
        set_intercepts(click_target, true)
        click_target:add_fast_event('左键-按下', function()
          local section = tostring(options.state.archive_panel_section or '')
          if section ~= 'shop' and section ~= 'archive' then
            return
          end
          if options.play_ui_click then
            options.play_ui_click()
          end
          select_spec_by_group(options, entry.name)
          M.refresh(ui, options)
        end)
      end
    end
  end

  if is_ui_alive(grid) then
    hide_static_slots(player)

    local column_count = 6
    local row_count = math.max(1, math.ceil(#specs / column_count))
    if grid.set_ui_gridview_count then
      grid:set_ui_gridview_count(row_count, column_count)
    end
    if grid.set_ui_gridview_size then
      grid:set_ui_gridview_size(136, 156)
    end
    if grid.set_ui_gridview_space then
      grid:set_ui_gridview_space(12, 14)
    end
    if grid.set_ui_gridview_scroll then
      grid:set_ui_gridview_scroll(true)
    end

    for index, spec in ipairs(specs) do
      local instance = create_prefab(player, grid, 'ArchiveDaoJv', index)
      local root = instance and instance.root or nil
      if is_ui_alive(root) then
        local bg = get_prefab_child(instance, 'btn.bg') or get_ui_child(root, 'btn.bg')
        local icon = get_prefab_child(instance, 'btn.icon') or get_ui_child(root, 'btn.icon')
        local name = get_prefab_child(instance, 'btn.name') or get_ui_child(root, 'btn.name')
        local trigger = is_ui_alive(bg) and bg or root
        local entry = {
          spec = spec,
          root = root,
          bg = bg,
          icon = icon,
          name = name,
        }
        ui.shop.items[#ui.shop.items + 1] = entry
        set_intercepts(trigger, true)
        trigger:add_fast_event('左键-按下', function()
          if options.play_ui_click then
            options.play_ui_click()
          end
          refresh_tip(options.state, ui.shop, entry.spec)
        end)
        trigger:add_fast_event('鼠标-移入', function()
          refresh_tip(options.state, ui.shop, entry.spec)
        end)
      end
    end
  end

  local primary_root_seen = {}
  for _, base in ipairs(PRIMARY_TAB_BASE_PATHS) do
    local primary_paths = collect_tab_paths(base, 8)
    for index, path in ipairs(primary_paths) do
      local root = resolve_ui(player, path)
      if is_ui_alive(root) then
        local root_key = tostring(root.handle or path)
        if primary_root_seen[root_key] == true then
          goto continue_primary_path
        end
        primary_root_seen[root_key] = true
        local bg = resolve_ui(player, path .. '.button_1') or resolve_ui(player, path .. '.button') or root
        local label = resolve_ui(player, path .. '.label_1') or resolve_ui(player, path .. '.label')
        local raw_label = get_text(label)
        local entry = {
          primary = nil,
          index = index,
          root = root,
          bg = bg,
          label = label,
          raw_label = raw_label,
        }
        ui.shop.primary_tabs[#ui.shop.primary_tabs + 1] = entry
        if is_ui_alive(bg) then
          set_intercepts(bg, true)
          bg:add_fast_event('左键-按下', function()
            local current_section = tostring(options.state.archive_panel_section or '')
            if current_section ~= 'shop' and current_section ~= 'career' and current_section ~= 'archive' then
              return
            end
            if current_section == 'career' then
              local target_tab = CAREER_TAB_LABELS[index] or CAREER_TAB_LABELS[1]
              if tostring(options.state.archive_panel_career_tab or '') == tostring(target_tab or '') then
                return
              end
              if options.play_ui_click then
                options.play_ui_click()
              end
              options.state.archive_panel_career_tab = target_tab
              M.refresh(ui, options)
              return
            end
            local target_primary = entry.primary
            if not target_primary or target_primary == '' then
              return
            end
            if tostring(options.state.archive_panel_shop_primary or '') == tostring(target_primary or '') then
              return
            end
            if options.play_ui_click then
              options.play_ui_click()
            end
            options.state.archive_panel_shop_primary = target_primary
            options.state.archive_panel_shop_category = nil
            options.state.archive_panel_shop_item = nil
            M.refresh(ui, options)
          end)
        end
      end
      ::continue_primary_path::
    end
  end

  for _, base in ipairs(SECONDARY_TAB_BASE_PATHS) do
    local category_paths = collect_tab_paths(base, 8)
    for _, path in ipairs(category_paths) do
      local root = resolve_ui(player, path)
      if is_ui_alive(root) then
        local bg = resolve_ui(player, path .. '.button_1') or resolve_ui(player, path .. '.button') or root
        local label = resolve_ui(player, path .. '.label_1') or resolve_ui(player, path .. '.label')
        local entry = {
          category = nil,
          root = root,
          bg = bg,
          label = label,
          raw_label = get_text(label),
        }
        ui.shop.secondary_tabs[#ui.shop.secondary_tabs + 1] = entry
        if is_ui_alive(bg) then
          set_intercepts(bg, true)
          bg:add_fast_event('左键-按下', function()
            local section = tostring(options.state.archive_panel_section or '')
            if section ~= 'shop' and section ~= 'archive' then
              return
            end
            if not entry.category then
              return
            end
            if tostring(options.state.archive_panel_shop_category or '') == tostring(entry.category or '') then
              return
            end
            if options.play_ui_click then
              options.play_ui_click()
            end
            options.state.archive_panel_shop_category = entry.category
            options.state.archive_panel_shop_item = nil
            M.refresh(ui, options)
          end)
        end
      end
    end
  end
  ui.shop.secondary_static_count = #(ui.shop.secondary_tabs or {})
  local secondary_tab_grid_root = resolve_ui_first(player, SECONDARY_TAB_GRID_PATHS)
  ui.shop.secondary_tab_grid_root = secondary_tab_grid_root

  ui.shop_initialized = true
  M.refresh(ui, options)
  return true
end

return M
