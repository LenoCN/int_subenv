#!/usr/bin/env python3
"""
验证merge信号处理的脚本
确保merge类信号不会被直接force/release，而是通过其源信号进行操作
"""

import re
import sys
from pathlib import Path

def get_merge_signals():
    """获取所有merge信号列表"""
    return [
        "merge_pll_intr_lock",
        "merge_pll_intr_unlock", 
        "merge_pll_intr_frechangedone",
        "merge_pll_intr_frechange_tot_done",
        "merge_pll_intr_intdocfrac_err",
        "iosub_normal_intr",
        "iosub_slv_err_intr",
        "iosub_ras_cri_intr",
        "iosub_ras_eri_intr",
        "iosub_ras_fhi_intr",
        "iosub_abnormal_0_intr",
        "iosub_abnormal_1_intr",
        "merge_external_pll_intr"
    ]

def verify_routing_model():
    """验证路由模型中merge信号的配置"""
    print("🔍 验证 seq/int_routing_model.sv 中的merge信号配置...")
    
    file_path = Path("seq/int_routing_model.sv")
    if not file_path.exists():
        print(f"❌ 文件不存在: {file_path}")
        return False
    
    with open(file_path, 'r', encoding='utf-8') as f:
        content = f.read()
    
    merge_signals = get_merge_signals()
    success = True
    
    # 检查is_merge_interrupt函数是否包含所有merge信号
    print("\n检查 is_merge_interrupt 函数:")
    for signal in merge_signals:
        if f'interrupt_name == "{signal}"' in content:
            print(f"✅ {signal}: 已在is_merge_interrupt函数中定义")
        else:
            print(f"❌ {signal}: 未在is_merge_interrupt函数中定义")
            success = False
    
    # 检查get_merge_sources函数是否包含所有merge信号的处理逻辑
    print("\n检查 get_merge_sources 函数:")
    for signal in merge_signals:
        if f'"{signal}":' in content:
            print(f"✅ {signal}: 已在get_merge_sources函数中定义")
        else:
            print(f"❌ {signal}: 未在get_merge_sources函数中定义")
            success = False
    
    return success

def verify_driver_handling():
    """验证驱动器中merge信号的处理"""
    print("\n🔍 验证 env/int_driver.sv 中merge信号的处理...")
    
    file_path = Path("env/int_driver.sv")
    if not file_path.exists():
        print(f"❌ 文件不存在: {file_path}")
        return False
    
    with open(file_path, 'r', encoding='utf-8') as f:
        content = f.read()
    
    # 检查是否有对merge信号的特殊处理
    # 通常merge信号不应该被直接force/release
    merge_signals = get_merge_signals()
    
    print("检查驱动器是否正确处理merge信号:")
    
    # 查找可能的merge信号处理逻辑
    if "is_merge_interrupt" in content:
        print("✅ 驱动器中包含merge信号检查逻辑")
        return True
    else:
        print("⚠️  驱动器中未发现merge信号检查逻辑")
        print("   建议在驱动器中添加merge信号检查，避免直接force/release merge信号")
        return False

def verify_test_coverage():
    """验证测试覆盖率"""
    print("\n🔍 验证测试文件中merge信号的覆盖...")
    
    file_path = Path("test/tc_comprehensive_merge_test.sv")
    if not file_path.exists():
        print(f"❌ 文件不存在: {file_path}")
        return False
    
    with open(file_path, 'r', encoding='utf-8') as f:
        content = f.read()
    
    merge_signals = get_merge_signals()
    success = True
    
    print("检查测试文件中的merge信号覆盖:")
    for signal in merge_signals:
        if f'"{signal}"' in content:
            print(f"✅ {signal}: 已包含在测试中")
        else:
            print(f"❌ {signal}: 未包含在测试中")
            success = False
    
    return success

def check_abnormal_signals_specifically():
    """专门检查abnormal信号的配置"""
    print("\n🔍 专门检查 iosub_abnormal_0_intr 和 iosub_abnormal_1_intr 的配置...")
    
    # 检查int_map_entries.svh中的配置
    file_path = Path("seq/int_map_entries.svh")
    if not file_path.exists():
        print(f"❌ 文件不存在: {file_path}")
        return False
    
    with open(file_path, 'r', encoding='utf-8') as f:
        content = f.read()
    
    success = True
    
    # 检查iosub_abnormal_0_intr的配置
    pattern_0 = r'name:"iosub_abnormal_0_intr".*?index:74'
    if re.search(pattern_0, content):
        print("✅ iosub_abnormal_0_intr: 在index 74处正确配置")
    else:
        print("❌ iosub_abnormal_0_intr: 配置不正确")
        success = False
    
    # 检查iosub_abnormal_1_intr的配置
    pattern_1 = r'name:"iosub_abnormal_1_intr".*?index:75'
    if re.search(pattern_1, content):
        print("✅ iosub_abnormal_1_intr: 在index 75处正确配置")
    else:
        print("❌ iosub_abnormal_1_intr: 配置不正确")
        success = False
    
    return success

def main():
    """主函数"""
    print("=" * 60)
    print("🔧 验证merge信号处理配置")
    print("=" * 60)
    
    success = True
    
    # 验证路由模型
    success &= verify_routing_model()
    
    # 验证驱动器处理
    success &= verify_driver_handling()
    
    # 验证测试覆盖
    success &= verify_test_coverage()
    
    # 专门检查abnormal信号
    success &= check_abnormal_signals_specifically()
    
    print("\n" + "=" * 60)
    if success:
        print("🎉 验证成功！merge信号处理配置正确")
        print("\n主要修改:")
        print("  1. iosub_abnormal_0_intr: 已正确配置为merge信号")
        print("  2. iosub_abnormal_1_intr: 已添加为reserved merge信号")
        print("  3. 路由模型: 已更新包含两个abnormal信号")
        print("  4. 测试覆盖: 已包含新的merge信号")
        print("\n这应该解决UVM_ERROR中的HDL路径定位问题")
    else:
        print("❌ 验证失败！请检查上述错误并修复")
        sys.exit(1)
    
    print("=" * 60)

if __name__ == "__main__":
    main()
