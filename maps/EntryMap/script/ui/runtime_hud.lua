local ui_res = require 'ui.res'
local skin = require 'ui.skin'
local theme = require 'ui.theme'
local UIStyle = require 'ui.style'
local Factory = require 'ui.factory'
local layout = require 'ui.runtime_hud_layout'
local RuntimeHudNodes = require 'ui.runtime_hud_nodes'
local BondTipPanel = require 'ui.bond_tip_panel'
local GrowthWeaponItemTip = require 'ui.growth_weapon_item_tip'

local M = {}

local BOND_SLOT_QUALITY_COLORS = {
  common = { 68, 162, 88, 255 },
  rare = { 72, 126, 210, 255 },
  epic = { 164, 108, 216, 255 },
  legendary = { 224, 172, 86, 255 },
}

local function resolve_ui(y3, player, path)
  local ok, ui = pcall(y3.ui.get_ui, player, path)
  if not ok or not ui then
    return nil
  end
  return ui
end

local function resolve_first_ui(y3, player, paths)
  for _, path in ipairs(paths or {}) do
    local ui = resolve_ui(y3, player, path)
    if ui then
      return ui
    end
  end
  return nil
end

local function is_ui_alive(ui)
  return ui and (not ui.is_removed or not ui:is_removed())
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
  local create_styled_text = factory.create_styled_text
  local create_button = factory.create_button
  local set_percent_pos = factory.set_percent_pos
  local get_hud_metrics = factory.get_hud_metrics
  local get_hud_scale = factory.get_hud_scale
  local scaled = factory.scaled
  local runtime_skin = skin.images.runtime_hud or {}
  local refresh_runtime_hud

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
    local ok, hud = pcall(y3.ui.get_ui, env.get_player(), 'GameHUD')
    if not ok or not hud then
      return nil
    end
    return hud
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
      return '羁绊抉择'
    end
    if kind == 'mark' then
      return '进化抉择'
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
      return string.format('按 %d 收下此卡', index)
    end
    if kind == 'mark' then
      return string.format('按 %d 选择此进化', index)
    end
    return string.format('按 %d 确认选择', index)
  end

  local function get_decision_notice(kind)
    if kind == 'upgrade' then
      return '成长抉择待确认'
    end
    if kind == 'bond' then
      return '羁绊招募进行中'
    end
    if kind == 'mark' then
      return '进化正在抉择'
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

  local function bind_bottom_bond_icons(runtime_hud)
    if not runtime_hud then
      return
    end
    runtime_hud.editor_bottom_bond_slot_bound = runtime_hud.editor_bottom_bond_slot_bound or {}
    runtime_hud.editor_bottom_bond_payloads = runtime_hud.editor_bottom_bond_payloads or {}
    for slot = 1, 7 do
      local icon_ui = runtime_hud.bottom_bond_icons and runtime_hud.bottom_bond_icons[slot] or nil
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

  local function bind_growth_weapon_slot(runtime_hud)
    if not runtime_hud then
      return
    end

    local slot_ui = runtime_hud.editor_bottom_inventory_slots and runtime_hud.editor_bottom_inventory_slots[1] or nil
    if not slot_ui then
      slot_ui = resolve_first_ui(y3, env.get_player(), {
        'GameHUD.layout_3.inventory.equip_slot_bg_1.equip_slot_1',
        'GameHUD.main.inventory.equip_slot_bg_1.equip_slot_1',
      })
    end
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

  local function bind_editor_overlay_nodes(runtime_hud)
    if not runtime_hud then
      return
    end
    local player = env.get_player()

    runtime_hud.editor_top_panel = resolve_ui(y3, player, 'top')
    runtime_hud.editor_top_root = resolve_first_ui(y3, player, {
      'top.top',
      'top',
    })
    runtime_hud.editor_top_gold_value = resolve_ui(y3, player, 'top.top.金币.image_3.label_2')
    runtime_hud.editor_top_wood_value = resolve_ui(y3, player, 'top.top.木材.image_3.label_2')
    runtime_hud.editor_top_kill_value = resolve_ui(y3, player, 'top.top.人口.image_3.label_2')

    attach_bottom_bg_prefab(runtime_hud)

    runtime_hud.editor_bottom_panel = runtime_hud.bottom_bg_root
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
    runtime_hud.editor_bottom_inventory_slots = runtime_hud.bottom_backpack_slots or {}
    runtime_hud.editor_bottom_bond_slots = runtime_hud.bottom_bond_icons or {}
    runtime_hud.editor_bottom_bond_slot_bound = runtime_hud.editor_bottom_bond_slot_bound or {}
    runtime_hud.editor_bottom_bond_payloads = runtime_hud.editor_bottom_bond_payloads or {}

    runtime_hud.legacy_bottom_nodes = runtime_hud.legacy_bottom_nodes or {
      resolve_ui(y3, player, 'GameHUD.layout_3.main_hp_bar'),
      resolve_ui(y3, player, 'GameHUD.layout_3.hp_value'),
      resolve_ui(y3, player, 'GameHUD.layout_3.hp_recover'),
      resolve_ui(y3, player, 'GameHUD.layout_3.exp'),
      resolve_ui(y3, player, 'GameHUD.layout_3.zuobian'),
      resolve_ui(y3, player, 'GameHUD.layout_3.inventory'),
      resolve_ui(y3, player, 'GameHUD.jiban_list'),
      resolve_ui(y3, player, 'GameHUD.main'),
    }
    for _, legacy_node in ipairs(runtime_hud.legacy_bottom_nodes) do
      set_visible_if_alive(legacy_node, false)
    end

    bind_bottom_bond_icons(runtime_hud)
    bind_bottom_bg_actions(runtime_hud)

    bind_growth_weapon_slot(runtime_hud)
  end

  local function has_editor_top(runtime_hud)
    return is_ui_alive(runtime_hud and runtime_hud.editor_top_root)
      or is_ui_alive(runtime_hud and runtime_hud.editor_top_panel)
  end

  local function has_editor_bottom(runtime_hud)
    return is_ui_alive(runtime_hud and runtime_hud.editor_bottom_root)
      or is_ui_alive(runtime_hud and runtime_hud.editor_bottom_panel)
  end

  local function sync_editor_inventory_slots(runtime_hud)
    if not runtime_hud or not STATE.hero or not STATE.hero.is_exist or not STATE.hero:is_exist() then
      return
    end
    for slot = 1, 6 do
      local slot_ui = runtime_hud.editor_bottom_inventory_slots and runtime_hud.editor_bottom_inventory_slots[slot] or nil
      if is_ui_alive(slot_ui) and slot_ui.set_ui_unit_slot then
        slot_ui:set_ui_unit_slot(STATE.hero, y3.const.SlotType.BAR, slot - 1)
      end
    end
    if is_ui_alive(runtime_hud.growth_weapon_slot) and runtime_hud.growth_weapon_slot.set_ui_unit_slot then
      runtime_hud.growth_weapon_slot:set_ui_unit_slot(STATE.hero, y3.const.SlotType.BAR, 0)
    end
  end

  local function refresh_editor_overlay(runtime_hud)
    if not runtime_hud then
      return
    end
    bind_editor_overlay_nodes(runtime_hud)

    set_text_if_alive(runtime_hud.editor_top_gold_value, format_compact(STATE.resources and STATE.resources.gold or 0))
    set_text_if_alive(runtime_hud.editor_top_wood_value, format_compact(STATE.resources and STATE.resources.wood or 0))
    set_text_if_alive(runtime_hud.editor_top_kill_value, format_compact(STATE.total_kills or 0))

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

    sync_editor_inventory_slots(runtime_hud)
  end

  local function apply_runtime_hud_visibility(runtime_hud, visible)
    if not runtime_hud then
      return
    end
    bind_editor_overlay_nodes(runtime_hud)

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
    set_visible_if_alive(runtime_hud.bond_slot_bar, show and not use_editor_bottom)
  end

  local function bind_default_item_slot_hover(runtime_hud)
    runtime_hud.default_item_slots = runtime_hud.default_item_slots or {}
    runtime_hud.default_item_slot_targets = runtime_hud.default_item_slot_targets or {}
    for slot = 1, 6 do
      local slot_ui = runtime_hud.editor_bottom_inventory_slots and runtime_hud.editor_bottom_inventory_slots[slot] or nil
      if not slot_ui then
        slot_ui = resolve_first_ui(y3, env.get_player(), {
          string.format('GameHUD.layout_3.inventory.equip_slot_bg_%d.equip_slot_1', slot),
          string.format('GameHUD.main.inventory.equip_slot_bg_%d.equip_slot_1', slot),
          string.format('GameHUD.main.goods.equip_slot_bg_%d.goods', slot),
        })
      end

      runtime_hud.default_item_slots[slot] = slot_ui or false
      if is_ui_alive(slot_ui) and runtime_hud.default_item_slot_targets[slot] ~= slot_ui then
        runtime_hud.default_item_slot_targets[slot] = slot_ui
        slot_ui:add_fast_event('鼠标-移入', function()
          local item = get_hero_bar_item(slot)
          if is_growth_weapon_item(item) then
            show_growth_weapon_tip(slot_ui)
          else
            hide_growth_weapon_tip()
          end
        end)
        slot_ui:add_fast_event('鼠标-移出', function()
          hide_growth_weapon_tip()
        end)
        slot_ui:add_fast_event('左键-点击', function()
          hide_growth_weapon_tip()
        end)
      end
    end
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
    for slot = 1, 7 do
      local payload = env.build_bond_slot_tip_payload and env.build_bond_slot_tip_payload(slot) or nil
      runtime_hud.editor_bottom_bond_payloads[slot] = payload

      local bottom_icon = runtime_hud.bottom_bond_icons and runtime_hud.bottom_bond_icons[slot] or nil
      if is_ui_alive(bottom_icon) then
        if payload then
          set_image_if_alive(bottom_icon, payload.icon_res or ui_res.common.empty, { 255, 255, 255, 255 })
        elseif bottom_icon.set_image_color then
          bottom_icon:set_image_color(116, 130, 154, 148)
        end
        bottom_icon:set_visible(true)
      end

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

    for slot = 1, 4 do
      local slot_nodes = runtime_hud.skill_slots and runtime_hud.skill_slots[slot] or nil
      if slot_nodes then
        local slot_text = env.build_attack_skill_slot_text and env.build_attack_skill_slot_text(slot) or string.format('%d号位 空', slot)
        local title_text = slot_text
        local meta_text = ''
        local separator_start = string.find(slot_text, ' | ', 1, true)
        if separator_start then
          title_text = string.sub(slot_text, 1, separator_start - 1)
          meta_text = string.sub(slot_text, separator_start + 3)
        end

        if slot_nodes.text then
          slot_nodes.text:set_text(title_text)
        end
        if slot_nodes.meta then
          slot_nodes.meta:set_text(meta_text ~= '' and meta_text or '已装配')
        end
      end
    end

    local growth_slot = runtime_hud.growth_weapon_slot
    if growth_slot then
      local payload = env.build_growth_weapon_tip_payload and env.build_growth_weapon_tip_payload() or nil
      if payload then
        if STATE.hero and STATE.hero.is_exist and STATE.hero:is_exist() and growth_slot.set_ui_unit_slot then
          growth_slot:set_ui_unit_slot(STATE.hero, y3.const.SlotType.BAR, 0)
        end
      end
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
      '已拥有羁绊',
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
      growth_weapon_slot = resolve_first_ui(y3, env.get_player(), {
        'GameHUD.layout_3.inventory.equip_slot_bg_1.equip_slot_1',
        'GameHUD.main.inventory.equip_slot_bg_1.equip_slot_1',
      }),
      skill_slots = {
        [1] = {
          root = resolve_ui(y3, env.get_player(), 'GameHUD.hud_root.bottom_action_bar.skill_hotbar.skill_slot_1'),
          text = resolve_ui(y3, env.get_player(), 'GameHUD.hud_root.bottom_action_bar.skill_hotbar.skill_slot_1.skill_slot_1_text'),
          meta = resolve_ui(y3, env.get_player(), 'GameHUD.hud_root.bottom_action_bar.skill_hotbar.skill_slot_1.skill_slot_1_meta'),
        },
        [2] = {
          root = resolve_ui(y3, env.get_player(), 'GameHUD.hud_root.bottom_action_bar.skill_hotbar.skill_slot_2'),
          text = resolve_ui(y3, env.get_player(), 'GameHUD.hud_root.bottom_action_bar.skill_hotbar.skill_slot_2.skill_slot_2_text'),
          meta = resolve_ui(y3, env.get_player(), 'GameHUD.hud_root.bottom_action_bar.skill_hotbar.skill_slot_2.skill_slot_2_meta'),
        },
        [3] = {
          root = resolve_ui(y3, env.get_player(), 'GameHUD.hud_root.bottom_action_bar.skill_hotbar.skill_slot_3'),
          text = resolve_ui(y3, env.get_player(), 'GameHUD.hud_root.bottom_action_bar.skill_hotbar.skill_slot_3.skill_slot_3_text'),
          meta = resolve_ui(y3, env.get_player(), 'GameHUD.hud_root.bottom_action_bar.skill_hotbar.skill_slot_3.skill_slot_3_meta'),
        },
        [4] = {
          root = resolve_ui(y3, env.get_player(), 'GameHUD.hud_root.bottom_action_bar.skill_hotbar.skill_slot_4'),
          text = resolve_ui(y3, env.get_player(), 'GameHUD.hud_root.bottom_action_bar.skill_hotbar.skill_slot_4.skill_slot_4_text'),
          meta = resolve_ui(y3, env.get_player(), 'GameHUD.hud_root.bottom_action_bar.skill_hotbar.skill_slot_4.skill_slot_4_meta'),
        },
      },
    }

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
