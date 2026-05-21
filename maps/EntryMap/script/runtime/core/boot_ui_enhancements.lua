local CONFIG = require 'config.entry_config'
local QualityImageTable = require 'data.tables.economy.quality_image_table'
local IconResolver = require 'data.tables.icon_resolver'
require 'runtime.core.boot_utils'; local BootHelpers = _G.BootHelpers

local M = {}

local function resolve_display_icon(...)
  return IconResolver.pick(...)
end

function M.resolve_quality_frame_image(quality)
  if QualityImageTable and QualityImageTable.get_frame_image then
    local image = QualityImageTable.get_frame_image(quality)
    if image then
      return image
    end
  end

  local image_table = rawget(_G, 'quality_image_table') or rawget(_G, 'QUALITY_IMAGE_TABLE')
  if type(image_table) ~= 'table' then
    return nil
  end
  local key = tostring(quality or 'common')
  local lower_key = string.lower(key)
  local normalized_key = ({
    n = 'N',
    r = 'R',
    sr = 'SR',
    ssr = 'SSR',
    ur = 'UR',
    common = 'N',
    excellent = 'R',
    rare = 'SR',
    epic = 'SSR',
    legendary = 'UR',
    ['普通'] = 'N',
    ['优秀'] = 'R',
    ['稀有'] = 'SR',
    ['史诗'] = 'SSR',
    ['传说'] = 'UR',
  })[lower_key] or ({
    ['普通'] = 'N',
    ['优秀'] = 'R',
    ['稀有'] = 'SR',
    ['史诗'] = 'SSR',
    ['传说'] = 'UR',
  })[key]
  local cn_key = ({
    common = '普通',
    excellent = '优秀',
    rare = '稀有',
    epic = '史诗',
    legendary = '传说',
  })[lower_key]
  return image_table[key]
      or image_table[lower_key]
      or (normalized_key and image_table[normalized_key] or nil)
      or (normalized_key and image_table[string.lower(normalized_key)] or nil)
      or (cn_key and image_table[cn_key] or nil)
      or (lower_key == 'excellent' and (image_table.rare or image_table.SR or image_table.sr) or nil)
      or (lower_key == 'legendary' and (image_table.epic or image_table.UR or image_table.ur) or nil)
      or image_table.common
      or image_table.N
      or image_table.n
      or image_table['普通']
end

local function set_ui_visible(ui, visible)
  if ui and (not ui.is_removed or not ui:is_removed()) and ui.set_visible then
    ui:set_visible(visible == true)
  end
end

local function set_ui_image(ui, image)
  if ui and (not ui.is_removed or not ui:is_removed()) and ui.set_image and image and image ~= 0 then
    ui:set_image(image)
  end
end

local function set_ui_image_color(ui, color)
  if ui and (not ui.is_removed or not ui:is_removed()) and ui.set_image_color and color then
    ui:set_image_color(color[1] or 255, color[2] or 255, color[3] or 255, color[4] or 255)
  end
end

local function set_ui_text_color(ui, color)
  if ui and (not ui.is_removed or not ui:is_removed()) and ui.set_text_color and color then
    ui:set_text_color(color[1] or 255, color[2] or 255, color[3] or 255, color[4] or 255)
  end
end

local function set_ui_pos(ui, x, y)
  if ui and (not ui.is_removed or not ui:is_removed()) and ui.set_pos then
    ui:set_pos(x, y)
  end
end

