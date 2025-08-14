`ifndef INT_LIGHTWEIGHT_SEQUENCE_SV
`define INT_LIGHTWEIGHT_SEQUENCE_SV

// Lightweight interrupt routing sequence that uses driver for stimulus generation
// This sequence focuses on decision logic while delegating stimulus details to the driver
class int_lightweight_sequence extends int_base_sequence;
    `uvm_object_utils(int_lightweight_sequence)

    function new(string name = "int_lightweight_sequence");
        super.new(name);
    endfunction

    // Helper function to check if interrupt routing should be skipped
    // Skip interrupts that have no routing destinations (merge sources)
    // Skip interrupts that only route to other_die or io destinations
    // Skip interrupts from SCP that only route to SCP
    // Skip interrupts from MCP that only route to MCP
    virtual function bit should_skip_interrupt_check(interrupt_info_s info);
        bit has_any_destinations = 0;
        bit has_other_destinations = 0;

        // Check if interrupt has any destinations at all
        if (info.to_ap || info.to_scp || info.to_mcp || info.to_accel || info.to_io || info.to_other_die) begin
            has_any_destinations = 1;
        end

        // Skip interrupts with no destinations - they are merge sources and should be handled in merge logic
        if (!has_any_destinations) begin
            `uvm_info(get_type_name(), $sformatf("Skipping interrupt '%s' - no routing destinations (merge source)",
                     info.name), UVM_MEDIUM)
            return 1;
        end

        // Check if interrupt has destinations other than to_other_die and to_io
        if (info.to_ap || info.to_scp || info.to_mcp || info.to_accel) begin
            has_other_destinations = 1;
        end

        // Skip ONLY if interrupt routes to other_die or io AND has no other destinations
        if (!has_other_destinations && (info.to_other_die || info.to_io)) begin
            `uvm_info(get_type_name(), $sformatf("Skipping interrupt '%s' - only routes to other_die(%0d) or io(%0d)",
                     info.name, info.to_other_die, info.to_io), UVM_MEDIUM)
            return 1;
        end
        
        // Skip interrupts from SCP that only route to SCP
        if (info.group == SCP && info.to_scp == 1 &&
            info.to_ap == 0 && info.to_mcp == 0 && info.to_accel == 0 &&
            info.to_io == 0 && info.to_other_die == 0) begin
            `uvm_info(get_type_name(), $sformatf("Skipping interrupt '%s' - from SCP and only routes to SCP",
                     info.name), UVM_MEDIUM)
            return 1;
        end

        // Skip interrupts from MCP that only route to MCP
        if (info.group == MCP && info.to_mcp == 1 &&
            info.to_ap == 0 && info.to_scp == 0 && info.to_accel == 0 &&
            info.to_io == 0 && info.to_other_die == 0) begin
            `uvm_info(get_type_name(), $sformatf("Skipping interrupt '%s' - from MCP and only routes to MCP",
                     info.name), UVM_MEDIUM)
            return 1;
        end

        return 0;
    endfunction

    virtual task body();
        `uvm_info(get_type_name(), "Starting lightweight interrupt sequence execution", UVM_LOW)
        
        // Build the interrupt model database
        `uvm_info(get_type_name(), "Building interrupt routing model database", UVM_HIGH)
        m_routing_model.build();

        if (m_routing_model.interrupt_map.size() == 0) begin
            `uvm_warning(get_type_name(), "Interrupt map is empty. No checks will be performed.")
            return;
        end
        #10us;
        `uvm_info(get_type_name(), $sformatf("Starting lightweight interrupt routing check for %0d interrupts",
                  m_routing_model.interrupt_map.size()), UVM_LOW)

        // Iterate over all interrupts in the model and check their routing
        `uvm_info(get_type_name(), "Beginning iteration through all interrupts in the model", UVM_DEBUG)
        foreach (m_routing_model.interrupt_map[i]) begin
            `uvm_info(get_type_name(), $sformatf("Processing interrupt %0d of %0d: %s",
                     i+1, m_routing_model.interrupt_map.size(),
                     m_routing_model.interrupt_map[i].name), UVM_DEBUG)
            check_interrupt_routing(m_routing_model.interrupt_map[i]);
        end

        `uvm_info(get_type_name(), "Lightweight interrupt routing check completed successfully", UVM_LOW)
    endtask

    // Main routing check - much simpler than the original version
    virtual task check_interrupt_routing(interrupt_info_s info);
        `uvm_info(get_type_name(), $sformatf("Checking interrupt: %s (group: %s, index: %0d, trigger: %s, polarity: %s)",
                  info.name, info.group.name(), info.index, info.trigger.name(), info.polarity.name()), UVM_MEDIUM)

        // Check if this is a merge interrupt
        if (m_routing_model.is_merge_interrupt(info.name)) begin
            `uvm_info(get_type_name(), $sformatf("Interrupt %s identified as a merge interrupt", info.name), UVM_HIGH)
            check_merge_interrupt_routing(info);
        end else begin
            `uvm_info(get_type_name(), $sformatf("Interrupt %s identified as a single interrupt", info.name), UVM_HIGH)
            // Simple single interrupt test
            test_single_interrupt(info);
        end
        
        `uvm_info(get_type_name(), $sformatf("Completed routing check for interrupt: %s", info.name), UVM_HIGH)
    endtask

    // Test a single interrupt using the driver
    virtual task test_single_interrupt(interrupt_info_s info);
        int_stimulus_item stim_item;

        `uvm_info(get_type_name(), $sformatf(" SINGLE INTERRUPT TEST START: %s", info.name), UVM_MEDIUM)

        if (info.rtl_path_src == "") begin
            `uvm_warning(get_type_name(), $sformatf("Source path for interrupt '%s' is empty. Skipping.", info.name));
            return;
        end

        // Skip interrupts that only route to other_die or io destinations
        if (should_skip_interrupt_check(info)) begin
            return;
        end

        `uvm_info(get_type_name(), $sformatf("RTL source path for interrupt %s: %s",
                 info.name, info.rtl_path_src), UVM_HIGH)
        
        // REFACTORED: Use high-level interface to handle all routing paths automatically
        `uvm_info(get_type_name(), $sformatf("Adding all expected interrupts for: %s", info.name), UVM_MEDIUM)
        add_all_expected_interrupts(info);

        // Create and send stimulus item to driver
        `uvm_info(get_type_name(), $sformatf("Creating ASSERT stimulus for interrupt: %s", info.name), UVM_HIGH)
        stim_item = int_stimulus_item::create_stimulus(info, STIMULUS_ASSERT);
        
        `uvm_info(get_type_name(), $sformatf("Sending ASSERT stimulus for interrupt: %s", info.name), UVM_DEBUG)
        start_item(stim_item);
        finish_item(stim_item);

        // REFACTORED: Use high-level interface to wait for all routing paths automatically
        `uvm_info(get_type_name(), "Waiting for propagation through merge logic", UVM_DEBUG)
        #10ns; // Wait for propagation through merge logic

        `uvm_info(get_type_name(), $sformatf("Waiting for all expected interrupts for: %s", info.name), UVM_MEDIUM)
        wait_for_all_expected_interrupts(info);

        // REFACTORED: Use high-level interface to update all interrupt status automatically
        `uvm_info(get_type_name(), $sformatf("Updating all interrupt status for: %s", info.name), UVM_HIGH)
        update_all_interrupt_status(info);

        // Send clear command to driver (simulates software clearing)
        `uvm_info(get_type_name(), $sformatf("Creating CLEAR stimulus for interrupt: %s", info.name), UVM_HIGH)
        stim_item = int_stimulus_item::create_stimulus(info, STIMULUS_CLEAR);
        
        `uvm_info(get_type_name(), $sformatf("Sending CLEAR stimulus for interrupt: %s", info.name), UVM_DEBUG)
        start_item(stim_item);
        finish_item(stim_item);

        `uvm_info(get_type_name(), $sformatf("Waiting for clear propagation of interrupt: %s", info.name), UVM_DEBUG)
        #10ns; // Wait for clear to propagate
        
        `uvm_info(get_type_name(), $sformatf("Completed testing of single interrupt: %s", info.name), UVM_MEDIUM)
    endtask

    // Simplified merge interrupt handling
    virtual task check_merge_interrupt_routing(interrupt_info_s merge_info);
        interrupt_info_s source_interrupts[$];
        int num_sources;

        `uvm_info(get_type_name(), $sformatf("Checking merge interrupt: %s", merge_info.name), UVM_LOW)

        // Get all source interrupts that should be merged into this interrupt
        `uvm_info(get_type_name(), $sformatf("Retrieving source interrupts for merge interrupt: %s",
                 merge_info.name), UVM_HIGH)
        num_sources = m_routing_model.get_merge_sources(merge_info.name, source_interrupts);

        if (num_sources == 0) begin
            `uvm_error(get_type_name(), $sformatf("No source interrupts found for merge interrupt '%s'", merge_info.name));
            return;
        end

        `uvm_info(get_type_name(), $sformatf("Found %0d source interrupts for merge interrupt '%s'",
                  num_sources, merge_info.name), UVM_MEDIUM)

        // Test each source interrupt individually
        `uvm_info(get_type_name(), $sformatf("Testing each source interrupt individually for merge interrupt: %s",
                 merge_info.name), UVM_HIGH)
        foreach (source_interrupts[i]) begin
            `uvm_info(get_type_name(), $sformatf("Testing source interrupt %0d of %0d: %s",
                     i+1, num_sources, source_interrupts[i].name), UVM_DEBUG)
            test_merge_source(merge_info, source_interrupts[i]);
        end

        // Test multiple sources simultaneously if there are multiple sources
        if (num_sources > 1) begin
            `uvm_info(get_type_name(), $sformatf("Testing multiple sources simultaneously for merge interrupt: %s",
                     merge_info.name), UVM_MEDIUM)
            test_multiple_merge_sources(merge_info, source_interrupts);
        end

        `uvm_info(get_type_name(), $sformatf("Completed merge interrupt routing check for: %s",
                 merge_info.name), UVM_LOW)
    endtask

    // Test multiple merge sources simultaneously - REFACTORED
    virtual task test_multiple_merge_sources(interrupt_info_s merge_info, interrupt_info_s source_interrupts[]);
        int_stimulus_item stim_item;
        interrupt_info_s valid_sources[$]; // Queue to store only valid, stimulatable sources

        `uvm_info(get_type_name(), $sformatf("MULTI-SOURCE MERGE TEST: Testing %0d sources for merge interrupt '%s'",
                 source_interrupts.size(), merge_info.name), UVM_LOW)

        // 1. Filter out invalid or non-stimulatable sources
        `uvm_info(get_type_name(), "Filtering for valid source interrupts with RTL paths", UVM_DEBUG)
        foreach (source_interrupts[i]) begin
            if (source_interrupts[i].rtl_path_src != "" && !m_routing_model.is_merge_interrupt(source_interrupts[i].name)) begin
                valid_sources.push_back(source_interrupts[i]);
            end else begin
                `uvm_info(get_type_name(), $sformatf("Skipping source '%s' (empty path or is a merge interrupt itself)", source_interrupts[i].name), UVM_HIGH);
            end
        end

        if (valid_sources.size() < 2) begin
            `uvm_warning(get_type_name(), $sformatf("Not enough valid sources (%0d) for multi-source test of merge interrupt '%s'. Test skipped.",
                      valid_sources.size(), merge_info.name));
            return;
        end

        `uvm_info(get_type_name(), $sformatf("Found %0d valid sources for multi-source test of merge interrupt '%s'",
                 valid_sources.size(), merge_info.name), UVM_MEDIUM)

        // Skip merge interrupts that only route to other_die or io destinations
        if (should_skip_interrupt_check(merge_info)) begin
             `uvm_info(get_type_name(), $sformatf("Skipping multi-source test for '%s' due to destination filter.", merge_info.name), UVM_MEDIUM);
            return;
        end

        // 2. Set expectations and assert all valid source interrupts simultaneously
        `uvm_info(get_type_name(), $sformatf("Asserting %0d source interrupts simultaneously", valid_sources.size()), UVM_MEDIUM)
        
        // --- Set expectations first ---
        foreach (valid_sources[i]) begin
             add_all_expected_interrupts(valid_sources[i]);
        end

        // --- Then, assert them all ---
        foreach (valid_sources[i]) begin
            `uvm_info(get_type_name(), $sformatf("Sending ASSERT stimulus for source: %s", valid_sources[i].name), UVM_DEBUG)
            stim_item = int_stimulus_item::create_stimulus(valid_sources[i], STIMULUS_ASSERT);
            start_item(stim_item);
            finish_item(stim_item);
        end

        `uvm_info(get_type_name(), "Waiting for propagation through merge logic...", UVM_DEBUG)
        #10ns;

        // 3. Wait for all expected interrupts from all sources
        `uvm_info(get_type_name(), $sformatf("Waiting for all interrupts resulting from %0d sources", valid_sources.size()), UVM_MEDIUM)
        begin
            fork
                foreach (valid_sources[i]) begin
                    automatic int j = i;
                    fork
                       wait_for_all_expected_interrupts(valid_sources[j]);
                    join_none
                end
            join
        end

        // 4. Update status for all affected interrupts
        `uvm_info(get_type_name(), "Updating status for all affected interrupts...", UVM_HIGH)
        foreach (valid_sources[i]) begin
            update_all_interrupt_status(valid_sources[i]);
        end

        // 5. Clear all source interrupts
        `uvm_info(get_type_name(), "Clearing all source interrupts...", UVM_MEDIUM)
        foreach (valid_sources[i]) begin
            `uvm_info(get_type_name(), $sformatf("Sending CLEAR stimulus for source: %s", valid_sources[i].name), UVM_DEBUG)
            stim_item = int_stimulus_item::create_stimulus(valid_sources[i], STIMULUS_CLEAR);
            start_item(stim_item);
            finish_item(stim_item);
        end

        `uvm_info(get_type_name(), "Waiting for clear to propagate...", UVM_DEBUG)
        #10ns;
        
        `uvm_info(get_type_name(), $sformatf("Completed multi-source test for merge interrupt: %s",
                 merge_info.name), UVM_LOW)
    endtask

    // Test single merge source using driver
    virtual task test_merge_source(interrupt_info_s merge_info, interrupt_info_s source_info);
        int_stimulus_item stim_item;

        `uvm_info(get_type_name(), $sformatf("MERGE SOURCE TEST: %s -> %s", source_info.name, merge_info.name), UVM_MEDIUM)

        if (source_info.rtl_path_src == "") begin
            `uvm_warning(get_type_name(), $sformatf("Source path for merge source '%s' is empty. Skipping.", source_info.name));
            return;
        end

        // Skip merge interrupts that only route to other_die or io destinations
        if (should_skip_interrupt_check(merge_info)) begin
            `uvm_info(get_type_name(), $sformatf("Skipping merge test for '%s' due to destination filter.", merge_info.name), UVM_MEDIUM);
            return;
        end

         if (m_routing_model.is_merge_interrupt(source_info.name)) begin
            `uvm_info(get_type_name(), $sformatf("⚠️  Skipping direct stimulus for merge source '%s' as it is itself a merge interrupt. It will be tested via its own sources.", source_info.name), UVM_MEDIUM)
            return;
        end

        // 1. (ROBUST) Add all expectations for the entire merge chain starting from the source
        `uvm_info(get_type_name(), $sformatf("Adding all hierarchical expectations for source: %s", source_info.name), UVM_MEDIUM)
        add_all_expected_interrupts(source_info);

        // 2. (ROBUST) Send stimulus for the source interrupt
        `uvm_info(get_type_name(), $sformatf("Creating ASSERT stimulus for source: %s", source_info.name), UVM_HIGH)
        stim_item = int_stimulus_item::create_stimulus(source_info, STIMULUS_ASSERT);
        
        start_item(stim_item);
        finish_item(stim_item);

        `uvm_info(get_type_name(), "Waiting a bit for propagation through merge logic...", UVM_DEBUG)
        #10ns;

        // 3. (ROBUST) Wait for all interrupts in the merge chain to be detected
        `uvm_info(get_type_name(), $sformatf("Waiting for all hierarchical interrupts from source: %s", source_info.name), UVM_MEDIUM)
        wait_for_all_expected_interrupts(source_info);

        // 4. (ROBUST) Update status for all affected interrupts in the model
        `uvm_info(get_type_name(), $sformatf("Updating all hierarchical statuses for source: %s", source_info.name), UVM_HIGH)
        update_all_interrupt_status(source_info);

        // 5. (ROBUST) Clear the source interrupt stimulus
        `uvm_info(get_type_name(), $sformatf("Creating CLEAR stimulus for source: %s", source_info.name), UVM_HIGH)
        stim_item = int_stimulus_item::create_stimulus(source_info, STIMULUS_CLEAR);
        
        start_item(stim_item);
        finish_item(stim_item);

        `uvm_info(get_type_name(), "Waiting for clear to propagate...", UVM_DEBUG)
        #10ns;
        
        `uvm_info(get_type_name(), $sformatf("Completed testing of merge source: %s -> %s",
                 source_info.name, merge_info.name), UVM_MEDIUM)
    endtask

endclass

`endif // INT_LIGHTWEIGHT_SEQUENCE_SV
