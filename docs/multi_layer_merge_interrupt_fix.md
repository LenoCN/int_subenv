# 多层Merge中断路由预测修复

## 问题描述

在进行`iosub_slv_err_intr`类型merge类中断处理的时候，虽然路由方向中不包含SCP和MCP，但是由于`iosub_slv_err_intr`进一步的被汇聚为`iosub_normal_intr`中断，因此在进行目的预测的时候还要同时考虑`iosub_normal_intr`是否分别经过scp和mcp的`iosub_normal_intr` mask可以被路由到MCP和SCP。

## 问题分析

### 中断汇聚层次结构

```
iosub_slv_err_intr (merge interrupt)
├── usb0_apb1ton_intr
├── usb1_apb1ton_intr  
└── usb_top_apb1ton_intr
    ↓ (进一步汇聚)
iosub_normal_intr (higher-level merge interrupt)
├── iosub_slv_err_intr
├── iosub_pmbus0_intr
├── iosub_pmbus1_intr
├── iosub_mem_ist_intr
├── iosub_dma_comreg_intr
├── iosub_dma_ch0_intr ~ iosub_dma_ch15_intr
└── ... (其他IOSUB normal中断)
    ↓ (路由到目标)
SCP/MCP (最终目标)
```

### 原有问题

1. **路由预测不完整**: `iosub_slv_err_intr`在配置中`to_scp:0, to_mcp:0`，但实际上它通过`iosub_normal_intr`可以间接路由到SCP/MCP
2. **Mask检查缺失**: 对于间接路由的中断，没有正确检查上层merge中断的mask状态

## 解决方案

### 1. 路由预测逻辑增强

在`seq/int_routing_model.sv`中的`predict_interrupt_routing_with_mask`函数中添加间接路由检查：

```systemverilog
// Special handling for merge interrupts that may be further aggregated
// Check if this interrupt is merged into another interrupt that has routing
if (!routing_enabled && is_merge_interrupt(interrupt_name)) begin
    routing_enabled = check_indirect_routing_via_merge(interrupt_name, destination);
    `uvm_info("INT_ROUTING_MODEL", $sformatf("🔗 Indirect routing check via merge: interrupt '%s' to '%s' = %s",
              interrupt_name, destination, routing_enabled ? "ENABLED" : "DISABLED"), UVM_HIGH)
end
```

### 2. 间接路由检查函数

新增`check_indirect_routing_via_merge`函数处理特定的merge汇聚关系：

```systemverilog
function bit check_indirect_routing_via_merge(string interrupt_name, string destination);
    // Special case: iosub_slv_err_intr is merged into iosub_normal_intr
    if (interrupt_name == "iosub_slv_err_intr") begin
        // Check if iosub_normal_intr has routing to the destination
        foreach (interrupt_map[i]) begin
            if (interrupt_map[i].name == "iosub_normal_intr") begin
                case (destination.toupper())
                    "SCP": has_indirect_routing = interrupt_map[i].to_scp;
                    "MCP": has_indirect_routing = interrupt_map[i].to_mcp;
                    // ... 其他目标
                endcase
            end
        end
    end
    return has_indirect_routing;
endfunction
```

### 3. Mask处理逻辑完善

在`seq/int_register_model.sv`中的`is_interrupt_masked`函数中添加间接路由的mask检查：

```systemverilog
// Special handling for merge interrupts that route indirectly via other merge interrupts
if (interrupt_name == "iosub_slv_err_intr" && (destination.toupper() == "SCP" || destination.toupper() == "MCP")) begin
    // For iosub_slv_err_intr routing to SCP/MCP, we need to check:
    // 1. iosub_normal_intr mask (since iosub_slv_err_intr is merged into it)
    // 2. The general SCP/MCP mask for iosub_normal_intr
    
    bit iosub_normal_masked = is_interrupt_masked("iosub_normal_intr", destination, routing_model);
    
    if (iosub_normal_masked) begin
        return 1; // Blocked by iosub_normal_intr mask
    end else begin
        return 0; // Not masked
    end
end
```

## 技术实现细节

### 路由检查流程

1. **直接路由检查**: 首先检查中断是否有直接路由到目标
2. **间接路由检查**: 如果没有直接路由且是merge中断，检查是否有间接路由
3. **Mask状态检查**: 对于有路由的中断，检查相应的mask状态

### Mask检查策略

对于间接路由的中断：
- **Layer 1**: 检查源中断本身的mask状态（如果适用）
- **Layer 2**: 检查上层merge中断的mask状态
- **Layer 3**: 检查最终目标的general mask状态

### 扩展性设计

代码设计支持添加更多的merge汇聚关系：
- 在`check_indirect_routing_via_merge`函数中添加新的case
- 在mask检查逻辑中添加相应的特殊处理

## 验证方法

### 测试场景

1. **直接激励测试**: 激励`iosub_slv_err_intr`的源中断，验证是否能正确路由到SCP/MCP
2. **Mask功能测试**: 设置不同的mask状态，验证路由预测的准确性
3. **多层汇聚测试**: 验证复杂的merge关系是否正确处理

### 预期结果

- `iosub_slv_err_intr`现在能够正确预测到SCP/MCP的路由
- Mask状态能够正确影响间接路由的中断
- 系统能够处理更复杂的多层merge场景

## 影响范围

### 修改文件

1. `seq/int_routing_model.sv`: 路由预测逻辑增强
2. `seq/int_register_model.sv`: Mask处理逻辑完善
3. `PROJECT_STATUS_SUMMARY.md`: 项目状态更新

### 兼容性

- 向后兼容：不影响现有的直接路由中断
- 功能增强：提升了merge中断的路由预测准确性
- 性能影响：最小，仅在特定场景下增加少量检查

## 未来扩展

### 可扩展的架构

当前实现为添加更多的多层merge关系提供了框架：
1. 在`check_indirect_routing_via_merge`中添加新的汇聚关系
2. 在mask检查逻辑中添加相应的特殊处理
3. 更新相关的测试用例

### 建议的改进

1. **配置驱动**: 将merge关系配置化，减少硬编码
2. **自动发现**: 自动分析merge关系，减少手动配置
3. **性能优化**: 对于复杂的merge关系，考虑缓存机制

---

**修复日期**: 2025-08-05  
**修复版本**: v1.0  
**影响等级**: 重要功能增强
