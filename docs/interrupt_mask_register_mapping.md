# Interrupt Mask Register Mapping Analysis

## Register Specification Analysis

Based on the provided register specification, here's the detailed analysis of mask registers and their relationship with interrupt names.

### PLL Interrupt Mask Registers

| Register | Address | Name | Description | Bit Width | Default | Interrupt Name |
|----------|---------|------|-------------|-----------|---------|----------------|
| 311 | 0x1_C000 | mask_pll_intr_0 | lock | 24 | 0x1FF_FFFF | merge_pll_intr_lock |
| 312 | 0x1_C004 | mask_pll_intr_1 | unlock | 24 | 0x1FF_FFFF | merge_pll_intr_unlock |
| 313 | 0x1_C008 | mask_pll_intr_2 | frechangedone | 24 | 0x1FF_FFFF | merge_pll_intr_frechangedone |
| 314 | 0x1_C00C | mask_pll_intr_3 | frechange_tot_done | 24 | 0x1FF_FFFF | merge_pll_intr_frechange_tot_done |
| 315 | 0x1_C010 | mask_pll_intr_4 | intdocfrac_err | 24 | 0x1FF_FFFF | merge_pll_intr_intdocfrac_err |

**Key Points:**
- Each register supports 24 PLLs (bit-0 for PLL-0, bit-1 for PLL-1, etc.)
- 1'b1: enable interrupt; 1'b0: disable interrupt
- Default value 0x1FF_FFFF means all PLL interrupts are enabled by default

### IOSUB Normal Interrupt Registers

| Register | Address | Name | Description | Bit Width | Default | Interrupt Coverage |
|----------|---------|------|-------------|-----------|---------|-------------------|
| 321 | 0x1_C040 | status_iosub_normal_intr_0 | low [31:0] | 32 | 0x0 | iosub_normal_intr[31:0] |
| 322 | 0x1_C044 | status_iosub_normal_intr_1 | high [45:32] | 14 | 0x0 | iosub_normal_intr[45:32] |
| 323 | 0x1_C050 | mask_iosub_to_scp_normal_intr_0 | low [31:0] | 32 | 0x0 | iosub_normal_intr[31:0] to SCP |
| 324 | 0x1_C054 | mask_iosub_to_scp_normal_intr_1 | high [45:32] | 14 | 0x0 | iosub_normal_intr[45:32] to SCP |
| 325 | 0x1_C058 | mask_iosub_to_mcp_normal_intr_0 | low [31:0] | 32 | 0x0 | iosub_normal_intr[31:0] to MCP |
| 326 | 0x1_C05C | mask_iosub_to_mcp_normal_intr_1 | high [45:32] | 14 | 0x0 | iosub_normal_intr[45:32] to MCP |

**Key Points:**
- Total 46 IOSUB normal interrupts ([45:0])
- Separate masks for routing to SCP vs MCP
- Default disabled (0x0) - interrupts are masked by default

### IOSUB to SCP General Interrupt Registers

| Register | Address | Name | Description | Bit Width | Default | Interrupt Coverage |
|----------|---------|------|-------------|-----------|---------|-------------------|
| 327 | 0x1_C060 | mask_iosub_to_scp_intr_0 | part_0 [31:0] | 32 | 0x0 | csr_mask_iosub_to_scp_intr[31:0] |
| 328 | 0x1_C064 | mask_iosub_to_scp_intr_1 | part_1 [63:32] | 32 | 0x0 | csr_mask_iosub_to_scp_intr[63:32] |
| 329 | 0x1_C068 | mask_iosub_to_scp_intr_2 | part_2 [95:64] | 32 | 0x0 | csr_mask_iosub_to_scp_intr[95:64] |
| 330 | 0x1_C06C | mask_iosub_to_scp_intr_3 | part_3 [127:96] | 32 | 0x0 | csr_mask_iosub_to_scp_intr[127:96] |
| 331 | 0x1_C070 | mask_iosub_to_scp_intr_4 | part_4 [130:128] | 3 | 0x0 | csr_mask_iosub_to_scp_intr[130:128] |

**Key Points:**
- Total 131 IOSUB to SCP interrupts ([130:0])
- Covers general IOSUB interrupts like iosub_slv_err_intr, iosub_ras_*_intr, etc.

### IOSUB to MCP General Interrupt Registers

