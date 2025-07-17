`ifndef INT_STIMULUS_ITEM_SV
`define INT_STIMULUS_ITEM_SV

// Stimulus types for interrupt driver
typedef enum {
    STIMULUS_ASSERT,    // Assert the interrupt (using appropriate method for trigger type)
    STIMULUS_DEASSERT,  // Deassert the interrupt (for level-triggered interrupts)
    STIMULUS_CLEAR      // Clear the interrupt (release HDL force)
} stimulus_type_e;

// Transaction class for interrupt stimulus
class int_stimulus_item extends uvm_sequence_item;
    `uvm_object_utils(int_stimulus_item)

    // Interrupt information
    interrupt_info_s interrupt_info;
    
    // Stimulus type
    stimulus_type_e stimulus_type = STIMULUS_ASSERT;

    function new(string name = "int_stimulus_item");
        super.new(name);
    endfunction

    // Helper function to create a new stimulus item
    // Note: UVM macros cannot be used in static functions as they call automatic methods
    static function int_stimulus_item create_stimulus(
        interrupt_info_s info,
        stimulus_type_e type_val = STIMULUS_ASSERT
    );
        int_stimulus_item item = int_stimulus_item::type_id::create("stim_item");

        item.interrupt_info = info;
        item.stimulus_type = type_val;

        return item;
    endfunction

    // Convert to string for debug
    virtual function string convert2string();
        string s;
        s = $sformatf("Interrupt: %s (group: %s, index: %0d), Type: %s",
                     interrupt_info.name,
                     interrupt_info.group.name(),
                     interrupt_info.index,
                     stimulus_type.name());
                     
        if (interrupt_info.rtl_path_src != "")
            s = {s, $sformatf(", RTL path: %s", interrupt_info.rtl_path_src)};
            
        return s;
    endfunction
endclass

`endif // INT_STIMULUS_ITEM_SV
