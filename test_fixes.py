#!/usr/bin/env python3
"""
测试修复后的验证环境
"""

import os
import re
import sys

def test_handshake_mechanism():
    """测试握手机制修复 - UVM最佳实践"""
    print("🔍 测试握手机制修复 - UVM最佳实践...")

    # 检查monitor中不应该有静态方法供sequence调用
    with open('env/int_monitor.sv', 'r') as f:
        monitor_content = f.read()

    if 'static task wait_for_interrupt_detection_event' in monitor_content:
        print("  ❌ int_monitor.sv: 不应该有静态方法供sequence调用 (违反UVM最佳实践)")
        return False
    else:
        print("  ✅ int_monitor.sv: 正确移除了不合适的静态方法")

    # 检查sequence中使用正确的base class方法
    with open('seq/int_lightweight_sequence.sv', 'r') as f:
        seq_content = f.read()

    if 'int_monitor::wait_for_interrupt_detection_event' in seq_content:
        print("  ❌ int_lightweight_sequence.sv: 仍在直接调用monitor方法 (违反UVM最佳实践)")
        return False
    elif 'wait_for_interrupt_detection(info)' in seq_content:
        print("  ✅ int_lightweight_sequence.sv: 正确使用base sequence的方法")
    else:
        print("  ❌ int_lightweight_sequence.sv: 等待方法调用缺失")
        return False

    # 检查base sequence中的正确实现
    with open('seq/int_base_sequence.sv', 'r') as f:
        base_content = f.read()

    if 'task wait_for_interrupt_detection' in base_content and 'event_manager.wait_for_interrupt_detection' in base_content:
        print("  ✅ int_base_sequence.sv: 正确实现了UVM架构的等待方法")
    else:
        print("  ❌ int_base_sequence.sv: 缺少正确的等待方法实现")
        return False

    # 检查事件管理器中的wait_trigger
    with open('env/int_event_manager.sv', 'r') as f:
        event_content = f.read()

    if 'wait_trigger()' in event_content:
        print("  ✅ int_event_manager.sv: wait_trigger调用存在")
    else:
        print("  ❌ int_event_manager.sv: wait_trigger调用缺失")
        return False

    return True

def test_sequencer_paths():
    """测试sequencer路径修复"""
    print("\n🔍 测试sequencer路径修复...")
    
    test_files = [
        'test/tc_merge_interrupt_test.sv',
        'test/tc_all_merge_interrupts.sv', 
        'test/tc_enhanced_stimulus_test.sv',
        'test/tc_comprehensive_merge_test.sv'
    ]
    
    all_fixed = True
    
    for test_file in test_files:
        if os.path.exists(test_file):
            with open(test_file, 'r') as f:
                content = f.read()
            
            if 'env.agent.sequencer' in content:
                print(f"  ❌ {test_file}: 仍使用错误的sequencer路径")
                all_fixed = False
            elif 'env.m_sequencer' in content:
                print(f"  ✅ {test_file}: 使用正确的sequencer路径")
            else:
                print(f"  ⚠️  {test_file}: 未找到sequencer引用")
    
    return all_fixed

def test_driver_architecture():
    """测试driver架构完整性"""
    print("\n🔍 测试driver架构完整性...")
    
    # 检查driver文件
    if not os.path.exists('env/int_driver.sv'):
        print("  ❌ int_driver.sv 文件缺失")
        return False
    
    with open('env/int_driver.sv', 'r') as f:
        driver_content = f.read()
    
    required_methods = [
        'drive_level_stimulus',
        'drive_edge_stimulus', 
        'drive_pulse_stimulus',
        'clear_interrupt_stimulus'
    ]
    
    all_methods_present = True
    for method in required_methods:
        if method in driver_content:
            print(f"  ✅ Driver方法: {method}")
        else:
            print(f"  ❌ Driver方法缺失: {method}")
            all_methods_present = False
    
    return all_methods_present

def test_stimulus_item():
    """测试stimulus item定义"""
    print("\n🔍 测试stimulus item定义...")
    
    if not os.path.exists('seq/int_stimulus_item.sv'):
        print("  ❌ int_stimulus_item.sv 文件缺失")
        return False
    
    with open('seq/int_stimulus_item.sv', 'r') as f:
        content = f.read()
    
    required_elements = [
        'STIMULUS_ASSERT',
        'STIMULUS_DEASSERT', 
        'STIMULUS_CLEAR',
        'create_stimulus'
    ]
    
    all_present = True
    for element in required_elements:
        if element in content:
            print(f"  ✅ Stimulus元素: {element}")
        else:
            print(f"  ❌ Stimulus元素缺失: {element}")
            all_present = False
    
    return all_present

def main():
    """主测试函数"""
    print("🚀 验证环境修复测试")
    print("=" * 50)
    
    tests = [
        ("UVM最佳实践握手机制", test_handshake_mechanism),
        ("Sequencer路径", test_sequencer_paths),
        ("Driver架构", test_driver_architecture),
        ("Stimulus Item", test_stimulus_item)
    ]
    
    all_passed = True
    results = []
    
    for test_name, test_func in tests:
        try:
            result = test_func()
            results.append((test_name, result))
            if not result:
                all_passed = False
        except Exception as e:
            print(f"  ❌ 测试 {test_name} 出现异常: {e}")
            results.append((test_name, False))
            all_passed = False
    
    # 总结
    print("\n" + "=" * 50)
    print("测试结果总结:")
    for test_name, result in results:
        status = "✅ 通过" if result else "❌ 失败"
        print(f"  {test_name}: {status}")
    
    if all_passed:
        print("\n🎉 所有测试通过！验证环境修复成功")
        return 0
    else:
        print("\n❌ 部分测试失败，需要进一步修复")
        return 1

if __name__ == "__main__":
    sys.exit(main())
