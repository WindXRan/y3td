local M = {}

function M.create(env)
  local STATE = env.STATE
  local CONFIG = env.CONFIG
  local y3 = env.y3
  local message = env.message
  local round_number = env.round_number
  local make_point = env.make_point
  local develop_command = env.develop_command
  local effect_debug_system = env.effect_debug_system

  local function format_int(value)
    return round_number(tonumber(value) or 0)
  end

  local function point_to_table(point)
    return {
      x = round_number(point:get_x()),
      y = round_number(point:get_y()),
      z = round_number(point:get_z()),
    }
  end

  local function format_point(point)
    if not point then
      return '(nil)'
    end
    return string.format('(%d, %d, %d)', round_number(point:get_x()), round_number(point:get_y()), round_number(point:get_z()))
  end

  local function get_area(area_id)
    return CONFIG.areas[area_id]
  end

  local function get_area_size(area_id)
    local area = get_area(area_id)
    if not area then
      return nil, nil
    end
    return area.x_max - area.x_min, area.y_max - area.y_min
  end

  local function update_point_config(point_key, point)
    local value = point_to_table(point)
    CONFIG.points[point_key] = value
    if point_key == 'hero_spawn' then
      STATE.hero_spawn_point = make_point(value)
    elseif point_key == 'defense_point' then
      STATE.defense_point = make_point(value)
    end
    return value
  end

  local function recenter_area(area_id, center_point, width, height, offset_x, offset_y)
    local area = get_area(area_id)
    if not area then
      return nil
    end

    local current_width, current_height = get_area_size(area_id)
    width = width or current_width or 200
    height = height or current_height or 200
    offset_x = offset_x or 0
    offset_y = offset_y or 0

    local cx = center_point:get_x() + offset_x
    local cy = center_point:get_y() + offset_y
    local half_w = width / 2
    local half_h = height / 2

    area.x_min = round_number(cx - half_w)
    area.x_max = round_number(cx + half_w)
    area.y_min = round_number(cy - half_h)
    area.y_max = round_number(cy + half_h)
    area.z = round_number(center_point:get_z())
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
        round_number(point.x),
        round_number(point.y),
        round_number(point.z or 0)
      )
    end

    lines[#lines + 1] = '  },'
    lines[#lines + 1] = '  areas = {'

    for key, area in pairs(CONFIG.areas) do
      lines[#lines + 1] = string.format(
        '    %s = { x_min = %d, x_max = %d, y_min = %d, y_max = %d, z = %d },',
        key,
        round_number(area.x_min),
        round_number(area.x_max),
        round_number(area.y_min),
        round_number(area.y_max),
        round_number(area.z or 0)
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
    message('[DEBUG] ' .. text)
  end

  local function build_challenge_charge_text()
    local max_charges = CONFIG.challenge_rules.max_charges or 0
    if not STATE.challenge_charge_map then
      return string.format('%d/%d', format_int(STATE.challenge_charges or 0), format_int(max_charges))
    end

    local parts = {}
    for _, challenge_id in ipairs({ 'gold_trial', 'wood_trial', 'exp_trial', 'treasure_trial' }) do
      local def = CONFIG.challenges and CONFIG.challenges[challenge_id]
      if def then
        parts[#parts + 1] = string.format(
          '%s %d/%d',
          tostring(def.hotkey or challenge_id),
          format_int(STATE.challenge_charge_map[challenge_id] or 0),
          format_int(max_charges)
        )
      end
    end
    return table.concat(parts, '  ')
  end

  local function show_debug_hotkey_help()
    debug_message('Ctrl+F1：显示调试快捷键说明')
    debug_message('Ctrl+F2：补 500 金币 / 300 木材 / 5 技能点')
    debug_message('Ctrl+F3：英雄直接升 3 级')
    debug_message('Ctrl+F4：解锁全部攻击技能并补 3 技能点')
    debug_message('Ctrl+F5：直接打开 G 三选一（无技能点时自动补 1）')
    debug_message('Ctrl+F6：直接触发 F 抽卡（木材不足时自动补足）')
    debug_message('Ctrl+F7：补满挑战次数')
    debug_message('Ctrl+F8：立刻刷出当前波 Boss')
    debug_message('Ctrl+F9：秒杀场上全部敌人')
    debug_message('Ctrl+F10：显示 / 隐藏 GM 面板')
  end

  local function register_dev_commands()
    if STATE.dev_commands_registered then
      return
    end
    STATE.dev_commands_registered = true

    develop_command.register('EPOS', {
      desc = '打印英雄、防线与主要刷新区域坐标。',
      onCommand = function()
        local hero_point = env.get_hero_point()
        message('英雄当前位置：' .. format_point(hero_point))
        message('英雄出生点：' .. format_point(STATE.hero_spawn_point))
        message('防线点：' .. format_point(STATE.defense_point))
        for _, area_id in ipairs({
          'main_spawn_wave_1',
          'main_spawn_wave_3',
          'main_spawn_wave_5',
          'challenge_spawn_top',
          'challenge_spawn_mid',
          'challenge_spawn_bottom',
        }) do
          local area = get_area(area_id)
          if area then
            message(string.format(
              '%s: x[%d,%d] y[%d,%d]',
              area_id,
              round_number(area.x_min),
              round_number(area.x_max),
              round_number(area.y_min),
              round_number(area.y_max)
            ))
          end
        end
      end,
    })

    develop_command.register('ESET', {
      desc = '把 hero/defense 记录到当前英雄位置。',
      onCommand = function(target)
        local hero_point = env.get_hero_point()
        if not hero_point then
          message('当前没有可用英雄，无法记录坐标。')
          return
        end

        target = (target or ''):lower()
        if target == 'hero' then
          local value = update_point_config('hero_spawn', hero_point)
          message(string.format('已记录 hero_spawn = (%d, %d, %d)', value.x, value.y, value.z))
          return
        end
        if target == 'defense' then
          local value = update_point_config('defense_point', hero_point)
          message(string.format('已记录 defense_point = (%d, %d, %d)', value.x, value.y, value.z))
          return
        end

        show_calibration_help()
      end,
    })

    develop_command.register('EAREA', {
      desc = '以当前英雄位置为中心重设某个刷新区域。',
      onCommand = function(area_id, width, height, offset_x, offset_y)
        local hero_point = env.get_hero_point()
        if not hero_point then
          message('当前没有可用英雄，无法设置区域。')
          return
        end
        if not area_id or area_id == '' then
          show_calibration_help()
          return
        end
        if not get_area(area_id) then
          message('未知区域：' .. tostring(area_id))
          return
        end

        local area = recenter_area(
          area_id,
          hero_point,
          tonumber(width),
          tonumber(height),
          tonumber(offset_x),
          tonumber(offset_y)
        )
        if area then
          message(string.format(
            '已重设 %s: x[%d,%d] y[%d,%d]',
            area_id,
            round_number(area.x_min),
            round_number(area.x_max),
            round_number(area.y_min),
            round_number(area.y_max)
          ))
        end
      end,
    })

    develop_command.register('EBLINK', {
      desc = '把英雄传送到 hero_spawn 或 defense_point。',
      onCommand = function(target)
        if not STATE.hero or not STATE.hero:is_exist() then
          message('当前没有可用英雄，无法传送。')
          return
        end

        target = (target or ''):lower()
        if target == 'hero' then
          STATE.hero:blink(STATE.hero_spawn_point)
          message('英雄已传送到 hero_spawn。')
          return
        end
        if target == 'defense' then
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
      desc = '直接获得指定羁绊卡，如 .ebond armor_break_rend',
      onCommand = function(card_id)
        if not card_id or card_id == '' then
          message('用法：.ebond <card_id>')
          return
        end
        env.debug_grant_bond_card(card_id)
      end,
    })

    develop_command.register('ETREASURE', {
      desc = '直接获得指定宝物，如 .etreasure ITEM_004 [replace_slot]',
      onCommand = function(treasure_id, replace_slot)
        if not treasure_id or treasure_id == '' then
          message('用法：.etreasure <treasure_id> [replace_slot]')
          return
        end
        env.debug_grant_treasure(treasure_id, tonumber(replace_slot))
      end,
    })

    develop_command.register('ETEMP', {
      desc = '打印当前临时宝物列表。',
      onCommand = function()
        env.debug_print_temporary_treasures()
      end,
    })
  end

  local function get_gm_panel_wave_text()
    local wave = env.get_current_wave()
    if not wave then
      return '波次：未开始'
    end

    local wave_name = wave.name or ('第' .. tostring(wave.index) .. '波')
    return string.format('波次：%d  %s', wave.index or 0, wave_name)
  end

  local function get_gm_panel_boss_text()
    if not STATE.active_wave or not STATE.active_wave.wave then
      return 'Boss：等待本波开始'
    end
    if STATE.active_wave.boss_spawned then
      return string.format('Boss：%s 已登场', env.get_boss_name(STATE.active_wave.wave))
    end

    local remain = math.max(0, STATE.active_wave.wave.boss_spawn_sec - STATE.active_wave.elapsed)
    return string.format('Boss：%.1f 秒后登场', remain)
  end

  local function get_gm_panel_status_text()
    local hero_level = env.get_hero_level()
    local gold = STATE.resources and STATE.resources.gold or 0
    local wood = STATE.resources and STATE.resources.wood or 0
    local skill_points = STATE.skill_points or 0
    local enemy_alive = STATE.total_enemy_alive or 0
    local challenge_count = env.get_active_challenge_count()

    return table.concat({
      get_gm_panel_wave_text(),
      get_gm_panel_boss_text(),
      string.format('英雄：Lv.%d    敌人数：%d', hero_level, enemy_alive),
      string.format('金币：%d    木材：%d', gold, wood),
      string.format('技能点：%d    挑战次数：%s', skill_points, build_challenge_charge_text()),
      string.format('进行中挑战：%d', challenge_count),
    }, '\n')
  end

  get_gm_panel_wave_text = function()
    local wave = env.get_current_wave()
    if not wave then
      return '波次：未开始'
    end

    local wave_name = wave.name or ('第' .. tostring(wave.index) .. '波')
    return string.format('波次：%d  %s', wave.index or 0, wave_name)
  end

  get_gm_panel_boss_text = function()
    if not STATE.active_wave or not STATE.active_wave.wave then
      return 'Boss：等待本波开始'
    end
    if STATE.active_wave.boss_spawned then
      return string.format('Boss：%s 已登场', env.get_boss_name(STATE.active_wave.wave))
    end

    local remain = math.max(0, STATE.active_wave.wave.boss_spawn_sec - STATE.active_wave.elapsed)
    return string.format('Boss：%.1f 秒后登场', remain)
  end

  get_gm_panel_status_text = function()
    local hero_level = env.get_hero_level()
    local gold = STATE.resources and STATE.resources.gold or 0
    local wood = STATE.resources and STATE.resources.wood or 0
    local skill_points = STATE.skill_points or 0
    local enemy_alive = STATE.total_enemy_alive or 0
    local challenge_count = env.get_active_challenge_count()

    return table.concat({
      get_gm_panel_wave_text(),
      get_gm_panel_boss_text(),
      string.format('英雄：Lv.%d    敌人数：%d', format_int(hero_level), format_int(enemy_alive)),
      string.format('金币：%d    木材：%d', format_int(gold), format_int(wood)),
      string.format('技能点：%d    挑战次数：%s', format_int(skill_points), build_challenge_charge_text()),
      string.format('进行中挑战：%d', format_int(challenge_count)),
    }, '\n')
  end

  local function build_effect_debug_entry_label(entry)
    local marker = entry and entry.selected and '>' or ' '
    local mounted = entry and entry.mounted and 'ON' or 'OFF'
    local effect_id = entry and entry.id or 'none'
    return string.format('%s%s [%s]', marker, effect_id, mounted)
  end

  local function get_effect_debug_detail_text()
    if not effect_debug_system then
      return '特效调试系统未初始化'
    end
    return table.concat(effect_debug_system.build_selected_detail_lines(), '\n')
  end

  local function get_effect_debug_log_text()
    if not effect_debug_system then
      return '暂无调试日志'
    end
    return table.concat(effect_debug_system.get_recent_logs(8), '\n')
  end

  local function refresh_effect_debug_panel()
    local gm_ui = STATE.gm_ui
    local effect_ui = gm_ui and gm_ui.effect_debug or nil
    if not effect_ui then
      return
    end

    local panel_visible = gm_ui.visible == true and effect_ui.visible == true
    if effect_ui.panel and not effect_ui.panel:is_removed() then
      effect_ui.panel:set_visible(panel_visible)
    end
    if not panel_visible then
      return
    end

    local entries = effect_debug_system and effect_debug_system.get_effect_list_entries() or {}
    for index, button in ipairs(effect_ui.list_buttons or {}) do
      local entry = entries[index]
      if button and not button:is_removed() then
        button:set_visible(entry ~= nil)
        if entry then
          button:set_text(build_effect_debug_entry_label(entry))
        end
      end
    end

    if effect_ui.detail_text and not effect_ui.detail_text:is_removed() then
      effect_ui.detail_text:set_text(get_effect_debug_detail_text())
    end
    if effect_ui.log_text and not effect_ui.log_text:is_removed() then
      effect_ui.log_text:set_text(get_effect_debug_log_text())
    end
  end

  local function close_effect_debug_panel()
    local gm_ui = STATE.gm_ui
    if not gm_ui or not gm_ui.effect_debug then
      return
    end
    gm_ui.effect_debug.visible = false
    refresh_effect_debug_panel()
  end

  local function debug_open_effect_debug_panel()
    local gm_ui = STATE.gm_ui
    if not gm_ui or not gm_ui.effect_debug then
      return
    end
    gm_ui.effect_debug.visible = true
    if env.debug_open_effect_debug_panel then
      env.debug_open_effect_debug_panel()
    end
    refresh_effect_debug_panel()
  end

  local function refresh_gm_panel()
    local gm_ui = STATE.gm_ui
    if not gm_ui then
      return
    end

    if gm_ui.panel and not gm_ui.panel:is_removed() then
      gm_ui.panel:set_visible(gm_ui.visible == true)
    end
    if gm_ui.toggle_button and not gm_ui.toggle_button:is_removed() then
      gm_ui.toggle_button:set_text(gm_ui.visible and '收起GM' or 'GM')
    end
    if gm_ui.status_text and not gm_ui.status_text:is_removed() then
      gm_ui.status_text:set_text(get_gm_panel_status_text())
    end
    refresh_effect_debug_panel()
  end

  local function toggle_gm_panel()
    local gm_ui = STATE.gm_ui
    if not gm_ui then
      return
    end

    gm_ui.visible = not gm_ui.visible
    refresh_gm_panel()
  end

  local function create_gm_panel()
    if not y3.game.is_debug_mode() then
      return nil
    end

    local ok, hud = pcall(y3.ui.get_ui, env.get_player(), 'GameHUD')
    if not ok or not hud then
      return nil
    end

    if STATE.gm_ui and STATE.gm_ui.panel and not STATE.gm_ui.panel:is_removed() then
      refresh_gm_panel()
      return STATE.gm_ui
    end

    local gm_ui = {
      visible = true,
    }

    local toggle_button = hud:create_child('按钮')
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

    local panel = hud:create_child('图片')
    panel:set_image(999)
    panel:set_ui_size(408, 510)
    panel:set_relative_parent_pos('顶部', 62)
    panel:set_relative_parent_pos('右侧', 18)
    panel:set_image_color(9, 15, 23, 220)
    panel:set_z_order(9500)
    panel:set_intercepts_operations(true)
    gm_ui.panel = panel

    local header_bg = panel:create_child('图片')
    header_bg:set_image(999)
    header_bg:set_ui_size(376, 54)
    header_bg:set_pos(204, 477)
    header_bg:set_image_color(22, 38, 58, 230)

    local title = panel:create_child('文本')
    title:set_ui_size(260, 26)
    title:set_pos(146, 484)
    title:set_text('GM 调试面板')
    title:set_font_size(24)
    title:set_text_color(245, 248, 255, 255)
    title:set_text_alignment('左', '中')

    local subtitle = panel:create_child('文本')
    subtitle:set_ui_size(320, 22)
    subtitle:set_pos(178, 455)
    subtitle:set_text('右侧速测工具栏，默认服务单机压测与功能验收')
    subtitle:set_font_size(14)
    subtitle:set_text_color(156, 178, 208, 255)
    subtitle:set_text_alignment('左', '中')

    local status_bg = panel:create_child('图片')
    status_bg:set_image(999)
    status_bg:set_ui_size(376, 120)
    status_bg:set_pos(204, 376)
    status_bg:set_image_color(16, 28, 42, 235)

    local status_text = panel:create_child('文本')
    status_text:set_ui_size(344, 96)
    status_text:set_pos(192, 376)
    status_text:set_font_size(17)
    status_text:set_text_color(233, 239, 248, 255)
    status_text:set_text_alignment('左', '中')
    gm_ui.status_text = status_text

    local function create_gm_action_button(label, left, bottom, width, height, callback, color)
      local r = color and color[1] or 32
      local g = color and color[2] or 71
      local b = color and color[3] or 118

      local bg = panel:create_child('图片')
      bg:set_image(999)
      bg:set_ui_size(width, height)
      bg:set_pos(left + width / 2, bottom + height / 2)
      bg:set_image_color(r, g, b, 235)

      local btn = panel:create_child('按钮')
      btn:set_ui_size(width, height)
      btn:set_pos(left + width / 2, bottom + height / 2)
      btn:set_text(label)
      btn:set_font_size(18)
      btn:set_text_color(245, 248, 255, 255)
      btn:set_z_order(9502)
      btn:add_fast_event('左键-点击', function()
        callback()
        refresh_gm_panel()
      end)
      return btn
    end

    local button_defs = {
      { '帮助 / F1', 24, 260, show_debug_hotkey_help, { 58, 84, 120 } },
      { '加资源 / F2', 204, 260, env.debug_add_test_resources, { 73, 94, 132 } },
      { '升 3 级 / F3', 24, 204, function() env.debug_grant_levels(3) end, { 64, 88, 128 } },
      { '解锁技能 / F4', 204, 204, env.debug_unlock_all_attack_skills, { 84, 97, 138 } },
      { '开强化 / F5', 24, 148, env.debug_open_upgrade_panel, { 72, 102, 142 } },
      { '抽羁绊 / F6', 204, 148, env.debug_trigger_bond_draw, { 84, 110, 150 } },
      { '满挑战 / F7', 24, 92, env.debug_refill_challenge_charges, { 70, 112, 142 } },
      { '刷 Boss / F8', 204, 92, env.debug_force_spawn_boss, { 110, 86, 126 } },
      { '清全场 / F9', 24, 36, env.debug_kill_all_active_enemies, { 128, 74, 88 } },
      { '属性对话框', 204, 36, env.debug_open_attr_overview, { 74, 100, 136 } },
      { '输出属性', 24, 0, env.debug_show_attr_tip_panel, { 70, 104, 134 } },
      { '打印状态', 114, 0, env.show_runtime_status, { 60, 92, 120 } },
    }

    for _, def in ipairs(button_defs) do
      create_gm_action_button(def[1], def[2], def[3], 180, 44, def[4], def[5])
    end

    STATE.gm_ui = gm_ui
    refresh_gm_panel()
    return gm_ui
  end

  local function ensure_gm_panel()
    if not y3.game.is_debug_mode() then
      return nil
    end

    if STATE.gm_ui and STATE.gm_ui.panel and not STATE.gm_ui.panel:is_removed() then
      return STATE.gm_ui
    end

    return create_gm_panel()
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
