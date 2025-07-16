`ifndef INT_TRANSACTION_SV
`define INT_TRANSACTION_SV

`include "seq/int_def.sv"

class int_transaction extends uvm_sequence_item;
    `uvm_object_utils(int_transaction)

    // The interrupt that was detected
    interrupt_info_s interrupt_info;
    
    // The destination where it was detected
    string destination_name;

    function new(string name = "int_transaction");
        super.new(name);
    endfunction
    
    // Convert to string for debug
    virtual function string convert2string();
        return $sformatf("Interrupt: %s (group: %s, index: %0d), Detected at: %s",
                        interrupt_info.name,
                        interrupt_info.group.name(),
                        interrupt_info.index,
                        destination_name);
    endfunction
    
    // Print detailed information about the transaction
    function void do_print(uvm_printer printer);
        super.do_print(printer);
        
        `uvm_info(get_type_name(), $sformatf("Interrupt transaction detected: %s", convert2string()), UVM_MEDIUM)
        
        if (interrupt_info.rtl_path_src != "")
            `uvm_info(get_type_name(), $sformatf("RTL source path: %s", interrupt_info.rtl_path_src), UVM_HIGH)
            
        `uvm_info(get_type_name(), $sformatf("Trigger type: %s, Polarity: %s",
                 interrupt_info.trigger.name(),
                 interrupt_info.polarity.name()), UVM_HIGH)
    endfunction

endclass

`endif // INT_TRANSACTION_SV
