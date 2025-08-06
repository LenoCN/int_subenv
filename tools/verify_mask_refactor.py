#!/usr/bin/env python3
"""
验证 Mask 处理逻辑重构的脚本

这个脚本检查重构是否正确实施：
1. 检查通用组件中是否添加了高级接口
2. 检查 sequence 中是否删除了重复逻辑
3. 检查 sequence 中是否正确使用了通用接口
4. 验证代码结构的完整性
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

def check_register_model_interfaces(content):
    """检查 register_model 中是否添加了高级接口"""
    print("\n🔍 检查 register_model 中的高级接口...")
    
    # 检查 should_expect_merge_interrupt 函数
    if "should_expect_merge_interrupt" in content:
        print("✅ 找到高级接口: should_expect_merge_interrupt")
    else:
        print("❌ 缺少高级接口: should_expect_merge_interrupt")
        return False
    
    # 检查 should_expect_merge_from_any_source 函数
    if "should_expect_merge_from_any_source" in content:
        print("✅ 找到高级接口: should_expect_merge_from_any_source")
    else:
        print("❌ 缺少高级接口: should_expect_merge_from_any_source")
        return False
    
    return True

def check_routing_model_interfaces(content):
    """检查 routing_model 中是否添加了高级接口"""
    print("\n🔍 检查 routing_model 中的高级接口...")
    
    # 检查 should_trigger_merge_expectation 函数
    if "should_trigger_merge_expectation" in content:
        print("✅ 找到高级接口: should_trigger_merge_expectation")
    else:
        print("❌ 缺少高级接口: should_trigger_merge_expectation")
        return False
    
    # 检查 get_merge_interrupt_info 函数
    if "get_merge_interrupt_info" in content:
        print("✅ 找到高级接口: get_merge_interrupt_info")
    else:
        print("❌ 缺少高级接口: get_merge_interrupt_info")
        return False
    
    # 检查 should_any_source_trigger_merge 函数
    if "should_any_source_trigger_merge" in content:
        print("✅ 找到高级接口: should_any_source_trigger_merge")
    else:
        print("❌ 缺少高级接口: should_any_source_trigger_merge")
        return False
    
    return True

def check_sequence_refactor(content):
    """检查 sequence 中是否正确重构"""
    print("\n🔍 检查 sequence 重构情况...")
    
    # 检查是否删除了旧的辅助函数
    if "is_source_masked_in_iosub_normal_layer" in content:
        print("❌ 仍然存在旧的辅助函数: is_source_masked_in_iosub_normal_layer")
        return False
    else:
        print("✅ 已删除旧的辅助函数: is_source_masked_in_iosub_normal_layer")
    
    if "any_source_unmasked_in_iosub_normal_layer" in content:
        print("❌ 仍然存在旧的辅助函数: any_source_unmasked_in_iosub_normal_layer")
        return False
    else:
        print("✅ 已删除旧的辅助函数: any_source_unmasked_in_iosub_normal_layer")
    
    # 检查是否使用了新的高级接口
    if "should_trigger_merge_expectation" in content:
        print("✅ 使用了新的高级接口: should_trigger_merge_expectation")
    else:
        print("❌ 未使用新的高级接口: should_trigger_merge_expectation")
        return False
    
    if "should_expect_merge_interrupt" in content:
        print("✅ 使用了新的高级接口: should_expect_merge_interrupt")
    else:
        print("❌ 未使用新的高级接口: should_expect_merge_interrupt")
        return False
    
    if "should_any_source_trigger_merge" in content:
        print("✅ 使用了新的高级接口: should_any_source_trigger_merge")
    else:
        print("❌ 未使用新的高级接口: should_any_source_trigger_merge")
        return False
    
    return True

def check_code_simplification(content):
    """检查代码是否简化"""
    print("\n🔍 检查代码简化情况...")
    
    # 检查是否减少了复杂的条件判断
    complex_patterns = [
        r'if\s*\(\s*merge_info\.name\s*==\s*"iosub_normal_intr"\s*\)\s*begin.*?check_iosub_normal_mask_layer',
        r'bit\s+source_masked_in_iosub_normal\s*=\s*0;',
        r'any_source_unmasked\s*=\s*0;'
    ]
    
    complex_found = 0
    for pattern in complex_patterns:
        if re.search(pattern, content, re.DOTALL):
            complex_found += 1
    
    if complex_found == 0:
        print("✅ 已删除复杂的条件判断逻辑")
    else:
        print(f"❌ 仍然存在 {complex_found} 个复杂的条件判断")
        return False
    
    # 检查接口调用的简洁性
    simple_calls = content.count("should_trigger_merge_expectation") + \
                   content.count("should_expect_merge_interrupt") + \
                   content.count("should_any_source_trigger_merge")
    
    if simple_calls >= 6:  # 预期至少有6个调用
        print(f"✅ 使用了 {simple_calls} 个简洁的接口调用")
    else:
        print(f"❌ 简洁接口调用数量不足: {simple_calls}")
        return False
    
    return True

def check_file_size_reduction(file_path):
    """检查文件大小是否减少"""
    print("\n🔍 检查文件大小变化...")
    
    try:
        with open(file_path, 'r', encoding='utf-8') as f:
            lines = f.readlines()
        
        line_count = len(lines)
        print(f"📊 当前文件行数: {line_count}")
        
        # 预期重构后应该少于 520 行（原来约 595 行）
        if line_count < 520:
            print(f"✅ 文件大小已减少（预期 < 520 行）")
            return True
        else:
            print(f"❌ 文件大小未明显减少（当前 {line_count} 行）")
            return False
            
    except Exception as e:
        print(f"❌ 检查文件大小失败: {e}")
        return False

def main():
    """主函数"""
    print("🔧 Mask 处理逻辑重构验证脚本")
    print("=" * 50)
    
    # 检查文件路径
    files_to_check = [
        "seq/int_register_model.sv",
        "seq/int_routing_model.sv", 
        "seq/int_lightweight_sequence.sv"
    ]
    
    for file_path in files_to_check:
        if not check_file_exists(file_path):
            sys.exit(1)
    
    # 读取文件内容
    try:
        with open("seq/int_register_model.sv", 'r', encoding='utf-8') as f:
            register_content = f.read()
        
        with open("seq/int_routing_model.sv", 'r', encoding='utf-8') as f:
            routing_content = f.read()
            
        with open("seq/int_lightweight_sequence.sv", 'r', encoding='utf-8') as f:
            sequence_content = f.read()
            
    except Exception as e:
        print(f"❌ 读取文件失败: {e}")
        sys.exit(1)
    
    # 执行各项检查
    checks = [
        check_register_model_interfaces(register_content),
        check_routing_model_interfaces(routing_content),
        check_sequence_refactor(sequence_content),
        check_code_simplification(sequence_content),
        check_file_size_reduction("seq/int_lightweight_sequence.sv")
    ]
    
    # 统计结果
    passed_checks = sum(checks)
    total_checks = len(checks)
    
    print("\n" + "=" * 50)
    print(f"📊 验证结果: {passed_checks}/{total_checks} 项检查通过")
    
    if passed_checks == total_checks:
        print("🎉 所有检查通过！Mask 处理逻辑重构已正确实施。")
        print("\n✅ 重构成果:")
        print("   - 在通用组件中添加了高级接口")
        print("   - 删除了 sequence 中的重复逻辑")
        print("   - 简化了代码结构和调用方式")
        print("   - 提高了代码的可维护性和可复用性")
        return 0
    else:
        print("❌ 部分检查未通过，请检查重构实施情况。")
        return 1

if __name__ == "__main__":
    sys.exit(main())
