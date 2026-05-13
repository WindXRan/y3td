# -*- coding: utf-8 -*-

# 读取文件
with open(r'd:\project\_codex_y3td_push\maps\EntryMap\script\ui\runtime_hud.lua', 'r', encoding='utf-8') as f:
    content = f.read()

# 修复所有 subtitle = ', 类型的问题
content = content.replace("subtitle = ',", "subtitle = '',")
content = content.replace("icon_name = ',", "icon_name = '',")
content = content.replace("body = ',", "body = '',")
content = content.replace("title = ',", "title = '',")

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
    for num, snippet in unclosed[:10]:
        print(f'  第{num}行: {snippet}')
else:
    print('✓ 所有字符串已正确闭合')
