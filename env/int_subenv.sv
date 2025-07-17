`ifndef INT_SUBENV
`define INT_SUBENV

class int_subenv extends soc_base_subenv;
    `uvm_component_utils(int_subenv)

    int_monitor   m_monitor;
    int_scoreboard m_scoreboard;
    int_event_manager m_event_manager;
    int_sequencer m_sequencer;
    int_driver    m_driver;
    int_coverage  m_coverage;

    function new(string name = "int_subenv",uvm_component parent = null);
        super.new(name,parent);
    endfunction

    function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        m_monitor = int_monitor::type_id::create("m_monitor", this);
        m_scoreboard = int_scoreboard::type_id::create("m_scoreboard", this);
        m_sequencer = int_sequencer::type_id::create("m_sequencer", this);
        m_driver = int_driver::type_id::create("m_driver", this);
        m_event_manager = int_event_manager::type_id::create("m_event_manager");
        m_coverage = int_coverage::type_id::create("m_coverage", this);

        // Share the event pool through configuration database
        uvm_config_db#(uvm_event_pool)::set(this, "m_monitor", "interrupt_event_pool", m_event_manager.get_event_pool());
        uvm_config_db#(int_event_manager)::set(this, "*", "event_manager", m_event_manager);
    endfunction

    function void connect_phase(uvm_phase phase);
        super.connect_phase(phase);
        m_monitor.item_collected_port.connect(m_scoreboard.item_collected_export);
        m_sequencer.expected_port.connect(m_scoreboard.expected_export);

        // Connect coverage collector
        m_monitor.item_collected_port.connect(m_coverage.analysis_export);

        // Connect sequencer to driver
        m_driver.seq_item_port.connect(m_sequencer.seq_item_export);
    endfunction

endclass
`endif
