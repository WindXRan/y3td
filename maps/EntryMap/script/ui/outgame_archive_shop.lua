local M = {}

local DEFAULT_ICON = 906565
local GRID_BASE_PATH = 'ArchiveMain.layout_1.scroll_view_main.scroll_view_1.ArchiveGridView.grid_view_1.'

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
    set_visible(resolve_ui(player, GRID_BASE_PATH .. name), false)
  end
end

local function collect_tab_paths(base_path, max_extra)
  local paths = { base_path }
  for index = 1, max_extra or 8 do
    paths[#paths + 1] = string.format('%s_%d', base_path, index)
  end
  return paths
end

local function resolve_tip(player)
  local tip_path = 'ArchiveMain.layout_1.scroll_view_main.scroll_view_1.ArchiveTips.scroll_view'
  return {
    root = resolve_ui(player, 'ArchiveMain.layout_1.scroll_view_main.scroll_view_1.ArchiveTips'),
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

local function get_primary_tabs(options, specs)
  local tabs = {}
  local seen = {}
  for _, primary in ipairs(options.primary_tabs or {}) do
    if primary and primary ~= '' and seen[primary] ~= true then
      seen[primary] = true
      tabs[#tabs + 1] = primary
    end
  end
  for _, spec in ipairs(specs or {}) do
    local primary = spec.primary
    if primary and primary ~= '' and seen[primary] ~= true then
      seen[primary] = true
      tabs[#tabs + 1] = primary
    end
  end
  if #tabs == 0 and options.primary_tab_label then
    tabs[1] = options.primary_tab_label
  end
  return tabs
end

local function get_categories_for_primary(options, specs, primary)
  local categories = {}
  local seen = {}
  local by_primary = options.categories_by_primary or {}
  for _, category in ipairs(by_primary[primary] or {}) do
    if category and category ~= '' and seen[category] ~= true then
      seen[category] = true
      categories[#categories + 1] = category
    end
  end
  if #categories == 0 then
    for _, spec in ipairs(specs or {}) do
      if spec.primary == primary then
        local category = spec.category
        if category and category ~= '' and seen[category] ~= true then
          seen[category] = true
          categories[#categories + 1] = category
        end
      end
    end
  end
  if #categories == 0 then
    for _, category in ipairs(options.categories or {}) do
      if category and category ~= '' and seen[category] ~= true then
        seen[category] = true
        categories[#categories + 1] = category
      end
    end
  end
  return categories
end

local function ensure_selection(state, options, specs)
  local primary_tabs = get_primary_tabs(options, specs)
  if (not state.archive_panel_shop_primary) or state.archive_panel_shop_primary == '' then
    state.archive_panel_shop_primary = primary_tabs[1]
  end
  local categories = get_categories_for_primary(options, specs, state.archive_panel_shop_primary)
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
  local primary = get_primary(state)
  local category = get_category(state)
  local items = {}
  for _, spec in ipairs(specs or {}) do
    local primary_ok = (not primary or primary == '' or spec.primary == primary)
    local category_ok = (not category or category == '' or spec.category == category)
    if primary_ok and category_ok then
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

function M.refresh(ui, options)
  local shop = ui and ui.shop
  if not shop then
    return false
  end
  local state = options.state
  local specs = options.specs or {}
  local _, categories = ensure_selection(state, options, specs)
  local visible_items = get_visible_items(state, specs)

  for index, entry in ipairs(shop.items or {}) do
    local spec = visible_items[index]
    entry.spec = spec
    set_visible(entry.root, spec ~= nil)
    if spec then
      local owned = is_owned(spec)
      set_image(entry.icon, spec.icon or options.default_icon or DEFAULT_ICON)
      set_text(entry.name, spec.title)
      set_image_color(entry.bg, owned and { 255, 255, 255, 255 } or { 92, 92, 92, 245 })
      set_image_color(entry.icon, owned and { 255, 255, 255, 255 } or { 120, 120, 120, 255 })
      set_text_color(entry.name, owned and { 245, 240, 228, 255 } or { 144, 144, 144, 255 })
    end
  end

  for _, entry in ipairs(shop.primary_tabs or {}) do
    local selected = entry.primary == get_primary(state)
    set_image_color(entry.bg, selected and { 183, 137, 48, 244 } or { 64, 68, 80, 230 })
    set_text_color(entry.label, selected and { 255, 247, 232, 255 } or { 218, 222, 232, 255 })
  end

  for index, entry in ipairs(shop.secondary_tabs or {}) do
    local category = categories[index]
    entry.category = category
    set_visible(entry.root, category ~= nil)
    if category then
      set_text(entry.label, category)
    end
  end

  for _, entry in ipairs(shop.secondary_tabs or {}) do
    local selected = entry.category == get_category(state)
    set_image_color(entry.bg, selected and { 183, 137, 48, 244 } or { 64, 68, 80, 230 })
    set_text_color(entry.label, selected and { 255, 247, 232, 255 } or { 218, 222, 232, 255 })
  end

  local selected_spec = nil
  for _, spec in ipairs(visible_items) do
    if spec.key == state.archive_panel_shop_item then
      selected_spec = spec
      break
    end
  end
  return refresh_tip(state, shop, selected_spec or visible_items[1])
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
  local grid = resolve_ui(player, 'ArchiveMain.layout_1.scroll_view_main.scroll_view_1.ArchiveGridView.grid_view_1')
  if not is_ui_alive(grid) then
    return false
  end

  hide_static_slots(player)
  ui.shop = {
    grid = grid,
    tip = resolve_tip(player),
    items = {},
    primary_tabs = {},
    secondary_tabs = {},
  }

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

  local primary_tabs = get_primary_tabs(options, specs)
  if (not options.state.archive_panel_shop_primary) or options.state.archive_panel_shop_primary == '' then
    options.state.archive_panel_shop_primary = primary_tabs[1]
  end
  local primary_paths = collect_tab_paths('ArchiveMain.layout_1.scroll_view_main.page_grid.ArchivePageOne', 8)
  for index, path in ipairs(primary_paths) do
    local primary = primary_tabs[index]
    local root = resolve_ui(player, path)
    if is_ui_alive(root) then
      local bg = resolve_ui(player, path .. '.button_1') or root
      local label = resolve_ui(player, path .. '.label_1')
      set_visible(root, primary ~= nil)
      if primary then
        set_text(label, primary)
        local entry = {
          primary = primary,
          root = root,
          bg = bg,
          label = label,
        }
        ui.shop.primary_tabs[#ui.shop.primary_tabs + 1] = entry
        if is_ui_alive(bg) then
          set_intercepts(bg, true)
          bg:add_fast_event('左键-按下', function()
            if options.play_ui_click then
              options.play_ui_click()
            end
            options.state.archive_panel_shop_primary = primary
            options.state.archive_panel_shop_category = nil
            options.state.archive_panel_shop_item = nil
            M.refresh(ui, options)
          end)
        end
      end
    end
  end

  local category_paths = collect_tab_paths('ArchiveMain.layout_1.scroll_view_main.page2_grid.ArchivePageTwo', 8)
  for _, path in ipairs(category_paths) do
    local root = resolve_ui(player, path)
    if is_ui_alive(root) then
      local bg = resolve_ui(player, path .. '.button_1') or root
      local label = resolve_ui(player, path .. '.label_1')
      local entry = {
        category = nil,
        root = root,
        bg = bg,
        label = label,
      }
      ui.shop.secondary_tabs[#ui.shop.secondary_tabs + 1] = entry
      if is_ui_alive(bg) then
        set_intercepts(bg, true)
        bg:add_fast_event('左键-按下', function()
          if not entry.category then
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

  ui.shop_initialized = true
  M.refresh(ui, options)
  return true
end

return M
