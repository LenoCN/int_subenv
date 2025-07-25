`ifndef INT_EVENT_MANAGER_SV
`define INT_EVENT_MANAGER_SV

// This class manages the interrupt events and provides a clean interface
// for sequences to wait for interrupt detection events
class int_event_manager extends uvm_object;
    `uvm_object_utils(int_event_manager)

    // Event pool for interrupt detection handshake
    uvm_event_pool interrupt_event_pool;

    // Track events that have been triggered to handle race conditions
    // Key: event_key, Value: 1 if triggered
    bit triggered_events[string];

    function new(string name = "int_event_manager");
        super.new(name);
        interrupt_event_pool = new("interrupt_event_pool");
    endfunction
    
    // Task for sequences to wait for interrupt detection
    // This creates a handshake mechanism between monitor and sequence
    // Fixed race condition: check if event was already triggered before waiting
    task wait_for_interrupt_detection(interrupt_info_s info, int timeout_ns = 1000);
        uvm_event int_events[$];
        string event_keys[$];
        bit timeout_occurred = 0;

        // Collect all expected destination events for this interrupt
        if (info.to_ap) begin
            event_keys.push_back($sformatf("%s@%s", info.name, "AP"));
        end
        if (info.to_scp) begin
            event_keys.push_back($sformatf("%s@%s", info.name, "SCP"));
        end
        if (info.to_mcp) begin
            event_keys.push_back($sformatf("%s@%s", info.name, "MCP"));
        end
        if (info.to_imu) begin
            event_keys.push_back($sformatf("%s@%s", info.name, "IMU"));
        end
        if (info.to_io) begin
            event_keys.push_back($sformatf("%s@%s", info.name, "IO"));
        end
        if (info.to_other_die) begin
            event_keys.push_back($sformatf("%s@%s", info.name, "OTHER_DIE"));
        end

        if (event_keys.size() == 0) begin
            `uvm_warning("INT_EVENT_MANAGER", $sformatf("No destinations specified for interrupt '%s'", info.name))
            return;
        end

        // Get events from pool
        foreach (event_keys[i]) begin
            int_events.push_back(interrupt_event_pool.get(event_keys[i]));
        end

        `uvm_info("INT_EVENT_MANAGER", $sformatf("Waiting for %0d destination events for interrupt '%s'",
                  int_events.size(), info.name), UVM_HIGH)

        // Wait for all expected events to be triggered with timeout
        // Fixed race condition: check if event was already triggered before waiting
        foreach (int_events[i]) begin
            // Check if event was already triggered to avoid race condition
            if (triggered_events.exists(event_keys[i]) && triggered_events[event_keys[i]]) begin
                `uvm_info("INT_EVENT_MANAGER", $sformatf("Event already triggered for %s (race condition avoided)",
                          event_keys[i]), UVM_HIGH)
                // Clear the triggered flag for this event
                triggered_events[event_keys[i]] = 0;
                continue; // Event already triggered, skip waiting
            end

            fork
                begin
                    int_events[i].wait_trigger();
                    `uvm_info("INT_EVENT_MANAGER", $sformatf("Handshake: Received detection event for %s",
                              event_keys[i]), UVM_HIGH)
                    // Clear the triggered flag after successful wait
                    if (triggered_events.exists(event_keys[i])) begin
                        triggered_events[event_keys[i]] = 0;
                    end
                end
                begin
                    #(timeout_ns * 1ns);
                    timeout_occurred = 1;
                    `uvm_error("INT_EVENT_MANAGER", $sformatf("Timeout waiting for interrupt detection: %s (timeout: %0dns)",
                               event_keys[i], timeout_ns))
                end
            join_any
            disable fork;

            if (timeout_occurred) break;
        end

        if (!timeout_occurred) begin
            `uvm_info("INT_EVENT_MANAGER", $sformatf("Handshake complete: All destinations detected for interrupt '%s'",
                      info.name), UVM_MEDIUM)
        end
    endtask
    
    // Mark an event as triggered (called by monitor to handle race conditions)
    function void mark_event_triggered(string event_key);
        triggered_events[event_key] = 1;
        `uvm_info("INT_EVENT_MANAGER", $sformatf("Marked event as triggered: %s", event_key), UVM_DEBUG)
    endfunction

    // Check if an event was already triggered
    function bit is_event_triggered(string event_key);
        return (triggered_events.exists(event_key) && triggered_events[event_key]);
    endfunction

    // Get the event pool
    function uvm_event_pool get_event_pool();
        return interrupt_event_pool;
    endfunction
endclass

`endif // INT_EVENT_MANAGER_SV
