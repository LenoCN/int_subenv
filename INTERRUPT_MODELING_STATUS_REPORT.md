# 中断向量表Comment列分析与建模状态报告

## 执行摘要

本报告基于对中断向量表CSV文件comment列的详细分析，识别出35个包含特殊处理逻辑的中断信号，并评估了当前环境中的建模实现状态。

## 分析结果概览

### 特殊处理中断分类统计
- **Merge处理中断**: 26个
- **特殊路由处理中断**: 6个  
- **其他特殊处理中断**: 3个
- **总计**: 35个

### 建模状态统计
- **需要建模**: 4个 (11.4%)
- **部分建模**: 30个 (85.7%)
- **已完全建模**: 1个 (2.9%)

## 详细分析结果

### 1. Merge处理中断 (26个)

#### 已实现的Merge逻辑
当前环境中已经实现了**5个PLL相关的merge中断**：
- `merge_pll_intr_lock` - 合并所有PLL lock中断
- `merge_pll_intr_unlock` - 合并所有PLL unlock中断  
- `merge_pll_intr_frechangedone` - 合并所有PLL frechangedone中断
- `merge_pll_intr_frechange_tot_done` - 合并所有PLL frechange_tot_done中断
- `merge_pll_intr_intdocfrac_err` - 合并所有PLL intdocfrac_err中断

**实现位置**: `seq/int_routing_model.sv` 中的 `get_merge_sources()` 函数

#### 需要补充的Merge逻辑
以下21个中断的merge逻辑尚未实现：

**IOSUB相关merge**:
- `iosub_pmbus0_intr` → `iosub_normal_int` + 额外单独路由
- `iosub_pmbus1_intr` → `iosub_normal_int`
- `iosub_mem_ist_intr` → `iosub_normal_int`
- `iosub_dma_ch1_intr` → `iosub_normal_int`

**USB相关merge**:
- `usb0_apb1ton_intr` → `iosub_slv_err_intr`

**SMMU相关merge**:
- `smmu_cri_intr` → `iosub_ras_cri_intr`
- `smmu_eri_intr` → `iosub_ras_eri_intr`
- `smmu_fhi_intr` → `iosub_ras_fhi_intr`

**IODAP相关merge**:
- `iodap_chk_err_etf0` → `iosub_ras_fhi_intr`
- `iodap_chk_err_etf1` → `iosub_ras_fhi_intr`
- `iodap_etr_buf_intr` → `iosub_abnormal_0_intr`
- `iodap_catu_addrerr_intr` → `iosub_abnormal_0_intr`

### 2. 特殊路由处理中断 (6个)

#### 需要实现的路由逻辑

**可配置路由**:
- `iosub_uart1_intr` - 支持从4个UART选择送3个中断给IMU，选择可配置

**专用路由**:
- `iosub_uart0_intr` - 只送给N2
- `usb0_ctrl_xhci_intr` - 同步后直连SPI-C，无MASK寄存器

**分发路由**:
- `scp_ras_cri_intr` - 3bit RAS先送给IOSUB进行分发
- `mcp_ras_cri_intr` - 3bit RAS先送给IOSUB进行分发

**统一性路由**:
- `iosub_dma_comreg_intr` - 考虑MSCP统一性，也支持送给SCP

### 3. 信号处理逻辑 (2个)

#### 需要实现的信号处理

**脉冲到电平转换**:
- `iosub_slv_err_intr` - 原始脉冲中断，接到中断五件套变成电平输出

**信号同步**:
- `usb0_ctrl_xhci_intr` - 同步之后直连SPI-C

### 4. 配置逻辑 (2个)

#### 需要实现的配置功能

**路由选择配置**:
- `iosub_uart1_intr` - 需要配置寄存器控制路由选择

**安全属性配置**:
- `iosub_dfx_lte_intr` - GIS-33需求，可配安全属性

## 当前环境实现状态

### 已实现功能
1. **基础中断路由模型** (`seq/int_routing_model.sv`)
   - 中断信息数据结构
   - 基本路由配置
   - PLL merge中断逻辑

2. **中断测试框架** (`seq/int_routing_sequence.sv`)
   - merge中断测试逻辑
   - 单个中断测试逻辑
   - 源中断验证

3. **监控和验证** (`env/int_monitor.sv`)
   - 信号监控
   - 事务生成
   - 边沿检测

### 缺失功能

#### 1. 扩展Merge逻辑支持
- 需要在 `get_merge_sources()` 中添加21个新的merge关系
- 需要实现 `iosub_normal_int`, `iosub_slv_err_intr`, `iosub_abnormal_0_intr` 等目标信号的merge逻辑

#### 2. 可配置路由矩阵
- UART中断的可配置路由选择
- 配置寄存器接口
- 动态路由切换逻辑

#### 3. 信号处理模块
- 脉冲到电平转换器
- 时钟域同步器
- 边沿检测和锁存器

#### 4. 安全属性配置
- 安全/非安全模式切换
- 属性配置寄存器
- 动态安全属性控制

## 建议的实现优先级

### 高优先级 (立即实现)
1. **扩展merge逻辑** - 补充21个缺失的merge关系
2. **UART可配置路由** - 实现最复杂的路由选择逻辑

### 中优先级 (后续实现)  
3. **信号处理逻辑** - 脉冲到电平转换和同步
4. **RAS中断分发** - SCP/MCP到IOSUB的分发逻辑

### 低优先级 (可选实现)
5. **安全属性配置** - 动态安全属性切换
6. **专用路由优化** - 直连和专用路径优化

## 结论

当前环境已经建立了良好的中断建模基础框架，特别是在PLL merge中断方面已有完整实现。主要缺失的是：

1. **更多merge关系的实现** - 需要补充21个merge逻辑
2. **可配置路由功能** - 特别是UART中断的选择性路由
3. **信号处理能力** - 脉冲到电平转换等基础信号处理

建议按照优先级逐步完善这些功能，以实现对中断向量表中所有特殊处理逻辑的完整建模。
