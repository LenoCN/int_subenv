#!/usr/bin/env python3
"""
验证多路径预期注册逻辑重构的脚本

这个脚本检查深度重构是否正确实施：
1. 检查 base_sequence 中是否添加了高级接口
2. 检查 routing_model 中是否添加了路径发现接口
3. 检查 lightweight_sequence 中是否大幅简化
4. 验证代码行数的显著减少
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

def check_base_sequence_interfaces(content):
    """检查 base_sequence 中是否添加了高级接口"""
    print("\n🔍 检查 base_sequence 中的高级接口...")
    
    required_interfaces = [
        "add_all_expected_interrupts",
        "wait_for_all_expected_interrupts", 
        "update_all_interrupt_status",
        "add_merge_test_expectations",
        "wait_for_merge_test_interrupts",
        "update_merge_test_status",
        "add_multi_source_merge_expectations",
        "wait_for_multi_source_merge_interrupts",
        "update_multi_source_merge_status"
    ]
    
    found_interfaces = 0
    for interface in required_interfaces:
        if interface in content:
            print(f"✅ 找到高级接口: {interface}")
            found_interfaces += 1
        else:
            print(f"❌ 缺少高级接口: {interface}")
    
    if found_interfaces == len(required_interfaces):
        print(f"✅ 所有 {len(required_interfaces)} 个高级接口都已实现")
        return True
    else:
        print(f"❌ 只找到 {found_interfaces}/{len(required_interfaces)} 个高级接口")
        return False

def check_routing_model_path_discovery(content):
    """检查 routing_model 中是否添加了路径发现接口"""
    print("\n🔍 检查 routing_model 中的路径发现接口...")
    
    if "get_merge_interrupts_for_source" in content:
        print("✅ 找到路径发现接口: get_merge_interrupts_for_source")
        return True
    else:
        print("❌ 缺少路径发现接口: get_merge_interrupts_for_source")
        return False

def check_sequence_simplification(content):
    """检查 sequence 中是否大幅简化"""
    print("\n🔍 检查 sequence 简化情况...")
    
    # 检查是否使用了新的高级接口
    high_level_calls = [
        "add_all_expected_interrupts",
        "wait_for_all_expected_interrupts",
        "update_all_interrupt_status",
        "add_merge_test_expectations",
        "wait_for_merge_test_interrupts", 
        "update_merge_test_status",
        "add_multi_source_merge_expectations",
        "wait_for_multi_source_merge_interrupts",
        "update_multi_source_merge_status"
    ]
    
    found_calls = 0
    for call in high_level_calls:
        if call in content:
            found_calls += 1
    
    if found_calls >= 6:  # 预期至少有6个高级接口调用
        print(f"✅ 使用了 {found_calls} 个高级接口调用")
    else:
        print(f"❌ 高级接口调用数量不足: {found_calls}")
        return False
    
    # 检查是否删除了复杂的逻辑
    complex_patterns = [
        r'is_iosub_normal_source\s*=',
        r'iosub_normal_info\s*=',
        r'source_has_direct_routing\s*=.*\(.*to_ap.*\|\|.*to_accel',
        r'foreach.*source_interrupts.*begin.*source_has_direct_routing'
    ]
    
    complex_found = 0
    for pattern in complex_patterns:
        if re.search(pattern, content, re.DOTALL):
            complex_found += 1
    
    if complex_found == 0:
        print("✅ 已删除复杂的手动判断逻辑")
    else:
        print(f"❌ 仍然存在 {complex_found} 个复杂的手动判断")
        return False
    
    return True

def check_code_reduction(file_path):
    """检查代码行数是否显著减少"""
    print("\n🔍 检查代码行数变化...")
    
    try:
        with open(file_path, 'r', encoding='utf-8') as f:
            lines = f.readlines()
        
        line_count = len(lines)
        print(f"📊 当前文件行数: {line_count}")
        
        # 预期重构后应该少于 350 行（原来约 514 行）
        if line_count < 350:
            print(f"✅ 文件大小显著减少（预期 < 350 行）")
            reduction_percent = ((514 - line_count) / 514) * 100
            print(f"📉 代码减少了约 {reduction_percent:.1f}%")
            return True
        else:
            print(f"❌ 文件大小未显著减少（当前 {line_count} 行）")
            return False
            
    except Exception as e:
        print(f"❌ 检查文件大小失败: {e}")
        return False

def check_function_simplification(content):
    """检查关键函数是否简化"""
    print("\n🔍 检查关键函数简化情况...")
    
    # 检查 test_single_interrupt 函数的简化
    single_interrupt_pattern = r'task\s+test_single_interrupt.*?endtask'
    match = re.search(single_interrupt_pattern, content, re.DOTALL)
    
    if match:
        function_content = match.group(0)
        function_lines = len(function_content.split('\n'))
        print(f"📊 test_single_interrupt 函数行数: {function_lines}")
        
        if function_lines < 60:  # 预期少于60行（包含注释和空行）
            print("✅ test_single_interrupt 函数已显著简化")

            # 检查是否使用了高级接口
            high_level_calls_in_function = 0
            for call in ["add_all_expected_interrupts", "wait_for_all_expected_interrupts", "update_all_interrupt_status"]:
                if call in function_content:
                    high_level_calls_in_function += 1

            if high_level_calls_in_function == 3:
                print(f"✅ 函数使用了所有3个核心高级接口")
            else:
                print(f"❌ 函数只使用了 {high_level_calls_in_function}/3 个核心高级接口")
                return False
        else:
            print("❌ test_single_interrupt 函数未充分简化")
            return False
    else:
        print("❌ 未找到 test_single_interrupt 函数")
        return False
    
    # 检查是否删除了不必要的变量声明
    unnecessary_vars = [
        "is_iosub_normal_source",
        "iosub_normal_info"
    ]
    
    found_unnecessary = 0
    for var in unnecessary_vars:
        if var in content:
            found_unnecessary += 1
    
    if found_unnecessary == 0:
        print("✅ 已删除不必要的变量声明")
    else:
        print(f"❌ 仍然存在 {found_unnecessary} 个不必要的变量")
        return False
    
    return True

def main():
    """主函数"""
    print("🔧 多路径预期注册逻辑重构验证脚本")
    print("=" * 60)
    
    # 检查文件路径
    files_to_check = [
        "seq/int_base_sequence.sv",
        "seq/int_routing_model.sv",
        "seq/int_lightweight_sequence.sv"
    ]
    
    for file_path in files_to_check:
        if not check_file_exists(file_path):
            sys.exit(1)
    
    # 读取文件内容
    try:
        with open("seq/int_base_sequence.sv", 'r', encoding='utf-8') as f:
            base_content = f.read()
        
        with open("seq/int_routing_model.sv", 'r', encoding='utf-8') as f:
            routing_content = f.read()
            
        with open("seq/int_lightweight_sequence.sv", 'r', encoding='utf-8') as f:
            sequence_content = f.read()
            
    except Exception as e:
        print(f"❌ 读取文件失败: {e}")
        sys.exit(1)
    
    # 执行各项检查
    checks = [
        check_base_sequence_interfaces(base_content),
        check_routing_model_path_discovery(routing_content),
        check_sequence_simplification(sequence_content),
        check_code_reduction("seq/int_lightweight_sequence.sv"),
        check_function_simplification(sequence_content)
    ]
    
    # 统计结果
    passed_checks = sum(checks)
    total_checks = len(checks)
    
    print("\n" + "=" * 60)
    print(f"📊 验证结果: {passed_checks}/{total_checks} 项检查通过")
    
    if passed_checks == total_checks:
        print("🎉 所有检查通过！多路径预期注册逻辑重构已正确实施。")
        print("\n✅ 重构成果:")
        print("   - 在 base_sequence 中添加了完整的高级接口")
        print("   - 在 routing_model 中添加了路径发现功能")
        print("   - 大幅简化了 sequence 中的复杂逻辑")
        print("   - 显著减少了代码行数和复杂度")
        print("   - 实现了真正的自动化路径处理")
        return 0
    else:
        print("❌ 部分检查未通过，请检查重构实施情况。")
        return 1

if __name__ == "__main__":
    sys.exit(main())
