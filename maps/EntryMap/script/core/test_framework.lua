local M = {}

function M.create(options)
    options = options or {}
    
    local tests = {}
    local test_results = {}
    local current_suite = nil
    local verbose = options.verbose or false
    
    local function log(level, message)
        if verbose or level == 'error' or level == 'warn' then
            local prefix = string.format('[%s]', level:upper())
            print(string.format('%s %s', prefix, message))
        end
    end
    
    local function describe(suite_name, callback)
        current_suite = {
            name = suite_name,
            tests = {},
            before_all = nil,
            after_all = nil,
            before_each = nil,
            after_each = nil
        }
        
        local context = {
            it = function(test_name, test_fn)
                table.insert(current_suite.tests, {
                    name = test_name,
                    fn = test_fn
                })
            end,
            
            before_all = function(fn)
                current_suite.before_all = fn
            end,
            
            after_all = function(fn)
                current_suite.after_all = fn
            end,
            
            before_each = function(fn)
                current_suite.before_each = fn
            end,
            
            after_each = function(fn)
                current_suite.after_each = fn
            end
        }
        
        callback(context)
        
        table.insert(tests, current_suite)
        current_suite = nil
    end
    
    local function run_test(test, suite)
        local result = {
            suite_name = suite.name,
            test_name = test.name,
            passed = false,
            error = nil,
            duration = nil
        }
        
        local start_time = os.clock()
        
        if suite.before_each then
            local ok, err = pcall(suite.before_each)
            if not ok then
                result.error = 'before_each failed: ' .. err
                log('error', string.format('Suite "%s" before_each failed: %s', suite.name, err))
                return result
            end
        end
        
        local ok, err = pcall(test.fn)
        
        if suite.after_each then
            local after_ok, after_err = pcall(suite.after_each)
            if not after_ok then
                log('warn', string.format('Suite "%s" after_each failed: %s', suite.name, after_err))
            end
        end
        
        result.duration = os.clock() - start_time
        
        if ok then
            result.passed = true
            log('info', string.format('✓ %s - %s (%.2fs)', suite.name, test.name, result.duration))
        else
            result.error = err
            log('error', string.format('✗ %s - %s: %s', suite.name, test.name, err))
        end
        
        return result
    end
    
    local function run_suite(suite)
        log('info', string.format('Running suite: "%s"', suite.name))
        
        if suite.before_all then
            local ok, err = pcall(suite.before_all)
            if not ok then
                log('error', string.format('Suite "%s" before_all failed: %s', suite.name, err))
                return
            end
        end
        
        for _, test in ipairs(suite.tests) do
            local result = run_test(test, suite)
            table.insert(test_results, result)
        end
        
        if suite.after_all then
            local ok, err = pcall(suite.after_all)
            if not ok then
                log('warn', string.format('Suite "%s" after_all failed: %s', suite.name, err))
            end
        end
        
        log('info', string.format('Suite "%s" completed', suite.name))
    end
    
    local function run_all()
        log('info', 'Starting test run...')
        
        for _, suite in ipairs(tests) do
            run_suite(suite)
        end
        
        summarize()
    end
    
    local function summarize()
        local passed = 0
        local failed = 0
        local total_time = 0
        
        for _, result in ipairs(test_results) do
            if result.passed then
                passed = passed + 1
            else
                failed = failed + 1
            end
            total_time = total_time + (result.duration or 0)
        end
        
        log('info', string.format('\nTest Summary:'))
        log('info', string.format('Total: %d', passed + failed))
        log('info', string.format('Passed: %d', passed))
        log('info', string.format('Failed: %d', failed))
        log('info', string.format('Total time: %.2fs', total_time))
        
        if failed > 0 then
            log('error', 'Some tests failed!')
        else
            log('info', 'All tests passed!')
        end
        
        return {
            total = passed + failed,
            passed = passed,
            failed = failed,
            total_time = total_time
        }
    end
    
    local function assert_equal(expected, actual, message)
        if expected ~= actual then
            error(message or string.format('Expected %s, got %s', 
                tostring(expected), tostring(actual)))
        end
    end
    
    local function assert_not_equal(expected, actual, message)
        if expected == actual then
            error(message or string.format('Expected not equal to %s', tostring(expected)))
        end
    end
    
    local function assert_true(value, message)
        if not value then
            error(message or 'Expected true')
        end
    end
    
    local function assert_false(value, message)
        if value then
            error(message or 'Expected false')
        end
    end
    
    local function assert_nil(value, message)
        if value ~= nil then
            error(message or 'Expected nil')
        end
    end
    
    local function assert_not_nil(value, message)
        if value == nil then
            error(message or 'Expected not nil')
        end
    end
    
    local function assert_error(callback, message)
        local ok, err = pcall(callback)
        if ok then
            error(message or 'Expected error')
        end
        return err
    end
    
    local function assert_almost_equal(expected, actual, epsilon, message)
        epsilon = epsilon or 0.001
        if math.abs(expected - actual) > epsilon then
            error(message or string.format('Expected %.4f, got %.4f (epsilon: %.4f)', 
                expected, actual, epsilon))
        end
    end
    
    return {
        describe = describe,
        run_all = run_all,
        run_suite = run_suite,
        get_results = function() return test_results end,
        clear_results = function() test_results = {} end,
        clear_tests = function() tests = {}; test_results = {} end,
        
        -- Assertions
        assert_equal = assert_equal,
        assert_not_equal = assert_not_equal,
        assert_true = assert_true,
        assert_false = assert_false,
        assert_nil = assert_nil,
        assert_not_nil = assert_not_nil,
        assert_error = assert_error,
        assert_almost_equal = assert_almost_equal,
        
        -- Aliases
        eq = assert_equal,
        ne = assert_not_equal,
        is_true = assert_true,
        is_false = assert_false,
        is_nil = assert_nil,
        is_not_nil = assert_not_nil,
        
        -- Async helpers
        wait_for = function(condition, timeout, interval)
            timeout = timeout or 5
            interval = interval or 0.1
            
            local start = os.clock()
            while os.clock() - start < timeout do
                if condition() then
                    return true
                end
                if y3 and y3.ltimer and y3.ltimer.wait then
                    y3.ltimer.wait(interval)
                else
                    os.execute('sleep ' .. tostring(interval))
                end
            end
            return false
        end
    }
