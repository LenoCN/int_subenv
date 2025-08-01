#!/usr/bin/env python3
"""
Excel-based interrupt vector table converter.
Converts int_vector.xlsx to SystemVerilog routing model with comprehensive signal mapping.

Data Sources:
- IOSUB中断源: IOSUB group interrupts (excluding SCP/MCP)
- MSCP-to-IOSUB中断: SCP and MCP group interrupts
- Destination sheets: Interrupt index mappings for each target
"""

import pandas as pd
import re
import argparse
from pathlib import Path
from typing import Dict, List, Tuple, Optional

# --- Mappings ---
GROUP_MAP = {
    "IOSUB中断源": "IOSUB",
    "USB中断源": "USB",
    "SCP中断源": "SCP",
    "MCP中断源": "MCP",
    "SMMU中断源": "SMMU",
    "IODAP中断源": "IODAP",
    "外部中断源-from ACCEL": "ACCEL",
    "外部中断源-from CSUB": "CSUB",
    "外部中断源-from PSUB": "PSUB",
    "外部中断源-from PCIE1": "PCIE1",
    "外部中断源-from D2D": "D2D",
    "外部中断源-from DDR0": "DDR0",
    "外部中断源-from DDR1": "DDR1",
    "外部中断源-from ddr2": "DDR2",
    # "外部中断源-from IO DIE": "IO_DIE"  # 移除IO DIE处理
}

TRIGGER_MAP = {
    "Level": "LEVEL",
    "Edge": "EDGE",
}

POLARITY_MAP = {
    "Active high": "ACTIVE_HIGH",
    "Active low": "ACTIVE_LOW",
    "Rising & Falling Edge": "RISING_FALLING",
}

# Sheet name mappings for destination lookup
DEST_SHEET_MAP = {
    'AP': 'iosub-to-AP中断列表',
    'SCP': 'SCP M7中断列表', 
    'MCP': 'MCP M7中断列表',
    'ACCEL': 'iosub-to-IMU中断列表',
    'IO': 'iosub-to-IO',
    'OTHER_DIE': '跨die中断列表'
}

class InterruptInfo:
    """Class to hold interrupt information with signal mapping."""
    def __init__(self, name: str, index: int, group: str, trigger: str, polarity: str):
        self.name = name
        self.index = index
        self.group = group
        self.trigger = trigger
        self.polarity = polarity
        self.destinations = {}  # dest_name -> (dest_index, signal_path)
        
    def add_destination(self, dest_name: str, dest_index: int, signal_path: str = ""):
        """Add destination mapping with signal path."""
        self.destinations[dest_name] = (dest_index, signal_path)
        
    def to_sv_entry(self) -> str:
        """Convert to SystemVerilog entry format."""
        # Build destination fields
        dest_fields = []
        for dest in ['AP', 'SCP', 'MCP', 'ACCEL', 'IO', 'OTHER_DIE']:
            if dest in self.destinations:
                dest_index, signal_path = self.destinations[dest]
                dest_fields.extend([
                    f"to_{dest.lower()}:1",
                    f"rtl_path_{dest.lower()}:\"{signal_path}\"",
                    f"dest_index_{dest.lower()}:{dest_index}"
                ])
            else:
                dest_fields.extend([
                    f"to_{dest.lower()}:0", 
                    f"rtl_path_{dest.lower()}:\"\"",
                    f"dest_index_{dest.lower()}:-1"
                ])
        
        entry_str = (
            f"        entry = '{{name:\"{self.name}\", "
            f"index:{self.index}, "
            f"group:{self.group}, "
            f"trigger:{self.trigger}, "
            f"polarity:{self.polarity}, "
            f"rtl_path_src:\"\", "
            f"{', '.join(dest_fields)}"
            "}; interrupt_map.push_back(entry);"
        )
        return entry_str

