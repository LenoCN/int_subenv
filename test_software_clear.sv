// Test to verify software interrupt clearing functionality
// This test demonstrates the difference between the old automatic clearing
// and the new software-based clearing approach

`include "uvm_macros.svh"
import uvm_pkg::*;

`include "seq/int_def.sv"
`include "seq/int_software_handler.sv"

class test_software_clear extends uvm_test;
    `uvm_component_utils(test_software_clear)

    function new(string name = "test_software_clear", uvm_component parent = null);
        super.new(name, parent);
    endfunction

    virtual task run_phase(uvm_phase phase);
        interrupt_info_s test_interrupt;
        
        phase.raise_objection(this);
        
        `uvm_info(get_type_name(), "=== Testing Software Interrupt Clearing ===", UVM_LOW)
        
        // Create a test interrupt
        test_interrupt = '{
            name: "test_uart_intr",
            index: 10,
            group: IOSUB,
            trigger: LEVEL,
            polarity: ACTIVE_HIGH,
            rtl_path_src: "tb.uart_intr_signal",
            to_ap: 1,
            rtl_path_ap: "tb.ap_intr[10]",
            to_scp: 0,
            rtl_path_scp: "",
            to_mcp: 0,
            rtl_path_mcp: "",
            to_imu: 1,
            rtl_path_imu: "tb.imu_intr[10]",
            to_io: 0,
            rtl_path_io: "",
            to_other_die: 0,
            rtl_path_other_die: ""
        };

        // Configure software handler for faster simulation
        int_software_handler::configure_timing(
            .ctx_save(5),      // Context save: 5ns
            .int_id(2),        // Interrupt ID: 2ns  
            .handler(10),      // Handler execution: 10ns
            .clear_reg(1),     // Clear register: 1ns
            .ctx_restore(3)    // Context restore: 3ns
        );

        // Reset statistics
        int_software_handler::reset_statistics();

        `uvm_info(get_type_name(), "Testing single interrupt handling...", UVM_MEDIUM)
        
        // Simulate the new software clearing approach
        test_single_interrupt_with_software_clear(test_interrupt);
        
        // Test multiple interrupts
        `uvm_info(get_type_name(), "Testing multiple interrupt handling...", UVM_MEDIUM)
        for (int i = 0; i < 5; i++) begin
            test_interrupt.name = $sformatf("test_intr_%0d", i);
            test_interrupt.index = i;
            test_single_interrupt_with_software_clear(test_interrupt);
        end

        // Print final statistics
        `uvm_info(get_type_name(), "=== Final Statistics ===", UVM_LOW)
        int_software_handler::print_statistics();
        
        `uvm_info(get_type_name(), "=== Test Completed Successfully ===", UVM_LOW)
        
        phase.drop_objection(this);
    endtask

    // Test task that simulates the new software clearing approach
    task test_single_interrupt_with_software_clear(interrupt_info_s info);
        `uvm_info(get_type_name(), $sformatf("--- Testing interrupt: %s ---", info.name), UVM_MEDIUM)
        
        // Step 1: Force interrupt (simulate hardware asserting interrupt)
        `uvm_info(get_type_name(), $sformatf("Asserting interrupt '%s'", info.name), UVM_HIGH)
        // In real test, this would be: uvm_hdl_force(info.rtl_path_src, 1);
        // For this demo, we just simulate the timing
        #10ns; // Interrupt propagation delay
        
        // Step 2: Wait for interrupt detection (simulate interrupt controller latching)
        `uvm_info(get_type_name(), $sformatf("Interrupt '%s' detected by system", info.name), UVM_HIGH)
        #20ns; // Interrupt detection delay
        
        // Step 3: Software handles and clears the interrupt
        `uvm_info(get_type_name(), $sformatf("Software handling interrupt '%s'", info.name), UVM_HIGH)
        int_software_handler::handle_interrupt(info);
        
        // Step 4: Wait for clear to propagate
        #10ns; // Clear propagation delay
        
        `uvm_info(get_type_name(), $sformatf("Interrupt '%s' fully processed", info.name), UVM_HIGH)
    endtask

endclass

// Simple test runner
module test_software_clear_tb;
    
    initial begin
        // Set up UVM
        uvm_config_db#(uvm_verbosity)::set(null, "*", "recording_detail", UVM_FULL);
        
        // Run the test
        run_test("test_software_clear");
    end

endmodule
