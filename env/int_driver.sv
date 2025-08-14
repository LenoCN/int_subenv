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
        `uvm_info(get_type_name(), "=== DRIVER STIMULUS GENERATION ===", UVM_MEDIUM)
        `uvm_info(get_type_name(), $sformatf("Driving interrupt stimulus: %s", item.interrupt_info.name), UVM_MEDIUM)
        `uvm_info(get_type_name(), $sformatf("  - Group: %s", item.interrupt_info.group.name()), UVM_MEDIUM)
        `uvm_info(get_type_name(), $sformatf("  - Index: %0d", item.interrupt_info.index), UVM_MEDIUM)
        `uvm_info(get_type_name(), $sformatf("  - Trigger: %s", item.interrupt_info.trigger.name()), UVM_MEDIUM)
        `uvm_info(get_type_name(), $sformatf("  - Polarity: %s", item.interrupt_info.polarity.name()), UVM_MEDIUM)
        `uvm_info(get_type_name(), $sformatf("  - Stimulus Type: %s", item.stimulus_type.name()), UVM_MEDIUM)
        `uvm_info(get_type_name(), $sformatf("  - RTL Source Path: %s", item.interrupt_info.rtl_path_src), UVM_MEDIUM)

        if (item.interrupt_info.rtl_path_src == "") begin
            `uvm_error(get_type_name(), $sformatf("Source path for interrupt '%s' is empty. Skipping stimulus generation.",
                         item.interrupt_info.name));
            return;
        end

        // Check if this is a merge interrupt - merge interrupts should not be directly stimulated
        if (is_merge_interrupt(item.interrupt_info.name)) begin
            `uvm_error(get_type_name(), $sformatf("Interrupt '%s' is a merge signal. Merge signals should not be directly stimulated. Skipping stimulus generation.",
                         item.interrupt_info.name));
            `uvm_info(get_type_name(), " To test merge signals, stimulate their source interrupts instead.", UVM_MEDIUM)
            return;
        end

        // Show expected destinations for this interrupt
        `uvm_info(get_type_name(), "Expected destinations for this interrupt:", UVM_MEDIUM)
        if (item.interrupt_info.to_ap) `uvm_info(get_type_name(), $sformatf("  ✅ AP: %s", item.interrupt_info.rtl_path_ap), UVM_MEDIUM);
        if (item.interrupt_info.to_scp) `uvm_info(get_type_name(), $sformatf("  ✅ SCP: %s", item.interrupt_info.rtl_path_scp), UVM_MEDIUM);
        if (item.interrupt_info.to_mcp) `uvm_info(get_type_name(), $sformatf("  ✅ MCP: %s", item.interrupt_info.rtl_path_mcp), UVM_MEDIUM);
        if (item.interrupt_info.to_accel) `uvm_info(get_type_name(), $sformatf("  ✅ ACCEL : %s", item.interrupt_info.rtl_path_accel), UVM_MEDIUM);
        if (item.interrupt_info.to_io) `uvm_info(get_type_name(), $sformatf("  ✅ IO: %s", item.interrupt_info.rtl_path_io), UVM_MEDIUM);
        if (item.interrupt_info.to_other_die) `uvm_info(get_type_name(), $sformatf("  ✅ OTHER_DIE: %s", item.interrupt_info.rtl_path_other_die), UVM_MEDIUM);

        // Select stimulus method based on trigger type and stimulus command
        `uvm_info(get_type_name(), $sformatf("Generating %s stimulus...", item.stimulus_type.name()), UVM_MEDIUM)
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

        `uvm_info(get_type_name(), $sformatf("✅ Stimulus generation completed for: %s", item.interrupt_info.name), UVM_MEDIUM)
        `uvm_info(get_type_name(), "=== END DRIVER STIMULUS ===", UVM_MEDIUM)
    endtask

    // Level-triggered interrupt stimulus
    virtual task drive_level_stimulus(interrupt_info_s info, bit assert_level);
        logic target_value;
        logic current_value;
        string action_str = assert_level ? "ASSERT" : "DEASSERT";

        `uvm_info(get_type_name(), $sformatf("Generating LEVEL stimulus (%s) for: %s", action_str, info.name), UVM_MEDIUM)

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

        // Read current value for debugging
        if (uvm_hdl_read(info.rtl_path_src, current_value)) begin
            `uvm_info(get_type_name(), $sformatf("Current signal value: %s = %0d", info.rtl_path_src, current_value), UVM_MEDIUM)
        end

        // Apply setup time
        `uvm_info(get_type_name(), $sformatf("Applying setup time: %0dns", timing_cfg.level_setup_time_ns), UVM_HIGH)
        #(timing_cfg.level_setup_time_ns * 1ns);

        `uvm_info(get_type_name(), $sformatf("Forcing signal: %s = %0d", info.rtl_path_src, target_value), UVM_MEDIUM)
        uvm_hdl_force(info.rtl_path_src, target_value);
        `uvm_info(get_type_name(), $sformatf("✅ Level stimulus applied: %s = %b (%s)", info.name, target_value, action_str), UVM_MEDIUM)

        // Apply propagation delay
        `uvm_info(get_type_name(), $sformatf("Applying propagation delay: %0dns", timing_cfg.propagation_delay_ns), UVM_HIGH)
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
            #((info.pulse_width_ns > 0 ? info.pulse_width_ns : timing_cfg.pulse_width_ns) * 1ns); // Use per-interrupt pulse width or default
            uvm_hdl_force(info.rtl_path_src, 0);
            #(timing_cfg.pulse_hold_time_ns * 1ns);
        end else if (info.polarity == ACTIVE_LOW) begin
            uvm_hdl_force(info.rtl_path_src, 1);
            #(timing_cfg.pulse_setup_time_ns * 1ns);
            uvm_hdl_force(info.rtl_path_src, 0);
            #((info.pulse_width_ns > 0 ? info.pulse_width_ns : timing_cfg.pulse_width_ns) * 1ns); // Use per-interrupt pulse width or default
            uvm_hdl_force(info.rtl_path_src, 1);
            #(timing_cfg.pulse_hold_time_ns * 1ns);
        end else begin
            `uvm_warning(get_type_name(), $sformatf("Unknown polarity for pulse interrupt '%s', using positive pulse", info.name));
            uvm_hdl_force(info.rtl_path_src, 0);
            #(timing_cfg.pulse_setup_time_ns * 1ns);
            uvm_hdl_force(info.rtl_path_src, 1);
            #((info.pulse_width_ns > 0 ? info.pulse_width_ns : timing_cfg.pulse_width_ns) * 1ns);
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

    // Function to check if an interrupt is a merge interrupt
    // Merge interrupts should not be directly stimulated
    virtual function bit is_merge_interrupt(string interrupt_name);
        return (interrupt_name == "merge_pll_intr_lock" ||
                interrupt_name == "merge_pll_intr_unlock" ||
                interrupt_name == "merge_pll_intr_frechangedone" ||
                interrupt_name == "merge_pll_intr_frechange_tot_done" ||
                interrupt_name == "merge_pll_intr_intdocfrac_err" ||
                interrupt_name == "iosub_normal_intr" ||
                interrupt_name == "iosub_slv_err_intr" ||
                interrupt_name == "iosub_ras_cri_intr" ||
                interrupt_name == "iosub_ras_eri_intr" ||
                interrupt_name == "iosub_ras_fhi_intr" ||
                interrupt_name == "iosub_abnormal_0_intr" ||
                interrupt_name == "iosub_abnormal_1_intr" ||
                interrupt_name.substr(0,7) == "pmerge_"
                );
    endfunction


endclass

`endif // INT_DRIVER_SV
