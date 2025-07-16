`ifndef TC_MERGE_INTERRUPT_TEST_SV
`define TC_MERGE_INTERRUPT_TEST_SV

// Test case specifically for testing merge interrupt functionality
class tc_merge_interrupt_test extends int_base_test;
    `uvm_component_utils(tc_merge_interrupt_test)

    function new(string name = "tc_merge_interrupt_test", uvm_component parent = null);
        super.new(name, parent);
    endfunction

    virtual function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        `uvm_info(get_type_name(), "Building merge interrupt test", UVM_MEDIUM)
    endfunction

    virtual task run_phase(uvm_phase phase);
        merge_interrupt_sequence seq;
        
        phase.raise_objection(this);
        
        `uvm_info(get_type_name(), "Starting merge interrupt test", UVM_MEDIUM)
        
        seq = merge_interrupt_sequence::type_id::create("seq");
        seq.start(env.m_sequencer);
        
        #5us; // Allow time for all checks to complete
        
        `uvm_info(get_type_name(), "Merge interrupt test completed", UVM_MEDIUM)
        
        phase.drop_objection(this);
    endtask

endclass

// Sequence specifically for testing merge interrupts
class merge_interrupt_sequence extends int_base_sequence;
    `uvm_object_utils(merge_interrupt_sequence)

    function new(string name = "merge_interrupt_sequence");
        super.new(name);
    endfunction

    virtual task body();
        interrupt_info_s merge_interrupts[];
        
        // Build the interrupt model database
        int_routing_model::build();

        if (int_routing_model::interrupt_map.size() == 0) begin
            `uvm_warning(get_type_name(), "Interrupt map is empty. No checks will be performed.")
            return;
        end

        `uvm_info(get_type_name(), "Starting merge interrupt testing", UVM_MEDIUM)
        
        // Find all merge interrupts
        foreach (int_routing_model::interrupt_map[i]) begin
            if (int_routing_model::is_merge_interrupt(int_routing_model::interrupt_map[i].name)) begin
                merge_interrupts.push_back(int_routing_model::interrupt_map[i]);
            end
        end
        
        `uvm_info(get_type_name(), $sformatf("Found %0d merge interrupts to test", merge_interrupts.size()), UVM_MEDIUM)
        
        // Test each merge interrupt
        foreach (merge_interrupts[i]) begin
            test_single_merge_interrupt(merge_interrupts[i]);
        end

    endtask

    // Task to test a single merge interrupt comprehensively
    virtual task test_single_merge_interrupt(interrupt_info_s merge_info);
        interrupt_info_s source_interrupts[];
        int num_sources;
        
        `uvm_info(get_type_name(), $sformatf("Testing merge interrupt: %s", merge_info.name), UVM_MEDIUM)
        
        // Get all source interrupts for this merge interrupt
        num_sources = int_routing_model::get_merge_sources(merge_info.name, source_interrupts);
        
        if (num_sources == 0) begin
            `uvm_warning(get_type_name(), $sformatf("No source interrupts found for merge interrupt '%s'", merge_info.name));
            return;
        end
        
        `uvm_info(get_type_name(), $sformatf("Testing %0d source interrupts for merge interrupt '%s'", num_sources, merge_info.name), UVM_MEDIUM)
        
        // Print all source interrupts for this merge interrupt
        foreach (source_interrupts[i]) begin
            `uvm_info(get_type_name(), $sformatf("  Source %0d: %s (group: %s)", i, source_interrupts[i].name, source_interrupts[i].group.name()), UVM_HIGH)
        end
        
        // Test each source interrupt individually
        foreach (source_interrupts[i]) begin
            test_merge_source_individual(merge_info, source_interrupts[i]);
        end
        
        // Test multiple sources simultaneously (if we have valid sources)
        test_merge_multiple_sources(merge_info, source_interrupts);
    endtask

    // Task to test a single source interrupt for merge logic
    virtual task test_merge_source_individual(interrupt_info_s merge_info, interrupt_info_s source_info);
        `uvm_info(get_type_name(), $sformatf("Testing individual source: %s -> %s", source_info.name, merge_info.name), UVM_HIGH)
        
        // Skip if source path is empty (placeholder)
        if (source_info.rtl_path_src == "") begin
            `uvm_info(get_type_name(), $sformatf("Source path for interrupt '%s' is empty (placeholder). Skipping individual test.", source_info.name), UVM_HIGH);
            return;
        end
        
        // Register expectation for the merge interrupt (not the source)
        int_scoreboard::add_expected(merge_info);
        
        // Force the source interrupt
        uvm_hdl_force(source_info.rtl_path_src, 1);
        #10ns; // Wait for propagation through merge logic
        
        // Release the source interrupt
        uvm_hdl_release(source_info.rtl_path_src);
        #10ns; // Wait for release to propagate
    endtask

    // Task to test multiple source interrupts simultaneously
    virtual task test_merge_multiple_sources(interrupt_info_s merge_info, interrupt_info_s source_interrupts[]);
        int valid_sources = 0;
        
        // Count valid sources (those with non-empty RTL paths)
        foreach (source_interrupts[i]) begin
            if (source_interrupts[i].rtl_path_src != "") begin
                valid_sources++;
            end
        end
        
        if (valid_sources < 2) begin
            `uvm_info(get_type_name(), $sformatf("Not enough valid sources (%0d) for multi-source test of merge interrupt '%s'", valid_sources, merge_info.name), UVM_HIGH);
            return;
        end
        
        `uvm_info(get_type_name(), $sformatf("Testing %0d sources simultaneously for merge interrupt: %s", valid_sources, merge_info.name), UVM_HIGH)
        
        // Register expectation for the merge interrupt
        int_scoreboard::add_expected(merge_info);
        
        // Force all valid source interrupts simultaneously
        foreach (source_interrupts[i]) begin
            if (source_interrupts[i].rtl_path_src != "") begin
                uvm_hdl_force(source_interrupts[i].rtl_path_src, 1);
            end
        end
        
        #10ns; // Wait for propagation through merge logic
        
        // Release all source interrupts
        foreach (source_interrupts[i]) begin
            if (source_interrupts[i].rtl_path_src != "") begin
                uvm_hdl_release(source_interrupts[i].rtl_path_src);
            end
        end
        
        #10ns; // Wait for release to propagate
    endtask

endclass

`endif // TC_MERGE_INTERRUPT_TEST_SV
