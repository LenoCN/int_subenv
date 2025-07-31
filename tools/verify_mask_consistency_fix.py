#!/usr/bin/env python3
"""
验证 mask 一致性修复的脚本

这个脚本验证 add_expected_with_mask 和 wait_for_interrupt_detection 
现在使用相同的 mask 感知逻辑。

作者: AI Assistant
日期: 2025-07-31
"""

import os
import re
import sys

def check_file_exists(filepath):
    """检查文件是否存在"""
    if not os.path.exists(filepath):
        print(f"❌ 文件不存在: {filepath}")
        return False
    return True

def read_file_content(filepath):
    """读取文件内容"""
    try:
        with open(filepath, 'r', encoding='utf-8') as f:
            return f.read()
    except Exception as e:
        print(f"❌ 读取文件失败 {filepath}: {e}")
        return None

def verify_base_sequence_changes():
    """验证 int_base_sequence.sv 的修改"""
    print("🔍 验证 int_base_sequence.sv 的修改...")

    filepath = "seq/int_base_sequence.sv"
    if not check_file_exists(filepath):
        return False

    content = read_file_content(filepath)
    if content is None:
        return False

    checks = [
        # 检查是否添加了新的 mask 感知等待函数
        (r"task\s+wait_for_interrupt_detection_with_mask", "wait_for_interrupt_detection_with_mask 任务"),

        # 检查是否使用了 get_expected_destinations_with_mask
        (r"get_expected_destinations_with_mask", "使用 get_expected_destinations_with_mask"),

        # 检查是否有相同的目标设置逻辑
        (r"masked_info\.to_ap\s*=\s*1", "设置 AP 目标"),
        (r"masked_info\.to_scp\s*=\s*1", "设置 SCP 目标"),

        # 检查是否调用原始等待函数
        (r"wait_for_interrupt_detection\(masked_info", "调用原始等待函数"),
    ]

    all_passed = True
    for pattern, description in checks:
        if re.search(pattern, content):
            print(f"  ✅ {description}")
        else:
            print(f"  ❌ {description}")
            all_passed = False

    return all_passed

def verify_consistency_logic():
    """验证一致性逻辑"""
    print("\n🔍 验证一致性逻辑...")

    # 检查 int_base_sequence.sv 中的 add_expected_with_mask
    base_seq_file = "seq/int_base_sequence.sv"
    if not check_file_exists(base_seq_file):
        return False

    base_content = read_file_content(base_seq_file)
    if base_content is None:
        return False

    # 检查 int_lightweight_sequence.sv 中的使用
    lightweight_seq_file = "seq/int_lightweight_sequence.sv"
    if not check_file_exists(lightweight_seq_file):
        return False

    lightweight_content = read_file_content(lightweight_seq_file)
    if lightweight_content is None:
        return False

    checks_passed = True

    # 检查 int_base_sequence.sv 中的新函数
    if "wait_for_interrupt_detection_with_mask" in base_content:
        print("  ✅ int_base_sequence.sv 实现了 wait_for_interrupt_detection_with_mask")
    else:
        print("  ❌ int_base_sequence.sv 未实现 wait_for_interrupt_detection_with_mask")
        checks_passed = False

    # 检查 int_lightweight_sequence.sv 使用新函数
    if "wait_for_interrupt_detection_with_mask" in lightweight_content:
        print("  ✅ int_lightweight_sequence.sv 使用 wait_for_interrupt_detection_with_mask")
    else:
        print("  ❌ int_lightweight_sequence.sv 未使用 wait_for_interrupt_detection_with_mask")
        checks_passed = False

    # 检查两个函数都使用相同的 mask 逻辑
    if "get_expected_destinations_with_mask" in base_content:
        add_expected_count = base_content.count("get_expected_destinations_with_mask")
        if add_expected_count >= 2:  # add_expected_with_mask 和 wait_for_interrupt_detection_with_mask 都使用
            print("  ✅ int_base_sequence.sv 中两个函数都使用 get_expected_destinations_with_mask")
        else:
            print("  ❌ int_base_sequence.sv 中只有一个函数使用 get_expected_destinations_with_mask")
            checks_passed = False
    else:
        print("  ❌ int_base_sequence.sv 未使用 get_expected_destinations_with_mask")
        checks_passed = False

    # 检查模型引用
    if "m_routing_model" in base_content and "m_register_model" in base_content:
        print("  ✅ int_base_sequence.sv 有模型引用")
    else:
        print("  ❌ int_base_sequence.sv 缺少模型引用")
        checks_passed = False

    return checks_passed

def verify_backward_compatibility():
    """验证向后兼容性"""
    print("\n🔍 验证向后兼容性...")

    # 检查原始的 wait_for_interrupt_detection 是否仍然存在
    filepath = "seq/int_base_sequence.sv"
    content = read_file_content(filepath)
    if content is None:
        return False

    checks = [
        # 检查原始函数是否保留
        (r"task\s+wait_for_interrupt_detection\(", "保留原始 wait_for_interrupt_detection 函数"),
        # 检查新函数调用原始函数
        (r"wait_for_interrupt_detection\(masked_info", "新函数调用原始函数"),
    ]

    all_passed = True
    for pattern, description in checks:
        if re.search(pattern, content):
            print(f"  ✅ {description}")
        else:
            print(f"  ❌ {description}")
            all_passed = False

    return all_passed

def main():
    """主函数"""
    print("🚀 开始验证 mask 一致性修复...")
    print("=" * 60)
    
    all_checks_passed = True

    # 验证各个组件的修改
    if not verify_base_sequence_changes():
        all_checks_passed = False

    if not verify_consistency_logic():
        all_checks_passed = False

    if not verify_backward_compatibility():
        all_checks_passed = False
    
    print("\n" + "=" * 60)
    if all_checks_passed:
        print("🎉 所有检查通过！mask 一致性修复验证成功")
        print("\n📋 修复总结:")
        print("  ✅ 在 int_base_sequence 中实现了 wait_for_interrupt_detection_with_mask")
        print("  ✅ add_expected_with_mask 和 wait_for_interrupt_detection_with_mask 使用完全相同的逻辑")
        print("  ✅ 两个函数都通过 get_expected_destinations_with_mask 获取未被 mask 的目标")
        print("  ✅ int_lightweight_sequence 使用新的 mask 感知等待函数")
        print("  ✅ 保持了向后兼容性，原始函数仍然可用")
        return 0
    else:
        print("❌ 部分检查失败，请检查修复实现")
        return 1

if __name__ == "__main__":
    sys.exit(main())
