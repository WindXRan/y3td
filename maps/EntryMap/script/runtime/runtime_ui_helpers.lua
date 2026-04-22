local M = {}

function M.create(env)
  local STATE = env.STATE
  local y3 = env.y3
  local get_player = env.get_player
  local build_growth_weapon_tip_payload = env.build_growth_weapon_tip_payload
  local get_growth_weapon_item_key = env.get_growth_weapon_item_key
  local try_upgrade_growth_weapon = env.try_upgrade_growth_weapon
  local get_runtime_hud_system = env.get_runtime_hud_system
  local get_choice_panel_system = env.get_choice_panel_system
  local get_runtime_overview_model = env.get_runtime_overview_model

  local function install_panel_systems()
    STATE.message_prompt_system = require('ui.message_prompt').create({
      STATE = STATE,
      y3 = y3,
      get_player = get_player,
    })

    STATE.talk_panel_system = require('ui.talk_panel').create({
      STATE = STATE,
      y3 = y3,
      get_player = get_player,
      get_reward_unit = function()
        return STATE.hero
      end,
    })

    STATE.inventory_panel_system = require('ui.inventory_panel').create({
      STATE = STATE,
      y3 = y3,
      get_player = get_player,
      get_growth_weapon_item_key = get_growth_weapon_item_key,
      build_growth_weapon_tip_payload = build_growth_weapon_tip_payload,
      try_upgrade_growth_weapon = try_upgrade_growth_weapon,
    })

    STATE.hero_attr_panel_view_system = require('ui.hero_attr_panel_view').create({
      STATE = STATE,
      y3 = y3,
      get_player = get_player,
      hero_attr_system = env.hero_attr_system,
    })
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
    local choice_panel_system = get_choice_panel_system and get_choice_panel_system() or nil
    return choice_panel_system and choice_panel_system.ensure_panel and choice_panel_system.ensure_panel() or nil
  end

  local function refresh_choice_panel()
    local choice_panel_system = get_choice_panel_system and get_choice_panel_system() or nil
    return choice_panel_system and choice_panel_system.refresh_panel and choice_panel_system.refresh_panel() or nil
  end

  local function destroy_choice_panel()
    local choice_panel_system = get_choice_panel_system and get_choice_panel_system() or nil
    if choice_panel_system and choice_panel_system.destroy_panel then
      choice_panel_system.destroy_panel()
    end
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
    local runtime_hud_system = get_runtime_hud_system and get_runtime_hud_system() or nil
    local choice_panel_system = get_choice_panel_system and get_choice_panel_system() or nil
    if runtime_hud_system and runtime_hud_system.set_visible then
      runtime_hud_system.set_visible(visible)
    end
    if choice_panel_system and choice_panel_system.set_visible then
      choice_panel_system.set_visible(visible)
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
    if STATE.hero_attr_panel_view_system and STATE.hero_attr_panel_view_system.set_visible then
      STATE.hero_attr_panel_view_system.set_visible(visible)
    end
  end

  local function toggle_talk_input()
    return STATE.talk_panel_system and STATE.talk_panel_system.toggle_input and STATE.talk_panel_system.toggle_input() or nil
  end

  local function toggle_inventory_panel()
    return STATE.inventory_panel_system and STATE.inventory_panel_system.toggle_panel and STATE.inventory_panel_system.toggle_panel() or nil
  end

  local function refresh_inventory_panel()
    return STATE.inventory_panel_system and STATE.inventory_panel_system.refresh_panel and STATE.inventory_panel_system.refresh_panel() or nil
  end

  local function toggle_attr_panel()
    return STATE.hero_attr_panel_view_system
      and STATE.hero_attr_panel_view_system.toggle_panel
      and STATE.hero_attr_panel_view_system.toggle_panel()
      or nil
  end

  local function refresh_attr_panel()
    return STATE.hero_attr_panel_view_system
      and STATE.hero_attr_panel_view_system.refresh_panel
      and STATE.hero_attr_panel_view_system.refresh_panel()
      or nil
  end

  return {
    destroy_choice_panel = destroy_choice_panel,
    ensure_choice_panel = ensure_choice_panel,
    ensure_runtime_hud = ensure_runtime_hud,
    install_panel_systems = install_panel_systems,
    refresh_choice_panel = refresh_choice_panel,
    refresh_inventory_panel = refresh_inventory_panel,
    refresh_attr_panel = refresh_attr_panel,
    refresh_runtime_hud = refresh_runtime_hud,
    refresh_runtime_overview = function()
    end,
    set_battle_hud_visible = set_battle_hud_visible,
    show_runtime_attr_tip_panel = show_runtime_attr_tip_panel,
    toggle_attr_panel = toggle_attr_panel,
    toggle_inventory_panel = toggle_inventory_panel,
    toggle_talk_input = toggle_talk_input,
  }
end

return M
