# 中断建模功能实现建议

## 概述

基于对中断向量表comment列的分析，本文档提供了补充缺失建模功能的具体实现建议。

## 1. 扩展Merge逻辑实现

### 1.1 修改 `seq/int_routing_model.sv`

需要在 `get_merge_sources()` 函数中添加以下merge关系：

```systemverilog
// 在现有的case语句中添加新的merge中断
case (merge_interrupt_name)
    // ... 现有的PLL merge逻辑 ...
    
    "iosub_normal_intr": begin
        // 收集所有应该merge到iosub_normal_intr的中断
        foreach (interrupt_map[i]) begin
            if (interrupt_map[i].name == "iosub_pmbus0_intr" ||
                interrupt_map[i].name == "iosub_pmbus1_intr" ||
                interrupt_map[i].name == "iosub_mem_ist_intr" ||
                interrupt_map[i].name == "iosub_dma_comreg_intr" ||
                // 添加所有DMAC channel中断
                interrupt_map[i].name == "iosub_dma_ch0_intr" ||
                interrupt_map[i].name == "iosub_dma_ch1_intr" ||
                // ... 其他DMAC通道 ...
                interrupt_map[i].name == "iosub_dma_ch15_intr") begin
                sources.push_back(interrupt_map[i]);
            end
        end
    end
    
    "iosub_slv_err_intr": begin
        // 收集所有应该merge到iosub_slv_err_intr的中断
        foreach (interrupt_map[i]) begin
            if (interrupt_map[i].name == "usb0_apb1ton_intr" ||
                interrupt_map[i].name == "usb1_apb1ton_intr" ||
                interrupt_map[i].name == "usb_top_apb1ton_intr") begin
                sources.push_back(interrupt_map[i]);
            end
        end
    end
    
    "iosub_ras_cri_intr": begin
        foreach (interrupt_map[i]) begin
            if (interrupt_map[i].name == "smmu_cri_intr" ||
                interrupt_map[i].name == "scp_ras_cri_intr" ||
                interrupt_map[i].name == "mcp_ras_cri_intr") begin
                sources.push_back(interrupt_map[i]);
            end
        end
    end
    
    "iosub_ras_eri_intr": begin
        foreach (interrupt_map[i]) begin
            if (interrupt_map[i].name == "smmu_eri_intr" ||
                interrupt_map[i].name == "scp_ras_eri_intr" ||
                interrupt_map[i].name == "mcp_ras_eri_intr") begin
                sources.push_back(interrupt_map[i]);
            end
        end
    end
    
    "iosub_ras_fhi_intr": begin
        foreach (interrupt_map[i]) begin
            if (interrupt_map[i].name == "smmu_fhi_intr" ||
                interrupt_map[i].name == "scp_ras_fhi_intr" ||
                interrupt_map[i].name == "mcp_ras_fhi_intr" ||
                interrupt_map[i].name == "iodap_chk_err_etf0" ||
                interrupt_map[i].name == "iodap_chk_err_etf1") begin
                sources.push_back(interrupt_map[i]);
            end
        end
    end
    
    "iosub_abnormal_0_intr": begin
        foreach (interrupt_map[i]) begin
            if (interrupt_map[i].name == "iodap_etr_buf_intr" ||
                interrupt_map[i].name == "iodap_catu_addrerr_intr") begin
                sources.push_back(interrupt_map[i]);
            end
        end
    end
```

### 1.2 更新 `is_merge_interrupt()` 函数

```systemverilog
static function bit is_merge_interrupt(string interrupt_name);
    return (interrupt_name == "merge_pll_intr_lock" ||
            interrupt_name == "merge_pll_intr_unlock" ||
            interrupt_name == "merge_pll_intr_frechangedone" ||
            interrupt_name == "merge_pll_intr_frechange_tot_done" ||
            interrupt_name == "merge_pll_intr_intdocfrac_err" ||
            interrupt_name == "iosub_normal_intr" ||
            interrupt_name == "iosub_slv_err_intr" ||
            interrupt_name == "iosub_ras_cri_intr" ||
            interrupt_name == "iosub_ras_eri_intr" ||
            interrupt_name == "iosub_ras_fhi_intr" ||
            interrupt_name == "iosub_abnormal_0_intr");
endfunction
```

## 2. 可配置路由逻辑实现

### 2.1 创建新文件 `seq/int_configurable_routing.sv`

```systemverilog
`ifndef INT_CONFIGURABLE_ROUTING_SV
`define INT_CONFIGURABLE_ROUTING_SV

class int_configurable_routing;
    
    // UART路由配置寄存器
    static bit [3:0] uart_to_imu_select = 4'b0111; // 默认选择UART1,2,3
    
    // 安全属性配置
    static bit dfx_lte_secure_mode = 1'b0; // 默认非安全模式
    
    // 配置UART到IMU的路由选择
    static function void configure_uart_routing(bit [3:0] selection);
        uart_to_imu_select = selection;
        `uvm_info("INT_CONFIG", $sformatf("UART routing configured: %04b", selection), UVM_MEDIUM)
    endfunction
    
    // 检查UART是否应该路由到IMU
    static function bit should_route_uart_to_imu(string uart_name);
        case (uart_name)
            "iosub_uart1_intr": return uart_to_imu_select[1];
            "iosub_uart2_intr": return uart_to_imu_select[2];
            "iosub_uart3_intr": return uart_to_imu_select[3];
            "iosub_uart4_intr": return uart_to_imu_select[0];
            default: return 1'b0;
        endcase
    endfunction
    
    // 配置DFX LTE安全属性
    static function void configure_dfx_security(bit secure);
        dfx_lte_secure_mode = secure;
        `uvm_info("INT_CONFIG", $sformatf("DFX LTE security mode: %s", secure ? "SECURE" : "NON-SECURE"), UVM_MEDIUM)
    endfunction
    
    // 获取DFX LTE安全模式
    static function bit get_dfx_security_mode();
        return dfx_lte_secure_mode;
    endfunction
    
endclass

`endif // INT_CONFIGURABLE_ROUTING_SV
```

### 2.2 修改 `seq/int_routing_sequence.sv`

在路由检查中添加可配置逻辑：

```systemverilog
// 在check_single_interrupt_routing中添加
virtual task check_single_interrupt_routing(interrupt_info_s info);
    // 检查是否为可配置路由中断
    if (is_configurable_routing_interrupt(info.name)) begin
        check_configurable_routing(info);
    end else begin
        // 原有的单个中断路由检查逻辑
        // ...
    end
