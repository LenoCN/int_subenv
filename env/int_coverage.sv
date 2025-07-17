`ifndef INT_COVERAGE_SV
`define INT_COVERAGE_SV

// Functional coverage collector for interrupt verification
class int_coverage extends uvm_subscriber #(int_transaction);
    `uvm_component_utils(int_coverage)

    // Coverage groups for different aspects of interrupt verification
    
    // Basic interrupt coverage
    covergroup interrupt_basic_cg;
        // Cover all interrupt groups
        interrupt_group: coverpoint m_transaction.interrupt_info.group {
            bins iosub_group = {IOSUB};
            bins usb_group = {USB};
            bins scp_group = {SCP};
            bins mcp_group = {MCP};
            bins smmu_group = {SMMU};
            bins iodap_group = {IODAP};
            bins accel_group = {ACCEL};
            bins csub_group = {CSUB};
            bins psub_group = {PSUB};
            bins pcie1_group = {PCIE1};
            bins d2d_group = {D2D};
            bins ddr0_group = {DDR0};
            bins ddr1_group = {DDR1};
            bins ddr2_group = {DDR2};
            bins io_die_group = {IO_DIE};
        }
        
        // Cover all trigger types
        trigger_type: coverpoint m_transaction.interrupt_info.trigger {
            bins level_trigger = {LEVEL};
            bins edge_trigger = {EDGE};
            bins unknown_trigger = {UNKNOWN_TRIGGER};
        }
        
        // Cover all polarity types
        polarity_type: coverpoint m_transaction.interrupt_info.polarity {
            bins active_high = {ACTIVE_HIGH};
            bins active_low = {ACTIVE_LOW};
            bins rising_falling = {RISING_FALLING};
            bins unknown_polarity = {UNKNOWN_POLARITY};
        }
        
        // Cover all destination types
        destination: coverpoint m_transaction.destination_name {
            bins ap_dest = {"AP"};
            bins scp_dest = {"SCP"};
            bins mcp_dest = {"MCP"};
            bins imu_dest = {"IMU"};
            bins io_dest = {"IO"};
            bins other_die_dest = {"OTHER_DIE"};
        }
        
        // Cross coverage: group vs destination
        group_dest_cross: cross interrupt_group, destination;
        
        // Cross coverage: trigger vs polarity
        trigger_polarity_cross: cross trigger_type, polarity_type;
    endgroup
    
    // Routing coverage - covers interrupt routing patterns
    covergroup interrupt_routing_cg;
        // Single destination routing
        single_dest: coverpoint get_destination_count() {
            bins single = {1};
            bins multiple = {[2:6]};
        }
        
        // Specific routing patterns
        ap_routing: coverpoint m_transaction.interrupt_info.to_ap {
            bins routed_to_ap = {1};
            bins not_routed_to_ap = {0};
        }
        
        scp_routing: coverpoint m_transaction.interrupt_info.to_scp {
            bins routed_to_scp = {1};
            bins not_routed_to_scp = {0};
        }
        
        mcp_routing: coverpoint m_transaction.interrupt_info.to_mcp {
            bins routed_to_mcp = {1};
            bins not_routed_to_mcp = {0};
        }
        
        // Cross coverage: routing patterns
        routing_pattern_cross: cross ap_routing, scp_routing, mcp_routing;
    endgroup
    
    // Timing coverage - covers timing-related aspects
    covergroup interrupt_timing_cg;
        // Cover different interrupt indices (to ensure we hit different timing scenarios)
        interrupt_index: coverpoint m_transaction.interrupt_info.index {
            bins low_index = {[0:99]};
            bins mid_index = {[100:299]};
            bins high_index = {[300:499]};
        }
        
        // Cover different groups with timing implications
        timing_group: coverpoint m_transaction.interrupt_info.group {
            bins fast_groups = {IOSUB, USB, SCP};
            bins medium_groups = {MCP, SMMU, IODAP};
            bins slow_groups = {ACCEL, CSUB, PSUB};
            bins special_groups = {PCIE1, D2D, DDR0, DDR1, DDR2, IO_DIE};
        }
    endgroup

    // Transaction being analyzed
    int_transaction m_transaction;
    
    // Coverage statistics
    int total_interrupts_seen = 0;
    int unique_interrupts_seen = 0;
    string seen_interrupts[string]; // Associative array to track unique interrupts

    function new(string name = "int_coverage", uvm_component parent = null);
        super.new(name, parent);
        
        // Create coverage groups
        interrupt_basic_cg = new();
        interrupt_routing_cg = new();
        interrupt_timing_cg = new();
    endfunction

    // Main write function called for each transaction
    virtual function void write(int_transaction t);
        m_transaction = t;
        total_interrupts_seen++;
        
        // Track unique interrupts
        string interrupt_key = $sformatf("%s@%s", t.interrupt_info.name, t.destination_name);
        if (!seen_interrupts.exists(interrupt_key)) begin
            seen_interrupts[interrupt_key] = interrupt_key;
            unique_interrupts_seen++;
        end
        
        // Sample all coverage groups
        interrupt_basic_cg.sample();
        interrupt_routing_cg.sample();
        interrupt_timing_cg.sample();
        
        `uvm_info(get_type_name(), $sformatf("Sampled coverage for interrupt: %s -> %s", 
                  t.interrupt_info.name, t.destination_name), UVM_HIGH)
    endfunction
    
    // Helper function to get destination count for routing coverage
    function int get_destination_count();
        int count = 0;
        if (m_transaction.interrupt_info.to_ap) count++;
        if (m_transaction.interrupt_info.to_scp) count++;
        if (m_transaction.interrupt_info.to_mcp) count++;
        if (m_transaction.interrupt_info.to_imu) count++;
        if (m_transaction.interrupt_info.to_io) count++;
        if (m_transaction.interrupt_info.to_other_die) count++;
        return count;
    endfunction
    
    // Report coverage statistics
    virtual function void report_phase(uvm_phase phase);
        real basic_coverage, routing_coverage, timing_coverage;
        
        super.report_phase(phase);
        
        // Get coverage percentages
        basic_coverage = interrupt_basic_cg.get_inst_coverage();
        routing_coverage = interrupt_routing_cg.get_inst_coverage();
        timing_coverage = interrupt_timing_cg.get_inst_coverage();
        
        `uvm_info(get_type_name(), "=== Interrupt Functional Coverage Report ===", UVM_LOW)
        `uvm_info(get_type_name(), $sformatf("Total interrupts processed: %0d", total_interrupts_seen), UVM_LOW)
        `uvm_info(get_type_name(), $sformatf("Unique interrupt-destination pairs: %0d", unique_interrupts_seen), UVM_LOW)
        `uvm_info(get_type_name(), $sformatf("Basic interrupt coverage: %0.2f%%", basic_coverage), UVM_LOW)
        `uvm_info(get_type_name(), $sformatf("Routing coverage: %0.2f%%", routing_coverage), UVM_LOW)
        `uvm_info(get_type_name(), $sformatf("Timing coverage: %0.2f%%", timing_coverage), UVM_LOW)
        
        // Calculate overall coverage
        real overall_coverage = (basic_coverage + routing_coverage + timing_coverage) / 3.0;
        `uvm_info(get_type_name(), $sformatf("Overall functional coverage: %0.2f%%", overall_coverage), UVM_LOW)
        
        // Coverage goals check
        if (overall_coverage >= 95.0) begin
            `uvm_info(get_type_name(), "✅ Coverage goal (95%) ACHIEVED!", UVM_LOW)
        end else begin
            `uvm_warning(get_type_name(), $sformatf("⚠️  Coverage goal (95%) NOT met. Current: %0.2f%%", overall_coverage))
        end
        
        `uvm_info(get_type_name(), "==========================================", UVM_LOW)
    endfunction

endclass

`endif // INT_COVERAGE_SV
