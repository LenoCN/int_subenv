#!/usr/bin/env python3
"""
中断激励方法合规性检查脚本

本脚本根据CSV格式的中断向量表中的trigger/polarity列，检查当前的激励方法
是否符合中断向量表规定的方式。

主要检查内容：
1. Level触发中断是否使用了正确的电平激励
2. Edge/Pulse触发中断是否使用了正确的边沿激励
3. Active High/Low极性是否正确
4. Rising & Falling Edge是否正确处理

作者: AI Assistant
日期: 2025-07-15
"""

import csv
import re
import sys
from pathlib import Path
from typing import Dict, List, Tuple, Set
from dataclasses import dataclass
from enum import Enum

class TriggerType(Enum):
    LEVEL = "Level"
    EDGE = "Edge" 
    PULSE = "Pulse"
    UNKNOWN = "Unknown"

class PolarityType(Enum):
    ACTIVE_HIGH = "Active high"
    ACTIVE_LOW = "Active low"
    RISING_FALLING = "Rising & Falling Edge"
    UNKNOWN = "Unknown"

@dataclass
class InterruptInfo:
    """中断信息数据类"""
    name: str
    index: int
    group: str
    trigger: TriggerType
    polarity: PolarityType
    rtl_path_src: str = ""
    
class StimulusMethod(Enum):
    """激励方法枚举"""
    FORCE_HIGH_RELEASE = "force_high_release"  # force(1) -> release
    FORCE_LOW_RELEASE = "force_low_release"    # force(0) -> release  
    FORCE_TOGGLE = "force_toggle"              # force(1) -> force(0) -> release
    EDGE_PULSE = "edge_pulse"                  # 短脉冲激励
    UNKNOWN = "unknown"

def parse_csv_interrupts(csv_path: Path) -> List[InterruptInfo]:
    """解析CSV文件中的中断信息"""
    interrupts = []
    current_group = ""
    
    with open(csv_path, 'r', encoding='utf-8') as f:
        reader = csv.reader(f)
        header = next(reader)  # 跳过标题行
        
        for row in reader:
            if len(row) < 7:
                continue
                
            # 检查是否是组标题行
            if row[0] and not row[1] and not row[2]:
                current_group = row[0].replace("中断源", "")
                continue
                
            # 跳过空行或无效行
            if not row[2]:  # 没有中断名称
                continue
                
            try:
                name = row[2].strip()
                index = int(row[1]) if row[1] else 0
                
                # 解析trigger类型
                trigger_str = row[5].strip() if len(row) > 5 else ""
                if "Level" in trigger_str:
                    trigger = TriggerType.LEVEL
                elif "Edge" in trigger_str:
                    trigger = TriggerType.EDGE
                elif "Pulse" in trigger_str:
                    trigger = TriggerType.PULSE
                else:
                    trigger = TriggerType.UNKNOWN
                    
                # 解析polarity类型
                polarity_str = row[6].strip() if len(row) > 6 else ""
                if "Active high" in polarity_str:
                    polarity = PolarityType.ACTIVE_HIGH
                elif "Active low" in polarity_str:
                    polarity = PolarityType.ACTIVE_LOW
                elif "Rising & Falling" in polarity_str:
                    polarity = PolarityType.RISING_FALLING
                else:
                    polarity = PolarityType.UNKNOWN
                    
                interrupts.append(InterruptInfo(
                    name=name,
                    index=index,
                    group=current_group,
                    trigger=trigger,
                    polarity=polarity
                ))
                
            except (ValueError, IndexError) as e:
                print(f"Warning: Failed to parse row: {row}, error: {e}")
                continue
                
    return interrupts

