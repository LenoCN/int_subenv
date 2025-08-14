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
    
    bit expected_interrupts_aa[string];  // key: "name@dest" → exists=1

    uvm_analysis_imp #(int_transaction, int_scoreboard) item_collected_export;
    uvm_analysis_imp_exp #(int_exp_transaction, int_scoreboard) expected_export;

    // This queue stores the names of the interrupts we expect to see.
    // The sequence will send expected interrupts through TLM interface.

    function new(string name = "int_scoreboard", uvm_component parent = null);
        super.new(name, parent);
        item_collected_export = new("item_collected_export", this);
        expected_export = new("expected_export", this);
    endfunction

    virtual function void write(int_transaction t);
        bit is_expected = 0;
        string expected_key;
        string remaining[$];  // 获取所有剩余键

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

        // 新增：手动用 foreach 遍历键，填充 remaining
        foreach (expected_interrupts_aa[key]) begin
            remaining.push_back(key);  // 添加每个剩余键到 queue
        end
        `uvm_info(get_type_name(), $sformatf("Current expected queue size: %0d", remaining.size()), UVM_MEDIUM)

        if (remaining.size() > 0) begin
            foreach (remaining[i]) begin
                `uvm_info(get_type_name(), $sformatf("  [%0d]: %s", i, remaining[i]), UVM_MEDIUM)
            end
        end else begin
            `uvm_info(get_type_name(), "Expected interrupts queue is EMPTY", UVM_MEDIUM)
        end

        if (expected_interrupts_aa.exists(expected_key)) begin
            expected_interrupts_aa.delete(expected_key);
            is_expected = 1;
            `uvm_info(get_type_name(), $sformatf("✅ MATCH FOUND and removed: %s", expected_key), UVM_MEDIUM)
        end

        // If it was not found in the expected queue, it's an error.
        if (!is_expected) begin
            `uvm_info(get_type_name(), "❌ NO MATCH FOUND - This is an UNEXPECTED interrupt!", UVM_MEDIUM)
            `uvm_error(get_type_name(), $sformatf("Detected an UNEXPECTED interrupt: '%s' was routed to '%s'. Current expected queue size: %0d",
                      t.interrupt_info.name, t.destination_name, remaining.size()))

            // Print detailed debugging information
            `uvm_info(get_type_name(), "=== DEBUGGING INFORMATION ===", UVM_MEDIUM)
            `uvm_info(get_type_name(), $sformatf("Expected key format: %s", expected_key), UVM_MEDIUM)
            `uvm_info(get_type_name(), $sformatf("Interrupt routing configuration for %s:", t.interrupt_info.name), UVM_MEDIUM)
            `uvm_info(get_type_name(), $sformatf("  - to_ap: %0d, to_scp: %0d, to_mcp: %0d", t.interrupt_info.to_ap, t.interrupt_info.to_scp, t.interrupt_info.to_mcp), UVM_MEDIUM)
            `uvm_info(get_type_name(), $sformatf("  - to_accel: %0d, to_io: %0d, to_other_die: %0d", t.interrupt_info.to_accel, t.interrupt_info.to_io, t.interrupt_info.to_other_die), UVM_MEDIUM)

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
        string key;

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
        `uvm_info(get_type_name(), $sformatf("  - to_accel: %0d", info.to_accel), UVM_MEDIUM)
        `uvm_info(get_type_name(), $sformatf("  - to_io: %0d", info.to_io), UVM_MEDIUM)
        `uvm_info(get_type_name(), $sformatf("  - to_other_die: %0d", info.to_other_die), UVM_MEDIUM)

        if (info.to_ap) begin
            key = $sformatf("%s@%s", info.name, "AP");
            if (!expected_interrupts_aa.exists(key)) begin
                expected_interrupts_aa[key] = 1;
                expected_count++;
                `uvm_info(get_type_name(), $sformatf("  ✅ Added unique expected: %s", key), UVM_MEDIUM)
            end else begin
                `uvm_info(get_type_name(), $sformatf("  ℹ️  Skipped duplicate expected: %s", key), UVM_HIGH)
            end
        end
        if (info.to_scp) begin
            key = $sformatf("%s@%s", info.name, "SCP");
            if (!expected_interrupts_aa.exists(key)) begin
                expected_interrupts_aa[key] = 1;
                expected_count++;
                `uvm_info(get_type_name(), $sformatf("  ✅ Added unique expected: %s", key), UVM_MEDIUM)
            end else begin
                `uvm_info(get_type_name(), $sformatf("  ℹ️  Skipped duplicate expected: %s", key), UVM_HIGH)
            end
        end
        if (info.to_mcp) begin
            key = $sformatf("%s@%s", info.name, "MCP");
            if (!expected_interrupts_aa.exists(key)) begin
                expected_interrupts_aa[key] = 1;
                expected_count++;
                `uvm_info(get_type_name(), $sformatf("  ✅ Added unique expected: %s", key), UVM_MEDIUM)
            end else begin
                `uvm_info(get_type_name(), $sformatf("  ℹ️  Skipped duplicate expected: %s", key), UVM_HIGH)
            end
        end
        if (info.to_accel) begin
            key = $sformatf("%s@%s", info.name, "ACCEL");
            if (!expected_interrupts_aa.exists(key)) begin
                expected_interrupts_aa[key] = 1;
                expected_count++;
                `uvm_info(get_type_name(), $sformatf("  ✅ Added unique expected: %s", key), UVM_MEDIUM)
            end else begin
                `uvm_info(get_type_name(), $sformatf("  ℹ️  Skipped duplicate expected: %s", key), UVM_HIGH)
            end
        end
        if (info.to_io) begin
            key = $sformatf("%s@%s", info.name, "IO");
            if (!expected_interrupts_aa.exists(key)) begin
                expected_interrupts_aa[key] = 1;
                expected_count++;
                `uvm_info(get_type_name(), $sformatf("  ✅ Added unique expected: %s", key), UVM_MEDIUM)
            end else begin
                `uvm_info(get_type_name(), $sformatf("  ℹ️  Skipped duplicate expected: %s", key), UVM_HIGH)
            end
        end
        if (info.to_other_die) begin
            key = $sformatf("%s@%s", info.name, "OTHER_DIE");
            if (!expected_interrupts_aa.exists(key)) begin
                expected_interrupts_aa[key] = 1;
                expected_count++;
                `uvm_info(get_type_name(), $sformatf("  ✅ Added unique expected: %s", key), UVM_MEDIUM)
            end else begin
                `uvm_info(get_type_name(), $sformatf("  ℹ️  Skipped duplicate expected: %s", key), UVM_HIGH)
            end
        end

        `uvm_info(get_type_name(), $sformatf("Total expected destinations added: %0d for interrupt '%s'",
                  expected_count, info.name), UVM_MEDIUM)

        if (expected_count == 0) begin
            `uvm_warning(get_type_name(), $sformatf("⚠️  No destinations specified for interrupt '%s' - this interrupt will not be expected!", info.name))
        end

        `uvm_info(get_type_name(), "=== END ADDING EXPECTED INTERRUPT ===", UVM_MEDIUM)
    endfunction
    
    // Check for any remaining expected interrupts at the end of test
    virtual function void check_phase(uvm_phase phase);
        string remaining[$];
        super.check_phase(phase);

        // 新增：手动用 foreach 遍历键，填充 remaining
        foreach (expected_interrupts_aa[key]) begin
            remaining.push_back(key);  // 添加每个剩余键到 queue
        end
        `uvm_info(get_type_name(), $sformatf("Current expected queue size: %0d", remaining.size()), UVM_MEDIUM)

        if (remaining.size() > 0) begin
            `uvm_error(get_type_name(), $sformatf("Test completed with %0d undetected expected interrupts:", remaining.size()))
            foreach (remaining[i]) begin
                `uvm_error(get_type_name(), $sformatf("  Missing interrupt: %s", remaining[i]))
            end
        end else begin
            `uvm_info(get_type_name(), "All expected interrupts were successfully detected", UVM_MEDIUM)
        end

    endfunction

    // Report phase for final statistics
    virtual function void report_phase(uvm_phase phase);
        super.report_phase(phase);
    endfunction

endclass

`endif // INT_SCOREBOARD_SV
