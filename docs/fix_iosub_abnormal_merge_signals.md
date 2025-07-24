# 修复 iosub_abnormal 信号 UVM_ERROR 问题

## 问题描述

在仿真过程中出现了以下两个 UVM_ERROR：

```
120:12994:UVM_ERROR /share/tools/eda1/synopsys/vcs-2024.09-sp1/etc/uvm-1.2/src/dpi/uvm_hdl_vcs.c(1416) @ 92895.00ns: reporter [UVM/DPI/HDL_SET] set: unable to locate hdl path (top_tb.multidie_top.DUT[0].u_str_top.u_iosub_top_wrap.u0_iosub_top_wrap_hd.u0_iosub_top_wrap_raw.u_iosub_int_sub.iosub_peri_intr[74])

120:12994:UVM_ERROR /share/tools/eda1/synopsys/vcs-2024.09-sp1/etc/uvm-1.2/src/dpi/uvm_hdl_vcs.c(1416) @ 92895.00ns: reporter [UVM/DPI/HDL_SET] set: unable to locate hdl path (top_tb.multidie_top.DUT[0].u_str_top.u_iosub_top_wrap.u0_iosub_top_wrap_hd.u0_iosub_top_wrap_raw.u_iosub_int_sub.iosub_peri_intr[75])
```

## 根本原因分析

1. **问题1**: `iosub_abnormal_0_intr` (index 74) 已经被配置为merge类信号，但系统仍然尝试直接force/release其RTL路径，导致HDL路径定位失败。

2. **问题2**: `iosub_abnormal_1_intr` (index 75) 应该也被添加为merge类信号，但由于属于reserved信号（没有对应的源信号），需要特殊处理。

## 解决方案

### 1. 更新路由模型 (seq/int_routing_model.sv)

#### 添加 iosub_abnormal_1_intr 的merge处理逻辑：

```systemverilog
"iosub_abnormal_1_intr": begin
    // iosub_abnormal_1_intr is a reserved merge signal with no sources
    // This is intentionally empty as it's reserved for future use
    // No sources to collect for this merge signal
end
```

#### 更新 is_merge_interrupt 函数：

```systemverilog
// Function to check if an interrupt is a merge interrupt
static function bit is_merge_interrupt(string interrupt_name);
    return (interrupt_name == "merge_pll_intr_lock" ||
            interrupt_name == "merge_pll_intr_unlock" ||
            interrupt_name == "merge_pll_intr_frechangedone" ||
            interrupt_name == "merge_pll_intr_frechange_tot_done" ||
            interrupt_name == "merge_pll_intr_intdocfrac_err" ||
            // New merge interrupts from CSV analysis
            interrupt_name == "iosub_normal_intr" ||
            interrupt_name == "iosub_slv_err_intr" ||
            interrupt_name == "iosub_ras_cri_intr" ||
            interrupt_name == "iosub_ras_eri_intr" ||
            interrupt_name == "iosub_ras_fhi_intr" ||
            interrupt_name == "iosub_abnormal_0_intr" ||
            interrupt_name == "iosub_abnormal_1_intr" ||  // 新增
            interrupt_name == "merge_external_pll_intr");
endfunction
```

### 2. 更新驱动器 (env/int_driver.sv)

#### 添加merge信号检查逻辑：

```systemverilog
// Check if this is a merge interrupt - merge interrupts should not be directly stimulated
if (is_merge_interrupt(item.interrupt_info.name)) begin
    `uvm_warning(get_type_name(), $sformatf("⚠️  Interrupt '%s' is a merge signal. Merge signals should not be directly stimulated. Skipping stimulus generation.",
                 item.interrupt_info.name));
    `uvm_info(get_type_name(), "💡 To test merge signals, stimulate their source interrupts instead.", UVM_MEDIUM)
    return;
end
```

#### 添加 is_merge_interrupt 函数：