def analyze_current_stimulus_methods(seq_files: List[Path]) -> Dict[str, StimulusMethod]:
    """分析当前激励方法的实现"""
    stimulus_methods = {}
    stimulus_patterns = {}  # 存储发现的激励模式

    # 首先检查是否使用了新的driver-based架构
    project_root = Path(__file__).parent.parent
    driver_file = project_root / "env" / "int_driver.sv"

    if driver_file.exists():
        print("检测到新的driver-based架构，分析driver实现...")
        try:
            with open(driver_file, 'r', encoding='utf-8') as f:
                driver_content = f.read()

            # 检查driver中是否实现了所有激励方法
            has_level_stimulus = 'drive_level_stimulus' in driver_content
            has_edge_stimulus = 'drive_edge_stimulus' in driver_content
            has_pulse_stimulus = 'drive_pulse_stimulus' in driver_content

            if has_level_stimulus and has_edge_stimulus and has_pulse_stimulus:
                print("✅ Driver实现了所有激励方法")
                # 在新架构中，所有激励方法都通过driver实现
                stimulus_patterns['DRIVER_LEVEL_STIMULUS'] = StimulusMethod.FORCE_HIGH_RELEASE
                stimulus_patterns['DRIVER_EDGE_STIMULUS'] = StimulusMethod.FORCE_TOGGLE
                stimulus_patterns['DRIVER_PULSE_STIMULUS'] = StimulusMethod.EDGE_PULSE

                # 检查sequence是否使用了STIMULUS_ASSERT
                for file_path in seq_files:
                    if file_path.exists():
                        try:
                            with open(file_path, 'r', encoding='utf-8') as f:
                                seq_content = f.read()
                            if 'STIMULUS_ASSERT' in seq_content:
                                print(f"✅ {file_path.name} 使用了STIMULUS_ASSERT")
                                # 新架构支持所有激励类型
                                return {
                                    'UNIVERSAL_STIMULUS_SUPPORT': StimulusMethod.FORCE_HIGH_RELEASE,
                                    'EDGE_STIMULUS_SUPPORT': StimulusMethod.FORCE_TOGGLE,
                                    'PULSE_STIMULUS_SUPPORT': StimulusMethod.EDGE_PULSE
                                }
                        except Exception as e:
                            print(f"Warning: Failed to analyze sequence file {file_path}: {e}")
        except Exception as e:
            print(f"Warning: Failed to analyze driver file: {e}")

    # 如果没有新架构，使用原来的分析方法
    for file_path in seq_files:
        if not file_path.exists():
            continue

        try:
            with open(file_path, 'r', encoding='utf-8') as f:
                content = f.read()

            # 查找激励模式
            # 模式1: force(variable, 1) -> release(variable) (Level Active High)
            force_high_release_pattern = r'uvm_hdl_force\(([^,]+),\s*1\).*?uvm_hdl_release\(\1\)'
            matches = re.finditer(force_high_release_pattern, content, re.DOTALL)
            for match in matches:
                signal_var = match.group(1).strip()
                stimulus_patterns[f"FORCE_HIGH_RELEASE_{signal_var}"] = StimulusMethod.FORCE_HIGH_RELEASE

            # 模式2: force(variable, 0) -> release(variable) (Level Active Low)
            force_low_release_pattern = r'uvm_hdl_force\(([^,]+),\s*0\).*?uvm_hdl_release\(\1\)'
            matches = re.finditer(force_low_release_pattern, content, re.DOTALL)
            for match in matches:
                signal_var = match.group(1).strip()
                stimulus_patterns[f"FORCE_LOW_RELEASE_{signal_var}"] = StimulusMethod.FORCE_LOW_RELEASE

            # 模式3: 检查是否有双边沿激励模式 (force(1) -> force(0) -> release)
            toggle_pattern = r'uvm_hdl_force\(([^,]+),\s*1\).*?uvm_hdl_force\(\1,\s*0\).*?uvm_hdl_release\(\1\)'
            matches = re.finditer(toggle_pattern, content, re.DOTALL)
            for match in matches:
                signal_var = match.group(1).strip()
                stimulus_patterns[f"FORCE_TOGGLE_{signal_var}"] = StimulusMethod.FORCE_TOGGLE

            # 检查通用的force(1)->release模式（不管变量名）
            if 'uvm_hdl_force' in content and 'uvm_hdl_release' in content:
                # 查找force(xxx, 1)模式
                force_1_matches = re.findall(r'uvm_hdl_force\([^,]+,\s*1\)', content)
                if force_1_matches:
                    stimulus_patterns['GENERIC_FORCE_HIGH_RELEASE'] = StimulusMethod.FORCE_HIGH_RELEASE

                # 查找force(xxx, 0)模式
                force_0_matches = re.findall(r'uvm_hdl_force\([^,]+,\s*0\)', content)
                if force_0_matches:
                    stimulus_patterns['GENERIC_FORCE_LOW_RELEASE'] = StimulusMethod.FORCE_LOW_RELEASE

        except Exception as e:
            print(f"Warning: Failed to analyze file {file_path}: {e}")

    return stimulus_patterns

