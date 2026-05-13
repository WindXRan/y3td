-- 游戏启动后会自动运行此文件

local function init_config()
    y3.config.sync.mouse = true

    if y3.game.is_debug_mode() then
        y3.config.log.toGame = false
        y3.config.log.level = 'debug'
    else
        y3.config.log.toGame = false
        y3.config.log.level = 'info'
    end
end

local MAIN_STATE_KEY = '__entrymap_main_state'
local MAIN_STATE = rawget(_G, MAIN_STATE_KEY)
if type(MAIN_STATE) ~= 'table' then
    MAIN_STATE = {
        runtime = nil,
        runtime_load_attempted = false,
        bootstrapped = false,
        bootstrapping = false,
        initialized = false,
    }
    rawset(_G, MAIN_STATE_KEY, MAIN_STATE)
end

local function load_runtime()
    if MAIN_STATE.runtime_load_attempted and MAIN_STATE.runtime then
        return MAIN_STATE.runtime
    end

    MAIN_STATE.runtime_load_attempted = true

    local ok, result = xpcall(function()
        require 'runtime.compat'
        return require 'entry_runtime'
    end, debug.traceback)

    if not ok then
        MAIN_STATE.runtime_load_attempted = false
        print('[EntryMap] failed to require entry_runtime:\n' .. tostring(result))
        return nil
    end

    MAIN_STATE.runtime = result
    return MAIN_STATE.runtime
end

local function bootstrap_once()
    if MAIN_STATE.bootstrapped or MAIN_STATE.bootstrapping then
        return
    end

    local loaded_runtime = load_runtime()
    if not loaded_runtime then
        return
    end
    if type(loaded_runtime.bootstrap) ~= 'function' then
        print('[EntryMap] entry_runtime.bootstrap is missing')
        return
    end

    MAIN_STATE.bootstrapping = true

    local ok, err = xpcall(function()
        loaded_runtime.bootstrap()
    end, debug.traceback)

    MAIN_STATE.bootstrapping = false
    if not ok then
        print('[EntryMap] runtime.bootstrap failed:\n' .. tostring(err))
        return
    end

    MAIN_STATE.bootstrapped = true
end

local function initialize()
    if MAIN_STATE.initialized then
        return true
    end

    local ok = pcall(init_config)
    if not ok then
        return false
    end

    y3.game:event('游戏-初始化', function()
        bootstrap_once()
    end)

    y3.ltimer.wait(0, function()
        bootstrap_once()
    end)

    MAIN_STATE.initialized = true
    return true
end

if not initialize() then
    local function wait_for_y3()
        local ok = pcall(function() return y3 and y3.game end)
        if ok and y3 and y3.game then
            initialize()
            return
        end

        local global_wait = rawget(_G, 'Wait')
        if global_wait then
            pcall(global_wait, 0)
        end

        local pcall_ok, ltimer = pcall(function() return y3 and y3.ltimer end)
        if pcall_ok and ltimer and ltimer.wait then
            ltimer.wait(0, wait_for_y3)
        else
            local global_delay = rawget(_G, 'delay')
            if global_delay then
                pcall(global_delay, 0, wait_for_y3)
            end
        end
    end

    wait_for_y3()
end
