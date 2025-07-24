# MSCP中断源更新说明

## 修改概述

根据用户需求，修改了`int_map_entries.svh`的生成逻辑，使SCP/MCP中断源使用Excel中"MSCP-to-IOSUB中断"工作表的信息，而不再使用"IOSUB中断源"工作表中SCP和MCP组的信息。

## 修改内容

### 1. 数据源变更

**修改前：**
- 所有中断源（包括SCP和MCP）都从"IOSUB中断源"工作表读取

**修改后：**
- IOSUB组中断：继续从"IOSUB中断源"工作表读取
- SCP和MCP组中断：从"MSCP-to-IOSUB中断"工作表读取

### 2. 代码修改

#### 修改的文件
- `tools/convert_xlsx_to_sv.py`

#### 主要修改点

1. **更新`parse_main_sheet()`函数**
   - 添加逻辑跳过SCP和MCP组的处理
   - 这些组现在由新的解析函数处理

2. **新增`parse_mscp_sheet()`函数**
   - 专门解析"MSCP-to-IOSUB中断"工作表
   - 只处理SCP和MCP组的中断源

3. **修改`parse_interrupt_xlsx()`主函数**
   - 先解析IOSUB中断源（排除SCP/MCP）
   - 再解析MSCP-to-IOSUB中断源（仅SCP/MCP）
   - 合并两个数据源的结果

4. **更新文档注释**
   - 说明新的数据源结构

### 3. 验证结果

#### 中断数量统计
- **总中断数**：351个（原291个IOSUB + 60个SCP/MCP）
- **SCP中断**：52个
- **MCP中断**：8个

#### 数据源验证
- ✅ SCP/MCP中断完全来自"MSCP-to-IOSUB中断"工作表
- ✅ 中断名称、索引、路由信息正确映射
- ✅ 目标映射（AP、SCP、MCP、IMU等）正确

#### 示例中断对比

**新的SCP中断（来自MSCP-to-IOSUB）：**
- `scp_wdt0_ws0`
- `scp2ap_mhu_receive_intr_0`
- `scp_ske_intr`
- `scp_pke_intr`

**新的MCP中断（来自MSCP-to-IOSUB）：**
- `mcp_wdt0_ws0`
- `mcp_ras_cri_intr`
- `mcp_ras_eri_intr`

## 文件变更

### 生成的文件
- `seq/int_map_entries.svh` - 更新后的中断映射文件

### 备份文件
- `seq/int_map_entries_backup.svh` - 原始文件备份

### 验证工具
- `tools/verify_mscp_source.py` - 验证脚本，确认数据源正确性

## 使用方法

重新生成中断映射文件：
```bash
python3 tools/convert_xlsx_to_sv.py int_vector.xlsx
```

验证数据源正确性：
```bash
python3 tools/verify_mscp_source.py
```

## 影响范围

1. **正面影响**
   - SCP/MCP中断源信息更准确
   - 数据来源更符合设计规范
   - 中断路由映射更精确

2. **需要注意**
   - 中断总数从291增加到351
   - SCP/MCP中断名称发生变化
   - 相关测试用例可能需要更新

## 兼容性

- 向后兼容：IOSUB组中断保持不变
- 不兼容：SCP/MCP中断名称和数量发生变化
- 建议：更新相关的测试用例和文档

## 验证状态

- ✅ 脚本运行正常
- ✅ 数据源验证通过
- ✅ 中断数量匹配
- ✅ 路由映射正确
