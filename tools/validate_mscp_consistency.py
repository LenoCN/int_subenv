#!/usr/bin/env python3
"""
Validation tool to check consistency between main interrupt table 
and MSCP-to-IOSUB reference sheet.
"""

import pandas as pd
import sys
import re

def parse_mscp_sheet(file_path: str):
    """Parse MSCP-to-IOSUB sheet and extract interrupt definitions."""
    sheet_name = 'MSCP-to-IOSUB中断'
    
    try:
        df = pd.read_excel(file_path, sheet_name=sheet_name)
        
        scp_interrupts = {}
        mcp_interrupts = {}
        current_source = None
        
        for idx, row in df.iterrows():
            # Check for source headers
            if pd.notna(row['interrupt Source']):
                current_source = row['interrupt Source']
                continue
                
            # Skip rows without interrupt names
            if pd.isna(row['Interrupt Name']) or pd.isna(row['sub index']):
                continue
                
            interrupt_name = str(row['Interrupt Name']).strip()
            sub_index = int(float(row['sub index']))
            
            # Skip reserved entries
            if interrupt_name == 'reserved':
                continue
                
            # Parse routing information
            routing = {
                'to_ap': str(row['to AP?']).upper() == 'YES',
                'to_scp': str(row['to SCP?']).upper() == 'YES', 
                'to_mcp': str(row['to MCP?']).upper() == 'YES',
                'to_accel': str(row['to ACCEL?']).upper() == 'YES',
                'to_io': str(row['to IO?']).upper() == 'YES'
            }
            
            interrupt_info = {
                'sub_index': sub_index,
                'routing': routing,
                'security': str(row['security']).strip(),
                'trigger': str(row['Trigger']).strip(),
                'polarity': str(row[' Polarity']).strip()
            }
            
            if current_source == 'SCP中断源':
                scp_interrupts[interrupt_name] = interrupt_info
            elif current_source == 'MCP中断源':
                mcp_interrupts[interrupt_name] = interrupt_info
                
        return scp_interrupts, mcp_interrupts
        
    except Exception as e:
        print(f"Error parsing MSCP sheet: {e}")
        return {}, {}

def parse_main_interrupts(file_path: str):
    """Parse main interrupt entries from generated file."""
    scp_main = {}
    mcp_main = {}
    
    try:
        with open(file_path, 'r') as f:
            content = f.read()
            
        # Extract interrupt entries
        pattern = r"entry = '\{([^}]+)\}"
        matches = re.findall(pattern, content)
        
        for match in matches:
            # Parse entry fields
            fields = {}
            for field in match.split(', '):
                if ':' in field:
                    key, value = field.split(':', 1)
                    fields[key] = value.strip('"')
            
            if 'group' not in fields or 'name' not in fields:
                continue
                
            name = fields['name']
            group = fields['group']
            
            if group == 'SCP':
                scp_main[name] = fields
            elif group == 'MCP':
                mcp_main[name] = fields
                
        return scp_main, mcp_main
        
    except Exception as e:
        print(f"Error parsing main interrupts: {e}")
        return {}, {}

def validate_consistency(excel_file: str, main_file: str):
    """Validate consistency between MSCP sheet and main interrupt table."""
    print("=== MSCP-to-IOSUB Consistency Validation ===\n")
    
    # Parse both sources
    scp_mscp, mcp_mscp = parse_mscp_sheet(excel_file)
    scp_main, mcp_main = parse_main_interrupts(main_file)
    
    print(f"MSCP sheet - SCP interrupts: {len(scp_mscp)}, MCP interrupts: {len(mcp_mscp)}")
    print(f"Main table - SCP interrupts: {len(scp_main)}, MCP interrupts: {len(mcp_main)}\n")
    
    # Validate SCP interrupts
    print("=== SCP Interrupt Validation ===")
    scp_issues = 0
    for name, mscp_info in scp_mscp.items():
        if name not in scp_main:
            print(f"❌ SCP interrupt '{name}' missing from main table")
            scp_issues += 1
            continue
            
        main_info = scp_main[name]
        
        # Check routing consistency
        routing_issues = []
        if mscp_info['routing']['to_ap'] != (main_info.get('to_ap', '0') == '1'):
            routing_issues.append('AP')
        if mscp_info['routing']['to_scp'] != (main_info.get('to_scp', '0') == '1'):
            routing_issues.append('SCP')
        if mscp_info['routing']['to_mcp'] != (main_info.get('to_mcp', '0') == '1'):
            routing_issues.append('MCP')
        if mscp_info['routing']['to_accel'] != (main_info.get('to_accel', '0') == '1'):
            routing_issues.append('ACCEL')
        if mscp_info['routing']['to_io'] != (main_info.get('to_io', '0') == '1'):
            routing_issues.append('IO')
            
        if routing_issues:
            print(f"⚠️  SCP interrupt '{name}' routing mismatch: {', '.join(routing_issues)}")
            scp_issues += 1
    
    if scp_issues == 0:
        print("✅ All SCP interrupts consistent")
    else:
        print(f"❌ Found {scp_issues} SCP consistency issues")
    
    # Validate MCP interrupts
    print("\n=== MCP Interrupt Validation ===")
    mcp_issues = 0
    for name, mscp_info in mcp_mscp.items():
        if name not in mcp_main:
            print(f"❌ MCP interrupt '{name}' missing from main table")
            mcp_issues += 1
            continue
            
        main_info = mcp_main[name]
        
        # Check routing consistency
        routing_issues = []
        if mscp_info['routing']['to_ap'] != (main_info.get('to_ap', '0') == '1'):
            routing_issues.append('AP')
        if mscp_info['routing']['to_scp'] != (main_info.get('to_scp', '0') == '1'):
            routing_issues.append('SCP')
        if mscp_info['routing']['to_mcp'] != (main_info.get('to_mcp', '0') == '1'):
            routing_issues.append('MCP')
        if mscp_info['routing']['to_accel'] != (main_info.get('to_accel', '0') == '1'):
            routing_issues.append('ACCEL')
        if mscp_info['routing']['to_io'] != (main_info.get('to_io', '0') == '1'):
            routing_issues.append('IO')
            
        if routing_issues:
            print(f"⚠️  MCP interrupt '{name}' routing mismatch: {', '.join(routing_issues)}")
            mcp_issues += 1
    
    if mcp_issues == 0:
        print("✅ All MCP interrupts consistent")
    else:
        print(f"❌ Found {mcp_issues} MCP consistency issues")
    
    total_issues = scp_issues + mcp_issues
    print(f"\n=== Summary ===")
    if total_issues == 0:
        print("✅ All MSCP interrupts are consistent with main table")
        return 0
    else:
        print(f"❌ Found {total_issues} total consistency issues")
        return 1

def main():
    if len(sys.argv) != 3:
        print("Usage: python3 validate_mscp_consistency.py <excel_file> <main_interrupt_file>")
        return 1
        
    excel_file = sys.argv[1]
    main_file = sys.argv[2]
    
    return validate_consistency(excel_file, main_file)

if __name__ == "__main__":
    sys.exit(main())
