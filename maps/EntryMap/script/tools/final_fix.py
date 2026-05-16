# -*- coding: utf-8 -*-

# 读取文件
with open(r'd:\project\_codex_y3td_push\maps\EntryMap\script\ui\runtime_hud.lua', 'r', encoding='utf-8') as f:
    content = f.read()

# 修复所有剩余问题
content = content.replace("''", "'")  # 移除重复的单引号

# 修复特定的未闭合字符串
content = content.replace("bt[#bt + 1] = '当前属性增幅'", "bt[#bt + 1] = '当前属性增幅'")
content = content.replace("set_body_lines = #attr_lines > 0 and attr_lines or { '当前无直接属性增幅' },", "set_body_lines = #attr_lines > 0 and attr_lines or { '当前无直接属性增幅' },")
content = content.replace("local bt = { '[左键点击]', '打开存档面板；如果当前没有可打开的存档界面，则显示运行时状态' }", "local bt = { '[左键点击]', '打开存档面板；如果当前没有可打开的存档界面，则显示运行时状态' }")
content = content.replace("tip_title = tostring(slot_data.name or slot_data.id or '技能'),", "tip_title = tostring(slot_data.name or slot_data.id or '技能'),")
content = content.replace("tip_text = #tip_lines > 0 and table.concat(tip_lines, '\\n') or '当前没有技能说明'", "tip_text = #tip_lines > 0 and table.concat(tip_lines, '\\n') or '当前没有技能说明'")
content = content.replace("return '操作提示', 'F 抽卡，如何变强查看英雄图鉴，H 查看英雄功能，P 打开存档'", "return '操作提示', 'F 抽卡，如何变强查看英雄图鉴，H 查看英雄功能，P 打开存档'")
content = content.replace("title = tostring(bM.item_name_text or bs.title or '羁绊'),", "title = tostring(bM.item_name_text or bs.title or '羁绊'),")
content = content.replace("title = tostring(c4.tip_title or c4.name or '英雄技能'),", "title = tostring(c4.tip_title or c4.name or '英雄技能'),")
content = content.replace("join_or_default({ tip_lines[1], tip_lines[2] }, '当前没有技能说明')", "join_or_default({ tip_lines[1], tip_lines[2] }, '当前没有技能说明')")
content = content.replace("c4.stack_text and c4.stack_text ~= '' and ('计数' .. tostring(c4.stack_text)) or ''", "c4.stack_text and c4.stack_text ~= '' and ('计数' .. tostring(c4.stack_text)) or ''")

# 保存修复后的文件
with open(r'd:\project\_codex_y3td_push\maps\EntryMap\script\ui\runtime_hud.lua', 'w', encoding='utf-8') as f:
    f.write(content)

print('修复完成')

# 验证
with open(r'd:\project\_codex_y3td_push\maps\EntryMap\script\ui\runtime_hud.lua', 'r', encoding='utf-8') as f:
    content = f.read()

unclosed = []
for i, line in enumerate(content.split('\n'), 1):
    if line.count("'") % 2 != 0:
        unclosed.append((i, line.strip()[:50]))

if unclosed:
    print(f'仍有 {len(unclosed)} 个问题')
    for num, snippet in unclosed[:5]:
        print(f'  第{num}行: {snippet}')
else:
    print('✓ 所有字符串已正确闭合')
