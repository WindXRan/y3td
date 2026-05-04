#!/usr/bin/env python
# -*- coding: utf-8 -*-

import json
import re
import socket
import struct
import time


def read_helper_port(port_file):
    """读取 Y3 Helper 端口"""
    try:
        with open(port_file, "r") as f:
            match = re.search(r"return\s*(\d+)", f.read())
            if match:
                return int(match.group(1))
    except Exception:
        pass
    return None


def send_command(port_file, command, args=None, timeout=5):
    """发送命令到 Y3 Helper 并等待响应"""
    port = read_helper_port(port_file)
    if not port:
        return None

    sock = None
    try:
        sock = socket.socket()
        sock.settimeout(timeout)
        sock.connect(("127.0.0.1", port))

        msg = {
            "method": "command",
            "id": 1,
            "params": {"command": command, "args": args or []},
        }
        data = json.dumps(msg).encode("utf-8")
        sock.send(struct.pack(">I", len(data)) + data)

        header = b""
        while len(header) < 4:
            chunk = sock.recv(4 - len(header))
            if not chunk:
                break
            header += chunk

        if len(header) < 4:
            return None

        length = struct.unpack(">I", header)[0]
        body = b""
        while len(body) < length:
            chunk = sock.recv(min(4096, length - len(body)))
            if not chunk:
                break
            body += chunk

        if len(body) < length:
            return None
        return json.loads(body.decode("utf-8"))
    except (socket.timeout, ConnectionRefusedError, Exception):
        return None
    finally:
        if sock is not None:
            try:
                sock.close()
            except Exception:
                pass


def send_continue(port_file):
    """发送 continue 命令恢复游戏"""
    port = read_helper_port(port_file)
    if not port:
        return False

    sock = None
    try:
        sock = socket.socket()
        sock.settimeout(3)
        sock.connect(("127.0.0.1", port))

        msg = {
            "method": "command",
            "id": 1,
            "params": {"command": "workbench.action.debug.continue", "args": []},
        }
        data = json.dumps(msg).encode("utf-8")
        sock.send(struct.pack(">I", len(data)) + data)
        time.sleep(0.3)
        return True
    except Exception:
        return False
    finally:
        if sock is not None:
            try:
                sock.close()
            except Exception:
                pass
