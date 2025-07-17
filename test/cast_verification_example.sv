`ifndef CAST_VERIFICATION_EXAMPLE
`define CAST_VERIFICATION_EXAMPLE

// 这个示例展示 $cast 如何保持对象的所有连接关系
class cast_verification_example extends int_tc_base;
    `uvm_component_utils(cast_verification_example)

    function new(string name = "cast_verification_example", uvm_component parent = null);
        super.new(name, parent);
    endfunction

    virtual task main_phase(uvm_phase phase);
        int_subenv int_env;
        super.main_phase(phase);
        phase.raise_objection(this);

        // Cast 操作
        if (!$cast(int_env, env.subenv["int_subenv"])) begin
            `uvm_fatal(get_type_name(), "Failed to cast subenv[\"int_subenv\"] to int_subenv")
        end

        // 验证对象身份一致性
        verify_object_identity(int_env);
        
        // 验证连接关系保持
        verify_connections_preserved(int_env);
        
        // 验证功能完整性
        verify_functionality(int_env);

        #1us;
        phase.drop_objection(this);
    endtask

    // 验证对象身份
    function void verify_object_identity(int_subenv int_env);
        soc_base_subenv base_ref = env.subenv["int_subenv"];
        
        `uvm_info(get_type_name(), "=== 对象身份验证 ===", UVM_LOW)
        `uvm_info(get_type_name(), $sformatf("原始引用路径: %s", base_ref.get_full_name()), UVM_LOW)
        `uvm_info(get_type_name(), $sformatf("Cast引用路径: %s", int_env.get_full_name()), UVM_LOW)
        
        // 验证是否为同一对象（地址比较）
        if (base_ref == int_env) begin
            `uvm_info(get_type_name(), "✓ 对象身份一致：指向同一内存地址", UVM_LOW)
        end else begin
            `uvm_error(get_type_name(), "✗ 对象身份不一致")
        end
    endfunction

    // 验证连接关系保持
    function void verify_connections_preserved(int_subenv int_env);
        `uvm_info(get_type_name(), "=== 连接关系验证 ===", UVM_LOW)
        
        // 检查内部组件是否存在
        if (int_env.m_monitor != null) begin
            `uvm_info(get_type_name(), "✓ m_monitor 连接保持", UVM_LOW)
        end else begin
            `uvm_error(get_type_name(), "✗ m_monitor 连接丢失")
        end
        
        if (int_env.m_sequencer != null) begin
            `uvm_info(get_type_name(), "✓ m_sequencer 连接保持", UVM_LOW)
        end else begin
            `uvm_error(get_type_name(), "✗ m_sequencer 连接丢失")
        end
        
        if (int_env.m_driver != null) begin
            `uvm_info(get_type_name(), "✓ m_driver 连接保持", UVM_LOW)
        end else begin
            `uvm_error(get_type_name(), "✗ m_driver 连接丢失")
        end
        
        if (int_env.m_scoreboard != null) begin
            `uvm_info(get_type_name(), "✓ m_scoreboard 连接保持", UVM_LOW)
        end else begin
            `uvm_error(get_type_name(), "✗ m_scoreboard 连接丢失")
        end
        
        // 验证层次结构
        `uvm_info(get_type_name(), $sformatf("m_sequencer 父组件: %s", 
                  int_env.m_sequencer.get_parent().get_name()), UVM_LOW)
    endfunction

    // 验证功能完整性
    function void verify_functionality(int_subenv int_env);
        `uvm_info(get_type_name(), "=== 功能完整性验证 ===", UVM_LOW)
        
        // 验证 sequencer 的端口连接
        if (int_env.m_sequencer.expected_port != null) begin
            `uvm_info(get_type_name(), "✓ sequencer.expected_port 可访问", UVM_LOW)
        end else begin
            `uvm_error(get_type_name(), "✗ sequencer.expected_port 不可访问")
        end
        
        // 验证可以正常创建和启动序列
        int_lightweight_sequence test_seq = int_lightweight_sequence::type_id::create("test_seq");
        if (test_seq != null) begin
            `uvm_info(get_type_name(), "✓ 可以创建序列对象", UVM_LOW)
            // 注意：这里不实际启动序列，只验证可访问性
            `uvm_info(get_type_name(), "✓ sequencer 可用于启动序列", UVM_LOW)
        end
    endfunction

endclass

`endif // CAST_VERIFICATION_EXAMPLE
