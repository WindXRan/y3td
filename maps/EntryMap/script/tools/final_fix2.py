# -*- coding: utf-8 -*-
import re

# 读取文件
with open(r'd:\project\_codex_y3td_push\maps\EntryMap\script\ui\runtime_hud.lua', 'r', encoding='utf-8') as f:
    content = f.read()

# 修复特定的重复单引号问题（只修复 'xxx'' 这种模式，不修复 ~= ''）
content = content.replace("属性增幅''", "属性增幅'")
content = content.replace("存档''", "存档'")
content = content.replace("技能''", "技能'")
content = content.replace("说明''", "说明'")
content = content.replace("羁绊''", "羁绊'")
content = content.replace("事件''", "事件'")
content = content.replace("词缀''", "词缀'")

# 修复其他问题
content = content.replace("'当前无直接属性增幅),", "'当前无直接属性增幅'),")
content = content.replace("'10 级会进入一次词缀选择，选择完成后可继续升级,", "'10 级会进入一次词缀选择，选择完成后可继续升级',")
content = content.replace("'悬停装备栏成长武器时实时读取当前等级、费用、属性和词缀", "'悬停装备栏成长武器时实时读取当前等级、费用、属性和词缀'")

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