endtask

virtual function bit is_configurable_routing_interrupt(string name);
    return (name == "iosub_uart1_intr" ||
            name == "iosub_uart2_intr" ||
            name == "iosub_uart3_intr" ||
            name == "iosub_uart4_intr" ||
            name == "iosub_dfx_lte_intr");
endfunction

virtual task check_configurable_routing(interrupt_info_s info);
    // 根据配置检查路由
    if (info.name.substr(0, 10) == "iosub_uart") begin
        check_uart_configurable_routing(info);
    end else if (info.name == "iosub_dfx_lte_intr") begin
        check_dfx_security_routing(info);
    end
endtask
```

## 3. 信号处理逻辑实现

### 3.1 创建新文件 `rtl/int_signal_processor.sv`

```systemverilog
module int_signal_processor (
    input  logic clk,
    input  logic rst_n,
    input  logic pulse_in,     // 脉冲输入
    output logic level_out,    // 电平输出
    input  logic clear         // 清除信号
);

    // 脉冲到电平转换逻辑
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            level_out <= 1'b0;
        end else if (clear) begin
            level_out <= 1'b0;
        end else if (pulse_in) begin
            level_out <= 1'b1;
        end
    end

endmodule
```

### 3.2 创建同步器模块 `rtl/int_synchronizer.sv`

```systemverilog
module int_synchronizer #(
    parameter SYNC_STAGES = 2
) (
    input  logic clk,
    input  logic rst_n,
    input  logic async_in,
    output logic sync_out
);

    logic [SYNC_STAGES-1:0] sync_reg;
    
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            sync_reg <= '0;
        end else begin
            sync_reg <= {sync_reg[SYNC_STAGES-2:0], async_in};
        end
    end
    
    assign sync_out = sync_reg[SYNC_STAGES-1];

endmodule
```

## 4. 测试用例扩展

### 4.1 创建 `test/tc_merge_interrupts.sv`

```systemverilog
class tc_merge_interrupts extends int_base_test;
    `uvm_component_utils(tc_merge_interrupts)
    
    function new(string name = "tc_merge_interrupts", uvm_component parent = null);
        super.new(name, parent);
    endfunction
    
    virtual task main_phase(uvm_phase phase);
        merge_interrupt_sequence seq;
        
        phase.raise_objection(this);
        
        seq = merge_interrupt_sequence::type_id::create("seq");
        seq.start(env.agent.sequencer);
        
        phase.drop_objection(this);
    endtask
    
endclass
```

### 4.2 创建 `test/tc_configurable_routing.sv`

```systemverilog
class tc_configurable_routing extends int_base_test;
    `uvm_component_utils(tc_configurable_routing)
    
    virtual task main_phase(uvm_phase phase);
        configurable_routing_sequence seq;
        
        phase.raise_objection(this);
        
        // 测试不同的UART路由配置
        int_configurable_routing::configure_uart_routing(4'b0001); // 只选择UART4
        seq = configurable_routing_sequence::type_id::create("seq");
        seq.start(env.agent.sequencer);
        
        int_configurable_routing::configure_uart_routing(4'b1110); // 选择UART1,2,3
        seq.start(env.agent.sequencer);
        
        phase.drop_objection(this);
    endtask
    
endclass
```

## 5. 实现步骤建议

### 第一阶段：扩展Merge逻辑
1. 修改 `int_routing_model.sv` 添加新的merge关系
2. 更新测试用例验证merge逻辑
3. 运行回归测试确保现有功能不受影响

### 第二阶段：实现可配置路由
1. 创建 `int_configurable_routing.sv`
2. 修改路由序列支持配置
3. 添加配置相关的测试用例

### 第三阶段：添加信号处理
1. 实现RTL信号处理模块
2. 集成到现有的监控框架
3. 添加信号处理相关测试

### 第四阶段：完善和优化
1. 添加更多边界条件测试
2. 优化性能和覆盖率
3. 完善文档和使用指南

## 6. 验证策略

### 6.1 功能验证
- 每个merge关系的正确性验证
- 可配置路由的所有组合测试
- 信号处理的时序验证

### 6.2 覆盖率目标
- 所有merge中断的源信号覆盖率 > 95%
- 所有路由配置组合覆盖率 > 90%
- 信号处理边界条件覆盖率 > 85%

### 6.3 性能验证
- 中断响应延迟测试
- 并发中断处理能力测试
- 配置切换的实时性测试

这个实现计划将确保中断向量表中所有特殊处理逻辑都得到完整的建模和验证。
