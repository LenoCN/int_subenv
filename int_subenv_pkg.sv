`ifndef INT_SUBENV_PKG
`define INT_SUBENV_PKG
package int_subenv_pkg;
    import uvm_pkg::*;
    import soc_com_pkg::*;  
    import bus_subenv_pkg::*;
    `include "env/int_subenv.sv"
    `include "seq/int_def.sv"
    `include "seq/int_routing_model.sv"
    `include "seq/int_base_sequence.sv"
    `include "seq/int_routing_sequence.sv"
endpackage

`endif 
