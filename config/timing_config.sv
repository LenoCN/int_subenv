`ifndef TIMING_CONFIG_SV
`define TIMING_CONFIG_SV

// Timing configuration parameters for interrupt stimulus
class timing_config extends uvm_object;
    `uvm_object_utils(timing_config)

    // Level interrupt timing parameters
    int level_hold_time_ns = 10;           // How long to hold level interrupt
    int level_setup_time_ns = 1;           // Setup time before assertion
    int level_release_delay_ns = 1;        // Delay after release

    // Edge interrupt timing parameters  
    int edge_setup_time_ns = 2;            // Setup time before edge
    int edge_pulse_width_ns = 5;           // Width of edge pulse
    int edge_hold_time_ns = 5;             // Hold time after edge

    // Pulse interrupt timing parameters
    int pulse_width_ns = 1;                // Width of pulse
    int pulse_setup_time_ns = 1;           // Setup time before pulse
    int pulse_hold_time_ns = 1;            // Hold time after pulse

    // Detection timing parameters
    int detection_timeout_ns = 1000;       // Timeout for interrupt detection
    int detection_poll_interval_ns = 1;    // Polling interval for detection
    int propagation_delay_ns = 1;          // General propagation delay

    // Clear timing parameters
    int clear_propagation_delay_ns = 10;   // Time to wait after clear
    int clear_setup_time_ns = 1;           // Setup time before clear

    function new(string name = "timing_config");
        super.new(name);
    endfunction

    // Load timing parameters from configuration database or file
    function void load_from_config();
        // Try to get parameters from UVM config database
        if (!uvm_config_db#(int)::get(null, "*", "level_hold_time_ns", level_hold_time_ns)) begin
            `uvm_info("TIMING_CONFIG", "Using default level_hold_time_ns", UVM_HIGH)
        end
        
        if (!uvm_config_db#(int)::get(null, "*", "edge_pulse_width_ns", edge_pulse_width_ns)) begin
            `uvm_info("TIMING_CONFIG", "Using default edge_pulse_width_ns", UVM_HIGH)
        end
        
        if (!uvm_config_db#(int)::get(null, "*", "pulse_width_ns", pulse_width_ns)) begin
            `uvm_info("TIMING_CONFIG", "Using default pulse_width_ns", UVM_HIGH)
        end
        
        if (!uvm_config_db#(int)::get(null, "*", "detection_timeout_ns", detection_timeout_ns)) begin
            `uvm_info("TIMING_CONFIG", "Using default detection_timeout_ns", UVM_HIGH)
        end

        `uvm_info("TIMING_CONFIG", $sformatf("Loaded timing config: level_hold=%0dns, edge_width=%0dns, pulse_width=%0dns, timeout=%0dns",
                  level_hold_time_ns, edge_pulse_width_ns, pulse_width_ns, detection_timeout_ns), UVM_MEDIUM)
    endfunction

    // Validate timing parameters
    function bit validate();
        bit valid = 1;
        
        if (level_hold_time_ns <= 0) begin
            `uvm_error("TIMING_CONFIG", "level_hold_time_ns must be positive")
            valid = 0;
        end
        
        if (edge_pulse_width_ns <= 0) begin
            `uvm_error("TIMING_CONFIG", "edge_pulse_width_ns must be positive")
            valid = 0;
        end
        
        if (pulse_width_ns <= 0) begin
            `uvm_error("TIMING_CONFIG", "pulse_width_ns must be positive")
            valid = 0;
        end
        
        if (detection_timeout_ns <= 0) begin
            `uvm_error("TIMING_CONFIG", "detection_timeout_ns must be positive")
            valid = 0;
        end
        
        return valid;
    endfunction

    // Print current configuration
    function void print_config();
        `uvm_info("TIMING_CONFIG", "=== Timing Configuration ===", UVM_LOW)
        `uvm_info("TIMING_CONFIG", $sformatf("Level interrupts:"), UVM_LOW)
        `uvm_info("TIMING_CONFIG", $sformatf("  Hold time: %0d ns", level_hold_time_ns), UVM_LOW)
        `uvm_info("TIMING_CONFIG", $sformatf("  Setup time: %0d ns", level_setup_time_ns), UVM_LOW)
        `uvm_info("TIMING_CONFIG", $sformatf("  Release delay: %0d ns", level_release_delay_ns), UVM_LOW)
        
        `uvm_info("TIMING_CONFIG", $sformatf("Edge interrupts:"), UVM_LOW)
        `uvm_info("TIMING_CONFIG", $sformatf("  Setup time: %0d ns", edge_setup_time_ns), UVM_LOW)
        `uvm_info("TIMING_CONFIG", $sformatf("  Pulse width: %0d ns", edge_pulse_width_ns), UVM_LOW)
        `uvm_info("TIMING_CONFIG", $sformatf("  Hold time: %0d ns", edge_hold_time_ns), UVM_LOW)
        
        `uvm_info("TIMING_CONFIG", $sformatf("Pulse interrupts:"), UVM_LOW)
        `uvm_info("TIMING_CONFIG", $sformatf("  Pulse width: %0d ns", pulse_width_ns), UVM_LOW)
        `uvm_info("TIMING_CONFIG", $sformatf("  Setup time: %0d ns", pulse_setup_time_ns), UVM_LOW)
        `uvm_info("TIMING_CONFIG", $sformatf("  Hold time: %0d ns", pulse_hold_time_ns), UVM_LOW)
        
        `uvm_info("TIMING_CONFIG", $sformatf("Detection:"), UVM_LOW)
        `uvm_info("TIMING_CONFIG", $sformatf("  Timeout: %0d ns", detection_timeout_ns), UVM_LOW)
        `uvm_info("TIMING_CONFIG", $sformatf("  Poll interval: %0d ns", detection_poll_interval_ns), UVM_LOW)
        `uvm_info("TIMING_CONFIG", "============================", UVM_LOW)
    endfunction

endclass

// Global timing configuration instance
timing_config global_timing_config;

// Initialize global timing configuration
function void init_timing_config();
    if (global_timing_config == null) begin
        global_timing_config = timing_config::type_id::create("global_timing_config");
        global_timing_config.load_from_config();
        if (!global_timing_config.validate()) begin
            `uvm_fatal("TIMING_CONFIG", "Invalid timing configuration")
        end
        global_timing_config.print_config();
    end
endfunction

`endif // TIMING_CONFIG_SV
