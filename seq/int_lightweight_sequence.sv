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
        bit is_iosub_normal_source = 0;
        interrupt_info_s iosub_normal_info;

        `uvm_info(get_type_name(), $sformatf("Testing single interrupt: %s", info.name), UVM_MEDIUM)

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

        // CRITICAL FIX: Check if this interrupt is an iosub_normal_intr aggregation source
        is_iosub_normal_source = m_routing_model.is_iosub_normal_intr_source(info.name);

        if (is_iosub_normal_source) begin
            `uvm_info(get_type_name(), $sformatf("SINGLE INTERRUPT DUAL ROUTING: %s is iosub_normal_intr source",
                     info.name), UVM_MEDIUM)

            // Get iosub_normal_intr info for merge expectation
            foreach (m_routing_model.interrupt_map[i]) begin
                if (m_routing_model.interrupt_map[i].name == "iosub_normal_intr") begin
                    iosub_normal_info = m_routing_model.interrupt_map[i];
                    break;
                end
            end

            // Register expectation for iosub_normal_intr (merge routing to SCP/MCP)
            `uvm_info(get_type_name(), $sformatf("SINGLE INTERRUPT DUAL ROUTING: Registering iosub_normal_intr expectation for source: %s",
                     info.name), UVM_MEDIUM)
            add_expected_with_mask(iosub_normal_info);
        end

        // Register expectations for the source interrupt itself (direct routing)
        `uvm_info(get_type_name(), $sformatf("Registering expected interrupt with mask consideration: %s", info.name), UVM_HIGH)
        add_expected_with_mask(info);

        // Create and send stimulus item to driver
        `uvm_info(get_type_name(), $sformatf("Creating ASSERT stimulus for interrupt: %s", info.name), UVM_HIGH)
        stim_item = int_stimulus_item::create_stimulus(info, STIMULUS_ASSERT);

        `uvm_info(get_type_name(), $sformatf("Sending ASSERT stimulus for interrupt: %s", info.name), UVM_DEBUG)
        start_item(stim_item);
        finish_item(stim_item);

        // CRITICAL FIX: Wait for BOTH direct routing AND merge routing (if applicable)
        if (is_iosub_normal_source) begin
            `uvm_info(get_type_name(), "Waiting for propagation through merge logic", UVM_DEBUG)
            #10ns; // Wait for propagation through merge logic

            // Wait for iosub_normal_intr merge interrupt detection first
            `uvm_info(get_type_name(), $sformatf("SINGLE INTERRUPT DUAL ROUTING: Waiting for iosub_normal_intr detection from source: %s",
                     info.name), UVM_MEDIUM)
            wait_for_interrupt_detection_with_mask(iosub_normal_info);
        end

        `uvm_info(get_type_name(), $sformatf("Waiting for detection of interrupt: %s", info.name), UVM_HIGH)
        // Wait for interrupt to be detected by monitor using mask-aware approach for consistency
        wait_for_interrupt_detection_with_mask(info);

        // CRITICAL FIX: Update status for BOTH interrupts (if applicable)
        if (is_iosub_normal_source) begin
            // Update iosub_normal_intr status
            `uvm_info(get_type_name(), $sformatf("SINGLE INTERRUPT DUAL ROUTING: Updating iosub_normal_intr status from source: %s",
                     info.name), UVM_HIGH)
            m_routing_model.update_interrupt_status("iosub_normal_intr", 1, m_register_model);
        end

        // Update status register to reflect source interrupt occurrence
        m_routing_model.update_interrupt_status(info.name, 1, m_register_model);

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
        interrupt_info_s source_interrupts[];
        int num_sources;

        `uvm_info(get_type_name(), $sformatf("Checking merge interrupt: %s", merge_info.name), UVM_LOW)

        // Get all source interrupts that should be merged into this interrupt
        `uvm_info(get_type_name(), $sformatf("Retrieving source interrupts for merge interrupt: %s",
                 merge_info.name), UVM_HIGH)
        num_sources = m_routing_model.get_merge_sources(merge_info.name, source_interrupts);

        if (num_sources == 0) begin
            `uvm_warning(get_type_name(), $sformatf("No source interrupts found for merge interrupt '%s'", merge_info.name));
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

    // Test single merge source using driver
    virtual task test_merge_source(interrupt_info_s merge_info, interrupt_info_s source_info);
        int_stimulus_item stim_item;
        bit source_has_direct_routing = 0;

        `uvm_info(get_type_name(), $sformatf("Testing merge source: %s -> %s", source_info.name, merge_info.name), UVM_MEDIUM)

        if (source_info.rtl_path_src == "") begin
            `uvm_warning(get_type_name(), $sformatf("Source path for merge source '%s' is empty. Skipping.", source_info.name));
            return;
        end

        // Skip merge interrupts that only route to other_die or io destinations
        if (should_skip_interrupt_check(merge_info)) begin
            return;
        end

        `uvm_info(get_type_name(), $sformatf("RTL source path for merge source %s: %s",
                 source_info.name, source_info.rtl_path_src), UVM_HIGH)

        // Check if source interrupt has its own direct routing (excluding SCP/MCP which are handled via merge)
        source_has_direct_routing = (source_info.to_ap || source_info.to_accel || source_info.to_io || source_info.to_other_die);

        `uvm_info(get_type_name(), $sformatf("Source interrupt %s direct routing: AP=%b, ACCEL=%b, IO=%b, OTHER_DIE=%b (has_direct=%b)",
                 source_info.name, source_info.to_ap, source_info.to_accel, source_info.to_io, source_info.to_other_die, source_has_direct_routing), UVM_HIGH)

        // Register expectation for the merge interrupt (for SCP/MCP routing via iosub_normal_intr)
        `uvm_info(get_type_name(), $sformatf("Registering expected merge interrupt with mask: %s (from source: %s)",
                 merge_info.name, source_info.name), UVM_HIGH)
        add_expected_with_mask(merge_info);

        // CRITICAL FIX: Also register expectation for source interrupt's direct routing
        // This ensures we expect responses for both merge routing (SCP/MCP) AND direct routing (AP/ACCEL/etc)
        if (source_has_direct_routing) begin
            `uvm_info(get_type_name(), $sformatf("DUAL EXPECTATION: Registering expected source interrupt with direct routing: %s",
                     source_info.name), UVM_MEDIUM)
            add_expected_with_mask(source_info);
        end

        // Send stimulus for source interrupt
        `uvm_info(get_type_name(), $sformatf("Creating ASSERT stimulus for source interrupt: %s", source_info.name), UVM_HIGH)
        stim_item = int_stimulus_item::create_stimulus(source_info, STIMULUS_ASSERT);

        `uvm_info(get_type_name(), $sformatf("Sending ASSERT stimulus for source interrupt: %s", source_info.name), UVM_DEBUG)
        start_item(stim_item);
        finish_item(stim_item);

        `uvm_info(get_type_name(), "Waiting for propagation through merge logic", UVM_DEBUG)
        #10ns; // Wait for propagation through merge logic

        // CRITICAL FIX: Wait for BOTH merge interrupt AND source interrupt direct routing
        // Wait for merge interrupt to be detected (for SCP/MCP routing)
        `uvm_info(get_type_name(), $sformatf("Waiting for detection of merge interrupt: %s", merge_info.name), UVM_HIGH)
        wait_for_interrupt_detection_with_mask(merge_info);

        // DUAL DETECTION: Also wait for source interrupt's direct routing (for AP/ACCEL/etc)
        if (source_has_direct_routing) begin
            `uvm_info(get_type_name(), $sformatf("DUAL DETECTION: Waiting for detection of source interrupt direct routing: %s",
                     source_info.name), UVM_MEDIUM)
            wait_for_interrupt_detection_with_mask(source_info);
        end

        // Update status register to reflect merge interrupt occurrence
        m_routing_model.update_interrupt_status(merge_info.name, 1, m_register_model);

        // DUAL STATUS UPDATE: Also update source interrupt status if it has direct routing
        if (source_has_direct_routing) begin
            `uvm_info(get_type_name(), $sformatf("DUAL STATUS: Updating status for source interrupt direct routing: %s",
                     source_info.name), UVM_HIGH)
            m_routing_model.update_interrupt_status(source_info.name, 1, m_register_model);
        end

        // Clear the source interrupt
        `uvm_info(get_type_name(), $sformatf("Creating CLEAR stimulus for source interrupt: %s", source_info.name), UVM_HIGH)
        stim_item = int_stimulus_item::create_stimulus(source_info, STIMULUS_CLEAR);

        `uvm_info(get_type_name(), $sformatf("Sending CLEAR stimulus for source interrupt: %s", source_info.name), UVM_DEBUG)
        start_item(stim_item);
        finish_item(stim_item);

        `uvm_info(get_type_name(), "Waiting for clear to propagate", UVM_DEBUG)
        #10ns; // Wait for clear to propagate
        
        `uvm_info(get_type_name(), $sformatf("Completed testing of merge source: %s -> %s",
                 source_info.name, merge_info.name), UVM_MEDIUM)
    endtask

    // Test multiple merge sources simultaneously
    virtual task test_multiple_merge_sources(interrupt_info_s merge_info, interrupt_info_s source_interrupts[]);
        int_stimulus_item stim_item;
        int valid_sources = 0;

        `uvm_info(get_type_name(), $sformatf("Testing multiple sources simultaneously for merge interrupt: %s",
                 merge_info.name), UVM_LOW)

        // Count valid sources
        `uvm_info(get_type_name(), "Counting valid source interrupts with RTL paths", UVM_DEBUG)
        foreach (source_interrupts[i]) begin
            if (source_interrupts[i].rtl_path_src != "") begin
                valid_sources++;
            end
        end

        if (valid_sources < 2) begin
            `uvm_warning(get_type_name(), $sformatf("Not enough valid sources (%0d) for multi-source test of merge interrupt '%s'",
                      valid_sources, merge_info.name));
            return;
        end

        `uvm_info(get_type_name(), $sformatf("Found %0d valid sources for multi-source test of merge interrupt: %s",
                 valid_sources, merge_info.name), UVM_MEDIUM)

        // Skip merge interrupts that only route to other_die or io destinations
        if (should_skip_interrupt_check(merge_info)) begin
            return;
        end

        // Register expectation for the merge interrupt with mask consideration
        `uvm_info(get_type_name(), $sformatf("Registering expected merge interrupt with mask: %s for multi-source test",
                 merge_info.name), UVM_HIGH)
        add_expected_with_mask(merge_info);

        // CRITICAL FIX: Also register expectations for source interrupts with direct routing
        `uvm_info(get_type_name(), "MULTI-SOURCE DUAL EXPECTATION: Checking for source interrupts with direct routing", UVM_MEDIUM)
        foreach (source_interrupts[i]) begin
            if (source_interrupts[i].rtl_path_src != "") begin
                bit source_has_direct_routing = (source_interrupts[i].to_ap || source_interrupts[i].to_accel ||
                                                source_interrupts[i].to_io || source_interrupts[i].to_other_die);
                if (source_has_direct_routing) begin
                    `uvm_info(get_type_name(), $sformatf("MULTI-SOURCE DUAL EXPECTATION: Registering direct routing expectation for: %s",
                             source_interrupts[i].name), UVM_MEDIUM)
                    add_expected_with_mask(source_interrupts[i]);
                end
            end
        end

        // Assert all valid source interrupts simultaneously
        `uvm_info(get_type_name(), $sformatf("Asserting %0d source interrupts simultaneously", valid_sources), UVM_MEDIUM)
        foreach (source_interrupts[i]) begin
            if (source_interrupts[i].rtl_path_src != "") begin
                `uvm_info(get_type_name(), $sformatf("Creating ASSERT stimulus for source interrupt: %s",
                         source_interrupts[i].name), UVM_HIGH)
                stim_item = int_stimulus_item::create_stimulus(source_interrupts[i], STIMULUS_ASSERT);

                `uvm_info(get_type_name(), $sformatf("Sending ASSERT stimulus for source interrupt: %s",
                         source_interrupts[i].name), UVM_DEBUG)
                start_item(stim_item);
                finish_item(stim_item);
            end
        end

        `uvm_info(get_type_name(), "Waiting for propagation through merge logic", UVM_DEBUG)
        #10ns; // Wait for propagation through merge logic

        // Wait for merge interrupt to be detected
        `uvm_info(get_type_name(), $sformatf("Waiting for detection of merge interrupt: %s from multiple sources",
                 merge_info.name), UVM_HIGH)
        wait_for_interrupt_detection_with_mask(merge_info);

        // CRITICAL FIX: Also wait for source interrupts with direct routing
        `uvm_info(get_type_name(), "MULTI-SOURCE DUAL DETECTION: Waiting for source interrupts with direct routing", UVM_MEDIUM)
        foreach (source_interrupts[i]) begin
            if (source_interrupts[i].rtl_path_src != "") begin
                bit source_has_direct_routing = (source_interrupts[i].to_ap || source_interrupts[i].to_accel ||
                                                source_interrupts[i].to_io || source_interrupts[i].to_other_die);
                if (source_has_direct_routing) begin
                    `uvm_info(get_type_name(), $sformatf("MULTI-SOURCE DUAL DETECTION: Waiting for direct routing of: %s",
                             source_interrupts[i].name), UVM_MEDIUM)
                    wait_for_interrupt_detection_with_mask(source_interrupts[i]);
                end
            end
        end

        // Update status register to reflect merge interrupt occurrence
        m_routing_model.update_interrupt_status(merge_info.name, 1, m_register_model);

        // CRITICAL FIX: Also update status for source interrupts with direct routing
        `uvm_info(get_type_name(), "MULTI-SOURCE DUAL STATUS: Updating status for source interrupts with direct routing", UVM_MEDIUM)
        foreach (source_interrupts[i]) begin
            if (source_interrupts[i].rtl_path_src != "") begin
                bit source_has_direct_routing = (source_interrupts[i].to_ap || source_interrupts[i].to_accel ||
                                                source_interrupts[i].to_io || source_interrupts[i].to_other_die);
                if (source_has_direct_routing) begin
                    `uvm_info(get_type_name(), $sformatf("MULTI-SOURCE DUAL STATUS: Updating status for: %s",
                             source_interrupts[i].name), UVM_HIGH)
                    m_routing_model.update_interrupt_status(source_interrupts[i].name, 1, m_register_model);
                end
            end
        end

        // Clear all source interrupts
        `uvm_info(get_type_name(), "Clearing all source interrupts", UVM_MEDIUM)
        foreach (source_interrupts[i]) begin
            if (source_interrupts[i].rtl_path_src != "") begin
                `uvm_info(get_type_name(), $sformatf("Creating CLEAR stimulus for source interrupt: %s",
                         source_interrupts[i].name), UVM_HIGH)
                stim_item = int_stimulus_item::create_stimulus(source_interrupts[i], STIMULUS_CLEAR);
                
                `uvm_info(get_type_name(), $sformatf("Sending CLEAR stimulus for source interrupt: %s",
                         source_interrupts[i].name), UVM_DEBUG)
                start_item(stim_item);
                finish_item(stim_item);
            end
        end

        `uvm_info(get_type_name(), "Waiting for clear to propagate", UVM_DEBUG)
        #10ns; // Wait for clear to propagate
        
        `uvm_info(get_type_name(), $sformatf("Completed multi-source test for merge interrupt: %s",
                 merge_info.name), UVM_LOW)
    endtask

endclass

`endif // INT_LIGHTWEIGHT_SEQUENCE_SV
