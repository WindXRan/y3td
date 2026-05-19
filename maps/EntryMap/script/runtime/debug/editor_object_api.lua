local M = {}

local y3 = y3 or {}

local function safe_find_all(func)
    local ok, result = pcall(func)
    if not ok or not result then
        return {}
    end
    return result
end

function M.find_prefab_by_name(name)
    if not y3.prefab then
        return nil
    end
    local prefabs = safe_find_all(y3.prefab.find_all)
    for _, prefab in ipairs(prefabs) do
        if prefab.get_name and prefab:get_name() == name then
            return prefab
        end
    end
    return nil
end

function M.find_area_by_name(name)
    if not y3.area then
        return nil
    end
    local areas = safe_find_all(y3.area.find_all)
    for _, area in ipairs(areas) do
        if area.get_name and area:get_name() == name then
            return area
        end
    end
    return nil
end

function M.find_unit_by_name(name)
    if not y3.unit then
        return nil
    end
    local units = safe_find_all(y3.unit.find_all)
    for _, unit in ipairs(units) do
        if unit.get_name and unit:get_name() == name then
            return unit
        end
    end
    return nil
end

function M.get_prefab_point(name)
    local prefab = M.find_prefab_by_name(name)
    if prefab and prefab.get_point then
        return prefab:get_point()
    end
    return nil
end

function M.get_area_center(area)
    if type(area) == 'string' then
        area = M.find_area_by_name(area)
    end
    if not area or not area.get_x or not area.get_y then
        return nil
    end
    return y3.point.create(
        area:get_x(),
        area:get_y(),
        area.get_z and area:get_z() or 0
    )
end

function M.random_point_in_area(area)
    if type(area) == 'string' then
        area = M.find_area_by_name(area)
    end
    if not area or not area.get_width or not area.get_height then
        return nil
    end
    local cx = area.get_x and area:get_x() or 0
    local cy = area.get_y and area:get_y() or 0
    local w = area:get_width() or 200
    local h = area:get_height() or 200
    local x = cx - w / 2 + math.random() * w
    local y = cy - h / 2 + math.random() * h
    local z = area.get_z and area:get_z() or 0
    return y3.point.create(x, y, z)
end

function M.list_all_prefabs()
    if not y3.prefab then
        return {}
    end
    local prefabs = safe_find_all(y3.prefab.find_all)
    local result = {}
    for _, prefab in ipairs(prefabs) do
        if prefab.get_name then
            result[#result + 1] = {
                name = prefab:get_name(),
                id = prefab.get_id and prefab:get_id() or nil,
                point = prefab.get_point and prefab:get_point() or nil,
            }
        end
    end
    return result
end

function M.list_all_areas()
    if not y3.area then
        return {}
    end
    local areas = safe_find_all(y3.area.find_all)
    local result = {}
    for _, area in ipairs(areas) do
        if area.get_name then
            result[#result + 1] = {
                name = area:get_name(),
                x = area.get_x and area:get_x() or 0,
                y = area.get_y and area:get_y() or 0,
                z = area.get_z and area:get_z() or 0,
                width = area.get_width and area:get_width() or 0,
                height = area.get_height and area:get_height() or 0,
            }
        end
    end
    return result
end

function M.connect_spawn_area(area_name, spawn_config)
    local area = M.find_area_by_name(area_name)
    if not area then
        return nil, '区域不存在: ' .. area_name
    end
    return {
        area = area,
        config = spawn_config,
        get_random_point = function()
            return M.random_point_in_area(area)
        end,
        get_center = function()
            return M.get_area_center(area)
        end,
        spawn = function(unit_id, facing)
            local point = M.random_point_in_area(area)
            if not point then
                return nil, '无法获取刷怪点'
            end
            local ok, unit = pcall(y3.unit.create_unit,
                y3.player.get_enemy_player(),
                unit_id,
                point,
                facing or 180.0
            )
            if not ok or not unit then
                return nil, '创建单位失败'
            end
            return unit
        end,
    }
end

function M.connect_trigger_volume(area_name, on_enter, on_leave)
    local area = M.find_area_by_name(area_name)
    if not area then
        return nil, '区域不存在: ' .. area_name
    end
    
    local trigger = {
        area = area,
        enabled = true,
        enter_handler = on_enter,
        leave_handler = on_leave,
    }
    
    if y3.trigger and y3.trigger.add then
        y3.trigger.add('单位-进入区域', {
            area = area,
            action = function(context)
                if trigger.enabled and trigger.enter_handler then
                    trigger.enter_handler(context.unit, area)
                end
            end,
        })
        
        y3.trigger.add('单位-离开区域', {
            area = area,
            action = function(context)
                if trigger.enabled and trigger.leave_handler then
                    trigger.leave_handler(context.unit, area)
                end
            end,
        })
    end
    
    return trigger
end

