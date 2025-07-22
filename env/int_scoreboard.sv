`ifndef INT_SCOREBOARD_SV
`define INT_SCOREBOARD_SV

// Declare custom analysis imp for expected transactions
`uvm_analysis_imp_decl(_exp)

// Transaction class for expected interrupt notifications
class int_exp_transaction extends uvm_sequence_item;
    interrupt_info_s interrupt_info;

    // Note: UVM field automation removed because interrupt_info_s is a struct, not a UVM object
    // uvm_field_object can only be used with objects that extend uvm_object
    `uvm_object_utils(int_exp_transaction)

    function new(string name = "int_exp_transaction");
        super.new(name);
    endfunction
endclass

class int_scoreboard extends uvm_scoreboard;
    `uvm_component_utils(int_scoreboard)

    uvm_analysis_imp #(int_transaction, int_scoreboard) item_collected_export;
    uvm_analysis_imp_exp #(int_exp_transaction, int_scoreboard) expected_export;

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

        `uvm_info(get_type_name(), "=== SCOREBOARD INTERRUPT PROCESSING ===", UVM_MEDIUM)
        `uvm_info(get_type_name(), $sformatf("Received interrupt transaction: %s", expected_key), UVM_MEDIUM)
        `uvm_info(get_type_name(), $sformatf("  - Interrupt Name: %s", t.interrupt_info.name), UVM_MEDIUM)
        `uvm_info(get_type_name(), $sformatf("  - Group: %s", t.interrupt_info.group.name()), UVM_MEDIUM)
        `uvm_info(get_type_name(), $sformatf("  - Index: %0d", t.interrupt_info.index), UVM_MEDIUM)
        `uvm_info(get_type_name(), $sformatf("  - Destination: %s", t.destination_name), UVM_MEDIUM)
        `uvm_info(get_type_name(), $sformatf("  - Trigger: %s", t.interrupt_info.trigger.name()), UVM_MEDIUM)
        `uvm_info(get_type_name(), $sformatf("  - Polarity: %s", t.interrupt_info.polarity.name()), UVM_MEDIUM)
        `uvm_info(get_type_name(), $sformatf("Current expected queue size: %0d", expected_interrupts.size()), UVM_MEDIUM)

        // Print all expected interrupts for debugging
        if (expected_interrupts.size() > 0) begin
            `uvm_info(get_type_name(), "Current expected interrupts in queue:", UVM_MEDIUM)
            foreach (expected_interrupts[i]) begin
                `uvm_info(get_type_name(), $sformatf("  [%0d]: %s", i, expected_interrupts[i]), UVM_MEDIUM)
            end
        end else begin
            `uvm_info(get_type_name(), "Expected interrupts queue is EMPTY", UVM_MEDIUM)
        end

        // Check if this interrupt was expected - improved search with better error handling
        `uvm_info(get_type_name(), $sformatf("Searching for match: %s", expected_key), UVM_MEDIUM)
        foreach (expected_interrupts[i]) begin
            `uvm_info(get_type_name(), $sformatf("  Comparing with [%0d]: %s", i, expected_interrupts[i]), UVM_HIGH)
            if (expected_interrupts[i] == expected_key) begin
                is_expected = 1;
                match_index = i;
                `uvm_info(get_type_name(), $sformatf("✅ MATCH FOUND at index [%0d]: %s", match_index, expected_key), UVM_MEDIUM)
                break;
            end
        end

        // Remove matched interrupt from expected queue
        if (is_expected && match_index >= 0) begin
            expected_interrupts.delete(match_index);
            `uvm_info(get_type_name(), $sformatf("Removed matched interrupt from queue. New queue size: %0d", expected_interrupts.size()), UVM_MEDIUM)
        end

        // If it was not found in the expected queue, it's an error.
        if (!is_expected) begin
            `uvm_info(get_type_name(), "❌ NO MATCH FOUND - This is an UNEXPECTED interrupt!", UVM_MEDIUM)
            `uvm_error(get_type_name(), $sformatf("Detected an UNEXPECTED interrupt: '%s' was routed to '%s'. Current expected queue size: %0d",
                      t.interrupt_info.name, t.destination_name, expected_interrupts.size()))

            // Print detailed debugging information
            `uvm_info(get_type_name(), "=== DEBUGGING INFORMATION ===", UVM_MEDIUM)
            `uvm_info(get_type_name(), $sformatf("Expected key format: %s", expected_key), UVM_MEDIUM)
            `uvm_info(get_type_name(), $sformatf("Interrupt routing configuration for %s:", t.interrupt_info.name), UVM_MEDIUM)
            `uvm_info(get_type_name(), $sformatf("  - to_ap: %0d, to_scp: %0d, to_mcp: %0d", t.interrupt_info.to_ap, t.interrupt_info.to_scp, t.interrupt_info.to_mcp), UVM_MEDIUM)
            `uvm_info(get_type_name(), $sformatf("  - to_imu: %0d, to_io: %0d, to_other_die: %0d", t.interrupt_info.to_imu, t.interrupt_info.to_io, t.interrupt_info.to_other_die), UVM_MEDIUM)

            if (expected_interrupts.size() > 0) begin
                `uvm_info(get_type_name(), "All expected interrupts in queue:", UVM_MEDIUM)
                foreach (expected_interrupts[i]) begin
                    `uvm_info(get_type_name(), $sformatf("  [%0d]: '%s' (length: %0d)", i, expected_interrupts[i], expected_interrupts[i].len()), UVM_MEDIUM)
                end
                // Analyze for patterns
                analyze_unexpected_interrupt(t);
            end else begin
                `uvm_info(get_type_name(), "Expected interrupts queue is EMPTY - no interrupts were registered!", UVM_MEDIUM)
                `uvm_info(get_type_name(), "This suggests the test sequence did not register any expected interrupts.", UVM_MEDIUM)
            end
        end

        `uvm_info(get_type_name(), "=== END SCOREBOARD PROCESSING ===", UVM_MEDIUM)
    endfunction
    
    // This function is called when an expected interrupt is registered through TLM
    virtual function void write_exp(int_exp_transaction t);
        add_expected(t.interrupt_info);
    endfunction

    // Add expected interrupts to the queue
    function void add_expected(interrupt_info_s info);
        int expected_count = 0;
        string caller_info;

        `uvm_info(get_type_name(), "=== ADDING EXPECTED INTERRUPT ===", UVM_MEDIUM)
        `uvm_info(get_type_name(), $sformatf("Adding expected interrupt: %s", info.name), UVM_MEDIUM)
        `uvm_info(get_type_name(), $sformatf("  - Group: %s", info.group.name()), UVM_MEDIUM)
        `uvm_info(get_type_name(), $sformatf("  - Index: %0d", info.index), UVM_MEDIUM)
        `uvm_info(get_type_name(), $sformatf("  - Trigger: %s", info.trigger.name()), UVM_MEDIUM)
        `uvm_info(get_type_name(), $sformatf("  - Polarity: %s", info.polarity.name()), UVM_MEDIUM)

        `uvm_info(get_type_name(), "Destination routing configuration:", UVM_MEDIUM)
        `uvm_info(get_type_name(), $sformatf("  - to_ap: %0d", info.to_ap), UVM_MEDIUM)
        `uvm_info(get_type_name(), $sformatf("  - to_scp: %0d", info.to_scp), UVM_MEDIUM)
        `uvm_info(get_type_name(), $sformatf("  - to_mcp: %0d", info.to_mcp), UVM_MEDIUM)
        `uvm_info(get_type_name(), $sformatf("  - to_imu: %0d", info.to_imu), UVM_MEDIUM)
        `uvm_info(get_type_name(), $sformatf("  - to_io: %0d", info.to_io), UVM_MEDIUM)
        `uvm_info(get_type_name(), $sformatf("  - to_other_die: %0d", info.to_other_die), UVM_MEDIUM)

        if (info.to_ap) begin
            expected_interrupts.push_back($sformatf("%s@%s", info.name, "AP"));
            expected_count++;
            `uvm_info(get_type_name(), $sformatf("  ✅ Added expected: %s@AP", info.name), UVM_MEDIUM)
        end
        if (info.to_scp) begin
            expected_interrupts.push_back($sformatf("%s@%s", info.name, "SCP"));
            expected_count++;
            `uvm_info(get_type_name(), $sformatf("  ✅ Added expected: %s@SCP", info.name), UVM_MEDIUM)
        end
        if (info.to_mcp) begin
            expected_interrupts.push_back($sformatf("%s@%s", info.name, "MCP"));
            expected_count++;
            `uvm_info(get_type_name(), $sformatf("  ✅ Added expected: %s@MCP", info.name), UVM_MEDIUM)
        end
        if (info.to_imu) begin
            expected_interrupts.push_back($sformatf("%s@%s", info.name, "IMU"));
            expected_count++;
            `uvm_info(get_type_name(), $sformatf("  ✅ Added expected: %s@IMU", info.name), UVM_MEDIUM)
        end
        if (info.to_io) begin
            expected_interrupts.push_back($sformatf("%s@%s", info.name, "IO"));
            expected_count++;
            `uvm_info(get_type_name(), $sformatf("  ✅ Added expected: %s@IO", info.name), UVM_MEDIUM)
        end
        if (info.to_other_die) begin
            expected_interrupts.push_back($sformatf("%s@%s", info.name, "OTHER_DIE"));
            expected_count++;
            `uvm_info(get_type_name(), $sformatf("  ✅ Added expected: %s@OTHER_DIE", info.name), UVM_MEDIUM)
        end

        `uvm_info(get_type_name(), $sformatf("Total expected destinations added: %0d for interrupt '%s'",
                  expected_count, info.name), UVM_MEDIUM)
        `uvm_info(get_type_name(), $sformatf("New expected queue size: %0d", expected_interrupts.size()), UVM_MEDIUM)

        if (expected_count == 0) begin
            `uvm_warning(get_type_name(), $sformatf("⚠️  No destinations specified for interrupt '%s' - this interrupt will not be expected!", info.name))
        end

        `uvm_info(get_type_name(), "=== END ADDING EXPECTED INTERRUPT ===", UVM_MEDIUM)
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

    // Generic function to analyze unexpected interrupt patterns
    function void analyze_unexpected_interrupt(int_transaction t);
        string interrupt_pattern;
        int similar_count = 0;

        `uvm_info(get_type_name(), $sformatf("🔍 === UNEXPECTED INTERRUPT ANALYSIS: %s ===", t.interrupt_info.name), UVM_HIGH)

        // Look for similar interrupt patterns in expected queue
        interrupt_pattern = t.interrupt_info.name;
        foreach (expected_interrupts[i]) begin
            if (expected_interrupts[i].substr(0, interrupt_pattern.len()-1) == interrupt_pattern.substr(0, interrupt_pattern.len()-1)) begin
                similar_count++;
                `uvm_info(get_type_name(), $sformatf("  - Similar pattern found: %s", expected_interrupts[i]), UVM_HIGH)
            end
        end

        if (similar_count == 0) begin
            `uvm_info(get_type_name(), $sformatf("No similar interrupt patterns found for %s", t.interrupt_info.name), UVM_HIGH)
            `uvm_info(get_type_name(), "This suggests the interrupt was not expected at all", UVM_HIGH)
        end else begin
            `uvm_info(get_type_name(), $sformatf("Found %0d similar patterns - possible destination mismatch", similar_count), UVM_HIGH)
        end

        `uvm_info(get_type_name(), $sformatf("🔍 === END ANALYSIS: %s ===", t.interrupt_info.name), UVM_HIGH)
    endfunction

endclass

`endif // INT_SCOREBOARD_SV
