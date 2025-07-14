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

    // Task to trigger routing for a single interrupt
    virtual task check_interrupt_routing(interrupt_info_s info);
        `uvm_info(get_type_name(), $sformatf("Forcing interrupt: %s (group: %s, index: %0d)", info.name, info.group.name(), info.index), UVM_HIGH)

        // Force the source interrupt signal
        if (info.rtl_path_src == "") begin
            `uvm_warning(get_type_name(), $sformatf("Source path for interrupt '%s' is empty. Skipping.", info.name));
            return;
        end
        
        // Register expectations with the scoreboard BEFORE forcing the interrupt
        int_scoreboard::add_expected(info);

        uvm_hdl_force(info.rtl_path_src, 1);
        #10ns; // Wait for propagation

        // Release the forced signal
        uvm_hdl_release(info.rtl_path_src);
        #10ns; // Wait for release to propagate and for monitor to detect it
    endtask

endclass

`endif // INT_ROUTING_SEQUENCE_SV
