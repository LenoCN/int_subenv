`ifndef TC_INT_ROUTING
`define TC_INT_ROUTING

class tc_int_routing extends int_tc_base;
    `uvm_component_utils(tc_int_routing)

    function new(string name = "tc_int_routing", uvm_component parent = null);
        super.new(name, parent);
    endfunction

    virtual task main_phase(uvm_phase phase);
        int_routing_sequence seq;
        super.main_phase(phase);
        phase.raise_objection(this);
        
        seq = int_routing_sequence::type_id::create("seq");
        // We run this sequence on a null sequencer since it uses direct HDL paths
        // to force/read signals and does not require a driver.
        seq.start(null);

        #5us;
        phase.drop_objection(this);
    endtask

endclass

`endif // TC_INT_ROUTING
