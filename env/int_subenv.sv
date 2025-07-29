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

    // Model object references (created by test case)
    int_register_model m_register_model;
    int_routing_model  m_routing_model;

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

        // Get model object references from configuration database (set by test case)
        if(!uvm_config_db#(int_register_model)::get(this, "", "register_model", m_register_model)) begin
            `uvm_fatal(get_type_name(), "Cannot get register_model from config DB - should be set by test case");
        end
        if(!uvm_config_db#(int_routing_model)::get(this, "", "routing_model", m_routing_model)) begin
            `uvm_fatal(get_type_name(), "Cannot get routing_model from config DB - should be set by test case");
        end

        // Share the event pool through configuration database
        uvm_config_db#(uvm_event_pool)::set(this, "m_monitor", "interrupt_event_pool", m_event_manager.get_event_pool());
        uvm_config_db#(int_event_manager)::set(this, "*", "event_manager", m_event_manager);
        // Also set event_manager specifically for monitor to handle race conditions
        uvm_config_db#(int_event_manager)::set(this, "m_monitor", "event_manager", m_event_manager);

        // Share model objects to sub-components
        uvm_config_db#(int_register_model)::set(this, "*", "register_model", m_register_model);
        uvm_config_db#(int_routing_model)::set(this, "*", "routing_model", m_routing_model);
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
