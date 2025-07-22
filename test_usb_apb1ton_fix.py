#!/usr/bin/env python3
"""
Test script to verify USB apb1ton interrupt fix

This script verifies that:
1. USB apb1ton interrupts have correct RTL source paths pointing to u_iosub_usb_sub
2. These interrupts are correctly merged into iosub_slv_err_intr
3. The Excel processing and RTL path generation logic handles these special cases
"""

import re
import sys
import os

def test_usb_apb1ton_rtl_paths():
    """Test that USB apb1ton interrupts have correct RTL source paths"""
    print("Testing USB apb1ton interrupt RTL paths...")
    
    # Read the generated int_map_entries.svh file
    entries_file = "seq/int_map_entries.svh"
    if not os.path.exists(entries_file):
        print(f"❌ Error: {entries_file} not found")
        return False
    
    with open(entries_file, 'r') as f:
        content = f.read()
    
    # Expected USB apb1ton interrupts and their correct paths
    expected_interrupts = {
        "usb0_apb1ton_intr": "top_tb.multidie_top.DUT[0].u_str_top.u_iosub_top_wrap.u0_iosub_top_wrap_hd.u0_iosub_top_wrap_raw.u_iosub_usb_sub.usb0_apb1ton_intr",
        "usb1_apb1ton_intr": "top_tb.multidie_top.DUT[0].u_str_top.u_iosub_top_wrap.u0_iosub_top_wrap_hd.u0_iosub_top_wrap_raw.u_iosub_usb_sub.usb1_apb1ton_intr",
        "usb_top_apb1ton_intr": "top_tb.multidie_top.DUT[0].u_str_top.u_iosub_top_wrap.u0_iosub_top_wrap_hd.u0_iosub_top_wrap_raw.u_iosub_usb_sub.usb_top_apb1ton_intr"
    }
    
    all_passed = True
    
    for interrupt_name, expected_path in expected_interrupts.items():
        # Find the entry for this interrupt
        pattern = rf'name:"{interrupt_name}".*?rtl_path_src:"([^"]*)"'
        match = re.search(pattern, content)
        
        if not match:
            print(f"❌ Error: Could not find entry for {interrupt_name}")
            all_passed = False
            continue
        
        actual_path = match.group(1)
        
        if actual_path == expected_path:
            print(f"✅ {interrupt_name}: RTL path correct")
        else:
            print(f"❌ {interrupt_name}: RTL path incorrect")
            print(f"   Expected: {expected_path}")
            print(f"   Actual:   {actual_path}")
            all_passed = False
    
    return all_passed

def test_merge_relationship():
    """Test that USB apb1ton interrupts are correctly merged into iosub_slv_err_intr"""
    print("\nTesting merge relationship...")
    
    # Read the int_routing_model.sv file
    routing_file = "seq/int_routing_model.sv"
    if not os.path.exists(routing_file):
        print(f"❌ Error: {routing_file} not found")
        return False
    
    with open(routing_file, 'r') as f:
        content = f.read()
    
    # Check if the merge logic for iosub_slv_err_intr includes our USB interrupts
    expected_interrupts = ["usb0_apb1ton_intr", "usb1_apb1ton_intr", "usb_top_apb1ton_intr"]
    
    # Find the iosub_slv_err_intr section
    pattern = r'"iosub_slv_err_intr":\s*begin.*?end'
    match = re.search(pattern, content, re.DOTALL)
    
    if not match:
        print("❌ Error: Could not find iosub_slv_err_intr merge logic")
        return False
    
    merge_section = match.group(0)
    
    all_found = True
    for interrupt_name in expected_interrupts:
        if interrupt_name in merge_section:
            print(f"✅ {interrupt_name}: Found in iosub_slv_err_intr merge logic")
        else:
            print(f"❌ {interrupt_name}: NOT found in iosub_slv_err_intr merge logic")
            all_found = False
    
    return all_found

def test_hierarchy_config():
    """Test that hierarchy configuration includes USB sub hierarchy"""
    print("\nTesting hierarchy configuration...")
    
    config_file = "config/hierarchy_config.json"
    if not os.path.exists(config_file):
        print(f"❌ Error: {config_file} not found")
        return False
    
    with open(config_file, 'r') as f:
        content = f.read()
    
    # Check if iosub_usb_sub hierarchy is defined
    if '"iosub_usb_sub"' in content:
        print("✅ iosub_usb_sub hierarchy found in configuration")
        
        # Check if the path is correct
        expected_path = "top_tb.multidie_top.DUT[0].u_str_top.u_iosub_top_wrap.u0_iosub_top_wrap_hd.u0_iosub_top_wrap_raw.u_iosub_usb_sub"
        if expected_path in content:
            print("✅ iosub_usb_sub hierarchy path is correct")
            return True
        else:
            print("❌ iosub_usb_sub hierarchy path is incorrect")
            return False
    else:
        print("❌ iosub_usb_sub hierarchy NOT found in configuration")
        return False

def main():
    """Main test function"""
    print("=" * 80)
    print("USB APB1TON Interrupt Fix Verification Test")
    print("=" * 80)
    
    # Change to workspace directory
    if os.path.exists('/mnt/persist/workspace'):
        os.chdir('/mnt/persist/workspace')
    
    test_results = []
    
    # Run all tests
    test_results.append(("RTL Paths", test_usb_apb1ton_rtl_paths()))
    test_results.append(("Merge Relationship", test_merge_relationship()))
    test_results.append(("Hierarchy Config", test_hierarchy_config()))
    
    # Print summary
    print("\n" + "=" * 80)
    print("Test Summary")
    print("=" * 80)
    
    all_passed = True
    for test_name, result in test_results:
        status = "✅ PASS" if result else "❌ FAIL"
        print(f"{test_name:20} {status}")
        if not result:
            all_passed = False
    
    print("=" * 80)
    if all_passed:
        print("🎉 All tests PASSED! USB apb1ton interrupt fix is working correctly.")
        return 0
    else:
        print("❌ Some tests FAILED! Please check the implementation.")
        return 1

if __name__ == "__main__":
    sys.exit(main())
