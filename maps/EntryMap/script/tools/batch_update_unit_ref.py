import json
import os

# 配置
EDITOR_UNIT_DIR = r'c:\Y3TD\Y3GPT\y3td\maps\EntryMap\editor_table\editorunit'

# 模板ID
HERO_TEMPLATE_ID = 134245850
CREATURE_TEMPLATE_ID = 134278989

# 英雄单位ID范围
HERO_UNIT_IDS = list(range(100001, 100032))  # 100001-100031
# 生物单位ID范围
CREATURE_UNIT_IDS = [200001]
# 波次单位
WAVE_UNITS = [134229682, 134248910]

def modify_unit_file(file_path, template_id):
    """修改单位文件引用指定模板，保留模型"""
    with open(file_path, 'r', encoding='utf-8') as f:
        data = json.load(f)
    
    # 保存原始模型ID
    original_model = data.get('model', 0)
    original_icon = data.get('icon', 0)
    original_name = data.get('name', '')
    original_description = data.get('description', '')
    
    # 读取模板文件
    template_path = os.path.join(EDITOR_UNIT_DIR, f'{template_id}.json')
    with open(template_path, 'r', encoding='utf-8') as f:
        template_data = json.load(f)
    
    # 复制模板数据
    new_data = template_data.copy()
    
    # 保留原始模型、图标、名称、描述
    new_data['model'] = original_model
    new_data['icon'] = original_icon
    new_data['name'] = original_name
    new_data['description'] = original_description
    
    # 更新引用ID为当前文件的key
    file_name = os.path.basename(file_path)
    unit_key = int(file_name.replace('.json', ''))
    new_data['_ref_'] = unit_key
    new_data['key'] = unit_key
    new_data['uid'] = str(unit_key)
    
    # 写回文件
    with open(file_path, 'w', encoding='utf-8') as f:
        json.dump(new_data, f, ensure_ascii=False, indent=4)
    
    print(f'修改完成: {file_name} -> 引用模板 {template_id}, 模型: {original_model}')

def main():
    print('=== 批量修改单位物编引用 ===')
    
    # 修改英雄单位
    print('\n1. 修改英雄单位(引用英雄模板)')
    for unit_id in HERO_UNIT_IDS:
        file_path = os.path.join(EDITOR_UNIT_DIR, f'{unit_id}.json')
        if os.path.exists(file_path):
            modify_unit_file(file_path, HERO_TEMPLATE_ID)
    
    # 修改生物单位
    print('\n2. 修改生物单位(引用生物模板)')
    for unit_id in CREATURE_UNIT_IDS:
        file_path = os.path.join(EDITOR_UNIT_DIR, f'{unit_id}.json')
        if os.path.exists(file_path):
            modify_unit_file(file_path, CREATURE_TEMPLATE_ID)
    
    # 修改波次单位 - 需要判断是英雄还是生物模板
    print('\n3. 修改波次单位')
    for unit_id in WAVE_UNITS:
        file_path = os.path.join(EDITOR_UNIT_DIR, f'{unit_id}.json')
        if os.path.exists(file_path):
            # 读取原始文件判断类型
            with open(file_path, 'r', encoding='utf-8') as f:
                data = json.load(f)
            # 根据blood_bar判断模板类型
            blood_bar = data.get('blood_bar', 0)
            if blood_bar == 327681:  # 英雄血条
                modify_unit_file(file_path, HERO_TEMPLATE_ID)
            else:  # 生物血条
                modify_unit_file(file_path, CREATURE_TEMPLATE_ID)
    
    print('\n=== 修改完成 ===')

if __name__ == '__main__':
    main()