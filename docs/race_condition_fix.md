# 中断事件竞争条件修复

## 问题描述

在原始实现中，`int_monitor.sv` 中的 `trigger()` 可能会早于 `int_event_manager.sv` 中的 `wait_trigger()` 执行，导致无法等待到 trigger 的 event。这是一个典型的竞争条件（race condition）问题。

### 问题场景

1. **正常情况**：
   ```
   sequence: wait_trigger() 开始等待
   monitor:  检测到中断，调用 trigger()
   sequence: wait_trigger() 收到事件，继续执行
   ```

2. **竞争条件**：
   ```
   monitor:  检测到中断，调用 trigger()  ← 事件被触发
   sequence: wait_trigger() 开始等待      ← 但事件已经错过了
   sequence: 永远等待，直到超时
   ```

## 解决方案

### 核心思路

使用事件状态跟踪机制，在 `int_event_manager` 中维护一个 `triggered_events` 关联数组来记录哪些事件已经被触发。

### 实现细节

#### 1. 在 `int_event_manager.sv` 中添加状态跟踪

```systemverilog
// Track events that have been triggered to handle race conditions
// Key: event_key, Value: 1 if triggered
bit triggered_events[string];

// Mark an event as triggered (called by monitor to handle race conditions)
function void mark_event_triggered(string event_key);
    triggered_events[event_key] = 1;
    `uvm_info("INT_EVENT_MANAGER", $sformatf("Marked event as triggered: %s", event_key), UVM_DEBUG)
endfunction
```

#### 2. 修改等待逻辑

在 `wait_for_interrupt_detection()` 中，在调用 `wait_trigger()` 之前检查事件是否已经被触发：

```systemverilog
// Check if event was already triggered to avoid race condition
if (triggered_events.exists(event_keys[i]) && triggered_events[event_keys[i]]) begin
    `uvm_info("INT_EVENT_MANAGER", $sformatf("Event already triggered for %s (race condition avoided)",
              event_keys[i]), UVM_HIGH)
    // Clear the triggered flag for this event
    triggered_events[event_keys[i]] = 0;
    continue; // Event already triggered, skip waiting
end
```

#### 3. 修改 monitor 触发逻辑

在 `int_monitor.sv` 的 `send_transaction()` 中，先标记事件状态，再触发事件：

```systemverilog
// Mark event as triggered first to handle race condition
if (event_manager != null) begin
    event_manager.mark_event_triggered(event_key);
end

// Then trigger the event
int_event.trigger();
```

#### 4. 配置共享

在 `int_subenv.sv` 中确保 monitor 能够访问 event_manager：

```systemverilog
// Also set event_manager specifically for monitor to handle race conditions
uvm_config_db#(int_event_manager)::set(this, "m_monitor", "event_manager", m_event_manager);
```

## 修复效果

### 优势

1. **消除竞争条件**：无论 trigger 和 wait_trigger 的执行顺序如何，都能正确处理
2. **保持兼容性**：不影响现有的正常工作流程
3. **性能友好**：只在检测到竞争条件时才进行额外处理
4. **调试友好**：添加了详细的日志信息

### 工作流程

1. **Monitor 检测到中断**：
   - 调用 `event_manager.mark_event_triggered(event_key)`
   - 调用 `int_event.trigger()`

2. **Sequence 等待中断**：
   - 检查 `triggered_events[event_key]` 是否已设置
   - 如果已设置，直接继续（避免竞争条件）
   - 如果未设置，正常调用 `wait_trigger()`

3. **清理机制**：
   - 事件被消费后，清除 `triggered_events` 标志
   - 为下次使用做准备

## 测试验证

创建了专门的测试用例 `test_race_condition_fix.sv` 来验证修复效果：

1. **正常情况测试**：验证原有功能不受影响
2. **竞争条件测试**：验证 trigger 早于 wait_trigger 的情况
3. **多事件竞争测试**：验证多个目标的复杂场景

## 使用注意事项

1. 确保 `int_subenv` 正确配置了 event_manager 的共享
2. 在自定义 monitor 中也需要类似的处理
3. 事件标志会在消费后自动清除，无需手动管理
