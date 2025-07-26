# Interrupt Mask and Status Register Functionality

## Overview

This document describes the interrupt mask configuration and status checking functionality that has been integrated into the interrupt verification environment. This functionality is now **automatically enabled for all test cases** and provides:

1. **Automatic mask register randomization** at test initialization (in `pre_reset_phase`)
2. **Mask-aware interrupt prediction** in all routing checks
3. **Automatic status register checking** at test completion (in `post_shutdown_phase`)

## Integration Approach

The functionality has been integrated into the **base verification components** rather than separate sequences, ensuring that **all test cases automatically benefit** from mask and status functionality without any code changes.

## Key Components

### 1. Register Model (`seq/int_register_model.sv`)

The register model provides a comprehensive software model of the interrupt mask and status registers based on the hardware specification.

#### Key Features:
- **Register Definitions**: All mask and status register addresses from the specification
- **Register Access**: Read/write functions for all registers
- **Mask Checking**: Functions to determine if specific interrupts are masked
- **Status Updates**: Functions to update status registers when interrupts occur
- **Automatic Randomization**: Randomizes mask values for test variety

#### Register Types Supported:
- **PLL Interrupt Masks**: `mask_pll_intr_0` through `mask_pll_intr_4`
- **IOSUB Interrupt Masks**: Various IOSUB to SCP/MCP/ACCEL mask registers
- **PSUB/PCIE1 Masks**: `mask_psub_to_iosub_intr`, `mask_pcie1_to_iosub_intr`
- **Status Registers**: Corresponding status registers for all interrupt types
- **Configuration Registers**: `accel_uart_sel`, `accel_dma_ch_sel`, etc.

### 2. Enhanced Test Base (`test/int_tc_base.sv`)

The base test class now automatically handles mask and status functionality:

#### Automatic Features:
- **`pre_reset_phase()`**: Initializes and randomizes all mask registers
- **`post_shutdown_phase()`**: Checks all status registers at test completion
- **Detailed Logging**: Prints mask configuration and status check results

### 3. Enhanced Routing Model (`seq/int_routing_model.sv`)

The routing model has been enhanced with mask-aware prediction functions.

#### New Functions:
- **`predict_interrupt_routing_with_mask()`**: Predicts if interrupt will be routed considering masks
- **`get_expected_destinations_with_mask()`**: Gets list of expected destinations after mask filtering
- **`print_routing_prediction_with_mask()`**: Prints detailed routing prediction with mask info
- **`update_interrupt_status()`**: Updates status registers when interrupts occur

### 4. Enhanced Base Sequence (`seq/int_base_sequence.sv`)

Added mask-aware expectation registration.

#### New Function:
- **`add_expected_with_mask()`**: Registers expectations only for unmasked destinations

### 5. Enhanced Lightweight Sequence (`seq/int_lightweight_sequence.sv`)

The main interrupt testing sequence now uses mask-aware prediction:

#### Automatic Features:
- **Mask-Aware Expectations**: Uses `add_expected_with_mask()` instead of `add_expected()`
- **Status Updates**: Automatically updates status registers when interrupts are triggered
- **Merge Interrupt Support**: Handles mask consideration for merge interrupts

## Register Specification Mapping

The implementation maps to the following register specification:

| Register Name | Address | Type | Description |
|---------------|---------|------|-------------|
| `mask_pll_intr_0` | 0x1_C000 | RW | PLL lock interrupt mask (24-bit) |
| `mask_pll_intr_1` | 0x1_C004 | RW | PLL unlock interrupt mask (24-bit) |
| `mask_pll_intr_2` | 0x1_C008 | RW | PLL frechangedone mask (24-bit) |
| `mask_pll_intr_3` | 0x1_C00C | RW | PLL frechange_tot_done mask (24-bit) |
| `mask_pll_intr_4` | 0x1_C010 | RW | PLL intdocfrac_err mask (24-bit) |
| `status_pll_intr_0` | 0x1_C020 | RO | PLL lock status (24-bit) |
| `status_pll_intr_1` | 0x1_C024 | RO | PLL unlock status (24-bit) |
| ... | ... | ... | ... |

*Note: See register specification for complete list of 30+ registers*

## Test Cases

### 1. Comprehensive Test (`test/tc_mask_and_status_test.sv`)

A comprehensive test case that demonstrates all mask and status functionality:

