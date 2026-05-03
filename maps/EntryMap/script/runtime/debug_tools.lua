local M = {}

local UiRoot = require 'ui.ui_root'

function M.create(env)
  local STATE = env.STATE
  local CONFIG = env.CONFIG
  local y3 = env.y3
  local message = env.message
  local round_number = env.round_number
  local make_point = env.make_point
  local develop_command = env.develop_command
  local effect_debug_system = env.effect_debug_system
  local sample_skill_system = env.sample_skill_system
  local DEFAULT_DEBUG_PROJECTILE_KEY = 134255250

  local function round(value)
    return round_number(tonumber(value) or 0)
  end

  local function is_alive(ui)
    return ui and (not ui.is_removed or not ui:is_removed())
  end

  local function set_visible(ui, visible)
    if is_alive(ui) and ui.set_visible then
      ui:set_visible(visible == true)
    end
  end

  local function set_text(ui, text)
    if is_alive(ui) and ui.set_text then
      ui:set_text(text or '')
    end
  end

  local function set_z_order(ui, z)
    if is_alive(ui) and ui.set_z_order then
      ui:set_z_order(z)
    end
  end

  local function set_intercepts(ui, intercepts)
    if is_alive(ui) and ui.set_intercepts_operations then
      ui:set_intercepts_operations(intercepts == true)
    end
  end

  local function is_ui_path_visible(path)
    if not path or path == '' or not env.get_player or not y3 or not y3.ui or not y3.ui.get_ui then
      return false
    end
    local player = env.get_player()
    if not player then
      return false
    end
    local ok, ui = pcall(y3.ui.get_ui, player, path)
    if not ok or not ui or (ui.is_removed and ui:is_removed()) then
      return false
    end
    if ui.is_real_visible then
      local visible_ok, visible = pcall(ui.is_real_visible, ui)
      if visible_ok then
        return visible == true
      end
    end
    if ui.is_visible then
      local visible_ok, visible = pcall(ui.is_visible, ui)
      if visible_ok then
        return visible == true
      end
    end
    return false
  end

  local function has_pending_modal_choice()
    if STATE.choice_panel_hidden == true then
      return false
    end
    if STATE.gear_state and STATE.gear_state.awaiting_choice and STATE.gear_state.current_choices and #STATE.gear_state.current_choices > 0 then
      return true
    end
    if STATE.attr_choice_runtime and STATE.attr_choice_runtime.awaiting_choice and STATE.attr_choice_runtime.current_choices
        and #STATE.attr_choice_runtime.current_choices > 0 then
      return true
    end
    if STATE.bond_runtime and STATE.bond_runtime.awaiting_choice and STATE.bond_runtime.current_choices
        and #STATE.bond_runtime.current_choices > 0 then
      return true
    end
    return false
  end

  local function is_gm_temporarily_blocked()
    if STATE.session_phase ~= 'battle' then
      return true
    end
    if STATE.archive_panel_visible == true then
      return true
    end
    if has_pending_modal_choice() then
      return true
    end
    if is_ui_path_visible('GameHUD.setting_panel') then
      return true
    end
    if is_ui_path_visible('top.top.left_buttons.exit_confirm') then
      return true
    end
    if is_ui_path_visible('top.top.left_buttons.exit_confirm_panel') then
      return true
    end
    if is_ui_path_visible('ArchivePanel') then
      return true
    end
    if is_ui_path_visible('win') or is_ui_path_visible('loss') then
      return true
    end
    return false
  end

  local function point_to_table(point)
    return {
      x = round(point:get_x()),
      y = round(point:get_y()),
      z = round(point:get_z()),
    }
  end

  local function format_point(point)
    if not point then
      return '(nil)'
    end
    return string.format('(%d, %d, %d)', round(point:get_x()), round(point:get_y()), round(point:get_z()))
  end

  local function get_area(area_name)
    return CONFIG.areas[area_name]
  end

  local function get_area_size(area_name)
    local area = get_area(area_name)
    if not area then
      return nil, nil
    end
    return area.x_max - area.x_min, area.y_max - area.y_min
  end

  local function update_point_config(point_name, point)
    local point_data = point_to_table(point)
    CONFIG.points[point_name] = point_data
    if point_name == 'hero_spawn' then
      STATE.hero_spawn_point = make_point(point_data)
    elseif point_name == 'defense_point' then
      STATE.defense_point = make_point(point_data)
    end
    return point_data
  end

  local function recenter_area(area_name, center_point, width, height, offset_x, offset_y)
    local area = get_area(area_name)
    if not area then
      return nil
    end

    local current_width, current_height = get_area_size(area_name)
    width = width or current_width or 200
    height = height or current_height or 200
    offset_x = offset_x or 0
    offset_y = offset_y or 0

    local center_x = center_point:get_x() + offset_x
    local center_y = center_point:get_y() + offset_y
    local half_width = width / 2
    local half_height = height / 2
    area.x_min = round(center_x - half_width)
    area.x_max = round(center_x + half_width)
    area.y_min = round(center_y - half_height)
    area.y_max = round(center_y + half_height)
    area.z = round(center_point:get_z())
    return area
  end

  local function dump_calibration_file()
    local lines = {
      '-- 游戏内校准导出',
      'return {',
      '  points = {',
    }
    for key, point in pairs(CONFIG.points) do
      lines[#lines + 1] = string.format(
        '    %s = { x = %d, y = %d, z = %d },',
        key,
        round(point.x),
        round(point.y),
        round(point.z or 0)
      )
    end
    lines[#lines + 1] = '  },'
    lines[#lines + 1] = '  areas = {'
    for key, area in pairs(CONFIG.areas) do
      lines[#lines + 1] = string.format(
        '    %s = { x_min = %d, x_max = %d, y_min = %d, y_max = %d, z = %d },',
        key,
        round(area.x_min),
        round(area.x_max),
        round(area.y_min),
        round(area.y_max),
        round(area.z or 0)
      )
    end
    lines[#lines + 1] = '  },'
    lines[#lines + 1] = '}'
    y3.fs.save('.log/entry_calibration.lua', table.concat(lines, '\n'))
    message('已导出当前 points/areas 到 script/.log/entry_calibration.lua')
  end

  local function show_calibration_help()
    message('校准指令：.epos / .eset hero / .eset defense / .earea 区域名 [宽] [高] [偏移X] [偏移Y] / .eblink hero|defense / .edump')
  end

  local function debug_message(text)
    message('[DEBUG] ' .. tostring(text))
  end

  local function get_challenge_charge_text()
    local max_charges = CONFIG.challenge_rules.max_charges or 0
    if not STATE.challenge_charge_map then
      return string.format('%d/%d', round(STATE.challenge_charges or 0), round(max_charges))
    end

    local parts = {}
    for _, challenge_id in ipairs({ 'gold_trial', 'wood_trial', 'exp_trial' }) do
      local challenge_def = CONFIG.challenges and CONFIG.challenges[challenge_id]
      if challenge_def then
        parts[#parts + 1] = string.format(
          '%s %d/%d',
          tostring(challenge_def.hotkey or challenge_id),
          round(STATE.challenge_charge_map[challenge_id] or 0),
          round(max_charges)
        )
      end
    end
    return table.concat(parts, '  ')
  end

  local function show_debug_hotkey_help()
    debug_message('Ctrl+F1：显示调试快捷键说明')
    debug_message('Ctrl+F2：补 500 金币 / 300 木材')
    debug_message('Ctrl+F3：英雄直接升 3 级')
    debug_message('Ctrl+F4：普攻技能调试入口已停用')
    debug_message('Ctrl+F6：直接触发 F 抽卡（木材不足时自动补足）')
    debug_message('Ctrl+F7：补满挑战次数')
    debug_message('Ctrl+F8：立刻刷出当前波 Boss')
    debug_message('Ctrl+F9：秒杀场上全部敌人')
    debug_message('Ctrl+F10：显示 / 隐藏 羁绊GM 面板')
    debug_message('投射物覆盖命令：.eproj [id|off|toggle]（默认ID=134255250）')
    debug_message('特效命令：.eeffect [id] / .eemount [id] / .eeunmount [id] / .eetrigger [id] / .eeobs [id] / .eeclear / .eelog')
    debug_message('羁绊GM命令：.egmbond [on|off|toggle] / .egmcard <card_id|卡名> / .egmbondeffect <羁绊名>')
    debug_message('样例技能命令：.esample list / .esample next / .esample report / .esample <sample_id>')
    debug_message('验收快照命令：.esample report（别名：.esample r）')
    debug_message('框架统计命令：.eframe <sample_id>（示例：.eframe ice_lance）')
    debug_message('分档连测命令：.etier run / .etier report')
  end

  local function register_dev_commands()
    if STATE.dev_commands_registered then
      return
    end
    STATE.dev_commands_registered = true

    develop_command.register('EPOS', {
      desc = '打印英雄、防线与主要刷新区域坐标。',
      onCommand = function()
        local point = env.get_hero_point()
        message('英雄当前位置：' .. format_point(point))
        message('英雄出生点：' .. format_point(STATE.hero_spawn_point))
        message('防线点：' .. format_point(STATE.defense_point))
        for _, area_name in ipairs({
          'main_spawn_wave_1',
          'main_spawn_wave_3',
          'main_spawn_wave_5',
          'challenge_spawn_top',
          'challenge_spawn_mid',
          'challenge_spawn_bottom',
        }) do
          local area = get_area(area_name)
          if area then
            message(string.format('%s: x[%d,%d] y[%d,%d]', area_name, round(area.x_min), round(area.x_max), round(area.y_min), round(area.y_max)))
          end
        end
      end,
    })

    develop_command.register('ESET', {
      desc = '把 hero/defense 记录到当前英雄位置。',
      onCommand = function(target_name)
        local point = env.get_hero_point()
        if not point then
          message('当前没有可用英雄，无法记录坐标。')
          return
        end
        target_name = (target_name or ''):lower()
        if target_name == 'hero' then
          local point_data = update_point_config('hero_spawn', point)
          message(string.format('已记录 hero_spawn = (%d, %d, %d)', point_data.x, point_data.y, point_data.z))
          return
        end
        if target_name == 'defense' then
          local point_data = update_point_config('defense_point', point)
          message(string.format('已记录 defense_point = (%d, %d, %d)', point_data.x, point_data.y, point_data.z))
          return
        end
        show_calibration_help()
      end,
    })

    develop_command.register('EAREA', {
      desc = '以当前英雄位置为中心重设某个刷新区域。',
      onCommand = function(area_name, width, height, offset_x, offset_y)
        local point = env.get_hero_point()
        if not point then
          message('当前没有可用英雄，无法设置区域。')
          return
        end
        if not area_name or area_name == '' then
          show_calibration_help()
          return
        end
        if not get_area(area_name) then
          message('未知区域：' .. tostring(area_name))
          return
        end
        local area = recenter_area(area_name, point, tonumber(width), tonumber(height), tonumber(offset_x), tonumber(offset_y))
        if area then
          message(string.format('已重设 %s: x[%d,%d] y[%d,%d]', area_name, round(area.x_min), round(area.x_max), round(area.y_min), round(area.y_max)))
        end
      end,
    })

    develop_command.register('EBLINK', {
      desc = '把英雄传送到 hero_spawn 或 defense_point。',
      onCommand = function(target_name)
        if not STATE.hero or not STATE.hero:is_exist() then
          message('当前没有可用英雄，无法传送。')
          return
        end
        target_name = (target_name or ''):lower()
        if target_name == 'hero' then
          STATE.hero:blink(STATE.hero_spawn_point)
          message('英雄已传送到 hero_spawn。')
          return
        end
        if target_name == 'defense' then
          STATE.hero:blink(STATE.defense_point)
          message('英雄已传送到 defense_point。')
          return
        end
        show_calibration_help()
      end,
    })

    develop_command.register('EDUMP', {
      desc = '导出当前校准后的 points/areas 到日志文件。',
      onCommand = function()
        dump_calibration_file()
      end,
    })

    develop_command.register('EHOTKEY', {
      desc = '打印当前调试快捷键说明。',
      onCommand = function()
        show_debug_hotkey_help()
      end,
    })

    develop_command.register('EBOND', {
      desc = '直接获得指定流派卡，如 .ebond armor_break_rend',
      onCommand = function(card_id)
        if not card_id or card_id == '' then
          message('用法：.ebond <card_id>')
          return
        end
        env.debug_grant_bond_card(card_id)
      end,
    })

    develop_command.register('EEFFECT', {
      desc = '显示或选中特效，如 .eeffect spell_burst',
      onCommand = function(effect_id)
        if not effect_debug_system then
          message('特效调试系统未初始化。')
          return
        end
        if effect_id and effect_id ~= '' then
          env.debug_select_effect(effect_id)
          return
        end
        for _, entry in ipairs(effect_debug_system.get_effect_list_entries()) do
          message(string.format('%s %s [%s]', entry.id, entry.name or '', entry.mounted and 'ON' or 'OFF'))
        end
      end,
    })

    develop_command.register('EEMOUNT', {
      desc = '挂载当前或指定特效。',
      onCommand = function(effect_id)
        env.debug_mount_effect(effect_id)
      end,
    })

    develop_command.register('EEUNMOUNT', {
      desc = '卸下当前或指定特效。',
      onCommand = function(effect_id)
        env.debug_unmount_effect(effect_id)
      end,
    })

    develop_command.register('EETRIGGER', {
      desc = '强制触发当前或指定特效。',
      onCommand = function(effect_id)
        env.debug_trigger_effect(effect_id)
      end,
    })

    develop_command.register('EEOBS', {
      desc = '观测当前或指定特效 10 秒。',
      onCommand = function(effect_id)
        env.debug_start_effect_observe(effect_id)
      end,
    })

    develop_command.register('EELOG', {
      desc = '打印特效调试日志。',
      onCommand = function()
        env.debug_print_effect_logs()
      end,
    })

    develop_command.register('EECLEAR', {
      desc = '清空全部特效调试挂载。',
      onCommand = function()
        env.debug_clear_mounted_effects()
      end,
    })

    develop_command.register('ESAMPLE', {
      desc = '施放样例技能：.esample list|next|report|<sample_id>',
      onCommand = function(arg)
        local raw = tostring(arg or '')
        local cmd = raw:lower()
        if cmd == '' or cmd == 'list' or cmd == 'ls' then
          if env.debug_list_sample_skills then
            env.debug_list_sample_skills()
          end
          return
        end
        if cmd == 'next' then
          if env.debug_cast_next_sample_skill then
            env.debug_cast_next_sample_skill()
          end
          return
        end
        if cmd == 'report' or cmd == 'r' then
          if env.debug_print_sample_framework_report then
            env.debug_print_sample_framework_report()
          end
          return
        end
        if env.debug_cast_sample_skill then
          env.debug_cast_sample_skill(raw)
        end
      end,
    })

    develop_command.register('EFRAME', {
      desc = '打印技能框架 telemetry：.eframe <sample_id>',
      onCommand = function(sample_id)
        local id = tostring(sample_id or '')
        if id == '' then
          message('用法：.eframe <sample_id>，例如 .eframe ice_lance')
          return
        end
        if env.debug_print_sample_framework_telemetry then
          env.debug_print_sample_framework_telemetry(id)
        end
      end,
    })

    develop_command.register('ETIER', {
      desc = '框架分档连测：.etier run|report',
      onCommand = function(arg)
        local cmd = tostring(arg or ''):lower()
        if cmd == '' or cmd == 'run' then
          if env.debug_run_framework_tier_suite then
            env.debug_run_framework_tier_suite()
          end
          return
        end
        if cmd == 'report' or cmd == 'r' then
          if env.debug_print_framework_tier_report then
            env.debug_print_framework_tier_report()
          end
          return
        end
        message('用法：.etier run|report')
      end,
    })

    develop_command.register('EPROJ', {
      desc = '全局投射物覆盖：.eproj 134255250 / .eproj off / .eproj toggle',
      onCommand = function(arg)
        local cmd = tostring(arg or ''):lower()
        if cmd == 'off' or cmd == 'close' or cmd == '0' then
          if env.debug_clear_global_projectile_override then
            env.debug_clear_global_projectile_override()
          end
          return
        end
        if cmd == '' or cmd == 'toggle' then
          if env.debug_toggle_global_projectile_override then
            env.debug_toggle_global_projectile_override(DEFAULT_DEBUG_PROJECTILE_KEY)
          end
          return
        end
        local key = tonumber(cmd)
        if not key or key <= 0 then
          message('用法：.eproj [id|off|toggle]，例如 .eproj 134255250')
          return
        end
        if env.debug_set_global_projectile_override then
          env.debug_set_global_projectile_override(key)
        end
      end,
    })
  end

  local function get_gm_panel_wave_text()
    local wave = env.get_current_wave()
    if not wave then
      return '波次：未开始'
    end
    local wave_name = wave.name or '第' .. tostring(wave.index) .. '波'
    return string.format('波次：%d  %s', wave.index or 0, wave_name)
  end

  local function get_gm_panel_boss_text()
    if not STATE.active_wave or not STATE.active_wave.wave then
      return 'Boss：等待本波开始'
    end
    if STATE.active_wave.boss_spawned then
      return string.format('Boss：%s 已登场', env.get_boss_name(STATE.active_wave.wave))
    end
    local remaining = math.max(0, STATE.active_wave.wave.boss_spawn_sec - STATE.active_wave.elapsed)
    return string.format('Boss：%.1f 秒后登场', remaining)
  end

  local function get_gm_panel_status_text()
    local level = env.get_hero_level()
    local gold = STATE.resources and STATE.resources.gold or 0
    local wood = STATE.resources and STATE.resources.wood or 0
    local enemy_count = STATE.total_enemy_alive or 0
    local challenge_count = env.get_active_challenge_count()
    return table.concat({
      get_gm_panel_wave_text(),
      get_gm_panel_boss_text(),
      string.format('英雄：Lv.%d    敌人数：%d', round(level), round(enemy_count)),
      string.format('金币：%d    木材：%d', round(gold), round(wood)),
      string.format('挑战次数：%s', get_challenge_charge_text()),
      string.format('进行中挑战：%d', round(challenge_count)),
      string.format('全局投射物覆盖：%s', tostring((env.debug_get_global_projectile_override and env.debug_get_global_projectile_override()) or '关闭')),
    }, '\n')
  end

  local refresh_gm_panel
  local toggle_gm_panel
  local ensure_gm_panel

  local function create_rect(parent, x, y, width, height, color)
    color = color or { 42, 72, 108, 230 }
    local ui = parent:create_child('图片')
    ui:set_image(999)
    ui:set_ui_size(width, height)
    ui:set_pos(x + width / 2, y + height / 2)
    ui:set_image_color(color[1] or 42, color[2] or 72, color[3] or 108, color[4] or 230)
    return ui
  end

  local function create_text(parent, text, x, y, width, height, font_size, color)
    local ui = parent:create_child('文本')
    ui:set_ui_size(width, height)
    ui:set_pos(x + width / 2, y + height / 2)
    ui:set_text(text or '')
    ui:set_font_size(font_size or 14)
    ui:set_text_color(color and color[1] or 230, color and color[2] or 238, color and color[3] or 248, color and color[4] or 255)
    ui:set_text_alignment('左', '中')
    return ui
  end

  local function create_button(parent, text, x, y, width, height, callback, color)
    create_rect(parent, x, y, width, height, color or { 120, 128, 140, 110 })
    local button = parent:create_child('按钮')
    button:set_ui_size(width, height)
    button:set_pos(x + width / 2, y + height / 2)
    button:set_text(text)
    button:set_font_size(15)
    button:set_text_color(245, 248, 255, 255)
    button:set_z_order(9502)
    button:add_fast_event('左键-点击', function()
      if callback then
        callback()
      end
      if refresh_gm_panel then
        refresh_gm_panel()
      end
    end)
    return button
  end

  local function format_effect_list_text(entry)
    local selected = entry.selected and '>' or ' '
    local mounted = entry.mounted and 'ON' or 'OFF'
    local active = entry.active and '可用' or '未激活'
    return string.format('%s%s [%s/%s]', selected, entry.name or entry.id or 'none', mounted, active)
  end

  local function get_effect_detail_text()
    if not effect_debug_system then
      return '特效调试系统未初始化'
    end
    return table.concat(effect_debug_system.build_selected_detail_lines(), '\n')
  end

  local function get_effect_log_text()
    if not effect_debug_system then
      return '暂无调试日志'
    end
    return table.concat(effect_debug_system.get_recent_logs(8), '\n')
  end

  local function refresh_effect_debug_panel()
    local gm_ui = STATE.gm_ui
    local effect_ui = gm_ui and gm_ui.effect_debug
    if not effect_ui then
      return
    end

    local visible = gm_ui.visible == true
    set_visible(effect_ui.panel, visible)
    if not visible then
      return
    end

    local entries = effect_debug_system and effect_debug_system.get_effect_list_entries() or {}
    for index, button in ipairs(effect_ui.list_buttons or {}) do
      local entry = entries[index]
      set_visible(button, entry ~= nil)
      if entry then
        set_text(button, format_effect_list_text(entry))
      end
    end
    set_text(effect_ui.detail_text, get_effect_detail_text())
    set_text(effect_ui.log_text, get_effect_log_text())
  end

  local function build_effect_debug_panel(panel)
    local effect_ui = {
      visible = true,
      list_buttons = {},
    }
    STATE.gm_ui.effect_debug = effect_ui

    effect_ui.panel = create_rect(panel, 378, 56, 492, 470, { 11, 23, 36, 230 })
    create_text(panel, '特效调试 / 验收', 390, 494, 190, 26, 20, { 245, 248, 255, 255 })
    create_text(panel, '选择任意特效查看功能、状态、失败原因，并可强制触发。', 390, 468, 440, 22, 13, { 154, 178, 208, 255 })

    for index = 1, 8 do
      local y = 426 - (index - 1) * 34
      effect_ui.list_buttons[index] = create_button(panel, '', 394, y, 208, 28, function()
        local entries = effect_debug_system and effect_debug_system.get_effect_list_entries() or {}
        local entry = entries[index]
        if entry and env.debug_select_effect then
          env.debug_select_effect(entry.id)
        end
      end, { 28, 56, 86, 230 })
    end

    create_rect(panel, 612, 226, 250, 240, { 7, 14, 22, 80 })
    effect_ui.detail_text = create_text(panel, '', 618, 236, 238, 220, 13, { 224, 234, 248, 255 })

    create_button(panel, '挂载', 394, 136, 94, 30, function()
      env.debug_mount_effect()
    end, { 54, 96, 122, 235 })
    create_button(panel, '卸下', 500, 136, 94, 30, function()
      env.debug_unmount_effect()
    end, { 86, 74, 112, 235 })
    create_button(panel, '触发', 394, 100, 94, 30, function()
      env.debug_trigger_effect()
    end, { 112, 78, 82, 235 })
    create_button(panel, '观测', 500, 100, 94, 30, function()
      env.debug_start_effect_observe()
    end, { 78, 100, 136, 235 })
    create_button(panel, '清空挂载', 394, 64, 94, 30, function()
      env.debug_clear_mounted_effects()
    end, { 92, 80, 94, 235 })
    create_button(panel, '打印日志', 500, 64, 94, 30, function()
      env.debug_print_effect_logs()
    end, { 68, 96, 126, 235 })
    create_button(panel, '打开调试', 394, 28, 200, 28, function()
      if env.debug_open_effect_debug_panel then
        env.debug_open_effect_debug_panel()
      end
    end, { 54, 76, 108, 235 })

    create_text(panel, '最近日志', 618, 184, 120, 20, 15, { 245, 248, 255, 255 })
    effect_ui.log_text = create_text(panel, '', 618, 64, 238, 118, 12, { 176, 199, 224, 255 })

    return effect_ui
  end

  local function get_showcase_center_point()
    if STATE and STATE.defense_point then
      return STATE.defense_point
    end
    if env.get_hero_point then
      return env.get_hero_point()
    end
    return nil
  end

  local function build_sample_showcase_panel(panel)
    local sample_ui = {
      list_buttons = {},
      page = 1,
    }
    STATE.gm_ui.sample_showcase = sample_ui

    sample_ui.panel = create_rect(panel, 18, 22, 380, 370, { 14, 26, 40, 232 })
    create_text(panel, '技能列表', 30, 362, 120, 24, 18, { 245, 248, 255, 255 })
    create_text(panel, '点击技能名施放  |  CSV 配表驱动', 30, 342, 360, 18, 12, { 168, 192, 220, 255 })
    sample_ui.page_text = create_text(panel, '', 280, 362, 110, 20, 12, { 205, 220, 236, 255 })
    sample_ui.status_text = create_text(panel, '', 30, 32, 350, 18, 12, { 184, 206, 230, 255 })

    for i = 1, 10 do
      local y = 310 - (i - 1) * 28
      sample_ui.list_buttons[i] = create_button(panel, '', 30, y, 326, 24, function()
        if not sample_skill_system or not sample_skill_system.get_sample_defs then
          debug_message('样例技能系统未初始化。')
          return
        end
        local defs = sample_skill_system.get_sample_defs() or {}
        local base = (sample_ui.page - 1) * 10
        local def = defs[base + i]
        if not def then
          return
        end
        local center = get_showcase_center_point()
        if center and STATE and STATE.hero and STATE.hero.blink then
          pcall(STATE.hero.blink, STATE.hero, center)
        end
        local center_text = center and format_point(center) or '(nil)'
        if env.debug_cast_sample_skill then
          env.debug_cast_sample_skill(def.id)
          set_text(sample_ui.status_text, string.format('已施放：%s @ %s', tostring(def.id), center_text))
        end
      end, { 90, 98, 110, 130 })
    end

    create_button(panel, '上一页', 30, 54, 84, 24, function()
      local defs = sample_skill_system and sample_skill_system.get_sample_defs and sample_skill_system.get_sample_defs() or {}
      local pages = math.max(1, math.ceil((#defs) / 10))
      sample_ui.page = math.max(1, sample_ui.page - 1)
      if sample_ui.page > pages then
        sample_ui.page = pages
      end
    end, { 66, 90, 120, 235 })

    create_button(panel, '下一页', 124, 54, 84, 24, function()
      local defs = sample_skill_system and sample_skill_system.get_sample_defs and sample_skill_system.get_sample_defs() or {}
      local pages = math.max(1, math.ceil((#defs) / 10))
      sample_ui.page = math.min(pages, sample_ui.page + 1)
    end, { 66, 90, 120, 235 })

    create_button(panel, '中区连播', 218, 54, 138, 24, function()
      local center = get_showcase_center_point()
      if center and STATE and STATE.hero and STATE.hero.blink then
        pcall(STATE.hero.blink, STATE.hero, center)
      end
      if env.debug_cast_next_sample_skill then
        env.debug_cast_next_sample_skill()
        local center_text = center and format_point(center) or '(nil)'
        set_text(sample_ui.status_text, string.format('已连播下一个样例 @ %s', center_text))
      end
    end, { 92, 82, 116, 235 })

    return sample_ui
  end

  local function refresh_sample_showcase_panel()
    local gm_ui = STATE.gm_ui
    local sample_ui = gm_ui and gm_ui.sample_showcase
    if not sample_ui then
      return
    end
    local visible = gm_ui.visible == true
    set_visible(sample_ui.panel, visible)
    if not visible then
      return
    end
    local defs = sample_skill_system and sample_skill_system.get_sample_defs and sample_skill_system.get_sample_defs() or {}
    local pages = math.max(1, math.ceil((#defs) / 10))
    if sample_ui.page > pages then
      sample_ui.page = pages
    end
    if sample_ui.page < 1 then
      sample_ui.page = 1
    end
    set_text(sample_ui.page_text, string.format('第 %d/%d 页', sample_ui.page, pages))
    local base = (sample_ui.page - 1) * 10
    for i = 1, 10 do
      local idx = base + i
      local def = defs[idx]
      local btn = sample_ui.list_buttons[i]
      set_visible(btn, def ~= nil)
      if def then
        set_text(btn, string.format('%d) %s', idx, tostring(def.name or def.id)))
      end
    end
  end

  refresh_gm_panel = function()
    local gm_ui = STATE.gm_ui
    if not gm_ui then
      return
    end
    local blocked = is_gm_temporarily_blocked()
    set_visible(gm_ui.panel, gm_ui.visible == true and not blocked)
    set_intercepts(gm_ui.panel, gm_ui.visible == true and not blocked)
    set_visible(gm_ui.toggle_button, not blocked)
    if blocked then
      return
    end
    if is_alive(gm_ui.toggle_button) then
      gm_ui.toggle_button:set_text(gm_ui.visible and '收起GM' or 'GM')
    end
    set_text(gm_ui.status_text, get_gm_panel_status_text())
    refresh_effect_debug_panel()
    refresh_sample_showcase_panel()
  end

  toggle_gm_panel = function()
    if not STATE.gm_ui then
      return
    end
    STATE.gm_ui.visible = not STATE.gm_ui.visible
    refresh_gm_panel()
  end

  ensure_gm_panel = function()
    local parent = UiRoot.get_overlay_parent(y3, env.get_player())
    if not parent then
      return nil
    end

    if STATE.gm_ui and is_alive(STATE.gm_ui.panel) then
      refresh_gm_panel()
      return STATE.gm_ui
    end

    local gm_ui = { visible = true }
    STATE.gm_ui = gm_ui

    local toggle_button = parent:create_child('按钮')
    toggle_button:set_ui_size(92, 34)
    toggle_button:set_relative_parent_pos('顶部', 18)
    toggle_button:set_relative_parent_pos('右侧', 66)
    toggle_button:set_text('收起GM')
    toggle_button:set_font_size(16)
    toggle_button:set_text_color(235, 242, 255, 255)
    toggle_button:set_z_order(9501)
    toggle_button:add_fast_event('左键-点击', function()
      toggle_gm_panel()
    end)
    gm_ui.toggle_button = toggle_button

    local panel = parent:create_child('图片')
    panel:set_image(999)
    panel:set_ui_size(900, 590)
    panel:set_relative_parent_pos('顶部', 62)
    panel:set_relative_parent_pos('右侧', 18)
    panel:set_image_color(8, 14, 22, 225)
    panel:set_z_order(9500)
    panel:set_intercepts_operations(true)
    gm_ui.panel = panel

    create_rect(panel, 18, 520, 850, 50, { 20, 38, 58, 230 })
    create_text(panel, 'GM 调试面板', 34, 536, 220, 28, 24, { 245, 248, 255, 255 })
    create_text(panel, '旧 GM 功能与特效验收已合并，右侧可查看每个特效功能与触发状态。', 250, 538, 560, 22, 14, { 156, 178, 208, 255 })

    create_rect(panel, 18, 382, 338, 120, { 14, 27, 42, 235 })
    gm_ui.status_text = create_text(panel, '', 34, 394, 306, 96, 16, { 233, 239, 248, 255 })

    local actions = {
      { '帮助 / F1', env.show_debug_hotkey_help or show_debug_hotkey_help, { 58, 84, 120 } },
      { '加资源 / F2', env.debug_add_test_resources, { 73, 94, 132 } },
      { '升 3 级 / F3', function() env.debug_grant_levels(3) end, { 64, 88, 128 } },
      { '技能废弃 / F4', env.debug_unlock_all_attack_skills, { 84, 97, 138 } },
      { '抽流派 / F6', env.debug_trigger_bond_draw, { 84, 110, 150 } },
      { '满挑战 / F7', env.debug_refill_challenge_charges, { 70, 112, 142 } },
      { '刷 Boss / F8', env.debug_force_spawn_boss, { 110, 86, 126 } },
      { '清全场 / F9', env.debug_kill_all_active_enemies, { 128, 74, 88 } },
      { '属性对话框', env.debug_open_attr_overview, { 74, 100, 136 } },
      { '输出属性', env.debug_show_attr_tip_panel, { 70, 104, 134 } },
      { '打印状态', env.show_runtime_status, { 60, 92, 120 } },
      { '样例技能', env.debug_cast_next_sample_skill, { 96, 84, 130 } },
      { '样例列表', env.debug_list_sample_skills, { 82, 96, 126 } },
      { '验收快照', env.debug_print_sample_framework_report, { 88, 112, 146 } },
      { '分档连测', env.debug_run_framework_tier_suite, { 86, 92, 132 } },
      { '分档报告', env.debug_print_framework_tier_report, { 86, 102, 142 } },
      { '投射物覆盖', function()
        if env.debug_toggle_global_projectile_override then
          env.debug_toggle_global_projectile_override(DEFAULT_DEBUG_PROJECTILE_KEY)
        end
      end, { 96, 106, 132 } },
    }

    create_text(panel, '通用 GM', 26, 344, 120, 24, 18, { 245, 248, 255, 255 })
    for index, action in ipairs(actions) do
      local column = (index - 1) % 2
      local row = math.floor((index - 1) / 2)
      create_button(
        panel,
        action[1],
        24 + column * 168,
        300 - row * 44,
        154,
        36,
        action[2],
        action[3]
      )
    end

    build_effect_debug_panel(panel)
    build_sample_showcase_panel(panel)
    set_z_order(panel, 9500)
    set_intercepts(panel, true)
    refresh_gm_panel()
    return gm_ui
  end

  local function remove_ui_if_alive(ui)
    if ui and ui.is_exist and ui:is_exist() and ui.remove then
      pcall(ui.remove, ui)
      return
    end
    if ui and ui.is_removed and (not ui:is_removed()) and ui.remove then
      pcall(ui.remove, ui)
    end
  end

  local function disable_legacy_gm_panel()
    if STATE.gm_ui then
      remove_ui_if_alive(STATE.gm_ui.panel)
      remove_ui_if_alive(STATE.gm_ui.toggle_button)
      STATE.gm_ui = nil
    end
  end

  disable_legacy_gm_panel()

  refresh_gm_panel = function()
    return
  end
  toggle_gm_panel = function()
    return
  end
  ensure_gm_panel = function()
    return nil
  end

  return {
    point_to_table = point_to_table,
    format_point = format_point,
    get_area = get_area,
    get_area_size = get_area_size,
    update_point_config = update_point_config,
    recenter_area = recenter_area,
    dump_calibration_file = dump_calibration_file,
    show_calibration_help = show_calibration_help,
    debug_message = debug_message,
    show_debug_hotkey_help = show_debug_hotkey_help,
    register_dev_commands = register_dev_commands,
    get_gm_panel_wave_text = get_gm_panel_wave_text,
    get_gm_panel_boss_text = get_gm_panel_boss_text,
    get_gm_panel_status_text = get_gm_panel_status_text,
    refresh_gm_panel = refresh_gm_panel,
    toggle_gm_panel = toggle_gm_panel,
    ensure_gm_panel = ensure_gm_panel,
  }
end

return M
