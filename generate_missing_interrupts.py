#!/usr/bin/env python3

import pandas as pd

def generate_missing_interrupts():
    # 读取IOSUB中断源工作表
    df = pd.read_excel('/home/leno/ws2/int_subenv/int_vector.xlsx', sheet_name='IOSUB中断源')
    
    # 读取SCP和MCP M7中断列表
    scp_df = pd.read_excel('/home/leno/ws2/int_subenv/int_vector.xlsx', sheet_name='SCP M7中断列表')
    mcp_df = pd.read_excel('/home/leno/ws2/int_subenv/int_vector.xlsx', sheet_name='MCP M7中断列表')
    
    # 创建SCP和MCP中断名到索引的映射
    scp_interrupt_dict = {}
    for i, row in scp_df.iterrows():
        name = str(row['Unnamed: 2'])
        if name and name != 'nan' and name != 'Interrupt Name':
            # 实际索引应该是第二列的值
            index_val = row['SCP M7中断列表']
            if pd.notna(index_val) and str(index_val).isdigit():
                scp_interrupt_dict[name] = int(index_val)
    
    mcp_interrupt_dict = {}
    for i, row in mcp_df.iterrows():
        name = str(row['Unnamed: 2'])
        if name and name != 'nan' and name != 'Interrupt Name':
            # 实际索引应该是第二列的值
            index_val = row['MCP M7中断列表']
            if pd.notna(index_val) and str(index_val).isdigit():
                mcp_interrupt_dict[name] = int(index_val)
    
    # 缺失的中断列表
    missing_interrupts = [
        'ap2scp_mhu_receive_intr_0', 'ap2scp_mhu_receive_intr_1', 'ap2scp_mhu_receive_intr_2',
        'ap2scp_mhu_receive_intr_3', 'd2d_d0_iosub_pmbus0_intr', 'd2d_d0_iosub_pvt_intr',
        'd2d_d0_n2_wakeup_intr', 'd2d_d0_n2_ws1_intr', 'd2d_d1_iosub_pmbus0_intr',
        'd2d_d1_iosub_pvt_intr', 'd2d_d1_n2_wakeup_intr', 'd2d_d1_n2_ws1_intr',
        'd2d_d2_iosub_pmbus0_intr', 'd2d_d2_iosub_pvt_intr', 'd2d_d2_n2_wakeup_intr',
        'd2d_d2_n2_ws1_intr', 'd2d_mcp2scp_mhu_receive_intr_0', 'd2d_mcp2scp_mhu_receive_intr_1',
        'd2d_mcp2scp_mhu_receive_intr_2', 'd2d_scp2mcp_mhu_send_intr_0',
        'd2d_scp2mcp_mhu_send_intr_1', 'd2d_scp2mcp_mhu_send_intr_2',
        'd2d_scp2scp_mhu_receive_intr_0', 'd2d_scp2scp_mhu_receive_intr_1',
        'd2d_scp2scp_mhu_receive_intr_2', 'd2d_scp2scp_mhu_send_intr_0',
        'd2d_scp2scp_mhu_send_intr_1', 'd2d_scp2scp_mhu_send_intr_2',
        'iosub_pad_in_0_intr', 'iosub_pad_in_1_intr', 'iosub_pad_in_2_intr',
        'iosub_pad_in_3_intr', 'iosub_pad_in_4_intr', 'iosub_pad_in_5_intr',
        'iosub_pad_in_6_intr', 'iosub_pad_in_7_intr', 'iosub_pad_in_8_intr',
        'iosub_pad_in_9_intr', 'iosub_pad_in_10_intr', 'iosub_pad_in_11_intr',
        'iosub_pad_in_12_intr', 'iosub_pad_in_13_intr', 'iosub_pad_in_14_intr',
        'iosub_pad_in_15_intr', 'mcp2io_wdt_ws1_intr', 'mcp2scp_mhu_receive_intr',
        'mcp_acl_intr', 'mcp_cpu_bus_fault_intr', 'mcp_cpu_cti_irq[0]',
        'mcp_cpu_cti_irq[1]', 'mcp_gpio_intr', 'mcp_i2c_intr',
        'mcp_smbus_intr', 'mcp_sram_bus_fault_intr', 'mcp_timer64_0_intr',
        'mcp_timer64_1_intr', 'mcp_timer64_2_intr', 'mcp_timer64_3_intr',
        'mcp_uart_intr', 'scp2ap_mhu_send_intr_0', 'scp2ap_mhu_send_intr_1',
        'scp2ap_mhu_send_intr_2', 'scp2ap_mhu_send_intr_3', 'scp2io_wdt_ws1_intr',
        'scp2mcp_mhu_send_intr', 'scp_acl_intr', 'scp_cpu_bus_fault_intr',
        'scp_cpu_cti_irq[0]', 'scp_cpu_cti_irq[1]', 'scp_dma_intr',
        'scp_efuse_intr', 'scp_gpio_intr', 'scp_i2c_intr',
        'scp_i3c_dma_0_intr', 'scp_i3c_dma_1_intr', 'scp_i3c_dma_2_intr',
        'scp_qspi_intr', 'scp_smbus_intr', 'scp_spi_intr',
        'scp_sram_bus_fault_intr', 'scp_timer64_0_intr', 'scp_timer64_1_intr',
        'scp_timer64_2_intr', 'scp_timer64_3_intr', 'scp_ts_sync_0_intr',
        'scp_ts_sync_1_intr', 'scp_ts_sync_2_intr', 'scp_uart_intr',
        'slcm_fault_intr'
    ]
    
    # 创建中断名到Excel行的映射
    interrupt_to_row = {}
    for index, row in df.iterrows():
        intr_name = str(row['Interrupt Name'])
        if intr_name and intr_name != 'nan' and intr_name.strip():
            interrupt_to_row[intr_name] = row
    
    generated_entries = []
    
    # 为每个缺失的中断生成条目
    for intr_name in missing_interrupts:
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
            if to_scp == 1 and intr_name in scp_interrupt_dict:
                dest_index_scp = scp_interrupt_dict[intr_name]
                rtl_path_scp = f'"top_tb.multidie_top.DUT[0].u_str_top.u_iosub_top_wrap.u0_iosub_top_wrap_hd.u0_iosub_top_wrap_raw.u_scp_top_wrapper.u_scp_top.u_m7_wrapper.cpu_irq[{dest_index_scp}]"'
            
            # MCP路径和索引
            rtl_path_mcp = '""'
            dest_index_mcp = -1
            if to_mcp == 1 and intr_name in mcp_interrupt_dict:
                dest_index_mcp = mcp_interrupt_dict[intr_name]
                rtl_path_mcp = f'"top_tb.multidie_top.DUT[0].u_str_top.u_iosub_top_wrap.u0_iosub_top_wrap_hd.u0_iosub_top_wrap_raw.u_mcp_top.u_cortexm7_wrapper.cpu_irq[{dest_index_mcp}]"'
            
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
    entries = generate_missing_interrupts()
    
    print("// Missing interrupt entries to be added to int_map_entries.svh")
    print("// Generated based on IOSUB中断源 worksheet and SCP/MCP M7 interrupt lists")
    print()
    
    for entry in entries:
        print(entry)
    
    print(f"\n// Total {len(entries)} missing interrupt entries generated")