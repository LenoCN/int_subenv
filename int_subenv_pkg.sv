`ifndef INT_SUBENV_PKG
`define INT_SUBENV_PKG
package int_subenv_pkg;
    import uvm_pkg::*;
    import soc_com_pkg::*;  
    import bus_subenv_pkg::*;
    `include "config/timing_config.sv"
    `include "seq/int_def.sv"
    `include "seq/int_transaction.sv"
    `include "seq/int_stimulus_item.sv"
    `include "seq/int_register_model.sv"
    `include "seq/int_routing_model.sv"
    `include "env/int_scoreboard.sv"
    `include "env/int_event_manager.sv"
    `include "env/int_monitor.sv"
    `include "env/int_driver.sv"
    //`include "env/int_coverage.sv"
    `include "env/int_sequencer.sv"
    `include "env/int_subenv.sv"
    `include "seq/int_base_sequence.sv"
    `include "seq/int_lightweight_sequence.sv"
endpackage

`endif 
