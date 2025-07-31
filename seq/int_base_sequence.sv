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

endclass
`endif
