`ifndef TC_COMPREHENSIVE_MERGE_TEST_SV
`define TC_COMPREHENSIVE_MERGE_TEST_SV

class tc_comprehensive_merge_test extends int_base_test;
    `uvm_component_utils(tc_comprehensive_merge_test)
    
    function new(string name = "tc_comprehensive_merge_test", uvm_component parent = null);
        super.new(name, parent);
    endfunction
    
    virtual task main_phase(uvm_phase phase);
        comprehensive_merge_sequence seq;
        
        phase.raise_objection(this);
        
        `uvm_info("TC_COMP_MERGE", "Starting comprehensive merge test with all implemented merge logic", UVM_MEDIUM)
        
        seq = comprehensive_merge_sequence::type_id::create("seq");
        seq.start(env.agent.sequencer);
        
        `uvm_info("TC_COMP_MERGE", "Completed comprehensive merge test", UVM_MEDIUM)
        
        phase.drop_objection(this);
    endtask
    
endclass

// Comprehensive sequence to test all merge interrupts
class comprehensive_merge_sequence extends int_base_sequence;
    `uvm_object_utils(comprehensive_merge_sequence)
    
    // Test statistics
    int total_merge_interrupts = 0;
    int successful_tests = 0;
    int failed_tests = 0;
    
    function new(string name = "comprehensive_merge_sequence");
        super.new(name);
    endfunction
    
    virtual task body();
        string all_merge_interrupts[$];
        
        `uvm_info("COMP_MERGE_SEQ", "Starting comprehensive merge interrupt testing", UVM_MEDIUM)
        
        // Get all merge interrupts (both original and new)
        all_merge_interrupts = {
            // Original PLL merge interrupts
            "merge_pll_intr_lock",
            "merge_pll_intr_unlock", 
            "merge_pll_intr_frechangedone",
            "merge_pll_intr_frechange_tot_done",
            "merge_pll_intr_intdocfrac_err",
            // New merge interrupts from CSV analysis
            "iosub_normal_intr",
            "iosub_slv_err_intr",
            "iosub_ras_cri_intr",
            "iosub_ras_eri_intr",
            "iosub_ras_fhi_intr",
            "iosub_abnormal_0_intr",
            "merge_external_pll_intr"
        };
        
        total_merge_interrupts = all_merge_interrupts.size();
        
        // Test each merge interrupt comprehensively
        foreach (all_merge_interrupts[i]) begin
            test_merge_interrupt_comprehensive(all_merge_interrupts[i]);
        end
        
        // Test specific merge scenarios
        test_iosub_merge_scenarios();
        test_ras_merge_scenarios();
        test_pll_merge_scenarios();
        
        // Print final statistics
        print_test_summary();
        
    endtask
    
    virtual task test_merge_interrupt_comprehensive(string merge_name);
        interrupt_info_s merge_sources[$];
        int num_sources;
        bit test_passed = 1;
        
        `uvm_info("COMP_MERGE_SEQ", $sformatf("=== Testing merge interrupt: %s ===", merge_name), UVM_MEDIUM)
        
        // Verify it's recognized as a merge interrupt
        if (!int_routing_model::is_merge_interrupt(merge_name)) begin
            `uvm_error("COMP_MERGE_SEQ", $sformatf("%s is not recognized as a merge interrupt", merge_name))
            test_passed = 0;
        end
        
        // Get sources for this merge interrupt
        num_sources = int_routing_model::get_merge_sources(merge_name, merge_sources);
        
        if (num_sources == 0) begin
            `uvm_warning("COMP_MERGE_SEQ", $sformatf("No sources found for merge interrupt: %s", merge_name))
            test_passed = 0;
        end else begin
            `uvm_info("COMP_MERGE_SEQ", $sformatf("Found %0d sources for %s", num_sources, merge_name), UVM_MEDIUM)
        end
        
        // Verify each source
        foreach (merge_sources[j]) begin
            `uvm_info("COMP_MERGE_SEQ", $sformatf("  Source[%0d]: %s", j, merge_sources[j].name), UVM_MEDIUM)
            
            // Verify source has valid properties
            if (merge_sources[j].name == "") begin
                `uvm_error("COMP_MERGE_SEQ", $sformatf("Source %0d has empty name", j))
                test_passed = 0;
            end
            
            // Verify source is not itself a merge interrupt (avoid circular dependencies)
            if (int_routing_model::is_merge_interrupt(merge_sources[j].name)) begin
                `uvm_warning("COMP_MERGE_SEQ", $sformatf("Source %s is also a merge interrupt - potential circular dependency", merge_sources[j].name))
            end
        end
        
        // Test specific merge logic based on merge type
        case (merge_name)
            "iosub_normal_intr": test_passed &= verify_iosub_normal_sources(merge_sources);
            "iosub_slv_err_intr": test_passed &= verify_iosub_slv_err_sources(merge_sources);
            "iosub_ras_cri_intr": test_passed &= verify_ras_cri_sources(merge_sources);
            "iosub_ras_eri_intr": test_passed &= verify_ras_eri_sources(merge_sources);
            "iosub_ras_fhi_intr": test_passed &= verify_ras_fhi_sources(merge_sources);
            "iosub_abnormal_0_intr": test_passed &= verify_abnormal_sources(merge_sources);
            "merge_external_pll_intr": test_passed &= verify_external_pll_sources(merge_sources);
            default: begin
                // For PLL merge interrupts, just verify they have sources
                test_passed &= (num_sources > 0);
            end
        endcase
        
        if (test_passed) begin
            successful_tests++;
            `uvm_info("COMP_MERGE_SEQ", $sformatf("✅ %s test PASSED", merge_name), UVM_MEDIUM)
        end else begin
            failed_tests++;
            `uvm_error("COMP_MERGE_SEQ", $sformatf("❌ %s test FAILED", merge_name))
        end
        
    endtask
    
    virtual function bit verify_iosub_normal_sources(interrupt_info_s sources[$]);
        string expected_sources[$] = {
            "iosub_pmbus0_intr", "iosub_pmbus1_intr", "iosub_mem_ist_intr", "iosub_dma_comreg_intr"
        };
        
        // Add all DMA channel interrupts
        for (int i = 0; i < 16; i++) begin
            expected_sources.push_back($sformatf("iosub_dma_ch%0d_intr", i));
        end
        
        return verify_sources_contain_expected(sources, expected_sources, "iosub_normal_intr");
    endfunction
    
    virtual function bit verify_iosub_slv_err_sources(interrupt_info_s sources[$]);
        string expected_sources[$] = {"usb0_apb1ton_intr", "usb1_apb1ton_intr", "usb_top_apb1ton_intr"};
        return verify_sources_contain_expected(sources, expected_sources, "iosub_slv_err_intr");
    endfunction
    
    virtual function bit verify_ras_cri_sources(interrupt_info_s sources[$]);
        string expected_sources[$] = {"smmu_cri_intr", "scp_ras_cri_intr", "mcp_ras_cri_intr"};
        return verify_sources_contain_expected(sources, expected_sources, "iosub_ras_cri_intr");
    endfunction
    
    virtual function bit verify_ras_eri_sources(interrupt_info_s sources[$]);
        string expected_sources[$] = {"smmu_eri_intr", "scp_ras_eri_intr", "mcp_ras_eri_intr"};
        return verify_sources_contain_expected(sources, expected_sources, "iosub_ras_eri_intr");
    endfunction
    
    virtual function bit verify_ras_fhi_sources(interrupt_info_s sources[$]);
        string expected_sources[$] = {
            "smmu_fhi_intr", "scp_ras_fhi_intr", "mcp_ras_fhi_intr",
            "iodap_chk_err_etf0", "iodap_chk_err_etf1"
        };
        return verify_sources_contain_expected(sources, expected_sources, "iosub_ras_fhi_intr");
    endfunction
    
    virtual function bit verify_abnormal_sources(interrupt_info_s sources[$]);
        string expected_sources[$] = {"iodap_etr_buf_intr", "iodap_catu_addrerr_intr"};
        return verify_sources_contain_expected(sources, expected_sources, "iosub_abnormal_0_intr");
    endfunction
    
    virtual function bit verify_external_pll_sources(interrupt_info_s sources[$]);
        string expected_sources[$] = {
            "accel_pll_lock_intr", "accel_pll_unlock_intr",
            "psub_pll_lock_intr", "psub_pll_unlock_intr",
            "pcie1_pll_lock_intr", "pcie1_pll_unlock_intr",
            "d2d_pll_lock_intr", "d2d_pll_unlock_intr",
            "ddr0_pll_lock_intr", "ddr1_pll_lock_intr", "ddr2_pll_lock_intr"
        };
        return verify_sources_contain_expected(sources, expected_sources, "merge_external_pll_intr");
    endfunction
    
    virtual function bit verify_sources_contain_expected(interrupt_info_s sources[$], string expected[$], string merge_name);
        bit all_found = 1;
        int found_count = 0;
        
        foreach (expected[i]) begin
            bit found = 0;
            foreach (sources[j]) begin
                if (sources[j].name == expected[i]) begin
                    found = 1;
                    found_count++;
                    break;
                end
            end
            if (!found) begin
                `uvm_warning("COMP_MERGE_SEQ", $sformatf("Expected source %s not found in %s", expected[i], merge_name))
                all_found = 0;
            end
        end
        
        `uvm_info("COMP_MERGE_SEQ", $sformatf("%s: Found %0d/%0d expected sources", merge_name, found_count, expected.size()), UVM_MEDIUM)
        return all_found;
    endfunction
    
    virtual task test_iosub_merge_scenarios();
        `uvm_info("COMP_MERGE_SEQ", "=== Testing IOSUB merge scenarios ===", UVM_MEDIUM)
        // Additional IOSUB-specific tests can be added here
    endtask
    
    virtual task test_ras_merge_scenarios();
        `uvm_info("COMP_MERGE_SEQ", "=== Testing RAS merge scenarios ===", UVM_MEDIUM)
        // Additional RAS-specific tests can be added here
    endtask
    
    virtual task test_pll_merge_scenarios();
        `uvm_info("COMP_MERGE_SEQ", "=== Testing PLL merge scenarios ===", UVM_MEDIUM)
        // Additional PLL-specific tests can be added here
    endtask
    
    virtual function void print_test_summary();
        `uvm_info("COMP_MERGE_SEQ", "=== COMPREHENSIVE MERGE TEST SUMMARY ===", UVM_MEDIUM)
        `uvm_info("COMP_MERGE_SEQ", $sformatf("Total merge interrupts tested: %0d", total_merge_interrupts), UVM_MEDIUM)
        `uvm_info("COMP_MERGE_SEQ", $sformatf("Successful tests: %0d", successful_tests), UVM_MEDIUM)
        `uvm_info("COMP_MERGE_SEQ", $sformatf("Failed tests: %0d", failed_tests), UVM_MEDIUM)
        `uvm_info("COMP_MERGE_SEQ", $sformatf("Success rate: %0.1f%%", 100.0 * successful_tests / total_merge_interrupts), UVM_MEDIUM)
        
        if (failed_tests == 0) begin
            `uvm_info("COMP_MERGE_SEQ", "🎉 ALL MERGE TESTS PASSED!", UVM_MEDIUM)
        end else begin
            `uvm_error("COMP_MERGE_SEQ", $sformatf("❌ %0d merge tests failed", failed_tests))
        end
    endfunction
    
endclass

`endif // TC_COMPREHENSIVE_MERGE_TEST_SV
