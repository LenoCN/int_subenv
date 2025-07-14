`ifndef INT_ROUTING_MODEL_SV
`define INT_ROUTING_MODEL_SV

`include "int_def.sv"

// This class serves as the prediction model for interrupt routing.
// It is populated with data parsed from '中断向量表-iosub-V0.5.csv'.
class int_routing_model;
    
    // The main data structure holding all interrupt information.
    static interrupt_info_s interrupt_map[];

    // `build` function to populate the interrupt map.
    // NOTE: RTL paths are placeholders and need to be updated based on the final RTL hierarchy from int_harness.sv
    static function void build();
        interrupt_info_s entry;
        interrupt_group_e current_group;

        if (interrupt_map.size() > 0) return; // a simple guard to prevent multiple builds
        // --- Start of IOSUB interrupts ---
        current_group = IOSUB;
        entry = '{name:"iosub_slv_err_intr", index:0, group:current_group, rtl_path_src:"top_tb.int_harness.u_dut.iosub_interrupts[0]", to_ap:1, rtl_path_ap:"top_tb.int_harness.u_dut.ap_bus[0]", to_scp:0, rtl_path_scp:"", to_mcp:0, rtl_path_mcp:"", to_imu:0, rtl_path_imu:"", to_io:0, rtl_path_io:"", to_other_die:0, rtl_path_other_die:""}; interrupt_map.push_back(entry);
        entry = '{name:"iosub_buffer_ovf_intr", index:1, group:current_group, rtl_path_src:"top_tb.int_harness.u_dut.iosub_interrupts[1]", to_ap:1, rtl_path_ap:"top_tb.int_harness.u_dut.ap_bus[1]", to_scp:0, rtl_path_scp:"", to_mcp:0, rtl_path_mcp:"", to_imu:0, rtl_path_imu:"", to_io:0, rtl_path_io:"", to_other_die:0, rtl_path_other_die:""}; interrupt_map.push_back(entry);
        // ... (All other interrupts from the CSV would be fully populated here) ...
        // --- Start of IO_DIE interrupts ---
        current_group = IO_DIE;
        entry = '{name:"io_die_intr_31_intr", index:31, group:current_group, rtl_path_src:"top_tb.int_harness.u_dut.io_die_interrupts[31]", to_ap:0, rtl_path_ap:"", to_scp:1, rtl_path_scp:"top_tb.int_harness.u_dut.scp_bus[31]", to_mcp:0, rtl_path_mcp:"", to_imu:0, rtl_path_imu:"", to_io:0, rtl_path_io:"", to_other_die:0, rtl_path_other_die:""}; interrupt_map.push_back(entry);
    endfunction

endclass

`endif // INT_ROUTING_MODEL_SV
