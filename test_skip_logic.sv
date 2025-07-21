// Simple test to verify the skip logic works correctly
`include "seq/int_def.sv"

module test_skip_logic;
    
    // Test function to simulate the skip logic
    function bit should_skip_interrupt_check(interrupt_info_s info);
        bit has_other_destinations = 0;

        // Check if interrupt has destinations other than to_other_die and to_io
        if (info.to_ap || info.to_scp || info.to_mcp || info.to_imu) begin
            has_other_destinations = 1;
        end

        // Skip ONLY if interrupt routes to other_die or io AND has no other destinations
        // Do NOT skip interrupts with no destinations at all (they are merge sources)
        if (!has_other_destinations && (info.to_other_die || info.to_io)) begin
            $display("Skipping interrupt '%s' - only routes to other_die(%0d) or io(%0d)",
                     info.name, info.to_other_die, info.to_io);
            return 1;
        end

        return 0;
    endfunction
    
    initial begin
        interrupt_info_s test_int;
        
        $display("=== Testing Skip Logic ===");
        
        // Test 1: Interrupt only routes to other_die - should be skipped
        test_int = '{
            name: "test_other_die_only",
            to_ap: 0, to_scp: 0, to_mcp: 0, to_imu: 0, to_io: 0, to_other_die: 1,
            default: 0
        };
        $display("Test 1 (other_die only): Skip = %0d", should_skip_interrupt_check(test_int));
        
        // Test 2: Interrupt only routes to io - should be skipped
        test_int = '{
            name: "test_io_only",
            to_ap: 0, to_scp: 0, to_mcp: 0, to_imu: 0, to_io: 1, to_other_die: 0,
            default: 0
        };
        $display("Test 2 (io only): Skip = %0d", should_skip_interrupt_check(test_int));
        
        // Test 3: Interrupt routes to AP and other_die - should NOT be skipped
        test_int = '{
            name: "test_ap_and_other_die",
            to_ap: 1, to_scp: 0, to_mcp: 0, to_imu: 0, to_io: 0, to_other_die: 1,
            default: 0
        };
        $display("Test 3 (AP + other_die): Skip = %0d", should_skip_interrupt_check(test_int));
        
        // Test 4: Interrupt routes to SCP only - should NOT be skipped
        test_int = '{
            name: "test_scp_only",
            to_ap: 0, to_scp: 1, to_mcp: 0, to_imu: 0, to_io: 0, to_other_die: 0,
            default: 0
        };
        $display("Test 4 (SCP only): Skip = %0d", should_skip_interrupt_check(test_int));
        
        // Test 5: Interrupt has no destinations - should NOT be skipped (merge source)
        test_int = '{
            name: "test_no_destinations",
            to_ap: 0, to_scp: 0, to_mcp: 0, to_imu: 0, to_io: 0, to_other_die: 0,
            default: 0
        };
        $display("Test 5 (no destinations - merge source): Skip = %0d", should_skip_interrupt_check(test_int));
        
        $display("=== Test Complete ===");
        $finish;
    end
    
endmodule
