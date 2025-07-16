`ifndef INT_MONITOR_SV
`define INT_MONITOR_SV

class int_monitor extends uvm_monitor;
    `uvm_component_utils(int_monitor)

    uvm_analysis_port #(int_transaction) item_collected_port;

    virtual int_interface int_if;

    // Event pool for interrupt detection handshake
    // Key format: "interrupt_name@destination"
    uvm_event_pool interrupt_detected_events;

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
    endfunction

    virtual task run_phase(uvm_phase phase);
        int_routing_model::build();
        
        // Create a fork for each interrupt to be monitored in parallel.
        // This provides better isolation and scalability than monitoring entire buses.
        fork
            foreach (int_routing_model::interrupt_map[i]) begin
                automatic int j = i;
                fork
                    monitor_interrupt(int_routing_model::interrupt_map[j]);
                join_none
            end
        join
    endtask

    // Monitors a single interrupt's destinations
    virtual task monitor_interrupt(interrupt_info_s info);
        fork
            if (info.rtl_path_ap != "") monitor_single_path(info, "AP", info.rtl_path_ap);
            if (info.rtl_path_scp != "") monitor_single_path(info, "SCP", info.rtl_path_scp);
            if (info.rtl_path_mcp != "") monitor_single_path(info, "MCP", info.rtl_path_mcp);
            if (info.rtl_path_imu != "") monitor_single_path(info, "IMU", info.rtl_path_imu);
            if (info.rtl_path_io != "") monitor_single_path(info, "IO", info.rtl_path_io);
            if (info.rtl_path_other_die != "") monitor_single_path(info, "OTHER_DIE", info.rtl_path_other_die);
        join_none
    endtask

    // Monitors a specific RTL signal path for an interrupt
    virtual task monitor_single_path(interrupt_info_s info, string dest, string path);
        logic value;
        forever begin
            // Wait for the interrupt signal to go high
            wait_for_signal_edge(path, 1);
            
            // Send the transaction when the interrupt is detected
            send_transaction(info, dest);

            // Wait for the interrupt signal to go low to prevent re-triggering
            wait_for_signal_edge(path, 0);
        end
    endtask

    // Helper task to wait for a specific signal value using polling.
    // In a real scenario, this would be replaced with @(posedge/negedge virtual_interface.signal)
    virtual task wait_for_signal_edge(string path, logic expected_value);
        logic current_value;
        int consecutive_failures = 0;
        const int MAX_FAILURES = 10;
        int timeout_counter = 0;
        const int MAX_TIMEOUT = 1000; // 1000ns timeout

        forever begin
            #1ns;
            timeout_counter++;

            if (uvm_hdl_read(path, current_value)) begin
                consecutive_failures = 0; // Reset failure counter on successful read
                if (current_value == expected_value) begin
                    break;
                end
            end else begin
                consecutive_failures++;
                if (consecutive_failures >= MAX_FAILURES) begin
                    `uvm_error(get_type_name(), $sformatf("Failed to read signal at path: %s (consecutive failures: %0d)",
                              path, consecutive_failures))
                    break;
                end
            end

            // Check for timeout
            if (timeout_counter >= MAX_TIMEOUT) begin
                `uvm_error(get_type_name(), $sformatf("Timeout waiting for signal %s to become %0d",
                          path, expected_value))
                break;
            end
        end
    endtask

    virtual task send_transaction(interrupt_info_s info, string dest);
        int_transaction trans = int_transaction::type_id::create("trans");
        string event_key;
        uvm_event int_event;

        // Create transaction
        trans.interrupt_info = info;
        trans.destination_name = dest;

        // Send to scoreboard
        item_collected_port.write(trans);

        // Create event key and trigger event for handshake
        event_key = $sformatf("%s@%s", info.name, dest);
        int_event = interrupt_detected_events.get(event_key);
        int_event.trigger();

        `uvm_info(get_type_name(), $sformatf("Detected interrupt '%s' at '%s' and triggered event",
                  info.name, dest), UVM_HIGH)
    endtask

    // Static method for sequences to wait for interrupt detection events
    static task wait_for_interrupt_detection_event(interrupt_info_s info, int timeout_ns = 1000);
        int_event_manager event_mgr;

        // Get event manager from config database
        if (!uvm_config_db#(int_event_manager)::get(null, "*", "event_manager", event_mgr)) begin
            `uvm_error("INT_MONITOR", "Failed to get event manager from config database")
            return;
        end

        // Use event manager to wait for detection
        event_mgr.wait_for_interrupt_detection(info, timeout_ns);
    endtask

endclass

`endif // INT_MONITOR_SV