def parse_main_sheet(df: pd.DataFrame) -> Dict[str, InterruptInfo]:
    """Parse the main IOSUB中断源 sheet, excluding SCP and MCP groups."""
    interrupts = {}
    current_group = ""

    for idx, row in df.iterrows():
        # Check for group header first (before checking for empty interrupt name)
        if pd.notna(row['interrupt Source']) and pd.isna(row['sub index']):
            group_name = str(row['interrupt Source']).strip()
            if group_name in GROUP_MAP:
                current_group = GROUP_MAP[group_name]
                # Skip SCP and MCP groups - they will be processed from MSCP-to-IOSUB sheet
                if current_group in ['SCP', 'MCP']:
                    continue
            elif group_name == "外部中断源-from IO DIE":
                # 跳过IO DIE组的处理
                current_group = "SKIP_IO_DIE"
            continue

        # Skip empty rows
        if pd.isna(row['Interrupt Name']) or row['Interrupt Name'] == '':
            continue

        # Skip IO DIE group interrupts
        if current_group == "SKIP_IO_DIE":
            continue
            
        # Skip SCP and MCP group entries
        if current_group in ['SCP', 'MCP']:
            continue

        # Parse interrupt entry
        if pd.notna(row['Interrupt Name']) and pd.notna(row['sub index']):
            name = str(row['Interrupt Name']).strip()
            index = int(float(row['sub index']))

            # Sanitize name
            name_sanitized = re.sub(r'(\s*\[\d+:\d+\]\s*)|(\s*\[\d+\]\s*)', '', name).strip()
            name_sanitized = name_sanitized.replace(' ', '_')

            # Map trigger and polarity
            trigger_str = str(row['Trigger']).strip() if pd.notna(row['Trigger']) else ""
            polarity_str = str(row[' Polarity']).strip() if pd.notna(row[' Polarity']) else ""

            trigger = TRIGGER_MAP.get(trigger_str, "UNKNOWN_TRIGGER")
            if "Pulse" in trigger_str:
                trigger = "EDGE"
            polarity = POLARITY_MAP.get(polarity_str, "UNKNOWN_POLARITY")

            # Create interrupt info
            if not current_group:
                current_group = "UNKNOWN_GROUP"
            interrupt_info = InterruptInfo(name_sanitized, index, current_group, trigger, polarity)

            # Check routing destinations
            for dest_col, dest_name in [('to AP?', 'AP'), ('to SCP?', 'SCP'), ('to MCP?', 'MCP'),
                                       ('to IMU?', 'ACCEL'), ('to IO?', 'IO'), ('to other DIE?', 'OTHER_DIE')]:
                if pd.notna(row[dest_col]):
                    dest_val = str(row[dest_col]).upper()
                    # Only add destination if it's explicitly YES, not just Possible
                    if 'YES' in dest_val:
                        interrupt_info.add_destination(dest_name, -1)  # Will be filled later

            interrupts[name_sanitized] = interrupt_info

    return interrupts

