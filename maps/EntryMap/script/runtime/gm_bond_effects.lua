local M = {}

local UiRoot = require 'ui.ui_root'
local BondModifierPool = require 'data.object_tables.bond_modifier_pool'
local BondVisualEditorIds = require 'data.object_tables.bond_visual_editor_ids'
local SkillRuntimeTuning = require 'data.object_tables.skill_runtime_tuning'

local BOND_GM_TEXT = SkillRuntimeTuning and SkillRuntimeTuning.bond and SkillRuntimeTuning.bond.gm or {}
local BOND_GM_STATUS_TEMPLATE = tostring(BOND_GM_TEXT.status_template or '羁绊技能：%s')
local BOND_GM_PANEL_INTRO = tostring(BOND_GM_TEXT.panel_intro or '用于立刻获得单卡特殊效果，或立刻激活整套羁绊技能。')
local BOND_GM_ACTIVATE_BUTTON = tostring(BOND_GM_TEXT.activate_button or '激活选中羁绊技能（自动补齐）')
local BOND_GM_ACTIVATION_TAB = tostring(BOND_GM_TEXT.activation_tab or '羁绊技能')
local BOND_GM_MODE_ACTIVATION = tostring(BOND_GM_TEXT.mode_activation or '羁绊技能')
local BOND_GM_CMD_ACTIVATE_DESC = tostring(BOND_GM_TEXT.cmd_activate_desc or '立即激活指定羁绊技能：.egmbondeffect <羁绊名>')
local BOND_GM_CMD_TEST_DESC = tostring(BOND_GM_TEXT.cmd_test_desc or '运行羁绊技能自动化自检：.egmbondtest')
local SAMPLE_BOND_NAME_BY_ID = {
  arrow_rain = '骤雨之幕',
  blizzard = '极寒之域',
  sky_thunder = '天罚雷陨',
  line_lance = '贯日之枪',
  meteor_grid = '陨星矩阵',
  orbit_blade = '旋刃风暴',
  chain_arc = '电弧传导',
  fan_barrage = '扇幕压制',
  burn_field = '炽焰禁区',
  boomerang_blade = '折返刃道',
  mark_execute = '裂隙处决',
  sg_guanyu_qinglong = '关羽·青龙偃月',
  sg_zhangfei_roar = '张飞·怒吼震地',
  sg_zhaoyun_charge = '赵云·七进七出',
  sg_zhuge_stars = '诸葛·七星借风',
  sg_lvbu_cleave = '吕布·无双裂阵',
  sf_line_pierce = '框架·直线穿透',
  sf_area_burst = '框架·落点爆发',
  sf_area_tick = '框架·持续领域',
  sf_chain_bounce = '框架·连锁弹跳',
}