local CHOICE_CARD_STYLE = {
  legendary = {
    normal = {
      bg = { 45, 30, 60, 225 },
      icon = { 255, 184, 64, 255 },
      title = { 255, 184, 64, 255 },
      subtitle = { 208, 140, 48, 255 },
      desc = { 180, 160, 140, 255 },
    },
    selected = {
      bg = { 80, 50, 100, 255 },
      icon = { 255, 220, 120, 255 },
      title = { 255, 220, 120, 255 },
      subtitle = { 255, 180, 80, 255 },
      desc = { 220, 200, 180, 255 },
    },
  },
  epic = {
    normal = {
      bg = { 50, 25, 80, 225 },
      icon = { 208, 62, 255, 255 },
      title = { 208, 62, 255, 255 },
      subtitle = { 160, 80, 220, 255 },
      desc = { 160, 140, 180, 255 },
    },
    selected = {
      bg = { 80, 40, 120, 255 },
      icon = { 230, 100, 255, 255 },
      title = { 230, 100, 255, 255 },
      subtitle = { 190, 120, 240, 255 },
      desc = { 190, 170, 210, 255 },
    },
  },
  rare = {
    normal = {
      bg = { 25, 50, 80, 225 },
      icon = { 45, 176, 255, 255 },
      title = { 45, 176, 255, 255 },
      subtitle = { 60, 140, 220, 255 },
      desc = { 140, 160, 180, 255 },
    },
    selected = {
      bg = { 40, 80, 120, 255 },
      icon = { 80, 200, 255, 255 },
      title = { 80, 200, 255, 255 },
      subtitle = { 100, 170, 240, 255 },
      desc = { 170, 190, 210, 255 },
    },
  },
  excellent = {
    normal = {
      bg = { 25, 50, 80, 225 },
      icon = { 45, 176, 255, 255 },
      title = { 45, 176, 255, 255 },
      subtitle = { 60, 140, 220, 255 },
      desc = { 140, 160, 180, 255 },
    },
    selected = {
      bg = { 40, 80, 120, 255 },
      icon = { 80, 200, 255, 255 },
      title = { 80, 200, 255, 255 },
      subtitle = { 100, 170, 240, 255 },
      desc = { 170, 190, 210, 255 },
    },
  },
  common = {
    normal = {
      bg = { 60, 65, 75, 225 },
      icon = { 200, 205, 210, 255 },
      title = { 220, 225, 230, 255 },
      subtitle = { 160, 165, 175, 255 },
      desc = { 140, 145, 155, 255 },
    },
    selected = {
      bg = { 90, 95, 105, 255 },
      icon = { 230, 235, 240, 255 },
      title = { 240, 245, 250, 255 },
      subtitle = { 190, 195, 205, 255 },
      desc = { 170, 175, 185, 255 },
    },
  },
}


local function resolve_choice_panel_card(scroll, index)
  if not scroll then
    return nil
  end
  local names
  if index == 1 then
    names = { 'Card1', 'Card_1' }
  elseif index == 2 then
    names = { 'Card2', 'Card_2' }
  elseif index == 3 then
    names = { 'Card3', 'Card_3' }
  else
    names = { 'Card4', 'Card_4' }
  end
  for _, name in ipairs(names) do
    local card = nil
    if scroll and scroll.get_child then
      local ok, child = pcall(scroll.get_child, scroll, name)
      if ok then
        card = child
      end
    end
    if card then
      return card
    end
  end
  return nil
end

local function resolve_ui_child(parent, child_name)
  if not parent or not child_name or not parent.get_child then
    return nil
  end
  local ok, child = pcall(parent.get_child, parent, child_name)
  if ok then
    return child
  end
  return nil
end

local card_positions = setmetatable({}, { __mode = 'k' })

local function apply_choice_card_style(card, selected, quality, skip_icon_color)
  if not card then
    return
  end
  local quality_style = CHOICE_CARD_STYLE[quality] or CHOICE_CARD_STYLE.common
  local style = selected and quality_style.selected or quality_style.normal
  local bg = resolve_ui_child(card, 'image_2')
  local icon = resolve_ui_child(card, 'image_2_1')
  local title = resolve_ui_child(card, 'title')
  local subtitle = resolve_ui_child(card, 'sub_title')
  local desc = resolve_ui_child(card, 'desc')
  set_ui_image_color(bg, style.bg)
  if not skip_icon_color then
    set_ui_image_color(icon, style.icon)
  end
  set_ui_text_color(title, style.title)
  set_ui_text_color(subtitle, style.subtitle)
  set_ui_text_color(desc, style.desc)
  if card.get_pos and card.set_pos then
    local pos = card:get_pos()
    if not card_positions[card] then
      card_positions[card] = { x = pos.x, y = pos.y }
    end
    local original = card_positions[card]
    if selected then
      card:set_pos(original.x, original.y - 20)
    else
      card:set_pos(original.x, original.y)
    end
  end
end

local function ensure_choice_list_choice_panel()
  local player
  if y3 and y3.player and y3.player.get_main_player then
    player = y3.player.get_main_player()
  elseif _G.get_player then
    player = _G.get_player()
  end
  if not player then
    return nil, nil, nil
  end
  local ok_root, root = pcall(y3.ui.get_ui, player, 'Choice_Panel')
  if not ok_root or not root then
    return nil, nil, nil
  end
  local ok_scroll, scroll = pcall(y3.ui.get_ui, player, 'Choice_Panel.ChoiceList.scroll_view')
  if not ok_scroll or not scroll then
    return nil, nil, nil
  end
  return root, scroll, player
end

local choice_click_bound = setmetatable({}, { __mode = 'k' })
local refresh_choice_selected_styles

local apply_round_choice_func = nil

