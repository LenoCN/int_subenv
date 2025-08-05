`ifndef INT_REGISTER_MODEL_SV
`define INT_REGISTER_MODEL_SV

// Hardware register model for interrupt mask and status registers
// Uses reg_seq for actual hardware access like tc_int_sanity.sv
typedef class int_routing_model;
class int_register_model extends uvm_object;
    `uvm_object_utils(int_register_model)

    // Register address definitions
    typedef enum logic [31:0] {
        // PLL interrupt mask registers
        ADDR_MASK_PLL_INTR_0    = 32'h0001_C000,  // lock
        ADDR_MASK_PLL_INTR_1    = 32'h0001_C004,  // unlock
        ADDR_MASK_PLL_INTR_2    = 32'h0001_C008,  // frechangedone
        ADDR_MASK_PLL_INTR_3    = 32'h0001_C00C,  // frechange_tot_done
        ADDR_MASK_PLL_INTR_4    = 32'h0001_C010,  // intdocfrac_err

        // PLL interrupt status registers
        ADDR_STATUS_PLL_INTR_0  = 32'h0001_C020,  // lock
        ADDR_STATUS_PLL_INTR_1  = 32'h0001_C024,  // unlock
        ADDR_STATUS_PLL_INTR_2  = 32'h0001_C028,  // frechangedone
        ADDR_STATUS_PLL_INTR_3  = 32'h0001_C02C,  // frechange_tot_done
        ADDR_STATUS_PLL_INTR_4  = 32'h0001_C030,  // intdocfrac_err

        // IOSUB normal interrupt status registers
        ADDR_STATUS_IOSUB_NORMAL_INTR_0 = 32'h0001_C040,  // low [31:0]
        ADDR_STATUS_IOSUB_NORMAL_INTR_1 = 32'h0001_C044,  // high [45:32]

        // IOSUB to SCP normal interrupt mask registers
        ADDR_MASK_IOSUB_TO_SCP_NORMAL_INTR_0 = 32'h0001_C050,  // low [31:0]
        ADDR_MASK_IOSUB_TO_SCP_NORMAL_INTR_1 = 32'h0001_C054,  // high [45:32]

        // IOSUB to MCP normal interrupt mask registers
        ADDR_MASK_IOSUB_TO_MCP_NORMAL_INTR_0 = 32'h0001_C058,  // low [31:0]
        ADDR_MASK_IOSUB_TO_MCP_NORMAL_INTR_1 = 32'h0001_C05C,  // high [45:32]

        // IOSUB to SCP interrupt mask registers (5 parts)
        ADDR_MASK_IOSUB_TO_SCP_INTR_0 = 32'h0001_C060,  // [31:0]
        ADDR_MASK_IOSUB_TO_SCP_INTR_1 = 32'h0001_C064,  // [63:32]
        ADDR_MASK_IOSUB_TO_SCP_INTR_2 = 32'h0001_C068,  // [95:64]
        ADDR_MASK_IOSUB_TO_SCP_INTR_3 = 32'h0001_C06C,  // [127:96]
        ADDR_MASK_IOSUB_TO_SCP_INTR_4 = 32'h0001_C070,  // [130:128]

        // IOSUB to MCP interrupt mask registers (5 parts)
        ADDR_MASK_IOSUB_TO_MCP_INTR_0 = 32'h0001_C080,  // [31:0]
        ADDR_MASK_IOSUB_TO_MCP_INTR_1 = 32'h0001_C084,  // [63:32]
        ADDR_MASK_IOSUB_TO_MCP_INTR_2 = 32'h0001_C088,  // [95:64]
        ADDR_MASK_IOSUB_TO_MCP_INTR_3 = 32'h0001_C08C,  // [127:96]
        ADDR_MASK_IOSUB_TO_MCP_INTR_4 = 32'h0001_C090,  // [145:128]

        // IOSUB to ACCEL interrupt mask register
        ADDR_MASK_IOSUB_TO_ACCEL_INTR_0 = 32'h0001_C0A0,  // [31:0]

        // PSUB and PCIE1 status registers
        ADDR_STATUS_PSUB_TO_IOSUB_INTR  = 32'h0001_C0B0,  // [19:0]
        ADDR_STATUS_PCIE1_TO_IOSUB_INTR = 32'h0001_C0B4,  // [19:0]

        // PSUB and PCIE1 mask registers
        ADDR_MASK_PSUB_TO_IOSUB_INTR    = 32'h0001_C0B8,  // [19:0]
        ADDR_MASK_PCIE1_TO_IOSUB_INTR   = 32'h0001_C0BC,  // [19:0]

        // Configuration registers
        ADDR_ACCEL_UART_SEL     = 32'h0001_C0C0,
        ADDR_ACCEL_DMA_CH_SEL   = 32'h0001_C0C4,

        // Hardware lock register
        ADDR_HW_LOCK_NONSEC     = 32'h0001_D000
    } register_addr_e;

    // Instance variables to store register base address and current mask values
    bit[63:0] interrupt_reg_base;
    logic [31:0] current_mask_values[logic [31:0]];  // Cache for mask values

    // Constructor
    function new(string name = "int_register_model");
        super.new(name);
    endfunction

    // Initialize register base address using memory_map (like tc_int_sanity.sv)
    task init_registers();
        // Get interrupt register base address from memory map
        // This follows the same pattern as tc_int_sanity.sv
        interrupt_reg_base = memory_map.get_start_addr("iosub_sysctrl", soc_vargs::main_core);
        `uvm_info("INT_REG_MODEL", $sformatf("Interrupt register base address: 0x%016x", interrupt_reg_base), UVM_MEDIUM)

        // Clear the mask value cache
        current_mask_values.delete();

        `uvm_info("INT_REG_MODEL", "Hardware register model initialized", UVM_MEDIUM)
    endtask
    // Write to hardware register using reg_seq (like tc_int_sanity.sv)
    task write_register(logic [31:0] addr, logic [31:0] data);
        logic [63:0] full_addr;
        full_addr = interrupt_reg_base + addr;

        `uvm_info("INT_REG_MODEL", $sformatf("Writing hardware register: addr=0x%08x, full_addr=0x%016x, data=0x%08x",
                  addr, full_addr, data), UVM_HIGH)

        // Use reg_seq to write to actual hardware (like tc_int_sanity.sv)
        reg_seq.write_reg(full_addr, data);

        // Cache the written value for mask checking
        current_mask_values[addr] = data;
    endtask

    // Read from hardware register using reg_seq (like tc_int_sanity.sv)
    task read_register(logic [31:0] addr, output logic [31:0] data);
        logic [63:0] full_addr;
        full_addr = interrupt_reg_base + addr;

        // Use reg_seq to read from actual hardware (like tc_int_sanity.sv)
        reg_seq.read_reg(full_addr, data);

        `uvm_info("INT_REG_MODEL", $sformatf("Read hardware register: addr=0x%08x, full_addr=0x%016x, data=0x%08x",
                  addr, full_addr, data), UVM_HIGH)
    endtask

    // Randomize mask registers for test initialization
    task randomize_mask_registers();
        logic [31:0] random_value;

        `uvm_info("INT_REG_MODEL", "Randomizing interrupt mask registers...", UVM_MEDIUM)

        // Randomize PLL interrupt masks (24-bit fields, default 0x1FF_FFFF)
        random_value = $urandom() & 32'h01FF_FFFF;  // 24-bit mask for 24 PLLs
        write_register(ADDR_MASK_PLL_INTR_0, random_value);

        random_value = $urandom() & 32'h01FF_FFFF;  // 24-bit mask for 24 PLLs
        write_register(ADDR_MASK_PLL_INTR_1, random_value);

        random_value = $urandom() & 32'h01FF_FFFF;  // 24-bit mask for 24 PLLs
        write_register(ADDR_MASK_PLL_INTR_2, random_value);

        random_value = $urandom() & 32'h01FF_FFFF;  // 24-bit mask for 24 PLLs
        write_register(ADDR_MASK_PLL_INTR_3, random_value);

        random_value = $urandom() & 32'h01FF_FFFF;  // 24-bit mask for 24 PLLs
        write_register(ADDR_MASK_PLL_INTR_4, random_value);

        // Randomize IOSUB to SCP normal interrupt masks
        random_value = $urandom();
        write_register(ADDR_MASK_IOSUB_TO_SCP_NORMAL_INTR_0, random_value);

        random_value = $urandom() & 32'h0000_3FFF; // [13:0] valid
        write_register(ADDR_MASK_IOSUB_TO_SCP_NORMAL_INTR_1, random_value);

        // Randomize IOSUB to MCP normal interrupt masks
        random_value = $urandom();
        write_register(ADDR_MASK_IOSUB_TO_MCP_NORMAL_INTR_0, random_value);

        random_value = $urandom() & 32'h0000_3FFF; // [13:0] valid
        write_register(ADDR_MASK_IOSUB_TO_MCP_NORMAL_INTR_1, random_value);

        // Randomize IOSUB to SCP interrupt masks
        random_value = $urandom();
        write_register(ADDR_MASK_IOSUB_TO_SCP_INTR_0, random_value);

        random_value = $urandom();
        write_register(ADDR_MASK_IOSUB_TO_SCP_INTR_1, random_value);

        random_value = $urandom();
        write_register(ADDR_MASK_IOSUB_TO_SCP_INTR_2, random_value);

        random_value = $urandom();
        write_register(ADDR_MASK_IOSUB_TO_SCP_INTR_3, random_value);

        random_value = $urandom() & 32'h0000_0007; // [130:128] = 3 bits valid
        write_register(ADDR_MASK_IOSUB_TO_SCP_INTR_4, random_value);

        // Randomize IOSUB to MCP interrupt masks
        random_value = $urandom();
        write_register(ADDR_MASK_IOSUB_TO_MCP_INTR_0, random_value);

        random_value = $urandom();
        write_register(ADDR_MASK_IOSUB_TO_MCP_INTR_1, random_value);

        random_value = $urandom();
        write_register(ADDR_MASK_IOSUB_TO_MCP_INTR_2, random_value);

        random_value = $urandom();
        write_register(ADDR_MASK_IOSUB_TO_MCP_INTR_3, random_value);

        random_value = $urandom() & 32'h0001_FFFF; // [145:128] = 17 bits valid
        write_register(ADDR_MASK_IOSUB_TO_MCP_INTR_4, random_value);

        // Randomize IOSUB to ACCEL interrupt mask
        random_value = $urandom();
        write_register(ADDR_MASK_IOSUB_TO_ACCEL_INTR_0, random_value);

        // Randomize PSUB and PCIE1 masks (19-bit fields)
        random_value = $urandom() & 32'h000F_FFFF;
        write_register(ADDR_MASK_PSUB_TO_IOSUB_INTR, random_value);

        random_value = $urandom() & 32'h000F_FFFF;
        write_register(ADDR_MASK_PCIE1_TO_IOSUB_INTR, random_value);

        // Randomize configuration registers
        random_value = $urandom() & 32'h0000_0FFF;
        write_register(ADDR_ACCEL_UART_SEL, random_value);

        random_value = $urandom() & 32'h00FF_FFFF;
        write_register(ADDR_ACCEL_DMA_CH_SEL, random_value);

        `uvm_info("INT_REG_MODEL", "Mask registers randomized for test initialization", UVM_MEDIUM)
    endtask

    // Update status register (called when interrupt occurs)
    // Note: Status registers are typically read-only and updated by hardware
    // This function is kept for compatibility but may not be needed for hardware model
    function void update_status_register(string interrupt_name, bit status_value);
        `uvm_info("INT_REG_MODEL", $sformatf("Status update for interrupt '%s': %b (Note: Status registers are typically hardware-updated)",
                  interrupt_name, status_value), UVM_HIGH)
        // In hardware model, status registers are updated by the DUT, not by software
        // This function is kept for compatibility with existing code
    endfunction

    // Check if interrupt is masked (returns 1 if masked/disabled, 0 if enabled)
    function bit is_interrupt_masked(string interrupt_name, string destination, int_routing_model routing_model);
        logic [31:0] mask_value;
        logic [31:0] addr;
        int bit_index;
        int dest_index;
        int sub_index;
        int reg_bit;
        int mask_bit;
        bit final_result;

        `uvm_info("INT_REG_MODEL", $sformatf("🔍 Checking mask status for interrupt '%s' to destination '%s'",
                  interrupt_name, destination), UVM_HIGH)

        // Special handling for merge interrupts that route indirectly via other merge interrupts
        // For example: iosub_slv_err_intr → iosub_normal_intr → SCP/MCP
        if (interrupt_name == "iosub_slv_err_intr" && (destination.toupper() == "SCP" || destination.toupper() == "MCP")) begin
            `uvm_info("INT_REG_MODEL", $sformatf("🔗 Special handling: %s routes indirectly to %s via iosub_normal_intr",
                      interrupt_name, destination), UVM_HIGH)

            // For iosub_slv_err_intr routing to SCP/MCP, we need to check:
            // 1. iosub_normal_intr mask (since iosub_slv_err_intr is merged into it)
            // 2. The general SCP/MCP mask for iosub_normal_intr

            // Check if iosub_normal_intr itself would be masked to this destination
            bit iosub_normal_masked = is_interrupt_masked("iosub_normal_intr", destination, routing_model);

            if (iosub_normal_masked) begin
                `uvm_info("INT_REG_MODEL", $sformatf("🚫 %s blocked because iosub_normal_intr is masked to %s",
                          interrupt_name, destination), UVM_HIGH)
                return 1; // Blocked by iosub_normal_intr mask
            end else begin
                `uvm_info("INT_REG_MODEL", $sformatf("✅ %s can route to %s via iosub_normal_intr (not masked)",
                          interrupt_name, destination), UVM_HIGH)
                return 0; // Not masked
            end
        end

        // Special handling for IOSUB normal interrupts
        // Check if interrupt belongs to IOSUB group and has index in [0,9] or [15,50] ranges
        bit is_iosub_normal = 0;
        foreach (routing_model.interrupt_map[i]) begin
            if (routing_model.interrupt_map[i].name == interrupt_name) begin
                if (routing_model.interrupt_map[i].group == IOSUB) begin
                    int idx = routing_model.interrupt_map[i].index;
                    if ((idx >= 0 && idx <= 9) || (idx >= 15 && idx <= 50)) begin
                        is_iosub_normal = 1;
                        `uvm_info("INT_REG_MODEL", $sformatf("✅ Identified as IOSUB normal interrupt: %s (group=IOSUB, index=%0d)",
                                  interrupt_name, idx), UVM_HIGH)
                    end else begin
                        `uvm_info("INT_REG_MODEL", $sformatf("📋 IOSUB interrupt but not normal range: %s (group=IOSUB, index=%0d)",
                                  interrupt_name, idx), UVM_HIGH)
                    end
                end
                break;
            end
        end

        if (is_iosub_normal) begin

            `uvm_info("INT_REG_MODEL", $sformatf("🔗 Processing IOSUB normal interrupt: %s to %s", interrupt_name, destination), UVM_HIGH)

            // Check destination to determine mask processing strategy
            case (destination.toupper())
                "SCP", "MCP": begin
                    `uvm_info("INT_REG_MODEL", $sformatf("🔗 SCP/MCP destination: Using serial mask processing (Layer 1 + Layer 2)"), UVM_HIGH)

                    // Serial mask processing: Layer 1 (IOSUB Normal) → Layer 2 (SCP/MCP General)
                    bit first_layer_masked = check_iosub_normal_mask_layer(interrupt_name, destination, routing_model);

                    if (first_layer_masked) begin
                        `uvm_info("INT_REG_MODEL", $sformatf("🚫 Interrupt '%s' blocked by Layer 1 (IOSUB normal mask)", interrupt_name), UVM_HIGH)
                        return 1; // First layer blocks the interrupt
                    end

                    `uvm_info("INT_REG_MODEL", $sformatf("✅ Layer 1 (IOSUB normal mask) passed for '%s', checking Layer 2...", interrupt_name), UVM_HIGH)

                    // Layer 2: Check SCP/MCP general mask for 'iosub_normal_intr'
                    // Note: iosub_normal_intr may not have valid dest_index, so we need special handling
                    bit second_layer_masked = 0;

                    // Try to find iosub_normal_intr in the mapping table
                    int normal_intr_dest_index = get_interrupt_dest_index("iosub_normal_intr", destination, routing_model);

                    if (normal_intr_dest_index >= 0) begin
                        // Found valid dest_index, use normal general mask check
                        second_layer_masked = check_general_mask_layer("iosub_normal_intr", destination, routing_model);
                        `uvm_info("INT_REG_MODEL", $sformatf("🔍 Layer 2: Found iosub_normal_intr with dest_index=%0d", normal_intr_dest_index), UVM_HIGH)
                    end else begin
                        // iosub_normal_intr doesn't have valid dest_index, assume it's not masked at Layer 2
                        `uvm_info("INT_REG_MODEL", $sformatf("⚠️  Layer 2: iosub_normal_intr has no valid dest_index, assuming Layer 2 is not masked"), UVM_MEDIUM)
                        second_layer_masked = 0;
                    end

                    `uvm_info("INT_REG_MODEL", $sformatf("🔗 Serial mask result for '%s' to '%s': Layer1=%s, Layer2=%s, Final=%s",
                              interrupt_name, destination,
                              first_layer_masked ? "BLOCKED" : "PASSED",
                              second_layer_masked ? "BLOCKED" : "PASSED",
                              second_layer_masked ? "MASKED" : "ENABLED"), UVM_MEDIUM)

                    return second_layer_masked;
                end

                "ACCEL": begin
                    `uvm_info("INT_REG_MODEL", $sformatf("🎯 ACCEL destination: Using single-layer mask processing (ACCEL mask only)"), UVM_HIGH)

                    // For ACCEL destination, IOSUB normal interrupts only use ACCEL mask (no serial processing)
                    return check_general_mask_layer(interrupt_name, destination, routing_model);
                end

                default: begin
                    `uvm_info("INT_REG_MODEL", $sformatf("📋 Other destination '%s': Using general mask processing", destination), UVM_HIGH)

                    // For other destinations, use general mask processing
                    return check_general_mask_layer(interrupt_name, destination, routing_model);
                end
            endcase
        end
        else begin
            `uvm_info("INT_REG_MODEL", $sformatf("📋 Processing general interrupt (non-IOSUB normal): %s", interrupt_name), UVM_HIGH)
            // For all other interrupts, directly use general mask check to avoid code duplication
            return check_general_mask_layer(interrupt_name, destination, routing_model);
        end

        // Get mask value from cache if available, otherwise assume enabled
        if (current_mask_values.exists(addr)) begin
            mask_value = current_mask_values[addr];
            `uvm_info("INT_REG_MODEL", $sformatf("📖 Found cached mask value: addr=0x%08x, value=0x%08x", addr, mask_value), UVM_HIGH)
        end else begin
            mask_value = 32'hFFFF_FFFF; // Default to enabled if not cached
            `uvm_info("INT_REG_MODEL", $sformatf("⚠️  No cached mask value for addr=0x%08x, using default 0x%08x (all enabled)", addr, mask_value), UVM_MEDIUM)
        end

        // Return 1 if masked (bit is 0), 0 if enabled (bit is 1)
        final_result = ~mask_value[bit_index];
        `uvm_info("INT_REG_MODEL", $sformatf("🔍 Final mask check result: interrupt='%s', dest='%s', addr=0x%08x, bit_index=%0d, mask_bit=%b, result=%s",
                  interrupt_name, destination, addr, bit_index, mask_value[bit_index], final_result ? "MASKED" : "ENABLED"), UVM_MEDIUM)
        return final_result;
    endfunction

    // Print current register configuration
    task print_register_config();
        logic [31:0] data;

        `uvm_info("INT_REG_MODEL", "=== Current Hardware Register Configuration ===", UVM_MEDIUM)

        // Read and print PLL mask registers
        read_register(ADDR_MASK_PLL_INTR_0, data);
        `uvm_info("INT_REG_MODEL", $sformatf("PLL Mask[0] (lock): 0x%08x", data), UVM_MEDIUM)

        read_register(ADDR_MASK_PLL_INTR_1, data);
        `uvm_info("INT_REG_MODEL", $sformatf("PLL Mask[1] (unlock): 0x%08x", data), UVM_MEDIUM)

        read_register(ADDR_MASK_PLL_INTR_2, data);
        `uvm_info("INT_REG_MODEL", $sformatf("PLL Mask[2] (frechangedone): 0x%08x", data), UVM_MEDIUM)

        read_register(ADDR_MASK_PLL_INTR_3, data);
        `uvm_info("INT_REG_MODEL", $sformatf("PLL Mask[3] (frechange_tot_done): 0x%08x", data), UVM_MEDIUM)

        read_register(ADDR_MASK_PLL_INTR_4, data);
        `uvm_info("INT_REG_MODEL", $sformatf("PLL Mask[4] (intdocfrac_err): 0x%08x", data), UVM_MEDIUM)

        // Read and print IOSUB mask registers
        read_register(ADDR_MASK_IOSUB_TO_SCP_NORMAL_INTR_0, data);
        `uvm_info("INT_REG_MODEL", $sformatf("IOSUB->SCP Normal[0]: 0x%08x", data), UVM_MEDIUM)

        read_register(ADDR_MASK_IOSUB_TO_MCP_NORMAL_INTR_0, data);
        `uvm_info("INT_REG_MODEL", $sformatf("IOSUB->MCP Normal[0]: 0x%08x", data), UVM_MEDIUM)

        // Read and print ACCEL mask register
        read_register(ADDR_MASK_IOSUB_TO_ACCEL_INTR_0, data);
        `uvm_info("INT_REG_MODEL", $sformatf("IOSUB->ACCEL Mask: 0x%08x", data), UVM_MEDIUM)

        // Read and print PSUB/PCIE1 mask registers
        read_register(ADDR_MASK_PSUB_TO_IOSUB_INTR, data);
        `uvm_info("INT_REG_MODEL", $sformatf("PSUB->IOSUB Mask: 0x%08x", data), UVM_MEDIUM)

        read_register(ADDR_MASK_PCIE1_TO_IOSUB_INTR, data);
        `uvm_info("INT_REG_MODEL", $sformatf("PCIE1->IOSUB Mask: 0x%08x", data), UVM_MEDIUM)

        `uvm_info("INT_REG_MODEL", "=== End Hardware Register Configuration ===", UVM_MEDIUM)
    endtask

    // Print current status registers
    task print_status_registers();
        logic [31:0] data;

        `uvm_info("INT_REG_MODEL", "=== Current Hardware Status Registers ===", UVM_MEDIUM)

        // Read and print PLL status registers
        read_register(ADDR_STATUS_PLL_INTR_0, data);
        `uvm_info("INT_REG_MODEL", $sformatf("PLL Status[0] (lock): 0x%08x", data), UVM_MEDIUM)

        read_register(ADDR_STATUS_PLL_INTR_1, data);
        `uvm_info("INT_REG_MODEL", $sformatf("PLL Status[1] (unlock): 0x%08x", data), UVM_MEDIUM)

        read_register(ADDR_STATUS_PLL_INTR_2, data);
        `uvm_info("INT_REG_MODEL", $sformatf("PLL Status[2] (frechangedone): 0x%08x", data), UVM_MEDIUM)

        read_register(ADDR_STATUS_PLL_INTR_3, data);
        `uvm_info("INT_REG_MODEL", $sformatf("PLL Status[3] (frechange_tot_done): 0x%08x", data), UVM_MEDIUM)

        read_register(ADDR_STATUS_PLL_INTR_4, data);
        `uvm_info("INT_REG_MODEL", $sformatf("PLL Status[4] (intdocfrac_err): 0x%08x", data), UVM_MEDIUM)

        // Read and print IOSUB status registers
        read_register(ADDR_STATUS_IOSUB_NORMAL_INTR_0, data);
        `uvm_info("INT_REG_MODEL", $sformatf("IOSUB Normal Status[0]: 0x%08x", data), UVM_MEDIUM)

        read_register(ADDR_STATUS_IOSUB_NORMAL_INTR_1, data);
        `uvm_info("INT_REG_MODEL", $sformatf("IOSUB Normal Status[1]: 0x%08x", data), UVM_MEDIUM)

        // Read and print PSUB/PCIE1 status registers
        read_register(ADDR_STATUS_PSUB_TO_IOSUB_INTR, data);
        `uvm_info("INT_REG_MODEL", $sformatf("PSUB Status: 0x%08x", data), UVM_MEDIUM)

        read_register(ADDR_STATUS_PCIE1_TO_IOSUB_INTR, data);
        `uvm_info("INT_REG_MODEL", $sformatf("PCIE1 Status: 0x%08x", data), UVM_MEDIUM)

        `uvm_info("INT_REG_MODEL", "=== End Hardware Status Registers ===", UVM_MEDIUM)
    endtask

    // Get interrupt sub_index from interrupt map (for IOSUB normal interrupts)
    function int get_interrupt_sub_index(string interrupt_name, int_routing_model routing_model);
        `uvm_info("INT_REG_MODEL", $sformatf("🔍 Searching sub_index for interrupt: %s", interrupt_name), UVM_HIGH)

        // Search through interrupt map to find the sub_index for this interrupt
        foreach (routing_model.interrupt_map[i]) begin
            if (routing_model.interrupt_map[i].name == interrupt_name) begin
                `uvm_info("INT_REG_MODEL", $sformatf("✅ Found interrupt '%s' at map index %0d, sub_index=%0d",
                          interrupt_name, i, routing_model.interrupt_map[i].index), UVM_HIGH)
                return routing_model.interrupt_map[i].index;
            end
        end
        `uvm_info("INT_REG_MODEL", $sformatf("❌ Interrupt '%s' not found in routing model", interrupt_name), UVM_MEDIUM)
        return -1; // Not found
    endfunction

    // Get interrupt destination index from interrupt map (for SCP/MCP general interrupts)
    function int get_interrupt_dest_index(string interrupt_name, string destination, int_routing_model routing_model);
        `uvm_info("INT_REG_MODEL", $sformatf("🔍 Searching dest_index for interrupt: %s, destination: %s", interrupt_name, destination), UVM_HIGH)

        // Search through interrupt map to find the dest_index for this interrupt and destination
        foreach (routing_model.interrupt_map[i]) begin
            if (routing_model.interrupt_map[i].name == interrupt_name) begin
                `uvm_info("INT_REG_MODEL", $sformatf("✅ Found interrupt '%s' at map index %0d", interrupt_name, i), UVM_HIGH)

                case (destination.toupper())
                    "SCP": begin
                        if (routing_model.interrupt_map[i].to_scp == 1) begin
                            `uvm_info("INT_REG_MODEL", $sformatf("📍 SCP routing enabled, dest_index_scp=%0d", routing_model.interrupt_map[i].dest_index_scp), UVM_HIGH)
                            return routing_model.interrupt_map[i].dest_index_scp;
                        end else begin
                            `uvm_info("INT_REG_MODEL", $sformatf("❌ SCP routing disabled for interrupt '%s'", interrupt_name), UVM_HIGH)
                        end
                    end
                    "MCP": begin
                        if (routing_model.interrupt_map[i].to_mcp == 1) begin
                            `uvm_info("INT_REG_MODEL", $sformatf("📍 MCP routing enabled, dest_index_mcp=%0d", routing_model.interrupt_map[i].dest_index_mcp), UVM_HIGH)
                            return routing_model.interrupt_map[i].dest_index_mcp;
                        end else begin
                            `uvm_info("INT_REG_MODEL", $sformatf("❌ MCP routing disabled for interrupt '%s'", interrupt_name), UVM_HIGH)
                        end
                    end
                    "ACCEL": begin
                        if (routing_model.interrupt_map[i].to_accel == 1) begin
                            `uvm_info("INT_REG_MODEL", $sformatf("📍 ACCEL routing enabled, dest_index_accel=%0d", routing_model.interrupt_map[i].dest_index_accel), UVM_HIGH)
                            return routing_model.interrupt_map[i].dest_index_accel;
                        end else begin
                            `uvm_info("INT_REG_MODEL", $sformatf("❌ ACCEL routing disabled for interrupt '%s'", interrupt_name), UVM_HIGH)
                        end
                    end
                    "AP": begin
                        if (routing_model.interrupt_map[i].to_ap == 1) begin
                            `uvm_info("INT_REG_MODEL", $sformatf("📍 AP routing enabled, dest_index_ap=%0d", routing_model.interrupt_map[i].dest_index_ap), UVM_HIGH)
                            return routing_model.interrupt_map[i].dest_index_ap;
                        end else begin
                            `uvm_info("INT_REG_MODEL", $sformatf("❌ AP routing disabled for interrupt '%s'", interrupt_name), UVM_HIGH)
                        end
                    end
                    "IO": begin
                        if (routing_model.interrupt_map[i].to_io == 1) begin
                            `uvm_info("INT_REG_MODEL", $sformatf("📍 IO routing enabled, dest_index_io=%0d", routing_model.interrupt_map[i].dest_index_io), UVM_HIGH)
                            return routing_model.interrupt_map[i].dest_index_io;
                        end else begin
                            `uvm_info("INT_REG_MODEL", $sformatf("❌ IO routing disabled for interrupt '%s'", interrupt_name), UVM_HIGH)
                        end
                    end
                    default: begin
                        `uvm_info("INT_REG_MODEL", $sformatf("❌ Unknown destination '%s' for interrupt '%s'", destination, interrupt_name), UVM_MEDIUM)
                    end
                endcase
                break; // Found the interrupt, no need to continue
            end
        end
        `uvm_info("INT_REG_MODEL", $sformatf("❌ Interrupt '%s' not found or destination '%s' not supported", interrupt_name, destination), UVM_MEDIUM)
        return -1; // Not found or destination not supported
    endfunction

    // Check IOSUB normal mask layer (Layer 1 of serial mask processing)
    function bit check_iosub_normal_mask_layer(string interrupt_name, string destination, int_routing_model routing_model);
        logic [31:0] mask_value;
        logic [31:0] addr;
        int bit_index;
        int sub_index;
        int reg_bit;
        bit result;

        `uvm_info("INT_REG_MODEL", $sformatf("🔍 Layer 1: Checking IOSUB normal mask for '%s' to '%s'", interrupt_name, destination), UVM_HIGH)

        // Get interrupt sub_index for IOSUB normal interrupts
        sub_index = get_interrupt_sub_index(interrupt_name, routing_model);
        `uvm_info("INT_REG_MODEL", $sformatf("📍 Retrieved sub_index: %0d for interrupt %s", sub_index, interrupt_name), UVM_HIGH)

        if (sub_index < 0) begin
            `uvm_info("INT_REG_MODEL", $sformatf("❌ Invalid sub_index (%0d) for interrupt %s, assuming not masked", sub_index, interrupt_name), UVM_MEDIUM)
            return 0;
        end

        case (destination.toupper())
            "SCP": begin
                `uvm_info("INT_REG_MODEL", $sformatf("🎯 Layer 1: Processing SCP destination for IOSUB normal interrupt"), UVM_HIGH)
                // IOSUB normal interrupts: 45-bit mask split across 2 registers
                if (sub_index >= 0 && sub_index <= 9) begin
                    reg_bit = sub_index;  // Index 0-9 maps to bit 0-9
                    `uvm_info("INT_REG_MODEL", $sformatf("📊 Range 0-9: sub_index=%0d → reg_bit=%0d", sub_index, reg_bit), UVM_HIGH)
                end else if (sub_index >= 15 && sub_index <= 50) begin
                    reg_bit = sub_index - 5;  // Index 15-50 maps to bit 10-45
                    `uvm_info("INT_REG_MODEL", $sformatf("📊 Range 15-50: sub_index=%0d → reg_bit=%0d", sub_index, reg_bit), UVM_HIGH)
                end else begin
                    `uvm_info("INT_REG_MODEL", $sformatf("❌ Invalid sub_index range (%0d) for SCP, assuming masked", sub_index), UVM_MEDIUM)
                    return 1; // Not in valid range, assume masked
                end

                if (reg_bit <= 31) begin
                    addr = ADDR_MASK_IOSUB_TO_SCP_NORMAL_INTR_0;  // [31:0]
                    bit_index = reg_bit;
                    `uvm_info("INT_REG_MODEL", $sformatf("📍 Layer 1: Using register 0: addr=0x%08x, bit_index=%0d", addr, bit_index), UVM_HIGH)
                end else begin
                    addr = ADDR_MASK_IOSUB_TO_SCP_NORMAL_INTR_1;  // [45:32]
                    bit_index = reg_bit - 32;
                    `uvm_info("INT_REG_MODEL", $sformatf("📍 Layer 1: Using register 1: addr=0x%08x, bit_index=%0d", addr, bit_index), UVM_HIGH)
                end
            end

            "MCP": begin
                `uvm_info("INT_REG_MODEL", $sformatf("🎯 Layer 1: Processing MCP destination for IOSUB normal interrupt"), UVM_HIGH)
                // IOSUB normal interrupts: 45-bit mask split across 2 registers
                if (sub_index >= 0 && sub_index <= 9) begin
                    reg_bit = sub_index;  // Index 0-9 maps to bit 0-9
                    `uvm_info("INT_REG_MODEL", $sformatf("📊 Range 0-9: sub_index=%0d → reg_bit=%0d", sub_index, reg_bit), UVM_HIGH)
                end else if (sub_index >= 15 && sub_index <= 50) begin
                    reg_bit = sub_index - 5;  // Index 15-50 maps to bit 10-45
                    `uvm_info("INT_REG_MODEL", $sformatf("📊 Range 15-50: sub_index=%0d → reg_bit=%0d", sub_index, reg_bit), UVM_HIGH)
                end else begin
                    `uvm_info("INT_REG_MODEL", $sformatf("❌ Invalid sub_index range (%0d) for MCP, assuming masked", sub_index), UVM_MEDIUM)
                    return 1; // Not in valid range, assume masked
                end

                if (reg_bit <= 31) begin
                    addr = ADDR_MASK_IOSUB_TO_MCP_NORMAL_INTR_0;  // [31:0]
                    bit_index = reg_bit;
                    `uvm_info("INT_REG_MODEL", $sformatf("📍 Layer 1: Using register 0: addr=0x%08x, bit_index=%0d", addr, bit_index), UVM_HIGH)
                end else begin
                    addr = ADDR_MASK_IOSUB_TO_MCP_NORMAL_INTR_1;  // [45:32]
                    bit_index = reg_bit - 32;
                    `uvm_info("INT_REG_MODEL", $sformatf("📍 Layer 1: Using register 1: addr=0x%08x, bit_index=%0d", addr, bit_index), UVM_HIGH)
                end
            end

            default: begin
                `uvm_info("INT_REG_MODEL", $sformatf("❌ Unsupported destination '%s' for IOSUB normal interrupt Layer 1, assuming unmasked", destination), UVM_MEDIUM)
                return 0; // Unmasked for other destinations
            end
        endcase

        // Get mask value from cache if available, otherwise assume enabled
        if (current_mask_values.exists(addr)) begin
            mask_value = current_mask_values[addr];
            `uvm_info("INT_REG_MODEL", $sformatf("📖 Layer 1: Found cached mask value: addr=0x%08x, value=0x%08x", addr, mask_value), UVM_HIGH)
        end else begin
            mask_value = 32'hFFFF_FFFF; // Default to enabled if not cached
            `uvm_info("INT_REG_MODEL", $sformatf("⚠️  Layer 1: No cached mask value for addr=0x%08x, using default 0x%08x (all enabled)", addr, mask_value), UVM_MEDIUM)
        end

        // Return 1 if masked (bit is 0), 0 if enabled (bit is 1)
        result = ~mask_value[bit_index];
        `uvm_info("INT_REG_MODEL", $sformatf("🔍 Layer 1 result: interrupt='%s', dest='%s', addr=0x%08x, bit_index=%0d, mask_bit=%b, result=%s",
                  interrupt_name, destination, addr, bit_index, mask_value[bit_index], result ? "BLOCKED" : "PASSED"), UVM_HIGH)
        return result;
    endfunction

    // Check general mask layer (Layer 2 of serial mask processing)
    function bit check_general_mask_layer(string interrupt_name, string destination, int_routing_model routing_model);
        logic [31:0] mask_value;
        logic [31:0] addr;
        int bit_index;
        int dest_index;
        int mask_bit;
        bit result;

        `uvm_info("INT_REG_MODEL", $sformatf("🔍 Layer 2: Checking general mask for '%s' to '%s'", interrupt_name, destination), UVM_HIGH)

        // Get destination index for the interrupt
        dest_index = get_interrupt_dest_index(interrupt_name, destination, routing_model);
        `uvm_info("INT_REG_MODEL", $sformatf("📍 Layer 2: Retrieved dest_index: %0d for interrupt %s to %s", dest_index, interrupt_name, destination), UVM_HIGH)

        if (dest_index < 0) begin
            `uvm_info("INT_REG_MODEL", $sformatf("❌ Layer 2: Invalid dest_index (%0d) for interrupt %s to %s, assuming not masked", dest_index, interrupt_name, destination), UVM_MEDIUM)
            return 0;
        end

        case (destination.toupper())
            "SCP": begin
                `uvm_info("INT_REG_MODEL", $sformatf("🎯 Layer 2: Processing SCP destination for general interrupt"), UVM_HIGH)
                // SCP: dest_index_scp maps to cpu_irq[109-239]
                // mask bit 0-130 corresponds to cpu_irq[109-239]
                // So mask_bit = dest_index_scp - 109
                if (dest_index < 109 || dest_index > 239) begin
                    `uvm_info("INT_REG_MODEL", $sformatf("❌ Layer 2: dest_index (%0d) out of valid SCP cpu_irq range [109-239], assuming masked", dest_index), UVM_MEDIUM)
                    return 1; // Out of valid cpu_irq range, assume masked
                end

                mask_bit = dest_index - 109;  // Convert cpu_irq index to mask bit position
                `uvm_info("INT_REG_MODEL", $sformatf("📊 Layer 2: SCP mapping: dest_index=%0d → mask_bit=%0d", dest_index, mask_bit), UVM_HIGH)

                // Map mask bit to register and bit position
                if (mask_bit <= 31) begin
                    addr = ADDR_MASK_IOSUB_TO_SCP_INTR_0;  // [31:0]
                    bit_index = mask_bit;
                    `uvm_info("INT_REG_MODEL", $sformatf("📍 Layer 2: Using SCP register 0: addr=0x%08x, bit_index=%0d", addr, bit_index), UVM_HIGH)
                end else if (mask_bit <= 63) begin
                    addr = ADDR_MASK_IOSUB_TO_SCP_INTR_1;  // [63:32]
                    bit_index = mask_bit - 32;
                    `uvm_info("INT_REG_MODEL", $sformatf("📍 Layer 2: Using SCP register 1: addr=0x%08x, bit_index=%0d", addr, bit_index), UVM_HIGH)
                end else if (mask_bit <= 95) begin
                    addr = ADDR_MASK_IOSUB_TO_SCP_INTR_2;  // [95:64]
                    bit_index = mask_bit - 64;
                    `uvm_info("INT_REG_MODEL", $sformatf("📍 Layer 2: Using SCP register 2: addr=0x%08x, bit_index=%0d", addr, bit_index), UVM_HIGH)
                end else if (mask_bit <= 127) begin
                    addr = ADDR_MASK_IOSUB_TO_SCP_INTR_3;  // [127:96]
                    bit_index = mask_bit - 96;
                    `uvm_info("INT_REG_MODEL", $sformatf("📍 Layer 2: Using SCP register 3: addr=0x%08x, bit_index=%0d", addr, bit_index), UVM_HIGH)
                end else if (mask_bit <= 130) begin
                    addr = ADDR_MASK_IOSUB_TO_SCP_INTR_4;  // [130:128]
                    bit_index = mask_bit - 128;
                    `uvm_info("INT_REG_MODEL", $sformatf("📍 Layer 2: Using SCP register 4: addr=0x%08x, bit_index=%0d", addr, bit_index), UVM_HIGH)
                end else begin
                    `uvm_info("INT_REG_MODEL", $sformatf("❌ Layer 2: mask_bit (%0d) out of SCP mask range [0-130], assuming masked", mask_bit), UVM_MEDIUM)
                    return 1; // Out of mask range, assume masked
                end
            end

            "MCP": begin
                `uvm_info("INT_REG_MODEL", $sformatf("🎯 Layer 2: Processing MCP destination for general interrupt"), UVM_HIGH)
                // MCP: dest_index_mcp maps to cpu_irq[64-209]
                // mask bit 0-145 corresponds to cpu_irq[64-209]
                // So mask_bit = dest_index_mcp - 64
                if (dest_index < 64 || dest_index > 209) begin
                    `uvm_info("INT_REG_MODEL", $sformatf("❌ Layer 2: dest_index (%0d) out of valid MCP cpu_irq range [64-209], assuming masked", dest_index), UVM_MEDIUM)
                    return 1; // Out of valid cpu_irq range, assume masked
                end

                mask_bit = dest_index - 64;  // Convert cpu_irq index to mask bit position
                `uvm_info("INT_REG_MODEL", $sformatf("📊 Layer 2: MCP mapping: dest_index=%0d → mask_bit=%0d", dest_index, mask_bit), UVM_HIGH)

                // Map mask bit to register and bit position
                if (mask_bit <= 31) begin
                    addr = ADDR_MASK_IOSUB_TO_MCP_INTR_0;  // [31:0]
                    bit_index = mask_bit;
                    `uvm_info("INT_REG_MODEL", $sformatf("📍 Layer 2: Using MCP register 0: addr=0x%08x, bit_index=%0d", addr, bit_index), UVM_HIGH)
                end else if (mask_bit <= 63) begin
                    addr = ADDR_MASK_IOSUB_TO_MCP_INTR_1;  // [63:32]
                    bit_index = mask_bit - 32;
                    `uvm_info("INT_REG_MODEL", $sformatf("📍 Layer 2: Using MCP register 1: addr=0x%08x, bit_index=%0d", addr, bit_index), UVM_HIGH)
                end else if (mask_bit <= 95) begin
                    addr = ADDR_MASK_IOSUB_TO_MCP_INTR_2;  // [95:64]
                    bit_index = mask_bit - 64;
                    `uvm_info("INT_REG_MODEL", $sformatf("📍 Layer 2: Using MCP register 2: addr=0x%08x, bit_index=%0d", addr, bit_index), UVM_HIGH)
                end else if (mask_bit <= 127) begin
                    addr = ADDR_MASK_IOSUB_TO_MCP_INTR_3;  // [127:96]
                    bit_index = mask_bit - 96;
                    `uvm_info("INT_REG_MODEL", $sformatf("📍 Layer 2: Using MCP register 3: addr=0x%08x, bit_index=%0d", addr, bit_index), UVM_HIGH)
                end else if (mask_bit <= 145) begin
                    addr = ADDR_MASK_IOSUB_TO_MCP_INTR_4;  // [145:128]
                    bit_index = mask_bit - 128;
                    `uvm_info("INT_REG_MODEL", $sformatf("📍 Layer 2: Using MCP register 4: addr=0x%08x, bit_index=%0d", addr, bit_index), UVM_HIGH)
                end else begin
                    `uvm_info("INT_REG_MODEL", $sformatf("❌ Layer 2: mask_bit (%0d) out of MCP mask range [0-145], assuming masked", mask_bit), UVM_MEDIUM)
                    return 1; // Out of mask range, assume masked
                end
            end

            "ACCEL": begin
                `uvm_info("INT_REG_MODEL", $sformatf("🎯 Layer 2: Processing ACCEL destination for general interrupt"), UVM_HIGH)
                // ACCEL: dest_index_accel maps directly to mask bit position
                // ACCEL uses a single 32-bit mask register
                if (dest_index < 0 || dest_index > 31) begin
                    `uvm_info("INT_REG_MODEL", $sformatf("❌ Layer 2: dest_index (%0d) out of valid ACCEL mask range [0-31], assuming masked", dest_index), UVM_MEDIUM)
                    return 1; // Out of valid mask range, assume masked
                end

                addr = ADDR_MASK_IOSUB_TO_ACCEL_INTR_0;  // [31:0]
                bit_index = dest_index;  // Direct mapping
                `uvm_info("INT_REG_MODEL", $sformatf("📊 Layer 2: ACCEL mapping: dest_index=%0d → bit_index=%0d", dest_index, bit_index), UVM_HIGH)
                `uvm_info("INT_REG_MODEL", $sformatf("📍 Layer 2: Using ACCEL register: addr=0x%08x, bit_index=%0d", addr, bit_index), UVM_HIGH)
            end

            default: begin
                `uvm_info("INT_REG_MODEL", $sformatf("❌ Layer 2: Unsupported destination '%s', assuming unmasked", destination), UVM_MEDIUM)
                return 0; // Unmasked for other destinations
            end
        endcase

        // Get mask value from cache if available, otherwise assume enabled
        if (current_mask_values.exists(addr)) begin
            mask_value = current_mask_values[addr];
            `uvm_info("INT_REG_MODEL", $sformatf("📖 Layer 2: Found cached mask value: addr=0x%08x, value=0x%08x", addr, mask_value), UVM_HIGH)
        end else begin
            mask_value = 32'hFFFF_FFFF; // Default to enabled if not cached
            `uvm_info("INT_REG_MODEL", $sformatf("⚠️  Layer 2: No cached mask value for addr=0x%08x, using default 0x%08x (all enabled)", addr, mask_value), UVM_MEDIUM)
        end

        // Return 1 if masked (bit is 0), 0 if enabled (bit is 1)
        result = ~mask_value[bit_index];
        `uvm_info("INT_REG_MODEL", $sformatf("🔍 Layer 2 result: interrupt='%s', dest='%s', addr=0x%08x, bit_index=%0d, mask_bit=%b, result=%s",
                  interrupt_name, destination, addr, bit_index, mask_value[bit_index], result ? "BLOCKED" : "PASSED"), UVM_HIGH)
        return result;
    endfunction

    // Update ACCEL UART and DMA interrupt routing based on configuration registers
    task update_accel_uart_dma_routing(int_routing_model routing_model);
        logic [31:0] accel_uart_sel_value;
        logic [31:0] accel_dma_ch_sel_value;
        int uart_bit_pos, dma_bit_pos;
        int selected_uart_index, selected_dma_index;
        string accel_uart_path, accel_dma_path;
        int accel_uart_dest_index, accel_dma_dest_index;
        string uart_num_str;
        int uart_index;
        bit is_routed;
        int routed_accel_bit;
        string dma_num_str;
        int dma_index;

        `uvm_info("INT_REG_MODEL", "🔄 Updating ACCEL UART and DMA interrupt routing based on configuration registers", UVM_MEDIUM)

        // Get UART selection register value
        if (current_mask_values.exists(ADDR_ACCEL_UART_SEL)) begin
            accel_uart_sel_value = current_mask_values[ADDR_ACCEL_UART_SEL];
            `uvm_info("INT_REG_MODEL", $sformatf("📖 ACCEL_UART_SEL value: 0x%08x", accel_uart_sel_value), UVM_MEDIUM)
        end else begin
            accel_uart_sel_value = 32'h00000000; // Default: all route to uart0
            `uvm_info("INT_REG_MODEL", $sformatf("⚠️  No ACCEL_UART_SEL value, using default 0x%08x", accel_uart_sel_value), UVM_MEDIUM)
        end

        // Get DMA channel selection register value
        if (current_mask_values.exists(ADDR_ACCEL_DMA_CH_SEL)) begin
            accel_dma_ch_sel_value = current_mask_values[ADDR_ACCEL_DMA_CH_SEL];
            `uvm_info("INT_REG_MODEL", $sformatf("📖 ACCEL_DMA_CH_SEL value: 0x%08x", accel_dma_ch_sel_value), UVM_MEDIUM)
        end else begin
            accel_dma_ch_sel_value = 32'h00000000; // Default: all route to dma_ch0
            `uvm_info("INT_REG_MODEL", $sformatf("⚠️  No ACCEL_DMA_CH_SEL value, using default 0x%08x", accel_dma_ch_sel_value), UVM_MEDIUM)
        end

        // Update UART interrupt routing
        foreach (routing_model.interrupt_map[i]) begin
            if (routing_model.interrupt_map[i].name.substr(0, 10) == "iosub_uart" &&
                routing_model.interrupt_map[i].name.substr(routing_model.interrupt_map[i].name.len()-5, routing_model.interrupt_map[i].name.len()-1) == "_intr") begin

                // Extract UART index from interrupt name
                uart_num_str = routing_model.interrupt_map[i].name.substr(11, routing_model.interrupt_map[i].name.len()-6);
                uart_index = uart_num_str.atoi();

                if (uart_index >= 0 && uart_index <= 4) begin
                    // Check if this UART is routed to any uart_to_accel_intr[0:2]
                    is_routed = 0;
                    routed_accel_bit = -1;

                    for (int accel_uart_bit = 0; accel_uart_bit <= 2; accel_uart_bit++) begin
                        uart_bit_pos = accel_uart_bit * 4; // Bits [0,1], [4,5], [8,9]
                        selected_uart_index = (accel_uart_sel_value >> uart_bit_pos) & 2'b11; // Extract 2-bit value

                        if (selected_uart_index == uart_index) begin
                            is_routed = 1;
                            routed_accel_bit = accel_uart_bit;
                            break;
                        end
                    end

                    if (is_routed) begin
                        // Update routing to ACCEL
                        routing_model.interrupt_map[i].to_accel = 1;
                        // uart_to_accel_intr[0:2] maps to iosub_accel_peri_intr[18:20]
                        accel_uart_dest_index = 18 + routed_accel_bit;
                        routing_model.interrupt_map[i].dest_index_accel = accel_uart_dest_index;
                        accel_uart_path = $sformatf("top_tb.multidie_top.DUT[0].u_str_top.u_iosub_top_wrap.iosub_accel_peri_intr[%0d]", accel_uart_dest_index);
                        routing_model.interrupt_map[i].rtl_path_accel = accel_uart_path;

                        `uvm_info("INT_REG_MODEL", $sformatf("✅ Updated UART routing: %s → ACCEL (uart_to_accel_intr[%0d] → iosub_accel_peri_intr[%0d])",
                                  routing_model.interrupt_map[i].name, routed_accel_bit, accel_uart_dest_index), UVM_MEDIUM)
                    end else begin
                        // Disable routing to ACCEL
                        routing_model.interrupt_map[i].to_accel = 0;
                        routing_model.interrupt_map[i].dest_index_accel = -1;
                        routing_model.interrupt_map[i].rtl_path_accel = "";

                        `uvm_info("INT_REG_MODEL", $sformatf("🚫 Disabled UART routing: %s (uart_index=%0d not selected)",
                                  routing_model.interrupt_map[i].name, uart_index), UVM_MEDIUM)
                    end
                end
            end
        end

        // Update DMA interrupt routing
        foreach (routing_model.interrupt_map[i]) begin
            if (routing_model.interrupt_map[i].name.substr(0, 12) == "iosub_dma_ch" &&
                routing_model.interrupt_map[i].name.substr(routing_model.interrupt_map[i].name.len()-5, routing_model.interrupt_map[i].name.len()-1) == "_intr") begin

                // Extract DMA channel index from interrupt name
                dma_num_str = routing_model.interrupt_map[i].name.substr(13, routing_model.interrupt_map[i].name.len()-6);
                dma_index = dma_num_str.atoi();

                if (dma_index >= 0 && dma_index <= 15) begin
                    // Check if this DMA channel is routed to any dma_to_accel_intr[0:5]
                    is_routed = 0;
                    routed_accel_bit = -1;

                    for (int accel_dma_bit = 0; accel_dma_bit <= 5; accel_dma_bit++) begin
                        dma_bit_pos = accel_dma_bit * 4; // Bits [0,3], [4,7], [8,11], [12,15], [16,19], [20,23]
                        selected_dma_index = (accel_dma_ch_sel_value >> dma_bit_pos) & 4'hF; // Extract 4-bit value

                        if (selected_dma_index == dma_index) begin
                            is_routed = 1;
                            routed_accel_bit = accel_dma_bit;
                            break;
                        end
                    end

                    if (is_routed) begin
                        // Update routing to ACCEL
                        routing_model.interrupt_map[i].to_accel = 1;
                        // dma_to_accel_intr[0:5] maps to iosub_accel_peri_intr[22:27]
                        accel_dma_dest_index = 22 + routed_accel_bit;
                        routing_model.interrupt_map[i].dest_index_accel = accel_dma_dest_index;
                        accel_dma_path = $sformatf("top_tb.multidie_top.DUT[0].u_str_top.u_iosub_top_wrap.iosub_accel_peri_intr[%0d]", accel_dma_dest_index);
                        routing_model.interrupt_map[i].rtl_path_accel = accel_dma_path;

                        `uvm_info("INT_REG_MODEL", $sformatf("✅ Updated DMA routing: %s → ACCEL (dma_to_accel_intr[%0d] → iosub_accel_peri_intr[%0d])",
                                  routing_model.interrupt_map[i].name, routed_accel_bit, accel_dma_dest_index), UVM_MEDIUM)
                    end else begin
                        // Disable routing to ACCEL
                        routing_model.interrupt_map[i].to_accel = 0;
                        routing_model.interrupt_map[i].dest_index_accel = -1;
                        routing_model.interrupt_map[i].rtl_path_accel = "";

                        `uvm_info("INT_REG_MODEL", $sformatf("🚫 Disabled DMA routing: %s (dma_index=%0d not selected)",
                                  routing_model.interrupt_map[i].name, dma_index), UVM_MEDIUM)
                    end
                end
            end
        end

        `uvm_info("INT_REG_MODEL", "✅ ACCEL UART and DMA interrupt routing update completed", UVM_MEDIUM)
    endtask

endclass

`endif // INT_REGISTER_MODEL_SV
