#!/usr/bin/env python3
"""
Simple Python script to test the merge interrupt logic by parsing the SystemVerilog files
"""

import re
import sys
from pathlib import Path

def parse_interrupt_entries(sv_file_path):
    """Parse interrupt entries from the SystemVerilog routing model file"""
    interrupts = []
    
    with open(sv_file_path, 'r', encoding='utf-8') as f:
        content = f.read()
    
    # Find all interrupt entries
    pattern = r"entry = '\{name:\"([^\"]+)\", index:(\d+), group:(\w+),"
    matches = re.findall(pattern, content)
    
    for match in matches:
        name, index, group = match
        interrupts.append({
            'name': name,
            'index': int(index),
            'group': group
        })
    
    return interrupts

def find_merge_interrupts(interrupts):
    """Find all merge interrupts"""
    merge_interrupts = []
    for intr in interrupts:
        if intr['name'].startswith('merge_'):
            merge_interrupts.append(intr)
    return merge_interrupts

def find_source_interrupts_for_merge(merge_name, interrupts):
    """Find source interrupts for a specific merge interrupt"""
    sources = []
    
    if merge_name == "merge_pll_intr_lock":
        source_names = [
            "iosub_pll_lock_intr",
            "accel_pll_lock_intr", 
            "csub_pll_intr_lock",
            "psub_pll_lock_intr",
            "pcie1_pll_lock_intr",
            "d2d_pll_lock_intr",
            "ddr0_pll_lock_intr",
            "ddr1_pll_lock_intr",
            "ddr2_pll_lock_intr"
        ]
    elif merge_name == "merge_pll_intr_unlock":
        source_names = [
            "iosub_pll_unlock_intr",
            "accel_pll_unlock_intr",
            "csub_pll_intr_unlock", 
            "psub_pll_unlock_intr",
            "pcie1_pll_unlock_intr",
            "d2d_pll_unlock_intr",
            "ddr0_pll_unlock_intr",
            "ddr1_pll_unlock_intr",
            "ddr2_pll_unlock_intr"
        ]
    elif merge_name == "merge_pll_intr_frechangedone":
        source_names = [
            "csub_pll_intr_frechangedone",
            "ddr0_pll_frechangedone_intr",
            "ddr1_pll_frechangedone_intr", 
            "ddr2_pll_frechangedone_intr"
        ]
    elif merge_name == "merge_pll_intr_frechange_tot_done":
        source_names = [
            "csub_pll_intr_frechange_tot_done",
            "ddr0_pll_frechange_tot_done_intr",
            "ddr1_pll_frechange_tot_done_intr",
            "ddr2_pll_frechange_tot_done_intr"
        ]
    elif merge_name == "merge_pll_intr_intdocfrac_err":
        source_names = [
            "csub_pll_intr_intdocfrac_err",
            "ddr0_pll_intdocfrac_err_intr",
            "ddr1_pll_intdocfrac_err_intr",
            "ddr2_pll_intdocfrac_err_intr"
        ]
    else:
        return sources
    
    # Find matching interrupts
    for intr in interrupts:
        if intr['name'] in source_names:
            sources.append(intr)
    
    return sources

def main():
    # Path to the routing model file
    sv_file = Path("seq/int_routing_model.sv")
    
    if not sv_file.exists():
        print(f"Error: {sv_file} not found")
        sys.exit(1)
    
    print("=== Testing Merge Interrupt Logic ===")
    
    # Parse interrupts
    interrupts = parse_interrupt_entries(sv_file)
    print(f"Parsed {len(interrupts)} interrupts from {sv_file}")
    
    # Find merge interrupts
    merge_interrupts = find_merge_interrupts(interrupts)
    print(f"Found {len(merge_interrupts)} merge interrupts:")
    
    for merge_intr in merge_interrupts:
        print(f"  - {merge_intr['name']} (index: {merge_intr['index']}, group: {merge_intr['group']})")
    
    print()
    
    # Test each merge interrupt
    for merge_intr in merge_interrupts:
        print(f"--- Testing {merge_intr['name']} ---")
        
        sources = find_source_interrupts_for_merge(merge_intr['name'], interrupts)
        print(f"Found {len(sources)} source interrupts:")
        
        for i, source in enumerate(sources):
            print(f"  [{i}] {source['name']} (group: {source['group']}, index: {source['index']})")
        
        if len(sources) == 0:
            print("  WARNING: No source interrupts found!")
        
        print()
    
    print("=== Merge Interrupt Logic Test Complete ===")

if __name__ == "__main__":
    main()
