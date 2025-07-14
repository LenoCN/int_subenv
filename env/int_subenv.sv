`ifndef INT_SUBENV
`define INT_SUBENV
`include "env/int_monitor.sv"
`include "env/int_scoreboard.sv"

class int_subenv extends soc_base_subenv;
    `uvm_component_utils(int_subenv)

    int_monitor   m_monitor;
    int_scoreboard m_scoreboard;

    function new(string name = "int_subenv",uvm_component parent = null);
        super.new(name,parent);
    endfunction

    function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        m_monitor = int_monitor::type_id::create("m_monitor", this);
        m_scoreboard = int_scoreboard::type_id::create("m_scoreboard", this);
    endfunction
    
    function void connect_phase(uvm_phase phase);
        super.connect_phase(phase);
        m_monitor.item_collected_port.connect(m_scoreboard.item_collected_export);
    endfunction

endclass
`endif