- **Mask Configuration**: Tests different mask configuration modes
- **Interrupt Testing**: Tests interrupts with various mask configurations
- **Status Verification**: Verifies status registers match expected values
- **Multiple Scenarios**: Tests enable_all, disable_all, and random configurations

### 2. Simple Example (`test/tc_mask_example.sv`)

A simple example showing basic usage:

- **Basic Configuration**: Sets specific mask values for demonstration
- **Prediction Demo**: Shows how mask-aware prediction works
- **Status Reading**: Demonstrates status register reading

## Automatic Workflow

The functionality is now **completely automatic** and requires **no code changes** to existing tests:

### 1. Test Initialization (Automatic)
```systemverilog
// This happens automatically in int_tc_base::pre_reset_phase()
int_register_model::init_registers();           // Initialize register model
int_register_model::randomize_mask_registers(); // Randomize all masks
int_register_model::print_register_config();    // Print configuration
```

### 2. Interrupt Testing (Automatic)
```systemverilog
// This happens automatically in int_lightweight_sequence
add_expected_with_mask(interrupt_info);         // Only expect unmasked destinations
// ... stimulus and detection ...
int_routing_model::update_interrupt_status();   // Update status registers
```

### 3. Status Checking (Automatic)
```systemverilog
// This happens automatically in int_tc_base::post_shutdown_phase()
check_interrupt_status_registers();             // Check all status registers
int_register_model::print_status_registers();   // Print final status
```

## Zero-Code Integration

The new functionality provides **complete backward compatibility**:

1. **✅ Existing tests work unchanged** - No code modifications required
2. **✅ Automatic mask randomization** - Happens in base test class
3. **✅ Automatic mask-aware prediction** - Integrated into routing sequence
4. **✅ Automatic status checking** - Happens at test completion
5. **✅ All test cases benefit** - Functionality is in base components

## Benefits

1. **Realistic Testing**: Tests now consider actual hardware mask behavior
2. **Better Coverage**: Random mask configurations increase test variety
3. **Verification Completeness**: Status register checking ensures end-to-end verification
4. **Debug Support**: Detailed logging helps debug mask-related issues
5. **Scalability**: Easy to extend for additional register types

## Future Enhancements

1. **Hardware Integration**: Connect to actual DUT register interface
2. **Advanced Patterns**: Support for complex mask patterns and sequences
3. **Performance Testing**: Test mask configuration performance impact
4. **Coverage Enhancement**: Add functional coverage for mask configurations
5. **Automated Validation**: Automatic validation of mask vs routing consistency

## Running the Tests

```bash
# Run the comprehensive mask and status test
make test TEST=tc_mask_and_status_test

# Run the simple example
make test TEST=tc_mask_example

# Run with specific mask mode
make test TEST=tc_mask_and_status_test MASK_MODE=enable_all
```

## Debugging

The implementation includes extensive logging:

- **Register Configuration**: Detailed logs of mask register values
- **Routing Prediction**: Step-by-step routing decisions with mask consideration
- **Status Checking**: Detailed comparison of expected vs actual status
- **Mismatch Reporting**: Specific information about any discrepancies

## Running Tests

All existing tests now automatically include mask and status functionality:

```bash
# Run the main interrupt routing test with automatic mask/status functionality
make test TEST=tc_int_routing

# Use high verbosity to see detailed mask and status logging
make test TEST=tc_int_routing UVM_VERBOSITY=UVM_HIGH
```

## Summary of Changes

The mask and status functionality has been **fully integrated** into the base verification components:

### ✅ **Automatic Integration Points**

1. **`int_tc_base::pre_reset_phase()`** - Initializes and randomizes mask registers
2. **`int_lightweight_sequence`** - Uses mask-aware prediction and status updates
3. **`int_tc_base::post_shutdown_phase()`** - Checks status registers at completion
4. **`int_base_sequence::add_expected_with_mask()`** - Mask-aware expectation registration

### ✅ **Zero Code Changes Required**

- **All existing tests** automatically benefit from the new functionality
- **No sequence modifications** needed
- **No test case changes** required
- **Backward compatibility** maintained

### ✅ **Complete Coverage**

- **Random mask configuration** at every test start
- **Mask-aware interrupt prediction** for all routing checks
- **Automatic status verification** at every test completion
- **Detailed logging** for debugging and analysis
