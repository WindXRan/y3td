local ui_res = require 'ui.res'
local skin = require 'ui.skin'
local theme = require 'ui.theme'
local UIStyle = require 'ui.style'
local Factory = require 'ui.factory'
local layout = require 'ui.runtime_hud_layout'
local RuntimeHudNodes = require 'ui.runtime_hud_nodes'
local UIRoot = require 'ui.ui_root'
local BondTipPanel = require 'ui.bond_tip_panel'
local GrowthWeaponItemTip = require 'ui.growth_weapon_item_tip'
local GearUpgrades = require 'runtime.gear_upgrades'

local M = {}

local BOND_SLOT_QUALITY_COLORS = {
  common = { 68, 162, 88, 255 },
  rare = { 72, 126, 210, 255 },
  epic = { 164, 108, 216, 255 },
  legendary = { 224, 172, 86, 255 },
}

local TOP_BG_BREATH_INTERVAL = 1.8
local TOP_BOSS_WARNING_THRESHOLD = 5
local GROWTH_WEAPON_LEVEL_ATTACK_GAIN = 10
local GROWTH_WEAPON_LEVEL_ALL_ATTR_GAIN = 2

local function resolve_ui(y3, player, path)
  return UIRoot.resolve_ui(y3, player, path)
end

local function resolve_first_ui(y3, player, paths)
  return UIRoot.resolve_first_ui(y3, player, paths)
end

local function is_ui_alive(ui)
  return UIRoot.is_alive(ui)
end

