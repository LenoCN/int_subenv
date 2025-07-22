#!/usr/bin/env python3
"""
验证 iosub_to_io 监测机制已被正确关闭的脚本
"""

import re
import sys
from pathlib import Path

def verify_int_map_entries():
    """验证中断映射条目中的 IO 监测已被禁用"""
    print("🔍 验证 seq/int_map_entries.svh 中的 IO 监测配置...")
    
    file_path = Path("seq/int_map_entries.svh")
    if not file_path.exists():
        print(f"❌ 文件不存在: {file_path}")
        return False
    
    with open(file_path, 'r', encoding='utf-8') as f:
        content = f.read()
    
    # 检查是否还有任何 iosub_to_io_intr 引用
    iosub_to_io_matches = re.findall(r'iosub_to_io_intr', content)
    if iosub_to_io_matches:
        print(f"❌ 仍然发现 {len(iosub_to_io_matches)} 个 iosub_to_io_intr 引用")
        return False
    
    # 检查4个特定中断的配置
    target_interrupts = [
        "iosub_strap_load_fail_intr",
        "scp2io_wdt_ws1_intr", 
        "mcp2io_wdt_ws1_intr",
        "pvt_temp_alarm_intr"
    ]
    
    all_disabled = True
    for interrupt_name in target_interrupts:
        # 查找中断条目
        pattern = rf'name:"{interrupt_name}".*?to_io:(\d+).*?rtl_path_io:"([^"]*)".*?dest_index_io:(-?\d+)'
        match = re.search(pattern, content)
        
        if not match:
            print(f"❌ 未找到中断: {interrupt_name}")
            all_disabled = False
            continue
            
        to_io, rtl_path_io, dest_index_io = match.groups()
        
        if to_io != "0" or rtl_path_io != "" or dest_index_io != "-1":
            print(f"❌ {interrupt_name} IO监测未正确禁用:")
            print(f"   to_io: {to_io} (应为0)")
            print(f"   rtl_path_io: '{rtl_path_io}' (应为空)")
            print(f"   dest_index_io: {dest_index_io} (应为-1)")
            all_disabled = False
        else:
            print(f"✅ {interrupt_name} IO监测已正确禁用")
    
    return all_disabled

def verify_monitor():
    """验证监控器中的 IO 路径监测已被禁用"""
    print("\n🔍 验证 env/int_monitor.sv 中的 IO 监测逻辑...")
    
    file_path = Path("env/int_monitor.sv")
    if not file_path.exists():
        print(f"❌ 文件不存在: {file_path}")
        return False
    
    with open(file_path, 'r', encoding='utf-8') as f:
        content = f.read()
    
    # 检查 IO 监测逻辑是否被注释
    io_monitor_pattern = r'//.*if \(info\.rtl_path_io != ""\) monitor_single_path\(info, "IO", info\.rtl_path_io\);'
    if re.search(io_monitor_pattern, content):
        print("✅ IO 监测逻辑已被正确注释")
        return True
    
    # 检查是否还有未注释的 IO 监测逻辑
    active_io_pattern = r'if \(info\.rtl_path_io != ""\) monitor_single_path\(info, "IO", info\.rtl_path_io\);'
    if re.search(active_io_pattern, content):
        print("❌ 发现未注释的 IO 监测逻辑")
        return False
    
    print("✅ 未发现活跃的 IO 监测逻辑")
    return True

def main():
    """主函数"""
    print("=" * 60)
    print("🚀 验证 iosub_to_io 监测机制关闭状态")
    print("=" * 60)
    
    # 切换到项目根目录
    script_dir = Path(__file__).parent
    project_root = script_dir.parent
    import os
    os.chdir(project_root)
    
    success = True
    
    # 验证中断映射条目
    if not verify_int_map_entries():
        success = False
    
    # 验证监控器
    if not verify_monitor():
        success = False
    
    print("\n" + "=" * 60)
    if success:
        print("🎉 验证成功！所有4个 iosub_to_io 监测机制已被正确关闭")
        print("\n关闭的监测机制包括:")
        print("  1. iosub_strap_load_fail_intr (iosub_to_io_intr[0])")
        print("  2. scp2io_wdt_ws1_intr (iosub_to_io_intr[1])")
        print("  3. mcp2io_wdt_ws1_intr (iosub_to_io_intr[2])")
        print("  4. pvt_temp_alarm_intr (iosub_to_io_intr[3])")
        print("\n修改的文件:")
        print("  - seq/int_map_entries.svh: 禁用了4个中断的IO目标配置")
        print("  - env/int_monitor.sv: 注释了IO路径监测逻辑")
    else:
        print("❌ 验证失败！请检查上述错误并修复")
        sys.exit(1)
    
    print("=" * 60)

if __name__ == "__main__":
    main()
