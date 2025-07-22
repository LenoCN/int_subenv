#!/usr/bin/env python3
"""
Signal Path Generator for Interrupt Verification

This tool generates the correct RTL signal paths for interrupt stimulus and monitoring
based on the hierarchy information and index mappings.
"""

import re
import sys
import json
import os
from typing import Dict, List, Tuple, Optional

class SignalPathGenerator:
    def __init__(self, config_file: str = None):
        """
        Initialize the signal path generator.

        Args:
            config_file: Path to hierarchy configuration JSON file.
                        If None, uses default config/hierarchy_config.json
        """
        if config_file is None:
            # Default config file path relative to this script
            script_dir = os.path.dirname(os.path.abspath(__file__))
            config_file = os.path.join(script_dir, '..', 'config', 'hierarchy_config.json')

        self.config_file = config_file
        self.load_config()

    def load_config(self):
        """Load hierarchy configuration from JSON file."""
        try:
            with open(self.config_file, 'r', encoding='utf-8') as f:
                config = json.load(f)

            self.base_hierarchy = config.get('base_hierarchy', {})
            self.signal_mappings = config.get('signal_mappings', {})
            self.signal_widths = config.get('signal_widths', {})
            self.interrupt_groups = config.get('interrupt_groups', {})
            self.destination_mappings = config.get('destination_mappings', {})
            self.hierarchy_rules = config.get('hierarchy_selection_rules', {})

            print(f"Loaded hierarchy configuration from: {self.config_file}")

        except FileNotFoundError:
            print(f"Warning: Config file not found: {self.config_file}")
            print("Using fallback default configuration...")
            self._load_default_config()
        except json.JSONDecodeError as e:
            print(f"Error parsing config file: {e}")
            print("Using fallback default configuration...")
            self._load_default_config()

    def _load_default_config(self):
        """Load default configuration as fallback."""
        # Fallback to hardcoded configuration
        self.base_hierarchy = {
            'iosub_top': 'top_tb.multidie_top.DUT[0].u_str_top.u_iosub_top_wrap',
            'mcp_top': 'top_tb.multidie_top.DUT[0].u_str_top.u_iosub_top_wrap.u0_iosub_top_wrap_hd.u0_iosub_top_wrap_raw.u_mcp_top',
            'scp_top': 'top_tb.multidie_top.DUT[0].u_str_top.u_iosub_top_wrap.u0_iosub_top_wrap_hd.u0_iosub_top_wrap_raw.u_scp_top_wrapper',
            'iosub_int_sub': 'top_tb.multidie_top.DUT[0].u_str_top.u_iosub_top_wrap.u0_iosub_top_wrap_hd.u0_iosub_top_wrap_raw.u_iosub_int_sub'
        }
        
        # Signal mappings from the provided hierarchy information
        self.signal_mappings = {
            # IOSUB TOP signals (inputs to IOSUB)
            'iosub_inputs': {
                'accel_iosub_scp2imu_mhu_send_intr': 'accel_iosub_scp2imu_mhu_send_intr',
                'accel_iosub_mcp2imu_mhu_send_intr': 'accel_iosub_mcp2imu_mhu_send_intr',
                'accel_iosub_imu2scp_mhu_receive_intr': 'accel_iosub_imu2scp_mhu_receive_intr',
                'accel_iosub_imu2mcp_mhu_receive_intr': 'accel_iosub_imu2mcp_mhu_receive_intr',
                'accel_iosub_imu_ws1_intr': 'accel_iosub_imu_ws1_intr',
                'csub_iosub_pll_lock_intr': 'csub_iosub_pll_lock_intr',
                'csub_iosub_pll_unlock_intr': 'csub_iosub_pll_unlock_intr',
                'csub_iosub_pll_frechangedone_intr': 'csub_iosub_pll_frechangedone_intr',
                'csub_iosub_pll_frechange_tot_done_intr': 'csub_iosub_pll_frechange_tot_done_intr',
                'csub_iosub_pll_intdocfrac_err_intr': 'csub_iosub_pll_intdocfrac_err_intr',
                'csub_to_iosub_intr': 'csub_to_iosub_intr',
                'psub_to_iosub_intr': 'psub_to_iosub_intr',
                'pciel_to_iosub_intr': 'pciel_to_iosub_intr',
                'accel_to_iosub_intr': 'accel_to_iosub_intr',
                'd2d_to_iosub_intr': 'd2d_to_iosub_intr',
                'ddr0_to_iosub_intr': 'ddr0_to_iosub_intr',
                'ddr1_to_iosub_intr': 'ddr1_to_iosub_intr',
                'ddr2_to_iosub_intr': 'ddr2_to_iosub_intr'
            },
            
            # IOSUB TOP outputs
            'iosub_outputs': {
                'iosub_accel_peri_intr': 'iosub_accel_peri_intr'
            },
            
            # MCP signals
            'mcp_inputs': {
                'iosub_to_mcp_intr': 'iosub_to_mcp_intr'
            },
            'mcp_outputs': {
                'mcp_to_iosub_intr': 'mcp_to_iosub_intr'
            },
            
            # SCP signals  
            'scp_inputs': {
                'iosub_to_scp_intr': 'iosub_to_scp_intr'
            },
            'scp_outputs': {
                'scp_to_iosub_intr': 'scp_to_iosub_intr'
            }
        }
        
        # Signal bit widths from the provided information
        self.signal_widths = {
            'iosub_to_mcp_intr': 146,  # [145:0]
            'mcp_to_iosub_intr': 8,    # [7:0]
            'iosub_to_scp_intr': 131,  # [130:0]
            'scp_to_iosub_intr': 53,   # [52:0]
            'iosub_accel_peri_intr': 32, # [31:0]
            'csub_iosub_pll_lock_intr': 17,  # [16:0]
            'csub_iosub_pll_unlock_intr': 17,
            'csub_iosub_pll_frechangedone_intr': 17,
            'csub_iosub_pll_frechange_tot_done_intr': 17,
            'csub_iosub_pll_intdocfrac_err_intr': 17,
            'csub_to_iosub_intr': 21,  # [20:0]
            'psub_to_iosub_intr': 22,  # [21:0]
            'pciel_to_iosub_intr': 22, # [21:0]
            'accel_to_iosub_intr': 15, # [14:0]
            'd2d_to_iosub_intr': 18,   # [17:0]
            'ddr0_to_iosub_intr': 11,  # [10:0]
            'ddr1_to_iosub_intr': 11,  # [10:0]
            'ddr2_to_iosub_intr': 11   # [10:0]
        }

    def select_hierarchy_for_signal(self, interrupt_name: str, group: str, purpose: str = "stimulus") -> str:
        """
        Select the appropriate hierarchy for a signal based on rules.

        Args:
            interrupt_name: Name of the interrupt
            group: Interrupt group (CSUB, SCP, MCP, etc.)
            purpose: "stimulus" or "monitor"

        Returns:
            Hierarchy key (iosub_top, mcp_top, scp_top, iosub_int_sub)
        """
        # Check if we have hierarchy selection rules
        if not hasattr(self, 'hierarchy_rules') or not self.hierarchy_rules:
            return self._fallback_hierarchy_selection(group)

        hierarchy_config = self.hierarchy_rules.get(f"{purpose}_hierarchy", {})
        signal_mapping = self.hierarchy_rules.get("signal_type_mapping", {})

        # Check for boundary signals first
        boundary_signals = signal_mapping.get("boundary_signals", [])
        for boundary_signal in boundary_signals:
            if boundary_signal in interrupt_name:
                return "iosub_int_sub"

        # Check by group type
        if group in signal_mapping.get("external_inputs", []):
            return hierarchy_config.get("external_subsystems", "iosub_top")
        elif group in signal_mapping.get("mcp_signals", []):
            return hierarchy_config.get("mcp_interactions", "mcp_top")
        elif group in signal_mapping.get("scp_signals", []):
            return hierarchy_config.get("scp_interactions", "scp_top")
        elif group in signal_mapping.get("internal_signals", []):
            return hierarchy_config.get("internal_boundaries", "iosub_int_sub")

        # Check for specific signal patterns
        if any(pattern in interrupt_name for pattern in ["smmu", "usb", "peri", "dap", "pad_int"]):
            return "iosub_int_sub"

        # Default fallback
        return self._fallback_hierarchy_selection(group)

    def _fallback_hierarchy_selection(self, group: str) -> str:
        """Fallback hierarchy selection for backward compatibility."""
        if group == "SCP":
            return "scp_top"
        elif group == "MCP":
            return "mcp_top"
        elif group == "IOSUB":
            return "iosub_int_sub"
        else:
            return "iosub_top"

    def get_iosub_boundary_signal(self, group: str, interrupt_name: str) -> str:
        """
        Get the correct iosub_int_sub boundary signal for a given interrupt group.

        Args:
            group: Interrupt group (USB, SMMU, etc.)
            interrupt_name: Name of the interrupt

        Returns:
            The correct boundary signal name at iosub_int_sub level
        """
        # Check if we have group to signal mapping in hierarchy rules
        if hasattr(self, 'hierarchy_rules') and self.hierarchy_rules:
            group_mapping = self.hierarchy_rules.get("group_to_iosub_signal_mapping", {})
            if group in group_mapping:
                return group_mapping[group]

        # Fallback mapping based on group
        group_signal_map = {
            "USB": "iosub_usb_intr",
            "SMMU": "iosub_smmu_level_intr",
            "IODAP": "iosub_dap_intr",
            "IO_DIE": "pad_int_i",
            "CSUB": "csub_to_iosub_intr",
            "PSUB": "psub_to_iosub_intr",
            "PCIE1": "pciel_to_iosub_intr",
            "ACCEL": "accel_to_iosub_intr",
            "D2D": "d2d_to_iosub_intr",
            "DDR0": "ddr0_to_iosub_intr",
            "DDR1": "ddr1_to_iosub_intr",
            "DDR2": "ddr2_to_iosub_intr",
            "SCP": "scp_to_iosub_intr",
            "MCP": "mcp_to_iosub_intr"
        }

        return group_signal_map.get(group, "")  # Return empty string if not found

    def generate_source_signal_path(self, signal_name: str, group: str, index: int) -> str:
        """
        Generate the RTL source path for specific signals like scp_to_iosub_intr and mcp_to_iosub_intr.

        Args:
            signal_name: Name of the signal (e.g., "scp_to_iosub_intr", "mcp_to_iosub_intr")
            group: Interrupt group (SCP, MCP, etc.)
            index: Index within the signal

        Returns:
            Full RTL path for the source signal
        """
        if signal_name == "scp_to_iosub_intr" and group == "SCP":
            # Use the correct hierarchy for scp_to_iosub signal
            scp_hierarchy = self.signal_mappings.get('scp_signals', {}).get('scp_to_iosub_hierarchy', '')
            if scp_hierarchy:
                return f"{scp_hierarchy}.scp_to_iosub_intr[{index}]"
            else:
                # Fallback to base hierarchy
                scp_base = self.base_hierarchy.get('scp_top', '')
                return f"{scp_base}.scp_to_iosub_intr[{index}]"

        elif signal_name == "mcp_to_iosub_intr" and group == "MCP":
            # Use the correct hierarchy for mcp_to_iosub signal
            mcp_hierarchy = self.signal_mappings.get('mcp_signals', {}).get('mcp_to_iosub_hierarchy', '')
            if mcp_hierarchy:
                return f"{mcp_hierarchy}.mcp_to_iosub_intr[{index}]"
            else:
                # Fallback to base hierarchy
                mcp_base = self.base_hierarchy.get('mcp_top', '')
                return f"{mcp_base}.mcp_to_iosub_intr[{index}]"
        else:
            # For other signals, use the standard source path generation
            return self.generate_source_path(signal_name, group, index)

    def generate_source_path(self, interrupt_name: str, group: str, index: int) -> str:
        """
        Generate the RTL source path for stimulus based on interrupt name and group.
        This determines where to apply the force for interrupt stimulus.

        Uses configuration file to determine the correct signal paths.
        """
        # Select appropriate hierarchy for stimulus
        hierarchy_key = self.select_hierarchy_for_signal(interrupt_name, group, "stimulus")
        base_path = self.base_hierarchy.get(hierarchy_key, self.base_hierarchy.get('iosub_top', ''))

        # Check if group is defined in configuration
        if group in self.interrupt_groups:
            group_config = self.interrupt_groups[group]

            # Check for special signals first
            if 'special_signals' in group_config:
                for special_key, signal_name in group_config['special_signals'].items():
                    if special_key in interrupt_name:
                        # Check if this signal has a special hierarchy
                        if 'special_hierarchy' in group_config and special_key in group_config['special_hierarchy']:
                            special_hierarchy_key = group_config['special_hierarchy'][special_key]
                            special_base_path = self.base_hierarchy.get(special_hierarchy_key, base_path)
                            if signal_name.endswith('_intr') and '[' not in signal_name:
                                # Single bit signal
                                return f"{special_base_path}.{signal_name}"
                            else:
                                # Multi-bit signal - for USB apb1ton interrupts, they are single bit signals
                                return f"{special_base_path}.{signal_name}"
                        else:
                            if signal_name.endswith('_intr') and '[' not in signal_name:
                                # Single bit signal
                                return f"{base_path}.{signal_name}"
                            else:
                                # Multi-bit signal
                                return f"{base_path}.{signal_name}[{index}]"

            # Use base signal for the group
            base_signal = group_config.get('base_signal', f"{group.lower()}_to_iosub_intr")

            # Handle special cases based on hierarchy
            if hierarchy_key == 'scp_top':
                return f"{base_path}.{base_signal}[{index}]"
            elif hierarchy_key == 'mcp_top':
                return f"{base_path}.{base_signal}[{index}]"
            elif hierarchy_key == 'iosub_int_sub':
                # For iosub_int_sub, use the correct boundary signal mapping
                iosub_signal = self.get_iosub_boundary_signal(group, interrupt_name)
                if iosub_signal:
                    return f"{base_path}.{iosub_signal}[{index}]"
                else:
                    # Fallback to base signal if no specific mapping found
                    return f"{base_path}.{base_signal}[{index}]"
            elif group == 'IOSUB':
                # Internal IOSUB interrupts at iosub_top level
                return f"{base_path}.{interrupt_name}_internal_src"
            else:
                # Standard external input signals
                return f"{base_path}.{base_signal}[{index}]"

        # Fallback for unknown groups - try to infer from group name
        else:
            print(f"Warning: Unknown interrupt group '{group}', using fallback logic")

            # Try common patterns
            if group.upper() in ['USB', 'SMMU', 'IODAP', 'IO_DIE']:
                return f"{base_path}.{interrupt_name}_src"
            else:
                # Default pattern: group_to_iosub_intr
                signal_name = f"{group.lower()}_to_iosub_intr"
                return f"{base_path}.{signal_name}[{index}]"

    def generate_destination_path(self, destination: str, index: int, interrupt_name: str = "") -> str:
        """
        Generate the RTL destination path for monitoring based on destination and index.
        Uses configuration file to determine the correct destination paths.

        Args:
            destination: Target destination (ap, scp, mcp, imu, io, other_die)
            index: Index within the destination signal
            interrupt_name: Optional interrupt name for hierarchy selection
        """
        # Check if destination is defined in configuration
        if destination in self.destination_mappings:
            dest_config = self.destination_mappings[destination]
            signal_name = dest_config.get('signal', f"iosub_to_{destination}_intr")
            hierarchy_path = dest_config.get('hierarchy_path', '')
            max_index = dest_config.get('max_index', -1)

            # Validate index range if specified
            if max_index >= 0 and index > max_index:
                print(f"Warning: Index {index} exceeds max index {max_index} for destination {destination}")

            # Use the specific hierarchy path if provided, otherwise use base hierarchy
            if hierarchy_path:
                return f"{hierarchy_path}.{signal_name}[{index}]"
            else:
                # Generate path based on destination type and monitoring requirements
                if destination == 'scp':
                    # Check if we should monitor at iosub_int_sub for cross-boundary checking
                    if interrupt_name and self.hierarchy_rules.get("monitor_hierarchy", {}).get("cross_boundary_check") == "iosub_int_sub":
                        int_sub_base = self.base_hierarchy.get('iosub_int_sub', '')
                        return f"{int_sub_base}.{signal_name}[{index}]"
                    else:
                        scp_base = self.base_hierarchy.get('scp_top', '')
                        return f"{scp_base}.{signal_name}[{index}]"
                elif destination == 'mcp':
                    # Check if we should monitor at iosub_int_sub for cross-boundary checking
                    if interrupt_name and self.hierarchy_rules.get("monitor_hierarchy", {}).get("cross_boundary_check") == "iosub_int_sub":
                        int_sub_base = self.base_hierarchy.get('iosub_int_sub', '')
                        return f"{int_sub_base}.{signal_name}[{index}]"
                    else:
                        mcp_base = self.base_hierarchy.get('mcp_top', '')
                        return f"{mcp_base}.{signal_name}[{index}]"
                elif destination == 'imu':
                    # IMU signals can be monitored at iosub_int_sub for internal boundary checking
                    if interrupt_name and any(pattern in interrupt_name for pattern in ["accel", "imu"]):
                        int_sub_base = self.base_hierarchy.get('iosub_int_sub', '')
                        return f"{int_sub_base}.{signal_name}[{index}]"
                    else:
                        iosub_base = self.base_hierarchy.get('iosub_top', '')
                        return f"{iosub_base}.{signal_name}[{index}]"
                else:
                    # For ap, io, other_die - these go through iosub_top
                    iosub_base = self.base_hierarchy.get('iosub_top', '')
                    return f"{iosub_base}.{signal_name}[{index}]"

        # Fallback for unknown destinations
        else:
            print(f"Warning: Unknown destination '{destination}', using fallback logic")
            iosub_base = self.base_hierarchy.get('iosub_top', '')
            return f"{iosub_base}.iosub_to_{destination}_intr[{index}]"

    def validate_index_range(self, signal_name: str, index: int) -> bool:
        """
        Validate that the index is within the valid range for the signal.
        """
        if signal_name in self.signal_widths:
            return 0 <= index < self.signal_widths[signal_name]
        return True  # Assume valid if width not known

    def validate_configuration(self) -> bool:
        """
        Validate the loaded configuration for completeness and consistency.
        """
        print("Validating configuration...")

        # Check required base hierarchy paths
        required_paths = ['iosub_top', 'mcp_top', 'scp_top', 'iosub_int_sub']
        for path in required_paths:
            if path not in self.base_hierarchy:
                print(f"Error: Missing required hierarchy path: {path}")
                return False

        # Check signal widths consistency
        if hasattr(self, 'validation_rules') and 'required_signals' in self.validation_rules:
            for signal in self.validation_rules['required_signals']:
                if signal not in self.signal_widths:
                    print(f"Warning: Missing signal width for required signal: {signal}")

        print("Configuration validation completed")
        return True

    def update_config(self, updates: dict):
        """
        Update configuration and save to file.

        Args:
            updates: Dictionary containing configuration updates
        """
        try:
            # Load current config
            with open(self.config_file, 'r', encoding='utf-8') as f:
                config = json.load(f)

            # Apply updates
            for key, value in updates.items():
                if key in config:
                    config[key].update(value) if isinstance(config[key], dict) else config.update({key: value})
                else:
                    config[key] = value

            # Update timestamp
            config['last_updated'] = '2025-07-17'

            # Save updated config
            with open(self.config_file, 'w', encoding='utf-8') as f:
                json.dump(config, f, indent=2, ensure_ascii=False)

            print(f"Configuration updated and saved to: {self.config_file}")

            # Reload configuration
            self.load_config()

        except Exception as e:
            print(f"Error updating configuration: {e}")

