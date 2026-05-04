local SuitSystem = require 'y3.game.suit_system'
local suit_catalog = require 'data.tables.economy.suit_catalog'
local suit_effects = require 'data.tables.economy.suit_effects'

local M = {}

local STAR_ICON_ID = 904702
local SUIT_ICONS = {
    suit_dragon = 906565,
    suit_phoenix = 906565,
    suit_tiger = 906565,
    suit_crane = 906565,
    suit_viper = 906565,
}

local QUALITY_COLORS = {
    N = { 200, 200, 200, 255 },
    R = { 100, 200, 255, 255 },
    SR = { 180, 100, 255, 255 },
    SSR = { 255, 180, 100, 255 },
    UR = { 255, 100, 100, 255 },
}

function M.create_suit_item_ui(player, suit_id, parent_ui, x, y)
    local data = SuitSystem.get_player_suit_data(player)
    local suit_data = data[suit_id]
    local catalog = suit_catalog.SUIT_IDS[suit_id]
    if not catalog then
        return nil
    end

    local suit_info = suit_catalog.by_suit_id[suit_id]
    if not suit_info then
        return nil
    end

    local item_ui = player:create_ui('item', parent_ui, x, y, 120, 150)
    if not item_ui then
        return nil
    end

    local bg_path = suit_info.icon
    item_ui:set_image(bg_path)

    local name_text = suit_info.name
    local star_level = suit_data and suit_data.current_star_level or 0
    local quality = suit_info.quality or 'N'
    local color = QUALITY_COLORS[quality] or QUALITY_COLORS.N

    local name_label = player:create_ui('text', item_ui, 10, 130, 100, 20)
    name_label:set_text(name_text)
    name_label:set_font_color(color[1], color[2], color[3], color[4])

    local star_label = player:create_ui('text', item_ui, 10, 110, 100, 20)
    star_label:set_text(string.format('%d阶', star_level))
    star_label:set_font_color(255, 255, 100, 255)

    M.create_star_display(player, item_ui, star_level, 10, 85)

    return item_ui
end

function M.create_star_display(player, parent_ui, star_level, x, y)
    local star_size = 12
    local star_spacing = 14
    local max_stars = 10
    local stars_per_row = 5

    for i = 1, max_stars do
        local row = math.floor((i - 1) / stars_per_row)
        local col = (i - 1) % stars_per_row
        local star_x = x + col * star_spacing
        local star_y = y - row * star_size

        local star_ui = player:create_ui('image', parent_ui, star_x, star_y, star_size, star_size)
        if star_ui then
            if i <= star_level then
                star_ui:set_image(tostring(STAR_ICON_ID))
                star_ui:set_visible(true)
            else
                star_ui:set_image(tostring(STAR_ICON_ID))
                star_ui:set_grayscale(true)
                star_ui:set_visible(true)
            end
        end
    end
end

function M.refresh_suit_item_ui(player, item_ui, suit_id)
    if not item_ui then
        return
    end

    local data = SuitSystem.get_player_suit_data(player)
    local suit_data = data[suit_id]
    local star_level = suit_data and suit_data.current_star_level or 0

    for _, child in ipairs(item_ui:get_all_children() or {}) do
        if child and child.set_text and child:get_name():find('star_level') then
            child:set_text(string.format('%d阶', star_level))
        end
    end
end

function M.get_suit_display_info(player, suit_id)
    local data = SuitSystem.get_player_suit_data(player)
    local suit_data = data[suit_id]
    local catalog = suit_catalog.by_suit_id[suit_id]

    if not catalog then
        return nil
    end

    local current_level = suit_data and suit_data.current_star_level or 0
    local effects = suit_effects.get_effects_by_suit_and_level(suit_id, current_level)
    local next_effects = suit_effects.get_effects_by_suit_and_level(suit_id, current_level + 1)

    return {
        suit_id = suit_id,
        name = catalog.name,
        quality = catalog.quality,
        icon = SUIT_ICONS[suit_id] or 906565,
        current_star_level = current_level,
        description = effects and effects.description or catalog.description or '',
        next_description = next_effects and next_effects.description or '',
        effects = effects and effects.effects or {},
        next_effects = next_effects and next_effects.effects or {},
        equipment = suit_data and suit_data.equipment or {},
    }
end

function M.get_all_suits_display_info(player)
    local result = {}
    for suit_id, _ in pairs(suit_catalog.SUIT_IDS) do
        local info = M.get_suit_display_info(player, suit_id)
        if info then
            result[#result + 1] = info
        end
    end
    return result
end

return M