// Simple test to verify merge interrupt logic
module test_merge_logic;
    
    // Import UVM and test packages
    import uvm_pkg::*;
    `include "uvm_macros.svh"
    `include "seq/int_def.sv"
    `include "seq/int_routing_model.sv"
    
    initial begin
        interrupt_info_s sources[$];
        int num_sources;
        
        $display("=== Testing Merge Interrupt Logic ===");
        
        // Build the interrupt model
        int_routing_model::build();
        $display("Built interrupt model with %0d interrupts", int_routing_model::interrupt_map.size());
        
        // Test each merge interrupt
        test_merge_interrupt("merge_pll_intr_lock");
        test_merge_interrupt("merge_pll_intr_unlock");
        test_merge_interrupt("merge_pll_intr_frechangedone");
        test_merge_interrupt("merge_pll_intr_frechange_tot_done");
        test_merge_interrupt("merge_pll_intr_intdocfrac_err");
        
        $display("=== Merge Interrupt Logic Test Complete ===");
        $finish;
    end
    
    task test_merge_interrupt(string merge_name);
        interrupt_info_s sources[];
        interrupt_info_s merge_info;
        int num_sources;
        
        $display("\n--- Testing %s ---", merge_name);
        
        // Check if it's recognized as a merge interrupt
        if (!int_routing_model::is_merge_interrupt(merge_name)) begin
            $display("ERROR: %s not recognized as merge interrupt", merge_name);
            return;
        end
        $display("✓ %s recognized as merge interrupt", merge_name);
        
        // Get merge interrupt info
        merge_info = int_routing_model::get_merge_interrupt_info(merge_name);
        if (merge_info.name == "") begin
            $display("ERROR: Could not find merge interrupt info for %s", merge_name);
            return;
        end
        $display("✓ Found merge interrupt info: %s (index: %0d, group: %s)", 
                merge_info.name, merge_info.index, merge_info.group.name());
        $display("  Routes to: AP=%0d, SCP=%0d, MCP=%0d, IMU=%0d, IO=%0d, OTHER_DIE=%0d",
                merge_info.to_ap, merge_info.to_scp, merge_info.to_mcp, 
                merge_info.to_imu, merge_info.to_io, merge_info.to_other_die);
        
        // Get source interrupts
        num_sources = int_routing_model::get_merge_sources(merge_name, sources);
        $display("✓ Found %0d source interrupts for %s:", num_sources, merge_name);
        
        foreach (sources[i]) begin
            $display("  [%0d] %s (group: %s, index: %0d)", 
                    i, sources[i].name, sources[i].group.name(), sources[i].index);
        end
        
        if (num_sources == 0) begin
            $display("WARNING: No source interrupts found for %s", merge_name);
        end
    endtask
    
endmodule
