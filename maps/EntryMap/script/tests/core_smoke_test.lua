local TestFramework = require 'core.test_framework'
local Core = require 'core.init'

local Test = TestFramework.Test
local Assert = TestFramework.Assert

local suite = TestFramework.create_suite('Core Smoke Tests')

suite.before_all(function()
    print('=== Initializing Core Systems ===')
    local options = {
        log_level = 'DEBUG',
        strict_config = false,
        debug_events = true,
        log_to_file = false
    }
    
    local ok, result = pcall(function()
        return Core.initialize(options)
    end)
    
    if ok then
        print('Core initialized successfully')
        suite.core = result
    else
        print('Core initialization failed:', result)
        error('Core initialization failed')
    end
end)

suite.after_all(function()
    print('=== Cleaning Up ===')
    suite.core = nil
end)

Test(suite, 'DI Container', function(t)
    local container = Core.get_container()
    
    Assert.is_not_nil(container, 'Container should exist')
    Assert.is_function(container.register, 'Register should be a function')
    Assert.is_function(container.register_instance, 'Register instance should be a function')
    Assert.is_function(container.get, 'Get should be a function')
    Assert.is_function(container.has, 'Has should be a function')
    
    container.register_instance('test_service', { value = 42 })
    Assert.true(container.has('test_service'), 'Service should be registered')
    
    local service = container.get('test_service')
    Assert.equal(service.value, 42, 'Service value should be 42')
    
    print('✓ DI Container tests passed')
end)

