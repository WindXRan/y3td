# -*- coding: utf-8 -*-

# 读取文件
with open(r'd:\project\_codex_y3td_push\maps\EntryMap\script\ui\runtime_hud.lua', 'r', encoding='utf-8') as f:
    content = f.read()

# 恢复被错误修改的 ~= ' 回到 ~= ''
content = content.replace("~= ' ", "~= '' ")
content = content.replace("~= ' and", "~= '' and")
content = content.replace("~= ',", "~= '',")
content = content.replace("~= ')", "~= '')")
content = content.replace("~= '\n", "~= ''\n")

# 恢复其他被错误修改的模式
content = content.replace("= ' end;", "= '' end;")
content = content.replace("= ' then", "= '' then")
content = content.replace("and ' then", "and '' then")
content = content.replace("or ' then", "or '' then")

# 现在修复真正需要修复的问题
content = content.replace("属性增幅''", "属性增幅'")
content = content.replace("存档''", "存档'")
content = content.replace("技能''", "技能'")
content = content.replace("说明''", "说明'")
content = content.replace("羁绊''", "羁绊'")
content = content.replace("事件''", "事件'")
content = content.replace("词缀''", "词缀'")

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