def main():
    import argparse

    parser = argparse.ArgumentParser(description='Signal Path Generator for Interrupt Verification')
    parser.add_argument('-c', '--config', help='Path to hierarchy configuration file')
    parser.add_argument('-t', '--test', action='store_true', help='Run test cases')
    parser.add_argument('-v', '--validate', action='store_true', help='Validate configuration')

    args = parser.parse_args()

    # Initialize generator
    generator = SignalPathGenerator(args.config)

    # Validate configuration if requested
    if args.validate:
        generator.validate_configuration()

    # Run test cases if requested
    if args.test:
        print("Signal Path Generator for Interrupt Verification")
        print("=" * 50)

        # Test some example paths
        test_cases = [
            ('csub_pll_intr_lock', 'CSUB', 0, 'scp', 100),
            ('psub_normal3_intr', 'PSUB', 3, 'mcp', 147),
            ('ddr0_ras_cri_intr', 'DDR0', 0, 'ap', 169),
            ('accel_iosub_scp2imu_mhu_send_intr', 'ACCEL', 0, 'scp', 50),
        ]

        for int_name, group, src_idx, dest, dest_idx in test_cases:
            src_path = generator.generate_source_path(int_name, group, src_idx)
            dest_path = generator.generate_destination_path(dest, dest_idx)

            print(f"\nInterrupt: {int_name}")
            print(f"  Group: {group}")
            print(f"  Source Path:      {src_path}")
            print(f"  Destination Path: {dest_path}")

    if not args.test and not args.validate:
        print("Use --test to run test cases or --validate to check configuration")
        print("Use --help for more options")

if __name__ == "__main__":
    main()
