local UIRoot = require 'ui.ui_root'

local M = {}

function M.create(env)
  local STATE = env.STATE
  local y3 = env.y3
  local get_player = env.get_player
  local get_runtime_hud_system = env.get_runtime_hud_system
  local get_runtime_overview_model = env.get_runtime_overview_model
  local get_pending_round_choice_kind = env.get_pending_round_choice_kind
  local refresh_current_choice = env.refresh_current_choice
  local apply_round_choice = env.apply_round_choice
  local defer_choice_panel = env.defer_choice_panel
  local get_growth_weapon_item_key = env.get_growth_weapon_item_key
  local build_treasure_slot_text = env.build_treasure_slot_text
  local get_treasure_quality_label = env.get_treasure_quality_label
  local get_treasure_def = env.get_treasure_def
  local get_evolution_quality_label = env.get_evolution_quality_label
  local is_ui_alive
  local set_visible_if_alive
  local set_text_if_alive
  local set_button_text_if_alive
  local set_font_size_if_alive
  local set_image_if_alive
  local set_button_enable_if_alive
  local set_intercepts_if_alive
  local set_z_order_if_alive
  local choice_panel_cache = {
    BondChoice2 = nil,
    BondChoice3 = nil,
    BondChoice4 = nil,
  }
  local choice_panel_bound = {}
  local LEGACY_GAME_HUD_Z = 9500
  local LEGACY_GAME_HUD_SETTING_PANEL_Z = 9560
  local LEGACY_GAME_HUD_BUTTON_Z = 9570
  local CHOICE_PANEL_Z = 9540
  local EMPTY_IMAGE_ID = 999
  local REFRESH_COSTS = { 40, 80, 100 }

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

  set_button_text_if_alive = function(ui, text)
    local final_text = tostring(text or '')
    if not is_ui_alive(ui) then
      return
    end
    if ui.set_text then
      ui:set_text(final_text)
    end
    if ui.set_btn_status_string then
      ui:set_btn_status_string('常态', final_text)
      ui:set_btn_status_string('悬浮', final_text)
      ui:set_btn_status_string('按下', final_text)
      ui:set_btn_status_string('禁用', final_text)
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

  set_intercepts_if_alive = function(ui, intercepts)
    if is_ui_alive(ui) and ui.set_intercepts_operations then
      ui:set_intercepts_operations(intercepts == true)
    end
  end

  set_z_order_if_alive = function(ui, z_order)
    if is_ui_alive(ui) and ui.set_z_order and z_order then
      ui:set_z_order(z_order)
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
    set_visible_if_alive(resolve_panel('BondChoice2'), false)
    set_visible_if_alive(resolve_panel('BondChoice3'), false)
    set_visible_if_alive(resolve_panel('BondChoice4'), false)
  end

  local function choose_panel_name(choice_count)
    if tonumber(choice_count) and choice_count <= 2 then
      return 'BondChoice2'
    end
    if tonumber(choice_count) and choice_count >= 4 then
      return 'BondChoice4'
    end
    return 'BondChoice3'
  end

  local function get_choice_panel_root_path(panel_name)
    if panel_name == 'BondChoice2' then
      return 'bond_choice_2'
    end
    if panel_name == 'BondChoice4' then
      return 'bond_choice_4'
    end
    return 'bond_choice_3'
  end

  local function get_choice_panel_card_suffix(panel_name)
    if panel_name == 'BondChoice2' then
      return '2'
    end
    if panel_name == 'BondChoice4' then
      return '4'
    end
    return '3'
  end

  local function trim_text(text)
    if text == nil then
      return ''
    end
    return tostring(text):gsub('^%s+', ''):gsub('%s+$', '')
  end

  local function get_quality_label(quality, kind)
    if kind == 'treasure' and get_treasure_quality_label then
      return get_treasure_quality_label(quality)
    end
    if kind == 'evolution' and get_evolution_quality_label then
      return get_evolution_quality_label(quality)
    end
    if quality == 'legendary' then
      return '传说'
    end
    if quality == 'epic' then
      return '史诗'
    end
    if quality == 'rare' or quality == 'excellent' then
      return '稀有'
    end
    return '普通'
  end

  local function get_refresh_cost(paid_count)
    local index = math.min((tonumber(paid_count) or 0) + 1, #REFRESH_COSTS)
    return REFRESH_COSTS[index] or REFRESH_COSTS[#REFRESH_COSTS]
  end

  local function get_item_icon_by_key(item_key)
    if item_key and y3 and y3.item and y3.item.get_icon_id_by_key then
      return y3.item.get_icon_id_by_key(item_key)
    end
    return EMPTY_IMAGE_ID
  end

  local function get_unit_icon_by_key(unit_key)
    if unit_key and y3 and y3.unit and y3.unit.get_icon_by_key then
      return y3.unit.get_icon_by_key(unit_key)
    end
    return EMPTY_IMAGE_ID
  end

  local function get_growth_weapon_name()
    local item_key = get_growth_weapon_item_key and get_growth_weapon_item_key() or nil
    if item_key and y3 and y3.item and y3.item.get_name_by_key then
      return y3.item.get_name_by_key(item_key)
    end
    return '成长武器'
  end

  local function get_growth_weapon_icon()
    return get_item_icon_by_key(get_growth_weapon_item_key and get_growth_weapon_item_key() or nil)
  end

  local function split_choice_values(text, max_lines)
    local lines = {}
    local current_text = tostring(text or '')
    current_text = current_text:gsub('\r\n', '\n'):gsub('\r', '\n')
    if string.find(current_text, '\n', 1, true) == nil then
      current_text = current_text:gsub('。%s*', '。\n')
      current_text = current_text:gsub('；%s*', '\n')
      current_text = current_text:gsub(';%s*', '\n')
      current_text = current_text:gsub('，', '\n')
      current_text = current_text:gsub(',%s*', '\n')
    end
    current_text = current_text:gsub('\n+', '\n')
    for line in string.gmatch(current_text, '[^\n]+') do
      local trimmed = trim_text(line)
      if trimmed ~= '' then
        lines[#lines + 1] = trimmed
      end
      if #lines >= (max_lines or 2) then
        break
      end
    end
    return lines
  end

  local function build_card_model(title_text, subtitle_text, body_text, icon, quality, enabled)
    local lines = type(body_text) == 'table' and body_text or split_choice_values(body_text, 2)
    return {
      title_text = trim_text(title_text),
      subtitle_text = trim_text(subtitle_text),
      body_lines = lines,
      icon = icon or EMPTY_IMAGE_ID,
      quality = quality or 'common',
      enabled = enabled ~= false,
    }
  end

  local function build_upgrade_card_model(choice)
    local quality_label = get_quality_label(choice and choice.quality or nil)
    local subtitle = trim_text(choice and choice.tag or '')
    if subtitle == '' or subtitle:find('羁绊', 1, true) then
      subtitle = '技能强化'
    end
    subtitle = string.format('[%s] %s', quality_label, subtitle)
    local title = trim_text(choice and choice.name or '')
    if title == '' then
      title = trim_text(choice and choice.display_name or '')
    end
    return build_card_model(
      title,
      subtitle,
      choice and (choice.desc or choice.summary) or '',
      choice and (choice.ui_icon or choice.icon) or EMPTY_IMAGE_ID,
      choice and choice.quality or 'common'
    )
  end

  local function build_bond_card_model(choice)
    local lines = split_choice_values(choice and choice.current_text or '', 2)
    if #lines < 2 then
      local desc_lines = split_choice_values(choice and choice.desc_text or '', 2)
      for _, line in ipairs(desc_lines) do
        if #lines >= 2 then
          break
        end
        lines[#lines + 1] = line
      end
    end

    local bond_name = trim_text(choice and choice.bond_root_name or '')
    local bond_progress = trim_text(choice and choice.bond_root_progress_text or '')
    local subtitle = ''
    if bond_name ~= '' then
      if bond_progress ~= '' then
        subtitle = string.format('羁绊： %s (%s)', bond_name, bond_progress)
      else
        subtitle = '羁绊： ' .. bond_name
      end
    else
      subtitle = trim_text(choice and choice.title_text or '')
      if subtitle ~= '' then
        subtitle = '羁绊： ' .. subtitle
      end
    end

    local title = trim_text(choice and (choice.pretty_display_name or choice.display_name or choice.title_text) or '')
    if title == '' then
      title = '未命名仙缘'
    end

    return build_card_model(
      title,
      subtitle,
      lines,
      choice and (choice.ui_icon or choice.icon) or EMPTY_IMAGE_ID,
      choice and choice.quality or 'common'
    )
  end

  local function build_gear_card_model(choice)
    local runtime = STATE and STATE.gear_state or nil
    local pending = runtime and runtime.pending_affix_choice or nil
    local level = pending and tonumber(pending.level) or 0
    local subtitle = level > 0
      and string.format('[%s] %s Lv.%d', get_quality_label(choice and choice.quality or nil), get_growth_weapon_name(), level)
      or string.format('[%s] %s词缀', get_quality_label(choice and choice.quality or nil), get_growth_weapon_name())

    return build_card_model(
      choice and (choice.display_name or choice.id) or '',
      subtitle,
      choice and choice.summary or '',
      get_growth_weapon_icon(),
      choice and choice.quality or 'common'
    )
  end

  local function build_evolution_card_model(def)
    local runtime = STATE and (STATE.evolution_runtime or STATE.mark_runtime) or nil
    local round = runtime and runtime.current_round or nil
    return build_card_model(
      def and def.name or '未命名真身',
      string.format('[%s] %s', get_quality_label(def and def.quality or nil, 'evolution'), round and round.ui_title or '真身进化'),
      def and def.summary or '',
      get_unit_icon_by_key(def and def.hero_unit_id or nil),
      def and def.quality or 'common'
    )
  end

  local function count_active_treasures()
    local runtime = STATE and STATE.treasure_runtime or nil
    if not runtime or not runtime.active_slots then
      return 0
    end

    local count = 0
    for slot = 1, 3, 1 do
      if runtime.active_slots[slot] then
        count = count + 1
      end
    end
    return count
  end

  local function build_treasure_card_model(def)
    local quality_label = get_quality_label(def and def.quality or nil, 'treasure')
    local replace_suffix = count_active_treasures() >= 3 and '·需替换' or ''
    return build_card_model(
      def and def.name or '未命名宝物',
      string.format('[%s] 宝物%s', quality_label, replace_suffix),
      def and def.summary or '',
      get_item_icon_by_key(def and def.editor_item_key or nil),
      def and def.quality or 'common'
    )
  end

  local function build_treasure_replace_card_model(slot)
    local runtime = STATE and STATE.treasure_runtime or nil
    local treasure_id = runtime and runtime.active_slots and runtime.active_slots[slot] or nil
    local current_def = get_treasure_def and get_treasure_def(treasure_id) or nil
    local selected_def = runtime and runtime.pending_replace_choice or nil
    local lines = split_choice_values(current_def and current_def.summary or '', 2)

    if #lines == 0 and build_treasure_slot_text then
      lines = split_choice_values(build_treasure_slot_text(slot), 2)
    end
    if #lines < 2 and selected_def and selected_def.name and selected_def.name ~= '' then
      lines[#lines + 1] = '换入：' .. tostring(selected_def.name)
    end

    local quality_label = get_quality_label(current_def and current_def.quality or nil, 'treasure')
    local subtitle = quality_label ~= ''
      and string.format('[%s] 替换位 %d', quality_label, slot)
      or string.format('替换位 %d', slot)

    return build_card_model(
      current_def and current_def.name or string.format('宝物位 %d', slot),
      subtitle,
      lines,
      get_item_icon_by_key(current_def and current_def.editor_item_key or nil),
      current_def and current_def.quality or 'common',
      treasure_id ~= nil
    )
  end

  local function build_choice_panel_model()
    if STATE.choice_panel_hidden == true then
      return nil
    end

    local kind = get_pending_round_choice_kind and get_pending_round_choice_kind() or nil
    if kind == 'upgrade' then
      if not STATE.awaiting_upgrade or not STATE.current_upgrade_choices or #STATE.current_upgrade_choices == 0 then
        return nil
      end

      local choices = {}
      for _, choice in ipairs(STATE.current_upgrade_choices) do
        choices[#choices + 1] = build_upgrade_card_model(choice)
      end
      return {
        kind = kind,
        panel_name = choose_panel_name(#choices),
        choices = choices,
        current_round = STATE.current_upgrade_round,
        can_refresh = true,
      }
    end

    if kind == 'gear' then
      local runtime = STATE and STATE.gear_state or nil
      if not runtime or runtime.awaiting_choice ~= true or not runtime.current_choices or #runtime.current_choices == 0 then
        return nil
      end

      local choices = {}
      for _, choice in ipairs(runtime.current_choices) do
        choices[#choices + 1] = build_gear_card_model(choice)
      end

      local current_round = runtime.current_round or runtime.pending_affix_choice or {}
      local free_refresh_left = tonumber(current_round.free_refresh_left or 0) or 0
      return {
        kind = kind,
        panel_name = choose_panel_name(#choices),
        choices = choices,
        current_round = current_round,
        can_refresh = free_refresh_left > 0,
        disabled_refresh_text = '刷新已用尽',
      }
    end

    if kind == 'bond' then
      local runtime = STATE and STATE.bond_runtime or nil
      if not runtime or runtime.awaiting_choice ~= true or not runtime.current_choices or #runtime.current_choices == 0 then
        return nil
      end

      local choices = {}
      for _, choice in ipairs(runtime.current_choices) do
        choices[#choices + 1] = build_bond_card_model(choice)
      end
      return {
        kind = kind,
        panel_name = choose_panel_name(#choices),
        choices = choices,
        current_round = runtime.current_round or runtime.current_offer_round,
        can_refresh = true,
      }
    end

    if kind == 'evolution' or kind == 'mark' then
      local runtime = STATE and (STATE.evolution_runtime or STATE.mark_runtime) or nil
      if not runtime or runtime.awaiting_choice ~= true or not runtime.current_choices or #runtime.current_choices == 0 then
        return nil
      end

      local choices = {}
      for _, choice in ipairs(runtime.current_choices) do
        choices[#choices + 1] = build_evolution_card_model(choice)
      end
      return {
        kind = 'evolution',
        panel_name = choose_panel_name(#choices),
        choices = choices,
        current_round = runtime.current_round,
        can_refresh = false,
        disabled_refresh_text = '当前不可刷新',
      }
    end

    if kind == 'treasure' then
      local runtime = STATE and STATE.treasure_runtime or nil
      if not runtime then
        return nil
      end

      if runtime.awaiting_replace and runtime.pending_replace_choice then
        local choices = {}
        for slot = 1, 3, 1 do
          choices[#choices + 1] = build_treasure_replace_card_model(slot)
        end
        return {
          kind = 'treasure_replace',
          panel_name = choose_panel_name(#choices),
          choices = choices,
          current_round = runtime.current_round,
          can_refresh = false,
          disabled_refresh_text = '已进入替换',
        }
      end

      if not runtime.awaiting_choice or not runtime.current_choices or #runtime.current_choices == 0 then
        return nil
      end

      local choices = {}
      for _, choice in ipairs(runtime.current_choices) do
        choices[#choices + 1] = build_treasure_card_model(choice)
      end
      return {
        kind = kind,
        panel_name = choose_panel_name(#choices),
        choices = choices,
        current_round = runtime.current_round,
        can_refresh = true,
      }
    end

    return nil
  end

  local function update_card(panel_name, index, choice)
    local card_path = string.format(
      'bond_choice_%s.cards_row.card_%d',
      get_choice_panel_card_suffix(panel_name),
      index
    )
    local card = resolve_panel_node(panel_name, card_path)
    if not card then
      return
    end

    set_visible_if_alive(card, choice ~= nil)
    if not choice then
      return
    end

    set_text_if_alive(resolve_panel_node(panel_name, card_path .. string.format('.title_%d', index)), choice.title_text)
    set_text_if_alive(resolve_panel_node(panel_name, card_path .. string.format('.bond_%d', index)), choice.subtitle_text)
    set_image_if_alive(resolve_panel_node(panel_name, card_path .. string.format('.icon_%d', index)), choice.icon or EMPTY_IMAGE_ID)

    local values = choice.body_lines or {}
    set_text_if_alive(resolve_panel_node(panel_name, card_path .. string.format('.value_1_%d', index)), values[1] or '')
    set_text_if_alive(resolve_panel_node(panel_name, card_path .. string.format('.value_2_%d', index)), values[2] or '')
    set_visible_if_alive(resolve_panel_node(panel_name, card_path .. string.format('.value_2_%d', index)), values[2] ~= nil)

    local title = resolve_panel_node(panel_name, card_path .. string.format('.title_%d', index))
    if choice.quality == 'legendary' then
      if is_ui_alive(title) and title.set_text_color then
        title:set_text_color(255, 184, 64, 255)
      end
    elseif choice.quality == 'epic' then
      if is_ui_alive(title) and title.set_text_color then
        title:set_text_color(208, 62, 255, 255)
      end
    elseif is_ui_alive(title) and title.set_text_color then
      title:set_text_color(45, 176, 255, 255)
    end

    local pick_btn = resolve_panel_node(panel_name, card_path .. string.format('.pick_btn_%d', index))
    set_intercepts_if_alive(pick_btn, true)
    set_button_enable_if_alive(pick_btn, choice.enabled ~= false)
  end

  local function bind_panel_events(panel_name, choice_count)
    choice_panel_bound[panel_name] = choice_panel_bound[panel_name] or {}
    local bound = choice_panel_bound[panel_name]
    local root_path = get_choice_panel_root_path(panel_name)

    for index = 1, choice_count do
      local event_key = 'pick_btn_' .. tostring(index)
      if bound[event_key] ~= true then
        local card_path = string.format('%s.cards_row.card_%d.pick_btn_%d', root_path, index, index)
        local btn = resolve_panel_node(panel_name, card_path)
        if is_ui_alive(btn) and btn.add_fast_event then
          set_intercepts_if_alive(btn, true)
          btn:add_fast_event('左键-点击', function()
            if apply_round_choice then
              apply_round_choice(index)
            end
          end)
          bound[event_key] = true
        end
      end
    end

    if bound.refresh_btn ~= true then
      local refresh_btn = resolve_panel_node(panel_name, root_path .. '.refresh_btn')
      if is_ui_alive(refresh_btn) and refresh_btn.add_fast_event then
        set_intercepts_if_alive(refresh_btn, true)
        refresh_btn:add_fast_event('左键-点击', function()
          if refresh_current_choice then
            refresh_current_choice()
          end
        end)
        bound.refresh_btn = true
      end
    end

    if bound.later_btn ~= true then
      local later_btn = resolve_panel_node(panel_name, root_path .. '.later_btn')
      if is_ui_alive(later_btn) and later_btn.add_fast_event then
        set_intercepts_if_alive(later_btn, true)
        later_btn:add_fast_event('左键-点击', function()
          if defer_choice_panel then
            defer_choice_panel()
          end
        end)
        bound.later_btn = true
      end
    end
  end

  local function sync_choice_panel_layers(panel_name)
    set_z_order_if_alive(resolve_panel(panel_name), CHOICE_PANEL_Z)
  end

  local function sync_runtime_hud_layers(visible)
    local player = get_player and get_player() or nil
    if not player then
      return
    end

    local battle_bottom_hud = UIRoot.resolve_ui(y3, player, 'BattleBottomHUD')
    local game_hud = UIRoot.resolve_ui(y3, player, 'GameHUD')
    local game_hud_main = UIRoot.resolve_ui(y3, player, 'GameHUD.main')
    local game_hud_setting_btn = UIRoot.resolve_ui(y3, player, 'GameHUD.setting_btn')
    local game_hud_exit_btn = UIRoot.resolve_ui(y3, player, 'GameHUD.exit_btn')
    local game_hud_setting_panel = UIRoot.resolve_ui(y3, player, 'GameHUD.setting_panel')

    -- Keep the built-in settings UI above the custom HUD and runtime overlay popups.
    set_z_order_if_alive(game_hud, LEGACY_GAME_HUD_Z)
    set_z_order_if_alive(game_hud_setting_panel, LEGACY_GAME_HUD_SETTING_PANEL_Z)
    set_z_order_if_alive(game_hud_setting_btn, LEGACY_GAME_HUD_BUTTON_Z)
    set_z_order_if_alive(game_hud_exit_btn, LEGACY_GAME_HUD_BUTTON_Z)

    set_visible_if_alive(battle_bottom_hud, visible)

    if visible == true then
      set_visible_if_alive(game_hud, true)
      set_visible_if_alive(game_hud_main, true)
      set_visible_if_alive(game_hud_setting_btn, false)
      set_visible_if_alive(game_hud_exit_btn, false)

      -- BattleBottomHUD is the active bottom combat bar; keep legacy bottoms hidden
      -- so we do not end up with nested frames or split spacing.
      set_visible_if_alive(UIRoot.resolve_ui(y3, player, 'bottom_bg.bottom_bg'), false)
      set_visible_if_alive(UIRoot.resolve_ui(y3, player, 'bottom_bg'), false)

      if battle_bottom_hud then
        local duplicate_paths = {
          'GameHUD.main.main_unit',
          'GameHUD.main.main_unit_name',
          'GameHUD.main.attr_list',
          'GameHUD.main.skill_list',
          'GameHUD.main.main_hp_bar',
          'GameHUD.main.main_mp_bar',
          'GameHUD.main.inventory',
          'GameHUD.main.bag_btn',
          'GameHUD.player_attr_list',
          'GameHUD.main.player_attr_list',
        }
        for _, path in ipairs(duplicate_paths) do
          set_visible_if_alive(UIRoot.resolve_ui(y3, player, path), false)
        end
      end
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
    local model = build_choice_panel_model()
    if not model then
      hide_all_choice_panels()
      return nil
    end

    local panel_name = model.panel_name or choose_panel_name(#model.choices)
    local panel = resolve_panel(panel_name)
    if not panel then
      return nil
    end

    bind_panel_events('BondChoice2', 2)
    bind_panel_events('BondChoice3', 3)
    bind_panel_events('BondChoice4', 4)
    sync_choice_panel_layers('BondChoice2')
    sync_choice_panel_layers('BondChoice3')
    sync_choice_panel_layers('BondChoice4')
    set_visible_if_alive(resolve_panel('BondChoice2'), panel_name == 'BondChoice2')
    set_visible_if_alive(resolve_panel('BondChoice3'), panel_name == 'BondChoice3')
    set_visible_if_alive(resolve_panel('BondChoice4'), panel_name == 'BondChoice4')
    return panel, model
  end

  local function refresh_choice_panel()
    local panel, model = ensure_choice_panel()
    if not panel or not model then
      return nil
    end

    local panel_name = model.panel_name or choose_panel_name(#model.choices)
    for index = 1, 4 do
      update_card(panel_name, index, model.choices[index])
    end

    local refresh_btn = resolve_panel_node(panel_name, (get_choice_panel_root_path(panel_name)) .. '.refresh_btn')
    local current_round = model.current_round or {}
    local free_refresh_left = tonumber(current_round.free_refresh_left or 0) or 0
    if model.can_refresh ~= true then
      set_button_text_if_alive(refresh_btn, model.disabled_refresh_text or '当前不可刷新')
    else
      if free_refresh_left > 0 then
        set_button_text_if_alive(refresh_btn, string.format('免费刷新候选（剩余%d次）', free_refresh_left))
      else
        local paid_count = tonumber(current_round.refresh_paid_count or 0) or 0
        set_button_text_if_alive(refresh_btn, string.format('刷新候选（%d木材）', get_refresh_cost(paid_count)))
      end
    end
    set_button_enable_if_alive(refresh_btn, model.can_refresh == true)
    set_font_size_if_alive(refresh_btn, 15)
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
