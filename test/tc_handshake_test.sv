`ifndef TC_HANDSHAKE_TEST_SV
`define TC_HANDSHAKE_TEST_SV

class tc_handshake_test extends int_tc_base;
    `uvm_component_utils(tc_handshake_test)

    function new(string name = "tc_handshake_test", uvm_component parent = null);
        super.new(name, parent);
    endfunction

    virtual function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        `uvm_info(get_type_name(), "Building handshake test...", UVM_LOW)
    endfunction

    virtual task run_phase(uvm_phase phase);
        int_lightweight_sequence seq;

        phase.raise_objection(this);

        `uvm_info(get_type_name(), "Starting handshake test...", UVM_LOW)

        // Create and start the sequence
        seq = int_lightweight_sequence::type_id::create("seq");
        seq.start(env.m_sequencer);

        `uvm_info(get_type_name(), "Handshake test completed successfully", UVM_LOW)

        phase.drop_objection(this);
    endtask

    virtual function void report_phase(uvm_phase phase);
        super.report_phase(phase);
        `uvm_info(get_type_name(), "Handshake test report phase", UVM_LOW)
    endfunction

endclass

`endif // TC_HANDSHAKE_TEST_SV
