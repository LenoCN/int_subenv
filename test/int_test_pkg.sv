`ifndef INT_TEST_PKG
`define INT_TEST_PKG
package int_test_pkg;
    import uvm_pkg::*;
    import svt_axi_uvm_pkg::*;
    import soc_com_pkg::*;
    import com_subenv_pkg::*;  
    import bus_subenv_pkg::*;
    import efuse_subenv_pkg::*;
    import pad_subenv_pkg::*;
    import crg_subenv_pkg::*;
    import int_subenv_pkg::*;
    
    `include "int_tc_base.sv"
    `include "tc_int_sanity.sv"
    `include "tc_scp_rd_reg.sv"
    `include "tc_int_routing.sv"

endpackage
import int_test_pkg::*;
`endif
