`ifndef INT_DRIVER_SV
`define INT_DRIVER_SV

class int_driver extends uvm_driver #(int_stimulus_item);
    `uvm_component_utils(int_driver)

    virtual int_interface int_if;
    timing_config timing_cfg;

    function new(string name = "int_driver", uvm_component parent = null);
        super.new(name, parent);
    endfunction

    function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        if(!uvm_config_db#(virtual int_interface)::get(this, "", "int_if", int_if)) begin
            `uvm_fatal(get_type_name(), "Failed to get virtual interface")
        end

        // Initialize timing configuration
        init_timing_config();
        timing_cfg = global_timing_config;
    endfunction

    virtual task run_phase(uvm_phase phase);
        int_stimulus_item req;
        forever begin
            seq_item_port.get_next_item(req);
            drive_interrupt(req);
            seq_item_port.item_done();
        end
    endtask

    // Main driver task that selects appropriate stimulus method
    virtual task drive_interrupt(int_stimulus_item item);
        `uvm_info(get_type_name(), $sformatf("Driving interrupt: %s (trigger: %s, polarity: %s)",
                  item.interrupt_info.name, item.interrupt_info.trigger.name(), 
                  item.interrupt_info.polarity.name()), UVM_HIGH)

        if (item.interrupt_info.rtl_path_src == "") begin
            `uvm_warning(get_type_name(), $sformatf("Source path for interrupt '%s' is empty. Skipping.", 
                         item.interrupt_info.name));
            return;
        end

        // Select stimulus method based on trigger type and stimulus command
        case (item.stimulus_type)
            STIMULUS_ASSERT: begin
                case (item.interrupt_info.trigger)
                    LEVEL: drive_level_stimulus(item.interrupt_info, 1);
                    EDGE:  drive_edge_stimulus(item.interrupt_info);
                    PULSE: drive_pulse_stimulus(item.interrupt_info);
                    default: drive_level_stimulus(item.interrupt_info, 1);
                endcase
            end
            STIMULUS_DEASSERT: begin
                drive_level_stimulus(item.interrupt_info, 0);
            end
            STIMULUS_CLEAR: begin
                clear_interrupt_stimulus(item.interrupt_info);
            end
            default: begin
                `uvm_warning(get_type_name(), $sformatf("Unknown stimulus type for interrupt '%s'", 
                             item.interrupt_info.name));
            end
        endcase
    endtask

    // Level-triggered interrupt stimulus
    virtual task drive_level_stimulus(interrupt_info_s info, bit assert_level);
        logic target_value;
        
        if (assert_level) begin
            // Assert the interrupt
            if (info.polarity == ACTIVE_HIGH) begin
                target_value = 1;
            end else if (info.polarity == ACTIVE_LOW) begin
                target_value = 0;
            end else begin
                `uvm_warning(get_type_name(), $sformatf("Unknown polarity for level interrupt '%s', using active high", info.name));
                target_value = 1;
            end
        end else begin
            // Deassert the interrupt (opposite of assert)
            if (info.polarity == ACTIVE_HIGH) begin
                target_value = 0;
            end else if (info.polarity == ACTIVE_LOW) begin
                target_value = 1;
            end else begin
                target_value = 0;
            end
        end

        // Apply setup time
        #(timing_cfg.level_setup_time_ns * 1ns);

        uvm_hdl_force(info.rtl_path_src, target_value);
        `uvm_info(get_type_name(), $sformatf("Level stimulus: %s = %b", info.name, target_value), UVM_HIGH)

        // Apply propagation delay
        #(timing_cfg.propagation_delay_ns * 1ns);
    endtask

    // Edge-triggered interrupt stimulus
    virtual task drive_edge_stimulus(interrupt_info_s info);
        `uvm_info(get_type_name(), $sformatf("Generating edge stimulus for %s", info.name), UVM_HIGH)

        if (info.polarity == RISING_FALLING) begin
            // Both rising and falling edges
            uvm_hdl_force(info.rtl_path_src, 0);
            #(timing_cfg.edge_setup_time_ns * 1ns);
            uvm_hdl_force(info.rtl_path_src, 1);
            #(timing_cfg.edge_pulse_width_ns * 1ns); // Hold high for edge detection
        end else if (info.polarity == ACTIVE_HIGH) begin
            // Rising edge only
            uvm_hdl_force(info.rtl_path_src, 0);
            #(timing_cfg.edge_setup_time_ns * 1ns);
            uvm_hdl_force(info.rtl_path_src, 1);
            #(timing_cfg.edge_hold_time_ns * 1ns);
        end else if (info.polarity == ACTIVE_LOW) begin
            // Falling edge only
            uvm_hdl_force(info.rtl_path_src, 1);
            #(timing_cfg.edge_setup_time_ns * 1ns);
            uvm_hdl_force(info.rtl_path_src, 0);
            #(timing_cfg.edge_hold_time_ns * 1ns);
        end else begin
            `uvm_warning(get_type_name(), $sformatf("Unknown polarity for edge interrupt '%s', using rising edge", info.name));
            uvm_hdl_force(info.rtl_path_src, 0);
            #(timing_cfg.edge_setup_time_ns * 1ns);
            uvm_hdl_force(info.rtl_path_src, 1);
            #(timing_cfg.edge_hold_time_ns * 1ns);
        end
    endtask

    // Pulse-triggered interrupt stimulus
    virtual task drive_pulse_stimulus(interrupt_info_s info);
        `uvm_info(get_type_name(), $sformatf("Generating pulse stimulus for %s", info.name), UVM_HIGH)

        if (info.polarity == ACTIVE_HIGH) begin
            uvm_hdl_force(info.rtl_path_src, 0);
            #(timing_cfg.pulse_setup_time_ns * 1ns);
            uvm_hdl_force(info.rtl_path_src, 1);
            #(timing_cfg.pulse_width_ns * 1ns); // Configurable pulse width
            uvm_hdl_force(info.rtl_path_src, 0);
            #(timing_cfg.pulse_hold_time_ns * 1ns);
        end else if (info.polarity == ACTIVE_LOW) begin
            uvm_hdl_force(info.rtl_path_src, 1);
            #(timing_cfg.pulse_setup_time_ns * 1ns);
            uvm_hdl_force(info.rtl_path_src, 0);
            #(timing_cfg.pulse_width_ns * 1ns); // Configurable pulse width
            uvm_hdl_force(info.rtl_path_src, 1);
            #(timing_cfg.pulse_hold_time_ns * 1ns);
        end else begin
            `uvm_warning(get_type_name(), $sformatf("Unknown polarity for pulse interrupt '%s', using positive pulse", info.name));
            uvm_hdl_force(info.rtl_path_src, 0);
            #(timing_cfg.pulse_setup_time_ns * 1ns);
            uvm_hdl_force(info.rtl_path_src, 1);
            #(timing_cfg.pulse_width_ns * 1ns);
            uvm_hdl_force(info.rtl_path_src, 0);
            #(timing_cfg.pulse_hold_time_ns * 1ns);
        end
    endtask

    // Clear interrupt stimulus (release HDL force)
    virtual task clear_interrupt_stimulus(interrupt_info_s info);
        #(timing_cfg.clear_setup_time_ns * 1ns); // Setup time before clear
        uvm_hdl_release(info.rtl_path_src);
        `uvm_info(get_type_name(), $sformatf("Cleared interrupt stimulus for '%s'", info.name), UVM_HIGH)
        #(timing_cfg.clear_propagation_delay_ns * 1ns); // Configurable propagation delay
    endtask

endclass

`endif // INT_DRIVER_SV
