#!/usr/bin/env python3
"""
提取中断向量表中所有merge关系的脚本
分析comment列，识别所有merge源和目标的映射关系
"""

import csv
import re
from pathlib import Path

def extract_merge_relationships(csv_file_path):
    """提取所有merge关系"""
    
    merge_relationships = {}
    detailed_merge_info = []
    
    try:
        with open(csv_file_path, 'r', encoding='utf-8-sig') as csvfile:
            reader = csv.reader(csvfile)
            header = next(reader)
            
            # 找到comment列的索引
            comment_idx = -1
            for i, col in enumerate(header):
                if 'comment' in col.lower():
                    comment_idx = i
                    break
            
            current_group = ""
            
            for row_num, row in enumerate(reader, start=2):
                if not row or len(row) <= comment_idx:
                    continue
                
                # 检查是否是组标题行
                if len(row) > 0 and "中断源" in row[0] and not row[1].strip():
                    current_group = row[0].strip()
                    continue
                
                # 跳过空行或无效行
                if not row[1].strip() or not row[2].strip():
                    continue
                
                interrupt_name = row[2].strip()
                comment = row[comment_idx].strip() if comment_idx < len(row) else ""
                
                # 分析merge关系
                if comment:
                    merge_info = analyze_merge_relationship(interrupt_name, comment, current_group)
                    if merge_info:
                        detailed_merge_info.append(merge_info)
                        
                        # 构建merge关系映射
                        if merge_info['type'] == 'source':
                            target = merge_info['target']
                            if target not in merge_relationships:
                                merge_relationships[target] = []
                            merge_relationships[target].append(interrupt_name)
                        elif merge_info['type'] == 'complex_target':
                            # 处理复杂的merge目标（如iosub_slv_err_intr包含多个源）
                            if interrupt_name not in merge_relationships:
                                merge_relationships[interrupt_name] = []
                            merge_relationships[interrupt_name].extend(merge_info['sources'])
    
    except Exception as e:
        print(f"读取CSV文件时出错: {e}")
        return {}, []
    
    return merge_relationships, detailed_merge_info

def analyze_merge_relationship(interrupt_name, comment, group):
    """分析单个中断的merge关系"""

    # 检查是否包含merge关键词
    if not any(keyword in comment for keyword in ['merge', 'Merge', '合并', '汇聚']):
        return None

    # 分析不同类型的merge关系

    # 1. 特殊处理：iosub_slv_err_intr包含多个源
    if 'merge了如下源' in comment:
        sources = extract_sources_from_description(comment)
        return {
            'name': interrupt_name,
            'group': group,
            'type': 'complex_target',
            'sources': sources,
            'description': comment
        }

    # 2. merge到iosub_normal_int相关
    if 'merge到' in comment and 'iosub_normal_int' in comment:
        return {
            'name': interrupt_name,
            'group': group,
            'type': 'source',
            'target': 'iosub_normal_intr',
            'description': comment
        }

    # 3. merge到iosub_slv_err_intr
    if 'merge到iosub_slv_err_intr' in comment:
        return {
            'name': interrupt_name,
            'group': group,
            'type': 'source',
            'target': 'iosub_slv_err_intr',
            'description': comment
        }

    # 4. merge到iosub ras中断
    if 'merge到iosub ras' in comment:
        if 'cri' in comment or 'CRI' in comment:
            target = 'iosub_ras_cri_intr'
        elif 'eri' in comment or 'ERI' in comment:
            target = 'iosub_ras_eri_intr'
        elif 'fhi' in comment or 'FHI' in comment or '2bit error' in comment:
            target = 'iosub_ras_fhi_intr'
        else:
            target = 'iosub_ras_intr'

        return {
            'name': interrupt_name,
            'group': group,
            'type': 'source',
            'target': target,
            'description': comment
        }

    # 5. merge到iosub_abnormal_0_intr
    if 'merge到iosub_abnormal_0_intr' in comment:
        return {
            'name': interrupt_name,
            'group': group,
            'type': 'source',
            'target': 'iosub_abnormal_0_intr',
            'description': comment
        }

    # 6. PLL相关merge (已经在现有代码中实现)
    if any(pll_type in comment for pll_type in ['PLL', 'pll']) and 'merge成' in comment:
        if 'lock' in comment:
            target = 'merge_pll_intr_lock'
        elif 'unlock' in comment:
            target = 'merge_pll_intr_unlock'
        elif 'frechangedone' in comment:
            target = 'merge_pll_intr_frechangedone'
        elif 'frechange_tot_done' in comment:
            target = 'merge_pll_intr_frechange_tot_done'
        elif 'intdocfrac_err' in comment:
            target = 'merge_pll_intr_intdocfrac_err'
        else:
            target = 'merge_pll_intr_general'

        return {
            'name': interrupt_name,
            'group': group,
            'type': 'source',
            'target': target,
            'description': comment
        }

    # 7. 通用merge处理
    if any(keyword in comment for keyword in ['merge', 'Merge']):
        return {
            'name': interrupt_name,
            'group': group,
            'type': 'general_merge',
            'description': comment
        }

    return None

