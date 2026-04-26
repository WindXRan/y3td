-- 游戏启动后会自动运行此文件

y3.config.sync.mouse = true

if y3.game.is_debug_mode() then
  y3.config.log.toGame = false
  y3.config.log.level = 'debug'
else
  y3.config.log.toGame = false
  y3.config.log.level = 'info'
end

local runtime
local runtime_load_attempted = false
local bootstrapped = false

local function load_runtime()
  if runtime_load_attempted then
    return runtime
  end

  runtime_load_attempted = true

  local ok, result = xpcall(function()
    return require 'entry_runtime'
  end, debug.traceback)

  if not ok then
    print('[EntryMap] failed to require entry_runtime:\n' .. tostring(result))
    return nil
  end

  runtime = result
  return runtime
end

local function bootstrap_once()
  if bootstrapped then
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

  bootstrapped = true

  local ok, err = xpcall(function()
    loaded_runtime.bootstrap()
  end, debug.traceback)

  if not ok then
    bootstrapped = false
    print('[EntryMap] runtime.bootstrap failed:\n' .. tostring(err))
    return
  end
end

y3.game:event('游戏-初始化', function()
  bootstrap_once()
end)

y3.ltimer.wait(0, function()
  bootstrap_once()
end)

include '可重载的代码'
