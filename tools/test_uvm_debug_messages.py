#!/usr/bin/env python3
"""
测试UVM调试消息增强的脚本
验证新增的UVM消息是否正确添加到相关函数中
"""

import os
import re
import sys
from pathlib import Path

def check_uvm_messages_in_file(file_path, expected_patterns):
    """检查文件中是否包含预期的UVM消息模式"""
    try:
        with open(file_path, 'r', encoding='utf-8') as f:
            content = f.read()
        
        results = {}
        for pattern_name, pattern in expected_patterns.items():
            matches = re.findall(pattern, content, re.MULTILINE)
            results[pattern_name] = {
                'found': len(matches) > 0,
                'count': len(matches),
                'matches': matches[:3]  # 只显示前3个匹配
            }
        
        return results
    except Exception as e:
        print(f"❌ 读取文件 {file_path} 时出错: {e}")
        return {}

def main():
    """主测试函数"""
    print("🧪 测试UVM调试消息增强")
    print("=" * 50)
    
    # 定义要检查的文件和预期的UVM消息模式
    test_cases = {
        'seq/int_register_model.sv': {
            'mask_check_entry': r'`uvm_info\("INT_REG_MODEL",.*Checking mask status for interrupt',
            'iosub_processing': r'`uvm_info\("INT_REG_MODEL",.*Processing IOSUB normal interrupt',
            'general_processing': r'`uvm_info\("INT_REG_MODEL",.*Processing general interrupt',
            'scp_destination': r'`uvm_info\("INT_REG_MODEL",.*Processing SCP destination',
            'mcp_destination': r'`uvm_info\("INT_REG_MODEL",.*Processing MCP destination',
            'final_result': r'`uvm_info\("INT_REG_MODEL",.*Final mask check result',
            'sub_index_search': r'`uvm_info\("INT_REG_MODEL",.*Searching sub_index for interrupt',
            'dest_index_search': r'`uvm_info\("INT_REG_MODEL",.*Searching dest_index for interrupt'
        },
        
        'seq/int_routing_model.sv': {
            'routing_prediction': r'`uvm_info\("INT_ROUTING_MODEL",.*Predicting routing for interrupt',
            'base_routing_check': r'`uvm_info\("INT_ROUTING_MODEL",.*Base routing check',
            'mask_check': r'`uvm_info\("INT_ROUTING_MODEL",.*Mask check',
            'final_prediction': r'`uvm_info\("INT_ROUTING_MODEL",.*Final routing prediction',
            'getting_destinations': r'`uvm_info\("INT_ROUTING_MODEL",.*Getting expected destinations with mask',
            'final_destinations': r'`uvm_info\("INT_ROUTING_MODEL",.*Final expected destinations'
        },
        
        'seq/int_base_sequence.sv': {
            'original_routing': r'`uvm_info\(get_type_name\(\),.*Original interrupt routing',
            'calling_routing_model': r'`uvm_info\(get_type_name\(\),.*Calling routing model to get expected destinations',
            'found_destinations': r'`uvm_info\(get_type_name\(\),.*Found.*expected destinations after mask filtering',
            'creating_masked_info': r'`uvm_info\(get_type_name\(\),.*Creating masked interrupt info',
            'final_masked_routing': r'`uvm_info\(get_type_name\(\),.*Final masked interrupt routing'
        }
    }
    
    overall_success = True
    
    for file_path, patterns in test_cases.items():
        print(f"\n📁 检查文件: {file_path}")
        print("-" * 40)
        
        if not os.path.exists(file_path):
            print(f"❌ 文件不存在: {file_path}")
            overall_success = False
            continue
        
        results = check_uvm_messages_in_file(file_path, patterns)
        file_success = True
        
        for pattern_name, result in results.items():
            if result['found']:
                print(f"✅ {pattern_name}: 找到 {result['count']} 个匹配")
            else:
                print(f"❌ {pattern_name}: 未找到匹配")
                file_success = False
        
        if file_success:
            print(f"✅ {file_path} - 所有UVM消息检查通过")
        else:
            print(f"❌ {file_path} - 部分UVM消息缺失")
            overall_success = False
    
    print("\n" + "=" * 50)
    if overall_success:
        print("🎉 所有UVM调试消息增强验证通过！")
        print("📋 建议:")
        print("   1. 运行仿真时使用 +UVM_VERBOSITY=UVM_HIGH 查看详细信息")
        print("   2. 关注 INT_REG_MODEL 和 INT_ROUTING_MODEL 标签的消息")
        print("   3. 在调试掩码问题时特别有用")
    else:
        print("❌ 部分UVM调试消息增强验证失败")
        print("📋 请检查上述失败的文件和模式")
        return 1
    
    return 0

def show_usage():
    """显示使用说明"""
    print("🔧 UVM调试消息测试工具")
    print("用法: python3 test_uvm_debug_messages.py")
    print("")
    print("功能:")
    print("  - 验证新增的UVM调试消息是否正确添加")
    print("  - 检查关键函数中的调试信息完整性")
    print("  - 确保调试消息格式符合预期")
    print("")
    print("检查的文件:")
    print("  - seq/int_register_model.sv")
    print("  - seq/int_routing_model.sv") 
    print("  - seq/int_base_sequence.sv")

if __name__ == "__main__":
    if len(sys.argv) > 1 and sys.argv[1] in ['-h', '--help']:
        show_usage()
        sys.exit(0)
    
    sys.exit(main())
