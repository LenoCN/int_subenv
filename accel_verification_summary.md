# ACCEL Interrupt RTL Path Generation - Verification Summary

## Requirements Implementation Status ✅

Based on the user requirements:
1. **ACCEL has 19 interrupts in Excel** ❌ → **Actually has 20 interrupts (sub_index 0-19)** ✅
2. **All interrupt sources use hierarchy**: `top_tb.multidie_top.DUT[0].u_str_top.u_iosub_top_wrap` ✅
3. **4 MHU-related interrupts use individual signal names** ✅
4. **15 other interrupts use `accel_to_iosub_intr` with bit mapping `sub_index-5`** ✅

## Actual Implementation

### MHU-Related Interrupts (4 interrupts)
These use individual signal names at `iosub_int_sub` level:

| Sub Index | Interrupt Name | RTL Path |
|-----------|----------------|----------|
| 0 | `accel_iosub_scp2imu_mhu_send_intr` | `top_tb.multidie_top.DUT[0].u_str_top.u_iosub_top_wrap.u0_iosub_top_wrap_hd.u0_iosub_top_wrap_raw.u_iosub_int_sub.accel_iosub_scp2imu_mhu_send_intr` |
| 1 | `accel_iosub_imu2scp_mhu_receive_intr` | `top_tb.multidie_top.DUT[0].u_str_top.u_iosub_top_wrap.u0_iosub_top_wrap_hd.u0_iosub_top_wrap_raw.u_iosub_int_sub.accel_iosub_imu2scp_mhu_receive_intr` |
| 3 | `accel_iosub_mcp2imu_mhu_send_intr` | `top_tb.multidie_top.DUT[0].u_str_top.u_iosub_top_wrap.u0_iosub_top_wrap_hd.u0_iosub_top_wrap_raw.u_iosub_int_sub.accel_iosub_mcp2imu_mhu_send_intr` |
| 4 | `accel_iosub_imu2mcp_mhu_receive_intr` | `top_tb.multidie_top.DUT[0].u_str_top.u_iosub_top_wrap.u0_iosub_top_wrap_hd.u0_iosub_top_wrap_raw.u_iosub_int_sub.accel_iosub_imu2mcp_mhu_receive_intr` |

### Special Case: IMU WS1 Interrupt (1 interrupt)
This uses individual signal name at top level:

| Sub Index | Interrupt Name | RTL Path |
|-----------|----------------|----------|
| 2 | `accel_iosub_imu_ws1_intr` | `top_tb.multidie_top.DUT[0].u_str_top.u_iosub_top_wrap.accel_iosub_imu_ws1_intr` |

### Other ACCEL Interrupts (15 interrupts)
These use `accel_to_iosub_intr[bit_index]` where `bit_index = sub_index - 5`:

| Sub Index | Bit Index | Interrupt Name | RTL Path |
|-----------|-----------|----------------|----------|
| 5 | 0 | `accel_ras_cri_intr` | `top_tb.multidie_top.DUT[0].u_str_top.u_iosub_top_wrap.accel_to_iosub_intr[0]` |
| 6 | 1 | `accel_ras_eri_intr` | `top_tb.multidie_top.DUT[0].u_str_top.u_iosub_top_wrap.accel_to_iosub_intr[1]` |
| 7 | 2 | `accel_ras_fhi_intr` | `top_tb.multidie_top.DUT[0].u_str_top.u_iosub_top_wrap.accel_to_iosub_intr[2]` |
| 8 | 3 | `accel_normal0_intr` | `top_tb.multidie_top.DUT[0].u_str_top.u_iosub_top_wrap.accel_to_iosub_intr[3]` |
| 9 | 4 | `accel_normal1_intr` | `top_tb.multidie_top.DUT[0].u_str_top.u_iosub_top_wrap.accel_to_iosub_intr[4]` |
| 10 | 5 | `accel_normal2_intr` | `top_tb.multidie_top.DUT[0].u_str_top.u_iosub_top_wrap.accel_to_iosub_intr[5]` |
| 11 | 6 | `accel_normal3_intr` | `top_tb.multidie_top.DUT[0].u_str_top.u_iosub_top_wrap.accel_to_iosub_intr[6]` |
| 12 | 7 | `accel_abnormal0_intr` | `top_tb.multidie_top.DUT[0].u_str_top.u_iosub_top_wrap.accel_to_iosub_intr[7]` |
| 13 | 8 | `accel_abnormal1_intr` | `top_tb.multidie_top.DUT[0].u_str_top.u_iosub_top_wrap.accel_to_iosub_intr[8]` |
| 14 | 9 | `accel_abnormal2_intr` | `top_tb.multidie_top.DUT[0].u_str_top.u_iosub_top_wrap.accel_to_iosub_intr[9]` |
| 15 | 10 | `accel_abnormal3_intr` | `top_tb.multidie_top.DUT[0].u_str_top.u_iosub_top_wrap.accel_to_iosub_intr[10]` |
| 16 | 11 | `accel_abnormal4_intr` | `top_tb.multidie_top.DUT[0].u_str_top.u_iosub_top_wrap.accel_to_iosub_intr[11]` |
| 17 | 12 | `accel_abnormal5_intr` | `top_tb.multidie_top.DUT[0].u_str_top.u_iosub_top_wrap.accel_to_iosub_intr[12]` |
| 18 | 13 | `accel_pll_lock_intr` | `top_tb.multidie_top.DUT[0].u_str_top.u_iosub_top_wrap.accel_to_iosub_intr[13]` |
| 19 | 14 | `accel_pll_unlock_intr` | `top_tb.multidie_top.DUT[0].u_str_top.u_iosub_top_wrap.accel_to_iosub_intr[14]` |

## Signal Width Configuration
- `accel_to_iosub_intr`: 15 bits [14:0] - for sub_index 5-19 (15 interrupts)

## Files Modified
1. **`tools/generate_signal_paths.py`**:
   - Added `_generate_accel_source_path()` helper method
   - Updated `generate_source_path()` to call ACCEL-specific logic
   - Updated signal width comment for `accel_to_iosub_intr`

2. **`config/hierarchy_config.json`**:
   - Updated ACCEL configuration with correct interrupt count (20 total)
   - Updated special signals mapping
   - Updated special hierarchy mapping
   - Added descriptive comment

## Verification Status
✅ All 20 ACCEL interrupts correctly mapped
✅ MHU interrupts use individual signal names at iosub_int_sub level
✅ IMU WS1 interrupt uses individual signal name at top level  
✅ Other interrupts use accel_to_iosub_intr with correct bit indexing
✅ All paths use the correct hierarchy base
✅ RTL path generation completed successfully
