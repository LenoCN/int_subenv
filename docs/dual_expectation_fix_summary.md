# Dual Expectation Fix Summary - 双重预期修复总结

## 📋 问题描述

在 `int_lightweight_sequence.sv` 的 merge 中断处理过程中，发现了一个关键的逻辑缺陷：

**问题现象**：对于既属于 `iosub_normal_intr` 汇聚源又要路由到 AP 或其他目的地的中断，系统只预期了通过 merge 路由到 SCP/MCP 的响应，但没有预期其本身直接路由目的地的响应。

**问题根因**：在 `test_merge_source` 和 `test_multiple_merge_sources` 函数中，只注册了 merge 中断的预期，忽略了源中断本身的直接路由预期。

## 🔍 技术分析

### 问题场景

假设有一个中断 `iosub_xxx_intr`：
- **属性1**：属于 `iosub_normal_intr` 汇聚源（index 在 [0,9] ∪ [15,50] 范围内）
- **属性2**：有自己的直接路由（比如 `to_ap = 1`, `to_accel = 1`）

### 原始逻辑问题

**修复前的行为**：
```systemverilog
// 只注册 merge 中断预期
add_expected_with_mask(merge_info);  // iosub_normal_intr -> SCP/MCP

// 缺失：源中断的直接路由预期
// add_expected_with_mask(source_info);  // iosub_xxx_intr -> AP/ACCEL
```

**结果**：
- ✅ 预期：`iosub_normal_intr` 到 SCP/MCP 的响应
- ❌ **缺失**：`iosub_xxx_intr` 到 AP/ACCEL 的直接响应

## 🛠️ 修复内容

### 1. 修复 `test_merge_source` 函数

**新增逻辑**：
- 检查源中断是否有直接路由（排除 SCP/MCP，因为它们通过 merge 处理）
- 如果有直接路由，同时注册源中断的预期
- 在检测和状态更新阶段也同时处理两种中断

**关键代码变更**：
```systemverilog
// 检查源中断的直接路由
source_has_direct_routing = (source_info.to_ap || source_info.to_accel || 
                           source_info.to_io || source_info.to_other_die);

// 双重预期注册
add_expected_with_mask(merge_info);  // Merge 路由预期
if (source_has_direct_routing) begin
    add_expected_with_mask(source_info);  // 直接路由预期
end

// 双重检测等待
wait_for_interrupt_detection_with_mask(merge_info);
if (source_has_direct_routing) begin
    wait_for_interrupt_detection_with_mask(source_info);
end

// 双重状态更新
m_routing_model.update_interrupt_status(merge_info.name, 1, m_register_model);
if (source_has_direct_routing) begin
    m_routing_model.update_interrupt_status(source_info.name, 1, m_register_model);
end
```

### 2. 修复 `test_multiple_merge_sources` 函数

**新增逻辑**：
- 在多源测试中，为每个有直接路由的源中断注册预期
- 在检测阶段等待所有直接路由的响应
- 在状态更新阶段更新所有相关中断的状态

### 3. 修复 `test_single_interrupt` 函数

**新增逻辑**：
- 检查单个中断是否属于 `iosub_normal_intr` 汇聚源
- 如果是汇聚源，同时注册 merge 中断的预期
- 在检测阶段等待两种路由的响应
- 在状态更新阶段更新两种中断的状态

**关键代码变更**：
```systemverilog
// 多源双重预期注册
add_expected_with_mask(merge_info);  // Merge 路由预期
foreach (source_interrupts[i]) begin
    if (source_interrupts[i].rtl_path_src != "") begin
        bit source_has_direct_routing = (source_interrupts[i].to_ap ||
                                        source_interrupts[i].to_accel ||
                                        source_interrupts[i].to_io ||
                                        source_interrupts[i].to_other_die);
        if (source_has_direct_routing) begin
            add_expected_with_mask(source_interrupts[i]);  // 直接路由预期
        end
    end
end
```

### 4. 修复 `test_single_interrupt` 函数

**新增逻辑**：
- 在单个中断测试中检查是否为 `iosub_normal_intr` 汇聚源
- 如果是汇聚源，同时注册 merge 中断和源中断的预期
- 完整的双重检测和状态更新流程