function M.set_apply_round_choice(func)
  apply_round_choice_func = func
end

local function bind_choice_click_target(target, index)
  if not target or not target.add_fast_event then
    return
  end
  if choice_click_bound[target] then
    return
  end
  choice_click_bound[target] = true
  if target.set_intercepts_operations then
    target:set_intercepts_operations(true)
  end
  target:add_fast_event('左键-点击', function()
    STATE.choice_panel_selected_index = index
    if refresh_choice_selected_styles then
      refresh_choice_selected_styles()
    end
    if apply_round_choice_func then
      apply_round_choice_func(index)
    end
  end)
  target:add_fast_event('鼠标-移入', function()
    STATE.choice_panel_selected_index = index
    if refresh_choice_selected_styles then
      refresh_choice_selected_styles()
    end
  end)
  target:add_fast_event('鼠标-移出', function()
    if STATE.choice_panel_selected_index == index then
      STATE.choice_panel_selected_index = nil
    end
    if refresh_choice_selected_styles then
      refresh_choice_selected_styles()
    end
  end)
end

local function normalize_choice_text(value)
  local text = tostring(value or ''):gsub('\r\n', '\n'):gsub('\r', '\n')
  text = text:gsub('^%s+', ''):gsub('%s+$', '')
  return text
end

local function first_non_empty_choice_text(...)
  for index = 1, select('#', ...) do
    local text = normalize_choice_text(select(index, ...))
    if text ~= '' then
      return text
    end
  end
  return ''
end