end

function M.run_smoke_tests()
    local Test = M.create({ verbose = true })
    
    Test.describe('Core Systems', function(t)
        t.before_all(function()
            print('Setting up core systems tests...')
        end)
        
        t.it('DI Container should create instances', function()
            local DI = require 'core.di_container'
            local container = DI.create()
            
            container.register('test_service', function()
                return { value = 42 }
            end)
            
            local instance = container.get('test_service')
            Test.assert_equal(42, instance.value)
        end)
        
        t.it('Event Bus should publish and subscribe', function()
            local EventBus = require 'core.event_bus'
            local bus = EventBus.create()
            
            local received = nil
            bus.subscribe('test.event', function(payload)
                received = payload
            end)
            
            bus.publish('test.event', { data = 'hello' })
            Test.assert_not_nil(received)
            Test.assert_equal('hello', received.data)
        end)
        
        t.it('Config Manager should load and get values', function()
            local ConfigManager = require 'core.config_manager'
            local config = ConfigManager.create()
            
            config.load_from_table('test', {
                key1 = 'value1',
                key2 = 123
            })
            
            Test.assert_equal('value1', config.get('test.key1'))
            Test.assert_equal(123, config.get('test.key2'))
        end)
        
        t.it('Error Handler should log messages', function()
            local ErrorHandler = require 'core.error_handler'
            local handler = ErrorHandler.create({ log_level = 'DEBUG' })
            
            local ok, err = pcall(function()
                handler.assert(false, 'Test assertion')
            end)
            
            Test.assert_false(ok)
            Test.assert_not_nil(err)
        end)
        
        t.after_all(function()
            print('Cleaning up core systems tests...')
        end)
    end)
    
    return Test.run_all()
end

return M