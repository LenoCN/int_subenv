`ifndef INT_CROSS_DIE_ROUTING_SEQUENCE
`define INT_CROSS_DIE_ROUTING_SEQUENCE

class int_cross_die_routing_sequence extends int_base_sequence;
    `uvm_object_utils(int_cross_die_routing_sequence)

    typedef struct {
        string name;
        bit [15:0] csr_addr;
        string source_path;
        string dest_path_prefix;
    } cross_die_intr_cfg_s;

    cross_die_intr_cfg_s intr_configs[$];
    
    // SCP 500M CSR base address
    bit [63:0] scp_500m_csr_base;

    function new(string name = "int_cross_die_routing_sequence");
        super.new(name);
    endfunction

    virtual task body();
        bit [2:0] die_enables;
        bit [63:0] reg_addr;
        bit [31:0] reg_data;
        string source_signal_path;
        string dest_signal_path;
        bit source_value, dest_value;
        int pass_count = 0;
        int fail_count = 0;

        `uvm_info(get_type_name(), "Starting cross-die interrupt routing sequence", UVM_LOW)
        
        // Get SCP 500M CSR base address from memory map
        scp_500m_csr_base = memory_map.get_start_addr("scp_500m_csr", soc_vargs::main_core);
        `uvm_info(get_type_name(), $sformatf("SCP 500M CSR base address: 0x%016x", scp_500m_csr_base), UVM_MEDIUM)
        
        // Test each interrupt configuration
        foreach (intr_configs[i]) begin
            `uvm_info(get_type_name(), $sformatf("\n===== Testing interrupt: %s =====", intr_configs[i].name), UVM_LOW)
            
            // Calculate full register address for SCP 500M CSR space
            reg_addr = scp_500m_csr_base + intr_configs[i].csr_addr;
            
            // Test different routing configurations
            for (int test_pattern = 0; test_pattern < 8; test_pattern++) begin
                die_enables = test_pattern[2:0];
                
                `uvm_info(get_type_name(), $sformatf("Testing pattern %0d: DIE0=%0b, DIE1=%0b, DIE2=%0b", 
                         test_pattern, die_enables[0], die_enables[1], die_enables[2]), UVM_MEDIUM)
                
                // Write enable pattern to register using reg_seq directly
                reg_data = {29'b0, die_enables};
                `uvm_info(get_type_name(), $sformatf("Writing CSR: addr=0x%016x, data=0x%08x", reg_addr, reg_data), UVM_HIGH)
                reg_seq.write_reg(reg_addr, reg_data);
                
                // Allow time for configuration to take effect
                #100ns;
                
                // Trigger the source interrupt
                trigger_interrupt(intr_configs[i].source_path);
                
                // Allow propagation time
                #500ns;
                
                // Check each die output
                for (int die_idx = 0; die_idx < 3; die_idx++) begin
                    check_die_routing(intr_configs[i], die_idx, die_enables[die_idx], pass_count, fail_count);
                end
                
                // Clear the interrupt
                clear_interrupt(intr_configs[i].source_path);
                #100ns;
            end
        end
        
        // Report test results
        `uvm_info(get_type_name(), $sformatf("\n===== Test Results ====="), UVM_LOW)
        `uvm_info(get_type_name(), $sformatf("Total Pass: %0d", pass_count), UVM_LOW)
        `uvm_info(get_type_name(), $sformatf("Total Fail: %0d", fail_count), UVM_LOW)
        
        if (fail_count == 0) begin
            `uvm_info(get_type_name(), "✅ All cross-die interrupt routing tests PASSED!", UVM_LOW)
        end else begin
            `uvm_error(get_type_name(), $sformatf("❌ Cross-die interrupt routing tests FAILED with %0d errors", fail_count))
        end
        
    endtask

    // Task to trigger an interrupt using uvm_hdl_force
    task trigger_interrupt(string source_path);
        string full_path;
        
        // Build full hierarchical path
        full_path = build_signal_path(source_path);
        
        `uvm_info(get_type_name(), $sformatf("Triggering interrupt: %s", full_path), UVM_HIGH)
        
        // Use uvm_hdl_force to trigger the interrupt (same as int_driver.sv)
        if (!uvm_hdl_force(full_path, 1'b1)) begin
            `uvm_error(get_type_name(), $sformatf("Failed to force signal: %s", full_path))
        end
    endtask

    // Task to clear an interrupt using uvm_hdl_force
    task clear_interrupt(string source_path);
        string full_path;
        
        full_path = build_signal_path(source_path);
        
        `uvm_info(get_type_name(), $sformatf("Clearing interrupt: %s", full_path), UVM_HIGH)
        
        if (!uvm_hdl_force(full_path, 1'b0)) begin
            `uvm_error(get_type_name(), $sformatf("Failed to clear signal: %s", full_path))
        end
    endtask

    // Function to build full signal path
    function string build_signal_path(string relative_path);
        string base_path = "top_tb.multidie_top.DUT[0].u_str_top.u_iosub_top_wrap.u0_iosub_top_wrap_hd.u0_iosub_top_wrap_raw";
        
        if (relative_path.substr(0, 4) == "u_d2d") begin
            // MHU interrupt paths
            return $sformatf("%s.u_scp_top_wrapper.u_scp_top.%s", base_path, relative_path);
        end else begin
            // Other interrupt paths
            return $sformatf("%s.%s", base_path, relative_path);
        end
    endfunction

    // Task to check die routing using uvm_hdl_read
    task check_die_routing(cross_die_intr_cfg_s cfg, int die_idx, bit expected_enable, 
                          ref int pass_count, ref int fail_count);
        string dest_signal_path;
        logic actual_value;
        string die_suffix;
        
        // Determine die suffix for signal name
        die_suffix = $sformatf("%0d_sig", die_idx);
        
        // Build destination signal path
        dest_signal_path = $sformatf("top_tb.multidie_top.DUT[0].u_str_top.u_iosub_top_wrap.u0_iosub_top_wrap_hd.u0_iosub_top_wrap_raw.u_scp_top_wrapper.u_scp_top.%s%s", 
                                     cfg.dest_path_prefix, die_suffix);
        
        // Read the destination signal value using uvm_hdl_read (same as int_monitor.sv)
        if (!uvm_hdl_read(dest_signal_path, actual_value)) begin
            `uvm_error(get_type_name(), $sformatf("Failed to read signal: %s", dest_signal_path))
            fail_count++;
            return;
        end
        
        // Check if the routing matches expectation
        if (expected_enable) begin
            if (actual_value == 1'b1) begin
                `uvm_info(get_type_name(), $sformatf("✅ DIE%0d: Interrupt correctly routed (expected=1, actual=1)", die_idx), UVM_MEDIUM)
                pass_count++;
            end else begin
                `uvm_error(get_type_name(), $sformatf("❌ DIE%0d: Interrupt NOT routed (expected=1, actual=0)", die_idx))
                fail_count++;
            end
        end else begin
            if (actual_value == 1'b0) begin
                `uvm_info(get_type_name(), $sformatf("✅ DIE%0d: Interrupt correctly masked (expected=0, actual=0)", die_idx), UVM_MEDIUM)
                pass_count++;
            end else begin
                `uvm_error(get_type_name(), $sformatf("❌ DIE%0d: Interrupt incorrectly routed (expected=0, actual=1)", die_idx))
                fail_count++;
            end
        end
    endtask

endclass

`endif // INT_CROSS_DIE_ROUTING_SEQUENCE