#!/usr/bin/env python3
"""
验证IODAP中断源更新的脚本

验证以下更改：
1. Hierarchy更新为：top_tb.multidie_top.DUT[0].u_str_top.u_iosub_top_wrap.u0_iosub_top_wrap_hd.u0_iosub_top_wrap_raw.u_iodap
2. 信号名称映射关系：
   - iodap_chk_err_etf0 -> chk_err_etf0
   - iodap_chk_err_etf1 -> chk_err_etf1
   - iodap_etr_buf_intr -> etr_bufintr
   - iodap_catu_addrerr_intr -> catu_addrerr
   - iodap_sdc600_intr -> sdc600_intr
"""

import re
import sys
import json
from pathlib import Path
from generate_signal_paths import SignalPathGenerator

def verify_hierarchy_config():
    """验证hierarchy配置文件中的IODAP配置"""
    print("🔍 验证 config/hierarchy_config.json 中的IODAP配置...")
    
    config_file = Path("config/hierarchy_config.json")
    if not config_file.exists():
        print(f"❌ 配置文件不存在: {config_file}")
        return False
    
    with open(config_file, 'r', encoding='utf-8') as f:
        config = json.load(f)
    
    # 检查base_hierarchy中是否有iodap条目
    base_hierarchy = config.get("base_hierarchy", {})
    expected_iodap_hierarchy = "top_tb.multidie_top.DUT[0].u_str_top.u_iosub_top_wrap.u0_iosub_top_wrap_hd.u0_iosub_top_wrap_raw.u_iodap"
    
    if "iodap" not in base_hierarchy:
        print("❌ base_hierarchy中缺少iodap条目")
        return False
    
    if base_hierarchy["iodap"] != expected_iodap_hierarchy:
        print(f"❌ iodap hierarchy不正确:")
        print(f"   期望: {expected_iodap_hierarchy}")
        print(f"   实际: {base_hierarchy['iodap']}")
        return False
    
    print("✅ base_hierarchy中的iodap配置正确")
    
    # 检查IODAP interrupt group配置
    interrupt_groups = config.get("interrupt_groups", {})
    if "IODAP" not in interrupt_groups:
        print("❌ interrupt_groups中缺少IODAP条目")
        return False
    
    iodap_config = interrupt_groups["IODAP"]
    
    # 检查必要的配置项
    required_fields = ["hierarchy", "use_interrupt_name_as_signal", "special_signals"]
    for field in required_fields:
        if field not in iodap_config:
            print(f"❌ IODAP配置中缺少{field}字段")
            return False
    
    if iodap_config["hierarchy"] != "iodap":
        print(f"❌ IODAP hierarchy字段不正确: {iodap_config['hierarchy']}")
        return False
    
    if not iodap_config["use_interrupt_name_as_signal"]:
        print("❌ IODAP use_interrupt_name_as_signal应为true")
        return False
    
    # 检查special_signals映射
    expected_mappings = {
        "iodap_chk_err_etf0": "chk_err_etf0",
        "iodap_chk_err_etf1": "chk_err_etf1",
        "iodap_etr_buf_intr": "etr_bufintr",
        "iodap_catu_addrerr_intr": "catu_addrerr",
        "iodap_sdc600_intr": "sdc600_intr"
    }
    
    special_signals = iodap_config.get("special_signals", {})
    for interrupt_name, expected_signal in expected_mappings.items():
        if interrupt_name not in special_signals:
            print(f"❌ special_signals中缺少{interrupt_name}映射")
            return False
        
        if special_signals[interrupt_name] != expected_signal:
            print(f"❌ {interrupt_name}信号映射不正确:")
            print(f"   期望: {expected_signal}")
            print(f"   实际: {special_signals[interrupt_name]}")
            return False
    
    print("✅ IODAP interrupt group配置正确")
    return True

def verify_signal_path_generation():
    """验证信号路径生成是否正确"""
    print("\n🔍 验证信号路径生成...")
    
    try:
        generator = SignalPathGenerator()
    except Exception as e:
        print(f"❌ 无法创建SignalPathGenerator: {e}")
        return False
    
    # 测试IODAP中断的信号路径生成
    test_cases = [
        ("iodap_chk_err_etf0", 0, "chk_err_etf0"),
        ("iodap_chk_err_etf1", 1, "chk_err_etf1"),
        ("iodap_etr_buf_intr", 2, "etr_bufintr"),
        ("iodap_catu_addrerr_intr", 3, "catu_addrerr"),
        ("iodap_sdc600_intr", 4, "sdc600_intr")
    ]
    
    expected_base_path = "top_tb.multidie_top.DUT[0].u_str_top.u_iosub_top_wrap.u0_iosub_top_wrap_hd.u0_iosub_top_wrap_raw.u_iodap"
    
    all_passed = True
    for interrupt_name, index, expected_signal in test_cases:
        try:
            generated_path = generator.generate_source_path(interrupt_name, "IODAP", index)
            expected_path = f"{expected_base_path}.{expected_signal}"
            
            if generated_path == expected_path:
                print(f"✅ {interrupt_name}: {generated_path}")
            else:
                print(f"❌ {interrupt_name}路径生成错误:")
                print(f"   期望: {expected_path}")
                print(f"   实际: {generated_path}")
                all_passed = False
                
        except Exception as e:
            print(f"❌ {interrupt_name}路径生成异常: {e}")
            all_passed = False
    
    return all_passed

