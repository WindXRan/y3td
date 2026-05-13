-- ui/hud/hud_core.lua
-- UI 工具函数层：安全包装 Y3 UI API，提供节点解析和格式化辅助函数。
-- 由 runtime_hud.lua (hud_main) 在 M.create() 中初始化。

local M = {}

function M.create(ctx)
  local y3 = ctx.y3
  local ui_root = ctx.ui_root
  local STATE = ctx.STATE
  local get_player_fn = ctx.get_player_fn
  local HERO_MODEL_FRAME_SIZE = ctx.HERO_MODEL_FRAME_SIZE
  local HERO_MODEL_CAMERA = ctx.HERO_MODEL_CAMERA

  local function is_ui_alive(u) return ui_root.is_alive(u) end;

  local function get_player() return get_player_fn and get_player_fn() or nil end;

  local function get_hud_state()
    STATE.runtime_hud = STATE.runtime_hud or {
      nodes = {},
      bound_events = {},
      visible = true,
      attr_panel_visible = false,
      tip_title_text = '',
      tip_body_text = '',
      tip_panel = nil,
      tip_panel_title = nil,
      tip_panel_body = nil,
      tip_expires_at = 0,
      hover_tip_panel = nil,
      hover_tip_panel_icon_bg = nil,
      hover_tip_panel_icon = nil,
      hover_tip_panel_title = nil,
      hover_tip_panel_subtitle = nil,
      hover_tip_panel_body = nil,
      hover_tip_visible = false,
      bond_tip_panel = nil,
      bond_tip_root = nil,
      bond_tip_icon = nil,
      bond_tip_title = nil,
      bond_tip_have = nil,
      bond_tip_swallow = nil,
      bond_tip_detail_body = nil,
      bond_tip_special_title = nil,
      bond_tip_special_body = nil,
      bond_tip_skill_title = nil,
      bond_tip_skill_body = nil,
      bond_tip_set_title = nil,
      bond_tip_visible = false,
      attr_panel = nil,
      attr_panel_title = nil,
      attr_panel_body = nil,
      attr_panel_hint = nil,
      big_cursor = nil,
      hero_model_ui = nil,
      buff_prefab = nil,
      buff_prefab_root = nil,
      buff_list_comp = nil
    }
    return STATE.runtime_hud
  end;

  local function ensure_ui_preferences()
    STATE.ui_preferences = STATE.ui_preferences or {}
    local ui_prefs = STATE.ui_preferences;
    if ui_prefs.hide_damage_text == nil then ui_prefs.hide_damage_text = false end;
    if ui_prefs.hide_hit_effects == nil then ui_prefs.hide_hit_effects = false end;
    if ui_prefs.big_cursor == nil then ui_prefs.big_cursor = false end;
    if ui_prefs.soft_paused == nil then ui_prefs.soft_paused = false end;
    return ui_prefs
  end;

  local function resolve_ui_node(_)
    local hud_state = get_hud_state()
    local cached_node = hud_state.nodes[_]
    if is_ui_alive(cached_node) then return cached_node end;
    local player = get_player()
    if not player then return nil end;
    local u = ui_root.resolve_ui(y3, player, _)
    hud_state.nodes[_] = u;
    return u
  end;

  local function resolve_first_ui_node(name_list)
    local hud_state = get_hud_state()
    local cache_key = '__first__:' .. table.concat(name_list or {}, '|')
    local cached_node = hud_state.nodes[cache_key]
    if is_ui_alive(cached_node) then return cached_node end;
    local player = get_player()
    if not player then return nil end;
    local u = ui_root.resolve_first_ui(y3, player, name_list)
    hud_state.nodes[cache_key] = u;
    return u
  end;

  local function safe_ui_call(u, method_name, ...)
    if not is_ui_alive(u) then return false end;
    local method = u[method_name]
    if type(method) ~= 'function' then return false end;
    return pcall(method, u, ...)
  end;

  local function set_ui_visible(u, visible)
    safe_ui_call(u, 'set_visible', visible == true)
  end;

  local function set_ui_text(u, text)
    safe_ui_call(u, 'set_text', text or '')
  end;

  local function set_ui_text_color(u, color)
    if color then safe_ui_call(u, 'set_text_color', color[1], color[2], color[3], color[4] or 255) end
  end;

  local function set_ui_font_size(u, font_size)
    if font_size then safe_ui_call(u, 'set_font_size', font_size) end
  end;

  local function set_ui_text_alignment(u, h_align, v_align)
    if h_align and v_align then safe_ui_call(u, 'set_text_alignment', h_align, v_align) end
  end;

  local function set_ui_image(u, image_id)
    if image_id ~= nil then safe_ui_call(u, 'set_image', image_id) end
  end;

  local function set_ui_image_color(u, color)
    if color then safe_ui_call(u, 'set_image_color', color[1], color[2], color[3], color[4] or 255) end
  end;

  local function set_ui_size(u, width, height)
    if width and height then safe_ui_call(u, 'set_ui_size', width, height) end
  end;

  local function set_ui_anchor(u, ar, as)
    if ar ~= nil and as ~= nil then safe_ui_call(u, 'set_anchor', ar, as) end
  end;

  local function set_ui_pos(u, ar, as)
    if ar ~= nil and as ~= nil then safe_ui_call(u, 'set_pos', ar, as) end
  end;

  local function set_ui_progress(u, av, aw)
    if not is_ui_alive(u) then return end;
    local ax = math.max(1, math.floor((tonumber(aw) or 1) + 0.5))
    local ay = math.max(0, math.min(ax, math.floor((tonumber(av) or 0) + 0.5)))
    safe_ui_call(u, 'set_max_progress_bar_value', ax)
    safe_ui_call(u, 'set_current_progress_bar_value', ay, 0)
  end;

  local function bind_ui_model_unit(u, aA, aB, aC, aD)
    if aA and aA.is_exist and not aA:is_exist() then aA = nil end;
    if not is_ui_alive(u) or not aA then return false end;
    
    local success = false
    
    if type(u.set_ui_model_unit) == 'function' then
        local ok, err = pcall(u.set_ui_model_unit, u, aA, aB == true, aC == true, aD == true)
        if ok then success = true end
    end
    
    if not success and y3 and y3.unit and y3.unit.get_model_by_key and aA.get_key then
        local unit_key = aA:get_key()
        local model_id = y3.unit.get_model_by_key(unit_key)
        if model_id and model_id ~= 0 then
            if type(u.set_ui_model) == 'function' then
                local ok, err = pcall(u.set_ui_model, u, model_id)
                if ok then success = true end
            end
        end
    end
    
    return success
  end;

  local function apply_ui_model_camera(u, aF)
    if not is_ui_alive(u) or not aF then return end;
    if aF.focus then safe_ui_call(u, 'set_ui_model_focus_pos', aF.focus[1], aF.focus[2], aF.focus[3]) end;
    if aF.fov then safe_ui_call(u, 'change_showroom_fov', aF.fov) end;
    if aF.camera_pos then safe_ui_call(u, 'change_showroom_cposition', aF.camera_pos[1], aF.camera_pos[2],
        aF.camera_pos[3]) end;
    if aF.camera_rot then safe_ui_call(u, 'change_showroom_crotation', aF.camera_rot[1], aF.camera_rot[2],
        aF.camera_rot[3]) end;
    if aF.background then safe_ui_call(u, 'set_show_room_background_color', aF.background[1], aF.background[2],
        aF.background[3], aF.background[4] or 0) end
  end;

  local function set_ui_pos_percent(u, ar, as)
    local player = get_player()
    if not player or not is_ui_alive(u) or not GameAPI or not GameAPI.set_ui_comp_pos_percent then return end;
    pcall(GameAPI.set_ui_comp_pos_percent, player.handle, u.handle, ar, as)
  end;

  local function format_short_number(aI)
    local aJ = tonumber(aI) or 0;
    local aK = math.abs(aJ)
    if aK >= 1000000 then
      local ac = string.format('%.1fm', aJ / 1000000)
      return ac:gsub('%.0m$', 'm')
    end;
    if aK >= 10000 then
      local ac = string.format('%.1fk', aJ / 1000)
      return ac:gsub('%.0k$', 'k')
    end;
    return tostring(math.floor(aJ + 0.5))
  end;

  local function format_time_mmss(aM)
    local aN = math.max(0, math.floor((tonumber(aM) or 0) + 0.5))
    local aO = aN // 60;
    local aP = aN % 60;
    return string.format('%02d:%02d', aO, aP)
  end;

  local function normalize_percent_value(aI)
    local aJ = tonumber(aI) or 0;
    if math.abs(aJ) <= 1 then aJ = aJ * 100 end;
    return aJ
  end;

  local function format_percent(aI) return string.format('%d%%', math.floor(normalize_percent_value(aI) + 0.5)) end;

  local function format_percent_delta(aT, aU)
    local aN = normalize_percent_value(aT) + normalize_percent_value(aU)
    if aN >= 0 then return string.format('+%d%%', math.floor(aN + 0.5)) end;
    return string.format('%d%%', math.floor(aN + 0.5))
  end;

  return {
    is_ui_alive = is_ui_alive,
    get_player = get_player,
    get_hud_state = get_hud_state,
    ensure_ui_preferences = ensure_ui_preferences,
    resolve_ui_node = resolve_ui_node,
    resolve_first_ui_node = resolve_first_ui_node,
    safe_ui_call = safe_ui_call,
    set_ui_visible = set_ui_visible,
    set_ui_text = set_ui_text,
    set_ui_text_color = set_ui_text_color,
    set_ui_font_size = set_ui_font_size,
    set_ui_text_alignment = set_ui_text_alignment,
    set_ui_image = set_ui_image,
    set_ui_image_color = set_ui_image_color,
    set_ui_size = set_ui_size,
    set_ui_anchor = set_ui_anchor,
    set_ui_pos = set_ui_pos,
    set_ui_progress = set_ui_progress,
    bind_ui_model_unit = bind_ui_model_unit,
    apply_ui_model_camera = apply_ui_model_camera,
    set_ui_pos_percent = set_ui_pos_percent,
    format_short_number = format_short_number,
    format_time_mmss = format_time_mmss,
    normalize_percent_value = normalize_percent_value,
    format_percent = format_percent,
    format_percent_delta = format_percent_delta,
  }
end

return M
