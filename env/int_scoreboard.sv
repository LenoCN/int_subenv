`ifndef INT_SCOREBOARD_SV
`define INT_SCOREBOARD_SV

`include "seq/int_transaction.sv"

class int_scoreboard extends uvm_scoreboard;
    `uvm_component_utils(int_scoreboard)

    uvm_analysis_imp #(int_transaction, int_scoreboard) item_collected_export;
    
    // This queue stores the names of the interrupts we expect to see.
    // The sequence that forces an interrupt will add the name to this queue.
    static string expected_interrupts[$];

    function new(string name = "int_scoreboard", uvm_component parent = null);
        super.new(name, parent);
        item_collected_export = new("item_collected_export", this);
    endfunction

    virtual function void write(int_transaction t);
        bit is_expected = 0;
        string expected_key;

        // Create a unique key for matching: "interrupt_name@destination"
        expected_key = $sformatf("%s@%s", t.interrupt_info.name, t.destination_name);
        
        `uvm_info(get_type_name(), $sformatf("Scoreboard received interrupt notification: %s", expected_key), UVM_MEDIUM)

        // Check if this interrupt was expected
        foreach (expected_interrupts[i]) begin
            if (expected_interrupts[i] == expected_key) begin
                is_expected = 1;
                expected_interrupts.delete(i); // Remove it as it has been seen
                `uvm_info(get_type_name(), $sformatf("Successfully matched expected interrupt: %s", expected_key), UVM_HIGH)
                break;
            end
        end

        // If it was not found in the expected queue, it's an error.
        if (!is_expected) begin
            `uvm_error(get_type_name(), $sformatf("Detected an UNEXPECTED interrupt: '%s' was routed to '%s'", t.interrupt_info.name, t.destination_name))
        end
    endfunction
    
    // This function will be called by the sequence to register an expectation.
    static function void add_expected(interrupt_info_s info);
        if (info.to_ap) expected_interrupts.push_back($sformatf("%s@%s", info.name, "AP"));
        if (info.to_scp) expected_interrupts.push_back($sformatf("%s@%s", info.name, "SCP"));
        if (info.to_mcp) expected_interrupts.push_back($sformatf("%s@%s", info.name, "MCP"));
        if (info.to_imu) expected_interrupts.push_back($sformatf("%s@%s", info.name, "IMU"));
        if (info.to_io) expected_interrupts.push_back($sformatf("%s@%s", info.name, "IO"));
        if (info.to_other_die) expected_interrupts.push_back($sformatf("%s@%s", info.name, "OTHER_DIE"));
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

endclass

`endif // INT_SCOREBOARD_SV