function M.create(env)
  local STATE = env.STATE
  local y3 = env.y3
  local message = env.message or print
  local develop_command = env.develop_command
  local get_player = env.get_player
  local is_battle_active = env.is_battle_active
  local grant_modifier_card_effect = env.grant_modifier_card_effect
  local activate_modifier_bond_effect = env.activate_modifier_bond_effect
  local activate_single_modifier_bond_effect = env.activate_single_modifier_bond_effect
  local clear_active_modifier_bond_effects = env.clear_active_modifier_bond_effects
  local set_force_special_effects_100 = env.set_force_special_effects_100
  local is_force_special_effects_100 = env.is_force_special_effects_100
  local run_bond_self_test = env.run_bond_self_test
  local set_n0_activation_mode = env.set_n0_activation_mode
  local set_n0_single_bond_name = env.set_n0_single_bond_name
  local restart_n0_auto_acceptance = env.restart_n0_auto_acceptance
  local list_sample_skills = env.list_sample_skills
  local cast_sample_skill = env.cast_sample_skill
  local cast_next_sample_skill = env.cast_next_sample_skill
  local get_sample_skill_defs = env.get_sample_skill_defs
  local debug_set_global_projectile_override = env.debug_set_global_projectile_override
  local debug_clear_global_projectile_override = env.debug_clear_global_projectile_override
  local debug_toggle_global_projectile_override = env.debug_toggle_global_projectile_override
  local debug_get_global_projectile_override = env.debug_get_global_projectile_override
  local DEFAULT_DEBUG_PROJECTILE_KEY = 134255250

  local function trim(text)
    return tostring(text or ''):gsub('^%s+', ''):gsub('%s+$', '')
  end

  local function resolve_sample_bond_name(sample_id, sample_name, sample_desc)
    local id = trim(sample_id)
    local mapped = SAMPLE_BOND_NAME_BY_ID[id]
    if mapped and mapped ~= '' then
      return mapped
    end

    local name = trim(sample_name)
    if name ~= '' then
      return string.format('羁绊·%s', name)
    end

    local desc = trim(sample_desc)
    if desc ~= '' then
      local summary = desc:match('^(.-)[，。,；;]') or desc
      summary = trim(summary)
      if summary ~= '' then
        return string.format('羁绊·%s', summary)
      end
    end

    return string.format('羁绊·%s', id ~= '' and id or '未知样例')
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

  local function set_intercepts(ui, value)
    if is_alive(ui) and ui.set_intercepts_operations then
      ui:set_intercepts_operations(value == true)
    end
  end

  local function debug_message(text)
    message('[DEBUG] ' .. tostring(text))
  end

  local function normalize_n0_mode(raw_mode)
    local mode = string.lower(trim(raw_mode))
    if mode == 'single' or mode == 'one' then
      return 'single'
    end
    if mode == 'none' or mode == 'off' then
      return 'none'
    end
    return 'all'
  end

  local function get_n0_mode_and_single_bond()
    local n0_runtime = STATE and STATE.battle_auto_acceptance or nil
    local stage_def = STATE and STATE.current_stage_def or nil
    local mode = normalize_n0_mode(
      (n0_runtime and n0_runtime.activation_mode_override)
      or (stage_def and stage_def.n0_activation_mode)
      or 'all'
    )
    local single_bond_name = trim(
      (n0_runtime and n0_runtime.single_bond_name_override)
      or (stage_def and stage_def.n0_single_bond)
    )
    return mode, single_bond_name
  end

  local function apply_n0_mode(mode, bond_name)
    if not set_n0_activation_mode then
      debug_message('未注入 N0 模式控制回调。')
      return false
    end
    local resolved_mode = normalize_n0_mode(mode)
    local resolved_bond_name = trim(bond_name)

    if resolved_mode == 'single' then
      if resolved_bond_name == '' then
        debug_message('单羁绊模式需要指定羁绊名。')
        return false
      end
      if not set_n0_single_bond_name then
        debug_message('未注入 N0 单羁绊回调。')
        return false
      end
    end

    set_n0_activation_mode(resolved_mode)
    if set_n0_single_bond_name then
      if resolved_mode == 'single' then
        set_n0_single_bond_name(resolved_bond_name)
      else
        set_n0_single_bond_name('')
      end
    end

    if resolved_mode == 'single' and activate_single_modifier_bond_effect then
      activate_single_modifier_bond_effect(resolved_bond_name, true)
    elseif resolved_mode == 'none' and clear_active_modifier_bond_effects then
      clear_active_modifier_bond_effects()
    end

    local restarted = false
    if restart_n0_auto_acceptance then
      restarted = restart_n0_auto_acceptance() == true
    end
    local mode_label_map = {
      all = '全开',
      single = '单羁绊',
      none = '灵/零羁绊',
    }
    local mode_label = mode_label_map[resolved_mode] or resolved_mode
    debug_message(string.format(
      'N0 模式已切换：%s%s%s',
      mode_label,
      resolved_mode == 'single' and string.format('（%s）', resolved_bond_name) or '',
      restarted and '（当前战斗已立即生效）' or '（下一次 N0 战斗生效）'
    ))
    return true
  end

  local function get_runtime()
    return STATE and STATE.bond_runtime or nil
  end

  local function get_cards_by_bond(bond_name)
    return BondModifierPool.cards_by_bond and BondModifierPool.cards_by_bond[bond_name] or {}
  end

  local function count_owned_cards(runtime, bond_name)
    local count = 0
    for _, card in ipairs(get_cards_by_bond(bond_name)) do
      if runtime and runtime.modifier_card_ids and runtime.modifier_card_ids[card.id] == true then
        count = count + 1
      end
    end
    return count
  end

  local function get_required_cards(bond_name)
    local cards = get_cards_by_bond(bond_name)
    return math.max(1, tonumber(cards[1] and cards[1].required_count) or #cards)
  end

  local function get_owned_cards_count(runtime, bond_name)
    local count = 0
    for _, card in ipairs(get_cards_by_bond(bond_name)) do
      if runtime and runtime.modifier_card_ids and runtime.modifier_card_ids[card.id] == true then
        count = count + 1
      end
    end
    return count
  end

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

  local refresh_board
  local refresh_encyclopedia

  local function create_button(parent, text, x, y, width, height, callback, color)
    create_rect(parent, x, y, width, height, color or { 42, 72, 108, 230 })
    local button = parent:create_child('按钮')
    button:set_ui_size(width, height)
    button:set_pos(x + width / 2, y + height / 2)
    button:set_text(text)
    button:set_font_size(14)
    -- 强制高对比：按钮本体改深色底，文字改浅色，避免白底白字看不清。
    if button.set_image then
      button:set_image(999)
    end
    if button.set_image_color then
      button:set_image_color(18, 34, 52, 210)
    end
    button:set_text_color(235, 244, 255, 255)
    button:add_fast_event('左键-点击', function()
      if callback then
        callback()
      end
      if refresh_board then
        refresh_board()
      end
    end)
    return button
  end

  local function get_selected_bond(ui)
    local bonds = ui and ui.single_bond_entries or {}
    if #bonds <= 0 then
      return nil, 1
    end
    local index = math.max(1, math.min(#bonds, ui.selected_bond_index or 1))
    ui.selected_bond_index = index
    return bonds[index], index
  end

  local function get_selected_card(ui, bond_name)
    local cards = get_cards_by_bond(bond_name)
    if #cards == 0 then
      return nil, 1
    end
    local selected = ui.selected_card_index_by_bond[bond_name] or 1
    local index = math.max(1, math.min(#cards, selected))
    ui.selected_card_index_by_bond[bond_name] = index
    return cards[index], index
  end

  local function execute_grant_card(card_ref)
    local ok, result = grant_modifier_card_effect(card_ref)
    debug_message(result or '')
    return ok == true
  end

  local function execute_activate_bond(bond_name, grant_missing_cards)
    local ok, result = activate_modifier_bond_effect(bond_name, grant_missing_cards == true)
    debug_message(result or '')
    return ok == true
  end

  local function execute_cast_sample(sample_id)
    if not cast_sample_skill then
      debug_message('未注入 sample 技能施放回调。')
      return false
    end
    local ok, result = cast_sample_skill(sample_id)
    debug_message(result or '')
    return ok == true
  end

  local function execute_cast_next_sample()
    if not cast_next_sample_skill then
      debug_message('未注入 sample 技能轮播施放回调。')
      return false
    end
    local ok, result = cast_next_sample_skill()
    debug_message(result or '')
    return ok == true
  end

  local function normalize_effect_text(text)
    local value = tostring(text or '')
    value = value:gsub('\r', '')
    value = value:gsub('^%s+', ''):gsub('%s+$', '')
    return value
  end

  local function summarize_effect_text(text)
    local value = normalize_effect_text(text):gsub('\n+', ' ')
    local short = value:match('^(.-)[。；;,，]') or value
    if #short > 80 then
      short = string.sub(short, 1, 80) .. '...'
    end
    return short
  end

  local function build_activation_entries()
    local result = {}
    for _, effect in ipairs(BondModifierPool.activation_effects or {}) do
      local bond_name = tostring(effect and effect.bond_name or '')
      local effect_text = normalize_effect_text(effect and effect.desc or '')
      if bond_name ~= '' and effect_text ~= '' then
        result[#result + 1] = {
          kind = 'activation',
          bond_name = bond_name,
          title = bond_name,
          desc = effect_text,
        }
      end
    end

    local sample_defs = get_sample_skill_defs and get_sample_skill_defs() or nil
    if type(sample_defs) == 'table' then
      for _, def in ipairs(sample_defs) do
        local sample_id = trim(def and def.id or '')
        if sample_id ~= '' then
          local sample_name = trim(def and def.name or sample_id)
          local sample_desc = normalize_effect_text(def and def.desc or '')
          local bond_name = resolve_sample_bond_name(sample_id, sample_name, sample_desc)
          result[#result + 1] = {
            kind = 'sample_bond',
            sample_id = sample_id,
            title = bond_name,
            desc = sample_desc ~= '' and sample_desc or '无描述。',
          }
        end
      end
    end
    return result
  end

  local function build_special_entries()
    local result = {}
    for _, card in ipairs(BondModifierPool.cards or {}) do
      local special_text = normalize_effect_text(card and card.extra_skill_desc or '')
      if special_text ~= '' and special_text ~= '无' then
        result[#result + 1] = {
          kind = 'special',
          card_id = card.id,
          card_name = tostring(card.name or card.id),
          bond_name = tostring(card.bond_name or ''),
          title = tostring(card.name or card.id),
          desc = special_text,
        }
      end
    end
    return result
  end

  local function build_sample_entries()
    local result = {}
    local defs = get_sample_skill_defs and get_sample_skill_defs() or nil
    if type(defs) == 'table' then
      for index, def in ipairs(defs) do
        local sample_id = trim(def and def.id or '')
        if sample_id ~= '' then
          local sample_name = trim(def and def.name or sample_id)
          local sample_desc = normalize_effect_text(def and def.desc or '')
          local bond_name = resolve_sample_bond_name(sample_id, sample_name, sample_desc)
          result[#result + 1] = {
            kind = 'sample',
            order = index,
            sample_id = sample_id,
            title = bond_name,
            desc = sample_desc ~= '' and sample_desc or '无描述。',
          }
        end
      end
    end
    if #result > 0 then
      return result
    end

    local lines = list_sample_skills and list_sample_skills() or nil
    if type(lines) ~= 'table' then
      return result
    end

    for index, line in ipairs(lines) do
      local raw = tostring(line or '')
      local sample_id = trim(raw:match('^%d+%)%s*([^|]+)') or '')
      if sample_id ~= '' then
        local sample_name = trim(raw:match('^%d+%)%s*[^|]+|%s*([^|]+)') or sample_id)
        local sample_desc = normalize_effect_text(raw:match('^%d+%)%s*[^|]+|%s*[^|]+|%s*(.+)$') or '')
        local bond_name = resolve_sample_bond_name(sample_id, sample_name, sample_desc)
        result[#result + 1] = {
          kind = 'sample',
          order = index,
          sample_id = sample_id,
          title = bond_name,
          desc = sample_desc ~= '' and sample_desc or '无描述。',
        }
      end
    end
    return result
  end

  local function get_activation_desc_by_bond(bond_name)
    bond_name = tostring(bond_name or '')
    if bond_name == '' then
      return ''
    end
    for _, effect in ipairs(BondModifierPool.activation_effects or {}) do
      if tostring(effect and effect.bond_name or '') == bond_name then
        local desc = normalize_effect_text(effect and effect.desc or '')
        if desc ~= '' then
          return desc
        end
        break
      end
    end
    -- 兜底：部分数据可能只在卡池 activation_desc 里维护
    for _, card in ipairs(get_cards_by_bond(bond_name)) do
      local desc = normalize_effect_text(card and card.activation_desc or '')
      if desc ~= '' then
        return desc
      end
    end
    return ''
  end

  local function build_status_text(ui)
    local runtime = get_runtime()
    local selected_bond = get_selected_bond(ui)
    if selected_bond and selected_bond.kind == 'sample_bond' then
      local lines = {
        string.format('羁绊：%s', tostring(selected_bond.title or 'Sample羁绊')),
        string.format(BOND_GM_STATUS_TEMPLATE, '可直接施放'),
        string.format('SampleID：%s', tostring(selected_bond.sample_id or '')),
        string.format('特殊效果100%%触发：%s', is_force_special_effects_100 and is_force_special_effects_100() and '开启' or '关闭'),
        string.format('投射物覆盖：%s', tostring((debug_get_global_projectile_override and debug_get_global_projectile_override()) or '关闭')),
        '单卡：无（Sample羁绊不使用单卡）',
      }
      if selected_bond.desc and selected_bond.desc ~= '' then
        lines[#lines + 1] = '羁绊说明：'
        for row in tostring(selected_bond.desc):gmatch('[^\n]+') do
          lines[#lines + 1] = row
        end
      end
      return table.concat(lines, '\n')
    end
    local bond_name = selected_bond and selected_bond.bond_name or ''
    local cards = get_cards_by_bond(bond_name)
    local owned = count_owned_cards(runtime, bond_name)
    local need = get_required_cards(bond_name)
    local effect_id = 'initial_bond_set_' .. tostring(bond_name)
    local active = runtime and runtime.modifier_pool_active_effects and runtime.modifier_pool_active_effects[effect_id] == true
    local selected_card = get_selected_card(ui, bond_name)

    local special_active = false
    local special_text = ''
    if selected_card then
      special_active = runtime and runtime.modifier_card_effect_ids and runtime.modifier_card_effect_ids[selected_card.id] == true or false
      special_text = tostring(selected_card.extra_skill_desc or '')
    end

    local lines = {
      string.format('羁绊：%s', bond_name ~= '' and bond_name or '未选择'),
      string.format('进度：%d/%d', owned, need),
      string.format(BOND_GM_STATUS_TEMPLATE, active and '已激活' or '未激活'),
      string.format('特殊效果100%%触发：%s', is_force_special_effects_100 and is_force_special_effects_100() and '开启' or '关闭'),
      string.format('投射物覆盖：%s', tostring((debug_get_global_projectile_override and debug_get_global_projectile_override()) or '关闭')),
      selected_card and string.format('单卡：%s', tostring(selected_card.name or selected_card.id)) or '单卡：未选择',
      selected_card and string.format('特殊效果：%s', special_active and '已获得' or '未获得') or '特殊效果：未获得',
    }
    local n0_mode, n0_single = get_n0_mode_and_single_bond()
    lines[#lines + 1] = string.format(
      'N0模式：%s%s',
      n0_mode,
      n0_single ~= '' and string.format('（单特效=%s）', n0_single) or ''
    )
    local activation_desc = get_activation_desc_by_bond(bond_name)
    if activation_desc ~= '' then
      lines[#lines + 1] = '羁绊激活描述：'
      for row in tostring(activation_desc):gmatch('[^\n]+') do
        lines[#lines + 1] = row
      end
    end
    if special_text ~= '' and special_text ~= '无' then
      lines[#lines + 1] = string.format('单卡说明：%s', special_text)
    end
    return table.concat(lines, '\n')
  end

  local function format_bond_button_text(ui, effect)
    if effect and effect.kind == 'sample_bond' then
      local selected = effect == select(1, get_selected_bond(ui))
      local prefix = selected and '>' or ' '
      return string.format('%s%s [Sample]', prefix, tostring(effect.title or effect.sample_id or 'Sample羁绊'))
    end
    local runtime = get_runtime()
    local owned = count_owned_cards(runtime, effect.bond_name)
    local need = get_required_cards(effect.bond_name)
    local effect_id = 'initial_bond_set_' .. tostring(effect.bond_name)
    local active = runtime and runtime.modifier_pool_active_effects and runtime.modifier_pool_active_effects[effect_id] == true
    local mode, single_bond_name = get_n0_mode_and_single_bond()
    local is_single_target = mode == 'single' and tostring(effect.bond_name or '') == tostring(single_bond_name or '')
    local selected = effect == select(1, get_selected_bond(ui))
    local prefix = is_single_target and '*' or (selected and '>' or ' ')
    local suffix = is_single_target and 'N0单羁绊' or (active and '已激活' or string.format('%d/%d', owned, need))
    return string.format('%s%s [%s]', prefix, tostring(effect.bond_name or '未命名'), suffix)
  end

  local function format_card_button_text(ui, card, bond_name)
    local runtime = get_runtime()
    local selected_card = select(1, get_selected_card(ui, bond_name))
    local selected = selected_card == card
    local prefix = selected and '>' or ' '
    local has_card = runtime and runtime.modifier_card_ids and runtime.modifier_card_ids[card.id] == true
    local has_special = runtime and runtime.modifier_card_effect_ids and runtime.modifier_card_effect_ids[card.id] == true
    return string.format(
      '%s%s [%s/%s]',
      prefix,
      tostring(card.name or card.id),
      has_card and '已拿' or '未拿',
      has_special and '特效' or '无特效'
    )
  end

  local function build_board(parent)
    local ui = {
      visible = false,
      selected_bond_index = 1,
      selected_card_index_by_bond = {},
      bond_buttons = {},
      card_buttons = {},
      encyclopedia_visible = false,
      encyclopedia_mode = 'special',
      encyclopedia_page = 1,
      encyclopedia_rows = {},
      encyclopedia_activation_entries = build_activation_entries(),
      encyclopedia_special_entries = build_special_entries(),
      encyclopedia_sample_entries = build_sample_entries(),
      single_bond_entries = build_activation_entries(),
    }
    STATE.gm_bond_ui = ui

    local toggle_button = parent:create_child('按钮')
    toggle_button:set_ui_size(120, 34)
    toggle_button:set_relative_parent_pos('顶部', 18)
    toggle_button:set_relative_parent_pos('右侧', 170)
    toggle_button:set_text('羁绊GM')
    toggle_button:set_font_size(15)
    if toggle_button.set_image then
      toggle_button:set_image(999)
    end
    if toggle_button.set_image_color then
      toggle_button:set_image_color(30, 56, 86, 228)
    end
    toggle_button:set_text_color(250, 232, 172, 255)
    toggle_button:set_z_order(9601)
    toggle_button:add_fast_event('左键-点击', function()
      ui.visible = not ui.visible
      refresh_board()
    end)
    ui.toggle_button = toggle_button

    local panel = parent:create_child('图片')
    panel:set_image(999)
    panel:set_ui_size(980, 560)
    panel:set_relative_parent_pos('顶部', 62)
    panel:set_relative_parent_pos('右侧', 18)
    panel:set_image_color(8, 14, 22, 228)
    panel:set_z_order(9600)
    panel:set_intercepts_operations(true)
    ui.panel = panel

    create_rect(panel, 16, 504, 948, 42, { 20, 38, 58, 230 })
    create_text(panel, '羁绊 / 特殊效果 GM', 30, 512, 250, 28, 23, { 245, 248, 255, 255 })
    create_text(panel, BOND_GM_PANEL_INTRO, 300, 514, 640, 22, 14, { 160, 186, 214, 255 })
    create_button(panel, 'Samples大全', 816, 508, 134, 30, function()
      ui.encyclopedia_mode = 'sample'
      ui.encyclopedia_visible = true
      ui.encyclopedia_page = 1
      ui.encyclopedia_sample_entries = build_sample_entries()
    end, { 56, 86, 126, 235 })

    create_rect(panel, 16, 282, 450, 212, { 14, 27, 42, 235 })
    create_text(panel, '单羁绊按钮（全量直达）', 28, 468, 300, 22, 17, { 245, 248, 255, 255 })
    for i = 1, 44 do
      local row = math.floor((i - 1) / 4)
      local col = (i - 1) % 4
      ui.bond_buttons[i] = create_button(
        panel,
        '',
        24 + col * 106,
        444 - row * 18,
        100,
        16,
        function()
          ui.selected_bond_index = i
          local bonds = ui.single_bond_entries or {}
          local effect = bonds[i]
          if effect and effect.kind == 'sample_bond' then
            execute_cast_sample(effect.sample_id)
            return
          end
          local bond_name = trim(effect and effect.bond_name or '')
          if bond_name ~= '' then
            apply_n0_mode('single', bond_name)
          end
        end,
        { 28, 56, 86, 230 }
      )
    end

    create_rect(panel, 482, 282, 482, 212, { 14, 27, 42, 235 })
    create_text(panel, '单卡列表（选中羁绊）', 496, 468, 230, 22, 17, { 245, 248, 255, 255 })
    for i = 1, 12 do
      local row = math.floor((i - 1) / 2)
      local col = (i - 1) % 2
      ui.card_buttons[i] = create_button(
        panel,
        '',
        492 + col * 236,
        434 - row * 30,
        226,
        26,
        function()
          local bond = select(1, get_selected_bond(ui))
          if not bond or bond.kind == 'sample_bond' then
            return
          end
          ui.selected_card_index_by_bond[bond.bond_name] = i
        end,
        { 32, 60, 90, 230 }
      )
    end

    create_rect(panel, 16, 16, 640, 250, { 14, 27, 42, 235 })
    ui.status_text = create_text(panel, '', 28, 30, 616, 226, 14, { 233, 239, 248, 255 })

    create_button(panel, '获得选中单卡特殊效果', 672, 206, 278, 40, function()
      local bond = select(1, get_selected_bond(ui))
      if bond and bond.kind == 'sample_bond' then
        debug_message('当前是 Sample羁绊，请使用“激活选中羁绊技能”直接施放。')
        return
      end
      local card = bond and select(1, get_selected_card(ui, bond.bond_name)) or nil
      if not card then
        debug_message('当前羁绊无可用单卡。')
        return
      end
      execute_grant_card(card.id)
    end, { 58, 102, 140, 235 })

    create_button(panel, BOND_GM_ACTIVATE_BUTTON, 672, 154, 278, 40, function()
      local bond = select(1, get_selected_bond(ui))
      if not bond then
        debug_message('请先选择羁绊。')
        return
      end
      if bond.kind == 'sample_bond' then
        execute_cast_sample(bond.sample_id)
        return
      end
      execute_activate_bond(bond.bond_name, true)
    end, { 82, 118, 86, 235 })

    create_button(panel, '仅尝试激活（不补齐）', 672, 102, 278, 40, function()
      local bond = select(1, get_selected_bond(ui))
      if not bond then
        debug_message('请先选择羁绊。')
        return
      end
      if bond.kind == 'sample_bond' then
        execute_cast_sample(bond.sample_id)
        return
      end
      execute_activate_bond(bond.bond_name, false)
    end, { 100, 82, 126, 235 })

    ui.n0_all_button = create_button(panel, 'N0全开（立即生效）', 672, 50, 278, 40, function()
      apply_n0_mode('all')
    end, { 64, 96, 132, 235 })

    ui.force_effect_button = create_button(panel, '', 672, 258, 278, 40, function()
      if not set_force_special_effects_100 then
        debug_message('未注入特殊效果100%开关回调。')
        return
      end
      local current = is_force_special_effects_100 and is_force_special_effects_100() or false
      set_force_special_effects_100(not current)
      debug_message(string.format('特殊效果100%%触发：%s', not current and '开启' or '关闭'))
    end, { 88, 108, 62, 235 })

    ui.projectile_override_button = create_button(panel, '', 672, 310, 278, 40, function()
      if debug_toggle_global_projectile_override then
        debug_toggle_global_projectile_override(DEFAULT_DEBUG_PROJECTILE_KEY)
      else
        debug_message('未注入投射物覆盖回调。')
      end
    end, { 96, 106, 132, 235 })

    ui.n0_none_button = create_button(panel, 'N0灵/零羁绊（立即生效）', 16, 4, 640, 40, function()
      apply_n0_mode('none')
    end, { 70, 92, 116, 235 })

    create_button(panel, '关闭', 672, 4, 278, 40, function()
      ui.visible = false
    end, { 96, 76, 88, 235 })

    local encyclopedia_mask = parent:create_child('图片')
    encyclopedia_mask:set_image(999)
    encyclopedia_mask:set_ui_size(2000, 1200)
    encyclopedia_mask:set_pos(960, 540)
    encyclopedia_mask:set_image_color(0, 0, 0, 150)
    encyclopedia_mask:set_z_order(9614)
    encyclopedia_mask:set_intercepts_operations(true)
    ui.encyclopedia_mask = encyclopedia_mask

    local encyclopedia_panel = parent:create_child('图片')
    encyclopedia_panel:set_image(999)
    encyclopedia_panel:set_ui_size(980, 640)
    encyclopedia_panel:set_pos(960, 540)
    encyclopedia_panel:set_image_color(6, 10, 18, 236)
    encyclopedia_panel:set_z_order(9615)
    encyclopedia_panel:set_intercepts_operations(true)
    ui.encyclopedia_panel = encyclopedia_panel

    create_rect(encyclopedia_panel, 16, 586, 948, 36, { 20, 38, 58, 235 })
    create_text(encyclopedia_panel, '羁绊特殊效果大全', 28, 590, 320, 28, 19, { 245, 248, 255, 255 })
    ui.encyclopedia_info_text = create_text(encyclopedia_panel, '', 360, 590, 592, 28, 13, { 170, 198, 228, 255 })

    create_button(encyclopedia_panel, BOND_GM_ACTIVATION_TAB, 20, 544, 140, 34, function()
      ui.encyclopedia_mode = 'activation'
      ui.encyclopedia_page = 1
    end, { 52, 90, 132, 235 })
    create_button(encyclopedia_panel, '单卡特殊效果', 170, 544, 180, 34, function()
      ui.encyclopedia_mode = 'special'
      ui.encyclopedia_page = 1
    end, { 52, 90, 132, 235 })
    create_button(encyclopedia_panel, 'Sample技能', 360, 544, 130, 34, function()
      ui.encyclopedia_mode = 'sample'
      ui.encyclopedia_page = 1
      ui.encyclopedia_sample_entries = build_sample_entries()
    end, { 52, 90, 132, 235 })
    create_button(encyclopedia_panel, '刷新Samples', 500, 544, 120, 34, function()
      ui.encyclopedia_sample_entries = build_sample_entries()
      debug_message(string.format('Sample 技能条目：%d', #ui.encyclopedia_sample_entries))
    end, { 72, 86, 120, 235 })
    create_button(encyclopedia_panel, '施放下一个', 628, 544, 108, 34, function()
      execute_cast_next_sample()
    end, { 72, 86, 120, 235 })
    create_button(encyclopedia_panel, '上一页', 744, 544, 96, 34, function()
      ui.encyclopedia_page = math.max(1, (ui.encyclopedia_page or 1) - 1)
    end, { 72, 86, 120, 235 })
    create_button(encyclopedia_panel, '下一页', 848, 544, 96, 34, function()
      ui.encyclopedia_page = math.max(1, (ui.encyclopedia_page or 1) + 1)
    end, { 72, 86, 120, 235 })
    create_button(encyclopedia_panel, '关闭大全', 848, 586, 96, 34, function()
      ui.encyclopedia_visible = false
    end, { 102, 72, 92, 235 })

    for i = 1, 10 do
      local y = 498 - (i - 1) * 42
      local row_bg = create_rect(encyclopedia_panel, 20, y, 940, 36, { 18, 30, 46, 220 })
      local title_text = create_text(encyclopedia_panel, '', 30, y + 13, 252, 18, 13, { 246, 234, 176, 255 })
      local desc_text = create_text(encyclopedia_panel, '', 286, y + 13, 528, 18, 12, { 222, 236, 248, 255 })
      create_rect(encyclopedia_panel, 824, y + 2, 128, 30, { 66, 118, 88, 235 })
      local action_btn = encyclopedia_panel:create_child('按钮')
      action_btn:set_ui_size(128, 30)
      action_btn:set_pos(888, y + 17)
      action_btn:set_text('立即获得')
      action_btn:set_font_size(13)
      if action_btn.set_image then
        action_btn:set_image(999)
      end
      if action_btn.set_image_color then
        action_btn:set_image_color(20, 40, 56, 210)
      end
      action_btn:set_text_color(236, 246, 255, 255)
      ui.encyclopedia_rows[i] = {
        bg = row_bg,
        title = title_text,
        desc = desc_text,
        action = action_btn,
      }
      action_btn:add_fast_event('左键-点击', function()
        local row = ui.encyclopedia_rows[i]
        if not row or not row.entry then
          return
        end
        if row.mode == 'activation' then
          if row.entry.kind == 'sample_bond' then
            execute_cast_sample(row.entry.sample_id)
          else
            execute_activate_bond(row.entry.bond_name, true)
          end
        elseif row.mode == 'sample' then
          execute_cast_sample(row.entry.sample_id)
        else
          execute_grant_card(row.entry.card_id)
        end
        if refresh_board then
          refresh_board()
        end
      end)
    end

    create_rect(encyclopedia_panel, 20, 20, 940, 96, { 16, 28, 44, 228 })
    create_text(encyclopedia_panel, '当前条目说明：', 30, 92, 180, 18, 14, { 176, 206, 236, 255 })
    ui.encyclopedia_detail_text = create_text(encyclopedia_panel, '', 30, 36, 920, 58, 13, { 236, 242, 250, 255 })
    if is_alive(ui.encyclopedia_detail_text) and ui.encyclopedia_detail_text.set_text_alignment then
      ui.encyclopedia_detail_text:set_text_alignment('左', '上')
    end

    return ui
  end

  local function bind_top_shortcut_button(ui)
    if not ui then
      return
    end
    local player = get_player and get_player() or nil
    if not player then
      return
    end
    ui.top_shortcut_bound_paths = ui.top_shortcut_bound_paths or {}
    local bound_any = false
    local paths = {
      'top.top.left_buttons.btn_hotkey',
      'top.top.left_buttons.btn_setting',
      'top.top.left_buttons.btn_save',
    }
    for _, path in ipairs(paths) do
      if ui.top_shortcut_bound_paths[path] ~= true then
        local button = UiRoot.resolve_ui(y3, player, path)
        if is_alive(button) and button.add_fast_event then
          button:add_fast_event('左键-点击', function()
            ui.visible = not ui.visible
            if refresh_board then
              refresh_board()
            end
          end)
          ui.top_shortcut_bound_paths[path] = true
          bound_any = true
        end
      else
        bound_any = true
      end
    end
    ui.top_shortcut_bound = bound_any
  end

  local function resolve_runtime_parent(player)
    if not player then
      return nil
    end
    local parent = UiRoot.resolve_first_ui(y3, player, {
      'top',
      'BattleBottomHUD',
      'GameHUD',
    })
    if is_alive(parent) then
      return parent
    end
    return UiRoot.get_overlay_parent(y3, player)
  end

  local function ensure_board()
    local player = get_player and get_player() or nil
    local parent = resolve_runtime_parent(player)
    if not parent then
      return nil
    end
    local ui = STATE.gm_bond_ui
    if ui and is_alive(ui.panel) then
      bind_top_shortcut_button(ui)
      return ui
    end
    ui = build_board(parent)
    bind_top_shortcut_button(ui)
    return ui
  end

  refresh_board = function()
    local ui = STATE.gm_bond_ui
    if not ui then
      return
    end

    local in_battle = true
    if is_battle_active then
      in_battle = is_battle_active() == true
    end
    set_visible(ui.toggle_button, true)
    local show_main = ui.visible == true and ui.encyclopedia_visible ~= true
    set_visible(ui.panel, show_main)
    set_intercepts(ui.panel, show_main)

    ui.single_bond_entries = build_activation_entries()
    local bonds = ui.single_bond_entries or {}
    local selected_bond = select(1, get_selected_bond(ui))
    for i, button in ipairs(ui.bond_buttons) do
      local effect = bonds[i]
      set_visible(button, effect ~= nil)
      if effect then
        set_text(button, format_bond_button_text(ui, effect))
      end
    end

    local cards = get_cards_by_bond(selected_bond and selected_bond.bond_name or '')
    for i, button in ipairs(ui.card_buttons) do
      local card = cards[i]
      set_visible(button, card ~= nil)
      if card then
        set_text(button, format_card_button_text(ui, card, selected_bond.bond_name))
      end
    end

    set_text(ui.status_text, build_status_text(ui))
    if is_alive(ui.force_effect_button) then
      local on = is_force_special_effects_100 and is_force_special_effects_100() or false
      set_text(ui.force_effect_button, on and '关闭特殊效果100%触发' or '开启特殊效果100%触发')
    end
    if is_alive(ui.projectile_override_button) then
      local projectile_key = debug_get_global_projectile_override and debug_get_global_projectile_override() or nil
      if projectile_key then
        set_text(ui.projectile_override_button, string.format('关闭投射物覆盖（当前:%s）', tostring(projectile_key)))
      else
        set_text(ui.projectile_override_button, string.format('开启投射物覆盖（ID:%d）', DEFAULT_DEBUG_PROJECTILE_KEY))
      end
    end
    if is_alive(ui.n0_all_button) then
      local mode, single_bond_name = get_n0_mode_and_single_bond()
      set_text(ui.n0_all_button, mode == 'all' and 'N0全开（当前）' or 'N0全开（立即生效）')
      if is_alive(ui.n0_none_button) then
        local label = mode == 'none' and 'N0灵/零羁绊（当前）' or 'N0灵/零羁绊（立即生效）'
        if mode == 'single' then
          label = string.format('N0灵/零羁绊（当前单羁绊:%s）', trim(single_bond_name) ~= '' and single_bond_name or '未指定')
        end
        set_text(ui.n0_none_button, label)
      end
    end
    if refresh_encyclopedia then
      refresh_encyclopedia()
    end
  end

  refresh_encyclopedia = function()
    local ui = STATE.gm_bond_ui
    if not ui or not is_alive(ui.encyclopedia_panel) then
      return
    end

    local show = ui.visible == true and ui.encyclopedia_visible == true
    set_visible(ui.encyclopedia_mask, show)
    set_intercepts(ui.encyclopedia_mask, show)
    set_visible(ui.encyclopedia_panel, show)
    set_intercepts(ui.encyclopedia_panel, show)
    if not show then
      return
    end

    local runtime = get_runtime()
    local entries = {}
    if ui.encyclopedia_mode == 'activation' then
      entries = ui.encyclopedia_activation_entries or {}
    elseif ui.encyclopedia_mode == 'sample' then
      ui.encyclopedia_sample_entries = build_sample_entries()
      entries = ui.encyclopedia_sample_entries or {}
    else
      entries = ui.encyclopedia_special_entries or {}
    end
    local page_size = #ui.encyclopedia_rows
    local total_pages = math.max(1, math.ceil(#entries / math.max(1, page_size)))
    ui.encyclopedia_page = math.max(1, math.min(total_pages, ui.encyclopedia_page or 1))
    local start_index = (ui.encyclopedia_page - 1) * page_size
    local mode_text = BOND_GM_MODE_ACTIVATION
    if ui.encyclopedia_mode == 'sample' then
      mode_text = 'Sample技能'
    elseif ui.encyclopedia_mode ~= 'activation' then
      mode_text = '单卡特殊效果'
    end
    set_text(ui.encyclopedia_info_text, string.format('%s | 第 %d/%d 页 | 共 %d 条', mode_text, ui.encyclopedia_page, total_pages, #entries))
    local detail_entry = nil

    for row_index, row_ui in ipairs(ui.encyclopedia_rows) do
      local entry = entries[start_index + row_index]
      local row_visible = entry ~= nil
      set_visible(row_ui.bg, row_visible)
      set_visible(row_ui.title, row_visible)
      set_visible(row_ui.desc, row_visible)
      set_visible(row_ui.action, row_visible)
      if row_visible then
        row_ui.entry = entry
        row_ui.mode = ui.encyclopedia_mode
        if ui.encyclopedia_mode == 'activation' then
          if entry.kind == 'sample_bond' then
            set_text(row_ui.title, string.format('%s [%s]', tostring(entry.title or ''), tostring(entry.sample_id or '')))
            set_text(row_ui.action, '立即施放')
          else
            local effect_id = 'initial_bond_set_' .. tostring(entry.bond_name or '')
            local active = runtime and runtime.modifier_pool_active_effects and runtime.modifier_pool_active_effects[effect_id] == true
            set_text(row_ui.title, string.format('%s [%s]', tostring(entry.title or ''), active and '已激活' or '未激活'))
            set_text(row_ui.action, active and '已激活' or '一键激活')
          end
        elseif ui.encyclopedia_mode == 'sample' then
          set_text(row_ui.title, string.format('%s [%s]', tostring(entry.title or ''), tostring(entry.sample_id or '')))
          set_text(row_ui.action, '立即施放')
        else
          local has_special = runtime and runtime.modifier_card_effect_ids and runtime.modifier_card_effect_ids[entry.card_id] == true
          set_text(row_ui.title, string.format('%s [%s]', tostring(entry.title or ''), has_special and '已获得' or '未获得'))
          set_text(row_ui.action, has_special and '已获得' or '立即获得')
        end
        set_text(row_ui.desc, summarize_effect_text(entry.desc or ''))
        if not detail_entry then
          detail_entry = entry
        end
      else
        row_ui.entry = nil
        row_ui.mode = nil
      end
    end

    if detail_entry then
      set_text(ui.encyclopedia_detail_text, tostring(detail_entry.desc or ''))
    else
      set_text(ui.encyclopedia_detail_text, '当前分类暂无可显示条目。')
    end
  end

  local function toggle_board()
    local ui = ensure_board()
    if not ui then
      return
    end
    ui.visible = not ui.visible
    refresh_board()
  end

  local function register_dev_commands()
    if STATE.dev_commands_bond_gm_registered then
      return
    end
    STATE.dev_commands_bond_gm_registered = true

    develop_command.register('EGMBOND', {
      desc = '显示/隐藏羁绊GM面板，支持 on/off/toggle。',
      onCommand = function(mode)
        local ui = ensure_board()
        if not ui then
          return
        end
        mode = trim(mode):lower()
        if mode == 'on' then
          ui.visible = true
        elseif mode == 'off' then
          ui.visible = false
        else
          ui.visible = not ui.visible
        end
        refresh_board()
      end,
    })

    develop_command.register('EGMBONDEFFECT', {
      desc = BOND_GM_CMD_ACTIVATE_DESC,
      onCommand = function(bond_name)
        bond_name = trim(bond_name)
        if bond_name == '' then
          debug_message('用法：.egmbondeffect <羁绊名>')
          return
        end
        execute_activate_bond(bond_name, true)
      end,
    })

    develop_command.register('EGMCARD', {
      desc = '立即获得指定单卡特殊效果：.egmcard <card_id|卡名>',
      onCommand = function(card_ref)
        card_ref = trim(card_ref)
        if card_ref == '' then
          debug_message('用法：.egmcard <card_id|卡名>')
          return
        end
        execute_grant_card(card_ref)
      end,
    })

    develop_command.register('EGMFX100', {
      desc = '切换特殊效果100%触发：.egmfx100 [on/off/toggle]',
      onCommand = function(mode)
        if not set_force_special_effects_100 then
          debug_message('未注入特殊效果100%开关回调。')
          return
        end
        mode = trim(mode):lower()
        local current = is_force_special_effects_100 and is_force_special_effects_100() or false
        local target = current
        if mode == 'on' then
          target = true
        elseif mode == 'off' then
          target = false
        else
          target = not current
        end
        set_force_special_effects_100(target)
        debug_message(string.format('特殊效果100%%触发：%s', target and '开启' or '关闭'))
        refresh_board()
      end,
    })

    develop_command.register('EGMPROJ', {
      desc = '全局投射物覆盖：.egmproj [id|off|toggle]，默认 134255250',
      onCommand = function(mode)
        local cmd = trim(mode):lower()
        if cmd == '' or cmd == 'toggle' then
          if debug_toggle_global_projectile_override then
            debug_toggle_global_projectile_override(DEFAULT_DEBUG_PROJECTILE_KEY)
          else
            debug_message('未注入投射物覆盖回调。')
          end
          refresh_board()
          return
        end
        if cmd == 'off' or cmd == 'close' or cmd == '0' then
          if debug_clear_global_projectile_override then
            debug_clear_global_projectile_override()
          else
            debug_message('未注入投射物覆盖回调。')
          end
          refresh_board()
          return
        end
        local key = tonumber(cmd)
        if not key or key <= 0 then
          debug_message('用法：.egmproj [id|off|toggle]，例如 .egmproj 134255250')
          return
        end
        if debug_set_global_projectile_override then
          debug_set_global_projectile_override(key)
        else
          debug_message('未注入投射物覆盖回调。')
        end
        refresh_board()
      end,
    })

    develop_command.register('EGMBONDTRACE', {
      desc = '羁绊特效追踪开关：.egmbondtrace [on/off/toggle]',
      onCommand = function(mode)
        mode = trim(mode):lower()
        local current = STATE.bond_debug_trace_enabled == true
        local target = current
        if mode == 'on' then
          target = true
        elseif mode == 'off' then
          target = false
        else
          target = not current
        end
        STATE.bond_debug_trace_enabled = target
        debug_message(string.format('羁绊追踪日志：%s', target and '开启' or '关闭'))
      end,
    })

    develop_command.register('EGMBONDMAP', {
      desc = '打印羁绊投射物映射：.egmbondmap',
      onCommand = function()
        local map = BondVisualEditorIds.visual_by_bond or {}
        debug_message('---- 羁绊投射物映射 ----')
        for bond_name, cfg in pairs(map) do
          debug_message(string.format(
            '%s => projectile=%s, particle=%s, speed=%s, time=%s',
            tostring(bond_name),
            tostring(cfg.projectile_key),
            tostring(cfg.particle_key),
            tostring(cfg.projectile_speed),
            tostring(cfg.projectile_time)
          ))
        end
      end,
    })

    develop_command.register('EGMBONDTEST', {
      desc = BOND_GM_CMD_TEST_DESC,
      onCommand = function()
        if not run_bond_self_test then
          debug_message('未注入 run_bond_self_test 回调。')
          return
        end
        local report = run_bond_self_test() or {}
        debug_message(string.format(
          '羁绊自检完成：total=%s pass=%s fail=%s',
          tostring(report.total or 0),
          tostring(report.passed or 0),
          tostring(report.failed or 0)
        ))
      end,
    })

    develop_command.register('EGMBONDAUTO', {
      desc = '全自动羁绊回归：.egmbondauto（自检+激活关键羁绊+校验）',
      onCommand = function()
        local runtime = get_runtime()
        if not runtime then
          debug_message('运行时未初始化，无法执行全自动回归。')
          return
        end

        if set_force_special_effects_100 then
          set_force_special_effects_100(true)
        end

        local report = run_bond_self_test and run_bond_self_test() or { total = 0, passed = 0, failed = 0 }
        local targets = { '龙骑士', '冰霜法师' }
        local ok_count = 0
        local fail_count = 0

        for _, bond_name in ipairs(targets) do
          local ok_activate = execute_activate_bond(bond_name, true)
          local effect_id = 'initial_bond_set_' .. tostring(bond_name)
          local active = runtime.modifier_pool_active_effects and runtime.modifier_pool_active_effects[effect_id] == true or false
          local owned = get_owned_cards_count(runtime, bond_name)
          local need = get_required_cards(bond_name)
          if ok_activate and active then
            ok_count = ok_count + 1
            debug_message(string.format('[AUTO][PASS] %s 激活成功（%d/%d）', bond_name, owned, need))
          else
            fail_count = fail_count + 1
            debug_message(string.format('[AUTO][FAIL] %s 激活失败（%d/%d）', bond_name, owned, need))
          end
        end

        debug_message(string.format(
          '[AUTO][SUMMARY] 自检 pass=%s/%s fail=%s | 关键羁绊 pass=%d fail=%d | 特效100%%=%s',
          tostring(report.passed or 0),
          tostring(report.total or 0),
          tostring(report.failed or 0),
          ok_count,
          fail_count,
          is_force_special_effects_100 and is_force_special_effects_100() and 'on' or 'off'
        ))
      end,
    })
  end

  return {
    ensure_board = ensure_board,
    refresh_board = refresh_board,
    toggle_board = toggle_board,
    register_dev_commands = register_dev_commands,
  }
end

return M
