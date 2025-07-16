#!/usr/bin/env python3
"""
分析中断向量表CSV文件中的comment列信息
筛选出包含特殊处理说明的中断信号，并分析是否已在环境中被建模
"""

import csv
import re
from pathlib import Path

def analyze_interrupt_comments(csv_file_path):
    """分析中断向量表中的comment列信息"""
    
    # 存储分析结果
    special_handling_interrupts = []
    merge_interrupts = []
    routing_specific_interrupts = []
    modeling_status = {}
    
    try:
        with open(csv_file_path, 'r', encoding='utf-8-sig') as csvfile:
            reader = csv.reader(csvfile)
            header = next(reader)  # 获取表头
            
            # 找到comment列的索引
            comment_idx = -1
            for i, col in enumerate(header):
                if 'comment' in col.lower():
                    comment_idx = i
                    break
            
            if comment_idx == -1:
                print("错误：未找到comment列")
                return
            
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
                
                # 分析comment内容
                if comment:
                    analysis = analyze_comment_content(interrupt_name, comment, current_group)
                    if analysis:
                        if analysis['type'] == 'merge':
                            merge_interrupts.append(analysis)
                        elif analysis['type'] == 'routing':
                            routing_specific_interrupts.append(analysis)
                        elif analysis['type'] == 'special':
                            special_handling_interrupts.append(analysis)
    
    except Exception as e:
        print(f"读取CSV文件时出错: {e}")
        return
    
    # 输出分析结果
    print("=" * 80)
    print("中断向量表Comment列分析报告")
    print("=" * 80)
    
    print(f"\n1. 包含Merge处理的中断 ({len(merge_interrupts)}个):")
    print("-" * 50)
    for intr in merge_interrupts:
        print(f"• {intr['name']} ({intr['group']})")
        print(f"  处理方式: {intr['description']}")
        print(f"  建模状态: {check_modeling_status(intr['name'], intr['description'])}")
        print()
    
    print(f"\n2. 包含特殊路由处理的中断 ({len(routing_specific_interrupts)}个):")
    print("-" * 50)
    for intr in routing_specific_interrupts:
        print(f"• {intr['name']} ({intr['group']})")
        print(f"  处理方式: {intr['description']}")
        print(f"  建模状态: {check_modeling_status(intr['name'], intr['description'])}")
        print()
    
    print(f"\n3. 其他特殊处理的中断 ({len(special_handling_interrupts)}个):")
    print("-" * 50)
    for intr in special_handling_interrupts:
        print(f"• {intr['name']} ({intr['group']})")
        print(f"  处理方式: {intr['description']}")
        print(f"  建模状态: {check_modeling_status(intr['name'], intr['description'])}")
        print()
    
    # 总结建模状态
    print("\n4. 建模状态总结:")
    print("-" * 50)
    all_interrupts = merge_interrupts + routing_specific_interrupts + special_handling_interrupts

    needs_modeling = []
    partially_modeled = []
    fully_modeled = []

    for intr in all_interrupts:
        status = check_modeling_status(intr['name'], intr['description'])
        if "需要建模" in status:
            needs_modeling.append(intr['name'])
        elif "部分建模" in status:
            partially_modeled.append(intr['name'])
        else:
            fully_modeled.append(intr['name'])

    print(f"需要建模的中断: {len(needs_modeling)}个")
    for name in needs_modeling:
        print(f"  - {name}")

    print(f"\n部分建模的中断: {len(partially_modeled)}个")
    for name in partially_modeled:
        print(f"  - {name}")

    print(f"\n已完全建模的中断: {len(fully_modeled)}个")
    for name in fully_modeled:
        print(f"  - {name}")

    # 生成详细的建模需求报告
    generate_detailed_modeling_report(all_interrupts)

