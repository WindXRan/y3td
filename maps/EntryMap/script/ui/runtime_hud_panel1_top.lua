local BaseHud = require 'ui.runtime_hud'

local M = {}

local function resolve_ui(y3, player, path)
  local ok, ui = pcall(y3.ui.get_ui, player, path)
  if not ok or not ui then
    return nil
  end
  return ui
end

local function is_alive(ui)
  return ui and (not ui.is_removed or not ui:is_removed())
end

local function make_noop_text()
  return {
    set_text = function() end,
    set_text_color = function() end,
  }
end

local function make_text_proxy(node, transform)
  return {
    set_text = function(_, text)
      if node and not node:is_removed() then
        node:set_text(transform and transform(text) or text)
      end
    end,
    set_text_color = function() end,
  }
end

local function make_value_proxy(node, getter)
  return {
    set_text = function() end,
    set_text_color = function() end,
    sync = function()
      if is_alive(node) then
        node:set_text(tostring(getter() or ''))
      end
    end,
  }
end

local function normalize_ratio(value)
  local number = tonumber(value) or 0
  if math.abs(number) > 1 then
    return number / 100
  end
  return number
end

local function format_compact_number(value)
  local number = tonumber(value) or 0
  local abs_number = math.abs(number)
  if abs_number >= 1000000 then
    local text = string.format('%.1fm', number / 1000000)
    return text:gsub('%.0m$', 'm')
  end
  if abs_number >= 10000 then
    local text = string.format('%.1fk', number / 1000)
    return text:gsub('%.0k$', 'k')
  end
  if math.abs(number - math.floor(number)) < 0.001 then
    return tostring(math.floor(number))
  end
  return string.format('%.1f', number)
end

local function format_percent_text(value)
  local ratio = normalize_ratio(value)
  if math.abs(ratio) < 0.0001 then
    return ''
  end
  return string.format('%+.0f', ratio * 100)
end

local function format_wave_time_text(text)
  if not text or text == '' then
    return '--s'
  end
  local seconds = text:match('([%d%.]+)%s*秒后登场')
  if seconds then
    return string.format('%ss', tostring(math.floor(tonumber(seconds) or 0)))
  end
  if text:find('已击败', 1, true) then
    return '已击败'
  end
  if text:find('HP ', 1, true) then
    return 'BOSS'
  end
  return text
end

local function format_tips_text(name, state)
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

