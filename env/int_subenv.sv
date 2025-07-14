`ifndef INT_SUBENV
`define INT_SUBENV
class int_subenv extends soc_base_subenv;
    `uvm_component_utils(int_subenv)

    function new(string name = "int_subenv",uvm_component parent = null);
        super.new(name,parent);
    endfunction

    function void build_phase(uvm_phase phase);
        super.build_phase(phase);
    endfunction

endclass
`endif
