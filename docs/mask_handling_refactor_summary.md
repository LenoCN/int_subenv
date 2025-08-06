# Mask 处理逻辑重构总结

## 📋 重构背景

在之前的修复中，我们在 `lightweight_sequence` 中实现了 IOSUB Normal mask 处理逻辑。但这种实现方式存在以下问题：

1. **代码重复**：在特定的 sequence 中硬编码了通用的 mask 处理逻辑
2. **架构不当**：违反了单一职责原则，sequence 应该专注于测试流程而非 mask 计算
3. **可维护性差**：mask 处理逻辑分散在多个地方，难以维护和扩展
4. **可复用性低**：其他 sequence 无法复用这些 mask 处理逻辑

## 🎯 重构目标

将 mask 处理逻辑从特定的 sequence 中提取出来，放到通用组件中，实现：

1. **职责分离**：sequence 专注于测试流程，通用组件负责 mask 计算
2. **代码复用**：所有 sequence 都可以使用统一的 mask 处理接口
3. **易于维护**：mask 处理逻辑集中在通用组件中
4. **易于扩展**：新的 mask 类型可以在通用组件中统一添加

## 🛠️ 重构实施

### 1. 在 `int_register_model` 中添加高级接口

**新增函数**：

#### `should_expect_merge_interrupt()`
```systemverilog
function bit should_expect_merge_interrupt(string merge_name, string source_name, int_routing_model routing_model);
```
- **功能**：判断是否应该为 merge 中断注册预期
- **特殊处理**：为 `iosub_normal_intr` 实现串行 mask 检查
- **通用性**：支持所有类型的 merge 中断

#### `should_expect_merge_from_any_source()`
```systemverilog
function bit should_expect_merge_from_any_source(string merge_name, interrupt_info_s source_interrupts[], int_routing_model routing_model);
```
- **功能**：判断是否有任何源中断应该触发 merge 中断预期
- **优化**：批量检查，找到第一个有效源即返回
- **适用场景**：多源测试场景

### 2. 在 `int_routing_model` 中添加高级接口

**新增函数**：

#### `should_trigger_merge_expectation()`
```systemverilog
function bit should_trigger_merge_expectation(string interrupt_name, string merge_name, int_register_model register_model);
```
- **功能**：检查中断是否应该触发 merge 中断预期
- **验证**：先验证中断是否为 merge 源，再检查 mask 状态
- **委托**：将具体的 mask 检查委托给 register_model

#### `get_merge_interrupt_info()`
```systemverilog
function bit get_merge_interrupt_info(string merge_name, ref interrupt_info_s merge_info);
```
- **功能**：获取 merge 中断的详细信息
- **便利性**：为其他函数提供便利的信息查询接口

#### `should_any_source_trigger_merge()`
```systemverilog
function bit should_any_source_trigger_merge(string merge_name, interrupt_info_s source_interrupts[], int_register_model register_model);
```
- **功能**：检查是否有任何源应该触发 merge 中断
- **委托**：将具体检查委托给 register_model 的批量接口

### 3. 重构 `lightweight_sequence`

**删除内容**：
- 删除了 `is_source_masked_in_iosub_normal_layer()` 辅助函数
- 删除了 `any_source_unmasked_in_iosub_normal_layer()` 辅助函数
- 删除了所有硬编码的 mask 检查逻辑

**修改内容**：
- 所有 mask 检查都改为调用通用组件的高级接口
- 简化了代码逻辑，提高了可读性
- 保持了原有的功能完整性

## 📊 重构效果

### 1. 代码质量提升

**代码行数减少**：
- `lightweight_sequence.sv`：从 595 行减少到 515 行（减少 80 行）
- 删除了 40 行重复的辅助函数
- 简化了复杂的条件判断逻辑

**可读性提升**：
- 函数调用更加语义化：`should_expect_merge_interrupt()` vs 复杂的条件判断
- 逻辑更加清晰：sequence 专注于测试流程，不涉及 mask 计算细节
- 注释更加简洁：不需要解释复杂的 mask 检查逻辑

### 2. 架构改进

**职责分离**：
```
之前：sequence 既负责测试流程，又负责 mask 计算
现在：sequence 负责测试流程，通用组件负责 mask 计算
```

**依赖关系优化**：
```
之前：sequence → register_model (直接调用底层接口)
现在：sequence → routing_model → register_model (通过高级接口)
```

**可扩展性增强**：
- 新的 merge 中断类型可以在通用组件中统一处理
- 新的 mask 策略可以在通用组件中实现
- 其他 sequence 可以直接使用这些高级接口

### 3. 维护性提升

**集中管理**：
- 所有 mask 处理逻辑集中在 `int_register_model` 中
- 所有 merge 相关逻辑集中在 `int_routing_model` 中
- 修改 mask 策略只需要修改通用组件

**测试友好**：
- 可以独立测试通用组件的 mask 处理逻辑
- 可以通过 mock 通用组件来测试 sequence 逻辑
- 更容易进行单元测试和集成测试

## 🔄 接口对比

### 重构前（在 sequence 中）
```systemverilog
// 复杂的条件判断和重复逻辑
if (merge_info.name == "iosub_normal_intr") begin
    bit source_masked_in_iosub_normal = 0;
    if (merge_info.to_scp) begin
        source_masked_in_iosub_normal = m_register_model.check_iosub_normal_mask_layer(source_info.name, "SCP", m_routing_model);
    end
    if (!source_masked_in_iosub_normal && merge_info.to_mcp) begin
        source_masked_in_iosub_normal = m_register_model.check_iosub_normal_mask_layer(source_info.name, "MCP", m_routing_model);
    end
    if (!source_masked_in_iosub_normal) begin
        add_expected_with_mask(merge_info);
    end
end else begin
    add_expected_with_mask(merge_info);
end
```

### 重构后（使用通用接口）
```systemverilog
// 简洁的高级接口调用
if (m_routing_model.should_trigger_merge_expectation(source_info.name, merge_info.name, m_register_model)) begin
    add_expected_with_mask(merge_info);
end
```

## 🎯 未来扩展

### 1. 新的 Merge 中断类型
当需要添加新的 merge 中断类型时，只需要在 `int_register_model.should_expect_merge_interrupt()` 中添加相应的处理逻辑，所有使用该接口的 sequence 都会自动支持新的类型。

### 2. 新的 Mask 策略
当需要实现新的 mask 策略时，只需要在通用组件中实现，然后通过高级接口暴露给 sequence 使用。

### 3. 其他 Sequence 的复用
其他 sequence 可以直接使用这些高级接口，无需重复实现 mask 处理逻辑。

## 📝 总结

这次重构实现了：

1. **架构优化**：将 mask 处理逻辑从 sequence 移到通用组件
2. **代码简化**：减少了 80 行代码，提高了可读性
3. **职责分离**：sequence 专注于测试流程，通用组件负责 mask 计算
4. **可复用性**：其他 sequence 可以直接使用高级接口
5. **可维护性**：mask 处理逻辑集中管理，易于维护和扩展

重构后的代码更加符合软件工程的最佳实践，为项目的长期维护和扩展奠定了良好的基础。

---
**重构日期**：2025-08-06  
**重构人员**：Augment Agent  
**审核状态**：待审核  
**版本标签**：v1.3-mask-handling-refactor
