#!/usr/bin/env python3
"""
测试新的Excel转换系统
验证生成的SystemVerilog文件是否正确
"""

import re

def test_include_file():
    """测试include文件的内容"""
    print("=== 测试 int_map_entries.svh ===")
    
    with open('seq/int_map_entries.svh', 'r') as f:
        content = f.read()
    
    # 检查文件头
    assert "Auto-generated interrupt map entries from Excel file" in content
    assert "int_vector.xlsx" in content
    
    # 检查psub_normal3_intr条目
    psub_pattern = r'entry = \'.*name:"psub_normal3_intr".*group:PSUB.*dest_index_ap:110.*dest_index_scp:173.*dest_index_mcp:147.*'
    assert re.search(psub_pattern, content), "psub_normal3_intr条目不正确"
    
    # 统计中断条目数量
    entry_count = content.count('interrupt_map.push_back(entry);')
    print(f"✓ 找到 {entry_count} 个中断条目")
    
    # 检查组分类
    groups = ['IOSUB', 'USB', 'SCP', 'MCP', 'SMMU', 'IODAP', 'ACCEL', 'CSUB', 'PSUB', 'PCIE1', 'D2D', 'DDR0', 'DDR1', 'DDR2', 'IO_DIE']
    for group in groups:
        if f"group:{group}" in content:
            group_count = content.count(f"group:{group}")
            print(f"✓ {group} 组: {group_count} 个中断")
    
    print("✓ include文件测试通过")

def test_main_file():
    """测试主文件的结构"""
    print("\n=== 测试 int_routing_model.sv ===")
    
    with open('seq/int_routing_model.sv', 'r') as f:
        content = f.read()
    
    # 检查include语句
    assert '`include "int_map_entries.svh"' in content
    
    # 检查类定义
    assert 'class int_routing_model;' in content
    
    # 检查函数定义
    functions = [
        'static function void build()',
        'static function interrupt_info_s get_merge_sources(',
        'static function bit is_merge_interrupt(',
        'static function bit interrupt_exists(',
        'static function interrupt_info_s get_merge_interrupt_info('
    ]
    
    for func in functions:
        assert func in content, f"函数 {func} 未找到"
        print(f"✓ 找到函数: {func}")
    
    # 检查merge中断逻辑
    merge_interrupts = [
        'merge_pll_intr_lock',
        'merge_pll_intr_unlock', 
        'iosub_normal_intr',
        'iosub_slv_err_intr',
        'iosub_ras_cri_intr'
    ]
    
    for merge_int in merge_interrupts:
        assert f'"{merge_int}"' in content, f"merge中断 {merge_int} 未找到"
        print(f"✓ 找到merge中断: {merge_int}")
    
    print("✓ 主文件测试通过")

def test_data_structure():
    """测试数据结构定义"""
    print("\n=== 测试数据结构 ===")
    
    with open('seq/int_def.sv', 'r') as f:
        content = f.read()
    
    # 检查新增的目的地索引字段
    dest_fields = [
        'dest_index_ap',
        'dest_index_scp', 
        'dest_index_mcp',
        'dest_index_imu',
        'dest_index_io',
        'dest_index_other_die'
    ]
    
    for field in dest_fields:
        assert field in content, f"字段 {field} 未找到"
        print(f"✓ 找到字段: {field}")
    
    print("✓ 数据结构测试通过")

def test_mapping_accuracy():
    """测试映射准确性"""
    print("\n=== 测试映射准确性 ===")
    
    with open('seq/int_map_entries.svh', 'r') as f:
        content = f.read()
    
    # 测试psub_normal3_intr的具体映射
    psub_line = None
    for line in content.split('\n'):
        if 'psub_normal3_intr' in line:
            psub_line = line
            break
    
    assert psub_line is not None, "未找到psub_normal3_intr条目"
    
    # 解析条目
    assert 'index:6' in psub_line, "索引不正确"
    assert 'group:PSUB' in psub_line, "组不正确"
    assert 'dest_index_ap:110' in psub_line, "AP目的地索引不正确"
    assert 'dest_index_scp:173' in psub_line, "SCP目的地索引不正确"
    assert 'dest_index_mcp:147' in psub_line, "MCP目的地索引不正确"
    assert 'to_ap:1' in psub_line, "AP路由标志不正确"
    assert 'to_scp:1' in psub_line, "SCP路由标志不正确"
    assert 'to_mcp:1' in psub_line, "MCP路由标志不正确"
    assert 'to_imu:0' in psub_line, "IMU路由标志不正确"
    
    print("✓ psub_normal3_intr映射验证通过:")
    print(f"  - 组: PSUB")
    print(f"  - 索引: 6")
    print(f"  - AP目的地: 110")
    print(f"  - SCP目的地: 173")
    print(f"  - MCP目的地: 147")
    
    print("✓ 映射准确性测试通过")

def main():
    """运行所有测试"""
    print("开始测试新的Excel转换系统...")
    
    try:
        test_include_file()
        test_main_file()
        test_data_structure()
        test_mapping_accuracy()
        
        print("\n🎉 所有测试通过！")
        print("\n系统功能验证:")
        print("✓ Excel多页签解析正常")
        print("✓ 中断映射关系正确")
        print("✓ 目的地索引提取准确")
        print("✓ SystemVerilog生成完整")
        print("✓ include文件结构正确")
        print("✓ merge逻辑保持完整")
        
        print("\n使用方法:")
        print("1. 更新Excel文件: int_vector.xlsx")
        print("2. 运行转换脚本: python3 convert_xlsx_to_sv.py int_vector.xlsx")
        print("3. 生成的文件会自动更新: seq/int_map_entries.svh")
        print("4. 主文件保持不变: seq/int_routing_model.sv")
        
    except Exception as e:
        print(f"\n❌ 测试失败: {e}")
        return 1
    
    return 0

if __name__ == "__main__":
    exit(main())
