local M = {}

local DEFAULT_ICON = 906565

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

local function set_intercepts(ui, intercepts)
  if is_ui_alive(ui) and ui.set_intercepts_operations then
    ui:set_intercepts_operations(intercepts == true)
  end
end

local function get_prefab_child(prefab_instance, child_path)
  local prefab = prefab_instance and prefab_instance.prefab or nil
  if not (prefab and prefab.get_child) then
    return nil
  end
  local ok, child = pcall(prefab.get_child, prefab, child_path)
  if ok then
    return child
  end
  return nil
end

local function get_prefab_child_with_fallback(prefab_instance, child_path, ...)
  local child = get_prefab_child(prefab_instance, child_path)
  if is_ui_alive(child) then
    return child
  end
  local fallbacks = { ... }
  for _, path in ipairs(fallbacks) do
    child = get_prefab_child(prefab_instance, path)
    if is_ui_alive(child) then
      return child
    end
  end
  return nil
end

local function get_ui_child_with_fallback(ui, child_path, ...)
  if not (is_ui_alive(ui) and ui.get_child and child_path) then
    return nil
  end
  local ok, child = pcall(ui.get_child, ui, child_path)
  if ok and is_ui_alive(child) then
    return child
  end
  local fallbacks = { ... }
  for _, path in ipairs(fallbacks) do
    ok, child = pcall(ui.get_child, ui, path)
    if ok and is_ui_alive(child) then
      return child
    end
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
  if root and parent.insert_ui_gridview_comp then
    pcall(parent.insert_ui_gridview_comp, parent, root, child_index)
  end
  return {
    prefab = prefab,
    root = root,
  }
end

local function hide_static_slots(player)
  local base_path = 'ArchiveMain.layout_1.scroll_view_main.scroll_view_1.ArchiveGridView.grid_view_1.'
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
  for _, name in ipairs(names) do
    set_visible(resolve_ui(player, base_path .. name), false)
  end
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

local function get_category(state)
  return state.archive_panel_shop_category
end

local function get_visible_items(state, specs)
  local category = get_category(state)
  local items = {}
  for _, spec in ipairs(specs or {}) do
    if not category or category == '' or spec.category == category then
      items[#items + 1] = spec
    end
  end
  return items
end

local function refresh_tip(state, shop, spec)
  if not spec then
    return false
  end
  state.archive_panel_shop_item = spec.key
  local tip = shop.tip or {}
  set_visible(tip.root, true)
  set_text(tip.title, spec.title)
  set_text(tip.owned, spec.owned_text ~= '' and spec.owned_text or '未拥有')
  set_text(tip.detail_title, '详情效果')
  set_text(tip.detail, table.concat(spec.attr_lines or {}, '\n'))
  set_text(tip.special_title, '特殊效果')
  set_text(tip.special, spec.special_effect ~= '' and spec.special_effect or '暂无')
  set_text(tip.obtain_title, '获取方式')
  set_text(tip.obtain, spec.obtain ~= '' and spec.obtain or '暂无')
  return true
end

function M.refresh(ui, options)
  local shop = ui and ui.shop
  if not shop then
    return false
  end
  local state = options.state
  local specs = options.specs or {}
  local visible_items = get_visible_items(state, specs)
  for index, entry in ipairs(shop.items or {}) do
    local spec = visible_items[index]
    entry.spec = spec
    entry.icon = entry.icon or get_ui_child_with_fallback(entry.root, 'icon', 'ArchiveDaoJv.icon')
    entry.name = entry.name or get_ui_child_with_fallback(entry.root, 'name', 'ArchiveDaoJv.name')
    set_visible(entry.root, spec ~= nil)
    if spec then
      set_image(entry.icon, spec.icon or options.default_icon or DEFAULT_ICON)
      set_text(entry.name, spec.title)
    end
  end
  for _, entry in ipairs(shop.categories or {}) do
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
    categories = {},
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
      local entry = {
        spec = spec,
        root = root,
        icon = get_prefab_child_with_fallback(instance, 'icon', 'ArchiveDaoJv.icon')
          or get_ui_child_with_fallback(root, 'icon', 'ArchiveDaoJv.icon'),
        name = get_prefab_child_with_fallback(instance, 'name', 'ArchiveDaoJv.name')
          or get_ui_child_with_fallback(root, 'name', 'ArchiveDaoJv.name'),
      }
      ui.shop.items[#ui.shop.items + 1] = entry
      set_intercepts(root, true)
      root:add_fast_event('左键-按下', function()
        if options.play_ui_click then
          options.play_ui_click()
        end
        refresh_tip(options.state, ui.shop, entry.spec)
      end)
      root:add_fast_event('鼠标-移入', function()
        refresh_tip(options.state, ui.shop, entry.spec)
      end)
    end
  end

  local primary_path = 'ArchiveMain.layout_1.scroll_view_main.page_grid.ArchivePageOne'
  local primary_root = resolve_ui(player, primary_path)
  local primary_bg = resolve_ui(player, primary_path .. '.button_1') or primary_root
  local primary_label = resolve_ui(player, primary_path .. '.label_1')
  set_visible(primary_root, true)
  set_text(primary_label, '地图商城')
  set_image_color(primary_bg, { 183, 137, 48, 244 })
  set_text_color(primary_label, { 255, 247, 232, 255 })

  local category_paths = {
    'ArchiveMain.layout_1.scroll_view_main.page_grid.ArchivePageOne_1',
    'ArchiveMain.layout_1.scroll_view_main.page_grid.ArchivePageOne_2',
    'ArchiveMain.layout_1.scroll_view_main.page_grid.ArchivePageOne_3',
    'ArchiveMain.layout_1.scroll_view_main.page_grid.ArchivePageOne_4',
    'ArchiveMain.layout_1.scroll_view_main.page_grid.ArchivePageOne_5',
    'ArchiveMain.layout_1.scroll_view_main.page_grid.ArchivePageOne_6',
    'ArchiveMain.layout_1.scroll_view_main.page2_grid.ArchivePageTwo',
    'ArchiveMain.layout_1.scroll_view_main.page2_grid.ArchivePageTwo_1',
  }
  local categories = options.categories or {}
  if (not options.state.archive_panel_shop_category) and #categories > 0 then
    options.state.archive_panel_shop_category = categories[1]
  end
  for index, path in ipairs(category_paths) do
    local category = categories[index]
    local root = resolve_ui(player, path)
    local bg = resolve_ui(player, path .. '.button_1') or root
    local label = resolve_ui(player, path .. '.label_1')
    set_visible(root, category ~= nil)
    if category then
      set_text(label, category)
      ui.shop.categories[#ui.shop.categories + 1] = {
        category = category,
        root = root,
        bg = bg,
        label = label,
      }
      if is_ui_alive(bg) then
        set_intercepts(bg, true)
        bg:add_fast_event('左键-按下', function()
          if options.play_ui_click then
            options.play_ui_click()
          end
          options.state.archive_panel_shop_category = category
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
