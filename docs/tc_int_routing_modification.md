# tc_int_routing 用例修改说明

## 修改概述

根据需求，修改了 `tc_int_routing` 用例的执行过程，对所有"来自SCP仅路由到SCP"以及"来自MCP仅路由到MCP"的中断源不进行激励触发。

## 修改内容

### 1. 修改文件：`seq/int_lightweight_sequence.sv`

在 `should_skip_interrupt_check` 函数中添加了新的跳过逻辑：

```systemverilog
// Skip interrupts from SCP that only route to SCP
if (info.group == SCP && info.to_scp == 1 && 
    info.to_ap == 0 && info.to_mcp == 0 && info.to_imu == 0 && 
    info.to_io == 0 && info.to_other_die == 0) begin
    `uvm_info(get_type_name(), $sformatf("Skipping interrupt '%s' - from SCP and only routes to SCP",
             info.name), UVM_MEDIUM)
    return 1;
end

// Skip interrupts from MCP that only route to MCP
if (info.group == MCP && info.to_mcp == 1 && 
    info.to_ap == 0 && info.to_scp == 0 && info.to_imu == 0 && 
    info.to_io == 0 && info.to_other_die == 0) begin
    `uvm_info(get_type_name(), $sformatf("Skipping interrupt '%s' - from MCP and only routes to MCP",
             info.name), UVM_MEDIUM)
    return 1;
end
```

### 2. 修改文件：`test_skip_logic.sv`

更新了测试逻辑以验证新的跳过条件，添加了以下测试用例：
- 测试SCP中断只路由到SCP的情况（应该被跳过）
- 测试MCP中断只路由到MCP的情况（应该被跳过）
- 测试SCP中断路由到多个目标的情况（不应该被跳过）
- 测试MCP中断路由到多个目标的情况（不应该被跳过）

## 跳过逻辑说明

### 跳过条件

中断源会被跳过激励触发，当且仅当满足以下条件之一：

1. **原有逻辑**：中断只路由到 `other_die` 或 `io` 目标，且没有其他路由目标
2. **新增逻辑**：来自SCP的中断源（`group == SCP`）且只路由到SCP（`to_scp == 1` 且其他所有路由目标为0）
3. **新增逻辑**：来自MCP的中断源（`group == MCP`）且只路由到MCP（`to_mcp == 1` 且其他所有路由目标为0）

### 不跳过的情况

以下情况的中断源仍会进行激励触发：
- 没有任何路由目标的中断（merge源中断）
- 有多个路由目标的中断
- 来自其他组（IOSUB、USB、SMMU等）的中断

## 受影响的中断源

### SCP中断源（仅路由到SCP）
根据中断映射文件 `seq/int_map_entries.svh`，以下SCP中断源将被跳过：
- `scp_timer64_0_intr`
- `scp_timer64_1_intr`
- `scp_timer64_2_intr`
- `scp_timer64_3_intr`
- `scp_cpu_bus_fault_intr`
- `scp_acl_intr`
- `scp_cpu_cti_irq`
- `scp2ap_mhu_send_intr_0`
- `scp2ap_mhu_send_intr_1`
- `scp2ap_mhu_send_intr_2`
- `scp2ap_mhu_send_intr_3`
- `ap2scp_mhu_receive_intr_0`
- `ap2scp_mhu_receive_intr_1`
- `ap2scp_mhu_receive_intr_2`
- `ap2scp_mhu_receive_intr_3`

### MCP中断源（仅路由到MCP）
以下MCP中断源将被跳过：
- `mcp_timer64_0_intr`
- `mcp_timer64_1_intr`
- `mcp_timer64_2_intr`
- `mcp_timer64_3_intr`
- `mcp_uart_intr`
- `mcp_smbus_intr`
- `mcp_gpio_intr`
- `mcp_i2c_intr`
- `mcp_cpu_bus_fault_intr`
- `mcp_acl_intr`
- `mcp_cpu_cti_irq`
- `mcp_sram_bus_fault_intr`

## 测试验证

可以通过运行 `tc_int_routing` 测试用例来验证修改效果。在测试日志中，会看到类似以下的信息：

```
UVM_MEDIUM: Skipping interrupt 'scp_timer64_0_intr' - from SCP and only routes to SCP
UVM_MEDIUM: Skipping interrupt 'mcp_timer64_0_intr' - from MCP and only routes to MCP
```

## 影响分析

### 正面影响
1. **减少不必要的测试**：避免对内部循环路由的中断进行激励，提高测试效率
2. **更符合实际使用场景**：SCP/MCP内部中断通常由各自的处理器内部产生和处理
3. **减少测试时间**：跳过这些中断源可以缩短测试执行时间

### 注意事项
1. **路由验证缺失**：这些被跳过的中断源的路由功能将不会被验证
2. **覆盖率影响**：功能覆盖率可能会受到影响，需要在覆盖率报告中说明
3. **文档更新**：需要在测试计划中明确说明这些中断源被跳过的原因

## 后续建议

1. **专门测试用例**：如果需要验证这些内部路由中断，可以创建专门的测试用例
2. **配置选项**：可以考虑添加配置选项来控制是否跳过这些中断源
3. **覆盖率补偿**：通过其他测试方法补偿这些中断源的覆盖率
