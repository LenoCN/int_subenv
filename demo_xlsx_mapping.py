#!/usr/bin/env python3
"""
演示脚本：展示从Excel文件生成的中断映射关系
"""

import pandas as pd

def demo_interrupt_mapping():
    """演示中断映射关系的提取和使用"""
    
    print("=== Excel中断映射演示 ===")
    print()
    
    # 读取Excel文件
    excel_file = 'int_vector.xlsx'
    
    # 1. 展示主表信息
    print("1. 主表信息 (IOSUB中断源)")
    df_main = pd.read_excel(excel_file, sheet_name='IOSUB中断源')
    
    # 查找psub_normal3_intr
    psub_rows = df_main[df_main['Interrupt Name'].str.contains('psub_normal3_intr', na=False)]
    if not psub_rows.empty:
        row = psub_rows.iloc[0]
        print(f"中断名称: {row['Interrupt Name']}")
        print(f"索引: {row['sub index']}")
        print(f"触发方式: {row['Trigger']}")
        print(f"极性: {row[' Polarity']}")
        print(f"路由到 AP: {row['to AP?']}")
        print(f"路由到 SCP: {row['to SCP?']}")
        print(f"路由到 MCP: {row['to MCP?']}")
        print()
    
    # 2. 展示目的地映射
    print("2. 目的地映射信息")
    
    # AP目的地
    df_ap = pd.read_excel(excel_file, sheet_name='iosub-to-AP中断列表')
    ap_rows = df_ap[df_ap['Unnamed: 3'].str.contains('psub_normal3_intr', na=False)]
    if not ap_rows.empty:
        ap_row = ap_rows.iloc[0]
        print(f"AP目的地: 索引 {ap_row['Unnamed: 2']} (中断ID: {ap_row['Unnamed: 1']})")
    
    # SCP目的地
    df_scp = pd.read_excel(excel_file, sheet_name='SCP M7中断列表')
    scp_rows = df_scp[df_scp['Unnamed: 2'].str.contains('psub_normal3_intr', na=False)]
    if not scp_rows.empty:
        scp_row = scp_rows.iloc[0]
        print(f"SCP目的地: 索引 {scp_row['SCP M7中断列表']}")
    
    # MCP目的地
    df_mcp = pd.read_excel(excel_file, sheet_name='MCP M7中断列表')
    mcp_rows = df_mcp[df_mcp['Unnamed: 2'].str.contains('psub_normal3_intr', na=False)]
    if not mcp_rows.empty:
        mcp_row = mcp_rows.iloc[0]
        print(f"MCP目的地: 索引 {mcp_row['MCP M7中断列表']}")
    
    print()
    
    # 3. 展示生成的SystemVerilog映射
    print("3. 生成的SystemVerilog映射")
    print("根据Excel数据，psub_normal3_intr的完整映射为:")
    print("- 组: PSUB")
    print("- 源索引: 6")
    print("- AP目的地索引: 110")
    print("- SCP目的地索引: 173") 
    print("- MCP目的地索引: 147")
    print()
    
    # 4. 展示信号层次结构
    print("4. 信号层次结构")
    print("这种映射关系可以用于:")
    print("- RTL仿真中的信号路径验证")
    print("- 中断路由的自动化测试")
    print("- 系统级验证环境的配置")
    print("- 软件驱动的中断处理验证")
    print()
    
    # 5. 展示与之前CSV方式的对比
    print("5. 与CSV方式的改进")
    print("Excel方式的优势:")
    print("- 多页签支持不同视角的中断信息")
    print("- 自动提取目的地索引信息")
    print("- 更完整的信号层次映射")
    print("- 支持复杂的中断路由关系")
    print("- 便于维护和更新")

if __name__ == "__main__":
    demo_interrupt_mapping()
