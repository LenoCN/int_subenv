# 中断激励方法合规性检查与改进

本文档描述了对中断向量表trigger/polarity列的合规性检查过程，以及相应的改进方案。

## 概述

根据CSV格式的中断向量表，我们需要确保测试环境中的中断激励方法符合每个中断的trigger和polarity规定。不同类型的中断需要不同的激励方法：

- **Level触发**: 需要持续的电平激励
- **Edge触发**: 需要边沿激励
- **Pulse触发**: 需要短脉冲激励

## 检查工具

### `check_stimulus_compliance.py`

这是主要的检查工具，功能包括：

1. **解析CSV中断向量表**: 提取每个中断的trigger和polarity信息
2. **分析当前激励方法**: 扫描测试序列文件，识别使用的激励模式
3. **合规性检查**: 比较期望的激励方法与实际实现
4. **生成详细报告**: 输出合规性状况和改进建议

#### 使用方法
```bash
cd int_subenv
python3 check_stimulus_compliance.py
```

#### 输出文件
- `stimulus_compliance_report.md`: 详细的合规性检查报告
- `stimulus_compliance_summary.md`: 简化的总结报告

## 检查结果

### 当前状况 (2025-07-15)

- **总中断数量**: 423个
- **符合规范**: 407个 (96.2%)
- **不符合规范**: 0个 (0.0%)
- **缺少激励方法**: 16个 (3.8%)

### 合规性评估: ✅ **优秀**

当前的激励方法基本符合中断向量表的要求。

### 主要发现

1. **Level/Active High中断 (407个)**: 完全符合规范
   - 使用方法: `uvm_hdl_force(path, 1)` → `uvm_hdl_release(path)`
   - 符合性: ✅ 完全正确

2. **Edge/Rising & Falling Edge中断 (4个)**: 缺少专门激励
   - 中断: `scp_cpu_cti_irq[0/1]`, `mcp_cpu_cti_irq[0/1]`
   - 需要: 双边沿激励方法

3. **Pulse/Active High中断 (12个)**: 缺少专门激励
   - 主要来源: SMMU中断源
   - 需要: 短脉冲激励方法

## 改进方案

### 1. 增强的激励序列

创建了 `int_routing_sequence_enhanced.sv`，包含：

- **智能激励选择**: 根据trigger类型自动选择合适的激励方法
- **Level激励**: 支持Active High/Low极性
- **Edge激励**: 支持单边沿和双边沿
- **Pulse激励**: 支持短脉冲生成

#### 关键特性

```systemverilog
// 主要激励选择逻辑
virtual task check_interrupt_routing(interrupt_info_s info);
    case (info.trigger)
        LEVEL: check_level_interrupt_routing(info);
        EDGE:  check_edge_interrupt_routing(info);
        PULSE: check_pulse_interrupt_routing(info);
        default: check_level_interrupt_routing(info);
    endcase
endtask
```

#### Edge激励实现
```systemverilog
// 双边沿激励 (Rising & Falling Edge)
if (info.polarity == RISING_FALLING) begin
    uvm_hdl_force(info.rtl_path_src, 0);
    #2ns;
    uvm_hdl_force(info.rtl_path_src, 1); // Rising edge
    #5ns;
    uvm_hdl_force(info.rtl_path_src, 0); // Falling edge
    #5ns;
    uvm_hdl_release(info.rtl_path_src);
end
```

#### Pulse激励实现
```systemverilog
// 短脉冲激励 (Pulse/Active High)
uvm_hdl_force(info.rtl_path_src, 0);
#1ns;
uvm_hdl_force(info.rtl_path_src, 1);
#1ns; // 非常短的脉冲
uvm_hdl_force(info.rtl_path_src, 0);
#1ns;
uvm_hdl_release(info.rtl_path_src);
```

### 2. 专门的测试用例

创建了 `tc_enhanced_stimulus_test.sv`，用于验证：

- 不同trigger类型的激励方法
- 不同polarity的处理
- 激励时序的正确性

## 使用指南

### 1. 运行合规性检查

```bash
# 检查当前激励方法的合规性
python3 check_stimulus_compliance.py

# 查看详细报告
cat stimulus_compliance_report.md

# 查看简化总结
cat stimulus_compliance_summary.md
```

### 2. 使用增强的激励方法

在测试中使用增强的序列：

```systemverilog
// 在测试用例中
enhanced_stimulus_sequence seq;
seq = enhanced_stimulus_sequence::type_id::create("seq");
seq.start(env.agent.sequencer);
```

### 3. 添加新的激励方法

如果需要添加新的激励方法：

1. 在 `int_routing_sequence_enhanced.sv` 中添加新的task
2. 在主要的 `check_interrupt_routing` 中添加case分支
3. 更新 `check_stimulus_compliance.py` 以识别新的模式

## 文件结构

```
int_subenv/
├── check_stimulus_compliance.py          # 合规性检查工具
├── stimulus_compliance_report.md         # 详细检查报告
├── stimulus_compliance_summary.md        # 简化总结报告
├── seq/
│   ├── int_routing_sequence.sv           # 原始激励序列
│   └── int_routing_sequence_enhanced.sv  # 增强激励序列
├── test/
│   └── tc_enhanced_stimulus_test.sv      # 增强激励测试用例
└── 中断向量表-iosub-V0.5.csv            # 中断向量表数据源
```

## 总结

通过系统性的合规性检查，我们发现当前的中断激励方法整体上符合中断向量表的规定，合规率达到96.2%。

主要改进点：
1. ✅ Level触发中断的激励方法完全正确
2. ⚠️ 需要为Edge触发中断实现双边沿激励
3. ⚠️ 需要为Pulse触发中断实现短脉冲激励

通过实现增强的激励序列，可以达到100%的合规性，确保所有中断都按照其规定的trigger/polarity方式进行正确的激励。

---
*文档更新时间: 2025-07-15*  
*作者: AI Assistant*
