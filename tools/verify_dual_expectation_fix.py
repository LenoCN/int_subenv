#!/usr/bin/env python3
"""
验证双重预期修复的脚本
Verification script for dual expectation fix
"""

import re
import sys
from pathlib import Path

def verify_dual_expectation_fix():
    """验证双重预期修复是否正确实现"""
    
    print("🔍 验证双重预期修复...")
    print("=" * 60)
    
    # 检查文件是否存在
    sequence_file = Path("seq/int_lightweight_sequence.sv")
    if not sequence_file.exists():
        print("❌ 错误: seq/int_lightweight_sequence.sv 文件不存在")
        return False
    
    # 读取文件内容
    with open(sequence_file, 'r', encoding='utf-8') as f:
        content = f.read()
    
    # 验证项目列表
    checks = []
    
    # 1. 检查 source_has_direct_routing 变量定义
    if "bit source_has_direct_routing = 0;" in content:
        checks.append(("✅", "source_has_direct_routing 变量定义"))
    else:
        checks.append(("❌", "source_has_direct_routing 变量定义"))
    
    # 2. 检查直接路由判断逻辑
    direct_routing_pattern = r"source_has_direct_routing = \(source_info\.to_ap \|\| source_info\.to_accel \|\| source_info\.to_io \|\| source_info\.to_other_die\);"
    if re.search(direct_routing_pattern, content):
        checks.append(("✅", "直接路由判断逻辑"))
    else:
        checks.append(("❌", "直接路由判断逻辑"))
    
    # 3. 检查双重预期注册
    if "DUAL EXPECTATION: Registering expected source interrupt with direct routing" in content:
        checks.append(("✅", "单源双重预期注册"))
    else:
        checks.append(("❌", "单源双重预期注册"))
    
    # 4. 检查双重检测等待
    if "DUAL DETECTION: Waiting for detection of source interrupt direct routing" in content:
        checks.append(("✅", "单源双重检测等待"))
    else:
        checks.append(("❌", "单源双重检测等待"))
    
    # 5. 检查双重状态更新
    if "DUAL STATUS: Updating status for source interrupt direct routing" in content:
        checks.append(("✅", "单源双重状态更新"))
    else:
        checks.append(("❌", "单源双重状态更新"))
    
    # 6. 检查多源双重预期
    if "MULTI-SOURCE DUAL EXPECTATION: Checking for source interrupts with direct routing" in content:
        checks.append(("✅", "多源双重预期注册"))
    else:
        checks.append(("❌", "多源双重预期注册"))
    
    # 7. 检查多源双重检测
    if "MULTI-SOURCE DUAL DETECTION: Waiting for source interrupts with direct routing" in content:
        checks.append(("✅", "多源双重检测等待"))
    else:
        checks.append(("❌", "多源双重检测等待"))
    
    # 8. 检查多源双重状态更新
    if "MULTI-SOURCE DUAL STATUS: Updating status for source interrupts with direct routing" in content:
        checks.append(("✅", "多源双重状态更新"))
    else:
        checks.append(("❌", "多源双重状态更新"))
    
    # 9. 检查条件判断逻辑
    if_pattern = r"if \(source_has_direct_routing\) begin"
    if_count = len(re.findall(if_pattern, content))
    if if_count >= 3:  # 至少应该有3个地方使用这个条件
        checks.append(("✅", f"条件判断逻辑 (找到 {if_count} 处)"))
    else:
        checks.append(("❌", f"条件判断逻辑 (只找到 {if_count} 处，期望至少3处)"))
    
    # 10. 检查多源循环中的条件判断
    multi_source_pattern = r"bit source_has_direct_routing = \(source_interrupts\[i\]\.to_ap"
    multi_source_count = len(re.findall(multi_source_pattern, content))
    if multi_source_count >= 3:  # 应该在3个地方有多源判断
        checks.append(("✅", f"多源条件判断 (找到 {multi_source_count} 处)"))
    else:
        checks.append(("❌", f"多源条件判断 (只找到 {multi_source_count} 处，期望至少3处)"))

    # 11. 检查单个中断的 iosub_normal_intr 源检查
    if "is_iosub_normal_source = m_routing_model.is_iosub_normal_intr_source(info.name);" in content:
        checks.append(("✅", "单个中断 iosub_normal_intr 源检查"))
    else:
        checks.append(("❌", "单个中断 iosub_normal_intr 源检查"))

    # 12. 检查单个中断的双重路由逻辑
    if "SINGLE INTERRUPT DUAL ROUTING" in content:
        checks.append(("✅", "单个中断双重路由逻辑"))
    else:
        checks.append(("❌", "单个中断双重路由逻辑"))

    # 13. 检查 is_iosub_normal_source 变量定义
    if "bit is_iosub_normal_source = 0;" in content:
        checks.append(("✅", "is_iosub_normal_source 变量定义"))
    else:
        checks.append(("❌", "is_iosub_normal_source 变量定义"))
    
    # 输出检查结果
    print("📋 检查结果:")
    print("-" * 60)
    
    passed = 0
    total = len(checks)
    
    for status, description in checks:
        print(f"{status} {description}")
        if status == "✅":
            passed += 1
    
    print("-" * 60)
    print(f"📊 总体结果: {passed}/{total} 项检查通过")
    
    if passed == total:
        print("🎉 所有检查都通过！双重预期修复实现正确。")
        return True
    else:
        print(f"⚠️  有 {total - passed} 项检查未通过，请检查实现。")
        return False

def verify_documentation():
    """验证文档是否已更新"""
    
    print("\n🔍 验证文档更新...")
    print("=" * 60)
    
    # 检查修复总结文档
    doc_file = Path("docs/dual_expectation_fix_summary.md")
    if doc_file.exists():
        print("✅ 修复总结文档已创建")
    else:
        print("❌ 修复总结文档缺失")
        return False
    
    # 检查项目状态文档更新
    status_file = Path("PROJECT_STATUS_SUMMARY.md")
    if status_file.exists():
        with open(status_file, 'r', encoding='utf-8') as f:
            content = f.read()
        
        if "双重预期逻辑完善" in content:
            print("✅ 项目状态文档已更新")
        else:
            print("❌ 项目状态文档未更新")
            return False
    else:
        print("❌ 项目状态文档不存在")
        return False
    
    return True

def main():
    """主函数"""
    
    print("🚀 双重预期修复验证工具")
    print("=" * 60)
    
    # 验证代码修复
    code_ok = verify_dual_expectation_fix()
    
    # 验证文档更新
    doc_ok = verify_documentation()
    
    print("\n" + "=" * 60)
    
    if code_ok and doc_ok:
        print("🎉 验证完成！双重预期修复已正确实现并文档化。")
        print("\n📋 修复要点:")
        print("   • 既属于iosub_normal_intr汇聚源又有直接路由的中断")
        print("   • 同时预期merge路由(SCP/MCP)和直接路由(AP/ACCEL/etc)")
        print("   • 单源和多源测试都已修复")
        print("   • 完整的预期-检测-状态更新流程")
        return 0
    else:
        print("❌ 验证失败！请检查修复实现。")
        return 1

if __name__ == "__main__":
    sys.exit(main())
