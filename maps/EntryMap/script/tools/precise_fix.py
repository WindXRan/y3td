# -*- coding: utf-8 -*-

# 读取文件
with open(r'd:\project\_codex_y3td_push\maps\EntryMap\script\ui\runtime_hud.lua', 'r', encoding='utf-8') as f:
    content = f.read()

# 修复被错误修改的 tostring(xxx or ') 回到 tostring(xxx or '')
content = content.replace("tostring(ac or ')", "tostring(ac or '')")
content = content.replace("tostring(bs.subtitle_text or ')", "tostring(bs.subtitle_text or '')")
content = content.replace("tostring(bs.cost_text or ')", "tostring(bs.cost_text or '')")
content = content.replace("tostring(bs.title_text or ')", "tostring(bs.title_text or '')")

# 修复其他被错误修改的地方
content = content.replace("string.format('%.1fs', cooldown_remaining) or ')", "string.format('%.1fs', cooldown_remaining) or ''")
content = content.replace("string.format('%.1f', cooldown_remaining) or ')", "string.format('%.1f', cooldown_remaining) or ''")

# 修复特定的未闭合字符串问题（只修复那些确实需要修复的）
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
