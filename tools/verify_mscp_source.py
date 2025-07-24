#!/usr/bin/env python3
"""
Verification script to confirm SCP/MCP interrupts are sourced from MSCP-to-IOSUB sheet.
"""

import pandas as pd
import re

def verify_mscp_source():
    """Verify that SCP/MCP interrupts in generated file match MSCP-to-IOSUB sheet."""
    
    # Read MSCP-to-IOSUB sheet
    df_mscp = pd.read_excel('int_vector.xlsx', sheet_name='MSCP-to-IOSUB中断')
    
    # Extract SCP and MCP interrupts from Excel
    mscp_interrupts = {}
    current_group = ""
    
    for idx, row in df_mscp.iterrows():
        # Check for group header
        if pd.notna(row['interrupt Source']) and pd.isna(row['sub index']):
            group_name = str(row['interrupt Source']).strip()
            if 'SCP' in group_name:
                current_group = 'SCP'
            elif 'MCP' in group_name:
                current_group = 'MCP'
            continue
            
        # Skip empty rows or non-SCP/MCP groups
        if pd.isna(row['Interrupt Name']) or current_group not in ['SCP', 'MCP']:
            continue
            
        if pd.notna(row['Interrupt Name']) and pd.notna(row['sub index']):
            name = str(row['Interrupt Name']).strip()
            index = int(float(row['sub index']))
            
            # Sanitize name
            name_sanitized = re.sub(r'(\s*\[\d+:\d+\]\s*)|(\s*\[\d+\]\s*)', '', name).strip()
            name_sanitized = name_sanitized.replace(' ', '_')
            
            mscp_interrupts[name_sanitized] = {
                'group': current_group,
                'index': index,
                'to_ap': str(row['to AP?']).upper() if pd.notna(row['to AP?']) else 'NO',
                'to_scp': str(row['to SCP?']).upper() if pd.notna(row['to SCP?']) else 'NO',
                'to_mcp': str(row['to MCP?']).upper() if pd.notna(row['to MCP?']) else 'NO',
                'to_imu': str(row['to IMU?']).upper() if pd.notna(row['to IMU?']) else 'NO'
            }
    
    # Read generated SystemVerilog file
    with open('seq/int_map_entries.svh', 'r') as f:
        sv_content = f.read()
    
    # Extract SCP and MCP entries from SV file
    sv_scp_entries = []
    sv_mcp_entries = []
    
    lines = sv_content.split('\n')
    for line in lines:
        if 'group:SCP' in line:
            # Extract interrupt name
            name_match = re.search(r'name:"([^"]+)"', line)
            if name_match:
                sv_scp_entries.append(name_match.group(1))
        elif 'group:MCP' in line:
            # Extract interrupt name
            name_match = re.search(r'name:"([^"]+)"', line)
            if name_match:
                sv_mcp_entries.append(name_match.group(1))
    
    print("=== MSCP Source Verification ===")
    print(f"Found {len(mscp_interrupts)} SCP/MCP interrupts in MSCP-to-IOSUB sheet")
    print(f"Found {len(sv_scp_entries)} SCP interrupts in generated SV file")
    print(f"Found {len(sv_mcp_entries)} MCP interrupts in generated SV file")
    print()
    
    # Verify SCP interrupts
    scp_excel = [name for name, info in mscp_interrupts.items() if info['group'] == 'SCP']
    print(f"SCP interrupts in Excel: {len(scp_excel)}")
    print(f"SCP interrupts in SV: {len(sv_scp_entries)}")
    
    missing_in_sv = set(scp_excel) - set(sv_scp_entries)
    extra_in_sv = set(sv_scp_entries) - set(scp_excel)
    
    if missing_in_sv:
        print(f"Missing SCP interrupts in SV: {missing_in_sv}")
    if extra_in_sv:
        print(f"Extra SCP interrupts in SV: {extra_in_sv}")
    
    # Verify MCP interrupts
    mcp_excel = [name for name, info in mscp_interrupts.items() if info['group'] == 'MCP']
    print(f"MCP interrupts in Excel: {len(mcp_excel)}")
    print(f"MCP interrupts in SV: {len(sv_mcp_entries)}")
    
    missing_in_sv = set(mcp_excel) - set(sv_mcp_entries)
    extra_in_sv = set(sv_mcp_entries) - set(mcp_excel)
    
    if missing_in_sv:
        print(f"Missing MCP interrupts in SV: {missing_in_sv}")
    if extra_in_sv:
        print(f"Extra MCP interrupts in SV: {extra_in_sv}")
    
    # Show some examples
    print("\n=== Sample SCP Interrupts from MSCP-to-IOSUB ===")
    scp_samples = [(name, info) for name, info in mscp_interrupts.items() if info['group'] == 'SCP'][:5]
    for name, info in scp_samples:
        print(f"{name}: index={info['index']}, AP={info['to_ap']}, SCP={info['to_scp']}, MCP={info['to_mcp']}")
    
    print("\n=== Sample MCP Interrupts from MSCP-to-IOSUB ===")
    mcp_samples = [(name, info) for name, info in mscp_interrupts.items() if info['group'] == 'MCP'][:5]
    for name, info in mcp_samples:
        print(f"{name}: index={info['index']}, AP={info['to_ap']}, SCP={info['to_scp']}, MCP={info['to_mcp']}")
    
    print("\n=== Verification Complete ===")
    if len(scp_excel) == len(sv_scp_entries) and len(mcp_excel) == len(sv_mcp_entries):
        print("✓ SCP/MCP interrupt counts match between Excel and SV files")
    else:
        print("✗ SCP/MCP interrupt counts do not match")

if __name__ == "__main__":
    verify_mscp_source()
