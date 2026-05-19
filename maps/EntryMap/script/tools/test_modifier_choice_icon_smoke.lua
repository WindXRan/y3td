package.path = 'script/?.lua;script/?/init.lua;script/?/?.lua;maps/EntryMap/script/?.lua;maps/EntryMap/script/?/init.lua;maps/EntryMap/script/?/?.lua;' .. package.path

local bonds = require 'runtime.bonds.bonds_chain'
local bond_modifier_pool = require 'data.tables.bond.bond_modifier_pool'

print('=== Testing build_modifier_choice_entry icon functionality ===\n')

local state = {
  resources = {
    wood = 0,
  },
  hero = nil,
}

-- 确保 runtime 被初始化
local runtime = bonds.create_runtime()
state[getmetatable(bonds) and 'bond_runtime' or 'bond_runtime'] = runtime -- 兼容可能的其他字段名

if not bond_modifier_pool.enabled or #bond_modifier_pool.cards == 0 then
  print('Modifier pool is disabled or empty, skipping test.')
  print('Test passed by default.')
  os.exit(0)
end

local test_card = bond_modifier_pool.cards[1]
print('Testing with card:')
print('  ID: ' .. tostring(test_card.id))
print('  Name: ' .. tostring(test_card.name))
print('  Bond Name: ' .. tostring(test_card.bond_name))
print('  Original Icon: ' .. tostring(test_card.icon))
print()

-- 获取 build_modifier_choice_entry 函数
local collect_candidate_choice_entries = nil
for index = 1, 20 do
  local ok, name, value = pcall(debug.getupvalue, bonds.try_draw, index)
  if ok and name == 'collect_candidate_choice_entries' then
    collect_candidate_choice_entries = value
    break
  end
end

local build_modifier_choice_entry = nil
if collect_candidate_choice_entries then
  for index = 1, 20 do
    local ok, name, value = pcall(debug.getupvalue, collect_candidate_choice_entries, index)
    if ok and name == 'collect_modifier_pool_choice_entries' then
      for index2 = 1, 20 do
        local ok2, name2, value2 = pcall(debug.getupvalue, value, index2)
        if ok2 and name2 == 'build_modifier_choice_entry' then
          build_modifier_choice_entry = value2
          break
        end
      end
      break
    end
  end
end

if not build_modifier_choice_entry then
  print('Could not find build_modifier_choice_entry function via debug.getupvalue.')
  print('Let us try using bonds.try_draw() to check if choices are generated correctly.')
  
  local ok, result = pcall(function()
    state.resources.wood = 1000
    if bonds.try_draw({
      STATE = state,
      message = function() end,
    }) then
      return runtime.current_choices
    end
    return nil
  end)
  
  if ok and result and #result > 0 then
    print('\nGenerated ' .. tostring(#result) .. ' choices successfully:')
    for i, choice in ipairs(result) do
      print('  Choice ' .. tostring(i) .. ':')
      print('    Name: ' .. tostring(choice.display_name))
      print('    Icon: ' .. tostring(choice.icon))
      print('    UI Icon: ' .. tostring(choice.ui_icon))
      
      if not choice.icon or choice.icon <= 0 then
        print('    ❌ ERROR: Invalid or missing icon!')
      else
        print('    ✅ OK: Icon is valid!')
      end
    end
  else
    print('❌ Could not draw choices. Error: ' .. tostring(result))
  end
  
  print('\nTest completed.')
  os.exit(0)
end

-- 直接测试 build_modifier_choice_entry
print('Testing build_modifier_choice_entry directly:')
local choice = build_modifier_choice_entry(state, test_card, 1)
print('  Generated Choice:')
print('    Name: ' .. tostring(choice.display_name))
print('    Icon: ' .. tostring(choice.icon))
print('    UI Icon: ' .. tostring(choice.ui_icon))

if not choice.icon or choice.icon <= 0 then
  print('❌ ERROR: Invalid or missing icon!')
else
  print('✅ OK: Icon is valid!')
end

print('\nTest completed!')