def analyze_comment_content(interrupt_name, comment, group):
    """分析comment内容，识别特殊处理类型"""
    
    if not comment:
        return None
    
    # 检查是否包含merge相关处理
    merge_keywords = ['merge', 'Merge', 'MERGE', '合并', '汇聚', '聚合']
    if any(keyword in comment for keyword in merge_keywords):
        return {
            'name': interrupt_name,
            'group': group,
            'type': 'merge',
            'description': comment,
            'keywords': [kw for kw in merge_keywords if kw in comment]
        }
    
    # 检查是否包含特殊路由处理
    routing_keywords = ['送给', '送到', '路由', '分发', '直连', '额外', '单独送', '选择可配置']
    if any(keyword in comment for keyword in routing_keywords):
        return {
            'name': interrupt_name,
            'group': group,
            'type': 'routing',
            'description': comment,
            'keywords': [kw for kw in routing_keywords if kw in comment]
        }
    
    # 检查其他特殊处理
    special_keywords = ['原始为脉冲', '同步之后', '经过', '处理得到', '变成电平', '可配安全属性', 
                       '支持从', '选择送', 'tie 0', '不单独送', '概率', '使用概览']
    if any(keyword in comment for keyword in special_keywords):
        return {
            'name': interrupt_name,
            'group': group,
            'type': 'special',
            'description': comment,
            'keywords': [kw for kw in special_keywords if kw in comment]
        }
    
    return None

def check_modeling_status(interrupt_name, description):
    """检查中断的建模状态"""
    
    # 检查是否涉及merge逻辑
    if any(keyword in description for keyword in ['merge', 'Merge', '合并', '汇聚']):
        # 检查是否提到了具体的merge源
        if '包含了' in description or '源：' in description or 'merge了如下源' in description:
            return "需要建模 - 需要实现merge逻辑和源信号追踪"
        else:
            return "部分建模 - merge逻辑需要完善"
    
    # 检查是否涉及特殊路由
    if any(keyword in description for keyword in ['送给', '送到', '路由', '分发']):
        if '可配置' in description or '选择' in description:
            return "需要建模 - 需要实现可配置路由逻辑"
        elif '额外' in description or '单独' in description:
            return "需要建模 - 需要实现额外路由路径"
        else:
            return "部分建模 - 基本路由已实现，特殊路由需要验证"
    
    # 检查是否涉及信号处理
    if any(keyword in description for keyword in ['原始为脉冲', '变成电平', '同步之后', '经过', '处理得到']):
        return "需要建模 - 需要实现信号处理逻辑"
    
    # 检查是否涉及安全属性配置
    if '可配安全属性' in description:
        return "需要建模 - 需要实现安全属性配置"
    
    # 检查是否涉及tie操作
    if 'tie 0' in description:
        return "已建模 - tie操作相对简单"
    
    # 检查是否明确说明不单独送出
    if '不单独送' in description:
        return "已建模 - 在merge逻辑中处理"
    
    return "需要验证 - 特殊处理逻辑需要确认"