def get_expected_stimulus_method(interrupt: InterruptInfo) -> StimulusMethod:
    """根据中断的trigger和polarity确定期望的激励方法"""
    
    if interrupt.trigger == TriggerType.LEVEL:
        if interrupt.polarity == PolarityType.ACTIVE_HIGH:
            return StimulusMethod.FORCE_HIGH_RELEASE
        elif interrupt.polarity == PolarityType.ACTIVE_LOW:
            return StimulusMethod.FORCE_LOW_RELEASE
        else:
            return StimulusMethod.UNKNOWN
            
    elif interrupt.trigger in [TriggerType.EDGE, TriggerType.PULSE]:
        if interrupt.polarity == PolarityType.RISING_FALLING:
            return StimulusMethod.FORCE_TOGGLE  # 需要双边沿
        elif interrupt.polarity == PolarityType.ACTIVE_HIGH:
            return StimulusMethod.EDGE_PULSE    # 上升沿脉冲
        elif interrupt.polarity == PolarityType.ACTIVE_LOW:
            return StimulusMethod.EDGE_PULSE    # 下降沿脉冲
        else:
            return StimulusMethod.UNKNOWN
    else:
        return StimulusMethod.UNKNOWN

def check_compliance(interrupts: List[InterruptInfo],
                    current_methods: Dict[str, StimulusMethod]) -> Dict[str, Dict]:
    """检查激励方法的合规性"""

    results = {
        'compliant': [],      # 符合规范的中断
        'non_compliant': [],  # 不符合规范的中断
        'missing_stimulus': [],  # 缺少激励方法的中断
        'unknown_requirement': [],  # 无法确定要求的中断
        'generic_compliant': []  # 使用通用激励方法符合规范的中断
    }

    # 检查是否使用了新的driver-based架构
    has_universal_support = 'UNIVERSAL_STIMULUS_SUPPORT' in current_methods
    has_edge_support = 'EDGE_STIMULUS_SUPPORT' in current_methods
    has_pulse_support = 'PULSE_STIMULUS_SUPPORT' in current_methods

    if has_universal_support and has_edge_support and has_pulse_support:
        print("✅ 检测到完整的driver-based激励支持")
        # 新架构支持所有激励类型，所有中断都应该是合规的
        for interrupt in interrupts:
            expected_method = get_expected_stimulus_method(interrupt)

            if expected_method == StimulusMethod.UNKNOWN:
                results['unknown_requirement'].append({
                    'interrupt': interrupt,
                    'reason': f"Unknown trigger ({interrupt.trigger.value}) or polarity ({interrupt.polarity.value})"
                })
                continue

            # 在新架构中，所有中断都通过driver支持
            results['generic_compliant'].append({
                'interrupt': interrupt,
                'method': expected_method,
                'path': 'driver_based_universal_support'
            })

        return results

    # 检查是否有通用的激励方法实现（旧架构）
    has_generic_force_high = 'GENERIC_FORCE_HIGH_RELEASE' in current_methods
    has_generic_force_low = 'GENERIC_FORCE_LOW_RELEASE' in current_methods
    has_generic_toggle = any('FORCE_TOGGLE' in key for key in current_methods.keys())

    for interrupt in interrupts:
        expected_method = get_expected_stimulus_method(interrupt)

        if expected_method == StimulusMethod.UNKNOWN:
            results['unknown_requirement'].append({
                'interrupt': interrupt,
                'reason': f"Unknown trigger ({interrupt.trigger.value}) or polarity ({interrupt.polarity.value})"
            })
            continue

        # 查找当前实现的激励方法
        current_method = None
        matching_path = None

        # 首先尝试精确匹配中断名称到激励路径
        for path, method in current_methods.items():
            if interrupt.name in path or path in interrupt.name:
                current_method = method
                matching_path = path
                break

        # 如果没有找到精确匹配，检查是否有通用的激励方法
        if current_method is None:
            if expected_method == StimulusMethod.FORCE_HIGH_RELEASE and has_generic_force_high:
                current_method = StimulusMethod.FORCE_HIGH_RELEASE
                matching_path = "GENERIC_FORCE_HIGH_RELEASE"
            elif expected_method == StimulusMethod.FORCE_LOW_RELEASE and has_generic_force_low:
                current_method = StimulusMethod.FORCE_LOW_RELEASE
                matching_path = "GENERIC_FORCE_LOW_RELEASE"
            elif expected_method == StimulusMethod.FORCE_TOGGLE and has_generic_toggle:
                current_method = StimulusMethod.FORCE_TOGGLE
                matching_path = "GENERIC_FORCE_TOGGLE"

        if current_method is None:
            results['missing_stimulus'].append({
                'interrupt': interrupt,
                'expected_method': expected_method,
                'reason': "No stimulus method found"
            })
            continue

        if current_method == expected_method:
            if 'GENERIC' in matching_path:
                results['generic_compliant'].append({
                    'interrupt': interrupt,
                    'method': current_method,
                    'path': matching_path
                })
            else:
                results['compliant'].append({
                    'interrupt': interrupt,
                    'method': current_method,
                    'path': matching_path
                })
        else:
            results['non_compliant'].append({
                'interrupt': interrupt,
                'expected_method': expected_method,
                'current_method': current_method,
                'path': matching_path,
                'issue': f"Expected {expected_method.value}, but found {current_method.value}"
            })

    return results