local function bind_panel1_top(env, runtime_hud)
  if runtime_hud.panel1_top_bound then
    return true
  end

  local y3 = env.y3
  local player = env.get_player()
  local top_root = resolve_ui(y3, player, 'panel_1.tophud')
  if not top_root then
    return false
  end

  local wave = resolve_ui(y3, player, 'panel_1.tophud.layout_2.wave')
  local wavetime = resolve_ui(y3, player, 'panel_1.tophud.layout_2.wavetime')
  local tips = resolve_ui(y3, player, 'panel_1.tophud.layout_2.tips')
  local curlevel = resolve_ui(y3, player, 'panel_1.tophud.layout_2.curlevel')
  local gametime = resolve_ui(y3, player, 'panel_1.tophud.layout_2.gametime')
  local coin_num = resolve_ui(y3, player, 'panel_1.coin.layout_1.floor.num')
  local coin_rate = resolve_ui(y3, player, 'panel_1.coin.layout_1.floor.persecondadd')
  local coin_extra = resolve_ui(y3, player, 'panel_1.coin.layout_1.floor.extraadd')
  local wood_num = resolve_ui(y3, player, 'panel_1.wood.layout_1.floor.num')
  local wood_rate = resolve_ui(y3, player, 'panel_1.wood.layout_1.floor.persecondadd')
  local wood_extra = resolve_ui(y3, player, 'panel_1.wood.layout_1.floor.extraadd')
  local kills_num = resolve_ui(y3, player, 'panel_1.kills.layout_1.floor.num')
  local kills_rate = resolve_ui(y3, player, 'panel_1.kills.layout_1.floor.persecondadd')
  local kills_extra = resolve_ui(y3, player, 'panel_1.kills.layout_1.floor.extraadd')

  if not wave or not wavetime or not tips or not curlevel or not gametime then
    return false
  end

  local legacy_top_root = runtime_hud.center_root
  if is_alive(legacy_top_root) and legacy_top_root ~= top_root then
    legacy_top_root:set_visible(false)
    legacy_top_root:remove()
  end

  local boss_state_cache = {
    name = '',
    state = '',
  }
  local tip_overlay = {
    text = nil,
    expires_at = 0,
  }
  local resource_refresh_interval = 1.5
  local resource_refresh_state = {
    next_sync_at = 0,
  }
  local hero_attr_system = env.hero_attr_system

  local function get_hero_attr(name)
    local hero = env.STATE and env.STATE.hero
    if not hero or not hero.is_exist or not hero:is_exist() then
      return 0
    end
    if hero_attr_system then
      return hero_attr_system.get_attr(hero, name)
    end
    return hero:get_attr(name) or 0
  end

  local function get_resource_rate(kind)
    local rules = env.get_resource_rules and env.get_resource_rules() or {}
    if kind == 'gold' then
      return (rules.gold_per_sec or 0)
        + (env.get_bond_runtime_bonus and env.get_bond_runtime_bonus('gold_per_sec_bonus') or 0)
        + (env.get_treasure_passive_income and env.get_treasure_passive_income('gold') or 0)
    end
    if kind == 'wood' then
      return (rules.wood_per_sec or 0)
        + (env.get_bond_runtime_bonus and env.get_bond_runtime_bonus('wood_per_sec_bonus') or 0)
        + (env.get_treasure_passive_income and env.get_treasure_passive_income('wood') or 0)
    end
    if kind == 'kills' then
      return get_hero_attr('每秒杀敌')
    end
    return 0
  end

  local function get_resource_extra_ratio(kind)
    local hero_attr_ratio = 0
    if kind == 'gold' then
      hero_attr_ratio = normalize_ratio(get_hero_attr('杀敌金币'))
    elseif kind == 'wood' then
      hero_attr_ratio = normalize_ratio(get_hero_attr('杀敌木材'))
    elseif kind == 'kills' then
      hero_attr_ratio = normalize_ratio(get_hero_attr('杀敌加成'))
    end

    if kind == 'gold' then
      return hero_attr_ratio
        + (env.get_bond_runtime_bonus and env.get_bond_runtime_bonus('kill_gold_ratio') or 0)
        + (env.get_treasure_reward_ratio and env.get_treasure_reward_ratio('gold') or 0)
    end
    if kind == 'wood' then
      return hero_attr_ratio
        + (env.get_bond_runtime_bonus and env.get_bond_runtime_bonus('kill_reward_ratio') or 0)
        + (env.get_treasure_reward_ratio and env.get_treasure_reward_ratio('wood') or 0)
    end
    if kind == 'kills' then
      return hero_attr_ratio
    end
    return 0
  end

  local function sync_resource_panels(force)
    local elapsed = env.STATE and env.STATE.runtime_elapsed or 0
    if not force and elapsed < (resource_refresh_state.next_sync_at or 0) then
      return
    end
    resource_refresh_state.next_sync_at = elapsed + resource_refresh_interval

    if is_alive(coin_num) then
      coin_num:set_text(format_compact_number(env.STATE and env.STATE.resources and env.STATE.resources.gold or 0))
    end
    if is_alive(wood_num) then
      wood_num:set_text(format_compact_number(env.STATE and env.STATE.resources and env.STATE.resources.wood or 0))
    end
    if is_alive(kills_num) then
      kills_num:set_text(format_compact_number(env.STATE and env.STATE.total_kills or 0))
    end

    if is_alive(coin_rate) then
      coin_rate:set_text(format_compact_number(get_resource_rate('gold')))
    end
    if is_alive(wood_rate) then
      wood_rate:set_text(format_compact_number(get_resource_rate('wood')))
    end
    if is_alive(kills_rate) then
      kills_rate:set_text(format_compact_number(get_resource_rate('kills')))
    end

    if is_alive(coin_extra) then
      coin_extra:set_text(format_percent_text(get_resource_extra_ratio('gold')))
    end
    if is_alive(wood_extra) then
      wood_extra:set_text(format_percent_text(get_resource_extra_ratio('wood')))
    end
    if is_alive(kills_extra) then
      kills_extra:set_text(format_percent_text(get_resource_extra_ratio('kills')))
    end
  end

  local function flush_tips()
    local elapsed = env.STATE and env.STATE.runtime_elapsed or 0
    if tip_overlay.text and (tip_overlay.expires_at or 0) > elapsed then
      if is_alive(tips) then
        tips:set_text(tostring(tip_overlay.text))
      end
      return
    end
    tip_overlay.text = nil
    tip_overlay.expires_at = 0
    if is_alive(tips) then
      tips:set_text(format_tips_text(boss_state_cache.name, boss_state_cache.state))
    end
  end

  runtime_hud.center_root = top_root
  runtime_hud.top_root = top_root
  runtime_hud.stage_text = curlevel
  runtime_hud.wave_title = wave
  runtime_hud.wave_status = {
    set_text = function(_, text)
      if is_alive(tips) and (not boss_state_cache.state or boss_state_cache.state == '') then
        tips:set_text(tostring(text or ''))
      end
    end,
    set_text_color = function() end,
  }
  runtime_hud.timer_text = make_text_proxy(gametime, function(text)
    local plain = tostring(text or '')
    local hhmm = plain:match('(%d%d:%d%d)')
    return hhmm or plain
  end)
  runtime_hud.boss_panel = {
    set_image_color = function() end,
  }
  runtime_hud.boss_name = {
    set_text = function(_, text)
      boss_state_cache.name = text or ''
      flush_tips()
    end,
    set_text_color = function() end,
  }
  runtime_hud.boss_state = {
    set_text = function(_, text)
      boss_state_cache.state = text or ''
      if is_alive(wavetime) then
        wavetime:set_text(format_wave_time_text(text))
      end
      flush_tips()
    end,
    set_text_color = function() end,
  }
  runtime_hud.gold_value = make_value_proxy(coin_num, function()
    return env.STATE and env.STATE.resources and env.STATE.resources.gold or 0
  end)
  runtime_hud.wood_value = make_value_proxy(wood_num, function()
    return env.STATE and env.STATE.resources and env.STATE.resources.wood or 0
  end)
  runtime_hud.skill_value = make_value_proxy(kills_num, function()
    return env.STATE and env.STATE.total_kills or 0
  end)
  runtime_hud.challenge_value = make_noop_text()
  runtime_hud.panel1_resource_sync = sync_resource_panels
  runtime_hud.panel1_flush_tips = flush_tips
  runtime_hud.panel1_set_tip_overlay = function(text, duration)
    local overlay_text = tostring(text or '')
    if overlay_text == '' then
      tip_overlay.text = nil
      tip_overlay.expires_at = 0
      flush_tips()
      return
    end
    local elapsed = env.STATE and env.STATE.runtime_elapsed or 0
    tip_overlay.text = overlay_text
    tip_overlay.expires_at = elapsed + math.max(0.5, tonumber(duration) or 8)
    flush_tips()
  end
  runtime_hud.panel1_clear_tip_overlay = function()
    tip_overlay.text = nil
    tip_overlay.expires_at = 0
    flush_tips()
  end
  runtime_hud.panel1_top_bound = true
  sync_resource_panels(true)
  flush_tips()

  return true
