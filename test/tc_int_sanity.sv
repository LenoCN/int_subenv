`ifndef TC_INT_SANITY
`define TC_INT_SANITY

//addr_info:    $MDL_PATH/subenv/bus_subenv/database/addr_info.db

class tc_int_sanity extends int_tc_base;
    bit[63:0] scp_por_csr;

    `uvm_component_utils(tc_int_sanity)

    function new(string name = "tc_int_sanity", uvm_component parent= null);
        super.new(name,parent);
    endfunction

    task pre_main_phase(uvm_phase phase);
        phase.raise_objection(this);
        phase.drop_objection(this);
    endtask

    extern virtual task main_phase   (uvm_phase phase);
endclass

task tc_int_sanity::main_phase(uvm_phase phase);
    super.main_phase(phase);
    phase.raise_objection(this);

    `uvm_info(get_type_name(),$sformatf("int_if test_signal: %0h", int_if.test_signal),UVM_NONE)

    scp_por_csr = memory_map.get_start_addr("scp_por_csr", soc_vargs::main_core);
    `uvm_info(get_type_name(),$sformatf("base is :%0h", scp_por_csr),UVM_NONE)
    reg_seq.write_reg(scp_por_csr + 'h1000, 'h55551111);
    reg_seq.read_reg(scp_por_csr + 'h1000, prdata);
    `CMP_VAL(prdata, 'h55551111)


    #5us;
    phase.drop_objection(this);
endtask

`endif