**关键代码变更**：
```systemverilog
// 检查是否为 iosub_normal_intr 汇聚源
is_iosub_normal_source = m_routing_model.is_iosub_normal_intr_source(info.name);

if (is_iosub_normal_source) begin
    // 注册 iosub_normal_intr 预期 (merge 路由)
    add_expected_with_mask(iosub_normal_info);
end

// 注册源中断预期 (直接路由)
add_expected_with_mask(info);

// 双重检测等待
if (is_iosub_normal_source) begin
    wait_for_interrupt_detection_with_mask(iosub_normal_info);
end
wait_for_interrupt_detection_with_mask(info);
```

## 🎯 修复效果

### 修复前的行为
```
激励: iosub_xxx_intr (to_ap=1, 属于iosub_normal_intr汇聚源)
预期: ✅ iosub_normal_intr -> SCP/MCP
预期: ❌ iosub_xxx_intr -> AP (缺失)
结果: 测试可能失败或不完整
```

### 修复后的行为
```
激励: iosub_xxx_intr (to_ap=1, 属于iosub_normal_intr汇聚源)
预期: ✅ iosub_normal_intr -> SCP/MCP (merge路由)
预期: ✅ iosub_xxx_intr -> AP (直接路由)
结果: 完整的双重路由验证
```

## 📊 影响范围

### 受益的中断类型
1. **IOSUB Normal 汇聚源中断**：index 在 [0,9] ∪ [15,50] 范围内
2. **有直接路由的中断**：`to_ap`, `to_accel`, `to_io`, `to_other_die` 任一为 1
3. **双重路由中断**：既通过 merge 路由又有直接路由的中断

### 典型受益中断示例
- `iosub_pmbus0_intr` (如果有 to_ap=1)
- `iosub_dma_ch0_intr` (如果有 to_accel=1)
- `iosub_mem_ist_intr` (如果有 to_io=1)

## 🔧 技术特点

### 1. 智能检测
- 自动识别源中断是否有直接路由
- 只对有直接路由的中断进行双重处理
- 避免不必要的预期注册

### 2. 完整覆盖
- Merge 路由：通过 `iosub_normal_intr` 到 SCP/MCP
- 直接路由：源中断直接到 AP/ACCEL/IO/OTHER_DIE
- 状态同步：两种路由的状态都得到正确更新

### 3. 向后兼容
- 不影响现有的单一路由中断
- 不影响纯 merge 中断（无直接路由）
- 保持现有的测试框架结构

## 📝 修改文件清单

### 核心修改
1. **`seq/int_lightweight_sequence.sv`**
   - `test_merge_source` 函数：添加双重预期逻辑
   - `test_multiple_merge_sources` 函数：添加多源双重预期逻辑

### 新增文档
2. **`docs/dual_expectation_fix_summary.md`**：本修复总结文档

## 🧪 验证建议

### 测试场景
1. **单源双重路由测试**：激励一个既属于汇聚源又有直接路由的中断
2. **多源双重路由测试**：同时激励多个有直接路由的汇聚源中断
3. **Mask 功能测试**：验证 mask 对双重路由的影响

### 预期结果
- 所有相关目的地都应该收到中断响应
- Mask 功能应该正确影响两种路由
- 状态寄存器应该正确反映所有中断的状态

## 🏆 结论

这次修复解决了 merge 中断处理中的一个重要遗漏，确保了对既有汇聚路由又有直接路由的中断进行完整的验证。修复后的系统能够：

1. **完整预期**：同时预期 merge 路由和直接路由的响应
2. **准确检测**：等待所有相关路由的中断检测
3. **正确状态**：更新所有相关中断的状态寄存器
4. **智能处理**：只对有直接路由的中断进行双重处理

这确保了验证环境能够准确模拟和验证硬件的实际行为，提高了测试的完整性和可靠性。

---
*修复完成时间: 2025-08-05*  
*修复类型: 关键逻辑修复*  
*影响等级: 高 - 影响 merge 中断验证的完整性*