end

function M.create(env)
  local base = BaseHud.create(env)

  return {
    ensure_hud = function()
      local hud = base.ensure_hud()
      if not hud then
        return nil
      end
      if bind_panel1_top(env, hud) then
        base.refresh_hud()
      end
      return hud
    end,
    refresh_hud = function()
      local hud = env.STATE and env.STATE.runtime_hud
      if hud then
        bind_panel1_top(env, hud)
      end
      local result = base.refresh_hud()
      if hud and hud.gold_value and hud.gold_value.sync then
        hud.gold_value:sync()
      end
      if hud and hud.wood_value and hud.wood_value.sync then
        hud.wood_value:sync()
      end
      if hud and hud.skill_value and hud.skill_value.sync then
        hud.skill_value:sync()
      end
      if hud and hud.panel1_resource_sync then
        hud.panel1_resource_sync(false)
      end
      return result
    end,
    set_visible = function(visible)
      return base.set_visible(visible)
    end,
    show_tip_panel = function(text, duration)
      local hud = env.STATE and env.STATE.runtime_hud
      if not hud then
        hud = base.ensure_hud()
        if hud then
          bind_panel1_top(env, hud)
        end
      end
      if hud and hud.panel1_set_tip_overlay then
        hud.panel1_set_tip_overlay(text, duration)
      end
    end,
    clear_tip_panel = function()
      local hud = env.STATE and env.STATE.runtime_hud
      if hud and hud.panel1_clear_tip_overlay then
        hud.panel1_clear_tip_overlay()
      end
    end,
  }
end

return M
