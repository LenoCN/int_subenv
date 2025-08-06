`ifndef TEST_RACE_CONDITION_FIX_SV
`define TEST_RACE_CONDITION_FIX_SV

// Test to verify the race condition fix using wait_ptrigger()
class test_race_condition_fix extends uvm_test;
    `uvm_component_utils(test_race_condition_fix)
    
    int_event_manager event_manager;
    uvm_event_pool event_pool;
    
    function new(string name = "test_race_condition_fix", uvm_component parent = null);
        super.new(name, parent);
    endfunction
    
    function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        event_manager = int_event_manager::type_id::create("event_manager");
        event_pool = event_manager.get_event_pool();
    endfunction
    
    task run_phase(uvm_phase phase);
        phase.raise_objection(this);
        
        `uvm_info(get_type_name(), "=== Starting Race Condition Fix Test ===", UVM_LOW)
        
        // Test 1: Normal case - wait_trigger before trigger
        test_normal_case();
        
        // Test 2: Race condition case - trigger before wait_trigger
        test_race_condition_case();
        
        // Test 3: Multiple events race condition
        test_multiple_events_race();
        
        `uvm_info(get_type_name(), "=== Race Condition Fix Test Completed ===", UVM_LOW)
        
        phase.drop_objection(this);
    endtask
    
    // Test normal case where wait_trigger is called before trigger
    task test_normal_case();
        uvm_event test_event;
        string event_key = "test_interrupt@AP";
        
        `uvm_info(get_type_name(), "--- Test 1: Normal Case ---", UVM_MEDIUM)
        
        test_event = event_pool.get(event_key);
        
        fork
            begin
                #5ns; // Small delay to ensure wait_trigger is called first
                event_manager.mark_event_triggered(event_key);
                test_event.trigger();
                `uvm_info(get_type_name(), "Event triggered", UVM_MEDIUM)
            end
            begin
                test_event.wait_trigger();
                `uvm_info(get_type_name(), "Event received", UVM_MEDIUM)
            end
        join
        
        `uvm_info(get_type_name(), "✅ Normal case test passed", UVM_LOW)
        #10ns; // Allow time for cleanup
    endtask
    
    // Test race condition case where trigger is called before wait_trigger
    task test_race_condition_case();
        interrupt_info_s test_info;
        string event_key = "race_test_interrupt@SCP";
        uvm_event test_event;
        
        `uvm_info(get_type_name(), "--- Test 2: Race Condition Case ---", UVM_MEDIUM)
        
        // Setup test interrupt info
        test_info.name = "race_test_interrupt";
        test_info.to_scp = 1;
        test_info.to_ap = 0;
        test_info.to_mcp = 0;
        test_info.to_accel = 0;
        test_info.to_io = 0;
        test_info.to_other_die = 0;
        
        test_event = event_pool.get(event_key);
        
        // Trigger event BEFORE calling wait_for_interrupt_detection
        event_manager.mark_event_triggered(event_key);
        test_event.trigger();
        `uvm_info(get_type_name(), "Event triggered BEFORE wait", UVM_MEDIUM)
        
        #1ns; // Small delay to simulate race condition
        
        // Now call wait_for_interrupt_detection - should not hang
        fork
            begin
                event_manager.wait_for_interrupt_detection(test_info, 100); // Short timeout
                `uvm_info(get_type_name(), "✅ Race condition handled correctly", UVM_LOW)
            end
            begin
                #200ns; // Timeout longer than the wait timeout
                `uvm_error(get_type_name(), "❌ Race condition NOT handled - test hung")
            end
        join_any
        disable fork;
        
        #10ns; // Allow time for cleanup
    endtask
    
    // Test multiple events with race conditions
    task test_multiple_events_race();
        interrupt_info_s test_info;
        string event_keys[$];
        uvm_event test_events[$];
        
        `uvm_info(get_type_name(), "--- Test 3: Multiple Events Race ---", UVM_MEDIUM)
        
        // Setup test interrupt info with multiple destinations
        test_info.name = "multi_race_interrupt";
        test_info.to_scp = 1;
        test_info.to_ap = 1;
        test_info.to_mcp = 1;
        test_info.to_accel = 0;
        test_info.to_io = 0;
        test_info.to_other_die = 0;
        
        // Prepare event keys
        event_keys.push_back("multi_race_interrupt@SCP");
        event_keys.push_back("multi_race_interrupt@AP");
        event_keys.push_back("multi_race_interrupt@MCP");
        
        // Get events
        foreach (event_keys[i]) begin
            test_events.push_back(event_pool.get(event_keys[i]));
        end
        
        // Trigger some events BEFORE wait (simulating race condition)
        event_manager.mark_event_triggered(event_keys[0]); // SCP
        test_events[0].trigger();
        event_manager.mark_event_triggered(event_keys[2]); // MCP
        test_events[2].trigger();
        `uvm_info(get_type_name(), "Pre-triggered 2 out of 3 events", UVM_MEDIUM)
        
        fork
            begin
                // Trigger remaining event after a delay
                #20ns;
                event_manager.mark_event_triggered(event_keys[1]); // AP
                test_events[1].trigger();
                `uvm_info(get_type_name(), "Triggered remaining event", UVM_MEDIUM)
            end
            begin
                // Wait for all events
                event_manager.wait_for_interrupt_detection(test_info, 100);
                `uvm_info(get_type_name(), "✅ Multiple events race condition handled correctly", UVM_LOW)
            end
            begin
                #200ns; // Timeout
                `uvm_error(get_type_name(), "❌ Multiple events race condition NOT handled")
            end
        join_any
        disable fork;
        
        #10ns; // Allow time for cleanup
    endtask
    
endclass

`endif // TEST_RACE_CONDITION_FIX_SV
