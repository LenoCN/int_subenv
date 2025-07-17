#!/usr/bin/env python3
"""
Configuration Validation Script

This script validates the hierarchy configuration and tests the signal path generation.
"""

import sys
import os
import json
from generate_signal_paths import SignalPathGenerator

def test_signal_path_generation():
    """Test signal path generation with various interrupt types."""
    print("Testing Signal Path Generation")
    print("=" * 40)
    
    generator = SignalPathGenerator()
    
    # Test cases covering different interrupt groups
    test_cases = [
        # (interrupt_name, group, src_index, dest, dest_index)
        ('csub_pll_intr_lock', 'CSUB', 0, 'scp', 100),
        ('csub_normal0_intr', 'CSUB', 10, 'mcp', 128),
        ('psub_ras_cri_intr', 'PSUB', 0, 'scp', 167),
        ('psub_normal3_intr', 'PSUB', 6, 'mcp', 147),
        ('ddr0_ras_cri_intr', 'DDR0', 0, 'ap', 169),
        ('ddr1_ch0_controller_intr', 'DDR1', 3, 'scp', 207),
        ('ddr2_abnormal_intr', 'DDR2', 6, 'mcp', 192),
        ('accel_iosub_scp2imu_mhu_send_intr', 'ACCEL', 0, 'scp', 50),
        ('accel_to_iosub_intr', 'ACCEL', 5, 'ap', 25),
        ('d2d_to_iosub_intr', 'D2D', 0, 'scp', 80),
        ('scp_wdt0_ws0', 'SCP', 0, 'mcp', 10),
        ('mcp_wdt0_ws0', 'MCP', 0, 'scp', 20),
    ]
    
    success_count = 0
    total_count = len(test_cases)
    
    for i, (int_name, group, src_idx, dest, dest_idx) in enumerate(test_cases, 1):
        print(f"\nTest Case {i}: {int_name}")
        print(f"  Group: {group}")
        
        try:
            # Generate source path
            src_path = generator.generate_source_path(int_name, group, src_idx)
            print(f"  Source Path:      {src_path}")
            
            # Generate destination path
            dest_path = generator.generate_destination_path(dest, dest_idx)
            print(f"  Destination Path: {dest_path}")
            
            # Basic validation
            if src_path and dest_path and 'top_tb.multidie_top.DUT[0]' in src_path:
                print(f"  Status: ✓ PASS")
                success_count += 1
            else:
                print(f"  Status: ✗ FAIL - Invalid path format")
                
        except Exception as e:
            print(f"  Status: ✗ ERROR - {e}")
    
    print(f"\nTest Summary: {success_count}/{total_count} tests passed")
    return success_count == total_count

def validate_config_file():
    """Validate the hierarchy configuration file."""
    print("\nValidating Configuration File")
    print("=" * 40)
    
    try:
        generator = SignalPathGenerator()
        
        # Run built-in validation
        is_valid = generator.validate_configuration()
        
        # Additional checks
        print("\nAdditional Configuration Checks:")
        
        # Check base hierarchy paths
        required_paths = ['iosub_top', 'mcp_top', 'scp_top']
        for path in required_paths:
            if path in generator.base_hierarchy:
                print(f"  ✓ {path}: {generator.base_hierarchy[path]}")
            else:
                print(f"  ✗ Missing {path}")
                is_valid = False
        
        # Check interrupt groups
        print(f"\n  Interrupt Groups: {len(generator.interrupt_groups)} defined")
        for group in generator.interrupt_groups:
            print(f"    - {group}")
        
        # Check signal widths
        print(f"\n  Signal Widths: {len(generator.signal_widths)} defined")
        
        # Check destination mappings
        print(f"\n  Destination Mappings: {len(generator.destination_mappings)} defined")
        for dest in generator.destination_mappings:
            max_idx = generator.destination_mappings[dest].get('max_index', -1)
            print(f"    - {dest}: max_index={max_idx}")
        
        return is_valid
        
    except Exception as e:
        print(f"Configuration validation failed: {e}")
        return False

def check_file_consistency():
    """Check consistency between configuration and generated files."""
    print("\nChecking File Consistency")
    print("=" * 40)
    
    try:
        # Check if int_map_entries.svh exists
        entries_file = "seq/int_map_entries.svh"
        if not os.path.exists(entries_file):
            print(f"  ✗ {entries_file} not found")
            return False
        
        print(f"  ✓ {entries_file} exists")
        
        # Read and analyze the file
        with open(entries_file, 'r', encoding='utf-8') as f:
            content = f.read()
        
        # Count entries
        total_entries = content.count('interrupt_map.push_back(entry);')
        empty_src_paths = content.count('rtl_path_src:""')
        hierarchy_refs = content.count('top_tb.multidie_top.DUT[0]')
        
        print(f"  Total interrupt entries: {total_entries}")
        print(f"  Empty source paths: {empty_src_paths}")
        print(f"  Hierarchy references: {hierarchy_refs}")
        
        # Check for common signals
        signal_checks = [
            ('csub_to_iosub_intr', 'CSUB interrupts'),
            ('psub_to_iosub_intr', 'PSUB interrupts'),
            ('iosub_to_scp_intr', 'SCP destinations'),
            ('iosub_to_mcp_intr', 'MCP destinations'),
        ]
        
        for signal, description in signal_checks:
            count = content.count(signal)
            print(f"  {description}: {count} references")
        
        # Basic consistency check
        if total_entries > 0 and empty_src_paths < total_entries * 0.1:  # Less than 10% empty
            print("  ✓ File consistency check passed")
            return True
        else:
            print("  ✗ File consistency check failed")
            return False
            
    except Exception as e:
        print(f"File consistency check failed: {e}")
        return False

def main():
    """Main validation function."""
    print("Interrupt Verification Configuration Validator")
    print("=" * 50)
    
    # Change to workspace directory
    script_dir = os.path.dirname(os.path.abspath(__file__))
    workspace_dir = os.path.dirname(script_dir)
    os.chdir(workspace_dir)
    
    print(f"Working directory: {workspace_dir}")
    
    # Run validation tests
    tests = [
        ("Configuration File Validation", validate_config_file),
        ("Signal Path Generation Test", test_signal_path_generation),
        ("File Consistency Check", check_file_consistency),
    ]
    
    results = []
    for test_name, test_func in tests:
        print(f"\n{'='*60}")
        print(f"Running: {test_name}")
        print('='*60)
        
        try:
            result = test_func()
            results.append((test_name, result))
        except Exception as e:
            print(f"Test failed with exception: {e}")
            results.append((test_name, False))
    
    # Summary
    print(f"\n{'='*60}")
    print("VALIDATION SUMMARY")
    print('='*60)
    
    passed = 0
    for test_name, result in results:
        status = "PASS" if result else "FAIL"
        symbol = "✓" if result else "✗"
        print(f"  {symbol} {test_name}: {status}")
        if result:
            passed += 1
    
    print(f"\nOverall Result: {passed}/{len(results)} tests passed")
    
    if passed == len(results):
        print("🎉 All validation tests passed!")
        return 0
    else:
        print("❌ Some validation tests failed. Please check the configuration.")
        return 1

if __name__ == "__main__":
    sys.exit(main())
