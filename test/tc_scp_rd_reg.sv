`ifndef TC_SCP_RD_REG
`define TC_SCP_RD_REG

class tc_scp_rd_reg extends int_tc_base;
    bit[63:0] scp_por_csr;

    `uvm_component_utils(tc_scp_rd_reg)

    function new(string name = "tc_scp_rd_reg", uvm_component parent= null);
        super.new(name,parent);
        vip_map.set_vip_mode("scp",IS_MASTER);
    endfunction

    task pre_main_phase(uvm_phase phase);
        phase.raise_objection(this);
        phase.drop_objection(this);
    endtask

    extern virtual task main_phase   (uvm_phase phase);
endclass

task tc_scp_rd_reg::main_phase(uvm_phase phase);
    super.main_phase(phase);
    phase.raise_objection(this);

    soc_vargs::main_core = "scp";
    reg_seq.set_master("scp");
    $display("main core is scp");

    scp_por_csr = memory_map.get_start_addr("scp_por_csr", soc_vargs::main_core);
    `uvm_info(get_type_name(),$sformatf("base is :%0h", scp_por_csr),UVM_NONE)
    reg_seq.write_reg(scp_por_csr + 'h1000, 'h66661111);
    reg_seq.read_reg(scp_por_csr + 'h1000, prdata);
    `CMP_VAL(prdata, 'h66661111)


    #5us;
    phase.drop_objection(this);
endtask

`endif
