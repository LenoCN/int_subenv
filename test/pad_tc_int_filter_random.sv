`ifndef PAD_TC_INT_FILTER_RANDOM
`define PAD_TC_INT_FILTER_RANDOM
class pad_tc_int_filter_random extends pad_tc_int_filter;
    
    `uvm_component_utils(pad_tc_int_filter_random)
    function new(string name = "pad_tc_int_filter_random",uvm_component parent= null);
        super.new(name,parent);
    endfunction

endclass
`endif
