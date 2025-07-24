# IO DIE中断源移除记录

## 概述

本文档记录了从int_map_entries.svh生成过程中移除"外部中断源-from IO DIE"部分处理的详细过程和结果。

## 背景

根据用户需求，在生成int_map_entries.svh的过程中，需要移除对"iosub中断源"工作表中"外部中断源-from IO DIE"部分的处理，这部分不需要生成entries信息。

## 修改内容

### 1. 修改convert_xlsx_to_sv.py脚本

**文件路径**: `tools/convert_xlsx_to_sv.py`

#### 1.1 注释GROUP_MAP中的IO_DIE映射

**修改前:**
```python
GROUP_MAP = {
    # ... 其他映射 ...
    "外部中断源-from IO DIE": "IO_DIE"
}
```

**修改后:**
```python
GROUP_MAP = {
    # ... 其他映射 ...
    # "外部中断源-from IO DIE": "IO_DIE"  # 移除IO DIE处理
}
```

#### 1.2 添加跳过IO_DIE组的逻辑

在`parse_main_sheet`函数中添加：

```python
elif group_name == "外部中断源-from IO DIE":
    # 跳过IO DIE组的处理
    current_group = "SKIP_IO_DIE"
```

以及：

```python
# Skip IO DIE group interrupts
if current_group == "SKIP_IO_DIE":
    continue
```

#### 1.3 在生成函数中添加额外保护

在`generate_sv_file`函数中添加：

```python
# Skip IO_DIE group
if group_name == "IO_DIE":
    continue
```

### 2. 重新生成int_map_entries.svh

使用修改后的脚本重新生成了`seq/int_map_entries.svh`文件，成功移除了所有IO_DIE相关的中断条目。

## 修改结果

### 文件变化统计

- **原文件行数**: 455行
- **新文件行数**: 421行  
- **减少行数**: 34行（32个IO_DIE中断条目 + 组标题和空行）

### 移除的中断条目

移除了32个IO_DIE组的中断条目：
- `io_die_intr_0_intr` 到 `io_die_intr_31_intr`
- 这些中断原本映射到SCP的cpu_irq[62]到cpu_irq[93]

### 当前中断统计

生成后的文件包含389个中断条目，分布在14个组中：

| 组名 | 中断数量 |
|------|----------|
| ACCEL | 20 |
| CSUB | 27 |
| D2D | 13 |
| DDR0 | 12 |
| DDR1 | 12 |
| DDR2 | 12 |
| IODAP | 5 |
| IOSUB | 83 |
| MCP | 20 |
| PCIE1 | 22 |
| PSUB | 22 |
| SCP | 110 |
| SMMU | 18 |
| USB | 13 |

## 验证

创建了验证脚本`tools/verify_io_die_removal.py`来确认修改的正确性：

1. ✅ 确认int_map_entries.svh中不包含任何IO_DIE引用
2. ✅ 确认convert_xlsx_to_sv.py脚本修改正确
3. ✅ 确认中断统计正确，IO_DIE组已完全移除

## 影响分析

### 正面影响

1. **简化生成过程**: 自动跳过不需要的IO_DIE中断源
2. **减少文件大小**: 移除了32个不必要的中断条目
3. **提高维护性**: 未来重新生成时会自动跳过IO_DIE部分

### 注意事项

1. **向后兼容性**: 如果有其他代码依赖IO_DIE中断，需要相应更新
2. **文档更新**: 相关设计文档可能需要更新以反映这一变化
3. **测试影响**: 涉及IO_DIE中断的测试用例可能需要调整

## 使用方法

今后重新生成int_map_entries.svh时，只需运行：

```bash
python3 tools/convert_xlsx_to_sv.py int_vector.xlsx -o seq/int_map_entries.svh
```

脚本会自动跳过"外部中断源-from IO DIE"部分的处理。

## 总结

成功实现了用户需求，在生成int_map_entries.svh的过程中移除了对"外部中断源-from IO DIE"部分的处理。修改包括：

1. 注释了GROUP_MAP中的IO_DIE映射
2. 添加了跳过IO_DIE组的处理逻辑
3. 重新生成了不包含IO_DIE条目的int_map_entries.svh文件
4. 创建了验证脚本确保修改正确

所有修改都经过验证，确保功能正常且不影响其他中断组的处理。
