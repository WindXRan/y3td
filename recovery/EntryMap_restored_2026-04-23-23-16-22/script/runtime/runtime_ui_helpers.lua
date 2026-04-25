local UIRoot = require 'ui.ui_root'

local M = {}

function M.create(env)
  local STATE = env.STATE
  local y3 = env.y3
  local get_player = env.get_player
  local get_runtime_hud_system = env.get_runtime_hud_system
  local get_runtime_overview_model = env.get_runtime_overview_model
  local refresh_bond_choice = env.refresh_bond_choice
  local apply_bond_choice = env.apply_bond_choice
  local defer_choice_panel = env.defer_choice_panel
  local is_ui_alive
  local set_visible_if_alive
  local set_text_if_alive
  local set_font_size_if_alive
  local set_image_if_alive
  local set_button_enable_if_alive
  local choice_panel_cache = {
    BondChoice3 = nil,
    BondChoice4 = nil,
  }
  local choice_panel_bound = {}

  local function install_panel_systems()
    STATE.message_prompt_system = nil
    STATE.talk_panel_system = nil
    STATE.inventory_panel_system = nil
  end

  is_ui_alive = function(ui)
    return ui and (not ui.is_removed or not ui:is_removed())
  end

  set_visible_if_alive = function(ui, visible)
    if is_ui_alive(ui) and ui.set_visible then
      ui:set_visible(visible == true)
    end
  end

  set_text_if_alive = function(ui, text)
    if is_ui_alive(ui) and ui.set_text then
      ui:set_text(text or '')
    end
  end

  set_font_size_if_alive = function(ui, size)
    if is_ui_alive(ui) and ui.set_font_size and size then
      ui:set_font_size(size)
    end
  end

  set_image_if_alive = function(ui, image)
    if is_ui_alive(ui) and ui.set_image and image and image ~= 0 then
      ui:set_image(image)
    end
  end

  set_button_enable_if_alive = function(ui, enabled)
    if is_ui_alive(ui) and ui.set_button_enable then
      ui:set_button_enable(enabled == true)
    end
  end

  local function resolve_panel(panel_name)
    local cached = choice_panel_cache[panel_name]
    if is_ui_alive(cached) then
      return cached
    end
    local player = get_player and get_player() or nil
    if not player then
      return nil
    end
    local panel = UIRoot.resolve_ui(y3, player, panel_name)
    choice_panel_cache[panel_name] = panel
    return panel
  end

  local function resolve_panel_node(panel_name, path)
    local panel = resolve_panel(panel_name)
    if not panel then
      return nil
    end
    if not path or path == '' then
      return panel
    end
    return UIRoot.resolve_child(panel, path)
  end

  local function hide_all_choice_panels()
    set_visible_if_alive(resolve_panel('BondChoice3'), false)
    set_visible_if_alive(resolve_panel('BondChoice4'), false)
  end

  local function get_bond_choice_runtime()
    local runtime = STATE and STATE.bond_runtime or nil
    if not runtime or runtime.awaiting_choice ~= true or not runtime.current_choices or STATE.choice_panel_hidden == true then
      return nil
    end
    return runtime
  end

  local function choose_panel_name(choice_count)
    if tonumber(choice_count) and choice_count >= 4 then
      return 'BondChoice4'
    end
    return 'BondChoice3'
  end

  local function get_card_width(panel_name, index)
    if panel_name == 'BondChoice4' then
      if index == 4 then
        return 370
      end
      return 418
    end
    return 504
  end

  local function get_choice_title(choice)
    return tostring(choice and (choice.pretty_display_name or choice.display_name or choice.title_text) or '')
  end

  local function get_choice_bond_text(choice)
    local progress = choice and choice.title_text or ''
    if progress ~= '' then
      return '羁绊： ' .. tostring(progress)
    end
    return ''
  end

  local function split_choice_values(choice)
    local lines = {}
    local current_text = tostring(choice and choice.current_text or '')
    for line in string.gmatch(current_text, '[^\n]+') do
      local trimmed = tostring(line):gsub('^%s+', ''):gsub('%s+$', '')
      if trimmed ~= '' then
        lines[#lines + 1] = trimmed
      end
      if #lines >= 3 then
        break
      end
    end
    return lines
  end

  local function update_card(panel_name, index, choice)
    local card_path = string.format('bond_choice_%s.card_%d', panel_name == 'BondChoice4' and '4' or '3', index)
    local card = resolve_panel_node(panel_name, card_path)
    if not card then
      return
    end

    set_visible_if_alive(card, choice ~= nil)
    if not choice then
      return
    end

    set_text_if_alive(resolve_panel_node(panel_name, card_path .. string.format('.title_%d', index)), get_choice_title(choice))
    set_text_if_alive(resolve_panel_node(panel_name, card_path .. string.format('.bond_%d', index)), get_choice_bond_text(choice))
    set_image_if_alive(resolve_panel_node(panel_name, card_path .. string.format('.icon_%d', index)), choice.ui_icon or choice.icon)

    local values = split_choice_values(choice)
    set_text_if_alive(resolve_panel_node(panel_name, card_path .. string.format('.value_1_%d', index)), values[1] or '')
    set_text_if_alive(resolve_panel_node(panel_name, card_path .. string.format('.value_2_%d', index)), values[2] or '')
    set_visible_if_alive(resolve_panel_node(panel_name, card_path .. string.format('.value_2_%d', index)), values[2] ~= nil)

    local title = resolve_panel_node(panel_name, card_path .. string.format('.title_%d', index))
    if choice.quality == 'epic' and index == 4 and panel_name == 'BondChoice4' then
      if is_ui_alive(title) and title.set_text_color then
        title:set_text_color(208, 62, 255, 255)
      end
    elseif is_ui_alive(title) and title.set_text_color then
      title:set_text_color(45, 176, 255, 255)
    end

    local pick_btn = resolve_panel_node(panel_name, card_path .. string.format('.pick_btn_%d', index))
    set_button_enable_if_alive(pick_btn, true)
  end

  local function bind_panel_events(panel_name, choice_count)
    if choice_panel_bound[panel_name] == true then
      return
    end
    choice_panel_bound[panel_name] = true

    for index = 1, choice_count do
      local card_path = string.format('bond_choice_%s.card_%d.pick_btn_%d', panel_name == 'BondChoice4' and '4' or '3', index, index)
      local btn = resolve_panel_node(panel_name, card_path)
      if is_ui_alive(btn) and btn.add_fast_event then
        btn:add_fast_event('左键-点击', function()
          if apply_bond_choice then
            apply_bond_choice(index)
          end
        end)
      end
    end

    local refresh_btn = resolve_panel_node(panel_name, 'refresh_btn')
    if is_ui_alive(refresh_btn) and refresh_btn.add_fast_event then
      refresh_btn:add_fast_event('左键-点击', function()
        if refresh_bond_choice then
          refresh_bond_choice()
        end
      end)
    end

    local later_btn = resolve_panel_node(panel_name, 'later_btn')
    if is_ui_alive(later_btn) and later_btn.add_fast_event then
      later_btn:add_fast_event('左键-点击', function()
        if defer_choice_panel then
          defer_choice_panel()
        end
      end)
    end
  end

  local function sync_runtime_hud_layers(visible)
    local player = get_player and get_player() or nil
    if not player then
      return
    end

    local battle_bottom_hud = UIRoot.resolve_ui(y3, player, 'BattleBottomHUD')
    local game_hud = UIRoot.resolve_ui(y3, player, 'GameHUD')
    local game_hud_setting_btn = UIRoot.resolve_ui(y3, player, 'GameHUD.setting_btn')
    local game_hud_exit_btn = UIRoot.resolve_ui(y3, player, 'GameHUD.exit_btn')
    local game_hud_setting_panel = UIRoot.resolve_ui(y3, player, 'GameHUD.setting_panel')
    set_visible_if_alive(battle_bottom_hud, visible)

    if visible == true then
      set_visible_if_alive(game_hud, true)
      set_visible_if_alive(game_hud_setting_btn, false)
      set_visible_if_alive(game_hud_exit_btn, false)
      return
    end

    set_visible_if_alive(game_hud_setting_panel, false)

    local legacy_paths = {
      'GameHUD.main',
      'GameHUD',
      'bottom_bg.bottom_bg',
      'bottom_bg',
    }
    for _, path in ipairs(legacy_paths) do
      set_visible_if_alive(UIRoot.resolve_ui(y3, player, path), false)
    end
  end

  local function ensure_runtime_hud()
    local runtime_hud_system = get_runtime_hud_system and get_runtime_hud_system() or nil
    return runtime_hud_system and runtime_hud_system.ensure_hud and runtime_hud_system.ensure_hud() or nil
  end

  local function refresh_runtime_hud()
    local runtime_hud_system = get_runtime_hud_system and get_runtime_hud_system() or nil
    return runtime_hud_system and runtime_hud_system.refresh_hud and runtime_hud_system.refresh_hud() or nil
  end

  local function ensure_choice_panel()
    local runtime = get_bond_choice_runtime()
    if not runtime then
      hide_all_choice_panels()
      return nil
    end

    local panel_name = choose_panel_name(#runtime.current_choices)
    local panel = resolve_panel(panel_name)
    if not panel then
      return nil
    end

    bind_panel_events('BondChoice3', 3)
    bind_panel_events('BondChoice4', 4)
    set_visible_if_alive(resolve_panel('BondChoice3'), panel_name == 'BondChoice3')
    set_visible_if_alive(resolve_panel('BondChoice4'), panel_name == 'BondChoice4')
    return panel
  end

  local function refresh_choice_panel()
    local runtime = get_bond_choice_runtime()
    if not runtime then
      hide_all_choice_panels()
      return nil
    end

    local panel_name = choose_panel_name(#runtime.current_choices)
    local panel = ensure_choice_panel()
    if not panel then
      return nil
    end

    for index = 1, math.max(4, #runtime.current_choices) do
      update_card(panel_name, index, runtime.current_choices[index])
    end

    local refresh_btn = resolve_panel_node(panel_name, 'refresh_btn')
    local current_round = runtime.current_round or runtime.current_offer_round or {}
    local free_refresh_left = tonumber(current_round.free_refresh_left or 0) or 0
    if free_refresh_left > 0 then
      set_text_if_alive(refresh_btn, string.format('免费刷新： %d', free_refresh_left))
    else
      local paid_count = tonumber(current_round.refresh_paid_count or 0) or 0
      local refresh_costs = { 40, 80, 100 }
      local refresh_cost = refresh_costs[math.min(paid_count + 1, #refresh_costs)] or refresh_costs[#refresh_costs]
      set_text_if_alive(refresh_btn, string.format('刷新： %d木材', refresh_cost))
    end

    set_font_size_if_alive(refresh_btn, panel_name == 'BondChoice4' and 16 or 16)
    return panel
  end

  local function destroy_choice_panel()
    hide_all_choice_panels()
    return nil
  end

  local function build_attr_tip_panel_text()
    local previous_mode = STATE.runtime_overview_mode
    STATE.runtime_overview_mode = 'attr'
    local model = get_runtime_overview_model and get_runtime_overview_model() or nil
    STATE.runtime_overview_mode = previous_mode

    if not model or not model.sections then
      return '属性面板暂不可用'
    end

    local lines = {}
    local ordered_sections = { 'summary', 'skills', 'bonds', 'treasures' }
    for _, key in ipairs(ordered_sections) do
      local section = model.sections[key]
      if section and section.title and section.lines and #section.lines > 0 then
        lines[#lines + 1] = string.format('[%s]', tostring(section.title))
        for _, line in ipairs(section.lines) do
          lines[#lines + 1] = tostring(line)
          if #lines >= 8 then
            break
          end
        end
      end
      if #lines >= 8 then
        break
      end
    end

    if #lines == 0 then
      return '当前没有可显示的属性面板'
    end
    return table.concat(lines, '\n')
  end

  local function show_runtime_attr_tip_panel(duration)
    local runtime_hud_system = get_runtime_hud_system and get_runtime_hud_system() or nil
    if runtime_hud_system and runtime_hud_system.ensure_hud then
      runtime_hud_system.ensure_hud()
    end
    if runtime_hud_system and runtime_hud_system.show_tip_panel then
      runtime_hud_system.show_tip_panel(build_attr_tip_panel_text(), duration or 8)
    end
  end

  local function set_battle_hud_visible(visible)
    sync_runtime_hud_layers(visible)

    local runtime_hud_system = get_runtime_hud_system and get_runtime_hud_system() or nil
    if runtime_hud_system and runtime_hud_system.set_visible then
      runtime_hud_system.set_visible(visible)
    end
    if STATE.message_prompt_system and STATE.message_prompt_system.set_visible then
      STATE.message_prompt_system.set_visible(visible)
    end
    if STATE.talk_panel_system and STATE.talk_panel_system.set_visible then
      STATE.talk_panel_system.set_visible(visible)
    end
    if STATE.inventory_panel_system and STATE.inventory_panel_system.set_visible then
      STATE.inventory_panel_system.set_visible(visible)
    end
  end

  local function toggle_talk_input()
    return nil
  end

  local function toggle_inventory_panel()
    return nil
  end

  local function refresh_inventory_panel()
    return nil
  end

  return {
    destroy_choice_panel = destroy_choice_panel,
    ensure_choice_panel = ensure_choice_panel,
    ensure_runtime_hud = ensure_runtime_hud,
    install_panel_systems = install_panel_systems,
    refresh_choice_panel = refresh_choice_panel,
    refresh_inventory_panel = refresh_inventory_panel,
    refresh_runtime_hud = refresh_runtime_hud,
    refresh_runtime_overview = function()
    end,
    set_battle_hud_visible = set_battle_hud_visible,
    show_runtime_attr_tip_panel = show_runtime_attr_tip_panel,
    toggle_inventory_panel = toggle_inventory_panel,
    toggle_talk_input = toggle_talk_input,
  }
end

return M