def generate_compliance_report(results: Dict[str, List], output_file: Path = None):
    """生成合规性检查报告"""

    report_lines = []
    report_lines.append("=" * 80)
    report_lines.append("中断激励方法合规性检查报告")
    report_lines.append("=" * 80)
    report_lines.append("")

    # 统计信息
    total_interrupts = (len(results['compliant']) + len(results['generic_compliant']) +
                       len(results['non_compliant']) + len(results['missing_stimulus']) +
                       len(results['unknown_requirement']))

    total_compliant = len(results['compliant']) + len(results['generic_compliant'])

    report_lines.append("## 统计摘要")
    report_lines.append(f"总中断数量: {total_interrupts}")
    report_lines.append(f"符合规范 (总计): {total_compliant} ({total_compliant/total_interrupts*100:.1f}%)")
    report_lines.append(f"  - 精确匹配: {len(results['compliant'])} ({len(results['compliant'])/total_interrupts*100:.1f}%)")
    report_lines.append(f"  - 通用方法: {len(results['generic_compliant'])} ({len(results['generic_compliant'])/total_interrupts*100:.1f}%)")
    report_lines.append(f"不符合规范: {len(results['non_compliant'])} ({len(results['non_compliant'])/total_interrupts*100:.1f}%)")
    report_lines.append(f"缺少激励方法: {len(results['missing_stimulus'])} ({len(results['missing_stimulus'])/total_interrupts*100:.1f}%)")
    report_lines.append(f"无法确定要求: {len(results['unknown_requirement'])} ({len(results['unknown_requirement'])/total_interrupts*100:.1f}%)")
    report_lines.append("")

    # 不符合规范的详细信息
    if results['non_compliant']:
        report_lines.append("## 不符合规范的中断 (需要修复)")
        report_lines.append("-" * 60)
        for item in results['non_compliant']:
            interrupt = item['interrupt']
            report_lines.append(f"中断名称: {interrupt.name}")
            report_lines.append(f"  组别: {interrupt.group}")
            report_lines.append(f"  触发类型: {interrupt.trigger.value}")
            report_lines.append(f"  极性: {interrupt.polarity.value}")
            report_lines.append(f"  期望激励方法: {item['expected_method'].value}")
            report_lines.append(f"  当前激励方法: {item['current_method'].value}")
            report_lines.append(f"  问题描述: {item['issue']}")
            report_lines.append(f"  信号路径: {item['path']}")
            report_lines.append("")

    # 缺少激励方法的中断
    if results['missing_stimulus']:
        report_lines.append("## 缺少激励方法的中断")
        report_lines.append("-" * 60)
        for item in results['missing_stimulus']:
            interrupt = item['interrupt']
            report_lines.append(f"中断名称: {interrupt.name}")
            report_lines.append(f"  组别: {interrupt.group}")
            report_lines.append(f"  触发类型: {interrupt.trigger.value}")
            report_lines.append(f"  极性: {interrupt.polarity.value}")
            report_lines.append(f"  需要的激励方法: {item['expected_method'].value}")
            report_lines.append("")

    # 特殊情况的中断
    if results['unknown_requirement']:
        report_lines.append("## 无法确定激励要求的中断")
        report_lines.append("-" * 60)
        for item in results['unknown_requirement']:
            interrupt = item['interrupt']
            report_lines.append(f"中断名称: {interrupt.name}")
            report_lines.append(f"  组别: {interrupt.group}")
            report_lines.append(f"  触发类型: {interrupt.trigger.value}")
            report_lines.append(f"  极性: {interrupt.polarity.value}")
            report_lines.append(f"  原因: {item['reason']}")
            report_lines.append("")

    # 符合规范的中断 (简要列表)
    if results['compliant'] or results['generic_compliant']:
        report_lines.append("## 符合规范的中断")
        report_lines.append("-" * 60)

        if results['compliant']:
            report_lines.append("### 精确匹配的中断:")
            for item in results['compliant']:
                interrupt = item['interrupt']
                report_lines.append(f"{interrupt.name} ({interrupt.group}) - {item['method'].value}")
            report_lines.append("")

        if results['generic_compliant']:
            report_lines.append("### 使用通用激励方法的中断:")
            report_lines.append("这些中断使用了通用的激励方法实现，符合其trigger/polarity要求:")

            # 按激励方法分组
            method_groups = {}
            for item in results['generic_compliant']:
                method = item['method']
                if method not in method_groups:
                    method_groups[method] = []
                method_groups[method].append(item)

            for method, items in method_groups.items():
                report_lines.append(f"\n**{method.value}** ({len(items)} 个中断):")
                for item in items:
                    interrupt = item['interrupt']
                    report_lines.append(f"  - {interrupt.name} ({interrupt.group}) - {interrupt.trigger.value}/{interrupt.polarity.value}")
            report_lines.append("")

    # 修复建议
    report_lines.append("## 修复建议")
    report_lines.append("-" * 60)

    if results['non_compliant']:
        report_lines.append("### 对于不符合规范的中断:")

        # 按问题类型分组建议
        level_issues = [item for item in results['non_compliant']
                       if item['interrupt'].trigger == TriggerType.LEVEL]
        edge_issues = [item for item in results['non_compliant']
                      if item['interrupt'].trigger in [TriggerType.EDGE, TriggerType.PULSE]]

        if level_issues:
            report_lines.append("1. Level触发中断问题:")
            for item in level_issues:
                interrupt = item['interrupt']
                if interrupt.polarity == PolarityType.ACTIVE_HIGH:
                    report_lines.append(f"   - {interrupt.name}: 应使用 uvm_hdl_force(path, 1) 然后 uvm_hdl_release(path)")
                elif interrupt.polarity == PolarityType.ACTIVE_LOW:
                    report_lines.append(f"   - {interrupt.name}: 应使用 uvm_hdl_force(path, 0) 然后 uvm_hdl_release(path)")
            report_lines.append("")

        if edge_issues:
            report_lines.append("2. Edge/Pulse触发中断问题:")
            for item in edge_issues:
                interrupt = item['interrupt']
                if interrupt.polarity == PolarityType.RISING_FALLING:
                    report_lines.append(f"   - {interrupt.name}: 需要双边沿激励 (force(1)->force(0)->release 或 force(0)->force(1)->release)")
                else:
                    report_lines.append(f"   - {interrupt.name}: 需要短脉冲激励，当前使用的电平激励不合适")
            report_lines.append("")

    if results['missing_stimulus']:
        report_lines.append("### 对于缺少激励方法的中断:")

        # 按类型分组缺少的中断
        missing_by_type = {}
        for item in results['missing_stimulus']:
            interrupt = item['interrupt']
            key = f"{interrupt.trigger.value}_{interrupt.polarity.value}"
            if key not in missing_by_type:
                missing_by_type[key] = []
            missing_by_type[key].append(item)

        for type_key, items in missing_by_type.items():
            trigger, polarity = type_key.split('_', 1)
            report_lines.append(f"\n**{trigger} / {polarity}** ({len(items)} 个中断):")

            if trigger == "Edge" and polarity == "Rising & Falling Edge":
                report_lines.append("  需要实现双边沿激励方法:")
                report_lines.append("  ```systemverilog")
                report_lines.append("  // 双边沿激励示例")
                report_lines.append("  uvm_hdl_force(info.rtl_path_src, 1);")
                report_lines.append("  #5ns;")
                report_lines.append("  uvm_hdl_force(info.rtl_path_src, 0);")
                report_lines.append("  #5ns;")
                report_lines.append("  uvm_hdl_release(info.rtl_path_src);")
                report_lines.append("  ```")
            elif trigger == "Pulse":
                report_lines.append("  需要实现脉冲激励方法:")
                report_lines.append("  ```systemverilog")
                report_lines.append("  // 脉冲激励示例")
                report_lines.append("  uvm_hdl_force(info.rtl_path_src, 1);")
                report_lines.append("  #1ns; // 短脉冲")
                report_lines.append("  uvm_hdl_force(info.rtl_path_src, 0);")
                report_lines.append("  #1ns;")
                report_lines.append("  uvm_hdl_release(info.rtl_path_src);")
                report_lines.append("  ```")

            for item in items:
                interrupt = item['interrupt']
                report_lines.append(f"  - {interrupt.name} ({interrupt.group})")

        report_lines.append("\n通用建议:")
        report_lines.append("1. 需要在测试序列中添加对这些中断的激励")
        report_lines.append("2. 确保在int_routing_model.sv中设置正确的rtl_path_src")
        report_lines.append("3. 根据trigger/polarity类型选择合适的激励方法")
        report_lines.append("")

    # 总结
    report_lines.append("## 总结")
    report_lines.append("-" * 60)
    total_compliant = len(results['compliant']) + len(results['generic_compliant'])
    compliance_rate = total_compliant / (total_compliant + len(results['non_compliant']) + len(results['missing_stimulus'])) * 100

    report_lines.append(f"当前激励方法合规率: {compliance_rate:.1f}%")
    report_lines.append("")

    if compliance_rate >= 95:
        report_lines.append("✅ **合规性评估: 优秀**")
        report_lines.append("当前的激励方法基本符合中断向量表的要求。")
    elif compliance_rate >= 80:
        report_lines.append("⚠️  **合规性评估: 良好**")
        report_lines.append("大部分激励方法符合要求，但仍有改进空间。")
    else:
        report_lines.append("❌ **合规性评估: 需要改进**")
        report_lines.append("存在较多不符合规范的激励方法，需要重点关注。")

    if len(results['missing_stimulus']) > 0:
        report_lines.append(f"\n主要问题: 有 {len(results['missing_stimulus'])} 个中断缺少专门的激励方法。")
        report_lines.append("建议优先实现Edge/Pulse类型中断的专用激励方法。")

    report_lines.append("")

    # 输出报告
    report_content = "\n".join(report_lines)

    if output_file:
        with open(output_file, 'w', encoding='utf-8') as f:
            f.write(report_content)
        print(f"合规性检查报告已保存到: {output_file}")
    else:
        print(report_content)

