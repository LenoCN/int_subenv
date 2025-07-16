`ifndef TC_ENHANCED_STIMULUS_TEST_SV
`define TC_ENHANCED_STIMULUS_TEST_SV

// Test case to verify enhanced stimulus methods for different interrupt types
class tc_enhanced_stimulus_test extends int_tc_base;
    `uvm_component_utils(tc_enhanced_stimulus_test)

    function new(string name = "tc_enhanced_stimulus_test", uvm_component parent = null);
        super.new(name, parent);
    endfunction

    virtual task run_phase(uvm_phase phase);
        enhanced_stimulus_sequence seq;
        
        phase.raise_objection(this);
        
        `uvm_info(get_type_name(), "Starting enhanced stimulus test", UVM_MEDIUM)
        
        seq = enhanced_stimulus_sequence::type_id::create("seq");
        seq.start(env.m_sequencer);
        
        #10us; // Allow time for all checks to complete
        
        `uvm_info(get_type_name(), "Enhanced stimulus test completed", UVM_MEDIUM)
        
        phase.drop_objection(this);
    endtask

endclass

// Sequence specifically for testing enhanced stimulus methods
class enhanced_stimulus_sequence extends int_base_sequence;
    `uvm_object_utils(enhanced_stimulus_sequence)

    function new(string name = "enhanced_stimulus_sequence");
        super.new(name);
    endfunction

    virtual task body();
        // Build the interrupt model database
        int_routing_model::build();

        if (int_routing_model::interrupt_map.size() == 0) begin
            `uvm_warning(get_type_name(), "Interrupt map is empty. No tests will be performed.")
            return;
        end

        `uvm_info(get_type_name(), "Starting enhanced stimulus method verification", UVM_MEDIUM)

        // Test different interrupt types separately
        test_level_interrupts();
        test_edge_interrupts();
        test_pulse_interrupts();

        `uvm_info(get_type_name(), "Enhanced stimulus method verification completed", UVM_MEDIUM)
    endtask

    // Test Level-triggered interrupts
    virtual task test_level_interrupts();
        interrupt_info_s level_interrupts[];
        int count = 0;

        `uvm_info(get_type_name(), "Testing Level-triggered interrupts", UVM_MEDIUM)

        // Find all level-triggered interrupts
        foreach (int_routing_model::interrupt_map[i]) begin
            if (int_routing_model::interrupt_map[i].trigger == LEVEL) begin
                level_interrupts = new[count + 1](level_interrupts);
                level_interrupts[count] = int_routing_model::interrupt_map[i];
                count++;
            end
        end

        `uvm_info(get_type_name(), $sformatf("Found %0d Level-triggered interrupts", count), UVM_MEDIUM)

        // Test a sample of level interrupts
        for (int i = 0; i < count && i < 5; i++) begin
            test_level_interrupt_stimulus(level_interrupts[i]);
        end
    endtask

    // Test Edge-triggered interrupts
    virtual task test_edge_interrupts();
        interrupt_info_s edge_interrupts[];
        int count = 0;

        `uvm_info(get_type_name(), "Testing Edge-triggered interrupts", UVM_MEDIUM)

        // Find all edge-triggered interrupts
        foreach (int_routing_model::interrupt_map[i]) begin
            if (int_routing_model::interrupt_map[i].trigger == EDGE) begin
                edge_interrupts = new[count + 1](edge_interrupts);
                edge_interrupts[count] = int_routing_model::interrupt_map[i];
                count++;
            end
        end

        `uvm_info(get_type_name(), $sformatf("Found %0d Edge-triggered interrupts", count), UVM_MEDIUM)

        // Test all edge interrupts (there should be only a few)
        foreach (edge_interrupts[i]) begin
            test_edge_interrupt_stimulus(edge_interrupts[i]);
        end
    endtask

    // Test Pulse-triggered interrupts
    virtual task test_pulse_interrupts();
        interrupt_info_s pulse_interrupts[];
        int count = 0;

        `uvm_info(get_type_name(), "Testing Pulse-triggered interrupts", UVM_MEDIUM)

        // Find all pulse-triggered interrupts
        foreach (int_routing_model::interrupt_map[i]) begin
            if (int_routing_model::interrupt_map[i].trigger == PULSE) begin
                pulse_interrupts = new[count + 1](pulse_interrupts);
                pulse_interrupts[count] = int_routing_model::interrupt_map[i];
                count++;
            end
        end

        `uvm_info(get_type_name(), $sformatf("Found %0d Pulse-triggered interrupts", count), UVM_MEDIUM)

        // Test all pulse interrupts
        foreach (pulse_interrupts[i]) begin
            test_pulse_interrupt_stimulus(pulse_interrupts[i]);
        end
    endtask

    // Test Level interrupt stimulus
    virtual task test_level_interrupt_stimulus(interrupt_info_s info);
        `uvm_info(get_type_name(), $sformatf("Testing Level stimulus for: %s (polarity: %s)", 
                  info.name, info.polarity.name()), UVM_HIGH)

        if (info.rtl_path_src == "") begin
            `uvm_warning(get_type_name(), $sformatf("Source path for interrupt '%s' is empty. Skipping.", info.name));
            return;
        end

        // Register expectations
        int_scoreboard::add_expected(info);

        // Apply level stimulus based on polarity
        if (info.polarity == ACTIVE_HIGH) begin
            `uvm_info(get_type_name(), $sformatf("Applying ACTIVE_HIGH level stimulus to %s", info.name), UVM_HIGH)
            uvm_hdl_force(info.rtl_path_src, 1);
            #10ns;
            uvm_hdl_release(info.rtl_path_src);
        end else if (info.polarity == ACTIVE_LOW) begin
            `uvm_info(get_type_name(), $sformatf("Applying ACTIVE_LOW level stimulus to %s", info.name), UVM_HIGH)
            uvm_hdl_force(info.rtl_path_src, 0);
            #10ns;
            uvm_hdl_release(info.rtl_path_src);
        end else begin
            `uvm_warning(get_type_name(), $sformatf("Unknown polarity for %s, using ACTIVE_HIGH", info.name));
            uvm_hdl_force(info.rtl_path_src, 1);
            #10ns;
            uvm_hdl_release(info.rtl_path_src);
        end

        #10ns; // Wait for propagation
    endtask

    // Test Edge interrupt stimulus
    virtual task test_edge_interrupt_stimulus(interrupt_info_s info);
        `uvm_info(get_type_name(), $sformatf("Testing Edge stimulus for: %s (polarity: %s)", 
                  info.name, info.polarity.name()), UVM_HIGH)

        if (info.rtl_path_src == "") begin
            `uvm_warning(get_type_name(), $sformatf("Source path for interrupt '%s' is empty. Skipping.", info.name));
            return;
        end

        // Register expectations
        int_scoreboard::add_expected(info);

        // Apply edge stimulus based on polarity
        if (info.polarity == RISING_FALLING) begin
            `uvm_info(get_type_name(), $sformatf("Applying RISING_FALLING edge stimulus to %s", info.name), UVM_HIGH)
            // Generate both rising and falling edges
            uvm_hdl_force(info.rtl_path_src, 0);
            #2ns;
            uvm_hdl_force(info.rtl_path_src, 1); // Rising edge
            #5ns;
            uvm_hdl_force(info.rtl_path_src, 0); // Falling edge
            #5ns;
            uvm_hdl_release(info.rtl_path_src);
        end else if (info.polarity == ACTIVE_HIGH) begin
            `uvm_info(get_type_name(), $sformatf("Applying ACTIVE_HIGH edge stimulus to %s", info.name), UVM_HIGH)
            // Generate rising edge only
            uvm_hdl_force(info.rtl_path_src, 0);
            #2ns;
            uvm_hdl_force(info.rtl_path_src, 1);
            #5ns;
            uvm_hdl_force(info.rtl_path_src, 0);
            #2ns;
            uvm_hdl_release(info.rtl_path_src);
        end else if (info.polarity == ACTIVE_LOW) begin
            `uvm_info(get_type_name(), $sformatf("Applying ACTIVE_LOW edge stimulus to %s", info.name), UVM_HIGH)
            // Generate falling edge only
            uvm_hdl_force(info.rtl_path_src, 1);
            #2ns;
            uvm_hdl_force(info.rtl_path_src, 0);
            #5ns;
            uvm_hdl_force(info.rtl_path_src, 1);
            #2ns;
            uvm_hdl_release(info.rtl_path_src);
        end else begin
            `uvm_warning(get_type_name(), $sformatf("Unknown polarity for edge interrupt %s, using rising edge", info.name));
            uvm_hdl_force(info.rtl_path_src, 0);
            #2ns;
            uvm_hdl_force(info.rtl_path_src, 1);
            #5ns;
            uvm_hdl_force(info.rtl_path_src, 0);
            #2ns;
            uvm_hdl_release(info.rtl_path_src);
        end

        #10ns; // Wait for propagation
    endtask

    // Test Pulse interrupt stimulus
    virtual task test_pulse_interrupt_stimulus(interrupt_info_s info);
        `uvm_info(get_type_name(), $sformatf("Testing Pulse stimulus for: %s (polarity: %s)", 
                  info.name, info.polarity.name()), UVM_HIGH)

        if (info.rtl_path_src == "") begin
            `uvm_warning(get_type_name(), $sformatf("Source path for interrupt '%s' is empty. Skipping.", info.name));
            return;
        end

        // Register expectations
        int_scoreboard::add_expected(info);

        // Apply pulse stimulus based on polarity
        if (info.polarity == ACTIVE_HIGH) begin
            `uvm_info(get_type_name(), $sformatf("Applying ACTIVE_HIGH pulse stimulus to %s", info.name), UVM_HIGH)
            uvm_hdl_force(info.rtl_path_src, 0);
            #1ns;
            uvm_hdl_force(info.rtl_path_src, 1);
            #1ns; // Very short pulse
            uvm_hdl_force(info.rtl_path_src, 0);
            #1ns;
            uvm_hdl_release(info.rtl_path_src);
        end else if (info.polarity == ACTIVE_LOW) begin
            `uvm_info(get_type_name(), $sformatf("Applying ACTIVE_LOW pulse stimulus to %s", info.name), UVM_HIGH)
            uvm_hdl_force(info.rtl_path_src, 1);
            #1ns;
            uvm_hdl_force(info.rtl_path_src, 0);
            #1ns; // Very short pulse
            uvm_hdl_force(info.rtl_path_src, 1);
            #1ns;
            uvm_hdl_release(info.rtl_path_src);
        end else begin
            `uvm_warning(get_type_name(), $sformatf("Unknown polarity for pulse interrupt %s, using positive pulse", info.name));
            uvm_hdl_force(info.rtl_path_src, 0);
            #1ns;
            uvm_hdl_force(info.rtl_path_src, 1);
            #1ns;
            uvm_hdl_force(info.rtl_path_src, 0);
            #1ns;
            uvm_hdl_release(info.rtl_path_src);
        end

        #10ns; // Wait for propagation
    endtask

endclass

`endif // TC_ENHANCED_STIMULUS_TEST_SV