def parse_mscp_sheet(df: pd.DataFrame) -> Dict[str, InterruptInfo]:
    """Parse the MSCP-to-IOSUB中断 sheet for SCP and MCP interrupt sources."""
    interrupts = {}
    current_group = ""

    for idx, row in df.iterrows():
        # Check for group header first (before checking for empty interrupt name)
        if pd.notna(row['interrupt Source']) and pd.isna(row['sub index']):
            group_name = str(row['interrupt Source']).strip()
            if group_name in GROUP_MAP:
                current_group = GROUP_MAP[group_name]
            continue

        # Skip empty rows
        if pd.isna(row['Interrupt Name']) or row['Interrupt Name'] == '':
            continue

        # Only process SCP and MCP groups
        if current_group not in ['SCP', 'MCP']:
            continue

        # Parse interrupt entry
        if pd.notna(row['Interrupt Name']) and pd.notna(row['sub index']):
            name = str(row['Interrupt Name']).strip()
            index = int(float(row['sub index']))

            # Sanitize name
            name_sanitized = re.sub(r'(\s*\[\d+:\d+\]\s*)|(\s*\[\d+\]\s*)', '', name).strip()
            name_sanitized = name_sanitized.replace(' ', '_')

            # Map trigger and polarity
            trigger_str = str(row['Trigger']).strip() if pd.notna(row['Trigger']) else ""
            polarity_str = str(row[' Polarity']).strip() if pd.notna(row[' Polarity']) else ""

            trigger = TRIGGER_MAP.get(trigger_str, "UNKNOWN_TRIGGER")
            if "Pulse" in trigger_str:
                trigger = "EDGE"
            polarity = POLARITY_MAP.get(polarity_str, "UNKNOWN_POLARITY")

            # Create interrupt info
            interrupt_info = InterruptInfo(name_sanitized, index, current_group, trigger, polarity)

            # Check routing destinations
            for dest_col, dest_name in [('to AP?', 'AP'), ('to SCP?', 'SCP'), ('to MCP?', 'MCP'),
                                       ('to IMU?', 'ACCEL'), ('to IO?', 'IO')]:
                if pd.notna(row[dest_col]):
                    dest_val = str(row[dest_col]).upper()
                    # Only add destination if it's explicitly YES, not just Possible
                    if 'YES' in dest_val:
                        interrupt_info.add_destination(dest_name, -1)  # Will be filled later

            interrupts[name_sanitized] = interrupt_info

    return interrupts

