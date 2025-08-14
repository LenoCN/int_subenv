`ifndef PAD_TC_INT_FILTER_1MS
`define PAD_TC_INT_FILTER_1MS
class pad_tc_int_filter_1ms extends pad_tc_int_filter;
    
    `uvm_component_utils(pad_tc_int_filter_1ms)
    function new(string name = "pad_tc_int_filter_1ms",uvm_component parent= null);
        super.new(name,parent);
    endfunction

    task test_int(int nu);
        bit[31:0] rd;
        bit[31:0] db_high_cnt_w,polarity_cnt_ns;
        bit[31:0] db_low_cnt_w,upolarity_cnt_ns;
        bit en,typee,polarity,both_edge;
        int ders[8];

        ders = '{1,-1,3,-3,4,-4,5,-5};
        en        = $urandom_range(0,1);
        typee     = $urandom_range(0,1);
        polarity  = $urandom_range(0,1);
        pad_if.u_int_if.INT[nu] <= ~polarity;
        both_edge = $urandom_range(0,1);
        db_high_cnt_w=$urandom_range(249999,249999);
        db_low_cnt_w =$urandom_range(249999,249999);
        polarity_cnt_ns  = (polarity ? (db_high_cnt_w+1)*4:(db_low_cnt_w+1)*4);
        upolarity_cnt_ns = (polarity ? (db_low_cnt_w+1)*4:(db_high_cnt_w+1)*4);
        reg_seq.read_reg(iosub_sysctrl_start_addr+'h12b0+'h10*nu,rd);
        reg_seq.write_reg(iosub_sysctrl_start_addr+'h12b0+'h10*nu,rd&32'hFFFF_FFFE);
        reg_seq.read_reg(iosub_sysctrl_start_addr+'h12b0+'h10*nu,rd);
        reg_seq.write_reg(iosub_sysctrl_start_addr+'h12b0+'h10*nu,(rd&32'hFFFF_FFF1)|(both_edge<<3)|(polarity<<2)|(typee<<1));
        reg_seq.write_reg(iosub_sysctrl_start_addr+'h12b4+'h10*nu,db_high_cnt_w);
        reg_seq.write_reg(iosub_sysctrl_start_addr+'h12b8+'h10*nu,db_low_cnt_w);
        reg_seq.read_reg(iosub_sysctrl_start_addr+'h12b0+'h10*nu,rd);
        reg_seq.write_reg(iosub_sysctrl_start_addr+'h12b0+'h10*nu,rd|(en<<0));

        pad_if.u_int_if.INT[nu] <= polarity;
        #((polarity_cnt_ns+ders[$urandom_range(0,7)])*1ns);
        pad_if.u_int_if.INT[nu] <= ~polarity;
    endtask

    task main_phase(uvm_phase phase);
        phase.raise_objection(this);
        `uvm_info(get_type_name(),"enter main_phase",UVM_NONE)
        fork
            test_int(0);
            test_int(1);
            test_int(2);
            test_int(3);
            test_int(4);
            test_int(5);
            test_int(6);
            test_int(7);
            test_int(8); 
            test_int(9); 
            test_int(10);
            test_int(11);
            test_int(12);
            test_int(13);
            test_int(14);
            test_int(15);
        join
        `uvm_info(get_type_name(),"finish main_phase",UVM_NONE)
        phase.drop_objection(this);
    endtask 
endclass
`endif
