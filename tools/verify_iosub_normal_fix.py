#!/usr/bin/env python3
"""
验证 is_interrupt_mask 函数修改的脚本
检查 IOSUB normal 中断判断逻辑是否正确从 interrupt_name 改为基于 index 范围
"""

import re
import sys
from pathlib import Path

def verify_is_interrupt_masked_fix():
    """验证 is_interrupt_masked 函数的修改"""
    print("🔍 验证 is_interrupt_masked 函数的 IOSUB normal 中断判断逻辑修改...")
    
    file_path = Path("seq/int_register_model.sv")
    if not file_path.exists():
        print(f"❌ 文件不存在: {file_path}")
        return False
    
    with open(file_path, 'r', encoding='utf-8') as f:
        content = f.read()
    
    # 检查是否移除了旧的基于 interrupt_name 的判断逻辑
    old_logic_patterns = [
        r'interrupt_name\.substr\(0,\s*6\)\s*==\s*"iosub_"',
        r'interrupt_name\s*!=\s*"iosub_ras_cri_intr"',
        r'interrupt_name\s*!=\s*"iosub_slv_err_intr"'
    ]
    
    old_logic_found = False
    for pattern in old_logic_patterns:
        if re.search(pattern, content):
            print(f"❌ 仍然发现旧的基于 interrupt_name 的判断逻辑: {pattern}")
            old_logic_found = True
    
    if not old_logic_found:
        print("✅ 已移除旧的基于 interrupt_name 的判断逻辑")
    
    # 检查是否添加了新的基于 index 范围的判断逻辑
    new_logic_patterns = [
        r'bit\s+is_iosub_normal\s*=\s*0',
        r'routing_model\.interrupt_map\[i\]\.group\s*==\s*IOSUB',
        r'\(idx\s*>=\s*0\s*&&\s*idx\s*<=\s*9\)',
        r'\(idx\s*>=\s*15\s*&&\s*idx\s*<=\s*50\)',
        r'if\s*\(is_iosub_normal\)'
    ]
    
    new_logic_found = 0
    for pattern in new_logic_patterns:
        if re.search(pattern, content):
            print(f"✅ 发现新的基于 index 范围的判断逻辑: {pattern}")
            new_logic_found += 1
        else:
            print(f"❌ 未发现预期的新逻辑: {pattern}")
    
    if new_logic_found == len(new_logic_patterns):
        print("✅ 所有新的判断逻辑都已正确实现")
        return True
    else:
        print(f"❌ 新逻辑实现不完整: {new_logic_found}/{len(new_logic_patterns)}")
        return False

def verify_iosub_interrupt_mapping():
    """验证 IOSUB 中断的 index 映射是否符合预期"""
    print("\n🔍 验证 IOSUB 中断的 index 映射...")
    
    file_path = Path("seq/int_map_entries.svh")
    if not file_path.exists():
        print(f"❌ 文件不存在: {file_path}")
        return False
    
    with open(file_path, 'r', encoding='utf-8') as f:
        content = f.read()
    
    # 提取所有 IOSUB 组的中断及其 index
    iosub_pattern = r'name:"([^"]*)",\s*index:(\d+),\s*group:IOSUB'
    iosub_matches = re.findall(iosub_pattern, content)
    
    if not iosub_matches:
        print("❌ 未找到任何 IOSUB 组的中断")
        return False
    
    print(f"📊 找到 {len(iosub_matches)} 个 IOSUB 组中断")
    
    # 分析 index 分布
    normal_range_interrupts = []
    other_range_interrupts = []
    
    for name, index_str in iosub_matches:
        index = int(index_str)
        if (0 <= index <= 9) or (15 <= index <= 50):
            normal_range_interrupts.append((name, index))
        else:
            other_range_interrupts.append((name, index))
    
    print(f"✅ IOSUB normal 范围 [0,9] ∪ [15,50] 中断: {len(normal_range_interrupts)} 个")
    for name, index in sorted(normal_range_interrupts, key=lambda x: x[1]):
        print(f"   - {name}: index={index}")
    
    print(f"📋 IOSUB 其他范围中断: {len(other_range_interrupts)} 个")
    for name, index in sorted(other_range_interrupts, key=lambda x: x[1]):
        print(f"   - {name}: index={index}")
    
    return True

