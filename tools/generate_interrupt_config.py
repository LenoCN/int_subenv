#!/usr/bin/env python3
"""
完整的中断配置生成脚本

这个脚本执行完整的从Excel到SystemVerilog的转换流程：
1. 检查Excel命名一致性
2. 从Excel生成SystemVerilog配置文件
3. 更新RTL路径
4. 验证生成结果
"""

import subprocess
import sys
import os
import re
from pathlib import Path

class InterruptConfigGenerator:
    def __init__(self, excel_file="int_vector.xlsx", output_file="seq/int_map_entries.svh"):
        self.excel_file = excel_file
        self.output_file = output_file
        self.backup_file = f"{output_file}.backup_generation"
        
    def run_command(self, cmd, description):
        """运行命令并处理结果"""
        print(f"🔄 {description}...")
        try:
            result = subprocess.run(cmd, shell=True, capture_output=True, text=True, cwd=".")
            if result.returncode != 0:
                print(f"❌ {description}失败:")
                print(f"   错误: {result.stderr}")
                return False, result.stderr
            else:
                print(f"✅ {description}成功")
                if result.stdout.strip():
                    print(f"   输出: {result.stdout.strip()}")
                return True, result.stdout
        except Exception as e:
            print(f"❌ {description}异常: {e}")
            return False, str(e)
    
    def check_excel_naming(self):
        """检查Excel命名一致性"""
        print("\n" + "="*60)
        print("步骤1: 检查Excel命名一致性")
        print("="*60)
        
        success, output = self.run_command(
            "python3 tools/check_excel_naming_issues.py",
            "检查Excel命名一致性"
        )
        
        if not success:
            print("⚠️  Excel命名检查发现问题，但继续执行生成流程")
            print("   建议: 修正Excel文件中的命名问题以获得最佳结果")
        
        return True  # 即使有命名问题也继续执行
    
    def generate_sv_config(self):
        """从Excel生成SystemVerilog配置文件"""
        print("\n" + "="*60)
        print("步骤2: 从Excel生成SystemVerilog配置文件")
        print("="*60)
        
        # 创建备份
        if Path(self.output_file).exists():
            subprocess.run(f"cp {self.output_file} {self.backup_file}", shell=True)
            print(f"✅ 创建备份: {self.backup_file}")
        
        success, output = self.run_command(
            f"python3 tools/convert_xlsx_to_sv.py {self.excel_file} -o {self.output_file}",
            "生成SystemVerilog配置文件"
        )
        
        if not success:
            print(f"❌ 配置文件生成失败")
            return False
        
        # 解析生成统计
        lines = output.split('\n')
        for line in lines:
            if 'Generated' in line and 'interrupt entries' in line:
                print(f"📊 {line}")
        
        return True
    
    def update_rtl_paths(self):
        """更新RTL路径"""
        print("\n" + "="*60)
        print("步骤3: 更新RTL路径")
        print("="*60)
        
        success, output = self.run_command(
            "python3 tools/update_rtl_paths.py",
            "更新RTL路径"
        )
        
        if not success:
            print(f"❌ RTL路径更新失败")
            return False
        
        # 解析更新统计
        lines = output.split('\n')
        for line in lines:
            if 'Updated' in line and 'interrupt entries' in line:
                print(f"📊 {line}")
        
        return True

    def validate_signal_paths(self):
        """验证信号路径生成器配置"""
        print("\n" + "="*60)
        print("步骤4: 验证信号路径生成器配置")
        print("="*60)

        success, output = self.run_command(
            "python3 tools/generate_signal_paths.py --validate",
            "验证信号路径生成器配置"
        )

        if not success:
            print("⚠️  信号路径生成器验证发现问题，但继续执行")
            print("   建议: 检查config/hierarchy_config.json配置文件")

        return True  # 即使验证失败也继续执行

    def validate_results(self):
        """验证生成结果"""
        print("\n" + "="*60)
        print("步骤5: 验证生成结果")
        print("="*60)
        
        try:
            with open(self.output_file, 'r', encoding='utf-8') as f:
                content = f.read()
            
            pattern = r'entry = \'{name:"([^"]+)".*?to_ap:(\d+).*?rtl_path_ap:"([^"]*)".*?to_scp:(\d+).*?rtl_path_scp:"([^"]*)".*?to_mcp:(\d+).*?rtl_path_mcp:"([^"]*)".*?to_accel:(\d+).*?rtl_path_accel:"([^"]*)".*?\};'
            
            matches = re.findall(pattern, content, re.DOTALL)
            
            print(f"📊 总共找到 {len(matches)} 个中断条目")
            
            problems = []
            for match in matches:
                name, to_ap, rtl_ap, to_scp, rtl_scp, to_mcp, rtl_mcp, to_accel, rtl_accel = match
                
                if to_ap == '1' and rtl_ap.strip() == '':
                    problems.append(f'{name}: to_ap=1 但 rtl_path_ap 为空')
                if to_scp == '1' and rtl_scp.strip() == '':
                    problems.append(f'{name}: to_scp=1 但 rtl_path_scp 为空')
                if to_mcp == '1' and rtl_mcp.strip() == '':
                    problems.append(f'{name}: to_mcp=1 但 rtl_path_mcp 为空')
                if to_accel == '1' and rtl_accel.strip() == '':
                    problems.append(f'{name}: to_accel=1 但 rtl_path_accel 为空')
            
            if problems:
                print(f"⚠️  发现 {len(problems)} 个路由配置问题:")
                for i, problem in enumerate(problems, 1):
                    print(f"   {i:2d}. {problem}")
                print("\n💡 这些问题可能是由于:")
                print("   - Excel中的命名不一致")
                print("   - 目标表中缺少对应的索引")
                print("   - 合理的设计边界情况")
            else:
                print("✅ 未发现路由配置问题")
            
            # 特别检查iosub_normal_intr
            iosub_pattern = r'name:"iosub_normal_intr".*?to_scp:(\d+).*?dest_index_scp:(-?\d+).*?to_mcp:(\d+).*?dest_index_mcp:(-?\d+)'
            iosub_match = re.search(iosub_pattern, content)
            if iosub_match:
                to_scp, scp_idx, to_mcp, mcp_idx = iosub_match.groups()
                print(f"\n🔍 iosub_normal_intr 状态:")
                print(f"   to_scp: {to_scp}, dest_index_scp: {scp_idx}")
                print(f"   to_mcp: {to_mcp}, dest_index_mcp: {mcp_idx}")
                
                if scp_idx == '-1' or mcp_idx == '-1':
                    print("   ❌ 没有正确的目标索引")
                    print("   💡 建议: 修正Excel中的iosub_normal_int -> iosub_normal_intr")
                else:
                    print("   ✅ 有正确的目标索引")
            
            return len(problems) == 0
            
        except Exception as e:
            print(f"❌ 验证过程中出错: {e}")
            return False
    
    def generate(self):
        """执行完整的生成流程"""
        print("🚀 中断配置生成器")
        print("="*60)
        print(f"Excel文件: {self.excel_file}")
        print(f"输出文件: {self.output_file}")
        print("="*60)
        
        # 检查输入文件
        if not Path(self.excel_file).exists():
            print(f"❌ Excel文件不存在: {self.excel_file}")
            return False
        
        # 执行各个步骤
        steps = [
            ("检查Excel命名一致性", self.check_excel_naming),
            ("生成SystemVerilog配置", self.generate_sv_config),
            ("更新RTL路径", self.update_rtl_paths),
            ("验证信号路径生成器", self.validate_signal_paths),
            ("验证生成结果", self.validate_results)
        ]
        
        for step_name, step_func in steps:
            if not step_func():
                print(f"\n❌ 流程在'{step_name}'步骤失败")
                return False
        
        print("\n" + "="*60)
        print("🎉 中断配置生成完成!")
        print("="*60)
        print(f"✅ 输出文件: {self.output_file}")
        if Path(self.backup_file).exists():
            print(f"📁 备份文件: {self.backup_file}")
        print("\n💡 后续建议:")
        print("   1. 检查验证结果中的任何问题")
        print("   2. 如有命名问题，修正Excel文件后重新生成")
        print("   3. 运行相关测试验证配置正确性")
        
        return True

def main():
    """主函数"""
    import argparse
    
    parser = argparse.ArgumentParser(description="完整的中断配置生成脚本")
    parser.add_argument("excel_file", nargs="?", default="int_vector.xlsx", 
                       help="Excel输入文件 (默认: int_vector.xlsx)")
    parser.add_argument("-o", "--output", default="seq/int_map_entries.svh",
                       help="SystemVerilog输出文件 (默认: seq/int_map_entries.svh)")
    
    args = parser.parse_args()
    
    generator = InterruptConfigGenerator(args.excel_file, args.output)
    success = generator.generate()
    
    return 0 if success else 1

if __name__ == "__main__":
    sys.exit(main())
