`ifndef INT_SCOREBOARD_SV
`define INT_SCOREBOARD_SV

// Transaction class for expected interrupt notifications
class int_exp_transaction extends uvm_sequence_item;
    interrupt_info_s interrupt_info;

    `uvm_object_utils_begin(int_exp_transaction)
        `uvm_field_object(interrupt_info, UVM_ALL_ON)
    `uvm_object_utils_end

    function new(string name = "int_exp_transaction");
        super.new(name);
    endfunction
endclass

class int_scoreboard extends uvm_scoreboard;
    `uvm_component_utils(int_scoreboard)

    uvm_analysis_imp #(int_transaction, int_scoreboard) item_collected_export;
    uvm_analysis_imp #(int_exp_transaction, int_scoreboard) expected_export;

    // This queue stores the names of the interrupts we expect to see.
    // The sequence will send expected interrupts through TLM interface.
    string expected_interrupts[$];

    function new(string name = "int_scoreboard", uvm_component parent = null);
        super.new(name, parent);
        item_collected_export = new("item_collected_export", this);
        expected_export = new("expected_export", this);
    endfunction

    virtual function void write(int_transaction t);
        bit is_expected = 0;
        string expected_key;
        int match_index = -1;

        // Create a unique key for matching: "interrupt_name@destination"
        expected_key = $sformatf("%s@%s", t.interrupt_info.name, t.destination_name);

        `uvm_info(get_type_name(), $sformatf("Scoreboard received interrupt notification: %s", expected_key), UVM_MEDIUM)

        // Check if this interrupt was expected - improved search with better error handling
        foreach (expected_interrupts[i]) begin
            if (expected_interrupts[i] == expected_key) begin
                is_expected = 1;
                match_index = i;
                `uvm_info(get_type_name(), $sformatf("Successfully matched expected interrupt: %s", expected_key), UVM_HIGH)
                break;
            end
        end

        // Remove matched interrupt from expected queue
        if (is_expected && match_index >= 0) begin
            expected_interrupts.delete(match_index);
        end

        // If it was not found in the expected queue, it's an error.
        if (!is_expected) begin
            `uvm_error(get_type_name(), $sformatf("Detected an UNEXPECTED interrupt: '%s' was routed to '%s'. Current expected queue size: %0d",
                      t.interrupt_info.name, t.destination_name, expected_interrupts.size()))
            // Print current expected interrupts for debugging
            if (expected_interrupts.size() > 0) begin
                `uvm_info(get_type_name(), "Current expected interrupts:", UVM_MEDIUM)
                foreach (expected_interrupts[i]) begin
                    `uvm_info(get_type_name(), $sformatf("  [%0d]: %s", i, expected_interrupts[i]), UVM_MEDIUM)
                end
            end
        end
    endfunction
    
    // This function is called when an expected interrupt is registered through TLM
    virtual function void write_exp(int_exp_transaction t);
        add_expected(t.interrupt_info);
    endfunction

    // Add expected interrupts to the queue
    function void add_expected(interrupt_info_s info);
        int expected_count = 0;

        if (info.to_ap) begin
            expected_interrupts.push_back($sformatf("%s@%s", info.name, "AP"));
            expected_count++;
        end
        if (info.to_scp) begin
            expected_interrupts.push_back($sformatf("%s@%s", info.name, "SCP"));
            expected_count++;
        end
        if (info.to_mcp) begin
            expected_interrupts.push_back($sformatf("%s@%s", info.name, "MCP"));
            expected_count++;
        end
        if (info.to_imu) begin
            expected_interrupts.push_back($sformatf("%s@%s", info.name, "IMU"));
            expected_count++;
        end
        if (info.to_io) begin
            expected_interrupts.push_back($sformatf("%s@%s", info.name, "IO"));
            expected_count++;
        end
        if (info.to_other_die) begin
            expected_interrupts.push_back($sformatf("%s@%s", info.name, "OTHER_DIE"));
            expected_count++;
        end

        `uvm_info(get_type_name(), $sformatf("Added %0d expected destinations for interrupt '%s'",
                  expected_count, info.name), UVM_HIGH)

        if (expected_count == 0) begin
            `uvm_warning(get_type_name(), $sformatf("No destinations specified for interrupt '%s'", info.name))
        end
    endfunction
    
    // At the end of the test, check if any expected interrupts were NOT seen.
    function void check_phase(uvm_phase phase);
        super.check_phase(phase);
        if (expected_interrupts.size() > 0) begin
            `uvm_error(get_type_name(), $sformatf("Found %0d expected interrupts that were NEVER detected:", expected_interrupts.size()))
            foreach (expected_interrupts[i]) begin
                `uvm_info(get_type_name(), $sformatf(" - MISSING: %s", expected_interrupts[i]), UVM_NONE)
            end
        end
    endfunction

    // Check for any remaining expected interrupts at the end of test
    virtual function void check_phase(uvm_phase phase);
        super.check_phase(phase);

        if (expected_interrupts.size() > 0) begin
            `uvm_error(get_type_name(), $sformatf("Test completed with %0d undetected expected interrupts:",
                      expected_interrupts.size()))
            foreach (expected_interrupts[i]) begin
                `uvm_error(get_type_name(), $sformatf("  Missing interrupt: %s", expected_interrupts[i]))
            end
        end else begin
            `uvm_info(get_type_name(), "All expected interrupts were successfully detected", UVM_MEDIUM)
        end
    endfunction

    // Report phase for final statistics
    virtual function void report_phase(uvm_phase phase);
        super.report_phase(phase);
        `uvm_info(get_type_name(), "=== Interrupt Verification Summary ===", UVM_LOW)
        `uvm_info(get_type_name(), $sformatf("Remaining expected interrupts: %0d", expected_interrupts.size()), UVM_LOW)
    endfunction

endclass

`endif // INT_SCOREBOARD_SV