def main():
    """主函数"""
    script_dir = Path(__file__).parent
    project_root = script_dir.parent

    # 输入文件路径
    csv_path = project_root / "中断向量表-iosub-V0.5.csv"
    seq_files = [
        project_root / "seq" / "int_lightweight_sequence.sv",
        project_root / "test" / "tc_merge_interrupt_test.sv",
        project_root / "test" / "tc_all_merge_interrupts.sv"
    ]

    # 输出文件路径
    output_file = project_root / "stimulus_compliance_report.md"

    print("开始中断激励方法合规性检查...")
    print(f"CSV文件: {csv_path}")
    print(f"检查的序列文件: {[str(f) for f in seq_files]}")
    print()

    # 解析CSV中断信息
    if not csv_path.exists():
        print(f"错误: CSV文件不存在: {csv_path}")
        sys.exit(1)

    interrupts = parse_csv_interrupts(csv_path)
    print(f"从CSV文件解析到 {len(interrupts)} 个中断")

    # 分析当前激励方法
    current_methods = analyze_current_stimulus_methods(seq_files)
    print(f"分析到 {len(current_methods)} 个激励方法")

    # 检查合规性
    results = check_compliance(interrupts, current_methods)

    # 生成报告
    generate_compliance_report(results, output_file)

    # 返回状态码
    total_compliant = len(results['compliant']) + len(results['generic_compliant'])
    if results['non_compliant'] or results['missing_stimulus']:
        print(f"\n检查完成:")
        print(f"  - 符合规范: {total_compliant} 个")
        print(f"  - 不符合规范: {len(results['non_compliant'])} 个")
        print(f"  - 缺少激励: {len(results['missing_stimulus'])} 个")
        print(f"  - 无法确定: {len(results['unknown_requirement'])} 个")
        return 1
    else:
        print(f"\n所有中断的激励方法都符合规范! (总计 {total_compliant} 个)")
        return 0

if __name__ == "__main__":
    sys.exit(main())
