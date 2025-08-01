#!/usr/bin/env python3
"""
检查Excel文件中的命名不一致问题
特别是iosub_normal_int vs iosub_normal_intr的问题
"""

import pandas as pd
import sys

def check_excel_naming_consistency():
    """检查Excel文件中的命名一致性问题"""
    
    print("🔍 检查Excel文件中的命名一致性问题")
    print("=" * 60)
    
    try:
        # 检查主表 - IOSUB中断源
        print("\n📋 检查主表 (IOSUB中断源)...")
        df_main = pd.read_excel('int_vector.xlsx', sheet_name='IOSUB中断源')
        
        main_issues = []
        for idx, row in df_main.iterrows():
            interrupt_name = str(row.get('Interrupt Name', '')).strip()
            if 'iosub_normal_int' in interrupt_name and interrupt_name != 'iosub_normal_intr':
                main_issues.append({
                    'row': idx,
                    'current_name': interrupt_name,
                    'should_be': interrupt_name.replace('iosub_normal_int', 'iosub_normal_intr')
                })
        
        if main_issues:
            print(f"❌ 在主表中发现 {len(main_issues)} 个命名问题:")
            for issue in main_issues:
                print(f"   行{issue['row']}: '{issue['current_name']}' → '{issue['should_be']}'")
        else:
            print("✅ 主表中未发现iosub_normal_int命名问题")
        
        # 检查SCP M7中断列表
        print("\n📋 检查SCP M7中断列表...")
        df_scp = pd.read_excel('int_vector.xlsx', sheet_name='SCP M7中断列表')
        
        scp_issues = []
        for idx, row in df_scp.iterrows():
            # 检查第2列 (Interrupt Name)
            if len(df_scp.columns) > 2:
                interrupt_name = str(row.iloc[2]).strip()
                if 'iosub_normal_int' in interrupt_name and interrupt_name != 'iosub_normal_intr':
                    scp_issues.append({
                        'row': idx,
                        'current_name': interrupt_name,
                        'should_be': interrupt_name.replace('iosub_normal_int', 'iosub_normal_intr'),
                        'index': str(row.iloc[1]) if len(df_scp.columns) > 1 else 'N/A'
                    })
        
        if scp_issues:
            print(f"❌ 在SCP M7中断列表中发现 {len(scp_issues)} 个命名问题:")
            for issue in scp_issues:
                print(f"   行{issue['row']} (索引{issue['index']}): '{issue['current_name']}' → '{issue['should_be']}'")
        else:
            print("✅ SCP M7中断列表中未发现iosub_normal_int命名问题")
        
        # 检查MCP M7中断列表
        print("\n📋 检查MCP M7中断列表...")
        df_mcp = pd.read_excel('int_vector.xlsx', sheet_name='MCP M7中断列表')
        
        mcp_issues = []
        for idx, row in df_mcp.iterrows():
            # 检查第2列 (Interrupt Name)
            if len(df_mcp.columns) > 2:
                interrupt_name = str(row.iloc[2]).strip()
                if 'iosub_normal_int' in interrupt_name and interrupt_name != 'iosub_normal_intr':
                    mcp_issues.append({
                        'row': idx,
                        'current_name': interrupt_name,
                        'should_be': interrupt_name.replace('iosub_normal_int', 'iosub_normal_intr'),
                        'index': str(row.iloc[1]) if len(df_mcp.columns) > 1 else 'N/A'
                    })
        
        if mcp_issues:
            print(f"❌ 在MCP M7中断列表中发现 {len(mcp_issues)} 个命名问题:")
            for issue in mcp_issues:
                print(f"   行{issue['row']} (索引{issue['index']}): '{issue['current_name']}' → '{issue['should_be']}'")
        else:
            print("✅ MCP M7中断列表中未发现iosub_normal_int命名问题")
        
        # 检查其他可能的表格
        print("\n📋 检查其他表格...")
        xl = pd.ExcelFile('int_vector.xlsx')
        other_issues = []
        
        for sheet_name in xl.sheet_names:
            if sheet_name in ['IOSUB中断源', 'SCP M7中断列表', 'MCP M7中断列表']:
                continue
                
            try:
                df = pd.read_excel('int_vector.xlsx', sheet_name=sheet_name)
                for idx, row in df.iterrows():
                    for col in df.columns:
                        cell_value = str(row[col]).strip()
                        if 'iosub_normal_int' in cell_value and cell_value != 'iosub_normal_intr':
                            other_issues.append({
                                'sheet': sheet_name,
                                'row': idx,
                                'column': col,
                                'current_value': cell_value,
                                'should_be': cell_value.replace('iosub_normal_int', 'iosub_normal_intr')
                            })
            except Exception as e:
                print(f"⚠️  跳过表格 {sheet_name}: {e}")
        
        if other_issues:
            print(f"❌ 在其他表格中发现 {len(other_issues)} 个命名问题:")
            for issue in other_issues:
                print(f"   {issue['sheet']} 行{issue['row']} 列'{issue['column']}': '{issue['current_value']}' → '{issue['should_be']}'")
        else:
            print("✅ 其他表格中未发现iosub_normal_int命名问题")
        
        # 总结
        total_issues = len(main_issues) + len(scp_issues) + len(mcp_issues) + len(other_issues)
        
        print("\n" + "=" * 60)
        print("📊 检查总结:")
        print(f"   主表问题: {len(main_issues)}")
        print(f"   SCP M7列表问题: {len(scp_issues)}")
        print(f"   MCP M7列表问题: {len(mcp_issues)}")
        print(f"   其他表格问题: {len(other_issues)}")
        print(f"   总计问题: {total_issues}")
        
        if total_issues > 0:
            print("\n🔧 修正建议:")
            print("   请在Excel文件中将所有 'iosub_normal_int' 修正为 'iosub_normal_intr'")
            print("   修正后重新运行 convert_xlsx_to_sv.py 脚本")
            return False
        else:
            print("\n✅ Excel文件命名一致性检查通过!")
            return True
            
    except Exception as e:
        print(f"❌ 检查过程中出错: {e}")
        return False

def main():
    """主函数"""
    success = check_excel_naming_consistency()
    return 0 if success else 1

if __name__ == "__main__":
    sys.exit(main())
