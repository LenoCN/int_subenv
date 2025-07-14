`ifndef INT_ROUTING_SEQUENCE_SV
`define INT_ROUTING_SEQUENCE_SV

class int_routing_sequence extends int_base_sequence;
    `uvm_object_utils(int_routing_sequence)

    function new(string name = "int_routing_sequence");
        super.new(name);
    endfunction

    virtual task body();
        // Build the interrupt model database
        int_routing_model::build();

        if (int_routing_model::interrupt_map.size() == 0) begin
            `uvm_warning(get_type_name(), "Interrupt map is empty. No checks will be performed.")
            return;
        end

        `uvm_info(get_type_name(), $sformatf("Starting interrupt routing check for %0d interrupts", int_routing_model::interrupt_map.size()), UVM_MEDIUM)

        // Iterate over all interrupts in the model and check their routing
        foreach (int_routing_model::interrupt_map[i]) begin
            check_interrupt_routing(int_routing_model::interrupt_map[i]);
        end

    endtask

    // Task to check routing for a single interrupt
    virtual task check_interrupt_routing(interrupt_info_s info);
        `uvm_info(get_type_name(), $sformatf("Checking interrupt: %s (group: %s, index: %0d)", info.name, info.group.name(), info.index), UVM_HIGH)

        // Force the source interrupt signal
        if (info.rtl_path_src == "") begin
            `uvm_warning(get_type_name(), $sformatf("Source path for interrupt '%s' is empty. Skipping.", info.name));
            return;
        end
        uvm_hdl_force(info.rtl_path_src, 1);
        #10ns; // Wait for propagation

        // Check destinations based on the model
        check_dest("AP", info.to_ap, info.rtl_path_ap, info.name);
        check_dest("SCP", info.to_scp, info.rtl_path_scp, info.name);
        check_dest("MCP", info.to_mcp, info.rtl_path_mcp, info.name);
        check_dest("IMU", info.to_imu, info.rtl_path_imu, info.name);
        check_dest("IO", info.to_io, info.rtl_path_io, info.name);
        check_dest("OTHER_DIE", info.to_other_die, info.rtl_path_other_die, info.name);

        // Release the forced signal
        uvm_hdl_release(info.rtl_path_src);
        #10ns; // Wait for release to propagate
    endtask

    // Helper task to check a specific destination
    virtual task check_dest(string dest_name, bit expected_route, string path, string int_name);
        logic value;
        if (path == "") return;

        if (!uvm_hdl_read(path, value)) begin
            `uvm_error(get_type_name(), $sformatf("Failed to read HDL path for %s: %s", dest_name, path))
            return;
        end

        if (expected_route && !value) begin
            `uvm_error(get_type_name(), $sformatf("Interrupt '%s' did NOT route to %s as expected. Path: %s", int_name, dest_name, path))
        end
        else if (!expected_route && value) begin
            `uvm_error(get_type_name(), $sformatf("Interrupt '%s' INCORRECTLY routed to %s. Path: %s", int_name, dest_name, path))
        end
        else begin
            `uvm_info(get_type_name(), $sformatf("Interrupt '%s' routing to %s verified (expected: %b, got: %b).", int_name, dest_name, expected_route, value), UVM_HIGH)
        end
    endtask

endclass

`endif // INT_ROUTING_SEQUENCE_SV
