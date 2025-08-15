`ifndef TC_CROSS_DIE_INTERRUPT_ROUTING
`define TC_CROSS_DIE_INTERRUPT_ROUTING

class tc_cross_die_interrupt_routing extends int_tc_base;
    `uvm_component_utils(tc_cross_die_interrupt_routing)

    typedef struct {
        string name;
        bit [15:0] csr_addr;
        string source_path;
        string dest_path_prefix;
    } cross_die_intr_cfg_s;

    cross_die_intr_cfg_s intr_configs[$];

    function new(string name = "tc_cross_die_interrupt_routing", uvm_component parent = null);
        super.new(name, parent);
    endfunction

    virtual function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        
        // Initialize interrupt configurations based on requirements
        intr_configs.push_back('{name: "n2_wakeup_intr", csr_addr: 16'h3B60, 
                                 source_path: "u_iosub_int_sub.u_iosub_int_sync_package.csub_normal2_intr",
                                 dest_path_prefix: "u_glue_logic_n2_wakeup_intr_masked"});
        
        intr_configs.push_back('{name: "n2_ws1_intr", csr_addr: 16'h3B64,
                                 source_path: "u_iosub_int_sub.u_iosub_int_sync_package.n2_ws1_intr",
                                 dest_path_prefix: "u_glue_logic_n2_ws1_intr_masked"});
        
        intr_configs.push_back('{name: "iosub_pmbus0_intr", csr_addr: 16'h3B68,
                                 source_path: "u_iosub_int_sub.u_iosub_int_sync_package.iosub_pmbus0_intr",
                                 dest_path_prefix: "u_glue_logic_iosub_pmbus0_intr_masked"});
        
        intr_configs.push_back('{name: "iosub_pvt_intr", csr_addr: 16'h3B6C,
                                 source_path: "u_iosub_int_sub.u_iosub_int_sync_package.iosub_pvt_intr",
                                 dest_path_prefix: "u_glue_logic_iosub_pvt_intr_masked"});
        
        intr_configs.push_back('{name: "psub_imu_acc_intr", csr_addr: 16'h3B70,
                                 source_path: "u_iosub_int_sub.u_iosub_int_sync_package.psub_merge_pcie1_normal8_intr",
                                 dest_path_prefix: "u_glue_logic_psub_imu_acc_intr_masked"});
        
        // MHU interrupts
        intr_configs.push_back('{name: "scp2scp_mhu0_rec_intr", csr_addr: 16'h3B00,
                                 source_path: "u_d2d_scp2scp_mhu0.MHU_IRQCOMB",
                                 dest_path_prefix: "u_glue_logic_scp2scp_mhu0_rec_intr_masked"});
        
        intr_configs.push_back('{name: "scp2scp_mhu1_rec_intr", csr_addr: 16'h3B04,
                                 source_path: "u_d2d_scp2scp_mhu1.MHU_IRQCOMB",
                                 dest_path_prefix: "u_glue_logic_scp2scp_mhu1_rec_intr_masked"});
        
        intr_configs.push_back('{name: "scp2scp_mhu2_rec_intr", csr_addr: 16'h3B08,
                                 source_path: "u_d2d_scp2scp_mhu2.MHU_IRQCOMB",
                                 dest_path_prefix: "u_glue_logic_scp2scp_mhu2_rec_intr_masked"});
        
        intr_configs.push_back('{name: "scp2mcp_mhu0_rec_intr", csr_addr: 16'h3B0C,
                                 source_path: "u_d2d_scp2mcp_mhu0.MHU_IRQCOMB",
                                 dest_path_prefix: "u_glue_logic_scp2mcp_mhu0_rec_intr_masked"});
        
        intr_configs.push_back('{name: "scp2mcp_mhu1_rec_intr", csr_addr: 16'h3B10,
                                 source_path: "u_d2d_scp2mcp_mhu1.MHU_IRQCOMB",
                                 dest_path_prefix: "u_glue_logic_scp2mcp_mhu1_rec_intr_masked"});
        
        intr_configs.push_back('{name: "scp2mcp_mhu2_rec_intr", csr_addr: 16'h3B14,
                                 source_path: "u_d2d_scp2mcp_mhu2.MHU_IRQCOMB",
                                 dest_path_prefix: "u_glue_logic_scp2mcp_mhu2_rec_intr_masked"});
        
        intr_configs.push_back('{name: "mcp2scp_mhu0_rec_intr", csr_addr: 16'h3B18,
                                 source_path: "u_d2d_mcp2scp_mhu0.MHU_IRQCOMB",
                                 dest_path_prefix: "u_glue_logic_mcp2scp_mhu0_rec_intr_masked"});
        
        intr_configs.push_back('{name: "mcp2scp_mhu1_rec_intr", csr_addr: 16'h3B1C,
                                 source_path: "u_d2d_mcp2scp_mhu1.MHU_IRQCOMB",
                                 dest_path_prefix: "u_glue_logic_mcp2scp_mhu1_rec_intr_masked"});
        
        intr_configs.push_back('{name: "mcp2scp_mhu2_rec_intr", csr_addr: 16'h3B20,
                                 source_path: "u_d2d_mcp2scp_mhu2.MHU_IRQCOMB",
                                 dest_path_prefix: "u_glue_logic_mcp2scp_mhu2_rec_intr_masked"});
        
        intr_configs.push_back('{name: "mcp2mcp_mhu0_rec_intr", csr_addr: 16'h3B24,
                                 source_path: "u_d2d_mcp2mcp_mhu0.MHU_IRQCOMB",
                                 dest_path_prefix: "u_glue_logic_mcp2mcp_mhu0_rec_intr_masked"});
        
        intr_configs.push_back('{name: "mcp2mcp_mhu1_rec_intr", csr_addr: 16'h3B28,
                                 source_path: "u_d2d_mcp2mcp_mhu1.MHU_IRQCOMB",
                                 dest_path_prefix: "u_glue_logic_mcp2mcp_mhu1_rec_intr_masked"});
        
        intr_configs.push_back('{name: "mcp2mcp_mhu2_rec_intr", csr_addr: 16'h3B2C,
                                 source_path: "u_d2d_mcp2mcp_mhu2.MHU_IRQCOMB",
                                 dest_path_prefix: "u_glue_logic_mcp2mcp_mhu2_rec_intr_masked"});
    endfunction

    virtual task main_phase(uvm_phase phase);
        int_cross_die_routing_sequence seq;
        int_subenv int_env;
        super.main_phase(phase);
        phase.raise_objection(this);

        `uvm_info(get_type_name(), "Starting cross-die interrupt routing test", UVM_LOW)

        // Cast the base subenv to int_subenv
        if (!$cast(int_env, env.subenv["int_subenv"])) begin
            `uvm_fatal(get_type_name(), "Failed to cast subenv[\"int_subenv\"] to int_subenv")
        end

        // Create and configure sequence
        seq = int_cross_die_routing_sequence::type_id::create("seq");
        seq.intr_configs = this.intr_configs;
        
        // Start the sequence
        seq.start(int_env.m_sequencer);

        #10us;
        phase.drop_objection(this);
    endtask

endclass

`endif // TC_CROSS_DIE_INTERRUPT_ROUTING