local function choice_blocks_to_text(blocks)
  local lines = {}
  for _, block in ipairs(blocks or {}) do
    local text = normalize_choice_text(block and block.text or '')
    if text ~= '' then
      lines[#lines + 1] = text
    end
    if #lines >= 2 then
      break
    end
  end
  return table.concat(lines, '\n')
end

local function choice_lines_to_text(source, max_lines)
  local lines = {}
  for _, line in ipairs(source or {}) do
    local text = normalize_choice_text(line)
    if text ~= '' then
      lines[#lines + 1] = text
    end
    if max_lines and #lines >= max_lines then
      break
    end
  end
  return table.concat(lines, '\n')
end

local function build_choice_desc_text(choice)
  if not choice then
    return ''
  end

  local tip_model = choice.tip_model or {}
  local lines = {}
  local seen_lines = {}

  local function add_line(text)
    local normalized = normalize_choice_text(text)
    if normalized ~= '' and not seen_lines[normalized] then
      seen_lines[normalized] = true
      lines[#lines + 1] = normalized
    end
  end

  add_line(choice.desc_text)
  add_line(choice.summary)
  add_line(choice.effect_body_text)
  add_line(choice.current_text)
  add_line(choice.value_text)
  add_line(choice.advanced_text)
  add_line(choice.effect_text)

  for _, block in ipairs(choice.body_blocks or {}) do
    add_line(block and block.text)
  end

  add_line(tip_model.effect_body_text)

  for _, line in ipairs(tip_model.bonus_lines or {}) do
    add_line(line)
  end

  for _, line in ipairs(tip_model.set_body_lines or {}) do
    add_line(line)
  end

  if #lines == 0 then
    return ''
  end

  return table.concat(lines, '\n')
end

local function normalize_quality_display(quality)
  local mapping = {
    legendary = '传说',
    epic = '史诗',
    rare = '稀有',
    excellent = '优秀',
    common = '普通',
  }
  return mapping[quality] or quality
end

local function normalize_kind_display(kind)
  local mapping = {
    gear = '武器词条',
    bond = '羁绊',
    attr = '属性',
    evolution = '英雄',
  }
  return mapping[kind] or kind
end

local function build_choice_subtitle_text(kind, choice)
  if not choice then
    return ''
  end
  local quality = choice.quality and normalize_quality_display(choice.quality) or nil
  local kind_text = normalize_kind_display(kind)
  return tostring(choice.bond_root_name or choice.bond_name or choice.tag or quality or kind_text or '候选')
end

local function get_pending_round_choice_kind()
  if STATE.gear_state and STATE.gear_state.awaiting_choice and STATE.gear_state.current_choices then
    return 'gear'
  end
  local attr_choice_system = STATE.attr_choice_system
  if attr_choice_system and attr_choice_system.get_pending_choice_kind then
    local attr_kind = attr_choice_system.get_pending_choice_kind()
    if attr_kind then
      return attr_kind
    end
  end
local evolution_runtime = STATE.evolution_runtime
  if evolution_runtime and evolution_runtime.awaiting_choice and evolution_runtime.current_choices then
    return 'evolution'
  end
  return nil
end

local function get_choice_panel_choices()
  local kind = get_pending_round_choice_kind()
  local choices = nil
  if kind == 'gear' then
    choices = STATE.gear_state and STATE.gear_state.current_choices or nil
  elseif kind == 'attr' then
    choices = STATE.attr_choice_runtime and STATE.attr_choice_runtime.current_choices or nil
elseif kind == 'evolution' then
    local evolution_runtime = STATE.evolution_runtime
    choices = evolution_runtime and evolution_runtime.current_choices or nil
  end
  return kind, choices
end

local function ensure_choice_selected_index(kind, choices, is_visible)
  if not is_visible or not choices or #choices == 0 then
    STATE.choice_panel_selected_index = nil
    STATE.choice_panel_selected_kind = nil
    return nil
  end
  local selected_index = tonumber(STATE.choice_panel_selected_index)
  -- 只要选中的索引在有效范围内，就保留选中状态
  -- 不要求 choice_panel_selected_kind 必须匹配，这样避免状态被不必要地重置
  if not selected_index or selected_index < 1 or selected_index > #choices then
    STATE.choice_panel_selected_index = nil
    STATE.choice_panel_selected_kind = nil
  end
  -- 同时确保 kind 被正确设置
  if selected_index and selected_index >= 1 and selected_index <= #choices then
    STATE.choice_panel_selected_kind = kind
  end
  return selected_index
end

refresh_choice_selected_styles = function()
  local root, scroll = ensure_choice_list_choice_panel()
  if not root or not scroll then
    return
  end
  local kind, choices = get_choice_panel_choices()
  local selected_index = tonumber(STATE.choice_panel_selected_index)
  local skip_icon_color = (kind == 'evolution')
  for index = 1, 4 do
    local card = resolve_choice_panel_card(scroll, index)
    local choice = choices and choices[index] or nil
    local quality = choice and choice.quality or nil
    apply_choice_card_style(card, selected_index == index, quality, skip_icon_color)
  end
end

local function build_choice_list_cards()
  local kind, choices = get_choice_panel_choices()

  local root, scroll, player = ensure_choice_list_choice_panel()
  if not root or not scroll then
    return
  end

  local is_visible = choices and #choices > 0 and STATE.choice_panel_hidden ~= true
  set_ui_visible(root, is_visible)
  local selected_index = ensure_choice_selected_index(kind, choices, is_visible)

  local old_choice_panels = { 'ChoiceList' }
  if player then
    for _, panel_name in ipairs(old_choice_panels) do
      local ok_old, old_panel = pcall(y3.ui.get_ui, player, panel_name)
      if ok_old and old_panel then
        set_ui_visible(old_panel, false)
      end
    end
  end

  for index = 1, 4 do
    local card = resolve_choice_panel_card(scroll, index)
    local choice = choices and choices[index] or nil
    set_ui_visible(card, is_visible and choice ~= nil)

    if card and is_visible and choice then
      local title = resolve_ui_child(card, 'title')
      if title and title.set_text then
        title:set_text(tostring(choice.pretty_display_name or choice.display_name or choice.title_text or choice.name or
          '候选'))
      end

      local subtitle = resolve_ui_child(card, 'sub_title')
      if subtitle and subtitle.set_text then
        subtitle:set_text(build_choice_subtitle_text(kind, choice))
      end

      local desc = resolve_ui_child(card, 'desc')
      if desc and desc.set_text then
        desc:set_text(build_choice_desc_text(choice))
      end

      local icon = resolve_ui_child(card, 'image_2_1')
      if icon and icon.set_image then
        local icon_id
        if kind == 'evolution' then
          icon_id = resolve_display_icon(
            choice.icon_res,
            choice.ui_icon,
            choice.icon,
            choice.bg,
            nil,
            nil
          )
        else
          icon_id = resolve_display_icon(choice.icon_res, choice.ui_icon, choice.icon, choice.bg)
        end
        if icon_id and icon_id ~= 0 and icon_id ~= '' then
          icon:set_image(icon_id)
        else
          icon:set_image(906900)
        end
      end

      local click_image = resolve_ui_child(card, 'image_2')
      bind_choice_click_target(click_image or card, index)
      local skip_icon_color = (kind == 'evolution')
      apply_choice_card_style(card, selected_index == index, choice.quality, skip_icon_color)
    end
  end

  if root.set_z_order then
    root:set_z_order(9600)
  end
end

function M.refresh_choice_panel(...)
  build_choice_list_cards()
  return nil
end

return M
