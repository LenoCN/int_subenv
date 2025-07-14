`ifndef INT_MONITOR_SV
`define INT_MONITOR_SV

`include "seq/int_transaction.sv"

class int_monitor extends uvm_monitor;
    `uvm_component_utils(int_monitor)

    uvm_analysis_port #(int_transaction) item_collected_port;
    
    virtual int_interface int_if;

    function new(string name = "int_monitor", uvm_component parent = null);
        super.new(name, parent);
        item_collected_port = new("item_collected_port", this);
    endfunction

    function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        if(!uvm_config_db#(virtual int_interface)::get(this, "", "int_if", int_if)) begin
            `uvm_fatal(get_type_name(), "Failed to get virtual interface")
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
        forever begin
            #1ns;
            if (uvm_hdl_read(path, current_value) && current_value == expected_value) begin
                break;
            end
        end
    endtask

    virtual task send_transaction(interrupt_info_s info, string dest);
        int_transaction trans = int_transaction::type_id::create("trans");
        trans.interrupt_info = info;
        trans.destination_name = dest;
        item_collected_port.write(trans);
        `uvm_info(get_type_name(), $sformatf("Detected interrupt '%s' at '%s'", info.name, dest), UVM_HIGH)
    endtask

endclass

`endif // INT_MONITOR_SV