def parse_destination_sheet(df: pd.DataFrame, sheet_name: str) -> Dict[str, int]:
    """Parse destination sheet to get interrupt index mapping."""
    interrupt_indices = {}

    # Sheet-specific parsing logic based on observed structure
    if 'SCP M7' in sheet_name:
        # For SCP M7 sheet: index in column 1, name in column 2
        index_col = df.columns[1]  # 'SCP M7中断列表'
        name_col = df.columns[2]   # 'Unnamed: 2'

        for idx, row in df.iterrows():
            if pd.notna(row[name_col]) and pd.notna(row[index_col]):
                interrupt_name = str(row[name_col]).strip()
                try:
                    # Skip header rows and NMI entries
                    if interrupt_name.lower() in ['interrupt name', 'interrupt'] or str(row[index_col]).upper() == 'NMI':
                        continue
                    interrupt_index = int(float(row[index_col]))
                    interrupt_indices[interrupt_name] = interrupt_index
                except (ValueError, TypeError):
                    continue

    elif 'MCP M7' in sheet_name:
        # For MCP M7 sheet: index in column 1, name in column 2
        index_col = df.columns[1]  # 'MCP M7中断列表'
        name_col = df.columns[2]   # 'Unnamed: 2'

        for idx, row in df.iterrows():
            if pd.notna(row[name_col]) and pd.notna(row[index_col]):
                interrupt_name = str(row[name_col]).strip()
                try:
                    # Skip header rows and NMI entries
                    if interrupt_name.lower() in ['interrupt name', 'interrupt'] or str(row[index_col]).upper() == 'NMI':
                        continue
                    interrupt_index = int(float(row[index_col]))
                    interrupt_indices[interrupt_name] = interrupt_index
                except (ValueError, TypeError):
                    continue

    elif 'iosub-to-AP' in sheet_name:
        # For AP sheet: index in column 2, name in column 3
        index_col = df.columns[2]  # 'Unnamed: 2'
        name_col = df.columns[3]   # 'Unnamed: 3'

        for idx, row in df.iterrows():
            if pd.notna(row[name_col]) and pd.notna(row[index_col]):
                interrupt_name = str(row[name_col]).strip()
                try:
                    # Skip header rows
                    if interrupt_name.lower() in ['interrupt name', 'interrupt']:
                        continue
                    interrupt_index = int(float(row[index_col]))
                    interrupt_indices[interrupt_name] = interrupt_index
                except (ValueError, TypeError):
                    continue

    elif 'iosub-to-IMU' in sheet_name:
        # For IMU sheet: index in column 1, name in column 2
        index_col = df.columns[1]  # 'IOSUB TO IMU中断列表'
        name_col = df.columns[2]   # 'Unnamed: 2'

        for idx, row in df.iterrows():
            if pd.notna(row[name_col]) and pd.notna(row[index_col]):
                interrupt_name = str(row[name_col]).strip()
                try:
                    # Skip header rows
                    if interrupt_name.lower() in ['interrupt name', 'interrupt']:
                        continue
                    interrupt_index = int(float(row[index_col]))
                    interrupt_indices[interrupt_name] = interrupt_index
                except (ValueError, TypeError):
                    continue



    elif 'iosub-to-IO' in sheet_name:
        # For IO sheet: index in column 1, name in column 2
        index_col = df.columns[1]  # 'IOSUB TO IO中断列表'
        name_col = df.columns[2]   # 'Unnamed: 2'

        for idx, row in df.iterrows():
            if pd.notna(row[name_col]) and pd.notna(row[index_col]):
                interrupt_name = str(row[name_col]).strip()
                try:
                    # Skip header rows
                    if interrupt_name.lower() in ['interrupt name', 'interrupt']:
                        continue
                    interrupt_index = int(float(row[index_col]))
                    interrupt_indices[interrupt_name] = interrupt_index
                except (ValueError, TypeError):
                    continue

    elif '跨die' in sheet_name:
        # For cross-die sheet: index in column 1, name in column 2
        index_col = df.columns[1]  # '跨die中断列表'
        name_col = df.columns[2]   # 'Unnamed: 2'

        for idx, row in df.iterrows():
            if pd.notna(row[name_col]) and pd.notna(row[index_col]):
                interrupt_name = str(row[name_col]).strip()
                try:
                    # Skip header rows
                    if interrupt_name.lower() in ['interrupt name', 'interrupt']:
                        continue
                    interrupt_index = int(float(row[index_col]))
                    interrupt_indices[interrupt_name] = interrupt_index
                except (ValueError, TypeError):
                    continue

    else:
        # Generic parsing for other sheets
        # Try to find columns with interrupt names and indices
        interrupt_col = None
        index_col = None

        for col in df.columns:
            col_str = str(col).lower()
            sample_values = df[col].dropna().astype(str).head(10)

            # Look for interrupt name column
            if interrupt_col is None and any('intr' in val.lower() for val in sample_values):
                interrupt_col = col

            # Look for index column (numeric values)
            if index_col is None and df[col].dtype in ['int64', 'float64']:
                # Check if it contains reasonable index values
                numeric_values = df[col].dropna()
                if len(numeric_values) > 0 and numeric_values.min() >= 0 and numeric_values.max() < 1000:
                    index_col = col

        if interrupt_col is not None and index_col is not None:
            for idx, row in df.iterrows():
                if pd.notna(row[interrupt_col]) and pd.notna(row[index_col]):
                    interrupt_name = str(row[interrupt_col]).strip()
                    try:
                        interrupt_index = int(float(row[index_col]))
                        interrupt_indices[interrupt_name] = interrupt_index
                    except (ValueError, TypeError):
                        continue

    return interrupt_indices

