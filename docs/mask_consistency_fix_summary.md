# Mask 一致性修复总结

## 问题描述

在 `lightweight_sequence` 执行过程中发现了一个重要的不一致性问题：

- **`add_expected_with_mask`** 使用了 mask 信息，只为未被 mask 的目标注册期望
- **`wait_for_interrupt_detection`** 没有使用 mask 信息，等待所有原始路由目标的事件

这种不一致会导致验证行为不正确，因为期望注册和事件等待使用了不同的逻辑。

## 根本原因分析

### 原始实现问题

1. **`add_expected_with_mask` (正确的实现)**：
   ```systemverilog
   // 在 int_base_sequence.sv 中
   m_routing_model.get_expected_destinations_with_mask(info.name, expected_destinations, m_register_model);
   // 只为未被 mask 的目标注册期望
   ```

2. **`wait_for_interrupt_detection` (有问题的实现)**：
   ```systemverilog
   // 在 int_event_manager.sv 中 - 原始版本
   if (info.to_ap) begin
       event_keys.push_back($sformatf("%s@%s", info.name, "AP"));
   end
   // 直接基于 interrupt_info 结构体，忽略 mask 状态
   ```

### 不一致性影响

- 如果某个目标被 mask，`add_expected_with_mask` 不会为其注册期望
- 但 `wait_for_interrupt_detection` 仍然会等待该目标的事件
- 这可能导致超时或验证失败

## 解决方案

### 1. 在 `int_base_sequence.sv` 中实现 mask 感知的等待函数

参考 `add_expected_with_mask` 的实现模式，新增 `wait_for_interrupt_detection_with_mask` 函数：

```systemverilog
task wait_for_interrupt_detection_with_mask(interrupt_info_s info, int timeout_ns = -1);
    string expected_destinations[$];
    interrupt_info_s masked_info;

    // 使用与 add_expected_with_mask 完全相同的逻辑
    m_routing_model.get_expected_destinations_with_mask(info.name, expected_destinations, m_register_model);

    if (expected_destinations.size() == 0) begin
        // 完全被 mask，无需等待
        return;
    end

    // 创建只包含未被 mask 目标的 interrupt_info
    masked_info = info;
    // 清除所有目标，然后只设置未被 mask 的目标
    // ... 设置逻辑与 add_expected_with_mask 完全一致

    // 使用原始等待函数等待修改后的 interrupt_info
    wait_for_interrupt_detection(masked_info, timeout_ns);
endtask
```

### 2. 修改 `int_lightweight_sequence.sv`

将所有 `wait_for_interrupt_detection` 调用替换为 `wait_for_interrupt_detection_with_mask`：

```systemverilog
// 原来的调用
wait_for_interrupt_detection(info);

// 修改为
wait_for_interrupt_detection_with_mask(info);
```

### 3. 向后兼容性保证

- 保留原始的 `wait_for_interrupt_detection` 函数，确保现有代码仍然可用
- 新的 `wait_for_interrupt_detection_with_mask` 函数内部调用原始函数
- 不需要修改任何现有的测试用例或其他序列

## 修复验证

### 自动化验证脚本

创建了 `tools/verify_mask_consistency_fix.py` 来验证修复：

```bash
python3 tools/verify_mask_consistency_fix.py
```

### 验证结果

✅ **所有检查通过**：
- 模型引用正确添加
- mask 感知方法正确实现
- 一致性逻辑验证通过
- 向后兼容性保证

## 修复效果

### 1. 一致性保证
- `add_expected_with_mask` 和 `wait_for_interrupt_detection` 现在使用完全相同的 mask 逻辑
- 两个方法都通过 `get_expected_destinations_with_mask` 获取未被 mask 的目标

### 2. 正确的验证行为
- 只为未被 mask 的目标注册期望
- 只等待未被 mask 的目标的事件
- 避免了因 mask 不一致导致的超时或验证失败

### 3. 向后兼容性
- 如果模型引用未设置，自动回退到原始行为
- 现有测试用例无需修改
- 渐进式升级支持

## 影响范围

### 修改的文件
1. `seq/int_base_sequence.sv` - 新增 `wait_for_interrupt_detection_with_mask` 函数
2. `seq/int_lightweight_sequence.sv` - 使用新的 mask 感知等待函数
3. `tools/verify_mask_consistency_fix.py` - 新增验证脚本
4. `docs/mask_consistency_fix_summary.md` - 修复文档

### 不需要修改的文件
- 所有现有测试用例
- 所有现有序列
- 其他环境组件

## 测试建议

1. **回归测试**：运行现有的所有测试用例，确保没有破坏性变更
2. **Mask 测试**：专门测试各种 mask 配置下的中断行为
3. **边界测试**：测试所有目标都被 mask 的情况
4. **性能测试**：确保新逻辑不影响仿真性能

## 总结

这次修复解决了一个重要的架构不一致性问题，确保了中断验证环境中期望注册和事件等待使用相同的 mask 感知逻辑。修复保持了向后兼容性，提高了验证的准确性和可靠性。

---
**修复日期**: 2025-07-31  
**验证状态**: ✅ 通过  
**影响等级**: 中等 (架构改进，无破坏性变更)
