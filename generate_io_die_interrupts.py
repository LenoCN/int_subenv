#!/usr/bin/env python3

import pandas as pd

def generate_io_die_interrupts():
    # 读取IOSUB中断源工作表
    df = pd.read_excel('/home/leno/ws2/int_subenv/int_vector.xlsx', sheet_name='IOSUB中断源')
    
    # IO Die中断列表
    io_die_interrupts = [f'io_die_intr_{i}_intr' for i in range(32)]
    
    # SCP中断索引映射 (从62到93)
    scp_index_map = {f'io_die_intr_{i}_intr': 62 + i for i in range(32)}
    
    # 创建中断名到Excel行的映射
    interrupt_to_row = {}
    for index, row in df.iterrows():
        intr_name = str(row['Interrupt Name'])
        if intr_name and intr_name != 'nan' and intr_name.strip():
            interrupt_to_row[intr_name] = row
    
    generated_entries = []
    
    # 为每个IO Die中断生成条目
    for intr_name in io_die_interrupts:
        if intr_name in interrupt_to_row:
            row = interrupt_to_row[intr_name]
            
            # 基本信息
            sub_index = int(row['sub index']) if pd.notna(row['sub index']) else -1
            to_ap = 1 if str(row['to AP?']).upper() == 'YES' else 0
            to_scp = 1 if str(row['to SCP?']).upper() == 'YES' else 0
            to_mcp = 1 if str(row['to MCP?']).upper() == 'YES' else 0
            
            # SCP路径和索引
            rtl_path_scp = '""'
            dest_index_scp = -1
            if to_scp == 1 and intr_name in scp_index_map:
                dest_index_scp = scp_index_map[intr_name]
                rtl_path_scp = f'"top_tb.multidie_top.DUT[0].u_str_top.u_iosub_top_wrap.u0_iosub_top_wrap_hd.u0_iosub_top_wrap_raw.u_scp_top_wrapper.u_scp_top.u_m7_wrapper.cpu_irq[{dest_index_scp}]"'
            
            # MCP路径（IO Die中断不路由到MCP）
            rtl_path_mcp = '""'
            dest_index_mcp = -1
            
            # 生成条目
            entry = (f'        entry = \'{{name:"{intr_name}", index:{sub_index}, group:IOSUB, trigger:LEVEL, polarity:ACTIVE_HIGH, '
                    f'rtl_path_src:"top_tb.multidie_top.DUT[0].u_str_top.u_iosub_top_wrap.u0_iosub_top_wrap_hd.u0_iosub_top_wrap_raw.u_iosub_int_sub.iosub_peri_intr[{sub_index}]", '
                    f'pulse_width_ns:0, to_ap:{to_ap}, rtl_path_ap:"", dest_index_ap:-1, '
                    f'to_scp:{to_scp}, rtl_path_scp:{rtl_path_scp}, dest_index_scp:{dest_index_scp}, '
                    f'to_mcp:{to_mcp}, rtl_path_mcp:{rtl_path_mcp}, dest_index_mcp:{dest_index_mcp}, '
                    f'to_accel:0, rtl_path_accel:"", dest_index_accel:-1, '
                    f'to_io:0, rtl_path_io:"", dest_index_io:-1, '
                    f'to_other_die:0, rtl_path_other_die:"", dest_index_other_die:-1}}; interrupt_map.push_back(entry);')
            
            generated_entries.append(entry)
    
    return generated_entries

if __name__ == "__main__":
    entries = generate_io_die_interrupts()
    
    print("// IO Die interrupt entries to be added to int_map_entries.svh")
    print("// Generated based on IOSUB中断源 worksheet and SCP M7 interrupt list")
    print()
    
    for entry in entries:
        print(entry)
    
    print(f"\n// Total {len(entries)} IO Die interrupt entries generated")