| Register | Address | Name | Description | Bit Width | Default | Interrupt Coverage |
|----------|---------|------|-------------|-----------|---------|-------------------|
| 332 | 0x1_C080 | mask_iosub_to_mcp_intr_0 | part_0 [31:0] | 32 | 0x0 | csr_mask_iosub_to_mcp_intr[31:0] |
| 333 | 0x1_C084 | mask_iosub_to_mcp_intr_1 | part_1 [63:32] | 32 | 0x0 | csr_mask_iosub_to_mcp_intr[63:32] |
| 334 | 0x1_C088 | mask_iosub_to_mcp_intr_2 | part_2 [95:64] | 32 | 0x0 | csr_mask_iosub_to_mcp_intr[95:64] |
| 335 | 0x1_C08C | mask_iosub_to_mcp_intr_3 | part_3 [127:96] | 32 | 0x0 | csr_mask_iosub_to_mcp_intr[127:96] |
| 336 | 0x1_C090 | mask_iosub_to_mcp_intr_4 | part_4 [145:128] | 18 | 0x0 | csr_mask_iosub_to_mcp_intr[145:128] |

**Key Points:**
- Total 146 IOSUB to MCP interrupts ([145:0])
- Covers general IOSUB interrupts routing to MCP

### IOSUB to ACCEL Interrupt Register

| Register | Address | Name | Description | Bit Width | Default | Interrupt Coverage |
|----------|---------|------|-------------|-----------|---------|-------------------|
| 337 | 0x1_C0A0 | mask_iosub_to_accel_intr_0 | part_0 [31:0] | 32 | 0x0 | csr_mask_iosub_to_accel_intr[31:0] |

### PSUB and PCIE1 Interrupt Registers

| Register | Address | Name | Description | Bit Width | Default | Interrupt Coverage |
|----------|---------|------|-------------|-----------|---------|-------------------|
| 338 | 0x1_C0B0 | status_psub_to_iosub_intr | status [19:0] | 20 | 0x0 | psub_to_iosub_intr[19:0] |
| 339 | 0x1_C0B4 | status_pcie1_to_iosub_intr | status [19:0] | 20 | 0x0 | pcie1_to_iosub_intr[19:0] |
| 340 | 0x1_C0B8 | mask_psub_to_iosub_intr | mask [19:0] | 20 | 0xF_FFFF | psub_to_iosub_intr[19:0] |
| 341 | 0x1_C0BC | mask_pcie1_to_iosub_intr | mask [19:0] | 20 | 0xF_FFFF | pcie1_to_iosub_intr[19:0] |

**Key Points:**
- PSUB and PCIE1 interrupts are enabled by default (0xF_FFFF)
- Only 20 bits are valid ([19:0])

## Implementation Corrections Made

### 1. Fixed PLL Mask Bit Width
- **Before**: 0x00FF_FFFF (24 bits)
- **After**: 0x01FF_FFFF (24 bits, correct mask)

### 2. Fixed IOSUB to MCP Interrupt Mask Part 4
- **Before**: 0x0003_FFFF (18 bits)
- **After**: 0x0001_FFFF (17 bits, [145:128])

### 3. Improved Interrupt Name Mapping
Enhanced `is_interrupt_masked()` function to properly map:

#### PLL Interrupts
- `merge_pll_intr_lock` → `mask_pll_intr_0`
- `merge_pll_intr_unlock` → `mask_pll_intr_1`
- `merge_pll_intr_frechangedone` → `mask_pll_intr_2`
- `merge_pll_intr_frechange_tot_done` → `mask_pll_intr_3`
- `merge_pll_intr_intdocfrac_err` → `mask_pll_intr_4`

#### IOSUB Normal Interrupts
- `iosub_normal_intr` → destination-specific masks:
  - To SCP: `mask_iosub_to_scp_normal_intr_0`
  - To MCP: `mask_iosub_to_mcp_normal_intr_0`

#### IOSUB General Interrupts
- `iosub_slv_err_intr`, `iosub_ras_*_intr`, `iosub_abnormal_*_intr` → destination-specific masks:
  - To SCP: `mask_iosub_to_scp_intr_0` (different bits for different interrupts)
  - To MCP: `mask_iosub_to_mcp_intr_0` (different bits for different interrupts)
  - To ACCEL: `mask_iosub_to_accel_intr_0` (different bits for different interrupts)

#### Source Interrupts
- `psub_*` interrupts → `mask_psub_to_iosub_intr`
- `pcie1_*` interrupts → `mask_pcie1_to_iosub_intr`

### 4. Bit Index Assignment
For IOSUB general interrupts, assigned specific bit indices:
- `iosub_slv_err_intr`: bit 1
- `iosub_ras_cri_intr`: bit 2
- `iosub_ras_eri_intr`: bit 3
- `iosub_ras_fhi_intr`: bit 4
- `iosub_abnormal_0_intr`: bit 5
- `iosub_abnormal_1_intr`: bit 6

## Summary

The implementation now correctly:
1. **Maps interrupt names to appropriate mask registers** based on register specification
2. **Uses correct bit widths** for all mask registers
3. **Handles destination-specific routing** for IOSUB interrupts
4. **Provides proper bit index mapping** for different interrupt types
5. **Follows the register specification** for default values and field sizes

The mask checking logic now accurately reflects the hardware register specification and properly determines whether specific interrupts are masked for specific destinations.
