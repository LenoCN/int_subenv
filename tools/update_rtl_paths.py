#!/usr/bin/env python3
"""
RTL Path Updater for Interrupt Map Entries

This tool updates the int_map_entries.svh file with correct RTL paths
based on the hierarchy information and signal mappings.
"""

import re
import sys
import os
from generate_signal_paths import SignalPathGenerator

class RTLPathUpdater:
    def __init__(self, config_file: str = None):
        """
        Initialize RTL path updater.

        Args:
            config_file: Path to hierarchy configuration file
        """
        self.generator = SignalPathGenerator(config_file)
        self.entries_file = "seq/int_map_entries.svh"
        
    def parse_entry_line(self, line: str) -> dict:
        """
        Parse a single interrupt map entry line and extract key information.
        """
        # Extract interrupt name
        name_match = re.search(r'name:"([^"]+)"', line)
        if not name_match:
            return None
            
        name = name_match.group(1)
        
        # Extract group
        group_match = re.search(r'group:(\w+)', line)
        group = group_match.group(1) if group_match else "UNKNOWN"
        
        # Extract index
        index_match = re.search(r'index:(\d+)', line)
        index = int(index_match.group(1)) if index_match else 0
        
        # Extract destination indices
        dest_indices = {}
        for dest in ['ap', 'scp', 'mcp', 'imu', 'io', 'other_die']:
            pattern = f'dest_index_{dest}:(-?\d+)'
            match = re.search(pattern, line)
            if match:
                dest_indices[dest] = int(match.group(1))
        
        # Extract to_destination flags
        to_flags = {}
        for dest in ['ap', 'scp', 'mcp', 'imu', 'io', 'other_die']:
            pattern = f'to_{dest}:([01])'
            match = re.search(pattern, line)
            if match:
                to_flags[dest] = int(match.group(1))
        
        return {
            'name': name,
            'group': group,
            'index': index,
            'dest_indices': dest_indices,
            'to_flags': to_flags,
            'original_line': line
        }
    
    def generate_updated_line(self, entry_info: dict) -> str:
        """
        Generate an updated entry line with correct RTL paths.
        """
        if not entry_info:
            return entry_info['original_line']
        
        name = entry_info['name']
        group = entry_info['group']
        index = entry_info['index']
        dest_indices = entry_info['dest_indices']
        to_flags = entry_info['to_flags']
        
        # Generate source path for stimulus
        src_path = self.generator.generate_source_path(name, group, index)
        
        # Generate destination paths for monitoring
        dest_paths = {}
        for dest in ['ap', 'scp', 'mcp', 'imu', 'io', 'other_die']:
            if to_flags.get(dest, 0) == 1 and dest_indices.get(dest, -1) >= 0:
                dest_paths[dest] = self.generator.generate_destination_path(dest, dest_indices[dest])
            else:
                dest_paths[dest] = ""
        
        # Build the updated line
        line = entry_info['original_line']
        
        # Update rtl_path_src
        line = re.sub(r'rtl_path_src:"[^"]*"', f'rtl_path_src:"{src_path}"', line)
        
        # Update destination paths
        for dest in ['ap', 'scp', 'mcp', 'imu', 'io', 'other_die']:
            pattern = f'rtl_path_{dest}:"[^"]*"'
            replacement = f'rtl_path_{dest}:"{dest_paths[dest]}"'
            line = re.sub(pattern, replacement, line)
        
        return line
    
    def update_entries_file(self):
        """
        Update the int_map_entries.svh file with correct RTL paths.
        """
        if not os.path.exists(self.entries_file):
            print(f"Error: {self.entries_file} not found!")
            return False
        
        # Read the original file
        with open(self.entries_file, 'r', encoding='utf-8') as f:
            lines = f.readlines()
        
        # Process each line
        updated_lines = []
        updated_count = 0
        
        for line in lines:
            if 'interrupt_map.push_back(entry);' in line:
                # This is an entry line, parse and update it
                entry_info = self.parse_entry_line(line)
                if entry_info:
                    updated_line = self.generate_updated_line(entry_info)
                    updated_lines.append(updated_line)
                    updated_count += 1
                    
                    # Print progress for some entries
                    if updated_count <= 5 or updated_count % 50 == 0:
                        print(f"Updated entry {updated_count}: {entry_info['name']}")
                else:
                    updated_lines.append(line)
            else:
                # Keep non-entry lines as-is
                updated_lines.append(line)
        
        # Create backup of original file
        backup_file = f"{self.entries_file}.backup"
        with open(backup_file, 'w', encoding='utf-8') as f:
            f.writelines(lines)
        print(f"Created backup: {backup_file}")
        
        # Write updated file
        with open(self.entries_file, 'w', encoding='utf-8') as f:
            f.writelines(updated_lines)
        
        print(f"Updated {updated_count} interrupt entries in {self.entries_file}")
        return True
    
    def validate_paths(self):
        """
        Validate the generated paths for common issues.
        """
        print("\nValidating generated paths...")
        
        # Read the updated file
        with open(self.entries_file, 'r', encoding='utf-8') as f:
            content = f.read()
        
        # Check for empty source paths
        empty_src_count = content.count('rtl_path_src:""')
        print(f"Entries with empty source paths: {empty_src_count}")
        
        # Check for common path patterns
        hierarchy_patterns = [
            'top_tb.multidie_top.DUT[0]',
            'u_iosub_top_wrap',
            'u_mcp_top',
            'u_scp_top_wrapper'
        ]
        
        for pattern in hierarchy_patterns:
            count = content.count(pattern)
            print(f"Paths containing '{pattern}': {count}")

def main():
    import argparse

    parser = argparse.ArgumentParser(description='RTL Path Updater for Interrupt Map Entries')
    parser.add_argument('-c', '--config', help='Path to hierarchy configuration file')
    parser.add_argument('-e', '--entries', default='seq/int_map_entries.svh',
                       help='Path to interrupt map entries file')

    args = parser.parse_args()

    updater = RTLPathUpdater(args.config)

    # Override entries file if specified
    if args.entries:
        updater.entries_file = args.entries

    print("RTL Path Updater for Interrupt Map Entries")
    print("=" * 50)
    print(f"Using configuration: {updater.generator.config_file}")
    print(f"Updating entries file: {updater.entries_file}")

    # Update the entries file
    if updater.update_entries_file():
        # Validate the results
        updater.validate_paths()
        print("\nRTL path update completed successfully!")
    else:
        print("RTL path update failed!")
        return 1

    return 0

if __name__ == "__main__":
    sys.exit(main())
