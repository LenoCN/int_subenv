# IOSUB Normal 中断串行Mask处理分析

## 📋 概述

**日期**: 2025-07-31  
**问题**: `iosub_normal_int`的mask和SCP/MCP的mask应该是串行执行的过程，两个mask都会同时起作用  
**当前状态**: 函数只检查了一层mask，缺少串行mask处理逻辑  

## 🔍 问题分析

### 当前实现的局限性
当前`is_interrupt_masked`函数的实现中：

```systemverilog
// 当前只检查一层mask
if (is_iosub_normal) begin
    // 只检查 IOSUB normal 专用的mask寄存器
    addr = ADDR_MASK_IOSUB_TO_SCP_NORMAL_INTR_0;  // 或 _1
    // 返回这一层mask的结果
    return ~mask_value[bit_index];
end
```

### 正确的串行Mask架构
根据您的说明，正确的处理流程应该是：

```
中断信号 → IOSUB Normal Mask → SCP/MCP General Mask → 最终输出
```

即：
1. **第一层**: 检查`IOSUB_TO_SCP_NORMAL_INTR`mask
2. **第二层**: 检查`IOSUB_TO_SCP_INTR`mask  
3. **最终结果**: 两层mask都通过才算未被屏蔽

## 🛠️ 建议的修复方案

### 方案1: 修改`is_interrupt_masked`函数
```systemverilog
function bit is_interrupt_masked(string interrupt_name, string destination, int_routing_model routing_model);
    bit first_layer_masked = 0;   // IOSUB normal mask结果
    bit second_layer_masked = 0;  // SCP/MCP general mask结果
    
    if (is_iosub_normal) begin
        // 第一层: 检查IOSUB normal mask
        first_layer_masked = check_iosub_normal_mask(interrupt_name, destination, routing_model);
        
        if (first_layer_masked) begin
            `uvm_info("INT_REG_MODEL", $sformatf("🚫 Interrupt '%s' blocked by IOSUB normal mask", interrupt_name), UVM_HIGH)
            return 1; // 第一层就被屏蔽了
        end
        
        // 第二层: 检查SCP/MCP general mask
        second_layer_masked = check_general_mask(interrupt_name, destination, routing_model);
        
        `uvm_info("INT_REG_MODEL", $sformatf("🔗 Serial mask result for '%s': normal_mask=%b, general_mask=%b, final=%b", 
                  interrupt_name, first_layer_masked, second_layer_masked, second_layer_masked), UVM_HIGH)
        
        return second_layer_masked;
    end
    else begin
        // 非IOSUB normal中断，只检查一层mask
        return check_general_mask(interrupt_name, destination, routing_model);
    end
endfunction
```

### 方案2: 新增串行mask检查函数
```systemverilog
function bit is_interrupt_serial_masked(string interrupt_name, string destination, int_routing_model routing_model);
    bit normal_mask_result;
    bit general_mask_result;
    
    // 检查IOSUB normal mask
    normal_mask_result = check_iosub_normal_mask_layer(interrupt_name, destination, routing_model);
    if (normal_mask_result) return 1; // 第一层屏蔽
    
    // 检查general mask
    general_mask_result = check_general_mask_layer(interrupt_name, destination, routing_model);
    return general_mask_result; // 第二层结果
endfunction
```

## 📊 影响分析

### 当前缺失的检查
对于IOSUB normal中断，当前实现缺少了：

1. **SCP目标**: 缺少`ADDR_MASK_IOSUB_TO_SCP_INTR_*`寄存器检查
2. **MCP目标**: 缺少`ADDR_MASK_IOSUB_TO_MCP_INTR_*`寄存器检查

### 寄存器映射关系
```
IOSUB Normal中断 → SCP:
第一层: ADDR_MASK_IOSUB_TO_SCP_NORMAL_INTR_0/1  (45-bit mask)
第二层: ADDR_MASK_IOSUB_TO_SCP_INTR_0/1/2/3/4   (131-bit mask)

IOSUB Normal中断 → MCP:
第一层: ADDR_MASK_IOSUB_TO_MCP_NORMAL_INTR_0/1  (45-bit mask)  
第二层: ADDR_MASK_IOSUB_TO_MCP_INTR_0/1/2/3/4   (146-bit mask)
```

## 🔧 实现细节

### 需要的辅助函数
```systemverilog
// 检查IOSUB normal mask层
function bit check_iosub_normal_mask_layer(string interrupt_name, string destination, int_routing_model routing_model);
    // 当前的IOSUB normal mask检查逻辑
endfunction

// 检查general mask层  
function bit check_general_mask_layer(string interrupt_name, string destination, int_routing_model routing_model);
    // 当前的general mask检查逻辑
endfunction
```

### 调试信息增强
```systemverilog
`uvm_info("INT_REG_MODEL", $sformatf("🔗 Serial mask check for '%s' to '%s':", interrupt_name, destination), UVM_HIGH)
`uvm_info("INT_REG_MODEL", $sformatf("   Layer 1 (IOSUB Normal): %s", first_layer_masked ? "BLOCKED" : "PASSED"), UVM_HIGH)
`uvm_info("INT_REG_MODEL", $sformatf("   Layer 2 (General): %s", second_layer_masked ? "BLOCKED" : "PASSED"), UVM_HIGH)
`uvm_info("INT_REG_MODEL", $sformatf("   Final Result: %s", final_result ? "MASKED" : "ENABLED"), UVM_HIGH)
```

## 🎯 建议的实施步骤

1. **第一步**: 重构现有函数，分离两层mask检查逻辑
2. **第二步**: 实现串行mask检查机制
3. **第三步**: 添加详细的调试信息
4. **第四步**: 创建测试用例验证串行mask功能
5. **第五步**: 更新文档说明新的mask处理流程

## ⚠️ 注意事项

1. **向后兼容**: 确保修改不影响非IOSUB normal中断的处理
2. **性能考虑**: 串行检查可能增加函数执行时间
3. **调试友好**: 需要清晰的日志来追踪两层mask的状态
4. **测试覆盖**: 需要测试各种mask组合的情况

## 📝 总结

当前的`is_interrupt_masked`函数缺少了IOSUB normal中断的串行mask处理逻辑。需要修改函数以支持两层mask的串行检查，确保中断信号经过完整的mask链路处理。

这个修复对于正确模拟硬件行为至关重要，特别是在复杂的中断路由场景中。

---
**分析完成时间**: 2025-07-31  
**优先级**: 高  
**影响范围**: IOSUB normal中断mask处理  
**建议实施**: 立即进行
