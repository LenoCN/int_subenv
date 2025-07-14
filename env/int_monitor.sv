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
        // Build the model to have access to all interrupt definitions
        int_routing_model::build();

        // Fork a process for each destination to monitor them in parallel
        // This is a conceptual representation. A real implementation would need to know the bus widths
        // and structure from the int_interface. We assume placeholder signals for now.
        // E.g. fork monitor_bus("AP", int_if.ap_interrupt_bus);
        //      fork monitor_bus("SCP", int_if.scp_interrupt_bus);
        //      ... and so on for all destination buses ...

        // For this example, we'll create a single continuous loop that conceptually checks all interrupts.
        forever begin
            #1ns; // Check every 1ns
            foreach (int_routing_model::interrupt_map[i]) begin
                check_and_report_interrupt(int_routing_model::interrupt_map[i]);
            end
        end
    endtask

    // Placeholder task to check all destinations for a given interrupt
    // A more robust implementation would monitor buses directly.
    virtual task check_and_report_interrupt(interrupt_info_s info);
        logic value;
        // Check AP destination
        if (info.rtl_path_ap != "" && uvm_hdl_read(info.rtl_path_ap, value) && value == 1) begin
            send_transaction(info, "AP");
        end
        // Check SCP destination
        if (info.rtl_path_scp != "" && uvm_hdl_read(info.rtl_path_scp, value) && value == 1) begin
            send_transaction(info, "SCP");
        end
        // ...checks for MCP, IMU, IO, OTHER_DIE would follow
    endtask

    virtual task send_transaction(interrupt_info_s info, string dest);
        int_transaction trans = int_transaction::type_id::create("trans");
        trans.interrupt_info = info;
        trans.destination_name = dest;
        item_collected_port.write(trans);
        // Add a mechanism to avoid re-triggering for a persistent interrupt
        // For example, wait until the signal goes low again.
        // `uvm_info(get_type_name(), $sformatf("Detected interrupt '%s' at '%s'", info.name, dest), UVM_DEBUG)
    endtask

endclass

`endif // INT_MONITOR_SV
