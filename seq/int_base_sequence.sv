`ifndef INT_BASE_SEQUENCE
`define INT_BASE_SEQUENCE

class int_base_sequence extends uvm_sequence;
    `uvm_object_utils(int_base_sequence)

    // Event manager for interrupt detection handshake
    int_event_manager event_manager;

    // Model object references
    int_register_model m_register_model;
    int_routing_model  m_routing_model;

    function new(string name = "int_base_sequence");
        super.new(name);
    endfunction

    // Get event manager in pre_start
    task pre_start();
        super.pre_start();

        `uvm_info(get_type_name(), "Starting interrupt sequence initialization", UVM_LOW)

        // Get event manager from config DB
        // Use m_sequencer as the starting point since event_manager is set in the subenv
        if (!uvm_config_db#(int_event_manager)::get(m_sequencer, "", "event_manager", event_manager)) begin
            `uvm_error(get_type_name(), "Failed to get event_manager from config DB")
        end else begin
            `uvm_info(get_type_name(), "Successfully retrieved event_manager from config DB", UVM_HIGH)
        end

        // Get model objects from config DB (set by test case)
        if (!uvm_config_db#(int_register_model)::get(m_sequencer, "", "register_model", m_register_model)) begin
            `uvm_fatal(get_type_name(), "Failed to get register_model from config DB - should be set by test case")
        end else begin
            `uvm_info(get_type_name(), "Successfully retrieved register_model from config DB", UVM_HIGH)
        end

        if (!uvm_config_db#(int_routing_model)::get(m_sequencer, "", "routing_model", m_routing_model)) begin
            `uvm_fatal(get_type_name(), "Failed to get routing_model from config DB - should be set by test case")
        end else begin
            `uvm_info(get_type_name(), "Successfully retrieved routing_model from config DB", UVM_HIGH)
        end
        
        `uvm_info(get_type_name(), "Interrupt sequence initialization completed", UVM_LOW)
    endtask

    // Helper task to wait for interrupt detection with configurable timeout
    task wait_for_interrupt_detection(interrupt_info_s info, int timeout_ns = -1);
        // Use global timing config if no specific timeout provided
        if (timeout_ns == -1) begin
            init_timing_config();
            timeout_ns = global_timing_config.detection_timeout_ns;
        end

        `uvm_info(get_type_name(), $sformatf("Waiting for interrupt detection: %s (group: %s, index: %0d) with timeout %0d ns",
                 info.name, info.group.name(), info.index, timeout_ns), UVM_MEDIUM)
                 
        if (event_manager != null) begin
            `uvm_info(get_type_name(), $sformatf("Starting wait for interrupt: %s", info.name), UVM_HIGH)
            event_manager.wait_for_interrupt_detection(info, timeout_ns);
            `uvm_info(get_type_name(), $sformatf("Interrupt detected: %s", info.name), UVM_LOW)
        end else begin
            `uvm_error(get_type_name(), "event_manager is null in wait_for_interrupt_detection")
            `uvm_info(get_type_name(), "Using fallback delay of 10ns due to null event_manager", UVM_HIGH)
            #10ns; // Fallback delay
        end
    endtask

    // Helper task to wait for interrupt detection with mask consideration
    // This ensures consistency with add_expected_with_mask behavior
    task wait_for_interrupt_detection_with_mask(interrupt_info_s info, int timeout_ns = -1);
        string expected_destinations[$];
        interrupt_info_s masked_info;

        `uvm_info(get_type_name(), "=== SEQUENCE WAITING FOR INTERRUPT WITH MASK ===", UVM_MEDIUM)
        `uvm_info(get_type_name(), $sformatf("Sequence '%s' waiting for interrupt with mask: %s", get_sequence_path(), info.name), UVM_MEDIUM)
        `uvm_info(get_type_name(), $sformatf("📊 Original interrupt routing: AP=%b, SCP=%b, MCP=%b, ACCEL=%b, IO=%b, OTHER_DIE=%b",
                  info.to_ap, info.to_scp, info.to_mcp, info.to_accel, info.to_io, info.to_other_die), UVM_MEDIUM)

        // Use global timing config if no specific timeout provided
        if (timeout_ns == -1) begin
            init_timing_config();
            timeout_ns = global_timing_config.detection_timeout_ns;
        end

        // Get expected destinations considering masks
        `uvm_info(get_type_name(), $sformatf("🔍 Calling routing model to get expected destinations with mask for: %s", info.name), UVM_HIGH)
        m_routing_model.get_expected_destinations_with_mask(info.name, expected_destinations, m_register_model);

        if (expected_destinations.size() == 0) begin
            `uvm_info(get_type_name(), $sformatf("⚠️  Interrupt '%s' is completely masked - no wait needed", info.name), UVM_MEDIUM)
            `uvm_info(get_type_name(), $sformatf("📋 This means all destinations are either not routed or masked by registers"), UVM_MEDIUM)
            `uvm_info(get_type_name(), "=== END SEQUENCE WAIT FOR INTERRUPT WITH MASK ===", UVM_MEDIUM)
            return;
        end

        `uvm_info(get_type_name(), $sformatf("✅ Found %0d expected destinations after mask filtering:", expected_destinations.size()), UVM_MEDIUM)
        foreach (expected_destinations[i]) begin
            `uvm_info(get_type_name(), $sformatf("  ✅ %s", expected_destinations[i]), UVM_MEDIUM)
        end

        // Create modified info with only unmasked destinations
        `uvm_info(get_type_name(), $sformatf("🔧 Creating masked interrupt info for wait: %s", info.name), UVM_HIGH)
        masked_info = info;
        masked_info.to_ap = 0;
        masked_info.to_scp = 0;
        masked_info.to_mcp = 0;
        masked_info.to_accel = 0;
        masked_info.to_io = 0;
        masked_info.to_other_die = 0;

        // Set only the unmasked destinations
        `uvm_info(get_type_name(), $sformatf("🎯 Setting unmasked destinations for wait: %s", info.name), UVM_HIGH)
        foreach (expected_destinations[i]) begin
            case (expected_destinations[i])
                "AP": begin
                    masked_info.to_ap = 1;
                    `uvm_info(get_type_name(), $sformatf("✅ Enabled AP destination for wait %s", info.name), UVM_HIGH)
                end
                "SCP": begin
                    masked_info.to_scp = 1;
                    `uvm_info(get_type_name(), $sformatf("✅ Enabled SCP destination for wait %s", info.name), UVM_HIGH)
                end
                "MCP": begin
                    masked_info.to_mcp = 1;
                    `uvm_info(get_type_name(), $sformatf("✅ Enabled MCP destination for wait %s", info.name), UVM_HIGH)
                end
                "ACCEL": begin
                    masked_info.to_accel = 1;
                    `uvm_info(get_type_name(), $sformatf("✅ Enabled ACCEL destination for wait %s", info.name), UVM_HIGH)
                end
                "IO": begin
                    masked_info.to_io = 1;
                    `uvm_info(get_type_name(), $sformatf("✅ Enabled IO destination for wait %s", info.name), UVM_HIGH)
                end
                "OTHER_DIE": begin
                    masked_info.to_other_die = 1;
                    `uvm_info(get_type_name(), $sformatf("✅ Enabled OTHER_DIE destination for wait %s", info.name), UVM_HIGH)
                end
            endcase
        end

        `uvm_info(get_type_name(), $sformatf("📊 Final masked interrupt routing for wait: AP=%b, SCP=%b, MCP=%b, ACCEL=%b, IO=%b, OTHER_DIE=%b",
                  masked_info.to_ap, masked_info.to_scp, masked_info.to_mcp, masked_info.to_accel, masked_info.to_io, masked_info.to_other_die), UVM_MEDIUM)

        // Wait for the masked interrupt using the original wait function
        `uvm_info(get_type_name(), $sformatf("📝 Waiting for masked interrupt: %s with timeout %0d ns", info.name, timeout_ns), UVM_HIGH)
        wait_for_interrupt_detection(masked_info, timeout_ns);

        `uvm_info(get_type_name(), $sformatf("✅ Mask-aware wait completed for interrupt: %s", info.name), UVM_MEDIUM)
        `uvm_info(get_type_name(), "=== END SEQUENCE WAIT FOR INTERRUPT WITH MASK ===", UVM_MEDIUM)
    endtask

    // Helper function to add expected interrupt
    function void add_expected(interrupt_info_s info);
        int_exp_transaction exp_trans;
        int_sequencer int_seq;
        string caller_info;

        `uvm_info(get_type_name(), "=== SEQUENCE ADDING EXPECTED INTERRUPT ===", UVM_MEDIUM)
        `uvm_info(get_type_name(), $sformatf("Sequence '%s' adding expected interrupt: %s", get_type_name(), info.name), UVM_MEDIUM)
        `uvm_info(get_type_name(), $sformatf("  - Group: %s", info.group.name()), UVM_MEDIUM)
        `uvm_info(get_type_name(), $sformatf("  - Index: %0d", info.index), UVM_MEDIUM)
        `uvm_info(get_type_name(), $sformatf("  - Trigger: %s", info.trigger.name()), UVM_MEDIUM)
        `uvm_info(get_type_name(), $sformatf("  - Polarity: %s", info.polarity.name()), UVM_MEDIUM)

        // Show routing configuration
        `uvm_info(get_type_name(), "Expected routing destinations:", UVM_MEDIUM)
        if (info.to_ap) `uvm_info(get_type_name(), "  ✅ AP", UVM_MEDIUM);
        if (info.to_scp) `uvm_info(get_type_name(), "  ✅ SCP", UVM_MEDIUM);
        if (info.to_mcp) `uvm_info(get_type_name(), "  ✅ MCP", UVM_MEDIUM);
        if (info.to_accel) `uvm_info(get_type_name(), "  ✅ ACCEL", UVM_MEDIUM);
        if (info.to_io) `uvm_info(get_type_name(), "  ✅ IO", UVM_MEDIUM);
        if (info.to_other_die) `uvm_info(get_type_name(), "  ✅ OTHER_DIE", UVM_MEDIUM);

        if (!info.to_ap && !info.to_scp && !info.to_mcp && !info.to_accel && !info.to_io && !info.to_other_die) begin
            `uvm_warning(get_type_name(), "  ⚠️  NO DESTINATIONS CONFIGURED - This interrupt will not be expected anywhere!");
        end

        // Cast sequencer to int_sequencer
        if (!$cast(int_seq, m_sequencer)) begin
            `uvm_error(get_type_name(), "Sequencer is not of type int_sequencer")
            return;
        end

        exp_trans = int_exp_transaction::type_id::create("exp_trans");
        exp_trans.interrupt_info = info;

        `uvm_info(get_type_name(), $sformatf("Sending expected interrupt transaction to scoreboard via TLM port"), UVM_MEDIUM)
        int_seq.expected_port.write(exp_trans);

        `uvm_info(get_type_name(), $sformatf("✅ Expected interrupt '%s' successfully registered with scoreboard", info.name), UVM_MEDIUM)
        `uvm_info(get_type_name(), "=== END SEQUENCE EXPECTED INTERRUPT ===", UVM_MEDIUM)
    endfunction

    // Add expected interrupt with mask consideration
    function void add_expected_with_mask(interrupt_info_s info);
        string expected_destinations[$];
        interrupt_info_s masked_info;

        `uvm_info(get_type_name(), "=== SEQUENCE ADDING EXPECTED INTERRUPT WITH MASK ===", UVM_MEDIUM)
        `uvm_info(get_type_name(), $sformatf("Sequence '%s' adding expected interrupt with mask: %s", get_sequence_path(), info.name), UVM_MEDIUM)
        `uvm_info(get_type_name(), $sformatf("📊 Original interrupt routing: AP=%b, SCP=%b, MCP=%b, ACCEL=%b, IO=%b, OTHER_DIE=%b",
                  info.to_ap, info.to_scp, info.to_mcp, info.to_accel, info.to_io, info.to_other_die), UVM_MEDIUM)

        // Get expected destinations considering masks
        `uvm_info(get_type_name(), $sformatf("🔍 Calling routing model to get expected destinations with mask for: %s", info.name), UVM_HIGH)
        m_routing_model.get_expected_destinations_with_mask(info.name, expected_destinations, m_register_model);

        if (expected_destinations.size() == 0) begin
            `uvm_info(get_type_name(), $sformatf("⚠️  Interrupt '%s' is completely masked - no expectations will be registered", info.name), UVM_MEDIUM)
            `uvm_info(get_type_name(), $sformatf("📋 This means all destinations are either not routed or masked by registers"), UVM_MEDIUM)
            `uvm_info(get_type_name(), "=== END SEQUENCE EXPECTED INTERRUPT WITH MASK ===", UVM_MEDIUM)
            return;
        end

        `uvm_info(get_type_name(), $sformatf("✅ Found %0d expected destinations after mask filtering:", expected_destinations.size()), UVM_MEDIUM)
        foreach (expected_destinations[i]) begin
            `uvm_info(get_type_name(), $sformatf("  ✅ %s", expected_destinations[i]), UVM_MEDIUM)
        end

        // Create modified info with only unmasked destinations
        `uvm_info(get_type_name(), $sformatf("🔧 Creating masked interrupt info for: %s", info.name), UVM_HIGH)
        masked_info = info;
        masked_info.to_ap = 0;
        masked_info.to_scp = 0;
        masked_info.to_mcp = 0;
        masked_info.to_accel = 0;
        masked_info.to_io = 0;
        masked_info.to_other_die = 0;

        // Set only the unmasked destinations
        `uvm_info(get_type_name(), $sformatf("🎯 Setting unmasked destinations for interrupt: %s", info.name), UVM_HIGH)
        foreach (expected_destinations[i]) begin
            case (expected_destinations[i])
                "AP": begin
                    masked_info.to_ap = 1;
                    `uvm_info(get_type_name(), $sformatf("✅ Enabled AP destination for %s", info.name), UVM_HIGH)
                end
                "SCP": begin
                    masked_info.to_scp = 1;
                    `uvm_info(get_type_name(), $sformatf("✅ Enabled SCP destination for %s", info.name), UVM_HIGH)
                end
                "MCP": begin
                    masked_info.to_mcp = 1;
                    `uvm_info(get_type_name(), $sformatf("✅ Enabled MCP destination for %s", info.name), UVM_HIGH)
                end
                "ACCEL": begin
                    masked_info.to_accel = 1;
                    `uvm_info(get_type_name(), $sformatf("✅ Enabled ACCEL destination for %s", info.name), UVM_HIGH)
                end
                "IO": begin
                    masked_info.to_io = 1;
                    `uvm_info(get_type_name(), $sformatf("✅ Enabled IO destination for %s", info.name), UVM_HIGH)
                end
                "OTHER_DIE": begin
                    masked_info.to_other_die = 1;
                    `uvm_info(get_type_name(), $sformatf("✅ Enabled OTHER_DIE destination for %s", info.name), UVM_HIGH)
                end
            endcase
        end

        `uvm_info(get_type_name(), $sformatf("📊 Final masked interrupt routing: AP=%b, SCP=%b, MCP=%b, ACCEL=%b, IO=%b, OTHER_DIE=%b",
                  masked_info.to_ap, masked_info.to_scp, masked_info.to_mcp, masked_info.to_accel, masked_info.to_io, masked_info.to_other_die), UVM_MEDIUM)

        // Register the masked expectation
        `uvm_info(get_type_name(), $sformatf("📝 Registering masked expectation for interrupt: %s", info.name), UVM_HIGH)
        add_expected(masked_info);

        `uvm_info(get_type_name(), "=== END SEQUENCE EXPECTED INTERRUPT WITH MASK ===", UVM_MEDIUM)
    endfunction

    // High-level function to add all expected interrupts for a given source interrupt
    // This automatically handles both direct routing and merge routing expectations
    function void add_all_expected_interrupts(interrupt_info_s source_info);
        string merge_interrupts[$];
        interrupt_info_s merge_info;

        `uvm_info(get_type_name(), "=== ADDING ALL EXPECTED INTERRUPTS ===", UVM_MEDIUM)
        `uvm_info(get_type_name(), $sformatf("Processing all routing paths for interrupt: %s", source_info.name), UVM_MEDIUM)

        // 1. Always add expectation for the source interrupt itself (direct routing)
        `uvm_info(get_type_name(), $sformatf("Adding direct routing expectation for: %s", source_info.name), UVM_HIGH)
        add_expected_with_mask(source_info);

        // 2. Check if this interrupt is a source for any merge interrupts
        m_routing_model.get_merge_interrupts_for_source(source_info.name, merge_interrupts);

        if (merge_interrupts.size() > 0) begin
            `uvm_info(get_type_name(), $sformatf("Found %0d merge interrupt(s) for source: %s", merge_interrupts.size(), source_info.name), UVM_MEDIUM)

            foreach (merge_interrupts[i]) begin
                `uvm_info(get_type_name(), $sformatf("Checking merge interrupt: %s", merge_interrupts[i]), UVM_HIGH)

                // Get merge interrupt info
                if (m_routing_model.get_merge_interrupt_info(merge_interrupts[i], merge_info)) begin
                    // Check if this source should trigger the merge interrupt expectation
                    if (m_register_model.should_expect_merge_interrupt(merge_interrupts[i], source_info.name, m_routing_model)) begin
                        `uvm_info(get_type_name(), $sformatf("Adding merge routing expectation: %s (from source: %s)", merge_interrupts[i], source_info.name), UVM_MEDIUM)
                        add_expected_with_mask(merge_info);
                    end else begin
                        `uvm_info(get_type_name(), $sformatf("🚫 Skipping merge expectation: %s (source %s blocked by mask)", merge_interrupts[i], source_info.name), UVM_MEDIUM)
                    end
                end else begin
                    `uvm_warning(get_type_name(), $sformatf("Could not find merge interrupt info for: %s", merge_interrupts[i]));
                end
            end
        end else begin
            `uvm_info(get_type_name(), $sformatf("No merge interrupts found for source: %s", source_info.name), UVM_HIGH)
        end

        `uvm_info(get_type_name(), "=== END ADDING ALL EXPECTED INTERRUPTS ===", UVM_MEDIUM)
    endfunction

    // High-level function to wait for all expected interrupts for a given source interrupt
    // This automatically handles both direct routing and merge routing waits
    task wait_for_all_expected_interrupts(interrupt_info_s source_info, int timeout_ns = -1);
        string merge_interrupts[$];
        interrupt_info_s merge_info;

        `uvm_info(get_type_name(), "=== WAITING FOR ALL EXPECTED INTERRUPTS ===", UVM_MEDIUM)
        `uvm_info(get_type_name(), $sformatf("Waiting for all routing paths for interrupt: %s", source_info.name), UVM_MEDIUM)

        // 1. Check if this interrupt is a source for any merge interrupts and wait for them first
        m_routing_model.get_merge_interrupts_for_source(source_info.name, merge_interrupts);

        if (merge_interrupts.size() > 0) begin
            `uvm_info(get_type_name(), $sformatf("Waiting for %0d merge interrupt(s) first", merge_interrupts.size()), UVM_MEDIUM)

            foreach (merge_interrupts[i]) begin
                if (m_routing_model.get_merge_interrupt_info(merge_interrupts[i], merge_info)) begin
                    if (m_register_model.should_expect_merge_interrupt(merge_interrupts[i], source_info.name, m_routing_model)) begin
                        `uvm_info(get_type_name(), $sformatf("Waiting for merge interrupt: %s (from source: %s)", merge_interrupts[i], source_info.name), UVM_MEDIUM)
                        wait_for_interrupt_detection_with_mask(merge_info, timeout_ns);
                    end else begin
                        `uvm_info(get_type_name(), $sformatf("🚫 Skipping merge wait: %s (source %s blocked by mask)", merge_interrupts[i], source_info.name), UVM_MEDIUM)
                    end
                end
            end
        end

        // 2. Wait for the source interrupt itself (direct routing)
        `uvm_info(get_type_name(), $sformatf("Waiting for direct routing of source interrupt: %s", source_info.name), UVM_HIGH)
        wait_for_interrupt_detection_with_mask(source_info, timeout_ns);

        `uvm_info(get_type_name(), "=== END WAITING FOR ALL EXPECTED INTERRUPTS ===", UVM_MEDIUM)
    endtask

    // High-level function to update status for all related interrupts
    task update_all_interrupt_status(interrupt_info_s source_info);
        string merge_interrupts[$];

        `uvm_info(get_type_name(), "=== UPDATING ALL INTERRUPT STATUS ===", UVM_MEDIUM)
        `uvm_info(get_type_name(), $sformatf("Updating status for all routing paths for interrupt: %s", source_info.name), UVM_MEDIUM)

        // 1. Update status for merge interrupts first
        m_routing_model.get_merge_interrupts_for_source(source_info.name, merge_interrupts);

        foreach (merge_interrupts[i]) begin
            if (m_register_model.should_expect_merge_interrupt(merge_interrupts[i], source_info.name, m_routing_model)) begin
                `uvm_info(get_type_name(), $sformatf("Updating merge interrupt status: %s (from source: %s)", merge_interrupts[i], source_info.name), UVM_HIGH)
                m_routing_model.update_interrupt_status(merge_interrupts[i], 1, m_register_model);
            end else begin
                `uvm_info(get_type_name(), $sformatf("🚫 Skipping merge status update: %s (source %s blocked by mask)", merge_interrupts[i], source_info.name), UVM_HIGH)
            end
        end

        // 2. Update status for the source interrupt itself
        `uvm_info(get_type_name(), $sformatf("Updating source interrupt status: %s", source_info.name), UVM_HIGH)
        m_routing_model.update_interrupt_status(source_info.name, 1, m_register_model);

        `uvm_info(get_type_name(), "=== END UPDATING ALL INTERRUPT STATUS ===", UVM_MEDIUM)
    endtask

    // High-level function for merge interrupt testing - handles both merge and direct routing expectations
    function void add_merge_test_expectations(interrupt_info_s merge_info, interrupt_info_s source_info);
        bit source_has_direct_routing;

        `uvm_info(get_type_name(), "=== ADDING MERGE TEST EXPECTATIONS ===", UVM_MEDIUM)
        `uvm_info(get_type_name(), $sformatf("Processing merge test for: %s -> %s", source_info.name, merge_info.name), UVM_MEDIUM)

        // 1. Add expectation for the merge interrupt if source should trigger it
        if (m_routing_model.should_trigger_merge_expectation(source_info.name, merge_info.name, m_register_model)) begin
            `uvm_info(get_type_name(), $sformatf("Adding merge expectation: %s (from source: %s)", merge_info.name, source_info.name), UVM_HIGH)
            add_expected_with_mask(merge_info);
        end else begin
            `uvm_info(get_type_name(), $sformatf("🚫 Skipping merge expectation: %s (source %s blocked by mask)", merge_info.name, source_info.name), UVM_MEDIUM)
        end

        // 2. Check if source has direct routing (excluding SCP/MCP which are handled via merge)
        source_has_direct_routing = (source_info.to_ap || source_info.to_accel || source_info.to_io || source_info.to_other_die);

        if (source_has_direct_routing) begin
            `uvm_info(get_type_name(), $sformatf("Adding direct routing expectation for source: %s", source_info.name), UVM_MEDIUM)
            add_expected_with_mask(source_info);
        end else begin
            `uvm_info(get_type_name(), $sformatf("No direct routing for source: %s", source_info.name), UVM_HIGH)
        end

        `uvm_info(get_type_name(), "=== END ADDING MERGE TEST EXPECTATIONS ===", UVM_MEDIUM)
    endfunction

    // High-level task for merge interrupt testing - handles both merge and direct routing waits
    task wait_for_merge_test_interrupts(interrupt_info_s merge_info, interrupt_info_s source_info, int timeout_ns = -1);
        bit source_has_direct_routing;

        `uvm_info(get_type_name(), "=== WAITING FOR MERGE TEST INTERRUPTS ===", UVM_MEDIUM)
        `uvm_info(get_type_name(), $sformatf("Waiting for merge test: %s -> %s", source_info.name, merge_info.name), UVM_MEDIUM)

        // 1. Wait for merge interrupt if source should trigger it
        if (m_routing_model.should_trigger_merge_expectation(source_info.name, merge_info.name, m_register_model)) begin
            `uvm_info(get_type_name(), $sformatf("Waiting for merge interrupt: %s (from source: %s)", merge_info.name, source_info.name), UVM_HIGH)
            wait_for_interrupt_detection_with_mask(merge_info, timeout_ns);
        end else begin
            `uvm_info(get_type_name(), $sformatf("🚫 Skipping merge wait: %s (source %s blocked by mask)", merge_info.name, source_info.name), UVM_MEDIUM)
        end

        // 2. Wait for source direct routing if applicable
        source_has_direct_routing = (source_info.to_ap || source_info.to_accel || source_info.to_io || source_info.to_other_die);

        if (source_has_direct_routing) begin
            `uvm_info(get_type_name(), $sformatf("Waiting for direct routing of source: %s", source_info.name), UVM_MEDIUM)
            wait_for_interrupt_detection_with_mask(source_info, timeout_ns);
        end

        `uvm_info(get_type_name(), "=== END WAITING FOR MERGE TEST INTERRUPTS ===", UVM_MEDIUM)
    endtask

    // High-level task for merge interrupt testing - handles both merge and direct routing status updates
    task update_merge_test_status(interrupt_info_s merge_info, interrupt_info_s source_info);
        bit source_has_direct_routing;

        `uvm_info(get_type_name(), "=== UPDATING MERGE TEST STATUS ===", UVM_MEDIUM)
        `uvm_info(get_type_name(), $sformatf("Updating status for merge test: %s -> %s", source_info.name, merge_info.name), UVM_MEDIUM)

        // 1. Update merge interrupt status if source should trigger it
        if (m_routing_model.should_trigger_merge_expectation(source_info.name, merge_info.name, m_register_model)) begin
            `uvm_info(get_type_name(), $sformatf("Updating merge interrupt status: %s (from source: %s)", merge_info.name, source_info.name), UVM_HIGH)
            m_routing_model.update_interrupt_status(merge_info.name, 1, m_register_model);
        end else begin
            `uvm_info(get_type_name(), $sformatf("🚫 Skipping merge status update: %s (source %s blocked by mask)", merge_info.name, source_info.name), UVM_HIGH)
        end

        // 2. Update source status if it has direct routing
        source_has_direct_routing = (source_info.to_ap || source_info.to_accel || source_info.to_io || source_info.to_other_die);

        if (source_has_direct_routing) begin
            `uvm_info(get_type_name(), $sformatf("Updating source interrupt status: %s", source_info.name), UVM_HIGH)
            m_routing_model.update_interrupt_status(source_info.name, 1, m_register_model);
        end

        `uvm_info(get_type_name(), "=== END UPDATING MERGE TEST STATUS ===", UVM_MEDIUM)
    endtask

    // High-level function for multi-source merge interrupt testing
    function void add_multi_source_merge_expectations(interrupt_info_s merge_info, interrupt_info_s source_interrupts[]);
        `uvm_info(get_type_name(), "=== ADDING MULTI-SOURCE MERGE EXPECTATIONS ===", UVM_MEDIUM)
        `uvm_info(get_type_name(), $sformatf("Processing multi-source merge test for: %s", merge_info.name), UVM_MEDIUM)

        // 1. Add expectation for the merge interrupt if any source should trigger it
        if (m_routing_model.should_any_source_trigger_merge(merge_info.name, source_interrupts, m_register_model)) begin
            `uvm_info(get_type_name(), $sformatf("Adding merge expectation: %s (from multiple sources)", merge_info.name), UVM_HIGH)
            add_expected_with_mask(merge_info);
        end else begin
            `uvm_info(get_type_name(), $sformatf("🚫 Skipping merge expectation: %s (all sources blocked by mask)", merge_info.name), UVM_MEDIUM)
        end

        // 2. Add expectations for source interrupts with direct routing
        `uvm_info(get_type_name(), "Checking for source interrupts with direct routing", UVM_MEDIUM)
        foreach (source_interrupts[i]) begin
            if (source_interrupts[i].rtl_path_src != "") begin
                bit source_has_direct_routing = (source_interrupts[i].to_ap || source_interrupts[i].to_accel ||
                                                source_interrupts[i].to_io || source_interrupts[i].to_other_die);
                if (source_has_direct_routing) begin
                    `uvm_info(get_type_name(), $sformatf("Adding direct routing expectation for: %s", source_interrupts[i].name), UVM_MEDIUM)
                    add_expected_with_mask(source_interrupts[i]);
                end
            end
        end

        `uvm_info(get_type_name(), "=== END ADDING MULTI-SOURCE MERGE EXPECTATIONS ===", UVM_MEDIUM)
    endfunction

    // High-level task for multi-source merge interrupt testing - waits
    task wait_for_multi_source_merge_interrupts(interrupt_info_s merge_info, interrupt_info_s source_interrupts[], int timeout_ns = -1);
        `uvm_info(get_type_name(), "=== WAITING FOR MULTI-SOURCE MERGE INTERRUPTS ===", UVM_MEDIUM)
        `uvm_info(get_type_name(), $sformatf("Waiting for multi-source merge test: %s", merge_info.name), UVM_MEDIUM)

        // 1. Wait for merge interrupt if any source should trigger it
        if (m_routing_model.should_any_source_trigger_merge(merge_info.name, source_interrupts, m_register_model)) begin
            `uvm_info(get_type_name(), $sformatf("Waiting for merge interrupt: %s (from multiple sources)", merge_info.name), UVM_HIGH)
            wait_for_interrupt_detection_with_mask(merge_info, timeout_ns);
        end else begin
            `uvm_info(get_type_name(), $sformatf("🚫 Skipping merge wait: %s (all sources blocked by mask)", merge_info.name), UVM_MEDIUM)
        end

        // 2. Wait for source interrupts with direct routing
        `uvm_info(get_type_name(), "Waiting for source interrupts with direct routing", UVM_MEDIUM)
        foreach (source_interrupts[i]) begin
            if (source_interrupts[i].rtl_path_src != "") begin
                bit source_has_direct_routing = (source_interrupts[i].to_ap || source_interrupts[i].to_accel ||
                                                source_interrupts[i].to_io || source_interrupts[i].to_other_die);
                if (source_has_direct_routing) begin
                    `uvm_info(get_type_name(), $sformatf("Waiting for direct routing of: %s", source_interrupts[i].name), UVM_MEDIUM)
                    wait_for_interrupt_detection_with_mask(source_interrupts[i], timeout_ns);
                end
            end
        end

        `uvm_info(get_type_name(), "=== END WAITING FOR MULTI-SOURCE MERGE INTERRUPTS ===", UVM_MEDIUM)
    endtask

    // High-level task for multi-source merge interrupt testing - status updates
    task update_multi_source_merge_status(interrupt_info_s merge_info, interrupt_info_s source_interrupts[]);
        `uvm_info(get_type_name(), "=== UPDATING MULTI-SOURCE MERGE STATUS ===", UVM_MEDIUM)
        `uvm_info(get_type_name(), $sformatf("Updating status for multi-source merge test: %s", merge_info.name), UVM_MEDIUM)

        // 1. Update merge interrupt status if any source should trigger it
        if (m_routing_model.should_any_source_trigger_merge(merge_info.name, source_interrupts, m_register_model)) begin
            `uvm_info(get_type_name(), $sformatf("Updating merge interrupt status: %s (from multiple sources)", merge_info.name), UVM_HIGH)
            m_routing_model.update_interrupt_status(merge_info.name, 1, m_register_model);
        end else begin
            `uvm_info(get_type_name(), $sformatf("🚫 Skipping merge status update: %s (all sources blocked by mask)", merge_info.name), UVM_HIGH)
        end

        // 2. Update status for source interrupts with direct routing
        `uvm_info(get_type_name(), "Updating status for source interrupts with direct routing", UVM_MEDIUM)
        foreach (source_interrupts[i]) begin
            if (source_interrupts[i].rtl_path_src != "") begin
                bit source_has_direct_routing = (source_interrupts[i].to_ap || source_interrupts[i].to_accel ||
                                                source_interrupts[i].to_io || source_interrupts[i].to_other_die);
                if (source_has_direct_routing) begin
                    `uvm_info(get_type_name(), $sformatf("Updating status for: %s", source_interrupts[i].name), UVM_HIGH)
                    m_routing_model.update_interrupt_status(source_interrupts[i].name, 1, m_register_model);
                end
            end
        end

        `uvm_info(get_type_name(), "=== END UPDATING MULTI-SOURCE MERGE STATUS ===", UVM_MEDIUM)
    endtask

endclass
`endif
