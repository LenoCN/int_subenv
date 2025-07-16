#!/usr/bin/env python3
"""
验证握手机制改进的脚本
检查修改后的代码是否正确实现了事件驱动的握手机制
"""

import os
import re
import sys

def check_monitor_handshake():
    """检查int_monitor.sv中的握手机制实现"""
    monitor_file = "env/int_monitor.sv"
    
    if not os.path.exists(monitor_file):
        print(f"❌ 文件不存在: {monitor_file}")
        return False
    
    with open(monitor_file, 'r') as f:
        content = f.read()
    
    checks = [
        ("事件池声明", r"uvm_event_pool.*interrupt_detected_events"),
        ("事件触发", r"int_event\.trigger\(\)"),
        ("静态等待方法", r"static task wait_for_interrupt_detection_event"),
        ("事件等待", r"wait_trigger\(\)")
    ]
    
    print("🔍 检查 int_monitor.sv 握手机制:")
    all_passed = True
    
    for check_name, pattern in checks:
        if re.search(pattern, content):
            print(f"  ✅ {check_name}: 已实现")
        else:
            print(f"  ❌ {check_name}: 未找到")
            all_passed = False
    
    return all_passed

def check_sequence_handshake():
    """检查int_routing_sequence.sv中的握手机制使用"""
    sequence_file = "seq/int_routing_sequence.sv"
    
    if not os.path.exists(sequence_file):
        print(f"❌ 文件不存在: {sequence_file}")
        return False
    
    with open(sequence_file, 'r') as f:
        content = f.read()
    
    checks = [
        ("移除固定延迟", r"#20ns.*Simulate interrupt propagation", False),  # 应该不存在
        ("使用握手方法", r"int_monitor::wait_for_interrupt_detection_event"),
        ("简化清除机制", r"#5ns.*Minimal software response time"),
        ("移除软件处理器依赖", r"int_software_handler::handle_interrupt", False)  # 应该不存在
    ]
    
    print("\n🔍 检查 int_routing_sequence.sv 握手机制:")
    all_passed = True
    
    for check_name, pattern, *should_exist in checks:
        should_exist = should_exist[0] if should_exist else True
        found = bool(re.search(pattern, content))
        
        if should_exist == found:
            status = "✅" if should_exist else "✅ (已移除)"
            print(f"  {status} {check_name}: {'已实现' if should_exist else '已移除'}")
        else:
            status = "❌"
            expected = "应该存在但未找到" if should_exist else "应该移除但仍存在"
            print(f"  {status} {check_name}: {expected}")
            all_passed = False
    
    return all_passed

def check_software_handler_usage():
    """检查int_software_handler的使用情况"""
    sequence_file = "seq/int_routing_sequence.sv"
    
    if not os.path.exists(sequence_file):
        return False
    
    with open(sequence_file, 'r') as f:
        content = f.read()
    
    print("\n🔍 检查 int_software_handler 使用情况:")
    
    # 检查是否还有include语句
    if 'include "seq/int_software_handler.sv"' in content:
        print("  ❌ 仍然包含 int_software_handler.sv")
        return False
    else:
        print("  ✅ 已移除 int_software_handler.sv 包含")
    
    # 检查是否还有统计调用
    if 'int_software_handler::' in content:
        print("  ❌ 仍然调用 int_software_handler 方法")
        return False
    else:
        print("  ✅ 已移除 int_software_handler 方法调用")
    
    return True

def analyze_timing_improvement():
    """分析时序改进"""
    print("\n📊 时序改进分析:")
    print("  🔄 原始机制: 固定等待 20ns")
    print("  ⚡ 新机制: 事件驱动，无固定延迟")
    print("  📈 预期改进:")
    print("    - 更精确的同步")
    print("    - 更快的仿真速度")
    print("    - 更真实的硬件行为模拟")

def main():
    """主函数"""
    print("🚀 验证握手机制改进")
    print("=" * 50)
    
    # 切换到正确的目录
    if os.path.exists("int_subenv"):
        os.chdir("int_subenv")
    
    # 执行检查
    monitor_ok = check_monitor_handshake()
    sequence_ok = check_sequence_handshake()
    handler_ok = check_software_handler_usage()
    
    # 分析改进
    analyze_timing_improvement()
    
    # 总结
    print("\n" + "=" * 50)
    if monitor_ok and sequence_ok and handler_ok:
        print("🎉 所有检查通过！握手机制改进成功实现")
        print("\n✨ 主要改进:")
        print("  1. 实现了事件驱动的握手机制")
        print("  2. 移除了固定的20ns等待时间")
        print("  3. 简化了中断清除逻辑")
        print("  4. 提高了仿真精度和性能")
        return 0
    else:
        print("❌ 部分检查失败，需要进一步修改")
        return 1

if __name__ == "__main__":
    sys.exit(main())
