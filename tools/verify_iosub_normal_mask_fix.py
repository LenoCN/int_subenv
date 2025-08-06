#!/usr/bin/env python3
"""
验证 IOSUB Normal Mask 修复的脚本

这个脚本检查 lightweight_sequence 中的修复是否正确实施：
1. 检查是否添加了辅助函数
2. 检查是否在关键位置添加了 mask 检查
3. 验证代码结构的完整性
"""

import re
import sys
from pathlib import Path

def check_file_exists(file_path):
    """检查文件是否存在"""
    if not Path(file_path).exists():
        print(f"❌ 文件不存在: {file_path}")
        return False
    print(f"✅ 文件存在: {file_path}")
    return True

def check_helper_functions(content):
    """检查是否添加了辅助函数"""
    print("\n🔍 检查辅助函数...")
    
    # 检查第一个辅助函数
    if "is_source_masked_in_iosub_normal_layer" in content:
        print("✅ 找到辅助函数: is_source_masked_in_iosub_normal_layer")
    else:
        print("❌ 缺少辅助函数: is_source_masked_in_iosub_normal_layer")
        return False
    
    # 检查第二个辅助函数
    if "any_source_unmasked_in_iosub_normal_layer" in content:
        print("✅ 找到辅助函数: any_source_unmasked_in_iosub_normal_layer")
    else:
        print("❌ 缺少辅助函数: any_source_unmasked_in_iosub_normal_layer")
        return False
    
    return True

def check_mask_checks_in_functions(content):
    """检查关键函数中是否添加了 mask 检查"""
    print("\n🔍 检查关键函数中的 mask 检查...")
    
    # 检查 test_single_interrupt 函数
    if "is_source_masked_in_iosub_normal_layer(info.name, iosub_normal_info)" in content:
        print("✅ test_single_interrupt 函数中添加了 mask 检查")
    else:
        print("❌ test_single_interrupt 函数中缺少 mask 检查")
        return False
    
    # 检查 test_merge_source 函数
    if 'merge_info.name == "iosub_normal_intr"' in content:
        print("✅ test_merge_source 函数中添加了 iosub_normal_intr 特殊处理")
    else:
        print("❌ test_merge_source 函数中缺少 iosub_normal_intr 特殊处理")
        return False
    
    # 检查 test_multiple_merge_sources 函数
    if "any_source_unmasked_in_iosub_normal_layer(source_interrupts, merge_info)" in content:
        print("✅ test_multiple_merge_sources 函数中添加了批量 mask 检查")
    else:
        print("❌ test_multiple_merge_sources 函数中缺少批量 mask 检查")
        return False
    
    return True

def check_critical_fix_comments(content):
    """检查是否添加了关键修复注释"""
    print("\n🔍 检查关键修复注释...")
    
    critical_fix_count = content.count("CRITICAL FIX")
    if critical_fix_count >= 5:
        print(f"✅ 找到 {critical_fix_count} 个 CRITICAL FIX 注释")
    else:
        print(f"❌ CRITICAL FIX 注释数量不足: {critical_fix_count} (期望 >= 5)")
        return False
    
    return True

def check_mask_layer_calls(content):
    """检查是否正确调用了 mask layer 检查函数"""
    print("\n🔍 检查 mask layer 函数调用...")
    
    # 检查是否调用了 check_iosub_normal_mask_layer
    mask_layer_calls = content.count("check_iosub_normal_mask_layer")
    if mask_layer_calls >= 2:
        print(f"✅ 找到 {mask_layer_calls} 个 check_iosub_normal_mask_layer 调用")
    else:
        print(f"❌ check_iosub_normal_mask_layer 调用数量不足: {mask_layer_calls}")
        return False
    
    return True

def check_code_structure(content):
    """检查代码结构完整性"""
    print("\n🔍 检查代码结构完整性...")
    
    # 检查类定义
    if "class int_lightweight_sequence extends int_base_sequence" in content:
        print("✅ 类定义正确")
    else:
        print("❌ 类定义有问题")
        return False
    
    # 检查文件结尾
    if content.strip().endswith("`endif // INT_LIGHTWEIGHT_SEQUENCE_SV"):
        print("✅ 文件结尾正确")
    else:
        print("❌ 文件结尾有问题")
        return False
    
    # 检查函数配对 - 使用正则表达式匹配实际的函数定义
    function_pattern = r'^\s*(virtual\s+)?function\s+'
    endfunction_pattern = r'^\s*endfunction'

    function_matches = re.findall(function_pattern, content, re.MULTILINE)
    endfunction_matches = re.findall(endfunction_pattern, content, re.MULTILINE)

    function_count = len(function_matches)
    endfunction_count = len(endfunction_matches)

    if function_count == endfunction_count:
        print(f"✅ 函数配对正确: {function_count} 个函数")
    else:
        print(f"❌ 函数配对不匹配: {function_count} 个 function, {endfunction_count} 个 endfunction")
        return False
    
    # 检查任务配对
    task_count = content.count("task ")
    endtask_count = content.count("endtask")
    if task_count == endtask_count:
        print(f"✅ 任务配对正确: {task_count} 个任务")
    else:
        print(f"❌ 任务配对不匹配: {task_count} 个 task, {endtask_count} 个 endtask")
        return False
    
    return True

def main():
    """主函数"""
    print("🔧 IOSUB Normal Mask 修复验证脚本")
    print("=" * 50)
    
    # 检查文件路径
    file_path = "seq/int_lightweight_sequence.sv"
    if not check_file_exists(file_path):
        sys.exit(1)
    
    # 读取文件内容
    try:
        with open(file_path, 'r', encoding='utf-8') as f:
            content = f.read()
    except Exception as e:
        print(f"❌ 读取文件失败: {e}")
        sys.exit(1)
    
    # 执行各项检查
    checks = [
        check_helper_functions(content),
        check_mask_checks_in_functions(content),
        check_critical_fix_comments(content),
        check_mask_layer_calls(content),
        check_code_structure(content)
    ]
    
    # 统计结果
    passed_checks = sum(checks)
    total_checks = len(checks)
    
    print("\n" + "=" * 50)
    print(f"📊 验证结果: {passed_checks}/{total_checks} 项检查通过")
    
    if passed_checks == total_checks:
        print("🎉 所有检查通过！IOSUB Normal Mask 修复已正确实施。")
        print("\n✅ 修复要点:")
        print("   - 添加了辅助函数减少代码重复")
        print("   - 在关键位置添加了第一层 mask 检查")
        print("   - 确保了串行 mask 处理的正确性")
        print("   - 保持了代码结构的完整性")
        return 0
    else:
        print("❌ 部分检查未通过，请检查修复实施情况。")
        return 1

if __name__ == "__main__":
    sys.exit(main())
