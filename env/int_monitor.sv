`ifndef INT_MONITOR_SV
`define INT_MONITOR_SV

class int_monitor extends uvm_monitor;
    `uvm_component_utils(int_monitor)

    uvm_analysis_port #(int_transaction) item_collected_port;

    virtual int_interface int_if;

    // Event pool for interrupt detection handshake
    // Key format: "interrupt_name@destination"
    uvm_event_pool interrupt_detected_events;

    // Event manager for race condition handling
    int_event_manager event_manager;

    // Model object references
    int_register_model m_register_model;
    int_routing_model  m_routing_model;

    // Timing configuration
    timing_config timing_cfg;

    function new(string name = "int_monitor", uvm_component parent = null);
        super.new(name, parent);
        item_collected_port = new("item_collected_port", this);
    endfunction

    function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        if(!uvm_config_db#(virtual int_interface)::get(this, "", "int_if", int_if)) begin
            `uvm_fatal(get_type_name(), "Failed to get virtual interface")
        end

        // Get event pool from configuration database
        if(!uvm_config_db#(uvm_event_pool)::get(this, "", "interrupt_event_pool", interrupt_detected_events)) begin
            `uvm_info(get_type_name(), "No event pool found in config DB, creating new one", UVM_MEDIUM)
            interrupt_detected_events = new("interrupt_detected_events");
        end

        // Get event manager from configuration database for race condition handling
        if(!uvm_config_db#(int_event_manager)::get(this, "", "event_manager", event_manager)) begin
            `uvm_warning(get_type_name(), "No event_manager found in config DB, race condition handling disabled")
        end

        // Get model objects from configuration database
        if(!uvm_config_db#(int_register_model)::get(this, "", "register_model", m_register_model)) begin
            `uvm_fatal(get_type_name(), "Cannot get register_model from config DB");
        end
        if(!uvm_config_db#(int_routing_model)::get(this, "", "routing_model", m_routing_model)) begin
            `uvm_fatal(get_type_name(), "Cannot get routing_model from config DB");
        end

        // Initialize timing configuration
        init_timing_config();
        timing_cfg = global_timing_config;
    endfunction

    virtual task run_phase(uvm_phase phase);
        m_routing_model.build();

        // Debug: Show interrupt configuration summary
        debug_interrupt_configuration();

        // Create a fork for each interrupt to be monitored in parallel.
        // This provides better isolation and scalability than monitoring entire buses.
        fork
            foreach (m_routing_model.interrupt_map[i]) begin
                automatic int j = i;
                fork
                    monitor_interrupt(m_routing_model.interrupt_map[j]);
                join_none
            end
        join
    endtask

    // Monitors a single interrupt's destinations
    virtual task monitor_interrupt(interrupt_info_s info);
        // Task 2: Check routing configuration before monitoring
        validate_routing_configuration(info);

        fork
            if (info.rtl_path_ap != "") monitor_single_path(info, "AP", info.rtl_path_ap);
            if (info.rtl_path_scp != "") monitor_single_path(info, "SCP", info.rtl_path_scp);
            if (info.rtl_path_mcp != "") monitor_single_path(info, "MCP", info.rtl_path_mcp);
            if (info.rtl_path_accel!= "") monitor_single_path(info, "ACCEL", info.rtl_path_accel);
            // TODO
            // IO monitoring disabled - iosub_to_io monitoring mechanism turned off
            // if (info.rtl_path_io != "") monitor_single_path(info, "IO", info.rtl_path_io);
            if (info.rtl_path_other_die != "") monitor_single_path(info, "OTHER_DIE", info.rtl_path_other_die);
        join_none
    endtask

    // Monitors a specific RTL signal path for an interrupt
    virtual task monitor_single_path(interrupt_info_s info, string dest, string path);
        logic value;
        logic prev_value = 0;
        int detection_count = 0;

        `uvm_info(get_type_name(), $sformatf("Starting monitor for interrupt '%s' -> '%s' at path: %s",
                  info.name, dest, path), UVM_MEDIUM)

        forever begin
            // Wait for the interrupt signal to go high
            `uvm_info(get_type_name(), $sformatf("Waiting for signal HIGH on path: %s (interrupt: %s -> %s)",
                      path, info.name, dest), UVM_HIGH)
            wait_for_signal_edge(path, 1);

            detection_count++;
            `uvm_info(get_type_name(), $sformatf("INTERRUPT DETECTED [%0d]: '%s' -> '%s' signal went HIGH at path: %s",
                      detection_count, info.name, dest, path), UVM_LOW)

            // Send the transaction when the interrupt is detected
            send_transaction(info, dest);

            // Wait for the interrupt signal to go low to prevent re-triggering
            `uvm_info(get_type_name(), $sformatf("Waiting for signal LOW on path: %s (interrupt: %s -> %s)",
                      path, info.name, dest), UVM_HIGH)
            wait_for_signal_edge(path, 0);

            `uvm_info(get_type_name(), $sformatf("INTERRUPT CLEARED [%0d]: '%s' -> '%s' signal went LOW at path: %s",
                      detection_count, info.name, dest, path), UVM_HIGH)
        end
    endtask

    // Helper task to wait for a specific signal value using polling.
    // In a real scenario, this would be replaced with @(posedge/negedge virtual_interface.signal)
    virtual task wait_for_signal_edge(string path, logic expected_value);
        logic current_value;
        logic prev_value;
        int consecutive_failures = 0;
        const int MAX_FAILURES = 10;
        int timeout_counter = 0;
        int max_timeout_cycles = timing_cfg.detection_timeout_ns / timing_cfg.detection_poll_interval_ns;
        bit first_read = 1;

        `uvm_info(get_type_name(), $sformatf("Starting signal polling: path=%s, expected_value=%0d, timeout=%0dns",
                  path, expected_value, timing_cfg.detection_timeout_ns), UVM_DEBUG)

        forever begin
            #(timing_cfg.detection_poll_interval_ns * 1ns);
            timeout_counter++;

            if (uvm_hdl_read(path, current_value)) begin
                consecutive_failures = 0; // Reset failure counter on successful read

                // Log signal transitions for debugging
                if (!first_read && (current_value != prev_value)) begin
                    `uvm_info(get_type_name(), $sformatf("Signal transition detected: %s changed from %0d to %0d",
                              path, prev_value, current_value), UVM_HIGH)
                end

                if (current_value == expected_value) begin
                    `uvm_info(get_type_name(), $sformatf("Signal reached expected value: %s = %0d",
                              path, expected_value), UVM_DEBUG)
                    break;
                end

                prev_value = current_value;
                first_read = 0;
            end
            else begin
                consecutive_failures++;
                if (consecutive_failures >= MAX_FAILURES) begin
                    `uvm_error(get_type_name(), $sformatf("Failed to read signal at path: %s (consecutive failures: %0d)",
                              path, consecutive_failures))
                    break;
                end
                `uvm_warning(get_type_name(), $sformatf("HDL read failure [%0d/%0d] for path: %s",
                            consecutive_failures, MAX_FAILURES, path))
            end

            //// Check for timeout using configurable timeout
            //if (timeout_counter >= max_timeout_cycles) begin
            //    `uvm_error(get_type_name(), $sformatf("Timeout (%0dns) waiting for signal %s to become %0d (current: %0d, cycles: %0d)",
            //              timing_cfg.detection_timeout_ns, path, expected_value, current_value, timeout_counter))
            //    break;
            //end
        end
    endtask

    virtual task send_transaction(interrupt_info_s info, string dest);
        int_transaction trans = int_transaction::type_id::create("trans");
        string event_key;
        uvm_event int_event;
        string rtl_path;

        `uvm_info(get_type_name(), "=== INTERRUPT TRANSACTION CREATION ===", UVM_MEDIUM)
        `uvm_info(get_type_name(), $sformatf("Creating transaction for interrupt: %s", info.name), UVM_MEDIUM)
        `uvm_info(get_type_name(), $sformatf("  - Group: %s", info.group.name()), UVM_MEDIUM)
        `uvm_info(get_type_name(), $sformatf("  - Index: %0d", info.index), UVM_MEDIUM)
        `uvm_info(get_type_name(), $sformatf("  - Trigger: %s", info.trigger.name()), UVM_MEDIUM)
        `uvm_info(get_type_name(), $sformatf("  - Polarity: %s", info.polarity.name()), UVM_MEDIUM)
        `uvm_info(get_type_name(), $sformatf("  - Destination: %s", dest), UVM_MEDIUM)

        // Get the RTL path for this destination
        case (dest)
            "AP": rtl_path = info.rtl_path_ap;
            "SCP": rtl_path = info.rtl_path_scp;
            "MCP": rtl_path = info.rtl_path_mcp;
            "ACCEL": rtl_path = info.rtl_path_accel;
            "IO": rtl_path = info.rtl_path_io;
            "OTHER_DIE": rtl_path = info.rtl_path_other_die;
            default: rtl_path = "UNKNOWN_DEST";
        endcase

        `uvm_info(get_type_name(), $sformatf("  - RTL Path: %s", rtl_path), UVM_MEDIUM)
        `uvm_info(get_type_name(), $sformatf("  - Source Path: %s", info.rtl_path_src), UVM_MEDIUM)

        // Create transaction
        trans.interrupt_info = info;
        trans.destination_name = dest;

        `uvm_info(get_type_name(), $sformatf("Sending transaction to scoreboard: %s@%s", info.name, dest), UVM_MEDIUM)

        //TODO : Disable , the scoreboard has been checked.
        //// Validate routing configuration (only at HIGH verbosity to avoid spam)
        //debug_interrupt_routing(info, dest);

        // Send to scoreboard
        item_collected_port.write(trans);

        // Create event key and trigger event for handshake
        event_key = $sformatf("%s@%s", info.name, dest);
        int_event = interrupt_detected_events.get(event_key);

        int_event.trigger();

        `uvm_info(get_type_name(), $sformatf("✅ INTERRUPT DETECTED: '%s' -> '%s' (event: %s)",
                  info.name, dest, event_key), UVM_LOW)
        `uvm_info(get_type_name(), "=== END INTERRUPT TRANSACTION ===", UVM_MEDIUM)
    endtask

    // Task 2: Validate routing configuration before monitoring
    virtual function void validate_routing_configuration(interrupt_info_s info);
        string config_errors[$];
        bit has_routing_enabled = 0;

        `uvm_info(get_type_name(), $sformatf(" === VALIDATING ROUTING CONFIG: %s ===", info.name), UVM_HIGH)

        // Check each destination for routing configuration consistency
        if (info.to_ap) begin
            has_routing_enabled = 1;
            if (info.rtl_path_ap == "") begin
                config_errors.push_back($sformatf("AP routing enabled (to_ap=1) but rtl_path_ap is empty"));
            end else begin
                `uvm_info(get_type_name(), $sformatf("✅ AP routing: %s", info.rtl_path_ap), UVM_HIGH)
            end
        end

        if (info.to_scp) begin
            has_routing_enabled = 1;
            if (info.rtl_path_scp == "") begin
                // Special handling for iosub_normal_intr - it's a merge signal
                if (info.name == "iosub_normal_intr") begin
                    `uvm_info(get_type_name(), $sformatf("⚠️  SCP routing: %s is a merge signal, empty rtl_path_scp is expected", info.name), UVM_MEDIUM)
                end else begin
                    config_errors.push_back($sformatf("SCP routing enabled (to_scp=1) but rtl_path_scp is empty"));
                end
            end else begin
                `uvm_info(get_type_name(), $sformatf("✅ SCP routing: %s", info.rtl_path_scp), UVM_HIGH)
            end
        end

        if (info.to_mcp) begin
            has_routing_enabled = 1;
            if (info.rtl_path_mcp == "") begin
                // Special handling for iosub_normal_intr - it's a merge signal
                if (info.name == "iosub_normal_intr") begin
                    `uvm_info(get_type_name(), $sformatf("⚠️  MCP routing: %s is a merge signal, empty rtl_path_mcp is expected", info.name), UVM_MEDIUM)
                end else begin
                    config_errors.push_back($sformatf("MCP routing enabled (to_mcp=1) but rtl_path_mcp is empty"));
                end
            end else begin
                `uvm_info(get_type_name(), $sformatf("✅ MCP routing: %s", info.rtl_path_mcp), UVM_HIGH)
            end
        end

        if (info.to_accel) begin
            has_routing_enabled = 1;
            if (info.rtl_path_accel == "") begin
                config_errors.push_back($sformatf("ACCEL routing enabled (to_accel=1) but rtl_path_accel is empty"));
            end else begin
                `uvm_info(get_type_name(), $sformatf("✅ ACCEL routing: %s", info.rtl_path_accel), UVM_HIGH)
            end
        end

        if (info.to_io) begin
            has_routing_enabled = 1;
            if (info.rtl_path_io == "") begin
                config_errors.push_back($sformatf("IO routing enabled (to_io=1) but rtl_path_io is empty"));
            end else begin
                `uvm_info(get_type_name(), $sformatf("✅ IO routing: %s", info.rtl_path_io), UVM_HIGH)
            end
        end

        if (info.to_other_die) begin
            has_routing_enabled = 1;
            if (info.rtl_path_other_die == "") begin
                config_errors.push_back($sformatf("OTHER_DIE routing enabled (to_other_die=1) but rtl_path_other_die is empty"));
            end else begin
                `uvm_info(get_type_name(), $sformatf("✅ OTHER_DIE routing: %s", info.rtl_path_other_die), UVM_HIGH)
            end
        end

        // Report configuration errors
        if (config_errors.size() > 0) begin
            `uvm_error(get_type_name(), $sformatf(" ROUTING CONFIG ERROR for '%s':", info.name))
            foreach (config_errors[i]) begin
                `uvm_error(get_type_name(), $sformatf("   %0d. %s", i+1, config_errors[i]))
            end
        end else if (has_routing_enabled) begin
            `uvm_info(get_type_name(), $sformatf("✅ Routing configuration valid for '%s'", info.name), UVM_HIGH)
        end else begin
            `uvm_info(get_type_name(), $sformatf("ℹ️  No routing enabled for '%s'", info.name), UVM_HIGH)
        end

        `uvm_info(get_type_name(), $sformatf(" === END ROUTING CONFIG VALIDATION: %s ===", info.name), UVM_HIGH)
    endfunction

    // Debug function to show interrupt configuration summary at startup
    function void debug_interrupt_configuration();
        int group_counts[string];
        int total_interrupts = m_routing_model.interrupt_map.size();

        `uvm_info(get_type_name(), " === INTERRUPT CONFIGURATION SUMMARY ===", UVM_MEDIUM)
        `uvm_info(get_type_name(), $sformatf("Total interrupts in map: %0d", total_interrupts), UVM_MEDIUM)

        // Count interrupts by group
        foreach (m_routing_model.interrupt_map[i]) begin
            string group_name = m_routing_model.interrupt_map[i].group.name();
            if (group_counts.exists(group_name)) begin
                group_counts[group_name]++;
            end else begin
                group_counts[group_name] = 1;
            end
        end

        // Display group statistics
        `uvm_info(get_type_name(), "Interrupt distribution by group:", UVM_MEDIUM)
        foreach (group_counts[group]) begin
            `uvm_info(get_type_name(), $sformatf("  - %s: %0d interrupts", group, group_counts[group]), UVM_MEDIUM)
        end

        // Show monitoring status
        `uvm_info(get_type_name(), "Monitor will track all configured interrupt destinations", UVM_MEDIUM)
        `uvm_info(get_type_name(), " === END INTERRUPT CONFIGURATION SUMMARY ===", UVM_MEDIUM)
    endfunction

endclass

`endif // INT_MONITOR_SV
