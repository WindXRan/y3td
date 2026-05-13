#!/usr/bin/env python3
"""
音频资源验证工具
检查 audio.lua 中使用的音频 ID 与 audio_resources.lua 配置是否一致
"""

from pathlib import Path
import re


ROOT = Path(__file__).resolve().parents[1]
AUDIO_PATH = ROOT / "runtime" / "audio.lua"
CONFIG_PATH = ROOT / "data" / "tables" / "audio_resources.lua"


def read_text(path: Path) -> str:
    return path.read_text(encoding="utf-8")


def extract_audio_ids_from_audio_lua(content: str) -> set:
    """
    从 audio.lua 中提取所有音频 ID
    """
    audio_ids = set()
    
    # 提取 LOCAL_AUDIO_IDS 中的 ID
    local_ids_pattern = r"(\d+)\s*[,}]"
    local_section = content.split("local LOCAL_AUDIO_IDS = {")[1].split("}")[0]
    for match in re.finditer(local_ids_pattern, local_section):
        audio_ids.add(match.group(1))
    
    # 提取所有字符串格式的音频 ID
    # 匹配 '12345' 格式的字符串
    string_ids_pattern = r"'(\d+)'"
    for match in re.finditer(string_ids_pattern, content):
        audio_ids.add(match.group(1))
    
    return audio_ids


def extract_audio_ids_from_config(content: str) -> set:
    """
    从 audio_resources.lua 中提取所有音频 ID
    """
    audio_ids = set()
    
    # 提取所有字符串格式的音频 ID
    string_ids_pattern = r"'(\d+)'"
    for match in re.finditer(string_ids_pattern, content):
        audio_ids.add(match.group(1))
    
    return audio_ids


def validate_audio_resources():
    """
    验证音频资源配置
    """
    print("=" * 60)
    print("音频资源验证工具")
    print("=" * 60)
    
    # 读取文件
    audio_content = read_text(AUDIO_PATH)
    config_content = read_text(CONFIG_PATH)
    
    # 提取音频 ID
    audio_lua_ids = extract_audio_ids_from_audio_lua(audio_content)
    config_ids = extract_audio_ids_from_config(config_content)
    
    print(f"\naudio.lua 中发现的音频 ID 数量: {len(audio_lua_ids)}")
    print(f"audio_resources.lua 中发现的音频 ID 数量: {len(config_ids)}")
    
    # 检查差异
    missing_in_config = audio_lua_ids - config_ids
    extra_in_config = config_ids - audio_lua_ids
    
    print("\n" + "-" * 60)
    print("检查结果:")
    print("-" * 60)
    
    if missing_in_config:
        print(f"\n❌ audio.lua 中有但配置文件中缺少的 ID ({len(missing_in_config)} 个):")
        for audio_id in sorted(missing_in_config):
            print(f"   - {audio_id}")
    else:
        print("\n✅ 所有 audio.lua 中的 ID 都在配置文件中")
    
    if extra_in_config:
        print(f"\n⚠️  配置文件中有但 audio.lua 中未使用的 ID ({len(extra_in_config)} 个):")
        for audio_id in sorted(extra_in_config):
            print(f"   - {audio_id}")
    else:
        print("\n✅ 配置文件中没有多余的 ID")
    
    # 输出完整清单
    print("\n" + "-" * 60)
    print("完整音频资源清单:")
    print("-" * 60)
    print("\n本地音频 ID:")
    # 从配置中提取 LOCAL_AUDIO_IDS 部分
    config_local_ids = []
    local_section = config_content.split("M.LOCAL_AUDIO_IDS = {")[1].split("}")[0]
    for match in re.finditer(r"(\w+)\s*=\s*'(\d+)'", local_section):
        name, audio_id = match.groups()
        config_local_ids.append((name, audio_id))
        print(f"  {name} = '{audio_id}'")
    
    print("\n回退音频 ID:")
    fallback_section = config_content.split("M.FALLBACK_IDS = {")[1].split("}")[0]
    for match in re.finditer(r"(\w+)\s*=\s*\{([^}]+)\}", fallback_section, re.DOTALL):
        category, ids_str = match.groups()
        ids = [id.strip().strip("'") for id in ids_str.split(",") if id.strip()]
        print(f"  {category}: {', '.join(ids)}")
    
    print("\n" + "=" * 60)
    
    if missing_in_config:
        return False
    return True


if __name__ == "__main__":
    success = validate_audio_resources()
    if success:
        print("\n✅ 音频资源验证通过！")
        exit(0)
    else:
        print("\n❌ 音频资源验证失败，请检查上述问题")
        exit(1)
