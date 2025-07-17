// Example timing configuration for different DUT scenarios
// This file shows how to configure timing parameters for various use cases

// Example 1: Fast simulation timing (for quick regression tests)
initial begin
    uvm_config_db#(int)::set(null, "*", "level_hold_time_ns", 5);
    uvm_config_db#(int)::set(null, "*", "edge_pulse_width_ns", 2);
    uvm_config_db#(int)::set(null, "*", "pulse_width_ns", 1);
    uvm_config_db#(int)::set(null, "*", "detection_timeout_ns", 500);
end

// Example 2: DUT-specific timing (uncomment and modify as needed)
/*
initial begin
    // For a DUT with slower interrupt detection
    uvm_config_db#(int)::set(null, "*", "level_hold_time_ns", 20);
    uvm_config_db#(int)::set(null, "*", "edge_pulse_width_ns", 10);
    uvm_config_db#(int)::set(null, "*", "pulse_width_ns", 5);
    uvm_config_db#(int)::set(null, "*", "detection_timeout_ns", 2000);
end
*/

// Example 3: High-precision timing (for detailed timing analysis)
/*
initial begin
    uvm_config_db#(int)::set(null, "*", "level_hold_time_ns", 50);
    uvm_config_db#(int)::set(null, "*", "edge_pulse_width_ns", 25);
    uvm_config_db#(int)::set(null, "*", "pulse_width_ns", 10);
    uvm_config_db#(int)::set(null, "*", "detection_timeout_ns", 5000);
    uvm_config_db#(int)::set(null, "*", "detection_poll_interval_ns", 1);
end
*/

// Example 4: Clock-domain specific timing
/*
initial begin
    // Different timing for different clock domains
    // Main clock domain (100MHz = 10ns period)
    uvm_config_db#(int)::set(null, "*main_clk*", "level_hold_time_ns", 30);
    uvm_config_db#(int)::set(null, "*main_clk*", "edge_pulse_width_ns", 15);
    
    // Slow clock domain (50MHz = 20ns period)  
    uvm_config_db#(int)::set(null, "*slow_clk*", "level_hold_time_ns", 60);
    uvm_config_db#(int)::set(null, "*slow_clk*", "edge_pulse_width_ns", 30);
end
*/