def parse_interrupt_xlsx(input_path: str, output_path: str):
    """Parse the Excel file and generate SystemVerilog routing model."""
    try:
        # Read main sheet (excluding SCP and MCP groups)
        df_main = pd.read_excel(input_path, sheet_name='IOSUB中断源')
        interrupts = parse_main_sheet(df_main)

        print(f"Parsed {len(interrupts)} interrupts from IOSUB中断源 sheet (excluding SCP/MCP)")

        # Read MSCP-to-IOSUB sheet for SCP and MCP interrupts
        xl = pd.ExcelFile(input_path)
        if 'MSCP-to-IOSUB中断' in xl.sheet_names:
            print("Processing MSCP-to-IOSUB中断 sheet for SCP and MCP interrupts")
            df_mscp = pd.read_excel(input_path, sheet_name='MSCP-to-IOSUB中断')
            mscp_interrupts = parse_mscp_sheet(df_mscp)

            print(f"Parsed {len(mscp_interrupts)} SCP/MCP interrupts from MSCP-to-IOSUB中断 sheet")

            # Merge MSCP interrupts with main interrupts
            interrupts.update(mscp_interrupts)
            print(f"Total interrupts after merging: {len(interrupts)}")
        else:
            print("Warning: MSCP-to-IOSUB中断 sheet not found, SCP/MCP interrupts will be missing")

        # Read destination sheets and update interrupt mappings
        for dest_name, sheet_name in DEST_SHEET_MAP.items():
            if sheet_name in xl.sheet_names:
                print(f"Processing destination sheet: {sheet_name}")
                df_dest = pd.read_excel(input_path, sheet_name=sheet_name)
                dest_indices = parse_destination_sheet(df_dest, sheet_name)

                print(f"Found {len(dest_indices)} interrupt mappings in {sheet_name}")

                # Update interrupt destinations
                for interrupt_name, dest_index in dest_indices.items():
                    if interrupt_name in interrupts:
                        if dest_name in interrupts[interrupt_name].destinations:
                            # Update with actual destination index
                            signal_path = f"// {sheet_name}[{dest_index}]"
                            interrupts[interrupt_name].destinations[dest_name] = (dest_index, signal_path)

        # Generate SystemVerilog file
        generate_sv_file(interrupts, output_path, input_path)

    except Exception as e:
        print(f"Error processing Excel file: {e}")
        raise

def generate_sv_file(interrupts: Dict[str, InterruptInfo], output_path: str, input_path: str = "int_vector.xlsx"):
    """Generate SystemVerilog include file with build function content only."""
    sv_lines = [
        "// Auto-generated interrupt map entries from Excel file",
        f"// Source: {input_path}",
        f"// Generated by: convert_xlsx_to_sv.py",
        "// NOTE: This file is included in int_routing_model.sv",
        ""
    ]
    
    # Group interrupts by their group
    grouped_interrupts = {}
    for interrupt in interrupts.values():
        group_name = interrupt.group if interrupt.group else "UNKNOWN_GROUP"
        if group_name not in grouped_interrupts:
            grouped_interrupts[group_name] = []
        grouped_interrupts[group_name].append(interrupt)

    # Generate entries grouped by interrupt group (without function wrapper)
    for group_name, group_interrupts in grouped_interrupts.items():
        # Skip IO_DIE group
        if group_name == "IO_DIE":
            continue

        sv_lines.append(f"        // --- Start of {group_name} interrupts ---")

        # Sort by index
        group_interrupts.sort(key=lambda x: x.index)

        for interrupt in group_interrupts:
            sv_lines.append(interrupt.to_sv_entry())

        sv_lines.append("")
    
    # Write to file
    with open(output_path, 'w', encoding='utf-8') as svfile:
        svfile.write("\n".join(sv_lines))
    
    print(f"Successfully converted '{input_path}' to '{output_path}'")
    print(f"Generated {len(interrupts)} interrupt entries")

if __name__ == "__main__":
    parser = argparse.ArgumentParser(
        description="Convert interrupt Excel file to SystemVerilog routing model.",
        formatter_class=argparse.RawTextHelpFormatter
    )
    parser.add_argument("xlsx_file", help="Path to the input Excel file (e.g., 'int_vector.xlsx')")
    parser.add_argument(
        "-o", "--output",
        default="seq/int_map_entries.svh",
        help="Path for the output SystemVerilog include file.\n(default: 'seq/int_map_entries.svh')"
    )
    args = parser.parse_args()
    
    # Ensure output directory exists
    output_path = Path(args.output)
    output_path.parent.mkdir(parents=True, exist_ok=True)
    
    parse_interrupt_xlsx(args.xlsx_file, output_path)
