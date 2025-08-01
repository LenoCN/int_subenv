# IOSUB RAS Merge逻辑修改报告

## 修改概述

**修改日期**: 2025-08-01  
**修改目标**: 修改iosub_ras_*_intr的merge逻辑，使其仅merge smmu的ras中断

## 修改前的逻辑

### iosub_ras_cri_intr
- smmu_cri_intr
- scp_ras_cri_intr  
- mcp_ras_cri_intr

### iosub_ras_eri_intr
- smmu_eri_intr
- scp_ras_eri_intr
- mcp_ras_eri_intr

### iosub_ras_fhi_intr
- smmu_fhi_intr
- scp_ras_fhi_intr
- mcp_ras_fhi_intr
- iodap_chk_err_etf0
- iodap_chk_err_etf1

## 修改后的逻辑

### iosub_ras_cri_intr
- 仅 smmu_cri_intr

### iosub_ras_eri_intr
- 仅 smmu_eri_intr

### iosub_ras_fhi_intr
- 仅 smmu_fhi_intr

## 修改的文件

### 1. seq/int_routing_model.sv
修改了三个merge中断的源中断收集逻辑：

**iosub_ras_cri_intr** (行171-178):
```systemverilog
"iosub_ras_cri_intr": begin
    // Collect only SMMU interrupts that should be merged into iosub_ras_cri_intr
    foreach (interrupt_map[i]) begin
        if (interrupt_map[i].name == "smmu_cri_intr") begin
            sources.push_back(interrupt_map[i]);
        end
    end
end
```

**iosub_ras_eri_intr** (行180-187):
```systemverilog
"iosub_ras_eri_intr": begin
    // Collect only SMMU interrupts that should be merged into iosub_ras_eri_intr
    foreach (interrupt_map[i]) begin
        if (interrupt_map[i].name == "smmu_eri_intr") begin
            sources.push_back(interrupt_map[i]);
        end
    end
end
```

**iosub_ras_fhi_intr** (行189-196):
```systemverilog
"iosub_ras_fhi_intr": begin
    // Collect only SMMU interrupts that should be merged into iosub_ras_fhi_intr
    foreach (interrupt_map[i]) begin
        if (interrupt_map[i].name == "smmu_fhi_intr") begin
            sources.push_back(interrupt_map[i]);
        end
    end
end
```

### 2. tools/verify_merge_implementation.py
更新了验证工具中的期望配置 (行65-75):

```python
"iosub_ras_cri_intr": [
    "smmu_cri_intr"
],

"iosub_ras_eri_intr": [
    "smmu_eri_intr"
],

"iosub_ras_fhi_intr": [
    "smmu_fhi_intr"
],
```

## 验证结果

运行验证工具确认修改成功：

```
验证 iosub_ras_cri_intr:
✅ 正确实现的源中断: 1个 - smmu_cri_intr
实现状态: 1/1 源中断正确

验证 iosub_ras_eri_intr:
✅ 正确实现的源中断: 1个 - smmu_eri_intr
实现状态: 1/1 源中断正确

验证 iosub_ras_fhi_intr:
✅ 正确实现的源中断: 1个 - smmu_fhi_intr
实现状态: 1/1 源中断正确
```

## 影响分析

### 正面影响
1. **简化了merge逻辑**: 每个iosub_ras_*_intr现在只包含一个源中断
2. **明确了责任边界**: iosub_ras_*_intr专门处理smmu的ras中断
3. **降低了复杂度**: 减少了merge逻辑的复杂性

### 需要注意的事项
1. **scp_ras_*_intr和mcp_ras_*_intr**: 这些中断不再通过iosub_ras_*_intr merge，需要确认它们有独立的路由路径
2. **iodap_chk_err_etf0/etf1**: 这些中断不再通过iosub_ras_fhi_intr merge，需要确认它们有独立的路由路径
3. **测试用例**: 可能需要更新相关的测试用例以反映新的merge逻辑

## 后续行动

1. **验证独立路由**: 确认被移除的源中断(scp_ras_*_intr, mcp_ras_*_intr, iodap_chk_err_*)有正确的独立路由配置
2. **更新测试**: 检查并更新相关的测试用例
3. **文档更新**: 更新相关的设计文档以反映新的merge逻辑

## 总结

✅ **修改完成**: iosub_ras_*_intr现在仅merge smmu的ras中断  
✅ **验证通过**: 所有merge逻辑实现验证通过  
✅ **代码一致性**: 路由模型和验证工具保持一致  

修改已成功完成，系统现在按照新的merge逻辑运行。
