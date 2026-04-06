#!/usr/bin/env python
# -*- coding: utf-8 -*-
"""
Install a y3-helper.runLua command into the Y3 Helper VSCode/Cursor extension.
"""

import os
import sys


def find_extension():
    possible_bases = []

    if sys.platform == 'win32':
        user_home = os.path.expanduser("~")
        possible_bases.extend([
            os.path.join(user_home, ".cursor", "extensions"),
            os.path.join(user_home, ".vscode", "extensions"),
        ])
    else:
        for drive in ["/mnt/c", "/mnt/d"]:
            if not os.path.exists(drive):
                continue
            users_dir = os.path.join(drive, "Users")
            if not os.path.exists(users_dir):
                continue
            for user in os.listdir(users_dir):
                user_path = os.path.join(users_dir, user)
                if not os.path.isdir(user_path):
                    continue
                possible_bases.append(os.path.join(user_path, ".cursor", "extensions"))
                possible_bases.append(os.path.join(user_path, ".vscode", "extensions"))

    for base in possible_bases:
        if not os.path.exists(base):
            continue
        for name in os.listdir(base):
            if not name.startswith("sumneko.y3-helper"):
                continue
            ext_path = os.path.join(base, name, "dist", "extension.js")
            if os.path.exists(ext_path):
                return ext_path

    return None


def install_runlua(ext_path):
    print(f"[INFO] 找到插件: {ext_path}")

    with open(ext_path, 'r', encoding='utf-8') as f:
        content = f.read()

    if 'y3-helper.runLua' in content:
        print("[OK] runLua 命令已存在，无需重复安装")
        return True

    backup_path = ext_path + '.backup'
    if not os.path.exists(backup_path):
        with open(backup_path, 'w', encoding='utf-8') as f:
            f.write(content)
        print(f"[INFO] 已备份到: {backup_path}")

    replacements = [
        (
            'a.commands.registerCommand("y3-helper.reloadLua",(async()=>{for(let e of g.allClients)e.notify("command",{data:".rd"})}))',
            'a.commands.registerCommand("y3-helper.reloadLua",(async()=>{for(let e of g.allClients)e.notify("command",{data:".rd"})})),a.commands.registerCommand("y3-helper.runLua",(async(code)=>{for(let e of g.allClients)e.notify("command",{data:code})}))',
        ),
        (
            'registerCommand("y3-helper.reloadLua",(async()=>{for(let e of d.allClients)e.notify("command",{data:".rd"})}))',
            'registerCommand("y3-helper.reloadLua",(async()=>{for(let e of d.allClients)e.notify("command",{data:".rd"})})),r.commands.registerCommand("y3-helper.runLua",(async(code)=>{for(let e of d.allClients)e.notify("command",{data:code})}))',
        ),
    ]

    for old_code, new_code in replacements:
        if old_code not in content:
            continue
        content = content.replace(old_code, new_code, 1)
        with open(ext_path, 'w', encoding='utf-8') as f:
            f.write(content)
        print("[OK] runLua 命令安装成功")
        print("=" * 50)
        print("请重启 VSCode/Cursor 使修改生效")
        print("=" * 50)
        return True

    print("[ERROR] 找不到 reloadLua 命令，可能插件版本不兼容")
    return False


def main():
    print("=" * 50)
    print("Y3 Helper runLua 命令安装工具")
    print("=" * 50)
    print("")

    ext_path = find_extension()

    if not ext_path:
        print("[ERROR] 找不到 Y3 Helper 插件")
        print("请确认已安装 Y3 Helper 插件 (sumneko.y3-helper)")
        return 1

    return 0 if install_runlua(ext_path) else 1


if __name__ == '__main__':
    sys.exit(main())