Test(suite, 'Event Bus', function(t)
    local event_bus = Core.get_event_bus()
    
    Assert.is_not_nil(event_bus, 'Event bus should exist')
    Assert.is_function(event_bus.on, 'On should be a function')
    Assert.is_function(event_bus.once, 'Once should be a function')
    Assert.is_function(event_bus.publish, 'Publish should be a function')
    
    local received = {}
    local unsubscribe = event_bus.on('test.event', function(payload)
        table.insert(received, payload)
    end)
    
    event_bus.publish('test.event', { value = 1 })
    event_bus.publish('test.event', { value = 2 })
    
    Assert.equal(#received, 2, 'Should receive 2 events')
    Assert.equal(received[1].value, 1, 'First event value should be 1')
    Assert.equal(received[2].value, 2, 'Second event value should be 2')
    
    unsubscribe()
    event_bus.publish('test.event', { value = 3 })
    
    Assert.equal(#received, 2, 'Should not receive event after unsubscribe')
    
    print('✓ Event Bus tests passed')
end)

Test(suite, 'Event Bus - Once Handler', function(t)
    local event_bus = Core.get_event_bus()
    
    local count = 0
    event_bus.once('test.once', function()
        count = count + 1
    end)
    
    event_bus.publish('test.once')
    event_bus.publish('test.once')
    
    Assert.equal(count, 1, 'Once handler should only fire once')
    
    print('✓ Event Bus Once Handler tests passed')
end)

Test(suite, 'Event Bus Adapter', function(t)
    local adapter = Core.get_event_bus_adapter()
    
    Assert.is_not_nil(adapter, 'Event bus adapter should exist')
    Assert.is_function(adapter.is_initialized, 'Is initialized should be a function')
    Assert.is_not_nil(adapter.bridge, 'Bridge should exist')
    Assert.is_not_nil(adapter.subscribe, 'Subscribe helpers should exist')
    
    Assert.true(adapter.is_initialized(), 'Adapter should be initialized')
    
    print('✓ Event Bus Adapter tests passed')
end)

Test(suite, 'Event Subscriber', function(t)
    local subscriber = Core.get_event_subscriber()
    
    Assert.is_not_nil(subscriber, 'Event subscriber should exist')
    Assert.is_function(subscriber.create_group, 'Create group should be a function')
    Assert.is_function(subscriber.battle, 'Battle should be a function')
    Assert.is_function(subscriber.hero, 'Hero should be a function')
    Assert.is_function(subscriber.skill, 'Skill should be a function')
    Assert.is_function(subscriber.reward, 'Reward should be a function')
    Assert.is_function(subscriber.challenge, 'Challenge should be a function')
    Assert.is_function(subscriber.ui, 'UI should be a function')
    
    local group = subscriber.create_group('test_group')
    Assert.is_not_nil(group, 'Group should be created')
    Assert.is_function(group.on, 'Group on should be a function')
    Assert.is_function(group.clear, 'Group clear should be a function')
    
    local event_bus = Core.get_event_bus()
    local received = {}
    
    group.on('test.subscriber', function(payload)
        table.insert(received, payload)
    end)
    
    event_bus.publish('test.subscriber', { test = true })
    Assert.equal(#received, 1, 'Should receive event through group')
    
    group.clear()
    event_bus.publish('test.subscriber', { test = false })
    Assert.equal(#received, 1, 'Should not receive event after clear')
    
    print('✓ Event Subscriber tests passed')
end)

Test(suite, 'Config Manager', function(t)
    local config = Core.get_config()
    
    Assert.is_not_nil(config, 'Config should exist')
    Assert.is_function(config.set, 'Set should be a function')
    Assert.is_function(config.get, 'Get should be a function')
    Assert.is_function(config.load_from_table, 'Load from table should be a function')
    
    config.load_from_table('game', {
        max_enemies = 40,
        debug_mode = true,
        settings = {
            volume = 0.8,
            graphics = 'high'
        }
    })
    
    Assert.equal(config.get('game.max_enemies'), 40, 'Max enemies should be 40')
    Assert.equal(config.get('game.debug_mode'), true, 'Debug mode should be true')
    Assert.equal(config.get('game.settings.volume'), 0.8, 'Volume should be 0.8')
    Assert.equal(config.get('game.settings.graphics'), 'high', 'Graphics should be high')
    
    Assert.is_nil(config.get('nonexistent.key'), 'Nonexistent key should return nil')
    
    print('✓ Config Manager tests passed')
end)

Test(suite, 'Error Handler', function(t)
    local error_handler = Core.get_error_handler()
    
    Assert.is_not_nil(error_handler, 'Error handler should exist')
    Assert.is_function(error_handler.safe_call, 'Safe call should be a function')
    Assert.is_function(error_handler.logger, 'Logger should be a function')
    
    local logger = error_handler.logger('Test')
    Assert.is_function(logger.debug, 'Debug should be a function')
    Assert.is_function(logger.info, 'Info should be a function')
    Assert.is_function(logger.warn, 'Warn should be a function')
    Assert.is_function(logger.error, 'Error should be a function')
    
    local result = error_handler.safe_call(function()
        return 'success'
    end)
    Assert.true(result.success, 'Safe call should succeed')
    Assert.equal(result.value, 'success', 'Safe call should return value')
    
    local failed_result = error_handler.safe_call(function()
        error('test error')
    end)
    Assert.false(failed_result.success, 'Safe call should fail on error')
    Assert.is_not_nil(failed_result.error, 'Should have error message')
    
    print('✓ Error Handler tests passed')
end)

Test(suite, 'Integration - Services Available', function(t)
    local container = Core.get_container()
    
    Assert.true(container.has('event_bus'), 'Event bus should be registered')
    Assert.true(container.has('event_bus_adapter'), 'Event bus adapter should be registered')
    Assert.true(container.has('event_subscriber'), 'Event subscriber should be registered')
    Assert.true(container.has('config'), 'Config should be registered')
    Assert.true(container.has('config_loader'), 'Config loader should be registered')
    Assert.true(container.has('error_handler'), 'Error handler should be registered')
    
    print('✓ Integration - Services Available tests passed')
end)

Test(suite, 'Config Loader', function(t)
    local config_loader = Core.get_config_loader()
    
    Assert.is_not_nil(config_loader, 'Config loader should exist')
    Assert.is_function(config_loader.load_all, 'Load all should be a function')
    Assert.is_function(config_loader.load_entry_config, 'Load entry config should be a function')
    Assert.is_function(config_loader.load_game_tables, 'Load game tables should be a function')
    
    print('✓ Config Loader tests passed')
end)

Test(suite, 'Integration - Event Flow', function(t)
    local event_bus = Core.get_event_bus()
    local subscriber = Core.get_event_subscriber()
    
    local events_received = {}
    
    local battle_group = subscriber.battle({
        on_wave_start = function(data)
            table.insert(events_received, { type = 'wave_start', data = data })
        end,
        on_battle_end = function(data)
            table.insert(events_received, { type = 'battle_end', data = data })
        end
    })
    
    local hero_group = subscriber.hero({
        on_hero_hurt = function(data)
            table.insert(events_received, { type = 'hero_hurt', data = data })
        end
    })
    
    event_bus.publish(event_bus.events.WAVE_START, { wave_index = 5 })
    event_bus.publish(event_bus.events.HERO_HURT, { damage = 100 })
    event_bus.publish(event_bus.events.BATTLE_END, { is_win = true })
    
    Assert.equal(#events_received, 3, 'Should receive 3 events')
    Assert.equal(events_received[1].type, 'wave_start', 'First event should be wave_start')
    Assert.equal(events_received[2].type, 'hero_hurt', 'Second event should be hero_hurt')
    Assert.equal(events_received[3].type, 'battle_end', 'Third event should be battle_end')
    
    battle_group.clear()
    hero_group.clear()
    
    print('✓ Integration - Event Flow tests passed')
end)

function suite.run()
    print('\n' .. string.rep('=', 60))
    print('Running Core Smoke Tests')
    print(string.rep('=', 60) .. '\n')
    
    local results = suite.execute()
    
    print('\n' .. string.rep('=', 60))
    print('Test Results:')
    print(string.rep('=', 60))
    print(string.format('Passed: %d / %d', results.passed, results.total))
    
    if results.failed > 0 then
        print('Failed:')
        for _, err in ipairs(results.errors) do
            print('  - ' .. err)
        end
    end
    
    return results
end

return suite