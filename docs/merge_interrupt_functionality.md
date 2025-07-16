# Merge中断功能说明

## 概述

在中断向量表中，存在一些特殊的merge中断，这些中断是由多个源中断合并（OR逻辑）而成的。本文档说明了merge中断的实现和测试方法。

## Merge中断列表

根据中断向量表，目前识别出以下5个merge中断：

1. **merge_pll_intr_lock** (index: 78)
   - 描述：所有的PLL lock中断在IOSUB内merge之后的中断
   - 目标：仅发送到SCP

2. **merge_pll_intr_unlock** (index: 79)
   - 描述：所有的PLL unlock中断在IOSUB内merge之后的中断
   - 目标：仅发送到SCP

3. **merge_pll_intr_frechangedone** (index: 80)
   - 描述：所有的PLL frechangedone中断在IOSUB内merge之后的中断
   - 目标：仅发送到SCP

4. **merge_pll_intr_frechange_tot_done** (index: 81)
   - 描述：所有的PLL frechange_tot_done中断在IOSUB内merge之后的中断
   - 目标：仅发送到SCP

5. **merge_pll_intr_intdocfrac_err** (index: 82)
   - 描述：所有的PLL intdocfrac_err中断在IOSUB内merge之后的中断
   - 目标：仅发送到SCP

## 源中断映射

### merge_pll_intr_lock 的源中断：
- iosub_pll_lock_intr
- accel_pll_lock_intr
- csub_pll_intr_lock (17-bit向量)
- psub_pll_lock_intr
- pcie1_pll_lock_intr
- d2d_pll_lock_intr
- ddr0_pll_lock_intr
- ddr1_pll_lock_intr
- ddr2_pll_lock_intr

### merge_pll_intr_unlock 的源中断：
- iosub_pll_unlock_intr
- accel_pll_unlock_intr
- csub_pll_intr_unlock (17-bit向量)
- psub_pll_unlock_intr
- pcie1_pll_unlock_intr
- d2d_pll_unlock_intr
- ddr0_pll_unlock_intr
- ddr1_pll_unlock_intr
- ddr2_pll_unlock_intr

### merge_pll_intr_frechangedone 的源中断：
- csub_pll_intr_frechangedone (17-bit向量)
- ddr0_pll_frechangedone_intr
- ddr1_pll_frechangedone_intr
- ddr2_pll_frechangedone_intr

### merge_pll_intr_frechange_tot_done 的源中断：
- csub_pll_intr_frechange_tot_done (17-bit向量)
- ddr0_pll_frechange_tot_done_intr
- ddr1_pll_frechange_tot_done_intr
- ddr2_pll_frechange_tot_done_intr

### merge_pll_intr_intdocfrac_err 的源中断：
- csub_pll_intr_intdocfrac_err (17-bit向量)
- ddr0_pll_intdocfrac_err_intr
- ddr1_pll_intdocfrac_err_intr
- ddr2_pll_intdocfrac_err_intr

## 实现细节

### 1. 数据结构扩展

在 `int_routing_model.sv` 中添加了以下函数：

- `get_merge_sources()`: 获取指定merge中断的所有源中断
- `is_merge_interrupt()`: 判断一个中断是否为merge中断
- `get_merge_interrupt_info()`: 根据名称获取merge中断信息

### 2. 测试逻辑扩展

在 `int_routing_sequence.sv` 中添加了merge中断的特殊处理：

- `check_merge_interrupt_routing()`: 专门处理merge中断的测试
- `test_merge_source_interrupt()`: 测试单个源中断
- `test_multiple_merge_sources()`: 测试多个源中断同时触发

### 3. 测试策略

对于merge中断，测试包括：

1. **单源测试**：逐个触发每个源中断，验证merge中断是否正确触发
2. **多源测试**：同时触发多个源中断，验证OR逻辑是否正确工作
3. **路由验证**：验证merge中断是否正确路由到预期目标（主要是SCP）

## 使用方法

### 运行标准中断路由测试（包含merge中断）：
```bash
make test TEST=tc_int_routing
```

### 运行专门的merge中断测试：
```bash
make test TEST=tc_merge_interrupt_test
```

## 注意事项

1. **RTL路径占位符**：当前所有RTL路径都是占位符，需要在获得实际RTL层次结构后更新
2. **CSUB向量中断**：CSUB的PLL中断是17-bit向量，需要在RTL中正确处理
3. **源中断路由**：源中断本身通常不路由到任何目标（to_ap=0, to_scp=0等），只有merge后的中断才路由到目标
4. **测试覆盖率**：确保所有源中断都有有效的RTL路径以进行完整测试

## 扩展性

如果将来需要添加新的merge中断：

1. 在 `get_merge_sources()` 函数中添加新的case分支
2. 在 `is_merge_interrupt()` 函数中添加新的中断名称
3. 确保CSV文件中正确定义了源中断和merge中断的关系
4. 更新本文档以反映新的merge中断

## 验证结果

通过Python测试脚本验证，merge逻辑已正确实现：

- ✅ 成功识别5个merge中断
- ✅ 正确映射所有源中断关系
- ✅ merge_pll_intr_lock: 9个源中断
- ✅ merge_pll_intr_unlock: 9个源中断
- ✅ merge_pll_intr_frechangedone: 4个源中断
- ✅ merge_pll_intr_frechange_tot_done: 4个源中断
- ✅ merge_pll_intr_intdocfrac_err: 4个源中断

## 调试建议

1. 使用 `UVM_HIGH` 详细级别查看每个源中断的测试过程
2. 检查scoreboard输出以确认期望的中断是否被正确检测
3. 验证RTL路径是否正确设置
4. 确认merge逻辑在RTL中正确实现（OR门逻辑）
5. 运行 `python3 test_merge_logic.py` 验证merge逻辑配置