def extract_sources_from_description(description):
    """从描述中提取源中断列表"""
    sources = []
    
    # 查找编号列表格式的源 (如: 1）source1 2）source2)
    pattern = r'\d+[）)]\s*(\w+)'
    matches = re.findall(pattern, description)
    sources.extend(matches)
    
    return sources

def generate_systemverilog_merge_logic(merge_relationships):
    """生成SystemVerilog merge逻辑代码"""
    
    sv_code = []
    
    # 为每个merge目标生成case分支
    for target, sources in merge_relationships.items():
        if not sources:
            continue
            
        sv_code.append(f'            "{target}": begin')
        sv_code.append(f'                // Collect all interrupts that should be merged into {target}')
        sv_code.append('                foreach (interrupt_map[i]) begin')
        
        # 构建条件语句
        conditions = []
        for source in sources:
            conditions.append(f'interrupt_map[i].name == "{source}"')
        
        if conditions:
            condition_str = ' ||\n                        '.join(conditions)
            sv_code.append(f'                    if ({condition_str}) begin')
            sv_code.append('                        sources.push_back(interrupt_map[i]);')
            sv_code.append('                    end')
        
        sv_code.append('                end')
        sv_code.append('            end')
        sv_code.append('')
    
    return '\n'.join(sv_code)

def print_merge_analysis(merge_relationships, detailed_merge_info):
    """打印merge关系分析结果"""
    
    print("=" * 80)
    print("中断Merge关系分析结果")
    print("=" * 80)
    
    print(f"\n1. 发现的Merge目标中断 ({len(merge_relationships)}个):")
    print("-" * 60)
    for target, sources in merge_relationships.items():
        print(f"• {target}")
        print(f"  源中断数量: {len(sources)}")
        for source in sources:
            print(f"    - {source}")
        print()
    
    print(f"\n2. 详细Merge信息 ({len(detailed_merge_info)}个):")
    print("-" * 60)
    for info in detailed_merge_info:
        print(f"• {info['name']} ({info['group']})")
        print(f"  类型: {info['type']}")
        if info['type'] == 'source':
            print(f"  目标: {info.get('target', 'N/A')}")
        elif info['type'] == 'complex_source':
            print(f"  包含源: {info.get('sources', [])}")
        print(f"  描述: {info['description'][:100]}...")
        print()

if __name__ == "__main__":
    csv_file = "中断向量表-iosub-V0.5.csv"
    if Path(csv_file).exists():
        merge_relationships, detailed_merge_info = extract_merge_relationships(csv_file)
        
        print_merge_analysis(merge_relationships, detailed_merge_info)
        
        print("\n" + "=" * 80)
        print("生成的SystemVerilog Merge逻辑代码")
        print("=" * 80)
        print(generate_systemverilog_merge_logic(merge_relationships))
        
    else:
        print(f"错误：找不到文件 {csv_file}")
