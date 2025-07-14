`ifndef INT_TC_BASE
`define INT_TC_BASE

class int_tc_base extends soc_tc_base;
    bit[31:0] prdata;
    
    virtual global_interface  global_if;       
    virtual int_interface     int_if;    
    `uvm_component_utils(int_tc_base)

    function new(string name = "int_tc_base",uvm_component parent= null);
        super.new(name,parent);
    endfunction
    
    function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        if(!uvm_config_db#(virtual global_interface)::get(uvm_root::get(),"","global_if",global_if)) begin
            `uvm_fatal(get_type_name(),"can not get global interface");
        end        
        if(!uvm_config_db#(virtual int_interface)::get(this,"","int_if",int_if)) begin
            `uvm_fatal(get_type_name(), $sformatf("can not get int interface"));
        end 
        uvm_top.set_timeout(13_000_000, 0); //ns
    endfunction 

    function void connect_phase(uvm_phase phase);
        super.connect_phase(phase);
    endfunction

    task pre_reset_phase(uvm_phase phase);
        phase.raise_objection(this);
        phase.drop_objection(this);
    endtask    

    task post_reset_phase(uvm_phase phase);
        phase.raise_objection(this);
        phase.drop_objection(this);
    endtask

    task main_phase(uvm_phase phase);
    phase.raise_objection(this);
    phase.drop_objection(this);
    endtask : main_phase

    task post_shutdown_phase(uvm_phase phase);
    endtask
endclass


`endif
