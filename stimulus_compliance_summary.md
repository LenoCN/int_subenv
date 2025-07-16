# 中断激励方法合规性检查总结

## 检查结果概览

根据对CSV格式中断向量表的trigger/polarity列分析，当前激励方法的合规性状况如下：

### 统计数据
- **总中断数量**: 423个
- **符合规范**: 407个 (96.2%)
- **不符合规范**: 0个 (0.0%)
- **缺少激励方法**: 16个 (3.8%)

### 合规性评估: ✅ **优秀**

当前的激励方法基本符合中断向量表的要求，合规率达到96.2%。

## 当前激励方法分析

### 符合规范的激励方法

**Level/Active High中断 (407个)**
- 当前使用: `uvm_hdl_force(path, 1)` → `uvm_hdl_release(path)`
- 符合性: ✅ **完全符合**
- 说明: 这是Level触发、Active High极性中断的标准激励方法

### 需要改进的激励方法

**1. Edge/Rising & Falling Edge中断 (4个)**
- 中断列表:
  - `scp_cpu_cti_irq[0]` (SCP)
  - `scp_cpu_cti_irq[1]` (SCP) 
  - `mcp_cpu_cti_irq[0]` (MCP)
  - `mcp_cpu_cti_irq[1]` (MCP)
- 当前状态: ❌ **缺少激励方法**
- 需要实现: 双边沿激励
- 建议实现:
  ```systemverilog
  uvm_hdl_force(info.rtl_path_src, 1);
  #5ns;
  uvm_hdl_force(info.rtl_path_src, 0);
  #5ns;
  uvm_hdl_release(info.rtl_path_src);
  ```

**2. Pulse/Active High中断 (12个)**
- 主要来源: SMMU中断源 (12个)
- 当前状态: ❌ **缺少激励方法**
- 需要实现: 脉冲激励
- 建议实现:
  ```systemverilog
  uvm_hdl_force(info.rtl_path_src, 1);
  #1ns; // 短脉冲
  uvm_hdl_force(info.rtl_path_src, 0);
  #1ns;
  uvm_hdl_release(info.rtl_path_src);
  ```

## 关键发现

### 1. 主要激励方法正确
当前使用的 `force(1) → release` 方法完全符合Level/Active High中断的要求，这覆盖了96.2%的中断。

### 2. 特殊中断类型需要专门处理
- **CTI中断**: 需要双边沿激励，因为它们对上升沿和下降沿都敏感
- **SMMU脉冲中断**: 需要短脉冲激励，而不是持续的电平激励

### 3. 当前实现的优势
- 通用性好: 一种激励方法覆盖了绝大多数中断
- 实现简单: 代码逻辑清晰，易于维护
- 可靠性高: Level触发方式不容易受到时序影响

## 改进建议

### 优先级1: 实现Edge触发中断激励
```systemverilog
// 在int_routing_sequence.sv中添加
virtual task check_edge_interrupt_routing(interrupt_info_s info);
    if (info.polarity == RISING_FALLING) begin
        // 双边沿激励
        uvm_hdl_force(info.rtl_path_src, 1);
        #5ns;
        uvm_hdl_force(info.rtl_path_src, 0);
        #5ns;
        uvm_hdl_release(info.rtl_path_src);
    end else begin
        // 单边沿激励
        uvm_hdl_force(info.rtl_path_src, 1);
        #1ns;
        uvm_hdl_force(info.rtl_path_src, 0);
        #1ns;
        uvm_hdl_release(info.rtl_path_src);
    end
endtask
```

### 优先级2: 实现Pulse触发中断激励
```systemverilog
// 在int_routing_sequence.sv中添加
virtual task check_pulse_interrupt_routing(interrupt_info_s info);
    // 短脉冲激励
    uvm_hdl_force(info.rtl_path_src, 1);
    #1ns; // 非常短的脉冲
    uvm_hdl_force(info.rtl_path_src, 0);
    #1ns;
    uvm_hdl_release(info.rtl_path_src);
endtask
```

### 优先级3: 更新主检查函数
```systemverilog
virtual task check_interrupt_routing(interrupt_info_s info);
    case (info.trigger)
        LEVEL: check_single_interrupt_routing(info);
        EDGE:  check_edge_interrupt_routing(info);
        PULSE: check_pulse_interrupt_routing(info);
        default: check_single_interrupt_routing(info);
    endcase
endtask
```

## 结论

当前的中断激励方法整体上**符合中断向量表的规定**，合规率达到96.2%。主要使用的Level/Active High激励方法完全正确。

需要改进的仅是16个特殊类型的中断（Edge和Pulse触发），这些中断需要专门的激励方法来正确模拟其触发特性。

建议按照上述优先级实现相应的激励方法，以达到100%的合规性。

---
*报告生成时间: 2025-07-15*  
*检查工具: check_stimulus_compliance.py*
