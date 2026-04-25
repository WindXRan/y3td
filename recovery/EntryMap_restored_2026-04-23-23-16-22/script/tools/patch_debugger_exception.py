#!/usr/bin/env python
# -*- coding: utf-8 -*-
"""
Patch Y3 Helper to write debugger exception events into %TEMP%/y3helper_messages.jsonl.
"""

import glob
import os
import shutil
from datetime import datetime


MSG_FILE = os.path.join(os.environ.get('TEMP', '/tmp'), 'y3helper_messages.jsonl')


def find_y3helper_extension():
    patterns = [
        os.path.expanduser("~/.cursor/extensions/sumneko.y3-helper-*"),
        os.path.expanduser("~/.vscode/extensions/sumneko.y3-helper-*"),
    ]
    for pattern in patterns:
        matches = glob.glob(pattern)
        if matches:
            return sorted(matches)[-1]
    return None


def patch_extension(ext_path):
    ext_js = os.path.join(ext_path, 'dist', 'extension.js')

    if not os.path.exists(ext_js):
        print(f'[错误] 找不到 extension.js: {ext_js}')
        return False

    with open(ext_js, 'r', encoding='utf-8') as f:
        content = f.read()

    if 'DEBUG_EXCEPTION_TRACKER' in content:
        print('[跳过] 调试异常捕获补丁已存在')
        return True

    backup_path = ext_js + f'.backup.exception.{datetime.now().strftime("%Y%m%d_%H%M%S")}'
    shutil.copy(ext_js, backup_path)
    print(f'[备份] {backup_path}')

    anchor = 'r.debug.registerDebugAdapterTrackerFactory("y3lua",c),'
    tracker_code = (
        'r.debug.registerDebugAdapterTrackerFactory("y3lua",c),'
        'r.debug.registerDebugAdapterTrackerFactory("y3lua",{createDebugAdapterTracker:function(session){'
        'return{onDidSendMessage:function(msg){'
        'if(msg&&msg.type==="event"&&msg.event==="stopped"&&msg.body&&msg.body.reason==="exception"){'
        'try{'
        'const fs=require("fs");'
        'const path=require("path");'
        'const msgFile=path.join(process.env.TEMP||"/tmp","y3helper_messages.jsonl");'
        'const data=JSON.stringify({type:"exception",level:"error",message:msg.body.text||"Unknown exception",description:msg.body.description||"",threadId:msg.body.threadId,timestamp:new Date().toISOString()})+"\\n";'
        'fs.appendFileSync(msgFile,data)'
        '}catch(err){}'
        '}'
        '}}'
        '}}),/* DEBUG_EXCEPTION_TRACKER */'
    )

    if anchor not in content:
        print('[错误] 找不到调试追踪注入点，可能插件版本不兼容')
        return False

    content = content.replace(anchor, tracker_code, 1)
    with open(ext_js, 'w', encoding='utf-8') as f:
        f.write(content)

    print('[成功] 调试异常捕获补丁已应用')
    print(f'[提示] 异常消息将写入 {MSG_FILE}')
    print('[提示] 请重启 VSCode/Cursor 使补丁生效')
    return True


def main():
    print('Y3 Helper 调试异常捕获补丁')
    print('=' * 50)

    ext_path = find_y3helper_extension()
    if not ext_path:
        print('[错误] 找不到 Y3 Helper 扩展')
        return

    print(f'[找到] {ext_path}')
    patch_extension(ext_path)


if __name__ == '__main__':
    main()
