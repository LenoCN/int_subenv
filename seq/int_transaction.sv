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

endclass

`endif // INT_TRANSACTION_SV
