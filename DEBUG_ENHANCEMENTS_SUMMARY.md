# 中断验证调试增强总结

## 问题描述
遇到UVM错误：中断被检测到但scoreboard中没有对应的期望中断，导致UNEXPECTED interrupt错误。

## 解决方案：增加通用的详细调试信息

### 1. Monitor (int_monitor.sv) 增强

#### 1.1 信号监控增强
- **monitor_single_path**: 添加了检测计数器和详细的信号状态日志
- **wait_for_signal_edge**: 增加了信号转换跟踪和更详细的超时信息
- **send_transaction**: 添加了完整的中断事务创建过程日志

#### 1.2 通用中断调试功能
- **debug_interrupt_routing**: 通用的中断路由验证函数
- **debug_interrupt_configuration**: 启动时显示中断配置统计信息

#### 1.3 新增调试信息
```systemverilog
// 信号监控日志
`uvm_info("Starting monitor for interrupt 'interrupt_name' -> 'destination'")
`uvm_info("INTERRUPT DETECTED [1]: 'interrupt_name' -> 'destination' signal went HIGH")
`uvm_info("Signal transition detected: path changed from 0 to 1")

// 路由验证调试
`uvm_info("🔍 === INTERRUPT ROUTING DEBUG: interrupt_name ===")
`uvm_info("Source signal value: path = 1")
`uvm_info("✅ Routing valid: interrupt_name correctly routed to destination")
```

### 2. Scoreboard (int_scoreboard.sv) 增强

#### 2.1 中断处理过程详细日志
- **write**: 完整的中断处理流程日志，包括期望队列状态
- **add_expected**: 详细的期望中断添加过程日志

#### 2.2 通用中断分析功能
- **analyze_unexpected_interrupt**: 通用的意外中断分析函数

#### 2.3 新增调试信息
```systemverilog
// 处理过程日志
`uvm_info("=== SCOREBOARD INTERRUPT PROCESSING ===")
`uvm_info("Received interrupt transaction: interrupt_name@destination")
`uvm_info("Current expected queue size: 0")
`uvm_info("Expected interrupts queue is EMPTY")

// 通用分析
`uvm_info("🔍 === UNEXPECTED INTERRUPT ANALYSIS: interrupt_name ===")
`uvm_info("Interrupt routing configuration for interrupt_name:")
`uvm_info("This suggests the test sequence did not register any expected interrupts.")
```

### 3. Sequence (int_base_sequence.sv) 增强

#### 3.1 期望注册过程详细日志
- **add_expected**: 显示完整的期望中断注册过程，包括路由配置

#### 3.2 新增调试信息
```systemverilog
// 期望注册日志
`uvm_info("=== SEQUENCE ADDING EXPECTED INTERRUPT ===")
`uvm_info("Sequence 'sequence_name' adding expected interrupt: interrupt_name")
`uvm_info("Expected routing destinations:")
`uvm_info("  ✅ destination_name")
`uvm_info("✅ Expected interrupt 'interrupt_name' successfully registered")
```

### 4. Driver (int_driver.sv) 增强

#### 4.1 激励生成过程详细日志
- **drive_interrupt**: 显示完整的激励生成信息
- **drive_level_stimulus**: 详细的电平激励过程

#### 4.2 新增调试信息
```systemverilog
// 激励生成日志
`uvm_info("=== DRIVER STIMULUS GENERATION ===")
`uvm_info("Driving interrupt stimulus: interrupt_name")
`uvm_info("Expected destinations for this interrupt:")
`uvm_info("  ✅ destination: rtl_path")
`uvm_info("Forcing signal: path = 1")
```

## 使用方法

### 1. 运行调试测试
```bash
# 在现有测试中设置更高的verbosity获取详细调试信息
make test TEST=your_test UVM_VERBOSITY=UVM_MEDIUM

# 获取最详细的调试信息（包括路由验证）
make test TEST=your_test UVM_VERBOSITY=UVM_HIGH
```

### 2. 关键调试信息查找
在日志中查找以下关键标识：
- `🔍 === INTERRUPT ROUTING DEBUG` - 路由验证调试
- `🔍 === UNEXPECTED INTERRUPT ANALYSIS` - 意外中断分析
- `🚨 ROUTING ERROR` - 路由配置错误
- `❌ NO MATCH FOUND` - 匹配失败
- `✅ MATCH FOUND` - 匹配成功

### 3. 问题定位流程
1. **检查中断配置**: 查找 "INTERRUPT CONFIGURATION DEBUG"
2. **检查期望注册**: 查找 "SEQUENCE ADDING EXPECTED INTERRUPT"
3. **检查激励生成**: 查找 "DRIVER STIMULUS GENERATION"
4. **检查中断检测**: 查找 "INTERRUPT DETECTED"
5. **检查scoreboard处理**: 查找 "SCOREBOARD INTERRUPT PROCESSING"

## 预期效果

通过这些调试增强，您应该能够：
1. **精确定位问题根源**: 是配置错误、期望未注册、还是时序问题
2. **跟踪完整流程**: 从激励生成到中断检测到scoreboard验证
3. **快速识别异常**: 通过特殊标识快速找到问题点
4. **验证修复效果**: 确认问题解决后的正常流程

## 下一步建议

1. 运行增强后的测试，收集详细日志
2. 根据日志信息确定具体问题原因
3. 如果是期望未注册，检查测试序列
4. 如果是配置错误，检查中断映射文件
5. 如果是时序问题，调整timing配置
