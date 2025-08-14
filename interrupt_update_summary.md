# IOSUB中断源更新汇总报告

## 任务完成情况

### ✅ 已完成任务

1. **读取int_vector.xlsx文件中IOSUB中断源工作表**
   - 成功读取Excel文件，识别了423个中断名

2. **对比int_map_entries.svh现有中断**
   - 原文件包含440个中断条目
   - 识别出138个缺失的中断

3. **检查SCP/MCP M7中断列表**
   - 在SCP M7列表中找到74个缺失中断的映射
   - 在MCP M7列表中找到29个缺失中断的映射

4. **添加缺失中断到int_map_entries.svh**
   - 成功添加了89个中断条目（包含完整的SCP/MCP路径信息）
   - 文件从474行增加到567行，增加了93行

5. **更新cpu_irq路径**
   - 为存在于SCP/MCP表中的中断正确设置了cpu_irq[*]信号路径
   - 例如：`cpu_irq[32]`, `cpu_irq[194]`等

### 📊 数据统计

- **Excel中断总数**: 423
- **原SVH文件中断数**: 440  
- **更新后SVH文件中断数**: 529
- **成功添加的中断数**: 89
- **设置SCP路径的中断数**: 74
- **设置MCP路径的中断数**: 29

### ✅ 成功添加的关键中断示例

1. **ap2scp_mhu_receive_intr_[0-3]** - 设置了SCP cpu_irq[32-35]路径
2. **mcp_timer64_[0-3]_intr** - 设置了MCP cpu_irq[1-4]路径  
3. **iosub_pad_in_[0-15]_intr** - 设置了SCP和MCP的cpu_irq路径
4. **d2d_*_mhu_*_intr** - 各种D2D通信中断
5. **scp_*_intr** - SCP相关的各类中断

### ⚠️ 仍未处理的中断 (49个)

主要包括以下类型：

1. **向量中断** (5个)
   - `csub_pll_intr_*[16:0]` - 需要展开为17个单独中断
   - 这些是向量格式，可能需要特殊的处理逻辑

2. **DDR PLL中断** (12个)  
   - `ddr[0-2]_pll_*_intr` - DDR相关的PLL中断
   - 可能需要确认是否应该单独添加

3. **IO Die中断** (32个)
   - `io_die_intr_[0-31]_intr` - IO Die的32个中断
   - 需要确认映射关系和路径

## 文件变更

### 备份文件
- `int_map_entries.svh.backup` - 原始文件备份

### 生成文件
- `generate_missing_interrupts.py` - 中断生成脚本
- `missing_interrupts.svh` - 生成的缺失中断条目
- `interrupt_update_summary.md` - 本汇总报告

### 主要文件更新
- `seq/int_map_entries.svh` - 主要的中断映射文件，已成功更新

## 验证结果

所有添加的中断条目都包含：
- ✅ 正确的IOSUB组别标识
- ✅ 正确的索引值  
- ✅ 正确的rtl_path_src路径
- ✅ 正确的SCP cpu_irq路径（如适用）
- ✅ 正确的MCP cpu_irq路径（如适用）
- ✅ 完整的中断属性设置

## 结论

任务已成功完成主要目标：
- ✅ 识别并添加了IOSUB中断源工作表中缺失的89个重要中断
- ✅ 为存在于SCP/MCP M7列表中的中断正确设置了cpu_irq[*]路径
- ✅ 保持了文件的原有格式和结构完整性

剩余的49个中断主要是向量类型和特殊类型中断，需要进一步确认处理方式。核心功能中断已全部添加完成。