function M.connect_marker_point(point_name)
    local point = M.get_prefab_point(point_name)
    if not point then
        return nil, '标记点不存在: ' .. point_name
    end
    return {
        point = point,
        x = point.get_x and point:get_x() or 0,
        y = point.get_y and point:get_y() or 0,
        z = point.get_z and point:get_z() or 0,
        move_unit_to = function(unit)
            if unit and unit.teleport then
                unit:teleport(point)
            end
        end,
        set_as_target = function(unit)
            if unit and unit.attack_move then
                unit:attack_move(point)
            end
        end,
    }
end

local hero_proximity_slow = {
    enabled = true,
    radius = 1000,
    speed_factor = 0.5,
    affected_units = {},
}

function M.enable_hero_proximity_slow(enable)
    hero_proximity_slow.enabled = enable
end

function M.set_hero_proximity_slow_radius(radius)
    hero_proximity_slow.radius = radius
end

function M.set_hero_proximity_slow_factor(factor)
    hero_proximity_slow.speed_factor = factor
end

function M.get_hero_proximity_slow_state()
    return {
        enabled = hero_proximity_slow.enabled,
        radius = hero_proximity_slow.radius,
        speed_factor = hero_proximity_slow.speed_factor,
    }
end

function M.start_hero_proximity_slow_monitor(hero_unit)
    if not hero_unit then
        return nil, '需要传入英雄单位'
    end
    
    local monitor = {
        hero = hero_unit,
        running = true,
        stop = function()
            monitor.running = false
            for unit in pairs(hero_proximity_slow.affected_units) do
                if unit and unit.set_speed_factor then
                    unit:set_speed_factor(1.0)
                end
            end
            hero_proximity_slow.affected_units = {}
        end,
    }
    
    if y3.timer and y3.timer.loop then
        y3.timer.loop(0.2, function()
            if not monitor.running or not hero_unit or not hero_unit.is_alive or not hero_unit:is_alive() then
                monitor.stop()
                return false
            end
            
            if not hero_proximity_slow.enabled then
                return true
            end
            
            local hero_pos = hero_unit.get_point and hero_unit:get_point()
            if not hero_pos then
                return true
            end
            
            local all_units = safe_find_all(y3.unit.find_all)
            local current_affected = {}
            
            for _, unit in ipairs(all_units) do
                if unit and unit.is_enemy and unit:is_enemy() and unit.is_alive and unit:is_alive() then
                    local unit_pos = unit.get_point and unit:get_point()
                    if unit_pos then
                        local distance = y3.point.distance(hero_pos, unit_pos)
                        if distance <= hero_proximity_slow.radius then
                            current_affected[unit] = true
                            if not hero_proximity_slow.affected_units[unit] then
                                if unit.set_speed_factor then
                                    unit:set_speed_factor(hero_proximity_slow.speed_factor)
                                end
                                hero_proximity_slow.affected_units[unit] = true
                            end
                        end
                    end
                end
            end
            
            for unit in pairs(hero_proximity_slow.affected_units) do
                if not current_affected[unit] then
                    if unit and unit.set_speed_factor then
                        unit:set_speed_factor(1.0)
                    end
                    hero_proximity_slow.affected_units[unit] = nil
                end
            end
            
            return true
        end)
    end
    
    return monitor
end

function M.auto_connect_battlefield()
    local result = {
        hero_spawn = M.connect_marker_point('hero_spawn'),
        defense_point = M.connect_marker_point('defense_point'),
        spawn_areas = {},
        main_spawn_area = nil,
        proximity_slow = {
            enabled = true,
            radius = 1000,
            speed_factor = 0.5,
            monitor = nil,
            start = function(hero_unit)
                result.proximity_slow.monitor = M.start_hero_proximity_slow_monitor(hero_unit)
            end,
            stop = function()
                if result.proximity_slow.monitor then
                    result.proximity_slow.monitor.stop()
                    result.proximity_slow.monitor = nil
                end
            end,
            set_radius = function(radius)
                M.set_hero_proximity_slow_radius(radius)
                result.proximity_slow.radius = radius
            end,
            set_factor = function(factor)
                M.set_hero_proximity_slow_factor(factor)
                result.proximity_slow.speed_factor = factor
            end,
        },
    }
    
    local single_spawn_area = M.find_area_by_name('spawn_area')
    if single_spawn_area then
        result.main_spawn_area = M.connect_spawn_area('spawn_area', { is_main = true })
        result.spawn_areas['main_spawn'] = result.main_spawn_area
        result.spawn_areas['boss_spawn'] = result.main_spawn_area
    else
        local spawn_area = M.connect_spawn_area('main_spawn', { is_main = true })
        if spawn_area then
            result.spawn_areas['main_spawn'] = spawn_area
        end
        
        local boss_area = M.connect_spawn_area('boss_spawn', { is_boss = true })
        if boss_area then
            result.spawn_areas['boss_spawn'] = boss_area
        end
    end
    
    return result
end

return M