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
        `uvm_info(get_type_name(), $sformatf(" Original interrupt routing: AP=%b, SCP=%b, MCP=%b, ACCEL=%b, IO=%b, OTHER_DIE=%b",
                  info.to_ap, info.to_scp, info.to_mcp, info.to_accel, info.to_io, info.to_other_die), UVM_MEDIUM)

        // Use global timing config if no specific timeout provided
        if (timeout_ns == -1) begin
            init_timing_config();
            timeout_ns = global_timing_config.detection_timeout_ns;
        end

        // Get expected destinations considering masks
        `uvm_info(get_type_name(), $sformatf(" Calling routing model to get expected destinations with mask for: %s", info.name), UVM_HIGH)
        m_routing_model.get_expected_destinations_with_mask(info.name, expected_destinations, m_register_model);

        if (expected_destinations.size() == 0) begin
            `uvm_info(get_type_name(), $sformatf("⚠️  Interrupt '%s' is completely masked - no wait needed", info.name), UVM_MEDIUM)
            `uvm_info(get_type_name(), $sformatf(" This means all destinations are either not routed or masked by registers"), UVM_MEDIUM)
            `uvm_info(get_type_name(), "=== END SEQUENCE WAIT FOR INTERRUPT WITH MASK ===", UVM_MEDIUM)
            return;
        end

        `uvm_info(get_type_name(), $sformatf("✅ Found %0d expected destinations after mask filtering:", expected_destinations.size()), UVM_MEDIUM)
        foreach (expected_destinations[i]) begin
            `uvm_info(get_type_name(), $sformatf("  ✅ %s", expected_destinations[i]), UVM_MEDIUM)
        end

        // Create modified info with only unmasked destinations
        `uvm_info(get_type_name(), $sformatf(" Creating masked interrupt info for wait: %s", info.name), UVM_HIGH)
        masked_info = info;
        masked_info.to_ap = 0;
        masked_info.to_scp = 0;
        masked_info.to_mcp = 0;
        masked_info.to_accel = 0;
        masked_info.to_io = 0;
        masked_info.to_other_die = 0;

        // Set only the unmasked destinations
        `uvm_info(get_type_name(), $sformatf(" Setting unmasked destinations for wait: %s", info.name), UVM_HIGH)
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

        `uvm_info(get_type_name(), $sformatf(" Final masked interrupt routing for wait: AP=%b, SCP=%b, MCP=%b, ACCEL=%b, IO=%b, OTHER_DIE=%b",
                  masked_info.to_ap, masked_info.to_scp, masked_info.to_mcp, masked_info.to_accel, masked_info.to_io, masked_info.to_other_die), UVM_MEDIUM)

        // Wait for the masked interrupt using the original wait function
        `uvm_info(get_type_name(), $sformatf(" Waiting for masked interrupt: %s with timeout %0d ns", info.name, timeout_ns), UVM_HIGH)
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

        if (!info.to_ap && !info.to_scp && !info.to_mcp && !info.to_accel&& !info.to_io && !info.to_other_die) begin
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

    // 修改 add_expected_with_mask 函数（添加 source_name 参数，并处理 iosub_normal_intr）
    function void add_expected_with_mask(interrupt_info_s info, string source_name = "");
        string expected_destinations[$];
        interrupt_info_s masked_info;
    
        `uvm_info(get_type_name(), "=== SEQUENCE ADDING EXPECTED INTERRUPT WITH MASK ===", UVM_MEDIUM)
        `uvm_info(get_type_name(), $sformatf("Sequence '%s' adding expected interrupt with mask: %s (source: %s)", get_sequence_path(), info.name, source_name), UVM_MEDIUM)
        `uvm_info(get_type_name(), $sformatf(" Original interrupt routing: AP=%b, SCP=%b, MCP=%b, ACCEL=%b, IO=%b, OTHER_DIE=%b",
                  info.to_ap, info.to_scp, info.to_mcp, info.to_accel, info.to_io, info.to_other_die), UVM_MEDIUM)
    
        // Get expected destinations considering masks (原有代码)
        `uvm_info(get_type_name(), $sformatf(" Calling routing model to get expected destinations with mask for: %s", info.name), UVM_HIGH)
        m_routing_model.get_expected_destinations_with_mask(info.name, expected_destinations, m_register_model);
    
        if (expected_destinations.size() == 0) begin
            `uvm_info(get_type_name(), $sformatf("⚠️  Interrupt '%s' is completely masked - no expectations will be registered", info.name), UVM_MEDIUM)
            return;
        end
    
        // Create modified info with only unmasked destinations (原有代码)
        masked_info = info;
        masked_info.to_ap = 0;
        masked_info.to_scp = 0;
        masked_info.to_mcp = 0;
        masked_info.to_accel = 0;
        masked_info.to_io = 0;
        masked_info.to_other_die = 0;
    
        // 最简洁修改：对于 iosub_normal_intr，独立检查并设置 to_scp 和 to_mcp（基于源）
        if (info.name == "iosub_normal_intr" && source_name != "") begin
            // 独立检查 SCP 路径：源是否通过 SCP 的 Layer1 + Layer2
            if (info.to_scp && !m_register_model.check_iosub_normal_mask_layer(source_name, "SCP", m_routing_model) &&
                !m_register_model.check_general_mask_layer(info.name, "SCP", m_routing_model)) begin
                masked_info.to_scp = 1;
                `uvm_info(get_type_name(), $sformatf("✅ Enabled SCP for iosub_normal_intr (source %s passes masks)", source_name), UVM_HIGH)
            end
    
            // 独立检查 MCP 路径：源是否通过 MCP 的 Layer1 + Layer2
            if (info.to_mcp && !m_register_model.check_iosub_normal_mask_layer(source_name, "MCP", m_routing_model) &&
                !m_register_model.check_general_mask_layer(info.name, "MCP", m_routing_model)) begin
                masked_info.to_mcp = 1;
                `uvm_info(get_type_name(), $sformatf("✅ Enabled MCP for iosub_normal_intr (source %s passes masks)", source_name), UVM_HIGH)
            end
    
            // 其他目的地保持原有（如果有）
            foreach (expected_destinations[i]) begin
                case (expected_destinations[i])
                    "AP": masked_info.to_ap = 1;
                    "ACCEL": masked_info.to_accel = 1;
                    "IO": masked_info.to_io = 1;
                    "OTHER_DIE": masked_info.to_other_die = 1;
                endcase
            end
        end else begin
            // 非 iosub_normal_intr 或无源：使用原有逻辑
            foreach (expected_destinations[i]) begin
                case (expected_destinations[i])
                    "AP": masked_info.to_ap = 1;
                    "SCP": masked_info.to_scp = 1;
                    "MCP": masked_info.to_mcp = 1;
                    "ACCEL": masked_info.to_accel = 1;
                    "IO": masked_info.to_io = 1;
                    "OTHER_DIE": masked_info.to_other_die = 1;
                endcase
            end
        end
    
        `uvm_info(get_type_name(), $sformatf(" Final masked interrupt routing: AP=%b, SCP=%b, MCP=%b, ACCEL=%b, IO=%b, OTHER_DIE=%b",
                  masked_info.to_ap, masked_info.to_scp, masked_info.to_mcp, masked_info.to_accel, masked_info.to_io, masked_info.to_other_die), UVM_MEDIUM)
    
        // Register the masked expectation
        `uvm_info(get_type_name(), $sformatf(" Registering masked expectation for interrupt: %s", info.name), UVM_HIGH)
        add_expected(masked_info);
    
        `uvm_info(get_type_name(), "=== END SEQUENCE EXPECTED INTERRUPT WITH MASK ===", UVM_MEDIUM)
    endfunction

    // =========================================================================
    // RECURSIVE HELPER FUNCTIONS FOR HIERARCHICAL INTERRUPT HANDLING
    // =========================================================================

    // Recursive helper to add all expectations in the merge chain
    function void add_all_expected_interrupts_recursive(interrupt_info_s current_info, string original_source_name, ref string processed[string]);
        string merge_interrupts[$];
        interrupt_info_s merge_info;

        // Base case: prevent infinite loops
        if (processed.exists(current_info.name)) return;
        processed[current_info.name] = 1;
        `uvm_info(get_type_name(), $sformatf("[RECURSIVE_ADD] Processing: %s (Original Source: %s)", current_info.name, original_source_name), UVM_HIGH);

        // 1. Add expectation for the current interrupt in the chain (direct or merged)
        add_expected_with_mask(current_info, original_source_name);

        // 2. Find what this interrupt merges into (next level) and recurse
        m_routing_model.get_merge_interrupts_for_source(current_info.name, merge_interrupts);
        foreach (merge_interrupts[i]) begin
            if (m_routing_model.get_merge_interrupt_info(merge_interrupts[i], merge_info)) begin
                `uvm_info(get_type_name(), $sformatf("[RECURSIVE_ADD] Recursing from %s -> %s", current_info.name, merge_info.name), UVM_HIGH);
                add_all_expected_interrupts_recursive(merge_info, current_info.name, processed);
                //add_all_expected_interrupts_recursive(merge_info, original_source_name, processed);
            end
        end
    endfunction

    // Recursive helper to wait for all interrupts in the merge chain
    task wait_for_all_expected_interrupts_recursive(interrupt_info_s current_info, int timeout_ns, ref string processed[string]);
        string merge_interrupts[$];
        interrupt_info_s merge_info;

        if (processed.exists(current_info.name)) return;
        processed[current_info.name] = 1;
        `uvm_info(get_type_name(), $sformatf("[RECURSIVE_WAIT] Processing: %s", current_info.name), UVM_HIGH);

        // 1. Wait for the current interrupt in the chain
        wait_for_interrupt_detection_with_mask(current_info, timeout_ns);

        // 2. Find next-level merges and recurse
        m_routing_model.get_merge_interrupts_for_source(current_info.name, merge_interrupts);
        foreach (merge_interrupts[i]) begin
             if (m_routing_model.get_merge_interrupt_info(merge_interrupts[i], merge_info)) begin
                 if (m_register_model.should_expect_merge_interrupt(merge_info.name, current_info.name, m_routing_model)) begin
                    `uvm_info(get_type_name(), $sformatf("[RECURSIVE_WAIT] Recursing from %s -> %s", current_info.name, merge_info.name), UVM_HIGH);
                    wait_for_all_expected_interrupts_recursive(merge_info, timeout_ns, processed);
                 end
             end
        end
    endtask

    // Recursive helper to update status for all interrupts in the merge chain
    task update_all_interrupt_status_recursive(interrupt_info_s current_info, ref string processed[string]);
        string merge_interrupts[$];
        interrupt_info_s merge_info;

        if (processed.exists(current_info.name)) return;
        processed[current_info.name] = 1;
        `uvm_info(get_type_name(), $sformatf("[RECURSIVE_UPDATE] Processing: %s", current_info.name), UVM_HIGH);
        
        // 1. Update status for the current interrupt
        m_routing_model.update_interrupt_status(current_info.name, 1, m_register_model);
        
        // 2. Find next-level merges and recurse
        m_routing_model.get_merge_interrupts_for_source(current_info.name, merge_interrupts);
        foreach (merge_interrupts[i]) begin
             if (m_routing_model.get_merge_interrupt_info(merge_interrupts[i], merge_info)) begin
                 if (m_register_model.should_expect_merge_interrupt(merge_info.name, current_info.name, m_routing_model)) begin
                    `uvm_info(get_type_name(), $sformatf("[RECURSIVE_UPDATE] Recursing from %s -> %s", current_info.name, merge_info.name), UVM_HIGH);
                    update_all_interrupt_status_recursive(merge_info, processed);
                 end
             end
        end
    endtask

    // =========================================================================
    // PUBLIC-FACING HIGH-LEVEL FUNCTIONS (Now using recursive helpers)
    // =========================================================================

    // High-level function to add all expected interrupts for a given source interrupt
    function void add_all_expected_interrupts(interrupt_info_s source_info);
        string processed[string];
        `uvm_info(get_type_name(), "=== ADDING ALL EXPECTED INTERRUPTS (HIERARCHICAL) ===", UVM_MEDIUM)
        `uvm_info(get_type_name(), $sformatf("Processing all routing paths for top-level source: %s", source_info.name), UVM_MEDIUM)
        add_all_expected_interrupts_recursive(source_info, source_info.name, processed);
        `uvm_info(get_type_name(), "=== END ADDING ALL EXPECTED INTERRUPTS ===", UVM_MEDIUM)
    endfunction

    // High-level function to wait for all expected interrupts for a given source interrupt
    task wait_for_all_expected_interrupts(interrupt_info_s source_info, int timeout_ns = -1);
        string processed[string];
        `uvm_info(get_type_name(), "=== WAITING FOR ALL EXPECTED INTERRUPTS (HIERARCHICAL) ===", UVM_MEDIUM)
        `uvm_info(get_type_name(), $sformatf("Waiting for all routing paths for top-level source: %s", source_info.name), UVM_MEDIUM)
        begin
            fork
                wait_for_all_expected_interrupts_recursive(source_info, timeout_ns, processed);
            join
        end
        `uvm_info(get_type_name(), "=== END WAITING FOR ALL EXPECTED INTERRUPTS ===", UVM_MEDIUM)
    endtask

    // High-level function to update status for all related interrupts
    task update_all_interrupt_status(interrupt_info_s source_info);
        string processed[string];
        `uvm_info(get_type_name(), "=== UPDATING ALL INTERRUPT STATUS (HIERARCHICAL) ===", UVM_MEDIUM)
        `uvm_info(get_type_name(), $sformatf("Updating status for all routing paths for top-level source: %s", source_info.name), UVM_MEDIUM)
        update_all_interrupt_status_recursive(source_info, processed);
        `uvm_info(get_type_name(), "=== END UPDATING ALL INTERRUPT STATUS ===", UVM_MEDIUM)
    endtask
    

endclass
`endif
