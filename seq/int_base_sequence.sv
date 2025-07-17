`ifndef INT_BASE_SEQUENCE
`define INT_BASE_SEQUENCE

class int_base_sequence extends uvm_sequence;
    `uvm_object_utils(int_base_sequence)

    // Event manager for interrupt detection handshake
    int_event_manager event_manager;

    // Analysis port for sending expected interrupts to scoreboard
    uvm_analysis_port #(int_exp_transaction) expected_port;

    function new(string name = "int_base_sequence");
        super.new(name);
    endfunction

    // Get event manager in pre_start
    task pre_start();
        super.pre_start();

        `uvm_info(get_type_name(), "Starting interrupt sequence initialization", UVM_LOW)

        // Get event manager from config DB
        if (!uvm_config_db#(int_event_manager)::get(null, "*", "event_manager", event_manager)) begin
            `uvm_error(get_type_name(), "Failed to get event_manager from config DB")
        end else begin
            `uvm_info(get_type_name(), "Successfully retrieved event_manager from config DB", UVM_HIGH)
        end

        // Create analysis port for expected interrupts
        expected_port = new("expected_port", this);
        `uvm_info(get_type_name(), "Created analysis port for expected interrupts", UVM_DEBUG)
        
        `uvm_info(get_type_name(), "Interrupt sequence initialization completed", UVM_LOW)
    endtask

    // Helper task to wait for interrupt detection with configurable timeout
    task wait_for_interrupt_detection(interrupt_info_s info, int timeout_ns = -1);
        // Use global timing config if no specific timeout provided
        if (timeout_ns == -1) begin
            init_timing_config();
            timeout_ns = global_timing_config.detection_timeout_ns;
        end

        `uvm_info(get_type_name(), $sformatf("Waiting for interrupt detection: %s (group: %s, index: %0d) with timeout %0d ns",
                 info.name, info.group.name(), info.index, timeout_ns), UVM_MEDIUM)
                 
        if (event_manager != null) begin
            `uvm_info(get_type_name(), $sformatf("Starting wait for interrupt: %s", info.name), UVM_HIGH)
            event_manager.wait_for_interrupt_detection(info, timeout_ns);
            `uvm_info(get_type_name(), $sformatf("Interrupt detected: %s", info.name), UVM_LOW)
        end else begin
            `uvm_error(get_type_name(), "event_manager is null in wait_for_interrupt_detection")
            `uvm_info(get_type_name(), "Using fallback delay of 10ns due to null event_manager", UVM_HIGH)
            #10ns; // Fallback delay
        end
    endtask

    // Helper function to add expected interrupt
    function void add_expected(interrupt_info_s info);
        int_exp_transaction exp_trans;
        int_sequencer int_seq;

        `uvm_info(get_type_name(), $sformatf("Adding expected interrupt: %s (group: %s, index: %0d, trigger: %s, polarity: %s)",
                 info.name, info.group.name(), info.index, info.trigger.name(), info.polarity.name()), UVM_MEDIUM)

        // Cast sequencer to int_sequencer
        if (!$cast(int_seq, m_sequencer)) begin
            `uvm_error(get_type_name(), "Sequencer is not of type int_sequencer")
            return;
        end

        exp_trans = int_exp_transaction::type_id::create("exp_trans");
        exp_trans.interrupt_info = info;
        
        `uvm_info(get_type_name(), $sformatf("Writing expected interrupt transaction for %s to scoreboard", info.name), UVM_HIGH)
        int_seq.expected_port.write(exp_trans);
        
        `uvm_info(get_type_name(), $sformatf("Expected interrupt %s successfully registered", info.name), UVM_DEBUG)
    endfunction
endclass
`endif
