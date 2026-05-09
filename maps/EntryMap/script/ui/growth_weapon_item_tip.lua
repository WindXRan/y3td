local GrowthWeaponTipPanel = require 'ui.growth_weapon_tip_panel'

local M = {}

function M.create(env)
  local y3 = env.y3
  local STATE = env.STATE
  local get_player = env.get_player
  local tip_panel = GrowthWeaponTipPanel.create({
    y3 = y3,
    get_player = get_player,
  })

  local root = y3.local_ui.create('GameHUD')
  local bound = false

  local function hide()
    tip_panel.hide()
  end

  local function hovered_item(slot_index, local_player)
    local hero = STATE.hero or local_player:get_local_selecting_unit()
    if not hero then
      return nil
    end
    local ok, item = pcall(hero.get_item_by_slot, hero, y3.const.SlotType.BAR, slot_index - 1)
    if not ok then
      ok, item = pcall(hero.get_item_by_slot, hero, '物品栏', slot_index)
    end
    return item
  end

  local function show(ui, local_player, slot_index)
    local item = hovered_item(slot_index, local_player)
    if not item or not item.is_exist or not item:is_exist() then
      hide()
      return
    end
    local payload = env.build_growth_weapon_tip_payload and env.build_growth_weapon_tip_payload('weapon') or nil
    if not payload then
      hide()
      return
    end
    local ok, item_key = pcall(item.get_key, item)
    if not ok or not item_key then
      hide()
      return
    end
    if payload.item_key ~= tonumber(item_key) then
      hide()
      return
    end
    tip_panel.show_for_anchor(ui, payload)
  end

  local function bind()
    if bound then
      return
    end
    bound = true
    for slot = 1, 6 do
      local child_name = string.format('main.inventory.equip_slot_bg_%d', slot)
      root:on_event(child_name, '鼠标-移入', function(ui, local_player)
        show(ui, local_player, slot)
      end)
      root:on_event(child_name, '鼠标-移出', function()
        hide()
      end)
    end
  end

  return {
    bind = bind,
    refresh = function() end,
    hide = hide,
  }
end

return M