def verify_int_map_entries():
    """验证int_map_entries.svh中的IODAP条目"""
    print("\n🔍 验证 seq/int_map_entries.svh 中的IODAP条目...")
    
    entries_file = Path("seq/int_map_entries.svh")
    if not entries_file.exists():
        print(f"❌ 文件不存在: {entries_file}")
        return False
    
    with open(entries_file, 'r', encoding='utf-8') as f:
        content = f.read()
    
    # 查找所有IODAP中断条目
    iodap_pattern = r'name:"(iodap_[^"]+)".*?rtl_path_src:"([^"]*)"'
    matches = re.findall(iodap_pattern, content)
    
    if len(matches) != 5:
        print(f"❌ 找到{len(matches)}个IODAP条目，期望5个")
        return False
    
    # 验证每个条目的路径
    expected_mappings = {
        "iodap_chk_err_etf0": "chk_err_etf0",
        "iodap_chk_err_etf1": "chk_err_etf1",
        "iodap_etr_buf_intr": "etr_bufintr",
        "iodap_catu_addrerr_intr": "catu_addrerr",
        "iodap_sdc600_intr": "sdc600_intr"
    }
    
    expected_base_path = "top_tb.multidie_top.DUT[0].u_str_top.u_iosub_top_wrap.u0_iosub_top_wrap_hd.u0_iosub_top_wrap_raw.u_iodap"
    
    all_correct = True
    for interrupt_name, rtl_path in matches:
        if interrupt_name not in expected_mappings:
            print(f"❌ 未知的IODAP中断: {interrupt_name}")
            all_correct = False
            continue
        
        expected_signal = expected_mappings[interrupt_name]
        expected_path = f"{expected_base_path}.{expected_signal}"
        
        if rtl_path == expected_path:
            print(f"✅ {interrupt_name}: {rtl_path}")
        else:
            print(f"❌ {interrupt_name}路径不正确:")
            print(f"   期望: {expected_path}")
            print(f"   实际: {rtl_path}")
            all_correct = False
    
    return all_correct

def main():
    """主验证函数"""
    print("IODAP中断源更新验证")
    print("=" * 50)
    
    # 切换到工作目录
    script_dir = Path(__file__).parent
    workspace_dir = script_dir.parent
    import os
    os.chdir(workspace_dir)
    
    print(f"工作目录: {workspace_dir}")
    
    # 运行验证测试
    tests = [
        ("Hierarchy配置验证", verify_hierarchy_config),
        ("信号路径生成验证", verify_signal_path_generation),
        ("中断映射条目验证", verify_int_map_entries),
    ]
    
    results = []
    for test_name, test_func in tests:
        print(f"\n{'='*60}")
        print(f"运行: {test_name}")
        print('='*60)
        
        try:
            result = test_func()
            results.append((test_name, result))
        except Exception as e:
            print(f"测试异常: {e}")
            results.append((test_name, False))
    
    # 总结
    print(f"\n{'='*60}")
    print("验证总结")
    print('='*60)
    
    passed = 0
    for test_name, result in results:
        status = "通过" if result else "失败"
        symbol = "✅" if result else "❌"
        print(f"  {symbol} {test_name}: {status}")
        if result:
            passed += 1
    
    print(f"\n总体结果: {passed}/{len(results)} 测试通过")
    
    if passed == len(results):
        print("\n🎉 所有IODAP更新验证测试通过！")
        print("\n更新摘要:")
        print("  ✅ Hierarchy已更新为: ...u_iodap")
        print("  ✅ 信号名称映射已应用:")
        print("     - iodap_chk_err_etf0 -> chk_err_etf0")
        print("     - iodap_chk_err_etf1 -> chk_err_etf1")
        print("     - iodap_etr_buf_intr -> etr_bufintr")
        print("     - iodap_catu_addrerr_intr -> catu_addrerr")
        print("     - iodap_sdc600_intr -> sdc600_intr")
        print("  ✅ RTL路径已正确更新")
        return 0
    else:
        print("\n❌ 部分验证测试失败，请检查上述错误")
        return 1

if __name__ == "__main__":
    sys.exit(main())