function M.create(env)
  local STATE = env.STATE
  local CONFIG = env.CONFIG
  local y3 = env.y3
  local round_number = env.round_number
  local hero_attr_system = env.hero_attr_system
  local factory = Factory.create(env)
  local bond_tip_panel = BondTipPanel.create({
    y3 = y3,
    get_player = env.get_player,
  })
  local growth_weapon_tip = GrowthWeaponItemTip.create({
    y3 = y3,
    get_player = env.get_player,
  })

  local create_panel = factory.create_panel
  local create_text = factory.create_text
  local create_button = factory.create_button
  local set_percent_pos = factory.set_percent_pos
  local get_hud_metrics = factory.get_hud_metrics
  local get_hud_scale = factory.get_hud_scale
  local scaled = factory.scaled
  local runtime_skin = skin.images.runtime_hud or {}
  local refresh_runtime_hud
  local bind_growth_weapon_slot
  local bind_default_item_slot_hover
  local attack_skill_slot_count = math.max(1, tonumber(env.attack_skill_slot_count) or 4)
  local bottom_bond_slot_count = 7

  local function fallback_create_styled_text(parent, x, y, width, height, style_key, value, z_order, h_align, v_align, font_size, color)
    local text = create_text(
      parent,
      x,
      y,
      width,
      height,
      font_size or math.max(10, math.floor((height or 18) * 0.72)),
      color,
      h_align or '中',
      v_align or '中',
      z_order
    )
    UIStyle.apply_text(text, style_key, value or '')
    return text
  end

  local create_styled_text = factory.create_styled_text or fallback_create_styled_text

  local function is_runtime_ui_animation_enabled()
    return CONFIG.runtime_ui_animations_enabled == true
  end

  local function get_challenge_charge_count(challenge_id)
    if STATE.challenge_charge_map and STATE.challenge_charge_map[challenge_id] ~= nil then
      return tonumber(STATE.challenge_charge_map[challenge_id]) or 0
    end
    return tonumber(STATE.challenge_charges) or 0
  end

  local function get_challenge_recover_sec(challenge_id)
    local def = CONFIG.challenges and CONFIG.challenges[challenge_id]
    local recover_sec = def and tonumber(def.recover_sec)
    if recover_sec and recover_sec > 0 then
      return recover_sec
    end
    return CONFIG.challenge_rules.recover_sec or 0
  end

  local function get_challenge_recover_remain(challenge_id)
    local max_charges = CONFIG.challenge_rules.max_charges or 0
    local charges = get_challenge_charge_count(challenge_id)
    if charges >= max_charges then
      return 0
    end
    local elapsed = STATE.challenge_recover_elapsed_map and STATE.challenge_recover_elapsed_map[challenge_id] or STATE.challenge_recover_elapsed or 0
    return math.max(0, get_challenge_recover_sec(challenge_id) - (tonumber(elapsed) or 0))
  end

  local function get_total_challenge_charge_count()
    if STATE.challenge_charge_map then
      local total = 0
      for _, charges in pairs(STATE.challenge_charge_map) do
        total = total + (tonumber(charges) or 0)
      end
      return total
    end
    return tonumber(STATE.challenge_charges) or 0
  end

  local function get_total_challenge_charge_max()
    if STATE.challenge_charge_map then
      local count = 0
      for _ in pairs(STATE.challenge_charge_map) do
        count = count + 1
      end
      return count * (CONFIG.challenge_rules.max_charges or 0)
    end
    return CONFIG.challenge_rules.max_charges or 0
  end

  local function get_hud_root()
    return UIRoot.get_overlay_parent(y3, env.get_player())
  end

  local function resolve_inventory_slot_ui(slot)
    local runtime_hud = STATE.runtime_hud
    local slot_ui = runtime_hud and runtime_hud.editor_bottom_inventory_anchors and runtime_hud.editor_bottom_inventory_anchors[slot] or nil
    if is_ui_alive(slot_ui) then
      return slot_ui
    end
    slot_ui = runtime_hud and runtime_hud.editor_bottom_inventory_slots and runtime_hud.editor_bottom_inventory_slots[slot] or nil
    if is_ui_alive(slot_ui) then
      return slot_ui
    end

    local player = env.get_player()
    local paths
    if slot == 1 then
      paths = {
        'GameHUD.main.inventory.equip_slot_bg_1.equip_slot_1',
        'GameHUD.layout_3.inventory.equip_slot_bg_1.equip_slot_1',
      }
    else
      paths = {
        string.format('GameHUD.main.inventory.equip_slot_bg_%d.equip_slot_1', slot),
        string.format('GameHUD.layout_3.inventory.equip_slot_bg_%d.equip_slot_1', slot),
      }
    end
    local resolved_ui = resolve_first_ui(y3, player, paths)
    if is_ui_alive(resolved_ui) then
      return resolved_ui
    end
    return nil
  end

  local function format_time(seconds)
    local total = math.max(0, math.floor(seconds or 0))
    local minute = total // 60
    local second = total % 60
    return string.format('%02d:%02d', minute, second)
  end

  local function format_compact(value)
    local number = round_number(value or 0)
    local abs_number = math.abs(number)
    if abs_number >= 1000000 then
      local text = string.format('%.1fm', number / 1000000)
      return text:gsub('%.0m$', 'm')
    end
    if abs_number >= 10000 then
      local text = string.format('%.1fk', number / 1000)
      return text:gsub('%.0k$', 'k')
    end
    return tostring(number)
  end

  local function get_hero_attr(name, fallback_name)
    if not STATE.hero or not STATE.hero:is_exist() then
      return 0
    end
    local value = hero_attr_system and hero_attr_system.get_attr(STATE.hero, name) or STATE.hero:get_attr(name)
    value = y3.helper.tonumber(value) or 0
    if value > 0 or not fallback_name then
      return value
    end
    local fallback = hero_attr_system and hero_attr_system.get_attr(STATE.hero, fallback_name) or STATE.hero:get_attr(fallback_name)
    return y3.helper.tonumber(fallback) or 0
  end

  local function set_visible_if_alive(ui, visible)
    if is_ui_alive(ui) then
      ui:set_visible(visible == true)
    end
  end

  local function set_text_if_alive(ui, text)
    if is_ui_alive(ui) and ui.set_text then
      ui:set_text(text or '')
    end
  end

  local function set_image_if_alive(ui, image, color)
    if not is_ui_alive(ui) then
      return
    end
    if image ~= nil and ui.set_image then
      ui:set_image(image)
    end
    if color and ui.set_image_color then
      ui:set_image_color(color[1], color[2], color[3], color[4] or 255)
    end
  end

  local function set_progress_if_alive(ui, current, max_value)
    if not is_ui_alive(ui) then
      return
    end
    local final_max = math.max(1, math.floor(max_value or 1))
    local final_current = math.max(0, math.min(final_max, math.floor(current or 0)))
    if ui.set_max_progress_bar_value then
      ui:set_max_progress_bar_value(final_max)
    end
    if ui.set_current_progress_bar_value then
      ui:set_current_progress_bar_value(final_current, 0)
    end
  end

  local function set_optional_text(ui, text)
    if is_ui_alive(ui) and ui.set_text then
      ui:set_text(text or '')
    end
  end

  local function call_ui_method_safely(ui, method_name, ...)
    if not is_ui_alive(ui) then
      return false
    end
    local method = ui[method_name]
    if type(method) ~= 'function' then
      return false
    end
    local ok = pcall(method, ui, ...)
    return ok
  end

  local function safe_remove_timer(timer)
    if timer and timer.remove then
      timer:remove()
    end
  end

  local function safe_remove_ui(ui)
    if ui and ui.remove then
      ui:remove()
    end
  end

  local function try_create_child_ui(parent, ui_type)
    if not is_ui_alive(parent) or type(parent.create_child) ~= 'function' then
      return nil
    end
    local ok, child = pcall(parent.create_child, parent, ui_type)
    if not ok or not child then
      return nil
    end
    return child
  end

  local function create_image(parent, x, y, width, height, z_order, image, color)
    local node = try_create_child_ui(parent, '图片')
    if not is_ui_alive(node) then
      return nil
    end
    node:set_ui_size(width, height)
    node:set_pos(x, y)
    call_ui_method_safely(node, 'set_ui_9_enable', false)
    if z_order then
      node:set_z_order(z_order)
    end
    set_image_if_alive(node, image or ui_res.common.empty, color)
    return node
  end

  local function get_ui_relative_pos(ui)
    if not is_ui_alive(ui) then
      return 0, 0
    end
    local x = ui.get_relative_x and ui:get_relative_x() or 0
    local y = ui.get_relative_y and ui:get_relative_y() or 0
    return x, y
  end

  local function get_ui_size(ui, fallback_width, fallback_height)
    if not is_ui_alive(ui) then
      return fallback_width or 0, fallback_height or 0
    end
    local width = ui.get_width and ui:get_width() or ui.get_real_width and ui:get_real_width() or fallback_width or 0
    local height = ui.get_height and ui:get_height() or ui.get_real_height and ui:get_real_height() or fallback_height or 0
    return math.max(1, math.floor((width or 0) + 0.5)), math.max(1, math.floor((height or 0) + 0.5))
  end

  local function play_ui_pop(ui, peak_scale, rise_duration, settle_duration)
    if not is_ui_alive(ui) then
      return false
    end

    local peak = peak_scale or 1.06
    local rise = rise_duration or 0.14
    local settle = settle_duration or 0.18
    if not call_ui_method_safely(ui, 'set_anim_scale', 1.0, 1.0, peak, peak, rise, 0) then
      return false
    end

    y3.ltimer.wait(rise, function()
      if is_ui_alive(ui) then
        call_ui_method_safely(ui, 'set_anim_scale', peak, peak, 1.0, 1.0, settle, 0)
      end
    end)
    return true
  end

  local function play_ui_float_fade(ui, start_offset_y, duration)
    if not is_ui_alive(ui) then
      return false
    end

    local x, y = get_ui_relative_pos(ui)
    local offset_y = start_offset_y or 6
    local anim_duration = duration or 0.18
    if ui.set_pos then
      ui:set_pos(x, y + offset_y)
    end
    call_ui_method_safely(ui, 'set_anim_pos', x, y + offset_y, x, y, anim_duration, 0)
    call_ui_method_safely(ui, 'set_anim_opacity', 0, 255, anim_duration, 0)
    return true
  end

  local function normalize_percent_bonus(value)
    local number = y3.helper.tonumber(value) or 0
    if math.abs(number) <= 1 then
      return number * 100
    end
    return number
  end

  local function combine_percent_bonus(value_a, value_b)
    return normalize_percent_bonus(value_a) + normalize_percent_bonus(value_b)
  end

  local function format_signed_compact(value)
    local number = y3.helper.tonumber(value) or 0
    if math.abs(number) < 0.0001 then
      return '+0'
    end
    local prefix = number >= 0 and '+' or '-'
    return prefix .. format_compact(math.abs(number))
  end

  local function format_percent_bonus_text(value_a, value_b)
    local total = combine_percent_bonus(value_a, value_b)
    local abs_total = math.abs(total)
    local text = string.format('%.1f', abs_total):gsub('%.0$', '')
    local prefix = total >= 0 and '+' or '-'
    return string.format('%s%s%%', prefix, text)
  end

  local function format_compact_breakdown_text(value, percent_bonus_a, percent_bonus_b, flat_bonus)
    local parts = {}
    local percent_text = format_percent_bonus_text(percent_bonus_a, percent_bonus_b)
    local flat_text = format_signed_compact(flat_bonus)
    if percent_text ~= '+0%' then
      parts[#parts + 1] = percent_text
    end
    if flat_text ~= '+0' then
      parts[#parts + 1] = flat_text
    end

    local base = format_compact(value)
    if #parts == 0 then
      return base
    end
    return string.format('%s (%s)', base, table.concat(parts, ', '))
  end

  local function format_editor_top_wave_time_text(text)
    if not text or text == '' then
      return '--s'
    end
    local seconds = tostring(text):match('([%d%.]+)%s*秒后登场')
    if seconds then
      return string.format('%ss', tostring(math.floor(tonumber(seconds) or 0)))
    end
    if tostring(text):find('已击败', 1, true) then
      return '已击败'
    end
    if tostring(text):find('HP ', 1, true) then
      return 'BOSS'
    end
    return tostring(text)
  end

  local function format_editor_top_boss_text(name, state)
    local boss_name = tostring(name or '')
    local boss_state = tostring(state or '')

    if boss_name == '' and boss_state == '' then
      return '准备迎战'
    end
    if boss_state == '' then
      return boss_name
    end
    if boss_state:find('HP ', 1, true) then
      if boss_name ~= '' then
        return boss_name .. ' 交战中'
      end
      return 'Boss 交战中'
    end
    if boss_state:find('已击败', 1, true) then
      if boss_name ~= '' then
        return boss_name .. ' 已击败'
      end
      return 'Boss 已击败'
    end
    if boss_state:match('([%d%.]+)%s*秒后登场') then
      if boss_name ~= '' then
        return boss_name .. ' 即将登场'
      end
      return 'Boss 即将登场'
    end
    if boss_name ~= '' then
      return boss_name .. ' ' .. boss_state
    end
    return boss_state
  end

  local function format_editor_top_game_time_text(text)
    local value = tostring(text or '')
    value = value:gsub('^战斗计时%s*', '')
    if value == '' then
      return '00：00'
    end
    return value:gsub(':', '：')
  end

  local function get_editor_top_boss_state_kind(state_text)
    local text = tostring(state_text or '')
    if text:match('([%d%.]+)%s*秒后登场') then
      return 'countdown'
    end
    if text:find('HP ', 1, true) then
      return 'fighting'
    end
    if text:find('已击败', 1, true) then
      return 'defeated'
    end
    return 'idle'
  end

  local function get_editor_top_boss_countdown_seconds(state_text)
    local seconds = tostring(state_text or ''):match('([%d%.]+)%s*秒后登场')
    if not seconds then
      return nil
    end
    return math.max(0, math.floor(tonumber(seconds) or 0))
  end

  local function format_growth_weapon_upgrade_bonus_text(next_level)
    local level = math.max(1, math.floor(tonumber(next_level) or 1))
    return string.format(
      'Lv.%d\n攻击 +%d  全属性 +%d',
      level,
      GROWTH_WEAPON_LEVEL_ATTACK_GAIN,
      GROWTH_WEAPON_LEVEL_ALL_ATTR_GAIN
    )
  end

  local function get_growth_weapon_current_level()
    local gear_state = STATE and STATE.gear_state or nil
    local weapon = gear_state and gear_state.items and gear_state.items.weapon or nil
    return math.max(1, math.floor(tonumber(weapon and weapon.level) or 1))
  end

  local function get_growth_weapon_next_upgrade_cost()
    return GearUpgrades.get_upgrade_cost('weapon', get_growth_weapon_current_level(), CONFIG and CONFIG.gear_upgrade_config) or 0
  end

  local function get_stage_text()
    if env.stage_runtime and env.stage_runtime.get_current_stage_text then
      local text = env.stage_runtime.get_current_stage_text()
      if text and text ~= '' then
        return text
      end
    end
    local wave_index = math.max(0, STATE.current_wave_index or 0)
    if wave_index <= 0 then
      return '章节 1-1'
    end
    return string.format('章节 1-%d', wave_index)
  end

  local function get_wave_title_text()
    local wave_index = math.max(0, STATE.current_wave_index or 0)
    if wave_index <= 0 then
      return '等待开波'
    end
    return string.format('第 %d / %d 波', wave_index, #CONFIG.waves)
  end

  local function get_wave_status_text()
    local active_wave = STATE.active_wave
    if not active_wave or not active_wave.wave then
      return '按 Space 查看当前战况'
    end
    return string.format(
      '本波已持续 %s  场上敌人 %d',
      format_time(active_wave.elapsed or 0),
      STATE.total_enemy_alive or 0
    )
  end

  local function get_boss_display()
    local active_wave = STATE.active_wave
    if not active_wave or not active_wave.wave then
      return {
        name = 'Boss 未登场',
        state = '等待本波开始',
        bg = theme.palette.accent_soft,
        text = theme.palette.text,
      }
    end

    local boss_name = env.get_boss_name(active_wave.wave)
    if active_wave.boss_spawned then
      local info = active_wave.boss_info
      if info and info.unit and info.unit:is_exist() then
        return {
          name = boss_name,
          state = string.format(
            'HP %s / %s',
            format_compact(info.unit:get_hp()),
            format_compact(info.unit:get_attr('生命') or info.unit:get_attr('最大生命'))
          ),
          bg = theme.palette.danger,
          text = { 255, 236, 240, 255 },
        }
      end
      return {
        name = boss_name,
        state = '已击败',
        bg = theme.palette.success,
        text = { 232, 247, 236, 255 },
      }
    end

    local remain = math.max(0, (active_wave.wave.boss_spawn_sec or 0) - (active_wave.elapsed or 0))
    return {
      name = boss_name,
      state = string.format('%.1f 秒后登场', remain),
      bg = theme.palette.warning,
      text = { 255, 242, 214, 255 },
    }
  end

  local function get_hero_hp_text()
    if not STATE.hero or not STATE.hero:is_exist() then
      return '生命 0 / 0'
    end
    return string.format(
      '生命 %s / %s',
      format_compact(STATE.hero:get_hp()),
      format_compact(get_hero_attr('生命结算值', '生命'))
    )
  end


  local function create_stat_text(parent, x, y, width, label, value, label_color, value_color, align, scale)
    local label_text = create_text(
      parent,
      x,
      y + scaled(8, scale),
      width,
      scaled(12, scale),
      scaled(10, scale),
      label_color or theme.palette.text_muted,
      align or '左',
      '中',
      9402
    )
    label_text:set_text(label)

    local value_text = create_text(
      parent,
      x,
      y - scaled(7, scale),
      width,
      scaled(18, scale),
      scaled(14, scale),
      value_color or theme.palette.text,
      align or '左',
      '中',
      9402
    )
    value_text:set_text(value)
    return label_text, value_text
  end

  local function get_decision_rarity_palette(rarity)
    if rarity == 'epic' then
      return {
        card = { 112, 72, 36, 238 },
        edge = { 228, 184, 112, 255 },
        title = { 255, 238, 206, 255 },
        tag = { 255, 210, 140, 255 },
        badge = { 168, 110, 48, 242 },
        badge_text = { 255, 241, 214, 255 },
      }
    end
    if rarity == 'rare' then
      return {
        card = { 40, 76, 118, 238 },
        edge = { 126, 188, 255, 255 },
        title = { 232, 244, 255, 255 },
        tag = { 170, 214, 255, 255 },
        badge = { 56, 110, 174, 242 },
        badge_text = { 230, 244, 255, 255 },
      }
    end
    return {
      card = { 38, 48, 66, 236 },
      edge = { 132, 152, 178, 255 },
      title = { 236, 242, 250, 255 },
      tag = { 182, 198, 220, 255 },
      badge = { 68, 82, 104, 238 },
      badge_text = { 232, 238, 248, 255 },
    }
  end

  local function get_decision_rarity_label(rarity)
    if rarity == 'epic' then
      return '史诗'
    end
    if rarity == 'rare' then
      return '稀有'
    end
    return '基础'
  end

  local function create_decision_option(parent, x, y, width, height, index, scale)
    local badge_width = layout.decision_panel.badge_width or 64
    local badge_height = layout.decision_panel.badge_height or 20
    local shadow = create_panel(
      parent,
      x,
      y - scaled(4, scale),
      width + scaled(10, scale),
      height + scaled(10, scale),
      { 6, 10, 18, 138 },
      { 18, 18, 18, 18 },
      9450,
      runtime_skin.decision_option_shadow
    )
    local bg = create_panel(
      parent,
      x,
      y,
      width,
      height,
      { 38, 48, 66, 236 },
      { 20, 20, 20, 20 },
      9451,
      runtime_skin.decision_option_bg
    )
    local edge = create_panel(
      bg,
      scaled(12, scale),
      scaled(14, scale),
      width - scaled(24, scale),
      scaled(5, scale),
      { 132, 152, 178, 255 },
      { 8, 8, 8, 8 },
      9452
    )
    local badge_bg = create_panel(
      bg,
      width - scaled(42, scale),
      scaled(108, scale),
      scaled(badge_width, scale),
      scaled(badge_height, scale),
      { 68, 82, 104, 238 },
      { 8, 8, 8, 8 },
      9453,
      runtime_skin.decision_option_badge
    )
    local emblem = create_panel(
      bg,
      scaled(28, scale),
      scaled(108, scale),
      scaled(22, scale),
      scaled(22, scale),
      { 220, 236, 255, 235 },
      theme.insets.soft,
      9454,
      runtime_skin.decision_option_emblem
    )
    emblem:set_anchor(0.5, 0.5)
    local badge_text = create_text(
      badge_bg,
      scaled(badge_width * 0.5, scale),
      scaled(badge_height * 0.5, scale),
      scaled(badge_width, scale),
      scaled(badge_height, scale),
      scaled(9, scale),
      { 232, 238, 248, 255 },
      nil,
      nil,
      9454
    )
    badge_text:set_text('基础')
    local tag_text = create_text(
      bg,
      scaled(18, scale),
      scaled(106, scale),
      width - scaled(36, scale),
      scaled(18, scale),
      scaled(12, scale),
      { 182, 198, 220, 255 },
      '左',
      '中',
      9455
    )
    local title_text = create_text(
      bg,
      scaled(18, scale),
      scaled(78, scale),
      width - scaled(36, scale),
      scaled(24, scale),
      scaled(18, scale),
      { 236, 242, 250, 255 },
      '左',
      '中',
      9455
    )
    local desc_text = create_text(
      bg,
      scaled(18, scale),
      scaled(36, scale),
      width - scaled(36, scale),
      scaled(36, scale),
      scaled(12, scale),
      { 196, 208, 224, 255 },
      '左',
      '中',
      9455
    )
    local hotkey_text = create_text(
      bg,
      width - scaled(26, scale),
      scaled(108, scale),
      scaled(24, scale),
      scaled(18, scale),
      scaled(15, scale),
      { 240, 245, 255, 255 },
      '右',
      '中',
      9455
    )
    hotkey_text:set_text(tostring(index))
    local pick_text = create_text(
      bg,
      scaled(18, scale),
      scaled(18, scale),
      width - scaled(36, scale),
      scaled(14, scale),
      scaled(10, scale),
      { 144, 168, 196, 255 },
      nil,
      nil,
      9455
    )
    pick_text:set_text(string.format('按键 %d / 点击选择', index))

    local button = parent:create_child('按钮')
    button:set_ui_size(width, height)
    button:set_pos(x, y)
    button:set_text('')
    button:set_btn_status_image(1, ui_res.common.empty)
    button:set_btn_status_image(2, ui_res.common.empty)
    button:set_btn_status_image(3, ui_res.common.empty)
    button:set_btn_status_image(4, ui_res.common.empty)
    button:set_z_order(9456)
    button:add_fast_event('左键-点击', function()
      if env.apply_round_choice then
        env.apply_round_choice(index)
        refresh_runtime_hud()
      end
    end)

    return {
      shadow = shadow,
      bg = bg,
      edge = edge,
      badge_bg = badge_bg,
      badge_text = badge_text,
      emblem = emblem,
      tag_text = tag_text,
      title_text = title_text,
      desc_text = desc_text,
      hotkey_text = hotkey_text,
      pick_text = pick_text,
      button = button,
    }
  end

  local function get_decision_rarity_palette_v2(rarity)
    local palette = get_decision_rarity_palette(rarity) or {}
    palette.shadow = palette.shadow or { 10, 16, 28, 138 }
    palette.desc = palette.desc or { 196, 208, 224, 255 }
    palette.hint = palette.hint or { 144, 168, 196, 255 }
    if rarity == 'epic' then
      palette.shadow = { 82, 52, 20, 168 }
      palette.desc = { 255, 228, 188, 255 }
      palette.hint = { 255, 210, 132, 255 }
    elseif rarity == 'rare' then
      palette.shadow = { 18, 50, 90, 168 }
      palette.desc = { 210, 228, 246, 255 }
      palette.hint = { 164, 214, 255, 255 }
    end
    return palette
  end

  local function get_decision_rarity_label_v2(rarity)
    if rarity == 'epic' then
      return '史诗'
    end
    if rarity == 'rare' then
      return '稀有'
    end
    return '基础'
  end

  local function get_decision_caption(kind)
    if kind == 'upgrade' then
      return '技能抉择'
    end
    if kind == 'bond' then
      return '仙缘抉择'
    end
    if kind == 'evolution' or kind == 'mark' then
      return '真身抉择'
    end
    if kind == 'treasure' then
      return '宝物抉择'
    end
    return '当前抉择'
  end

  local function get_decision_pick_text(kind, index)
    if kind == 'treasure' then
      return string.format('按 %d 领取此项', index)
    end
    if kind == 'bond' then
      return string.format('按 %d 收下此缘', index)
    end
    if kind == 'evolution' or kind == 'mark' then
      return string.format('按 %d 选择此真身', index)
    end
    return string.format('按 %d 确认选择', index)
  end

  local function get_decision_notice(kind)
    if kind == 'upgrade' then
      return '成长抉择待确认'
    end
    if kind == 'bond' then
      return '仙缘感应进行中'
    end
    if kind == 'evolution' or kind == 'mark' then
      return '真身进化进行中'
    end
    if kind == 'treasure' then
      return '宝物选择进行中'
    end
    return '抉择进行中'
  end

  local function is_hud_alive(runtime_hud)
    return runtime_hud
      and runtime_hud.center_root
      and not runtime_hud.center_root:is_removed()
      and (not runtime_hud.decision_root or not runtime_hud.decision_root:is_removed())
  end

  local function hide_bond_tip()
    if bond_tip_panel and bond_tip_panel.hide then
      bond_tip_panel.hide()
    end
  end

  local function hide_growth_weapon_tip()
    if growth_weapon_tip and growth_weapon_tip.hide then
      growth_weapon_tip.hide()
    end
  end

  local function show_growth_weapon_tip(anchor_ui)
    if not anchor_ui or not env.build_growth_weapon_tip_payload then
      hide_growth_weapon_tip()
      return
    end
    local payload = env.build_growth_weapon_tip_payload()
    if not payload then
      hide_growth_weapon_tip()
      return
    end
    growth_weapon_tip.show_for_anchor(anchor_ui, payload)
  end

  local function get_hero_bar_item(slot)
    if not STATE.hero or not STATE.hero.is_exist or not STATE.hero:is_exist() then
      return nil
    end
    return STATE.hero:get_item_by_slot(y3.const.SlotType.BAR, slot)
      or STATE.hero:get_item_by_slot(y3.const.SlotType.BAR, slot - 1)
  end

  local function is_growth_weapon_item(item)
    local item_key = env.get_growth_weapon_item_key and env.get_growth_weapon_item_key() or nil
    return item and item_key and item.get_key and item:get_key() == item_key
  end

  local function clear_top_center_fx(runtime_hud)
    if not runtime_hud then
      return
    end
    safe_remove_timer(runtime_hud.editor_top_breath_timer)
    safe_remove_timer(runtime_hud.editor_top_breath_reset_timer)
    runtime_hud.editor_top_breath_timer = nil
    runtime_hud.editor_top_breath_reset_timer = nil
    runtime_hud.editor_top_last_wave_text = nil
    runtime_hud.editor_top_last_boss_state_kind = nil
    runtime_hud.editor_top_last_boss_warning_second = nil
  end

  local function ensure_top_center_fx(runtime_hud)
    if not runtime_hud or not is_ui_alive(runtime_hud.editor_top_bg_root) then
      return nil
    end
    return runtime_hud.editor_top_bg_root
  end

  local function start_top_center_breath_fx(runtime_hud)
    if not is_runtime_ui_animation_enabled() then
      clear_top_center_fx(runtime_hud)
      return
    end
    local bg_root = ensure_top_center_fx(runtime_hud)
    if not bg_root or runtime_hud.editor_top_breath_timer then
      return
    end

    local function pulse_once()
      if not is_ui_alive(bg_root) then
        clear_top_center_fx(runtime_hud)
        return
      end
      call_ui_method_safely(bg_root, 'set_anim_scale', 1.0, 1.0, 1.016, 1.032, TOP_BG_BREATH_INTERVAL * 0.5, 0)
      safe_remove_timer(runtime_hud.editor_top_breath_reset_timer)
      runtime_hud.editor_top_breath_reset_timer = y3.ltimer.wait(TOP_BG_BREATH_INTERVAL * 0.5, function()
        if is_ui_alive(bg_root) then
          call_ui_method_safely(bg_root, 'set_anim_scale', 1.016, 1.032, 1.0, 1.0, TOP_BG_BREATH_INTERVAL * 0.5, 0)
        end
        runtime_hud.editor_top_breath_reset_timer = nil
      end)
    end

    pulse_once()
    runtime_hud.editor_top_breath_timer = y3.ltimer.loop(TOP_BG_BREATH_INTERVAL, function()
      pulse_once()
    end)
  end

  local function play_top_wave_transition_fx(runtime_hud)
    if not is_runtime_ui_animation_enabled() then
      return
    end
    play_ui_pop(runtime_hud and runtime_hud.editor_top_bg_root, 1.018, 0.12, 0.16)
    play_ui_pop(runtime_hud and runtime_hud.editor_top_wave_value, 1.10, 0.12, 0.18)
    play_ui_float_fade(runtime_hud and runtime_hud.editor_top_stage_value, 8, 0.18)
  end

  local function play_top_boss_warning_fx(runtime_hud)
    if not is_runtime_ui_animation_enabled() then
      return
    end
    play_ui_pop(runtime_hud and runtime_hud.editor_top_bg_root, 1.02, 0.10, 0.14)
    play_ui_pop(runtime_hud and runtime_hud.editor_top_boss_value, 1.06, 0.10, 0.14)
    play_ui_pop(runtime_hud and runtime_hud.editor_top_boss_countdown_value, 1.12, 0.10, 0.16)
  end

  local function play_top_boss_spawn_fx(runtime_hud)
    if not is_runtime_ui_animation_enabled() then
      return
    end
    play_ui_pop(runtime_hud and runtime_hud.editor_top_bg_root, 1.04, 0.10, 0.18)
    play_ui_pop(runtime_hud and runtime_hud.editor_top_boss_value, 1.10, 0.10, 0.18)
    play_ui_pop(runtime_hud and runtime_hud.editor_top_boss_countdown_value, 1.08, 0.10, 0.16)
  end

  local function play_top_boss_defeated_fx(runtime_hud)
    if not is_runtime_ui_animation_enabled() then
      return
    end
    play_ui_pop(runtime_hud and runtime_hud.editor_top_bg_root, 1.025, 0.10, 0.16)
    play_ui_pop(runtime_hud and runtime_hud.editor_top_boss_value, 1.06, 0.10, 0.16)
  end

  local function update_top_center_fx(runtime_hud, wave_text, stage_text, boss_display)
    if not runtime_hud then
      return
    end

    start_top_center_breath_fx(runtime_hud)

    local boss_kind = get_editor_top_boss_state_kind(boss_display and boss_display.state or nil)
    local boss_countdown_seconds = get_editor_top_boss_countdown_seconds(boss_display and boss_display.state or nil)

    if runtime_hud.editor_top_last_wave_text ~= nil and runtime_hud.editor_top_last_wave_text ~= wave_text then
      play_top_wave_transition_fx(runtime_hud)
    end
    runtime_hud.editor_top_last_wave_text = wave_text
    runtime_hud.editor_top_last_stage_text = stage_text

    if runtime_hud.editor_top_last_boss_state_kind ~= nil and runtime_hud.editor_top_last_boss_state_kind ~= boss_kind then
      if boss_kind == 'fighting' then
        play_top_boss_spawn_fx(runtime_hud)
      elseif boss_kind == 'defeated' then
        play_top_boss_defeated_fx(runtime_hud)
      elseif boss_kind == 'countdown' then
        play_top_boss_warning_fx(runtime_hud)
      end
    end

    if boss_kind == 'countdown' and boss_countdown_seconds and boss_countdown_seconds <= TOP_BOSS_WARNING_THRESHOLD then
      if runtime_hud.editor_top_last_boss_warning_second ~= boss_countdown_seconds then
        play_top_boss_warning_fx(runtime_hud)
      end
      runtime_hud.editor_top_last_boss_warning_second = boss_countdown_seconds
    else
      runtime_hud.editor_top_last_boss_warning_second = nil
    end

    runtime_hud.editor_top_last_boss_state_kind = boss_kind
  end

  local function clear_growth_weapon_slot_fx(runtime_hud)
    if not runtime_hud then
      return
    end
    safe_remove_timer(runtime_hud.growth_weapon_ready_pulse_timer)
    runtime_hud.growth_weapon_ready_pulse_timer = nil
    if is_ui_alive(runtime_hud.growth_weapon_ready_pulse_glow) then
      runtime_hud.growth_weapon_ready_pulse_glow:set_visible(false)
      runtime_hud.growth_weapon_ready_pulse_glow:set_alpha(0)
    end
    safe_remove_timer(runtime_hud.growth_weapon_hover_hide_timer)
    runtime_hud.growth_weapon_hover_hide_timer = nil
    if is_ui_alive(runtime_hud.growth_weapon_hover_glow) then
      runtime_hud.growth_weapon_hover_glow:set_visible(false)
      runtime_hud.growth_weapon_hover_glow:set_alpha(0)
    end
  end

  local function clear_growth_weapon_ready_pulse(runtime_hud)
    if not runtime_hud then
      return
    end
    safe_remove_timer(runtime_hud.growth_weapon_ready_pulse_timer)
    runtime_hud.growth_weapon_ready_pulse_timer = nil
    if is_ui_alive(runtime_hud.growth_weapon_ready_pulse_glow) then
      runtime_hud.growth_weapon_ready_pulse_glow:set_visible(false)
      runtime_hud.growth_weapon_ready_pulse_glow:set_alpha(0)
    end
  end

  local function ensure_growth_weapon_slot_fx(runtime_hud)
    if not runtime_hud then
      return nil
    end

    bind_growth_weapon_slot(runtime_hud)
    local host = runtime_hud.growth_weapon_slot or runtime_hud.growth_weapon_tip_anchor
    if not is_ui_alive(host) then
      return nil
    end

    if runtime_hud.growth_weapon_slot_fx_host ~= host then
      safe_remove_ui(runtime_hud.growth_weapon_ready_pulse_glow)
      safe_remove_ui(runtime_hud.growth_weapon_hover_glow)
      runtime_hud.growth_weapon_ready_pulse_glow = nil
      runtime_hud.growth_weapon_hover_glow = nil
      runtime_hud.growth_weapon_slot_fx_host = host
      clear_growth_weapon_slot_fx(runtime_hud)
    end

    local width, height = get_ui_size(host, 64, 64)

    if not is_ui_alive(runtime_hud.growth_weapon_ready_pulse_glow) then
      local pulse_glow = try_create_child_ui(host, '图片')
      if pulse_glow then
        pulse_glow:set_ui_size(width + 18, height + 18)
        pulse_glow:set_pos(width * 0.5, height * 0.5)
        pulse_glow:set_anchor(0.5, 0.5)
        pulse_glow:set_image(ui_res.common_tip.panel_bg)
        pulse_glow:set_image_color(theme.palette.gold[1], theme.palette.gold[2], theme.palette.gold[3], 0)
        pulse_glow:set_ui_9_enable(true)
        pulse_glow:set_ui_9(
          theme.insets.normal[1],
          theme.insets.normal[2],
          theme.insets.normal[3],
          theme.insets.normal[4]
        )
        pulse_glow:set_z_order(9817)
        pulse_glow:set_visible(false)
        if pulse_glow.set_intercepts_operations then
          pulse_glow:set_intercepts_operations(false)
        end
        runtime_hud.growth_weapon_ready_pulse_glow = pulse_glow
      end
    end

    if not is_ui_alive(runtime_hud.growth_weapon_hover_glow) then
      local hover_glow = try_create_child_ui(host, '图片')
      if hover_glow then
        hover_glow:set_ui_size(width + 12, height + 12)
        hover_glow:set_pos(width * 0.5, height * 0.5)
        hover_glow:set_anchor(0.5, 0.5)
        hover_glow:set_image(ui_res.common_tip.panel_bg)
        hover_glow:set_image_color(theme.palette.accent_bright[1], theme.palette.accent_bright[2], theme.palette.accent_bright[3], 0)
        hover_glow:set_ui_9_enable(true)
        hover_glow:set_ui_9(
          theme.insets.normal[1],
          theme.insets.normal[2],
          theme.insets.normal[3],
          theme.insets.normal[4]
        )
        hover_glow:set_z_order(9818)
        hover_glow:set_visible(false)
        if hover_glow.set_intercepts_operations then
          hover_glow:set_intercepts_operations(false)
        end
        runtime_hud.growth_weapon_hover_glow = hover_glow
      end
    end

    if is_ui_alive(runtime_hud.growth_weapon_ready_pulse_glow) then
      runtime_hud.growth_weapon_ready_pulse_glow:set_ui_size(width + 18, height + 18)
      runtime_hud.growth_weapon_ready_pulse_glow:set_pos(width * 0.5, height * 0.5)
    end
    if is_ui_alive(runtime_hud.growth_weapon_hover_glow) then
      runtime_hud.growth_weapon_hover_glow:set_ui_size(width + 12, height + 12)
      runtime_hud.growth_weapon_hover_glow:set_pos(width * 0.5, height * 0.5)
    end

    return {
      host = host,
      width = width,
      height = height,
      pulse_glow = runtime_hud.growth_weapon_ready_pulse_glow,
      hover_glow = runtime_hud.growth_weapon_hover_glow,
    }
  end

  local function should_growth_weapon_ready_pulse()
    local item = get_hero_bar_item(1)
    if not is_growth_weapon_item(item) then
      return false
    end
    local next_cost = get_growth_weapon_next_upgrade_cost()
    if next_cost <= 0 then
      return false
    end
    return (STATE.resources and STATE.resources.gold or 0) >= next_cost
  end

  local function set_growth_weapon_slot_hover_fx(runtime_hud, hovered)
    if not is_runtime_ui_animation_enabled() then
      clear_growth_weapon_slot_fx(runtime_hud)
      return
    end
    local fx = ensure_growth_weapon_slot_fx(runtime_hud)
    if not fx or not is_ui_alive(fx.host) then
      return
    end

    safe_remove_timer(runtime_hud.growth_weapon_hover_hide_timer)
    runtime_hud.growth_weapon_hover_hide_timer = nil

    if hovered == true and is_growth_weapon_item(get_hero_bar_item(1)) then
      if is_ui_alive(fx.hover_glow) then
        fx.hover_glow:set_visible(true)
        fx.hover_glow:set_alpha(148)
        fx.hover_glow:set_anim_opacity(0, 148, 0.12, 0)
      end
      call_ui_method_safely(fx.host, 'set_anim_scale', 1.0, 1.0, 1.05, 1.05, 0.12, 0)
      return
    end

    if is_ui_alive(fx.hover_glow) then
      fx.hover_glow:set_alpha(88)
      fx.hover_glow:set_anim_opacity(88, 0, 0.12, 0)
      runtime_hud.growth_weapon_hover_hide_timer = y3.ltimer.wait(0.12, function()
        if is_ui_alive(fx.hover_glow) then
          fx.hover_glow:set_visible(false)
          fx.hover_glow:set_alpha(0)
        end
        runtime_hud.growth_weapon_hover_hide_timer = nil
      end)
    end
    call_ui_method_safely(fx.host, 'set_anim_scale', 1.05, 1.05, 1.0, 1.0, 0.14, 0)
  end

  local function update_growth_weapon_ready_fx(runtime_hud)
    if not is_runtime_ui_animation_enabled() then
      clear_growth_weapon_ready_pulse(runtime_hud)
      return
    end
    local fx = ensure_growth_weapon_slot_fx(runtime_hud)
    if not fx or not should_growth_weapon_ready_pulse() then
      clear_growth_weapon_ready_pulse(runtime_hud)
      return
    end

    local function pulse_once()
      if not is_ui_alive(fx.pulse_glow) then
        clear_growth_weapon_slot_fx(runtime_hud)
        return
      end
      fx.pulse_glow:set_visible(true)
      fx.pulse_glow:set_alpha(164)
      fx.pulse_glow:set_anim_scale(0.94, 0.94, 1.16, 1.16, 0.46, 0)
      fx.pulse_glow:set_anim_opacity(164, 0, 0.46, 0)
    end

    if not runtime_hud.growth_weapon_ready_pulse_timer then
      pulse_once()
      runtime_hud.growth_weapon_ready_pulse_timer = y3.ltimer.loop(1.25, function()
        pulse_once()
      end)
    end
  end

  local function bind_ui_click_once(runtime_hud, key, ui, callback)
    if not runtime_hud or not is_ui_alive(ui) then
      return
    end
    runtime_hud.bound_click_targets = runtime_hud.bound_click_targets or {}
    if runtime_hud.bound_click_targets[key] == ui then
      return
    end
    runtime_hud.bound_click_targets[key] = ui
    if ui.set_intercepts_operations then
      ui:set_intercepts_operations(true)
    end
    ui:add_fast_event('左键-点击', function()
      hide_bond_tip()
      hide_growth_weapon_tip()
      if callback then
        callback()
      end
    end)
  end

  local function attach_bottom_bg_prefab(runtime_hud)
    if not runtime_hud then
      return
    end
    if is_ui_alive(runtime_hud.bottom_bg_root) then
      return
    end

    local root = UIRoot.get_bottom_root(y3, env.get_player())
    if not root then
      return
    end

    RuntimeHudNodes.attach_bottom_bg(runtime_hud, root)
  end

  local function hide_legacy_bottom_panels(runtime_hud)
    if not runtime_hud then
      return
    end
    set_visible_if_alive(runtime_hud.legacy_game_hud_inventory, false)
    set_visible_if_alive(runtime_hud.legacy_game_hud_skill_list, false)
  end

  local function create_bottom_skill_slot_nodes(slot_host, slot_index, kind)
    if not is_ui_alive(slot_host) then
      return nil
    end

    local width, height = get_ui_size(slot_host, 66, 66)

    local icon = create_image(
      slot_host,
      width * 0.5,
      height * 0.5,
      width,
      height,
      9411,
      ui_res.common.empty,
      { 255, 255, 255, 255 }
    )
    local slot_hint = create_text(
      slot_host,
      math.floor(width * 0.16),
      math.floor(height * 0.82),
      math.max(14, math.floor(width * 0.24)),
      10,
      8,
      { 170, 188, 208, 255 },
      '中',
      '中',
      9412
    )
    local badge = create_text(
      slot_host,
      math.floor(width * 0.76),
      math.floor(height * 0.82),
      math.max(24, math.floor(width * 0.32)),
      10,
      8,
      { 255, 230, 182, 255 },
      '中',
      '中',
      9412
    )
    local meta = create_text(
      slot_host,
      math.floor(width * 0.5),
      math.max(8, math.floor(height * 0.14)),
      math.max(58, width - 8),
      10,
      8,
      { 236, 242, 250, 255 },
      '中',
      '中',
      9412
    )

    if is_ui_alive(slot_hint) then
      slot_hint:set_anchor(0.5, 0.5)
    end
    if is_ui_alive(badge) then
      badge:set_anchor(0.5, 0.5)
    end
    if is_ui_alive(meta) then
      meta:set_anchor(0.5, 0.5)
    end
    if is_ui_alive(icon) then
      icon:set_anchor(0.5, 0.5)
    end
    if slot_host.set_intercepts_operations then
      slot_host:set_intercepts_operations(true)
    end
    if is_ui_alive(icon) and icon.set_intercepts_operations then
      icon:set_intercepts_operations(false)
    end

    return {
      host = slot_host,
      icon = icon,
      slot_hint = slot_hint,
      badge = badge,
      meta = meta,
      kind = kind,
      slot_index = slot_index,
    }
  end

  local function ensure_bottom_slot_entry(runtime_hud, key, host, slot_index, kind)
    runtime_hud.bottom_dynamic_slot_nodes = runtime_hud.bottom_dynamic_slot_nodes or {}

    local slot_nodes = runtime_hud.bottom_dynamic_slot_nodes[key]
    if slot_nodes and slot_nodes.host == host and is_ui_alive(slot_nodes.host) then
      slot_nodes.kind = kind
      slot_nodes.slot_index = slot_index
      return slot_nodes
    end

    slot_nodes = create_bottom_skill_slot_nodes(host, slot_index, kind)
    runtime_hud.bottom_dynamic_slot_nodes[key] = slot_nodes
    return slot_nodes
  end

  local function ensure_bottom_skill_slots(runtime_hud)
    if not runtime_hud then
      return
    end

    runtime_hud.skill_slots = runtime_hud.skill_slots or {}
    runtime_hud.editor_bottom_bond_slots = runtime_hud.editor_bottom_bond_slots or {}

    local hosts = runtime_hud.bottom_skill_slot_hosts or {}
    for slot = 1, attack_skill_slot_count do
      local host = hosts[slot]
      runtime_hud.skill_slots[slot] = ensure_bottom_slot_entry(runtime_hud, 'attack_' .. tostring(slot), host, slot, 'attack')
    end

    for slot = 1, bottom_bond_slot_count do
      local host = hosts[attack_skill_slot_count + slot]
      runtime_hud.editor_bottom_bond_slots[slot] = ensure_bottom_slot_entry(runtime_hud, 'bond_' .. tostring(slot), host, slot, 'bond')
    end
  end

  local function get_bottom_slot_anchor(slot_nodes)
    if type(slot_nodes) ~= 'table' then
      return slot_nodes
    end
    if is_ui_alive(slot_nodes.host) then
      return slot_nodes.host
    end
    if is_ui_alive(slot_nodes.icon) then
      return slot_nodes.icon
    end
    return nil
  end

  local function render_bottom_attack_skill_slot(slot_nodes, slot, skill)
    local host = get_bottom_slot_anchor(slot_nodes)
    if not is_ui_alive(host) then
      return
    end

    set_visible_if_alive(host, true)
    set_text_if_alive(slot_nodes.slot_hint, tostring(slot))

    if skill then
      set_image_if_alive(host, nil, { 255, 255, 255, 255 })
      set_image_if_alive(slot_nodes.icon, skill.ui_icon or skill.icon or ui_res.game_hud.unit_icon, { 255, 255, 255, 255 })
      set_text_if_alive(slot_nodes.badge, 'Lv' .. tostring(skill.level or 1))
      set_text_if_alive(slot_nodes.meta, skill.name or '')
      if is_ui_alive(slot_nodes.meta) and slot_nodes.meta.set_text_color then
        slot_nodes.meta:set_text_color(236, 242, 250, 255)
      end
      return
    end

    set_image_if_alive(host, nil, { 132, 132, 132, 190 })
    set_image_if_alive(slot_nodes.icon, ui_res.common.empty, { 86, 104, 128, 180 })
    set_text_if_alive(slot_nodes.badge, '')
    set_text_if_alive(slot_nodes.meta, '')
    if is_ui_alive(slot_nodes.meta) and slot_nodes.meta.set_text_color then
      slot_nodes.meta:set_text_color(132, 148, 174, 255)
    end
  end

  local function render_bottom_bond_slot(slot_nodes, slot, payload)
    local host = get_bottom_slot_anchor(slot_nodes)
    if not is_ui_alive(host) then
      return
    end

    set_visible_if_alive(host, true)
    set_text_if_alive(slot_nodes.slot_hint, tostring(slot))

    if payload then
      local color = BOND_SLOT_QUALITY_COLORS[payload.quality or 'common'] or BOND_SLOT_QUALITY_COLORS.common
      set_image_if_alive(host, nil, color)
      set_image_if_alive(slot_nodes.icon, payload.icon_res or ui_res.hero_prefab.icon_1, { 255, 255, 255, 255 })
      set_text_if_alive(slot_nodes.badge, '缘')
      set_text_if_alive(slot_nodes.meta, payload.item_name_text or payload.title_text or '羁绊')
      if is_ui_alive(slot_nodes.meta) and slot_nodes.meta.set_text_color then
        slot_nodes.meta:set_text_color(236, 242, 250, 255)
      end
      return
    end

    set_image_if_alive(host, nil, { 116, 130, 154, 148 })
    set_image_if_alive(slot_nodes.icon, ui_res.common.empty, { 72, 88, 112, 220 })
    set_text_if_alive(slot_nodes.badge, '')
    set_text_if_alive(slot_nodes.meta, '')
    if is_ui_alive(slot_nodes.meta) and slot_nodes.meta.set_text_color then
      slot_nodes.meta:set_text_color(132, 148, 174, 255)
    end
  end

  local function bind_bottom_bond_icons(runtime_hud)
    if not runtime_hud then
      return
    end
    runtime_hud.editor_bottom_bond_slot_bound = runtime_hud.editor_bottom_bond_slot_bound or {}
    runtime_hud.editor_bottom_bond_payloads = runtime_hud.editor_bottom_bond_payloads or {}
    for slot = 1, bottom_bond_slot_count do
      local slot_nodes = runtime_hud.editor_bottom_bond_slots and runtime_hud.editor_bottom_bond_slots[slot] or nil
      local icon_ui = get_bottom_slot_anchor(slot_nodes)
      if is_ui_alive(icon_ui) and runtime_hud.editor_bottom_bond_slot_bound[slot] ~= icon_ui then
        runtime_hud.editor_bottom_bond_slot_bound[slot] = icon_ui
        if icon_ui.set_intercepts_operations then
          icon_ui:set_intercepts_operations(true)
        end
        icon_ui:add_fast_event('鼠标-移入', function()
          local payload = runtime_hud.editor_bottom_bond_payloads[slot]
          if payload then
            bond_tip_panel.show_for_anchor(icon_ui, payload)
          else
            hide_bond_tip()
          end
        end)
        icon_ui:add_fast_event('鼠标-移出', function()
          hide_bond_tip()
        end)
        icon_ui:add_fast_event('左键-点击', function()
          hide_bond_tip()
        end)
      end
    end
  end

  local function bind_bottom_bg_actions(runtime_hud)
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
  end

  bind_growth_weapon_slot = function(runtime_hud)
    if not runtime_hud then
      return runtime_hud
    end
    runtime_hud.growth_weapon_slot = runtime_hud.editor_bottom_inventory_slots and runtime_hud.editor_bottom_inventory_slots[1] or nil
    if not is_ui_alive(runtime_hud.growth_weapon_slot) then
      runtime_hud.growth_weapon_slot = runtime_hud.editor_bottom_inventory_anchors and runtime_hud.editor_bottom_inventory_anchors[1] or nil
    end

    local slot_ui = runtime_hud.growth_weapon_slot
    if is_ui_alive(slot_ui) then
      call_ui_method_safely(slot_ui, 'set_equip_slot_use_operation', '无')
      call_ui_method_safely(slot_ui, 'set_equip_slot_drag_operation', '无')
    end
    return runtime_hud
  end

  local function clear_growth_weapon_upgrade_fx(runtime_hud)
    if not runtime_hud then
      return
    end
    safe_remove_timer(runtime_hud.growth_weapon_upgrade_fx_timer)
    safe_remove_timer(runtime_hud.growth_weapon_upgrade_scale_reset_timer)
    runtime_hud.growth_weapon_upgrade_fx_timer = nil
    runtime_hud.growth_weapon_upgrade_scale_reset_timer = nil
    if is_ui_alive(runtime_hud.growth_weapon_upgrade_flash) then
      runtime_hud.growth_weapon_upgrade_flash:set_visible(false)
      runtime_hud.growth_weapon_upgrade_flash:set_alpha(0)
    end
    if is_ui_alive(runtime_hud.growth_weapon_upgrade_label) then
      runtime_hud.growth_weapon_upgrade_label:set_visible(false)
      runtime_hud.growth_weapon_upgrade_label:set_alpha(0)
    end
    if is_ui_alive(runtime_hud.growth_weapon_upgrade_shine) then
      runtime_hud.growth_weapon_upgrade_shine:set_visible(false)
      runtime_hud.growth_weapon_upgrade_shine:set_alpha(0)
    end
    if is_ui_alive(runtime_hud.growth_weapon_upgrade_bonus_label) then
      runtime_hud.growth_weapon_upgrade_bonus_label:set_visible(false)
      runtime_hud.growth_weapon_upgrade_bonus_label:set_alpha(0)
    end
  end

  local function ensure_growth_weapon_upgrade_fx(runtime_hud)
    if not runtime_hud then
      return nil
    end

    bind_growth_weapon_slot(runtime_hud)
    local host = runtime_hud.growth_weapon_slot
    if not is_ui_alive(host) then
      host = runtime_hud.growth_weapon_tip_anchor
    end
    if not is_ui_alive(host) then
      return nil
    end

    if runtime_hud.growth_weapon_upgrade_fx_host ~= host then
      safe_remove_ui(runtime_hud.growth_weapon_upgrade_flash)
      safe_remove_ui(runtime_hud.growth_weapon_upgrade_label)
      safe_remove_ui(runtime_hud.growth_weapon_upgrade_shine)
      safe_remove_ui(runtime_hud.growth_weapon_upgrade_bonus_label)
      runtime_hud.growth_weapon_upgrade_flash = nil
      runtime_hud.growth_weapon_upgrade_label = nil
      runtime_hud.growth_weapon_upgrade_shine = nil
      runtime_hud.growth_weapon_upgrade_bonus_label = nil
      runtime_hud.growth_weapon_upgrade_fx_host = host
    end

    local width = math.max(1, math.floor(((host.get_width and host:get_width()) or 64) + 0.5))
    local height = math.max(1, math.floor(((host.get_height and host:get_height()) or 64) + 0.5))

    if not is_ui_alive(runtime_hud.growth_weapon_upgrade_flash) then
      local flash = try_create_child_ui(host, '图片')
      if flash then
        flash:set_ui_size(width + 18, height + 18)
        flash:set_pos(width * 0.5, height * 0.5)
        flash:set_anchor(0.5, 0.5)
        flash:set_image(ui_res.common_tip.panel_bg)
        flash:set_image_color(theme.palette.gold[1], theme.palette.gold[2], theme.palette.gold[3], 0)
        flash:set_ui_9_enable(true)
        flash:set_ui_9(
          theme.insets.normal[1],
          theme.insets.normal[2],
          theme.insets.normal[3],
          theme.insets.normal[4]
        )
        flash:set_z_order(9820)
        flash:set_visible(false)
        if flash.set_intercepts_operations then
          flash:set_intercepts_operations(false)
        end
        runtime_hud.growth_weapon_upgrade_flash = flash
      end
    end

    if not is_ui_alive(runtime_hud.growth_weapon_upgrade_label) then
      local label = try_create_child_ui(host, '文本')
      if label then
        label:set_ui_size(width + 28, math.max(24, math.floor(height * 0.72)))
        label:set_pos(width * 0.5, height * 0.5)
        label:set_anchor(0.5, 0.5)
        label:set_font_size(18)
        label:set_text_alignment('中', '中')
        label:set_text_color(theme.palette.gold[1], theme.palette.gold[2], theme.palette.gold[3], 255)
        label:set_z_order(9821)
        label:set_visible(false)
        if label.set_intercepts_operations then
          label:set_intercepts_operations(false)
        end
        runtime_hud.growth_weapon_upgrade_label = label
      end
    end

    if not is_ui_alive(runtime_hud.growth_weapon_upgrade_shine) then
      local shine = try_create_child_ui(host, '图片')
      if shine then
        shine:set_ui_size(math.max(18, math.floor(width * 0.46)), height + 12)
        shine:set_pos(width * 0.5, height * 0.5)
        shine:set_anchor(0.5, 0.5)
        shine:set_image(ui_res.common_tip.panel_bg)
        shine:set_image_color(theme.palette.gold[1], theme.palette.gold[2], theme.palette.gold[3], 0)
        shine:set_ui_9_enable(true)
        shine:set_ui_9(
          theme.insets.normal[1],
          theme.insets.normal[2],
          theme.insets.normal[3],
          theme.insets.normal[4]
        )
        shine:set_z_order(9821)
        shine:set_visible(false)
        if shine.set_intercepts_operations then
          shine:set_intercepts_operations(false)
        end
        runtime_hud.growth_weapon_upgrade_shine = shine
      end
    end

    if not is_ui_alive(runtime_hud.growth_weapon_upgrade_bonus_label) then
      local bonus_label = try_create_child_ui(host, '文本')
      if bonus_label then
        bonus_label:set_ui_size(width + 84, math.max(42, height))
        bonus_label:set_pos(width * 0.5, height * 0.28)
        bonus_label:set_anchor(0.5, 0.5)
        bonus_label:set_font_size(14)
        bonus_label:set_text_alignment('中', '中')
        bonus_label:set_text_color(theme.palette.gold[1], theme.palette.gold[2], theme.palette.gold[3], 255)
        bonus_label:set_z_order(9822)
        bonus_label:set_visible(false)
        if bonus_label.set_intercepts_operations then
          bonus_label:set_intercepts_operations(false)
        end
        runtime_hud.growth_weapon_upgrade_bonus_label = bonus_label
      end
    end

    if is_ui_alive(runtime_hud.growth_weapon_upgrade_flash) then
      runtime_hud.growth_weapon_upgrade_flash:set_ui_size(width + 18, height + 18)
      runtime_hud.growth_weapon_upgrade_flash:set_pos(width * 0.5, height * 0.5)
    end
    if is_ui_alive(runtime_hud.growth_weapon_upgrade_label) then
      runtime_hud.growth_weapon_upgrade_label:set_ui_size(width + 28, math.max(24, math.floor(height * 0.72)))
      runtime_hud.growth_weapon_upgrade_label:set_pos(width * 0.5, height * 0.5)
    end
    if is_ui_alive(runtime_hud.growth_weapon_upgrade_shine) then
      runtime_hud.growth_weapon_upgrade_shine:set_ui_size(math.max(18, math.floor(width * 0.46)), height + 12)
      runtime_hud.growth_weapon_upgrade_shine:set_pos(width * 0.5, height * 0.5)
    end
    if is_ui_alive(runtime_hud.growth_weapon_upgrade_bonus_label) then
      runtime_hud.growth_weapon_upgrade_bonus_label:set_ui_size(width + 84, math.max(42, height))
      runtime_hud.growth_weapon_upgrade_bonus_label:set_pos(width * 0.5, height * 0.28)
    end

    return {
      host = host,
      width = width,
      height = height,
      flash = runtime_hud.growth_weapon_upgrade_flash,
      label = runtime_hud.growth_weapon_upgrade_label,
      shine = runtime_hud.growth_weapon_upgrade_shine,
      bonus_label = runtime_hud.growth_weapon_upgrade_bonus_label,
    }
  end

  local function play_growth_weapon_upgrade_fx(runtime_hud, next_level)
    if not is_runtime_ui_animation_enabled() then
      clear_growth_weapon_upgrade_fx(runtime_hud)
      return
    end
    local fx = ensure_growth_weapon_upgrade_fx(runtime_hud)
    if not fx then
      return
    end

    clear_growth_weapon_upgrade_fx(runtime_hud)

    if is_ui_alive(fx.flash) then
      fx.flash:set_visible(true)
      fx.flash:set_alpha(245)
      fx.flash:set_anim_scale(0.82, 0.82, 1.42, 1.42, 0.28, 0)
      fx.flash:set_anim_opacity(245, 0, 0.28, 0)
    end

    if is_ui_alive(fx.label) then
      fx.label:set_visible(true)
      fx.label:set_text(string.format('Lv.%d', math.max(1, math.floor(tonumber(next_level) or 1))))
      fx.label:set_alpha(255)
      fx.label:set_pos(fx.width * 0.5, fx.height * 0.42)
      fx.label:set_anim_pos(fx.width * 0.5, fx.height * 0.42, fx.width * 0.5, fx.height * 0.78, 0.42, 0)
      fx.label:set_anim_opacity(255, 0, 0.42, 0)
    end

    if is_ui_alive(fx.shine) then
      fx.shine:set_visible(true)
      fx.shine:set_alpha(188)
      fx.shine:set_pos(-math.floor(fx.width * 0.18), fx.height * 0.5)
      fx.shine:set_anim_pos(-math.floor(fx.width * 0.18), fx.height * 0.5, math.floor(fx.width * 1.18), fx.height * 0.5, 0.22, 0)
      fx.shine:set_anim_opacity(188, 0, 0.22, 0)
    end

    if is_ui_alive(fx.bonus_label) then
      fx.bonus_label:set_visible(true)
      fx.bonus_label:set_text(format_growth_weapon_upgrade_bonus_text(next_level))
      fx.bonus_label:set_alpha(255)
      fx.bonus_label:set_pos(fx.width * 0.5, fx.height * 0.24)
      fx.bonus_label:set_anim_pos(fx.width * 0.5, fx.height * 0.24, fx.width * 0.5, -math.floor(fx.height * 0.12), 0.45, 0)
      fx.bonus_label:set_anim_opacity(255, 0, 0.45, 0)
    end

    if is_ui_alive(fx.host) and fx.host.set_anim_scale then
      fx.host:set_anim_scale(1.0, 1.0, 1.12, 1.12, 0.10, 0)
      runtime_hud.growth_weapon_upgrade_scale_reset_timer = y3.ltimer.wait(0.10, function()
        if is_ui_alive(fx.host) and fx.host.set_anim_scale then
          fx.host:set_anim_scale(1.12, 1.12, 1.0, 1.0, 0.16, 0)
        end
        runtime_hud.growth_weapon_upgrade_scale_reset_timer = nil
      end)
    end

    runtime_hud.growth_weapon_upgrade_fx_timer = y3.ltimer.wait(0.46, function()
      if is_ui_alive(fx.flash) then
        fx.flash:set_visible(false)
        fx.flash:set_alpha(0)
      end
      if is_ui_alive(fx.label) then
        fx.label:set_visible(false)
        fx.label:set_alpha(0)
      end
      if is_ui_alive(fx.shine) then
        fx.shine:set_visible(false)
        fx.shine:set_alpha(0)
      end
      if is_ui_alive(fx.bonus_label) then
        fx.bonus_label:set_visible(false)
        fx.bonus_label:set_alpha(0)
      end
      runtime_hud.growth_weapon_upgrade_fx_timer = nil
    end)
  end

  local function bind_editor_overlay_nodes(runtime_hud)
    if not runtime_hud then
      return
    end
    local player = env.get_player()

    runtime_hud.editor_top_panel = UIRoot.get_top_sheet(y3, player)
    runtime_hud.editor_top_root = UIRoot.get_top_root(y3, player)
    runtime_hud.editor_top_bg_root = resolve_first_ui(y3, player, {
      'top.top.layout_2.bg',
      'top.layout_2.bg',
    })
    runtime_hud.editor_top_gold_value = resolve_first_ui(y3, player, {
      'top.top.layout_2.金币.image_3.label_2',
      'top.layout_2.金币.image_3.label_2',
      'top.top.金币.image_3.label_2',
    })
    runtime_hud.editor_top_wood_value = resolve_first_ui(y3, player, {
      'top.top.layout_2.木材.image_3.label_2',
      'top.layout_2.木材.image_3.label_2',
      'top.top.木材.image_3.label_2',
    })
    runtime_hud.editor_top_kill_value = resolve_first_ui(y3, player, {
      'top.top.layout_2.杀敌数.image_3.label_2',
      'top.layout_2.杀敌数.image_3.label_2',
      'top.top.人口.image_3.label_2',
    })
    runtime_hud.editor_top_wave_value = resolve_first_ui(y3, player, {
      'top.top.layout_2.bg.第X波',
      'top.layout_2.bg.第X波',
    })
    runtime_hud.editor_top_stage_value = resolve_first_ui(y3, player, {
      'top.top.layout_2.bg.关卡',
      'top.layout_2.bg.关卡',
    })
    runtime_hud.editor_top_game_time_value = resolve_first_ui(y3, player, {
      'top.top.layout_2.bg.游戏时长',
      'top.layout_2.bg.游戏时长',
    })
    runtime_hud.editor_top_boss_value = resolve_first_ui(y3, player, {
      'top.top.layout_2.bg.boss',
      'top.layout_2.bg.boss',
    })
    runtime_hud.editor_top_boss_countdown_value = resolve_first_ui(y3, player, {
      'top.top.layout_2.bg.BOSS倒计时',
      'top.layout_2.bg.BOSS倒计时',
      'top.top.layout_2.bg.boss_daojishi',
      'top.layout_2.bg.boss_daojishi',
    })
    runtime_hud.legacy_game_hud_inventory = resolve_ui(y3, player, 'GameHUD.main.inventory')
    runtime_hud.legacy_game_hud_skill_list = resolve_ui(y3, player, 'GameHUD.main.skill_list')

    attach_bottom_bg_prefab(runtime_hud)

    runtime_hud.editor_bottom_panel = UIRoot.get_bottom_sheet(y3, player)
    runtime_hud.editor_bottom_root = runtime_hud.bottom_bg_root
    runtime_hud.editor_bottom_layout = runtime_hud.bottom_bg_root
    runtime_hud.editor_bottom_hp_bar = runtime_hud.bottom_hp_fill
    runtime_hud.editor_bottom_hp_value = runtime_hud.bottom_hp_text
    runtime_hud.editor_bottom_hp_recover = nil
    runtime_hud.editor_bottom_exp_bar = runtime_hud.bottom_exp_fill
    runtime_hud.editor_bottom_attack_text = runtime_hud.bottom_attack_value
    runtime_hud.editor_bottom_armor_text = runtime_hud.bottom_armor_value
    runtime_hud.editor_bottom_strength_text = runtime_hud.bottom_strength_value
    runtime_hud.editor_bottom_agility_text = runtime_hud.bottom_agility_value
    runtime_hud.editor_bottom_intelligence_text = runtime_hud.bottom_intelligence_value
    runtime_hud.editor_bottom_inventory_anchors = runtime_hud.bottom_backpack_slots or {}
    runtime_hud.editor_bottom_inventory_slots = runtime_hud.editor_bottom_inventory_slots or {}
    ensure_bottom_skill_slots(runtime_hud)
    runtime_hud.editor_bottom_bond_slots = runtime_hud.editor_bottom_bond_slots or {}
    runtime_hud.editor_bottom_bond_slot_bound = runtime_hud.editor_bottom_bond_slot_bound or {}
    runtime_hud.editor_bottom_bond_payloads = runtime_hud.editor_bottom_bond_payloads or {}
    runtime_hud.legacy_bottom_nodes = {}

    hide_legacy_bottom_panels(runtime_hud)
    bind_bottom_bond_icons(runtime_hud)
    bind_bottom_bg_actions(runtime_hud)

    set_visible_if_alive(runtime_hud.bottom_bg_backpack, false)
  end

  local function has_editor_top(runtime_hud)
    return is_ui_alive(runtime_hud and runtime_hud.editor_top_root)
      or is_ui_alive(runtime_hud and runtime_hud.editor_top_panel)
  end

  local function has_editor_bottom(runtime_hud)
    return is_ui_alive(runtime_hud and runtime_hud.editor_bottom_root)
      or is_ui_alive(runtime_hud and runtime_hud.editor_bottom_panel)
  end

  local function has_editor_bottom_bond_icons(runtime_hud)
    if not runtime_hud or not runtime_hud.editor_bottom_bond_slots then
      return false
    end
    for slot = 1, bottom_bond_slot_count do
      if is_ui_alive(get_bottom_slot_anchor(runtime_hud.editor_bottom_bond_slots[slot])) then
        return true
      end
    end
    return false
  end

  local function sync_editor_inventory_slots(runtime_hud)
    if not runtime_hud then
      return runtime_hud
    end

    runtime_hud.editor_bottom_inventory_anchors = runtime_hud.bottom_backpack_slots or {}
    runtime_hud.editor_bottom_inventory_slots = runtime_hud.editor_bottom_inventory_slots or {}

    for slot = 1, 6 do
      local slot_ui = runtime_hud.editor_bottom_inventory_anchors[slot]
      if not is_ui_alive(slot_ui) then
        slot_ui = resolve_inventory_slot_ui(slot)
      end
      runtime_hud.editor_bottom_inventory_slots[slot] = slot_ui

      if is_ui_alive(slot_ui) and STATE.hero and STATE.hero.is_exist and STATE.hero:is_exist() then
        call_ui_method_safely(slot_ui, 'set_ui_unit_slot', STATE.hero, y3.const.SlotType.BAR, slot - 1)
        if slot == 1 then
          call_ui_method_safely(slot_ui, 'set_equip_slot_use_operation', '无')
          call_ui_method_safely(slot_ui, 'set_equip_slot_drag_operation', '无')
        end
      end
    end

    bind_growth_weapon_slot(runtime_hud)
    bind_default_item_slot_hover(runtime_hud)
    return runtime_hud
  end

  local function refresh_editor_overlay(runtime_hud)
    if not runtime_hud then
      return
    end
    bind_editor_overlay_nodes(runtime_hud)

    local wave_text = get_wave_title_text()
    local stage_text = get_stage_text()
    local game_time_text = format_editor_top_game_time_text(format_time(STATE.runtime_elapsed or 0))
    local boss_display = get_boss_display()
    local boss_text = format_editor_top_boss_text(boss_display.name, boss_display.state)
    local boss_countdown_text = format_editor_top_wave_time_text(boss_display.state)

    set_text_if_alive(runtime_hud.editor_top_gold_value, format_compact(STATE.resources and STATE.resources.gold or 0))
    set_text_if_alive(runtime_hud.editor_top_wood_value, format_compact(STATE.resources and STATE.resources.wood or 0))
    set_text_if_alive(runtime_hud.editor_top_kill_value, format_compact(STATE.total_kills or 0))
    set_text_if_alive(runtime_hud.editor_top_wave_value, wave_text)
    set_text_if_alive(runtime_hud.editor_top_stage_value, stage_text)
    set_text_if_alive(
      runtime_hud.editor_top_game_time_value,
      game_time_text
    )
    set_text_if_alive(
      runtime_hud.editor_top_boss_value,
      boss_text
    )
    set_text_if_alive(
      runtime_hud.editor_top_boss_countdown_value,
      boss_countdown_text
    )
    update_top_center_fx(runtime_hud, wave_text, stage_text, boss_display)

    local current_hp = 0
    if STATE.hero and STATE.hero.is_exist and STATE.hero:is_exist() then
      current_hp = y3.helper.tonumber(STATE.hero:get_hp()) or 0
    end
    local hero_name = STATE.hero and STATE.hero.get_name and STATE.hero:get_name() or '英雄'
    local hero_level = env.get_hero_level and env.get_hero_level() or ((STATE.hero_progress and STATE.hero_progress.level) or 1)
    set_image_if_alive(runtime_hud.bottom_portrait, STATE.hero and STATE.hero.get_icon and STATE.hero:get_icon() or nil, { 255, 255, 255, 255 })
    set_optional_text(runtime_hud.bottom_name, hero_name)
    set_optional_text(runtime_hud.bottom_level, tostring(math.max(1, math.floor(hero_level or 1))))

    local max_hp = math.max(1, get_hero_attr('生命结算值', '生命'))
    set_progress_if_alive(runtime_hud.editor_bottom_hp_bar, current_hp, max_hp)
    set_text_if_alive(
      runtime_hud.editor_bottom_hp_value,
      string.format('%s/%s', format_compact(current_hp), format_compact(max_hp))
    )
    set_text_if_alive(runtime_hud.editor_bottom_hp_recover, '+' .. format_compact(get_hero_attr('生命恢复')))

    local progress = STATE.hero_progress or {}
    local exp_current = progress.exp or 0
    local exp_max = progress.exp_to_next or 0
    if exp_max <= 0 then
      exp_max = math.max(1, exp_current)
    end
    set_progress_if_alive(runtime_hud.editor_bottom_exp_bar, exp_current, exp_max)
    set_optional_text(
      runtime_hud.bottom_exp_text,
      string.format('%s/%s', format_compact(exp_current), format_compact(exp_max))
    )

    set_text_if_alive(runtime_hud.editor_bottom_attack_text, format_compact(get_hero_attr('攻击结算值', '攻击')))
    set_text_if_alive(runtime_hud.editor_bottom_armor_text, format_compact(get_hero_attr('护甲结算值', '护甲')))
    set_text_if_alive(runtime_hud.editor_bottom_strength_text, format_compact(get_hero_attr('最终力量', '力量')))
    set_text_if_alive(runtime_hud.editor_bottom_agility_text, format_compact(get_hero_attr('最终敏捷', '敏捷')))
    set_text_if_alive(runtime_hud.editor_bottom_intelligence_text, format_compact(get_hero_attr('最终智力', '智力')))

    set_optional_text(runtime_hud.bottom_attack_percent, '攻击力')
    set_optional_text(runtime_hud.bottom_attack_percent_bonus, format_percent_bonus_text(
      get_hero_attr('攻击增幅'),
      get_hero_attr('最终攻击')
    ))
    set_optional_text(runtime_hud.bottom_attack_value_bonus, format_signed_compact(get_hero_attr('攻击绿字')))

    set_optional_text(runtime_hud.bottom_strength_percent, '力量')
    set_optional_text(runtime_hud.bottom_strength_percent_bonus, format_percent_bonus_text(
      get_hero_attr('力量增幅'),
      get_hero_attr('最终力量增幅')
    ))
    set_optional_text(runtime_hud.bottom_strength_value_bonus, format_signed_compact(get_hero_attr('力量绿字')))

    set_optional_text(runtime_hud.bottom_agility_percent, '敏捷')
    set_optional_text(runtime_hud.bottom_agility_percent_bonus, format_percent_bonus_text(
      get_hero_attr('敏捷增幅'),
      get_hero_attr('最终敏捷增幅')
    ))
    set_optional_text(runtime_hud.bottom_agility_value_bonus, format_signed_compact(get_hero_attr('敏捷绿字')))

    set_optional_text(runtime_hud.bottom_intelligence_percent, '智力')
    set_optional_text(runtime_hud.bottom_intelligence_percent_bonus, format_percent_bonus_text(
      get_hero_attr('智力增幅'),
      get_hero_attr('最终智力增幅')
    ))
    set_optional_text(runtime_hud.bottom_intelligence_value_bonus, format_signed_compact(get_hero_attr('智力绿字')))

    set_optional_text(runtime_hud.bottom_armor_percent, '护甲值')
    set_optional_text(runtime_hud.bottom_armor_percent_bonus, format_percent_bonus_text(
      get_hero_attr('护甲增幅'),
      get_hero_attr('最终护甲')
    ))
    set_optional_text(runtime_hud.bottom_armor_value_bonus, format_signed_compact(get_hero_attr('护甲绿字')))

    if is_ui_alive(runtime_hud.bottom_compact_stats_root) then
      set_text_if_alive(
        runtime_hud.bottom_attack_value,
        format_compact_breakdown_text(
          get_hero_attr('攻击结算值', '攻击'),
          get_hero_attr('攻击增幅'),
          get_hero_attr('最终攻击'),
          get_hero_attr('攻击绿字')
        )
      )
      set_text_if_alive(
        runtime_hud.bottom_strength_value,
        format_compact_breakdown_text(
          get_hero_attr('最终力量', '力量'),
          get_hero_attr('力量增幅'),
          get_hero_attr('最终力量增幅'),
          get_hero_attr('力量绿字')
        )
      )
      set_text_if_alive(
        runtime_hud.bottom_agility_value,
        format_compact_breakdown_text(
          get_hero_attr('最终敏捷', '敏捷'),
          get_hero_attr('敏捷增幅'),
          get_hero_attr('最终敏捷增幅'),
          get_hero_attr('敏捷绿字')
        )
      )
      set_text_if_alive(
        runtime_hud.bottom_intelligence_value,
        format_compact_breakdown_text(
          get_hero_attr('最终智力', '智力'),
          get_hero_attr('智力增幅'),
          get_hero_attr('最终智力增幅'),
          get_hero_attr('智力绿字')
        )
      )
      set_text_if_alive(
        runtime_hud.bottom_armor_value,
        format_compact_breakdown_text(
          get_hero_attr('护甲结算值', '护甲'),
          get_hero_attr('护甲增幅'),
          get_hero_attr('最终护甲'),
          get_hero_attr('护甲绿字')
        )
      )
    end

    sync_editor_inventory_slots(runtime_hud)
    update_growth_weapon_ready_fx(runtime_hud)
  end

  local function apply_runtime_hud_visibility(runtime_hud, visible)
    if not runtime_hud then
      return
    end
    bind_editor_overlay_nodes(runtime_hud)
    hide_legacy_bottom_panels(runtime_hud)

    local show = visible == true
    local use_editor_top = has_editor_top(runtime_hud)
    local use_editor_bottom = has_editor_bottom(runtime_hud)

    set_visible_if_alive(runtime_hud.center_root, show and not use_editor_top)
    set_visible_if_alive(runtime_hud.left_root, show and not use_editor_top)
    set_visible_if_alive(runtime_hud.editor_top_panel, show)
    set_visible_if_alive(runtime_hud.editor_top_root, show)
    set_visible_if_alive(runtime_hud.editor_bottom_panel, show)
    set_visible_if_alive(runtime_hud.editor_bottom_root, show)
    set_visible_if_alive(runtime_hud.editor_bottom_layout, show)
    set_visible_if_alive(runtime_hud.bottom_bg_backpack, false)
    set_visible_if_alive(runtime_hud.bond_slot_bar, show and (not use_editor_bottom or not has_editor_bottom_bond_icons(runtime_hud)))
    if not show then
      clear_top_center_fx(runtime_hud)
      clear_growth_weapon_slot_fx(runtime_hud)
      clear_growth_weapon_upgrade_fx(runtime_hud)
      return
    end
    start_top_center_breath_fx(runtime_hud)
    update_growth_weapon_ready_fx(runtime_hud)
  end

  -- local function bind_default_item_slot_hover(runtime_hud)
  bind_default_item_slot_hover = function(runtime_hud)
    if not runtime_hud then
      return runtime_hud
    end

    runtime_hud.editor_bottom_inventory_anchors = runtime_hud.bottom_backpack_slots or {}
    runtime_hud.editor_bottom_inventory_slots = runtime_hud.editor_bottom_inventory_slots or {}

    local anchor_ui = runtime_hud.editor_bottom_inventory_slots and runtime_hud.editor_bottom_inventory_slots[1] or nil
    if not is_ui_alive(anchor_ui) then
      anchor_ui = runtime_hud.editor_bottom_inventory_anchors[1] or nil
    end
    if not is_ui_alive(anchor_ui) then
      return runtime_hud
    end

    runtime_hud.bound_inventory_targets = runtime_hud.bound_inventory_targets or {}
    if runtime_hud.bound_inventory_targets.growth_weapon == anchor_ui then
      return runtime_hud
    end
    runtime_hud.bound_inventory_targets.growth_weapon = anchor_ui

    if anchor_ui.set_intercepts_operations then
      anchor_ui:set_intercepts_operations(true)
    end

    anchor_ui:add_fast_event('鼠标-移入', function()
      local item = get_hero_bar_item(1)
      if is_growth_weapon_item(item) then
        runtime_hud.growth_weapon_tip_anchor = anchor_ui
        set_growth_weapon_slot_hover_fx(runtime_hud, true)
        show_growth_weapon_tip(anchor_ui)
      else
        set_growth_weapon_slot_hover_fx(runtime_hud, false)
        hide_growth_weapon_tip()
      end
    end)
    anchor_ui:add_fast_event('鼠标-移出', function()
      set_growth_weapon_slot_hover_fx(runtime_hud, false)
      hide_growth_weapon_tip()
    end)
    anchor_ui:add_fast_event('左键-点击', function()
      set_growth_weapon_slot_hover_fx(runtime_hud, false)
      hide_growth_weapon_tip()
      if is_growth_weapon_item(get_hero_bar_item(1)) and env.try_upgrade_growth_weapon then
        env.try_upgrade_growth_weapon('hud_click')
      end
    end)
    return runtime_hud
  end

  local function show_latest_bond_tip(anchor_ui)
    if not anchor_ui or not env.build_latest_bond_tip_payload then
      hide_bond_tip()
      return
    end
    local payload = env.build_latest_bond_tip_payload()
    if not payload then
      hide_bond_tip()
      return
    end
    bond_tip_panel.show_for_anchor(anchor_ui, payload)
  end

  local function get_bond_slot_frame_color(quality)
    return BOND_SLOT_QUALITY_COLORS[quality or 'common'] or BOND_SLOT_QUALITY_COLORS.common
  end

  local function hide_legacy_decision_panel(runtime_hud)
    if runtime_hud and runtime_hud.decision_root then
      runtime_hud.decision_root:set_visible(false)
    end
  end

  refresh_runtime_hud = function()
    local runtime_hud = STATE.runtime_hud
    if not is_hud_alive(runtime_hud) then
      return
    end

    bind_editor_overlay_nodes(runtime_hud)
    hide_legacy_bottom_panels(runtime_hud)

    if runtime_hud.gold_value then
      runtime_hud.gold_value:set_text(format_compact(STATE.resources and STATE.resources.gold or 0))
    end
    if runtime_hud.wood_value then
      runtime_hud.wood_value:set_text(format_compact(STATE.resources and STATE.resources.wood or 0))
    end
    if runtime_hud.skill_value then
      runtime_hud.skill_value:set_text(format_compact(STATE.total_kills or 0))
    end
    if runtime_hud.challenge_value then
      runtime_hud.challenge_value:set_text(string.format('%d/%d', get_total_challenge_charge_count(), get_total_challenge_charge_max()))
    end

    refresh_editor_overlay(runtime_hud)

    runtime_hud.editor_bottom_bond_payloads = runtime_hud.editor_bottom_bond_payloads or {}
    for slot = 1, bottom_bond_slot_count do
      local payload = env.build_bond_slot_tip_payload and env.build_bond_slot_tip_payload(slot) or nil
      runtime_hud.editor_bottom_bond_payloads[slot] = payload
      render_bottom_bond_slot(runtime_hud.editor_bottom_bond_slots and runtime_hud.editor_bottom_bond_slots[slot] or nil, slot, payload)

      local slot_ui = runtime_hud.bond_slot_icons and runtime_hud.bond_slot_icons[slot] or nil
      if slot_ui then
        slot_ui.payload = payload
        slot_ui.count:set_text(tostring(slot))
        slot_ui.count:set_visible(true)
        if payload then
          local color = get_bond_slot_frame_color(payload.quality)
          slot_ui.shadow:set_visible(true)
          slot_ui.frame:set_visible(true)
          slot_ui.icon:set_visible(true)
          slot_ui.frame:set_image_color(color[1], color[2], color[3], color[4])
          slot_ui.icon:set_image(payload.icon_res or ui_res.common.empty)
          slot_ui.icon:set_image_color(255, 255, 255, 255)
          slot_ui.count:set_text_color(236, 242, 250, 255)
        else
          slot_ui.shadow:set_visible(false)
          slot_ui.frame:set_visible(true)
          slot_ui.icon:set_visible(true)
          slot_ui.frame:set_image_color(54, 72, 98, 196)
          slot_ui.icon:set_image(ui_res.common.empty)
          slot_ui.icon:set_image_color(72, 88, 112, 220)
          slot_ui.count:set_text_color(132, 148, 174, 255)
        end
      end
    end

    for slot = 1, attack_skill_slot_count do
      local skill = STATE.attack_skill_state and STATE.attack_skill_state.slots and STATE.attack_skill_state.slots[slot] or nil
      render_bottom_attack_skill_slot(runtime_hud.skill_slots and runtime_hud.skill_slots[slot] or nil, slot, skill)
    end

    hide_legacy_decision_panel(runtime_hud)
  end

  local function create_runtime_hud()
    local hud = get_hud_root()
    if not hud then
      return nil
    end

    if is_hud_alive(STATE.runtime_hud) then
      refresh_runtime_hud()
      return STATE.runtime_hud
    end

    local hud_width, hud_height = get_hud_metrics(hud, y3)
    local scale = get_hud_scale(hud, y3)

    local center_root = create_panel(
      hud,
      0,
      0,
      scaled(layout.top_bar.width, scale),
      scaled(layout.top_bar.height, scale),
      { 9, 16, 27, 192 },
      { 30, 30, 24, 24 },
      9400,
      runtime_skin.top_bar
    )
    center_root:set_anchor(0.5, 1)
    center_root:set_relative_parent_pos('顶部', scaled(layout.top_bar.top, scale))
    set_percent_pos(env.get_player(), center_root, 43.5, 100)
    center_root:set_visible(false)

    local center_glow = create_panel(
      center_root,
      scaled(layout.top_glow.x, scale),
      scaled(layout.top_glow.y, scale),
      scaled(layout.top_glow.width, scale),
      scaled(layout.top_glow.height, scale),
      { 56, 112, 184, 54 },
      { 8, 8, 8, 8 },
      9401
    )
    center_glow:set_anchor(0.5, 0.5)

    local stage_panel = create_panel(
      center_root,
      scaled(94, scale),
      scaled(58, scale),
      scaled(170, scale),
      scaled(34, scale),
      theme.palette.panel_alt,
      theme.insets.normal,
      9401
    )
    local stage_text = create_text(
      stage_panel,
      scaled(85, scale),
      scaled(17, scale),
      scaled(150, scale),
      scaled(18, scale),
      scaled(13, scale),
      theme.palette.text,
      '中',
      '中',
      9402
    )

    local wave_panel = create_panel(
      center_root,
      scaled(532, scale),
      scaled(56, scale),
      scaled(232, scale),
      scaled(38, scale),
      theme.palette.accent,
      theme.insets.normal,
      9401
    )
    local wave_title = create_text(
      wave_panel,
      scaled(116, scale),
      scaled(20, scale),
      scaled(216, scale),
      scaled(22, scale),
      scaled(22, scale),
      theme.palette.text,
      '中',
      '中',
      9402
    )
    local wave_status = create_text(
      center_root,
      scaled(532, scale),
      scaled(24, scale),
      scaled(286, scale),
      scaled(16, scale),
      scaled(12, scale),
      theme.palette.text_soft,
      '中',
      '中',
      9402
    )

    local boss_panel = create_panel(
      center_root,
      scaled(918, scale),
      scaled(56, scale),
      scaled(222, scale),
      scaled(34, scale),
      theme.palette.warning,
      theme.insets.normal,
      9401
    )
    local boss_name = create_text(
      boss_panel,
      scaled(62, scale),
      scaled(18, scale),
      scaled(100, scale),
      scaled(16, scale),
      scaled(12, scale),
      theme.palette.text,
      '左',
      '中',
      9402
    )
    local boss_state = create_text(
      boss_panel,
      scaled(158, scale),
      scaled(18, scale),
      scaled(118, scale),
      scaled(16, scale),
      scaled(12, scale),
      theme.palette.text,
      '右',
      '中',
      9402
    )

    local timer_text = create_text(
      center_root,
      scaled(532, scale),
      scaled(80, scale),
      scaled(280, scale),
      scaled(14, scale),
      scaled(12, scale),
      theme.palette.text_soft,
      '中',
      '中',
      9402
    )
    local gold_icon = create_panel(
      center_root,
      scaled(24, scale),
      scaled(44, scale),
      scaled(20, scale),
      scaled(20, scale),
      { 255, 226, 150, 255 },
      theme.insets.soft,
      9403,
      runtime_skin.top_bar_icon
    )
    gold_icon:set_anchor(0.5, 0.5)
    local wood_icon = create_panel(
      center_root,
      scaled(170, scale),
      scaled(44, scale),
      scaled(20, scale),
      scaled(20, scale),
      { 198, 244, 188, 255 },
      theme.insets.soft,
      9403,
      runtime_skin.top_bar_icon
    )
    wood_icon:set_anchor(0.5, 0.5)
    local skill_icon = create_panel(
      center_root,
      scaled(724, scale),
      scaled(44, scale),
      scaled(18, scale),
      scaled(18, scale),
      { 212, 228, 255, 255 },
      theme.insets.soft,
      9403,
      runtime_skin.top_bar_icon
    )
    skill_icon:set_anchor(0.5, 0.5)
    local challenge_icon = create_panel(
      center_root,
      scaled(852, scale),
      scaled(44, scale),
      scaled(18, scale),
      scaled(18, scale),
      { 255, 216, 176, 255 },
      theme.insets.soft,
      9403,
      runtime_skin.top_bar_icon
    )
    challenge_icon:set_anchor(0.5, 0.5)

    local _, gold_value = create_stat_text(
      center_root,
      scaled(40, scale),
      scaled(38, scale),
      scaled(86, scale),
      '金币',
      '0',
      { 194, 176, 112, 255 },
      theme.palette.gold,
      '左',
      scale
    )
    local _, wood_value = create_stat_text(
      center_root,
      scaled(186, scale),
      scaled(38, scale),
      scaled(86, scale),
      '木材',
      '0',
      { 158, 194, 160, 255 },
      theme.palette.wood,
      '左',
      scale
    )
    local _, skill_value = create_stat_text(
      center_root,
      scaled(742, scale),
      scaled(38, scale),
      scaled(90, scale),
      '杀敌数',
      '0',
      theme.palette.text_muted,
      theme.palette.text,
      '左',
      scale
    )
    local _, challenge_value = create_stat_text(
      center_root,
      scaled(872, scale),
      scaled(38, scale),
      scaled(100, scale),
      '挑战',
      '0/0',
      { 210, 178, 132, 255 },
      { 255, 236, 212, 255 },
      '左',
      scale
    )

    local left_root = create_panel(
      hud,
      0,
      0,
      scaled(layout.left_bar.width, scale),
      scaled(layout.left_bar.height, scale),
      { 10, 18, 28, 174 },
      theme.insets.soft,
      9400,
      runtime_skin.left_bar
    )
    left_root:set_anchor(0.5, 1)
    left_root:set_relative_parent_pos('顶部', scaled(layout.left_bar.top, scale))
    set_percent_pos(env.get_player(), left_root, 43.5, 100)
    left_root:set_visible(false)

    local challenge_summary_text = create_text(
      left_root,
      scaled(406, scale),
      scaled(18, scale),
      scaled(248, scale),
      scaled(14, scale),
      scaled(11, scale),
      theme.palette.text_soft,
      '中',
      '中',
      9402
    )
    local hero_progress_text = create_text(
      left_root,
      scaled(86, scale),
      scaled(18, scale),
      scaled(210, scale),
      scaled(14, scale),
      scaled(12, scale),
      theme.palette.text,
      '左',
      '中',
      9402
    )
    local hero_hp_text = create_text(
      left_root,
      scaled(748, scale),
      scaled(18, scale),
      scaled(138, scale),
      scaled(14, scale),
      scaled(12, scale),
      theme.palette.text,
      '右',
      '中',
      9402
    )
    local hero_status_text = create_text(
      left_root,
      scaled(612, scale),
      scaled(18, scale),
      scaled(158, scale),
      scaled(14, scale),
      scaled(12, scale),
      theme.palette.text_muted,
      '右',
      '中',
      9402
    )

    local decision_root = create_panel(
      hud,
      0,
      0,
      scaled(layout.decision_panel.width, scale),
      scaled(layout.decision_panel.height, scale),
      { 8, 14, 24, 216 },
      { 24, 24, 24, 24 },
      9440,
      runtime_skin.decision_root
    )
    decision_root:set_anchor(0.5, 0.5)
    set_percent_pos(env.get_player(), decision_root, 50, layout.decision_panel.percent_y)
    local decision_header_line = create_panel(
      decision_root,
      scaled(520, scale),
      scaled(198, scale),
      scaled(944, scale),
      scaled(8, scale),
      { 54, 104, 168, 72 },
      { 8, 8, 8, 8 },
      9441,
      runtime_skin.decision_header_line
    )
    decision_header_line:set_anchor(0.5, 0.5)
    local decision_caption = create_styled_text(
      decision_root,
      scaled(90, scale),
      scaled(212, scale),
      scaled(140, scale),
      scaled(18, scale),
      'runtime_hud.decision.caption',
      '当前抉择',
      9442
    )

    local decision_logo = create_panel(
      decision_root,
      scaled(48, scale),
      scaled(212, scale),
      scaled(28, scale),
      scaled(28, scale),
      { 196, 222, 255, 255 },
      theme.insets.soft,
      9442,
      runtime_skin.decision_logo
    )
    decision_logo:set_anchor(0.5, 0.5)
    local decision_title = create_styled_text(
      decision_root,
      scaled(520, scale),
      scaled(212, scale),
      scaled(820, scale),
      scaled(24, scale),
      'runtime_hud.decision.title',
      '',
      9442
    )
    local decision_subtitle = create_styled_text(
      decision_root,
      scaled(520, scale),
      scaled(184, scale),
      scaled(860, scale),
      scaled(18, scale),
      'runtime_hud.decision.subtitle',
      '',
      9442
    )
    local decision_hint = create_styled_text(
      decision_root,
      scaled(520, scale),
      scaled(22, scale),
      scaled(860, scale),
      scaled(16, scale),
      'runtime_hud.decision.hint',
      '',
      9442
    )
    local decision_options = {
      create_decision_option(
        decision_root,
        scaled(layout.decision_panel.option_x[1], scale),
        scaled(layout.decision_panel.option_y, scale),
        scaled(layout.decision_panel.option_width, scale),
        scaled(layout.decision_panel.option_height, scale),
        1,
        scale
      ),
      create_decision_option(
        decision_root,
        scaled(layout.decision_panel.option_x[2], scale),
        scaled(layout.decision_panel.option_y, scale),
        scaled(layout.decision_panel.option_width, scale),
        scaled(layout.decision_panel.option_height, scale),
        2,
        scale
      ),
      create_decision_option(
        decision_root,
        scaled(layout.decision_panel.option_x[3], scale),
        scaled(layout.decision_panel.option_y, scale),
        scaled(layout.decision_panel.option_width, scale),
        scaled(layout.decision_panel.option_height, scale),
        3,
        scale
      ),
    }
    decision_root:set_visible(false)

    local bond_slot_bar = create_panel(
      hud,
      0,
      0,
      scaled(312, scale),
      scaled(44, scale),
      { 9, 16, 27, 188 },
      theme.insets.normal,
      9400,
      runtime_skin.bottom_bar
    )
    UIStyle.apply_text(wave_title, 'runtime_hud.wave_title', get_wave_title_text())
    bond_slot_bar:set_anchor(0.5, 0)
    bond_slot_bar:set_relative_parent_pos('底部', scaled(194, scale))
    set_percent_pos(env.get_player(), bond_slot_bar, 50, 0)
    bond_slot_bar:set_visible(false)

    local bond_slot_label = create_styled_text(
      bond_slot_bar,
      scaled(18, scale),
      scaled(31, scale),
      scaled(96, scale),
      scaled(12, scale),
      'runtime_hud.bond_slot_label',
      '已结仙缘',
      9402
    )

    local bond_slot_icons = {}

    for slot = 1, 7 do
      local slot_x = scaled(116 + (slot - 1) * 28, scale)
      local shadow = create_panel(
        bond_slot_bar,
        slot_x,
        scaled(20, scale),
        scaled(24, scale),
        scaled(24, scale),
        { 4, 8, 16, 132 },
        theme.insets.soft,
        9401
      )
      shadow:set_anchor(0.5, 0.5)

      local frame = create_panel(
        bond_slot_bar,
        slot_x,
        scaled(22, scale),
        scaled(24, scale),
        scaled(24, scale),
        { 54, 72, 98, 255 },
        theme.insets.soft,
        9402
      )
      frame:set_anchor(0.5, 0.5)
      frame:set_intercepts_operations(true)

      local icon = create_panel(
        bond_slot_bar,
        slot_x,
        scaled(22, scale),
        scaled(20, scale),
        scaled(20, scale),
        { 255, 255, 255, 255 },
        { 4, 4, 4, 4 },
        9403
      )
      icon:set_anchor(0.5, 0.5)
      icon:set_intercepts_operations(false)

      local count = create_text(
        bond_slot_bar,
        slot_x + scaled(8, scale),
        scaled(8, scale),
        scaled(12, scale),
        scaled(10, scale),
        scaled(8, scale),
        { 190, 206, 228, 255 },
        '中',
        '中',
        9404
      )
      count:set_anchor(0.5, 0.5)
      count:set_text(tostring(slot))

      bond_slot_icons[slot] = {
        shadow = shadow,
        frame = frame,
        icon = icon,
        count = count,
        payload = nil,
      }

      frame:add_fast_event('鼠标-移入', function()
        if bond_slot_icons[slot].payload then
          bond_tip_panel.show_for_anchor(frame, bond_slot_icons[slot].payload)
        else
          hide_bond_tip()
        end
      end)
      frame:add_fast_event('鼠标-移出', function()
        hide_bond_tip()
      end)
      frame:add_fast_event('左键-点击', function()
        hide_bond_tip()
      end)
    end

    STATE.runtime_hud = {
      center_root = center_root,
      center_glow = center_glow,
      left_root = left_root,
      stage_text = stage_text,
      wave_title = wave_title,
      wave_status = wave_status,
      boss_panel = boss_panel,
      boss_name = boss_name,
      boss_state = boss_state,
      timer_text = timer_text,
      gold_value = gold_value,
      wood_value = wood_value,
      skill_value = skill_value,
      challenge_value = challenge_value,
      hero_progress_text = hero_progress_text,
      hero_hp_text = hero_hp_text,
      hero_status_text = hero_status_text,
      challenge_summary_text = challenge_summary_text,
      decision_root = decision_root,
      decision_header_line = decision_header_line,
      decision_caption = decision_caption,
      decision_title = decision_title,
      decision_subtitle = decision_subtitle,
      decision_hint = decision_hint,
      decision_options = decision_options,
      bond_slot_bar = bond_slot_bar,
      bond_slot_label = bond_slot_label,
      bond_slot_icons = bond_slot_icons,
      growth_weapon_slot = nil,
      skill_slots = {},
    }

    if is_ui_alive(bond_slot_bar) then
      bond_slot_bar:set_visible(false)
    end

    bind_editor_overlay_nodes(STATE.runtime_hud)
    bind_default_item_slot_hover(STATE.runtime_hud)
    apply_runtime_hud_visibility(STATE.runtime_hud, true)
    refresh_runtime_hud()
    return STATE.runtime_hud
  end

  return {
    ensure_hud = function()
      return create_runtime_hud()
    end,
    refresh_hud = function()
      return refresh_runtime_hud()
    end,
    play_growth_weapon_upgrade_effect = function(next_level)
      local runtime_hud = create_runtime_hud()
      if not is_hud_alive(runtime_hud) then
        return
      end
      bind_editor_overlay_nodes(runtime_hud)
      play_growth_weapon_upgrade_fx(runtime_hud, next_level)
    end,
    set_visible = function(visible)
      local runtime_hud = STATE.runtime_hud
      if not is_hud_alive(runtime_hud) then
        return
      end
      hide_bond_tip()
      hide_growth_weapon_tip()
      apply_runtime_hud_visibility(runtime_hud, visible == true)
      hide_legacy_decision_panel(runtime_hud)
    end,
  }
end

return M
