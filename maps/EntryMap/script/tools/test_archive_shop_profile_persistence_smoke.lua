local source = assert(io.open('maps/EntryMap/script/ui/outgame.lua', 'r'))
local content = source:read('*a')
source:close()

assert(content:find('profile%.archive_items') ~= nil, 'expected archive shop items to persist in outgame profile')
assert(content:find('local function archive_item_profile_key') ~= nil, 'expected stable archive item profile keys')
assert(content:find("spec%.source == 'csv_shangchengdaojv_feature'") ~= nil, 'expected shangchengdaojv specs to be persisted')
assert(content:find('local function sync_archive_shop_specs_from_profile') ~= nil, 'expected profile to hydrate archive shop specs')
assert(content:find('local function persist_archive_shop_specs_to_profile') ~= nil, 'expected archive shop specs to be saved back to profile')
assert(content:find('persist_archive_items_state = persist_archive_shop_specs_to_profile') ~= nil, 'expected ArchiveShop options to expose persistence callback')
assert(content:find('sync_archive_shop_specs_from_profile%(load_profile%(%)%)') ~= nil, 'expected archive shop refresh to sync profile state')

local archive_source = assert(io.open('maps/EntryMap/script/ui/outgame_archive_shop.lua', 'r'))
local archive_content = archive_source:read('*a')
archive_source:close()

assert(archive_content:find('options%.persist_archive_items_state%(%)') ~= nil, 'expected archive actions to persist mutated item state')
assert(archive_content:find('local function handle_buy_action') ~= nil, 'expected buy action to mutate saved shop item state')
assert(archive_content:find('local function handle_use_action') ~= nil, 'expected use action to mutate saved shop item state')
assert(archive_content:find("spec%.owned_text = '已拥有'") ~= nil, 'expected non-stackable purchases to mark owned state')

print('archive shop profile persistence smoke passed')