```systemverilog
// Function to check if an interrupt is a merge interrupt
// Merge interrupts should not be directly stimulated
virtual function bit is_merge_interrupt(string interrupt_name);
    return (interrupt_name == "merge_pll_intr_lock" ||
            interrupt_name == "merge_pll_intr_unlock" ||
            interrupt_name == "merge_pll_intr_frechangedone" ||
            interrupt_name == "merge_pll_intr_frechange_tot_done" ||
            interrupt_name == "merge_pll_intr_intdocfrac_err" ||
            // New merge interrupts from CSV analysis
            interrupt_name == "iosub_normal_intr" ||
            interrupt_name == "iosub_slv_err_intr" ||
            interrupt_name == "iosub_ras_cri_intr" ||
            interrupt_name == "iosub_ras_eri_intr" ||
            interrupt_name == "iosub_ras_fhi_intr" ||
            interrupt_name == "iosub_abnormal_0_intr" ||
            interrupt_name == "iosub_abnormal_1_intr" ||
            interrupt_name == "merge_external_pll_intr");
endfunction
```

### 3. 更新验证脚本 (tools/verify_merge_implementation.py)

#### 添加 iosub_abnormal_1_intr 到预期merge列表：

```python
"iosub_abnormal_1_intr": [
    # Reserved merge signal with no sources
    # This is intentionally empty as it's reserved for future use
],
```

### 4. 更新测试文件 (test/tc_comprehensive_merge_test.sv)

#### 添加到merge信号列表：

```systemverilog
all_merge_interrupts = {
    // ... 其他信号 ...
    "iosub_abnormal_0_intr",
    "iosub_abnormal_1_intr",  // 新增
    "merge_external_pll_intr"
};
```

#### 添加验证函数：

```systemverilog
virtual function bit verify_abnormal_1_sources(interrupt_info_s sources[$]);
    // iosub_abnormal_1_intr is a reserved merge signal with no sources
    // Verify that it has no sources (empty list)
    if (sources.size() == 0) begin
        `uvm_info("COMP_MERGE_SEQ", "✅ iosub_abnormal_1_intr correctly has no sources (reserved)", UVM_MEDIUM)
        return 1;
    end else begin
        `uvm_warning("COMP_MERGE_SEQ", $sformatf("iosub_abnormal_1_intr should have no sources but found %0d", sources.size()))
        return 0;
    end
endfunction
```

## 修改的文件列表

1. `seq/int_routing_model.sv` - 添加merge信号处理逻辑
2. `env/int_driver.sv` - 添加merge信号检查，防止直接force/release
3. `tools/verify_merge_implementation.py` - 更新验证脚本
4. `test/tc_comprehensive_merge_test.sv` - 更新测试覆盖
5. `tools/verify_merge_signal_handling.py` - 新增验证脚本

## 验证结果

运行验证脚本 `tools/verify_merge_signal_handling.py` 确认：

✅ 所有merge信号已正确配置在路由模型中  
✅ 驱动器包含merge信号检查逻辑  
✅ 测试文件包含所有merge信号的覆盖  
✅ iosub_abnormal_0_intr 和 iosub_abnormal_1_intr 配置正确  

## 预期效果

1. **解决UVM_ERROR**: merge信号不再被直接force/release，避免HDL路径定位错误
2. **正确的merge信号处理**: 通过源信号来测试merge信号的功能
3. **完整的测试覆盖**: 包含所有merge信号的测试验证
4. **Reserved信号处理**: iosub_abnormal_1_intr作为reserved信号被正确处理

## 使用说明

- 要测试 `iosub_abnormal_0_intr`，应该刺激其源信号：`iodap_etr_buf_intr` 和 `iodap_catu_addrerr_intr`
- `iosub_abnormal_1_intr` 作为reserved信号，暂时没有源信号，但已配置为merge信号以备将来使用
- 驱动器会自动检测并跳过对merge信号的直接刺激，并给出相应的警告信息
