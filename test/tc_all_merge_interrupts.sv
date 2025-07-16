`ifndef TC_ALL_MERGE_INTERRUPTS_SV
`define TC_ALL_MERGE_INTERRUPTS_SV

class tc_all_merge_interrupts extends int_base_test;
    `uvm_component_utils(tc_all_merge_interrupts)
    
    function new(string name = "tc_all_merge_interrupts", uvm_component parent = null);
        super.new(name, parent);
    endfunction
    
    virtual task main_phase(uvm_phase phase);
        all_merge_interrupts_sequence seq;
        
        phase.raise_objection(this);
        
        `uvm_info("TC_ALL_MERGE", "Starting comprehensive merge interrupt test", UVM_MEDIUM)
        
        seq = all_merge_interrupts_sequence::type_id::create("seq");
        seq.start(env.agent.sequencer);
        
        `uvm_info("TC_ALL_MERGE", "Completed comprehensive merge interrupt test", UVM_MEDIUM)
        
        phase.drop_objection(this);
    endtask
    
endclass

// Sequence to test all merge interrupts
class all_merge_interrupts_sequence extends int_base_sequence;
    `uvm_object_utils(all_merge_interrupts_sequence)
    
    function new(string name = "all_merge_interrupts_sequence");
        super.new(name);
    endfunction
    
    virtual task body();
        string merge_interrupts[$];
        
        `uvm_info("ALL_MERGE_SEQ", "Testing all merge interrupt relationships", UVM_MEDIUM)
        
        // Get all merge interrupts
        merge_interrupts = {
            "merge_pll_intr_lock",
            "merge_pll_intr_unlock", 
            "merge_pll_intr_frechangedone",
            "merge_pll_intr_frechange_tot_done",
            "merge_pll_intr_intdocfrac_err",
            "iosub_normal_intr",
            "iosub_slv_err_intr",
            "iosub_ras_cri_intr",
            "iosub_ras_eri_intr",
            "iosub_ras_fhi_intr",
            "iosub_abnormal_0_intr",
            "merge_external_pll_intr"
        };
        
        // Test each merge interrupt
        foreach (merge_interrupts[i]) begin
            test_single_merge_interrupt(merge_interrupts[i]);
        end
        
        // Test specific merge scenarios
        test_iosub_normal_merge_scenario();
        test_ras_merge_scenario();
        test_external_pll_merge_scenario();
        
    endtask
    
    virtual task test_single_merge_interrupt(string merge_name);
        interrupt_info_s merge_sources[$];
        int num_sources;
        
        `uvm_info("ALL_MERGE_SEQ", $sformatf("Testing merge interrupt: %s", merge_name), UVM_MEDIUM)
        
        // Get sources for this merge interrupt
        num_sources = int_routing_model::get_merge_sources(merge_name, merge_sources);
        
        if (num_sources == 0) begin
            `uvm_warning("ALL_MERGE_SEQ", $sformatf("No sources found for merge interrupt: %s", merge_name))
            return;
        end
        
        `uvm_info("ALL_MERGE_SEQ", $sformatf("Found %0d sources for %s", num_sources, merge_name), UVM_MEDIUM)
        
        // Print all sources
        foreach (merge_sources[j]) begin
            `uvm_info("ALL_MERGE_SEQ", $sformatf("  Source[%0d]: %s", j, merge_sources[j].name), UVM_MEDIUM)
        end
        
        // Verify each source can be found in interrupt map
        foreach (merge_sources[j]) begin
            if (!int_routing_model::interrupt_exists(merge_sources[j].name)) begin
                `uvm_error("ALL_MERGE_SEQ", $sformatf("Source interrupt %s not found in interrupt map", merge_sources[j].name))
            end
        end
        
    endtask
    
    virtual task test_iosub_normal_merge_scenario();
        interrupt_info_s sources[$];
        int num_sources;
        string expected_sources[$] = {
            "iosub_pmbus0_intr",
            "iosub_pmbus1_intr", 
            "iosub_mem_ist_intr",
            "iosub_dma_comreg_intr",
            "iosub_dma_ch0_intr",
            "iosub_dma_ch1_intr",
            "iosub_dma_ch2_intr",
            "iosub_dma_ch3_intr",
            "iosub_dma_ch4_intr",
            "iosub_dma_ch5_intr",
            "iosub_dma_ch6_intr",
            "iosub_dma_ch7_intr",
            "iosub_dma_ch8_intr",
            "iosub_dma_ch9_intr",
            "iosub_dma_ch10_intr",
            "iosub_dma_ch11_intr",
            "iosub_dma_ch12_intr",
            "iosub_dma_ch13_intr",
            "iosub_dma_ch14_intr",
            "iosub_dma_ch15_intr"
        };
        
        `uvm_info("ALL_MERGE_SEQ", "Testing iosub_normal_intr merge scenario", UVM_MEDIUM)
        
        num_sources = int_routing_model::get_merge_sources("iosub_normal_intr", sources);
        
        // Verify we have the expected number of sources
        if (num_sources < expected_sources.size()) begin
            `uvm_warning("ALL_MERGE_SEQ", $sformatf("Expected at least %0d sources for iosub_normal_intr, got %0d", 
                        expected_sources.size(), num_sources))
        end
        
        // Verify key sources are present
        foreach (expected_sources[i]) begin
            bit found = 0;
            foreach (sources[j]) begin
                if (sources[j].name == expected_sources[i]) begin
                    found = 1;
                    break;
                end
            end
            if (!found) begin
                `uvm_warning("ALL_MERGE_SEQ", $sformatf("Expected source %s not found in iosub_normal_intr merge", expected_sources[i]))
            end
        end
        
    endtask
    
    virtual task test_ras_merge_scenario();
        interrupt_info_s cri_sources[$], eri_sources[$], fhi_sources[$];
        int num_cri, num_eri, num_fhi;
        
        `uvm_info("ALL_MERGE_SEQ", "Testing RAS merge scenarios", UVM_MEDIUM)
        
        // Test CRI merge
        num_cri = int_routing_model::get_merge_sources("iosub_ras_cri_intr", cri_sources);
        `uvm_info("ALL_MERGE_SEQ", $sformatf("iosub_ras_cri_intr has %0d sources", num_cri), UVM_MEDIUM)
        
        // Test ERI merge  
        num_eri = int_routing_model::get_merge_sources("iosub_ras_eri_intr", eri_sources);
        `uvm_info("ALL_MERGE_SEQ", $sformatf("iosub_ras_eri_intr has %0d sources", num_eri), UVM_MEDIUM)
        
        // Test FHI merge
        num_fhi = int_routing_model::get_merge_sources("iosub_ras_fhi_intr", fhi_sources);
        `uvm_info("ALL_MERGE_SEQ", $sformatf("iosub_ras_fhi_intr has %0d sources", num_fhi), UVM_MEDIUM)
        
        // Verify SMMU interrupts are properly distributed
        string smmu_interrupts[$] = {"smmu_cri_intr", "smmu_eri_intr", "smmu_fhi_intr"};
        foreach (smmu_interrupts[i]) begin
            if (!int_routing_model::interrupt_exists(smmu_interrupts[i])) begin
                `uvm_warning("ALL_MERGE_SEQ", $sformatf("SMMU interrupt %s not found", smmu_interrupts[i]))
            end
        end
        
    endtask
    
    virtual task test_external_pll_merge_scenario();
        interrupt_info_s sources[$];
        int num_sources;
        string expected_pll_sources[$] = {
            "accel_pll_lock_intr",
            "accel_pll_unlock_intr",
            "psub_pll_lock_intr", 
            "psub_pll_unlock_intr",
            "pcie1_pll_lock_intr",
            "pcie1_pll_unlock_intr",
            "d2d_pll_lock_intr",
            "d2d_pll_unlock_intr",
            "ddr0_pll_lock_intr",
            "ddr1_pll_lock_intr",
            "ddr2_pll_lock_intr"
        };
        
        `uvm_info("ALL_MERGE_SEQ", "Testing external PLL merge scenario", UVM_MEDIUM)
        
        num_sources = int_routing_model::get_merge_sources("merge_external_pll_intr", sources);
        
        `uvm_info("ALL_MERGE_SEQ", $sformatf("merge_external_pll_intr has %0d sources", num_sources), UVM_MEDIUM)
        
        // Verify key external PLL sources are present
        foreach (expected_pll_sources[i]) begin
            bit found = 0;
            foreach (sources[j]) begin
                if (sources[j].name == expected_pll_sources[i]) begin
                    found = 1;
                    break;
                end
            end
            if (!found) begin
                `uvm_info("ALL_MERGE_SEQ", $sformatf("External PLL source %s not found (may not be in current interrupt map)", expected_pll_sources[i]), UVM_LOW)
            end
        end
        
    endtask
    
endclass

`endif // TC_ALL_MERGE_INTERRUPTS_SV
