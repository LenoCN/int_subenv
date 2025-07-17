`ifndef TC_INT_ROUTING
`define TC_INT_ROUTING

class tc_int_routing extends int_tc_base;
    `uvm_component_utils(tc_int_routing)

    function new(string name = "tc_int_routing", uvm_component parent = null);
        super.new(name, parent);
    endfunction

    virtual task main_phase(uvm_phase phase);
        int_lightweight_sequence seq;
        int_subenv int_env;
        super.main_phase(phase);
        phase.raise_objection(this);

        // Cast the base subenv to int_subenv to access m_sequencer
        if (!$cast(int_env, env.subenv["int_subenv"])) begin
            `uvm_fatal(get_type_name(), "Failed to cast subenv[\"int_subenv\"] to int_subenv")
        end

        seq = int_lightweight_sequence::type_id::create("seq");
        // Use the new lightweight sequence with driver architecture
        seq.start(int_env.m_sequencer);

        #5us;
        phase.drop_objection(this);
    endtask

endclass

`endif // TC_INT_ROUTING
