`ifndef INT_SEQUENCER_SV
`define INT_SEQUENCER_SV

class int_sequencer extends uvm_sequencer #(int_stimulus_item);
    `uvm_component_utils(int_sequencer)

    // Analysis port for expected interrupts from sequences
    uvm_analysis_port #(int_exp_transaction) expected_port;

    function new(string name = "int_sequencer", uvm_component parent = null);
        super.new(name, parent);
        expected_port = new("expected_port", this);
    endfunction
endclass

`endif // INT_SEQUENCER_SV