def generate_detailed_modeling_report(all_interrupts):
    """生成详细的建模需求报告"""

    print("\n" + "=" * 80)
    print("详细建模需求分析报告")
    print("=" * 80)

    # 按类型分组分析
    merge_logic_needed = []
    routing_logic_needed = []
    signal_processing_needed = []
    config_logic_needed = []

    for intr in all_interrupts:
        desc = intr['description']

        # 分析merge逻辑需求
        if any(keyword in desc for keyword in ['merge', 'Merge', '合并', '汇聚']):
            merge_details = extract_merge_details(desc)
            if merge_details:
                merge_logic_needed.append({
                    'name': intr['name'],
                    'group': intr['group'],
                    'details': merge_details
                })

        # 分析路由逻辑需求
        if any(keyword in desc for keyword in ['送给', '送到', '路由', '分发', '可配置', '选择']):
            routing_details = extract_routing_details(desc)
            if routing_details:
                routing_logic_needed.append({
                    'name': intr['name'],
                    'group': intr['group'],
                    'details': routing_details
                })

        # 分析信号处理需求
        if any(keyword in desc for keyword in ['原始为脉冲', '变成电平', '同步', '处理得到']):
            signal_details = extract_signal_processing_details(desc)
            if signal_details:
                signal_processing_needed.append({
                    'name': intr['name'],
                    'group': intr['group'],
                    'details': signal_details
                })

        # 分析配置逻辑需求
        if any(keyword in desc for keyword in ['可配', '配置', '选择']):
            config_details = extract_config_details(desc)
            if config_details:
                config_logic_needed.append({
                    'name': intr['name'],
                    'group': intr['group'],
                    'details': config_details
                })

    # 输出详细分析
    print(f"\n1. 需要Merge逻辑的中断 ({len(merge_logic_needed)}个):")
    print("-" * 60)
    for item in merge_logic_needed:
        print(f"• {item['name']} ({item['group']})")
        print(f"  Merge详情: {item['details']}")
        print(f"  建模建议: 实现多源信号合并逻辑，支持状态寄存器")
        print()

    print(f"\n2. 需要特殊路由逻辑的中断 ({len(routing_logic_needed)}个):")
    print("-" * 60)
    for item in routing_logic_needed:
        print(f"• {item['name']} ({item['group']})")
        print(f"  路由详情: {item['details']}")
        print(f"  建模建议: 实现可配置路由矩阵或专用路由路径")
        print()

    print(f"\n3. 需要信号处理逻辑的中断 ({len(signal_processing_needed)}个):")
    print("-" * 60)
    for item in signal_processing_needed:
        print(f"• {item['name']} ({item['group']})")
        print(f"  处理详情: {item['details']}")
        print(f"  建模建议: 实现脉冲到电平转换或同步逻辑")
        print()

    print(f"\n4. 需要配置逻辑的中断 ({len(config_logic_needed)}个):")
    print("-" * 60)
    for item in config_logic_needed:
        print(f"• {item['name']} ({item['group']})")
        print(f"  配置详情: {item['details']}")
        print(f"  建模建议: 实现配置寄存器和动态选择逻辑")
        print()

def extract_merge_details(description):
    """提取merge相关的详细信息"""
    if 'merge了如下源' in description:
        return "多源合并 - 需要实现源信号列表和合并逻辑"
    elif 'merge到' in description:
        return "合并到目标信号 - 需要实现目标信号的合并逻辑"
    elif 'merge成' in description:
        return "合并成新信号 - 需要实现信号转换和合并"
    else:
        return "通用合并逻辑"

def extract_routing_details(description):
    """提取路由相关的详细信息"""
    if '可配置' in description:
        return "可配置路由 - 需要配置寄存器控制路由选择"
    elif '选择送' in description:
        return "选择性路由 - 需要实现路由选择逻辑"
    elif '额外' in description or '单独' in description:
        return "额外路由路径 - 需要实现并行路由"
    elif '直连' in description:
        return "直连路由 - 需要实现专用连接"
    else:
        return "特殊路由逻辑"

def extract_signal_processing_details(description):
    """提取信号处理相关的详细信息"""
    if '原始为脉冲' in description and '变成电平' in description:
        return "脉冲到电平转换 - 需要实现边沿检测和锁存"
    elif '同步之后' in description:
        return "信号同步 - 需要实现时钟域同步逻辑"
    elif '经过' in description and '处理得到' in description:
        return "信号处理 - 需要实现中间处理逻辑"
    else:
        return "通用信号处理"

def extract_config_details(description):
    """提取配置相关的详细信息"""
    if '可配安全属性' in description:
        return "安全属性配置 - 需要实现安全/非安全模式切换"
    elif '选择可配置' in description:
        return "路由选择配置 - 需要实现路由配置寄存器"
    else:
        return "通用配置逻辑"

if __name__ == "__main__":
    csv_file = "中断向量表-iosub-V0.5.csv"
    if Path(csv_file).exists():
        analyze_interrupt_comments(csv_file)
    else:
        print(f"错误：找不到文件 {csv_file}")
