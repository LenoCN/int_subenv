#!/usr/bin/env python3
"""
验证IO DIE中断源已被成功移除的脚本
"""

import re
import sys
from pathlib import Path

def verify_int_map_entries():
    """验证int_map_entries.svh中不包含IO_DIE组"""
    print("🔍 验证 seq/int_map_entries.svh 中的IO_DIE组已被移除...")
    
    file_path = Path("seq/int_map_entries.svh")
    if not file_path.exists():
        print(f"❌ 文件不存在: {file_path}")
        return False
    
    with open(file_path, 'r', encoding='utf-8') as f:
        content = f.read()
    
    # 检查是否还有任何IO_DIE引用
    io_die_matches = re.findall(r'IO_DIE', content)
    if io_die_matches:
        print(f"❌ 仍然发现 {len(io_die_matches)} 个 IO_DIE 引用")
        return False
    
    # 检查是否还有io_die_intr相关的中断名称
    io_die_intr_matches = re.findall(r'io_die_intr_\d+_intr', content)
    if io_die_intr_matches:
        print(f"❌ 仍然发现 {len(io_die_intr_matches)} 个 io_die_intr 中断")
        return False
    
    # 检查是否还有pad_int_i路径引用
    pad_int_matches = re.findall(r'pad_int_i\[\d+\]', content)
    if pad_int_matches:
        print(f"❌ 仍然发现 {len(pad_int_matches)} 个 pad_int_i 路径引用")
        return False
    
    print("✅ 确认 IO_DIE 组已被完全移除")
    return True

def verify_convert_script():
    """验证convert_xlsx_to_sv.py脚本的修改"""
    print("\n🔍 验证 tools/convert_xlsx_to_sv.py 脚本的修改...")
    
    script_path = Path("tools/convert_xlsx_to_sv.py")
    if not script_path.exists():
        print(f"❌ 文件不存在: {script_path}")
        return False
    
    with open(script_path, 'r', encoding='utf-8') as f:
        content = f.read()
    
    # 检查GROUP_MAP中IO_DIE映射是否被注释
    # 检查是否有未注释的IO_DIE映射
    uncommented_io_die = re.search(r'^\s*"外部中断源-from IO DIE": "IO_DIE"', content, re.MULTILINE)
    if uncommented_io_die:
        print("❌ GROUP_MAP中IO_DIE映射未被注释")
        return False

    # 检查是否有注释的IO_DIE映射
    commented_io_die = re.search(r'^\s*#.*"外部中断源-from IO DIE": "IO_DIE"', content, re.MULTILINE)
    if not commented_io_die:
        print("❌ 未找到注释的IO_DIE映射")
        return False
    
    # 检查是否添加了跳过IO_DIE的逻辑
    if 'SKIP_IO_DIE' not in content:
        print("❌ 未找到跳过IO_DIE的逻辑")
        return False
    
    # 检查generate_sv_file函数中的跳过逻辑
    if 'if group_name == "IO_DIE":' not in content:
        print("❌ generate_sv_file函数中未添加跳过IO_DIE的逻辑")
        return False
    
    print("✅ 确认脚本修改正确")
    return True

def count_interrupts():
    """统计当前中断数量"""
    print("\n📊 统计当前中断数量...")
    
    file_path = Path("seq/int_map_entries.svh")
    if not file_path.exists():
        print(f"❌ 文件不存在: {file_path}")
        return False
    
    with open(file_path, 'r', encoding='utf-8') as f:
        content = f.read()
    
    # 统计中断条目数
    total_entries = len(re.findall(r'interrupt_map\.push_back\(entry\);', content))
    
    # 统计各组的中断数
    groups = {}
    group_pattern = r'// --- Start of (\w+) interrupts ---'
    entry_pattern = r'group:(\w+),'
    
    group_matches = re.findall(group_pattern, content)
    entry_matches = re.findall(entry_pattern, content)
    
    for group in entry_matches:
        groups[group] = groups.get(group, 0) + 1
    
    print(f"  总中断条目数: {total_entries}")
    print(f"  发现的中断组: {sorted(groups.keys())}")
    for group, count in sorted(groups.items()):
        print(f"    {group}: {count} 个中断")
    
    # 确认IO_DIE不在组列表中
    if 'IO_DIE' in groups:
        print("❌ IO_DIE组仍然存在")
        return False
    
    print("✅ 中断统计完成，确认IO_DIE组已移除")
    return True

def main():
    """主函数"""
    print("=" * 60)
    print("🚀 验证IO DIE中断源移除")
    print("=" * 60)
    
    success = True
    
    # 验证生成的文件
    if not verify_int_map_entries():
        success = False
    
    # 验证脚本修改
    if not verify_convert_script():
        success = False
    
    # 统计中断数量
    if not count_interrupts():
        success = False
    
    print("\n" + "=" * 60)
    if success:
        print("🎉 验证成功！IO DIE中断源已被完全移除")
        print("\n修改内容:")
        print("  1. tools/convert_xlsx_to_sv.py: 注释了IO_DIE映射，添加了跳过逻辑")
        print("  2. seq/int_map_entries.svh: 移除了所有IO_DIE相关的中断条目")
        print("\n影响:")
        print("  - 减少了32个IO_DIE中断条目")
        print("  - 生成过程将自动跳过'外部中断源-from IO DIE'部分")
    else:
        print("❌ 验证失败！请检查上述错误并修复")
        sys.exit(1)
    
    print("=" * 60)

if __name__ == "__main__":
    main()