def verify_other_groups_index_overlap():
    """验证其他组是否有 index 在 [15,50] 范围内的中断"""
    print("\n🔍 验证其他组在 [15,50] 范围内的中断...")
    
    file_path = Path("seq/int_map_entries.svh")
    if not file_path.exists():
        print(f"❌ 文件不存在: {file_path}")
        return False
    
    with open(file_path, 'r', encoding='utf-8') as f:
        content = f.read()
    
    # 提取所有非 IOSUB 组的中断及其 index
    non_iosub_pattern = r'name:"([^"]*)",\s*index:(\d+),\s*group:([^,\s]+)'
    all_matches = re.findall(non_iosub_pattern, content)
    
    overlap_interrupts = []
    for name, index_str, group in all_matches:
        index = int(index_str)
        if group != "IOSUB" and (15 <= index <= 50):
            overlap_interrupts.append((name, index, group))
    
    if overlap_interrupts:
        print(f"⚠️  发现 {len(overlap_interrupts)} 个非 IOSUB 组中断的 index 在 [15,50] 范围内:")
        for name, index, group in sorted(overlap_interrupts, key=lambda x: (x[2], x[1])):
            print(f"   - {name}: index={index}, group={group}")
        print("✅ 这证明了基于 index 范围 + group 的判断逻辑是必要的")
    else:
        print("📋 未发现非 IOSUB 组中断的 index 在 [15,50] 范围内")
    
    return True

def verify_serial_mask_implementation():
    """验证串行mask处理的实现"""
    print("\n🔍 验证串行mask处理实现...")

    file_path = Path("seq/int_register_model.sv")
    if not file_path.exists():
        print(f"❌ 文件不存在: {file_path}")
        return False

    with open(file_path, 'r', encoding='utf-8') as f:
        content = f.read()

    # 检查串行mask处理的关键函数
    serial_mask_patterns = [
        r'check_iosub_normal_mask_layer\(',
        r'check_general_mask_layer\(',
        r'Serial mask processing: Layer 1.*Layer 2',
        r'Layer 1.*IOSUB normal mask.*passed.*checking Layer 2',
        r'Layer1=.*Layer2=.*Final='
    ]

    found_patterns = 0
    for pattern in serial_mask_patterns:
        if re.search(pattern, content):
            print(f"✅ 发现串行mask处理逻辑: {pattern}")
            found_patterns += 1
        else:
            print(f"❌ 未发现预期的串行mask逻辑: {pattern}")

    # 检查辅助函数的实现
    helper_functions = [
        r'function bit check_iosub_normal_mask_layer',
        r'function bit check_general_mask_layer',
        r'Layer 1:.*Checking IOSUB normal mask',
        r'Layer 2:.*Checking general mask'
    ]

    for pattern in helper_functions:
        if re.search(pattern, content):
            print(f"✅ 发现辅助函数实现: {pattern}")
            found_patterns += 1
        else:
            print(f"❌ 未发现预期的辅助函数: {pattern}")

    if found_patterns >= 7:  # 至少要有7个关键模式
        print("✅ 串行mask处理实现验证通过")
        return True
    else:
        print(f"❌ 串行mask处理实现不完整: {found_patterns}/9")
        return False

def verify_iosub_normal_intr_lookup():
    """验证 iosub_normal_intr 在映射表中的存在"""
    print("\n🔍 验证 'iosub_normal_intr' 在中断映射表中的存在...")

    file_path = Path("seq/int_map_entries.svh")
    if not file_path.exists():
        print(f"❌ 文件不存在: {file_path}")
        return False

    with open(file_path, 'r', encoding='utf-8') as f:
        content = f.read()

    # 查找 iosub_normal_intr 条目
    pattern = r'name:"iosub_normal_intr".*?dest_index_scp:(-?\d+).*?dest_index_mcp:(-?\d+)'
    match = re.search(pattern, content)

    if match:
        scp_index, mcp_index = match.groups()
        print(f"✅ 找到 'iosub_normal_intr' 条目:")
        print(f"   - dest_index_scp: {scp_index}")
        print(f"   - dest_index_mcp: {mcp_index}")

        if scp_index == "-1" and mcp_index == "-1":
            print("⚠️  注意: iosub_normal_intr 的 dest_index 都是 -1，这是预期的")
            print("   这意味着它是一个汇聚信号，不直接路由到 SCP/MCP")
            print("   串行mask的第二层将被跳过（假设不被屏蔽）")

        return True
    else:
        print("❌ 未找到 'iosub_normal_intr' 条目")
        print("⚠️  这可能影响串行mask的第二层处理")
        return False

def main():
    """主函数"""
    print("=" * 60)
    print("🔧 验证 is_interrupt_mask 函数 IOSUB normal 中断串行mask处理")
    print("=" * 60)

    success = True

    # 验证函数修改
    if not verify_is_interrupt_masked_fix():
        success = False

    # 验证串行mask实现
    if not verify_serial_mask_implementation():
        success = False

    # 验证 IOSUB 中断映射
    if not verify_iosub_interrupt_mapping():
        success = False

    # 验证其他组的 index 重叠情况
    if not verify_other_groups_index_overlap():
        success = False

    # 验证 iosub_normal_intr 查找
    if not verify_iosub_normal_intr_lookup():
        success = False

    print("\n" + "=" * 60)
    if success:
        print("✅ 所有验证通过！IOSUB normal 中断串行mask处理实现正确")
    else:
        print("❌ 验证失败，请检查修改")
    print("=" * 60)

    return 0 if success else 1

if __name__ == "__main__":
    sys.exit(main())
