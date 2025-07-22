# 通用中断调试功能使用示例

## 场景：UNEXPECTED interrupt 错误调试

假设您遇到以下错误：
```
UVM_ERROR: Detected an UNEXPECTED interrupt: 'some_interrupt' was routed to 'AP'. Current expected queue size: 0
```

## 调试步骤

### 1. 设置适当的 Verbosity 级别

```bash
# 获取基本调试信息
make test TEST=your_test UVM_VERBOSITY=UVM_MEDIUM

# 获取详细的路由验证信息
make test TEST=your_test UVM_VERBOSITY=UVM_HIGH
```

### 2. 查看日志中的关键信息

#### 2.1 中断配置信息（测试开始时）
```
🔍 === INTERRUPT CONFIGURATION SUMMARY ===
Total interrupts in map: 150
Interrupt distribution by group:
  - IOSUB: 65 interrupts
  - USB: 8 interrupts
  - SCP: 12 interrupts
  ...
Monitor will track all configured interrupt destinations
🔍 === END INTERRUPT CONFIGURATION SUMMARY ===
```

#### 2.2 激励生成信息
```
=== DRIVER STIMULUS GENERATION ===
Driving interrupt stimulus: some_interrupt
  - Group: IOSUB
  - Index: 5
  - Trigger: LEVEL
  - Polarity: ACTIVE_HIGH
  - Stimulus Type: STIMULUS_ASSERT
  - RTL Source Path: top_tb.dut.some_interrupt_src
Expected destinations for this interrupt:
  ✅ AP: top_tb.dut.some_interrupt_to_ap
✅ Stimulus generation completed for: some_interrupt
```

#### 2.3 中断检测信息
```
Starting monitor for interrupt 'some_interrupt' -> 'AP' at path: top_tb.dut.some_interrupt_to_ap
INTERRUPT DETECTED [1]: 'some_interrupt' -> 'AP' signal went HIGH at path: top_tb.dut.some_interrupt_to_ap
```

#### 2.4 路由验证信息（UVM_HIGH）
```
🔍 === INTERRUPT ROUTING DEBUG: some_interrupt ===
Interrupt: some_interrupt detected at destination: AP
Source signal value: top_tb.dut.some_interrupt_src = 1
AP destination signal: top_tb.dut.some_interrupt_to_ap = 1
✅ Routing valid: some_interrupt correctly routed to AP
🔍 === END ROUTING DEBUG: some_interrupt ===
```

#### 2.5 Scoreboard 处理信息
```
=== SCOREBOARD INTERRUPT PROCESSING ===
Received interrupt transaction: some_interrupt@AP
  - Interrupt Name: some_interrupt
  - Group: IOSUB
  - Index: 5
  - Destination: AP
  - Trigger: LEVEL
  - Polarity: ACTIVE_HIGH
Current expected queue size: 0
Expected interrupts queue is EMPTY
Searching for match: some_interrupt@AP
❌ NO MATCH FOUND - This is an UNEXPECTED interrupt!
```

#### 2.6 详细调试分析
```
=== DEBUGGING INFORMATION ===
Expected key format: some_interrupt@AP
Interrupt routing configuration for some_interrupt:
  - to_ap: 1, to_scp: 0, to_mcp: 0
  - to_imu: 0, to_io: 0, to_other_die: 0
Expected interrupts queue is EMPTY - no interrupts were registered!
This suggests the test sequence did not register any expected interrupts.

🔍 === UNEXPECTED INTERRUPT ANALYSIS: some_interrupt ===
No similar interrupt patterns found for some_interrupt
This suggests the interrupt was not expected at all
🔍 === END ANALYSIS: some_interrupt ===
```

## 问题诊断

根据上述日志信息，可以得出以下结论：

### 情况1：期望未注册
**症状**：`Expected interrupts queue is EMPTY`
**原因**：测试序列没有调用 `add_expected()` 注册期望中断
**解决**：在触发中断前添加期望注册

```systemverilog
// 在序列中添加
add_expected(interrupt_info);  // 注册期望
// 然后触发中断
stim_item = int_stimulus_item::create_stimulus(interrupt_info, STIMULUS_ASSERT);
start_item(stim_item);
finish_item(stim_item);
```

### 情况2：目标不匹配
**症状**：队列中有期望但格式不匹配
**原因**：期望的目标与实际检测的目标不一致
**解决**：检查中断配置和期望注册的目标

### 情况3：配置错误
**症状**：`🚨 ROUTING ERROR` 或路由验证失败
**原因**：中断映射配置与实际硬件行为不符
**解决**：检查 `int_map_entries.svh` 中的配置

## 最佳实践

1. **始终先注册期望再触发中断**
2. **使用 UVM_MEDIUM 获取基本调试信息**
3. **使用 UVM_HIGH 获取详细的路由验证**
4. **关注 🔍、✅、❌、🚨 等标识符快速定位问题**
5. **检查期望队列状态确认是否正确注册**

## 常见问题解决

| 错误症状 | 可能原因 | 解决方法 |
|---------|---------|---------|
| Expected queue is EMPTY | 未注册期望 | 添加 add_expected() 调用 |
| Similar patterns found | 目标不匹配 | 检查期望的目标配置 |
| ROUTING ERROR | 配置错误 | 检查中断映射文件 |
| Signal read failure | RTL路径错误 | 验证RTL路径正确性 |
