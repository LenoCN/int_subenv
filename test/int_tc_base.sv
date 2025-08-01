`ifndef INT_TC_BASE
`define INT_TC_BASE

class int_tc_base extends soc_tc_base;
    bit[31:0] prdata;

    virtual global_interface  global_if;
    virtual int_interface     int_if;

    // Model object references
    int_register_model m_register_model;
    int_routing_model  m_routing_model;

    `uvm_component_utils(int_tc_base)

    function new(string name = "int_tc_base",uvm_component parent= null);
        super.new(name,parent);
    endfunction
    
    function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        if(!uvm_config_db#(virtual global_interface)::get(uvm_root::get(),"","global_if",global_if)) begin
            `uvm_fatal(get_type_name(),"can not get global interface");
        end
        if(!uvm_config_db#(virtual int_interface)::get(this,"","int_if",int_if)) begin
            `uvm_fatal(get_type_name(), $sformatf("can not get int interface"));
        end

        // Create model objects at test case level (top level)
        m_register_model = int_register_model::type_id::create("m_register_model");
        m_routing_model = int_routing_model::type_id::create("m_routing_model");

        // Set model objects in configuration database for sub-components
        uvm_config_db#(int_register_model)::set(this, "*", "register_model", m_register_model);
        uvm_config_db#(int_routing_model)::set(this, "*", "routing_model", m_routing_model);

        uvm_top.set_timeout(13_000_000, 0); //ns
    endfunction

    function void connect_phase(uvm_phase phase);
        super.connect_phase(phase);
    endfunction

    task pre_reset_phase(uvm_phase phase);
        phase.raise_objection(this);

        // Initialize interrupt register model
        `uvm_info(get_type_name(), "Initializing interrupt register model...", UVM_MEDIUM)
        m_register_model.init_registers();

        `uvm_info(get_type_name(), "Randomizing interrupt mask registers...", UVM_MEDIUM)
        m_register_model.randomize_mask_registers();

        // Update ACCEL UART and DMA interrupt routing based on configuration registers
        `uvm_info(get_type_name(), "Updating ACCEL UART and DMA interrupt routing...", UVM_MEDIUM)
        m_register_model.update_accel_uart_dma_routing(m_routing_model);

        // Print the randomized configuration
        m_register_model.print_register_config();

        phase.drop_objection(this);
    endtask

    task post_reset_phase(uvm_phase phase);
        phase.raise_objection(this);
        phase.drop_objection(this);
    endtask

    task main_phase(uvm_phase phase);
        // Base task, derived tasks should handle objections
    endtask : main_phase

    task post_shutdown_phase(uvm_phase phase);
        phase.raise_objection(this);

        // Check interrupt status registers at test completion
        `uvm_info(get_type_name(), "Checking interrupt status registers at test completion...", UVM_MEDIUM)
        check_interrupt_status_registers();

        phase.drop_objection(this);
    endtask

    // Check interrupt status registers
    virtual task check_interrupt_status_registers();
        logic [31:0] status_value;
        int status_errors = 0;

        `uvm_info(get_type_name(), "=== Interrupt Status Register Check ===", UVM_MEDIUM)

        // Check PLL interrupt status registers
        for (int i = 0; i < 5; i++) begin
            m_register_model.read_register(int_register_model::ADDR_STATUS_PLL_INTR_0 + (i * 4), status_value);
            `uvm_info(get_type_name(), $sformatf("PLL status[%0d]: 0x%08x", i, status_value), UVM_HIGH)
        end

        // Check IOSUB normal interrupt status registers
        m_register_model.read_register(int_register_model::ADDR_STATUS_IOSUB_NORMAL_INTR_0, status_value);
        `uvm_info(get_type_name(), $sformatf("IOSUB normal status[0]: 0x%08x", status_value), UVM_HIGH)

        m_register_model.read_register(int_register_model::ADDR_STATUS_IOSUB_NORMAL_INTR_1, status_value);
        `uvm_info(get_type_name(), $sformatf("IOSUB normal status[1]: 0x%08x", status_value), UVM_HIGH)

        // Check PSUB and PCIE1 status registers
        m_register_model.read_register(int_register_model::ADDR_STATUS_PSUB_TO_IOSUB_INTR, status_value);
        `uvm_info(get_type_name(), $sformatf("PSUB status: 0x%08x", status_value), UVM_HIGH)

        m_register_model.read_register(int_register_model::ADDR_STATUS_PCIE1_TO_IOSUB_INTR, status_value);
        `uvm_info(get_type_name(), $sformatf("PCIE1 status: 0x%08x", status_value), UVM_HIGH)

        // Print summary of all status registers
        m_register_model.print_status_registers();

        if (status_errors == 0) begin
            `uvm_info(get_type_name(), "✅ Status register check completed", UVM_MEDIUM)
        end else begin
            `uvm_error(get_type_name(), $sformatf("❌ Status register check found %0d errors", status_errors))
        end

        `uvm_info(get_type_name(), "=== End Status Register Check ===", UVM_MEDIUM)
    endtask
endclass


`endif
