local M = {}

function M.create(deps)
  local env = deps.env
  local y3 = deps.y3
  local ui_res = deps.ui_res
  local theme = deps.theme
  local create_panel = deps.create_panel
  local create_text = deps.create_text
  local set_percent_pos = deps.set_percent_pos
  local get_hud_scale = deps.get_hud_scale
  local get_hud_root = deps.get_hud_root
  local RuntimeHudNodes = deps.RuntimeHudNodes
  local is_ui_alive = deps.is_ui_alive
  local set_visible_if_alive = deps.set_visible_if_alive
  local set_text_if_alive = deps.set_text_if_alive
  local set_image_if_alive = deps.set_image_if_alive
  local bind_ui_click_once = deps.bind_ui_click_once
  local open_save_panel = deps.open_save_panel
  local hide_growth_weapon_tip = deps.hide_growth_weapon_tip
  local show_growth_weapon_tip = deps.show_growth_weapon_tip

  local function get_absolute_x(ui)
    if not is_ui_alive(ui) or not ui.get_absolute_x then
      return nil
    end
    local ok, value = pcall(ui.get_absolute_x, ui)
    return ok and tonumber(value) or nil
  end

  local function get_absolute_y(ui)
    if not is_ui_alive(ui) or not ui.get_absolute_y then
      return nil
    end
    local ok, value = pcall(ui.get_absolute_y, ui)
    return ok and tonumber(value) or nil
  end

  local function get_real_width(ui)
    if not is_ui_alive(ui) or not ui.get_real_width then
      return nil
    end
    local ok, value = pcall(ui.get_real_width, ui)
    return ok and tonumber(value) or nil
  end

  local function get_real_height(ui)
    if not is_ui_alive(ui) or not ui.get_real_height then
      return nil
    end
    local ok, value = pcall(ui.get_real_height, ui)
    return ok and tonumber(value) or nil
  end

  local function get_ui_width(ui)
    if not is_ui_alive(ui) or not ui.get_width then
      return nil
    end
    local ok, value = pcall(ui.get_width, ui)
    return ok and tonumber(value) or nil
  end

  local function get_ui_height(ui)
    if not is_ui_alive(ui) or not ui.get_height then
      return nil
    end
    local ok, value = pcall(ui.get_height, ui)
    return ok and tonumber(value) or nil
  end

  local function get_ui_size(ui, fallback_width, fallback_height)
    local width = get_real_width(ui) or get_ui_width(ui) or fallback_width or 0
    local height = get_real_height(ui) or get_ui_height(ui) or fallback_height or 0
    return math.max(1, math.floor(width)), math.max(1, math.floor(height))
  end

  local function set_passthrough_if_alive(ui, enabled)
    if is_ui_alive(ui) and ui.set_intercepts_operations then
      ui:set_intercepts_operations(enabled ~= true)
    end
  end

  local function align_ui_to_host(ui, host)
    if not is_ui_alive(ui) or not is_ui_alive(host) then
      return
    end
    local abs_x = get_absolute_x(host)
    local abs_y = get_absolute_y(host)
    if abs_x ~= nil and abs_y ~= nil and ui.set_absolute_pos then
      ui:set_absolute_pos(abs_x, abs_y)
    end
    local width = get_real_width(host)
    local height = get_real_height(host)
    if width and height and ui.set_ui_size then
      ui:set_ui_size(width, height)
    end
    if ui.set_visible then
      ui:set_visible(true)
    end
  end

  local function create_bottom_icon_slot(host, z_order)
    if not is_ui_alive(host) then
      return nil
    end

    local width, height = get_ui_size(host, 66, 66)
    local frame = create_panel(
      host,
      width * 0.5,
      height * 0.5,
      width,
      height,
      { 255, 255, 255, 0 },
      theme.insets.soft,
      z_order or 9400,
      ui_res.common.empty
    )
    frame:set_anchor(0.5, 0.5)
    set_passthrough_if_alive(frame, true)

    local icon = create_panel(
      frame,
      width * 0.5,
      height * 0.5,
      math.max(8, width - 10),
      math.max(8, height - 10),
      { 255, 255, 255, 255 },
      theme.insets.soft,
      (z_order or 9400) + 1,
      ui_res.common.empty
    )
    icon:set_anchor(0.5, 0.5)
    set_passthrough_if_alive(icon, true)

    local shade = create_panel(
      frame,
      width * 0.5,
      height * 0.5,
      math.max(8, width - 10),
      math.max(8, height - 10),
      { 8, 12, 20, 0 },
      theme.insets.soft,
      (z_order or 9400) + 2,
      ui_res.common.empty
    )
    shade:set_anchor(0.5, 0.5)
    set_passthrough_if_alive(shade, true)

    local hotkey = create_text(
      frame,
      4,
      height - 18,
      math.max(18, width * 0.32),
      16,
      11,
      { 236, 240, 247, 210 },
      '中',
      '中',
      (z_order or 9400) + 3
    )
    set_passthrough_if_alive(hotkey, true)

    local level = create_text(
      frame,
      0,
      3,
      width,
      14,
      10,
      { 255, 232, 174, 255 },
      '中',
      '中',
      (z_order or 9400) + 3
    )
    set_passthrough_if_alive(level, true)

    local cooldown = create_text(
      frame,
      0,
      math.floor(height * 0.32),
      width,
      math.max(18, math.floor(height * 0.36)),
      math.max(12, math.floor(height * 0.28)),
      { 255, 255, 255, 255 },
      '中',
      '中',
      (z_order or 9400) + 4
    )
    set_passthrough_if_alive(cooldown, true)

    return {
      root = frame,
      icon = icon,
      shade = shade,
      hotkey = hotkey,
      level = level,
      cooldown = cooldown,
      host = host,
    }
  end

  local function format_cooldown_text(value)
    local seconds = y3.helper.tonumber(value) or 0
    if seconds <= 0.05 then
      return ''
    end
    if seconds >= 10 then
      return tostring(math.floor(seconds + 0.5))
    end
    return string.format('%.1f', seconds):gsub('%.0$', '')
  end

  local api = {}

  function api.attach_bottom_bg_prefab(runtime_hud)
    if not runtime_hud or is_ui_alive(runtime_hud.bottom_bg_root) then
      return
    end

    local hud = get_hud_root()
    if not hud then
      return
    end

    local prefab = y3.ui_prefab.create(env.get_player(), 'bottom_bg', hud)
    local root = prefab and prefab:get_child() or nil
    if not root then
      return
    end

    root:set_anchor(0.5, 0)
    root:set_relative_parent_pos('底部', 0)
    set_percent_pos(env.get_player(), root, 50, 0)
    if root.set_widget_relative_scale then
      local prefab_scale = math.max(0.84, math.min(1.02, get_hud_scale(hud, y3) * 0.94))
      root:set_widget_relative_scale(prefab_scale, prefab_scale)
    end
    root:set_z_order(9392)

    RuntimeHudNodes.attach_bottom_bg(runtime_hud, prefab)
  end

  function api.layout_legacy_slot_controls(runtime_hud)
    if not runtime_hud then
      return
    end

    set_visible_if_alive(runtime_hud.legacy_gamehud_main, true)
    set_visible_if_alive(runtime_hud.legacy_inventory_bar, true)
    set_visible_if_alive(runtime_hud.legacy_skill_bar, true)

    for slot = 1, 6 do
      align_ui_to_host(
        runtime_hud.legacy_inventory_slot_roots and runtime_hud.legacy_inventory_slot_roots[slot] or nil,
        runtime_hud.bottom_backpack_slot_hosts and runtime_hud.bottom_backpack_slot_hosts[slot] or nil
      )
      align_ui_to_host(
        runtime_hud.legacy_inventory_slots and runtime_hud.legacy_inventory_slots[slot] or nil,
        runtime_hud.bottom_backpack_slot_hosts and runtime_hud.bottom_backpack_slot_hosts[slot] or nil
      )
    end

    for slot = 1, 8 do
      set_visible_if_alive(runtime_hud.legacy_skill_button_roots and runtime_hud.legacy_skill_button_roots[slot] or nil, false)
    end
  end

  function api.bind_bottom_bg_actions(runtime_hud)
    if not runtime_hud then
      return
    end

    bind_ui_click_once(runtime_hud, 'bottom_skill_draw', runtime_hud.bottom_skill_draw_button, function()
      if env.show_upgrade_choices then
        env.show_upgrade_choices()
      end
    end)
    bind_ui_click_once(runtime_hud, 'bottom_bond_draw', runtime_hud.bottom_bond_draw_button, function()
      if env.try_bond_draw then
        env.try_bond_draw()
      end
    end)
    bind_ui_click_once(runtime_hud, 'bottom_gold_trial', runtime_hud.bottom_gold_challenge_button, function()
      if env.try_start_challenge then
        env.try_start_challenge('gold_trial')
      end
    end)
    bind_ui_click_once(runtime_hud, 'bottom_wood_trial', runtime_hud.bottom_wood_challenge_button, function()
      if env.try_start_challenge then
        env.try_start_challenge('wood_trial')
      end
    end)
    bind_ui_click_once(runtime_hud, 'bottom_exp_trial', runtime_hud.bottom_exp_challenge_button, function()
      if env.try_start_challenge then
        env.try_start_challenge('exp_trial')
      end
    end)
    bind_ui_click_once(runtime_hud, 'bottom_treasure_trial', runtime_hud.bottom_treasure_challenge_button, function()
      if env.try_treasure_entry then
        env.try_treasure_entry()
      end
    end)
    bind_ui_click_once(runtime_hud, 'editor_setting_save', runtime_hud.editor_setting_button, function()
      if open_save_panel then
        open_save_panel()
      end
    end)
    bind_ui_click_once(runtime_hud, 'editor_exit_save', runtime_hud.editor_exit_button, function()
      if open_save_panel then
        open_save_panel()
      end
    end)
  end

  function api.ensure_bottom_skill_slots(runtime_hud)
    if not runtime_hud then
      return
    end

    runtime_hud.skill_slots = runtime_hud.skill_slots or {}
    local hotkeys = { 'Q', 'W', 'E', 'R' }
    for slot = 1, 4 do
      local host = runtime_hud.bottom_skill_slot_hosts and runtime_hud.bottom_skill_slot_hosts[slot] or nil
      local existing = runtime_hud.skill_slots[slot]
      if is_ui_alive(host) and (not existing or not is_ui_alive(existing.root)) then
        local slot_view = create_bottom_icon_slot(host, 9410)
        if slot_view and slot_view.hotkey then
          slot_view.hotkey:set_text(hotkeys[slot] or tostring(slot))
        end
        runtime_hud.skill_slots[slot] = slot_view
      end
    end
  end

  function api.ensure_growth_weapon_overlay(runtime_hud)
    if not runtime_hud then
      return
    end

    local host = runtime_hud.bottom_backpack_slot_hosts and runtime_hud.bottom_backpack_slot_hosts[1] or nil
    if not is_ui_alive(host) then
      return
    end
    local existing = runtime_hud.growth_weapon_visual
    if existing and is_ui_alive(existing.root) then
      return
    end

    local slot_view = create_bottom_icon_slot(host, 9406)
    if not slot_view then
      return
    end
    if slot_view.hotkey then
      slot_view.hotkey:set_text('1')
    end
    runtime_hud.growth_weapon_visual = slot_view
  end

  function api.render_bottom_attack_skill_slot(slot_view, skill)
    if not slot_view then
      return
    end

    local is_empty = skill == nil
    local icon_res = skill and (skill.ui_icon or skill.icon) or nil
    set_image_if_alive(slot_view.icon, icon_res or ui_res.common.empty, is_empty
      and { 78, 92, 116, 120 }
      or { 255, 255, 255, 255 })
    set_image_if_alive(slot_view.shade, ui_res.common.empty, is_empty
      and { 12, 16, 24, 160 }
      or ((y3.helper.tonumber(skill.cooldown_remaining) or 0) > 0.05 and { 8, 12, 20, 112 } or { 8, 12, 20, 0 }))
    set_text_if_alive(slot_view.level, skill and ('Lv.' .. tostring(skill.level or 1)) or '')
    set_text_if_alive(slot_view.cooldown, skill and format_cooldown_text(skill.cooldown_remaining) or '')
    set_visible_if_alive(slot_view.root, true)
    set_visible_if_alive(slot_view.icon, true)
    set_visible_if_alive(slot_view.hotkey, true)
    set_visible_if_alive(slot_view.level, not is_empty)
    set_visible_if_alive(slot_view.cooldown, skill and (y3.helper.tonumber(skill.cooldown_remaining) or 0) > 0.05)
  end

  function api.render_growth_weapon_overlay(runtime_hud)
    if not runtime_hud then
      return
    end
    api.ensure_growth_weapon_overlay(runtime_hud)
    local slot_view = runtime_hud.growth_weapon_visual
    if not slot_view then
      return
    end

    local payload = env.build_growth_weapon_tip_payload and env.build_growth_weapon_tip_payload() or nil
    if not payload then
      set_image_if_alive(slot_view.icon, ui_res.common.empty, { 78, 92, 116, 100 })
      set_image_if_alive(slot_view.shade, ui_res.common.empty, { 8, 12, 20, 110 })
      set_text_if_alive(slot_view.level, '')
      set_text_if_alive(slot_view.cooldown, '')
      return
    end

    local level_text = ''
    local level_number = string.match(payload.subtitle_text or '', 'Lv%.?(%d+)')
    if level_number then
      level_text = 'Lv.' .. tostring(level_number)
    end

    set_image_if_alive(slot_view.icon, payload.icon_res or ui_res.common.empty, { 255, 255, 255, 255 })
    set_image_if_alive(slot_view.shade, ui_res.common.empty, { 8, 12, 20, 0 })
    set_text_if_alive(slot_view.level, level_text)
    set_text_if_alive(slot_view.cooldown, '')
    set_visible_if_alive(slot_view.root, true)
    set_visible_if_alive(slot_view.icon, true)
    set_visible_if_alive(slot_view.level, level_text ~= '')
    set_visible_if_alive(slot_view.cooldown, false)
  end

  function api.bind_growth_weapon_slot(runtime_hud)
    if not runtime_hud then
      return
    end

    local slot_ui = runtime_hud.editor_bottom_inventory_slots and runtime_hud.editor_bottom_inventory_slots[1] or nil
    if not slot_ui then
      return
    end

    runtime_hud.growth_weapon_slot = slot_ui
    if runtime_hud.growth_weapon_slot_bound_target == slot_ui then
      return
    end

    runtime_hud.growth_weapon_slot_bound_target = slot_ui
    if slot_ui.set_equip_slot_use_operation then
      slot_ui:set_equip_slot_use_operation('无')
    end
    if slot_ui.set_equip_slot_drag_operation then
      slot_ui:set_equip_slot_drag_operation('无')
    end
    slot_ui:add_fast_event('鼠标-移入', function()
      show_growth_weapon_tip(slot_ui)
    end)
    slot_ui:add_fast_event('鼠标-移出', function()
      hide_growth_weapon_tip()
    end)
    slot_ui:add_fast_event('左键-点击', function()
      hide_growth_weapon_tip()
    end)
  end

  function api.hide_legacy_bottom_nodes(runtime_hud)
    if not runtime_hud then
      return
    end
    for _, legacy_node in ipairs(runtime_hud.legacy_bottom_nodes or {}) do
      set_visible_if_alive(legacy_node, false)
    end
  end

  function api.refresh_skill_slots(runtime_hud, attack_skill_slots)
    for slot = 1, 4 do
      local slot_nodes = runtime_hud.skill_slots and runtime_hud.skill_slots[slot] or nil
      local skill = attack_skill_slots and attack_skill_slots[slot] or nil
      api.render_bottom_attack_skill_slot(slot_nodes, skill)
    end
  end

  return api
end

return M
