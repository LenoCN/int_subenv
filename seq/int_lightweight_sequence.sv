`ifndef INT_LIGHTWEIGHT_SEQUENCE_SV
`define INT_LIGHTWEIGHT_SEQUENCE_SV

// Lightweight interrupt routing sequence that uses driver for stimulus generation
// This sequence focuses on decision logic while delegating stimulus details to the driver
class int_lightweight_sequence extends int_base_sequence;
    `uvm_object_utils(int_lightweight_sequence)

    function new(string name = "int_lightweight_sequence");
        super.new(name);
    endfunction

    virtual task body();
        `uvm_info(get_type_name(), "Starting lightweight interrupt sequence execution", UVM_LOW)
        
        // Build the interrupt model database
        `uvm_info(get_type_name(), "Building interrupt routing model database", UVM_HIGH)
        int_routing_model::build();

        if (int_routing_model::interrupt_map.size() == 0) begin
            `uvm_warning(get_type_name(), "Interrupt map is empty. No checks will be performed.")
            return;
        end

        `uvm_info(get_type_name(), $sformatf("Starting lightweight interrupt routing check for %0d interrupts",
                  int_routing_model::interrupt_map.size()), UVM_LOW)

        // Iterate over all interrupts in the model and check their routing
        `uvm_info(get_type_name(), "Beginning iteration through all interrupts in the model", UVM_DEBUG)
        foreach (int_routing_model::interrupt_map[i]) begin
            `uvm_info(get_type_name(), $sformatf("Processing interrupt %0d of %0d: %s",
                     i+1, int_routing_model::interrupt_map.size(),
                     int_routing_model::interrupt_map[i].name), UVM_DEBUG)
            check_interrupt_routing(int_routing_model::interrupt_map[i]);
        end

        `uvm_info(get_type_name(), "Lightweight interrupt routing check completed successfully", UVM_LOW)
    endtask

    // Main routing check - much simpler than the original version
    virtual task check_interrupt_routing(interrupt_info_s info);
        `uvm_info(get_type_name(), $sformatf("Checking interrupt: %s (group: %s, index: %0d, trigger: %s, polarity: %s)",
                  info.name, info.group.name(), info.index, info.trigger.name(), info.polarity.name()), UVM_MEDIUM)

        // Check if this is a merge interrupt
        if (int_routing_model::is_merge_interrupt(info.name)) begin
            `uvm_info(get_type_name(), $sformatf("Interrupt %s identified as a merge interrupt", info.name), UVM_HIGH)
            check_merge_interrupt_routing(info);
        end else begin
            `uvm_info(get_type_name(), $sformatf("Interrupt %s identified as a single interrupt", info.name), UVM_HIGH)
            // Simple single interrupt test
            test_single_interrupt(info);
        end
        
        `uvm_info(get_type_name(), $sformatf("Completed routing check for interrupt: %s", info.name), UVM_HIGH)
    endtask

    // Test a single interrupt using the driver
    virtual task test_single_interrupt(interrupt_info_s info);
        int_stimulus_item stim_item;

        `uvm_info(get_type_name(), $sformatf("Testing single interrupt: %s", info.name), UVM_MEDIUM)

        if (info.rtl_path_src == "") begin
            `uvm_warning(get_type_name(), $sformatf("Source path for interrupt '%s' is empty. Skipping.", info.name));
            return;
        end

        `uvm_info(get_type_name(), $sformatf("RTL source path for interrupt %s: %s",
                 info.name, info.rtl_path_src), UVM_HIGH)

        // Register expectations with the scoreboard BEFORE sending stimulus
        `uvm_info(get_type_name(), $sformatf("Registering expected interrupt: %s", info.name), UVM_HIGH)
        add_expected(info);

        // Create and send stimulus item to driver
        `uvm_info(get_type_name(), $sformatf("Creating ASSERT stimulus for interrupt: %s", info.name), UVM_HIGH)
        stim_item = int_stimulus_item::create_stimulus(info, STIMULUS_ASSERT);
        
        `uvm_info(get_type_name(), $sformatf("Sending ASSERT stimulus for interrupt: %s", info.name), UVM_DEBUG)
        start_item(stim_item);
        finish_item(stim_item);

        `uvm_info(get_type_name(), $sformatf("Waiting for detection of interrupt: %s", info.name), UVM_HIGH)
        // Wait for interrupt to be detected by monitor using proper UVM approach
        wait_for_interrupt_detection(info);

        // Send clear command to driver (simulates software clearing)
        `uvm_info(get_type_name(), $sformatf("Creating CLEAR stimulus for interrupt: %s", info.name), UVM_HIGH)
        stim_item = int_stimulus_item::create_stimulus(info, STIMULUS_CLEAR);
        
        `uvm_info(get_type_name(), $sformatf("Sending CLEAR stimulus for interrupt: %s", info.name), UVM_DEBUG)
        start_item(stim_item);
        finish_item(stim_item);

        `uvm_info(get_type_name(), $sformatf("Waiting for clear propagation of interrupt: %s", info.name), UVM_DEBUG)
        #10ns; // Wait for clear to propagate
        
        `uvm_info(get_type_name(), $sformatf("Completed testing of single interrupt: %s", info.name), UVM_MEDIUM)
    endtask

    // Simplified merge interrupt handling
    virtual task check_merge_interrupt_routing(interrupt_info_s merge_info);
        interrupt_info_s source_interrupts[];
        int num_sources;

        `uvm_info(get_type_name(), $sformatf("Checking merge interrupt: %s", merge_info.name), UVM_LOW)

        // Get all source interrupts that should be merged into this interrupt
        `uvm_info(get_type_name(), $sformatf("Retrieving source interrupts for merge interrupt: %s",
                 merge_info.name), UVM_HIGH)
        num_sources = int_routing_model::get_merge_sources(merge_info.name, source_interrupts);

        if (num_sources == 0) begin
            `uvm_warning(get_type_name(), $sformatf("No source interrupts found for merge interrupt '%s'", merge_info.name));
            return;
        end

        `uvm_info(get_type_name(), $sformatf("Found %0d source interrupts for merge interrupt '%s'",
                  num_sources, merge_info.name), UVM_MEDIUM)

        // Test each source interrupt individually
        `uvm_info(get_type_name(), $sformatf("Testing each source interrupt individually for merge interrupt: %s",
                 merge_info.name), UVM_HIGH)
        foreach (source_interrupts[i]) begin
            `uvm_info(get_type_name(), $sformatf("Testing source interrupt %0d of %0d: %s",
                     i+1, num_sources, source_interrupts[i].name), UVM_DEBUG)
            test_merge_source(merge_info, source_interrupts[i]);
        end

        // Test multiple sources simultaneously if there are multiple sources
        if (num_sources > 1) begin
            `uvm_info(get_type_name(), $sformatf("Testing multiple sources simultaneously for merge interrupt: %s",
                     merge_info.name), UVM_MEDIUM)
            test_multiple_merge_sources(merge_info, source_interrupts);
        end
        
        `uvm_info(get_type_name(), $sformatf("Completed merge interrupt routing check for: %s",
                 merge_info.name), UVM_LOW)
    endtask

    // Test single merge source using driver
    virtual task test_merge_source(interrupt_info_s merge_info, interrupt_info_s source_info);
        int_stimulus_item stim_item;

        `uvm_info(get_type_name(), $sformatf("Testing merge source: %s -> %s", source_info.name, merge_info.name), UVM_MEDIUM)

        if (source_info.rtl_path_src == "") begin
            `uvm_warning(get_type_name(), $sformatf("Source path for merge source '%s' is empty. Skipping.", source_info.name));
            return;
        end

        `uvm_info(get_type_name(), $sformatf("RTL source path for merge source %s: %s",
                 source_info.name, source_info.rtl_path_src), UVM_HIGH)

        // Register expectation for the merge interrupt (not the source)
        `uvm_info(get_type_name(), $sformatf("Registering expected merge interrupt: %s (from source: %s)",
                 merge_info.name, source_info.name), UVM_HIGH)
        add_expected(merge_info);

        // Send stimulus for source interrupt
        `uvm_info(get_type_name(), $sformatf("Creating ASSERT stimulus for source interrupt: %s", source_info.name), UVM_HIGH)
        stim_item = int_stimulus_item::create_stimulus(source_info, STIMULUS_ASSERT);
        
        `uvm_info(get_type_name(), $sformatf("Sending ASSERT stimulus for source interrupt: %s", source_info.name), UVM_DEBUG)
        start_item(stim_item);
        finish_item(stim_item);

        `uvm_info(get_type_name(), "Waiting for propagation through merge logic", UVM_DEBUG)
        #10ns; // Wait for propagation through merge logic

        // Wait for merge interrupt to be detected
        `uvm_info(get_type_name(), $sformatf("Waiting for detection of merge interrupt: %s", merge_info.name), UVM_HIGH)
        wait_for_interrupt_detection(merge_info);

        // Clear the source interrupt
        `uvm_info(get_type_name(), $sformatf("Creating CLEAR stimulus for source interrupt: %s", source_info.name), UVM_HIGH)
        stim_item = int_stimulus_item::create_stimulus(source_info, STIMULUS_CLEAR);
        
        `uvm_info(get_type_name(), $sformatf("Sending CLEAR stimulus for source interrupt: %s", source_info.name), UVM_DEBUG)
        start_item(stim_item);
        finish_item(stim_item);

        `uvm_info(get_type_name(), "Waiting for clear to propagate", UVM_DEBUG)
        #10ns; // Wait for clear to propagate
        
        `uvm_info(get_type_name(), $sformatf("Completed testing of merge source: %s -> %s",
                 source_info.name, merge_info.name), UVM_MEDIUM)
    endtask

    // Test multiple merge sources simultaneously
    virtual task test_multiple_merge_sources(interrupt_info_s merge_info, interrupt_info_s source_interrupts[]);
        int_stimulus_item stim_item;
        int valid_sources = 0;

        `uvm_info(get_type_name(), $sformatf("Testing multiple sources simultaneously for merge interrupt: %s",
                 merge_info.name), UVM_LOW)

        // Count valid sources
        `uvm_info(get_type_name(), "Counting valid source interrupts with RTL paths", UVM_DEBUG)
        foreach (source_interrupts[i]) begin
            if (source_interrupts[i].rtl_path_src != "") begin
                valid_sources++;
            end
        end

        if (valid_sources < 2) begin
            `uvm_warning(get_type_name(), $sformatf("Not enough valid sources (%0d) for multi-source test of merge interrupt '%s'",
                      valid_sources, merge_info.name));
            return;
        end

        `uvm_info(get_type_name(), $sformatf("Found %0d valid sources for multi-source test of merge interrupt: %s",
                 valid_sources, merge_info.name), UVM_MEDIUM)

        // Register expectation for the merge interrupt
        `uvm_info(get_type_name(), $sformatf("Registering expected merge interrupt: %s for multi-source test",
                 merge_info.name), UVM_HIGH)
        add_expected(merge_info);

        // Assert all valid source interrupts simultaneously
        `uvm_info(get_type_name(), $sformatf("Asserting %0d source interrupts simultaneously", valid_sources), UVM_MEDIUM)
        foreach (source_interrupts[i]) begin
            if (source_interrupts[i].rtl_path_src != "") begin
                `uvm_info(get_type_name(), $sformatf("Creating ASSERT stimulus for source interrupt: %s",
                         source_interrupts[i].name), UVM_HIGH)
                stim_item = int_stimulus_item::create_stimulus(source_interrupts[i], STIMULUS_ASSERT);
                
                `uvm_info(get_type_name(), $sformatf("Sending ASSERT stimulus for source interrupt: %s",
                         source_interrupts[i].name), UVM_DEBUG)
                start_item(stim_item);
                finish_item(stim_item);
            end
        end

        `uvm_info(get_type_name(), "Waiting for propagation through merge logic", UVM_DEBUG)
        #10ns; // Wait for propagation through merge logic

        // Wait for merge interrupt to be detected
        `uvm_info(get_type_name(), $sformatf("Waiting for detection of merge interrupt: %s from multiple sources",
                 merge_info.name), UVM_HIGH)
        wait_for_interrupt_detection(merge_info);

        // Clear all source interrupts
        `uvm_info(get_type_name(), "Clearing all source interrupts", UVM_MEDIUM)
        foreach (source_interrupts[i]) begin
            if (source_interrupts[i].rtl_path_src != "") begin
                `uvm_info(get_type_name(), $sformatf("Creating CLEAR stimulus for source interrupt: %s",
                         source_interrupts[i].name), UVM_HIGH)
                stim_item = int_stimulus_item::create_stimulus(source_interrupts[i], STIMULUS_CLEAR);
                
                `uvm_info(get_type_name(), $sformatf("Sending CLEAR stimulus for source interrupt: %s",
                         source_interrupts[i].name), UVM_DEBUG)
                start_item(stim_item);
                finish_item(stim_item);
            end
        end

        `uvm_info(get_type_name(), "Waiting for clear to propagate", UVM_DEBUG)
        #10ns; // Wait for clear to propagate
        
        `uvm_info(get_type_name(), $sformatf("Completed multi-source test for merge interrupt: %s",
                 merge_info.name), UVM_LOW)
    endtask

endclass

`endif // INT_LIGHTWEIGHT_SEQUENCE_SV
