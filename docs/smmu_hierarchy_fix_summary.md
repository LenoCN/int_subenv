# SMMU Hierarchy Fix Summary

## 问题描述

在RTL路径生成过程中，SMMU的路径是错误的。SMMU wrapper的正确hierarchy应该是：
```
top_tb.multidie_top.DUT[0].u_str_top.u_iosub_top_wrap.u0_iosub_top_wrap_hd.u0_iosub_top_wrap_raw.u_iosub_bus_out_sub.u_smmu_iosub_top_wrap
```

但之前生成的路径缺少了`u_iosub_bus_out_sub.u_smmu_iosub_top_wrap`这一层。

## hierarchy_config各类信息的作用分析

### 1. base_hierarchy
定义基础层次结构路径，用于确定不同子系统的基础路径：
- `iosub_top`: IOSUB顶层路径
- `mcp_top`: MCP子系统路径  
- `scp_top`: SCP子系统路径
- `iosub_int_sub`: IOSUB内部中断子系统路径
- `smmu_wrapper`: SMMU wrapper路径（新增）

### 2. signal_mappings
定义信号名称映射关系，用于将逻辑信号名映射到实际RTL信号名。

### 3. signal_widths
定义各信号的位宽信息，用于验证索引范围和生成正确的路径。

### 4. interrupt_groups
定义中断组配置，包括：
- `base_signal`: 基础信号名
- `special_signals`: 特殊信号映射
- `hierarchy`: 指定使用的层次结构（新增功能）

### 5. destination_mappings
定义目标路径映射，用于监控路径生成，包含具体的hierarchy_path和信号信息。

### 6. hierarchy_selection_rules
定义层次选择规则，用于确定stimulus和monitor的层次：
- `stimulus_hierarchy`: 刺激信号的层次选择规则
- `monitor_hierarchy`: 监控信号的层次选择规则
- `group_to_iosub_signal_mapping`: 中断组到iosub边界信号的映射

## 修复方案

### 1. 配置文件修改 (config/hierarchy_config.json)

#### 添加SMMU wrapper基础层次路径：
```json
"base_hierarchy": {
  ...
  "smmu_wrapper": "top_tb.multidie_top.DUT[0].u_str_top.u_iosub_top_wrap.u0_iosub_top_wrap_hd.u0_iosub_top_wrap_raw.u_iosub_bus_out_sub.u_smmu_iosub_top_wrap"
}
```

#### 更新SMMU中断组配置：
```json
"SMMU": {
  "description": "System Memory Management Unit interrupts",
  "hierarchy": "smmu_wrapper",
  "use_interrupt_name_as_signal": true,
  "special_signals": {
    "pulse": "iosub_smmu_pulse_intr",
    "ras": "smmu_ras_intr"
  }
}
```

关键变化：
- 移除了`base_signal`字段
- 添加了`use_interrupt_name_as_signal: true`，表示直接使用中断名称作为信号名

### 2. 路径生成逻辑修改 (tools/generate_signal_paths.py)

在`generate_source_path`方法中添加对中断组特定层次结构和信号名的支持：

```python
# Check if group has a specific hierarchy override
group_hierarchy = group_config.get('hierarchy', '')
if group_hierarchy and group_hierarchy in self.base_hierarchy:
    base_path = self.base_hierarchy[group_hierarchy]

# Check if this group uses interrupt name as signal name directly
if group_config.get('use_interrupt_name_as_signal', False):
    return f"{base_path}.{interrupt_name}"
```

## 修复结果

### 修复前的SMMU路径：
```
top_tb.multidie_top.DUT[0].u_str_top.u_iosub_top_wrap.u0_iosub_top_wrap_hd.u0_iosub_top_wrap_raw.u_iosub_int_sub.iosub_smmu_level_intr[X]
```

问题：
1. 缺少SMMU wrapper层次：`u_iosub_bus_out_sub.u_smmu_iosub_top_wrap`
2. 使用了错误的信号名格式：`iosub_smmu_level_intr[X]`而不是实际的中断名称

### 修复后的SMMU路径：
```
top_tb.multidie_top.DUT[0].u_str_top.u_iosub_top_wrap.u0_iosub_top_wrap_hd.u0_iosub_top_wrap_raw.u_iosub_bus_out_sub.u_smmu_iosub_top_wrap.{interrupt_name}
```

其中`{interrupt_name}`直接使用Excel中的中断名称，例如：
- `intr_tcu_ups_event_q_irpt_s`
- `smmu_abnormal_intr`
- `smmu_normal_intr_ns`
等等

## 验证结果

- 成功更新了421个中断条目
- 所有18个SMMU中断的`rtl_path_src`都已正确更新
- 路径现在包含正确的SMMU wrapper层次结构：`u_iosub_bus_out_sub.u_smmu_iosub_top_wrap`
- 创建了备份文件`seq/int_map_entries.svh.backup`

## 配置版本更新

- 版本从1.1更新到1.2
- 更新日期：2025-07-22
- 变更记录：添加SMMU wrapper hierarchy支持

## 影响范围

此修复仅影响SMMU中断组的源路径生成，不影响其他中断组的路径生成逻辑。目标路径（destination paths）保持不变，因为它们使用的是iosub_int_sub边界信号。
