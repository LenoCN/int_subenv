# 中断验证文件更新流程

本文档描述了当Excel表格或hierarchy信号层次有更新时，如何重新生成所需要的SystemVerilog文件的完整流程。

## 概述

中断验证环境包含以下关键文件：
- `seq/int_map_entries.svh` - 中断映射条目（从Excel生成）
- `seq/int_routing_model.sv` - 中断路由模型
- `tools/generate_signal_paths.py` - 信号路径生成器
- `tools/update_rtl_paths.py` - RTL路径更新工具

## 更新流程

### 快速更新（推荐）

使用自动化脚本进行一键更新：

```bash
# 完整更新（从Excel + hierarchy）
./tools/update_interrupt_files.sh -e interrupt_spec.xlsx -v

# 只更新hierarchy路径
./tools/update_interrupt_files.sh -h -v

# 验证当前配置
python3 tools/validate_config.py
```

### 详细步骤

#### 步骤1：更新Excel表格数据

当中断规格发生变化时：

1. **更新Excel文件**
   - 修改中断名称、索引、目标映射等信息
   - 确保所有必要的列都已填写完整
   - 保存Excel文件

2. **重新生成中断映射条目**
   ```bash
   cd /path/to/workspace
   python3 tools/excel_to_sv.py input.xlsx seq/int_map_entries.svh
   ```

#### 步骤2：更新Hierarchy信号层次

当RTL hierarchy或信号名称发生变化时：

1. **更新配置文件** (`config/hierarchy_config.json`)

   这是推荐的方法，修改JSON配置文件：

   ```json
   {
     "base_hierarchy": {
       "iosub_top": "top_tb.multidie_top.DUT[0].u_str_top.u_iosub_top_wrap",
       "mcp_top": "top_tb.multidie_top.DUT[0].u_str_top.u_iosub_top_wrap.u0_iosub_top_wrap_hd.u0_iosub_top_wrap_raw.u_mcp_top",
       "scp_top": "top_tb.multidie_top.DUT[0].u_str_top.u_iosub_top_wrap.u0_iosub_top_wrap_hd.u0_iosub_top_wrap_raw.u_scp_top_wrapper"
     },

     "signal_widths": {
       "iosub_to_mcp_intr": 146,
       "mcp_to_iosub_intr": 8,
       "iosub_to_scp_intr": 131,
       "scp_to_iosub_intr": 53
     },

     "interrupt_groups": {
       "NEW_GROUP": {
         "description": "New interrupt group",
         "base_signal": "new_group_to_iosub_intr"
       }
     }
   }
   ```

2. **验证配置更新**
   ```bash
   # 验证配置文件
   python3 tools/validate_config.py

   # 测试信号路径生成
   python3 tools/generate_signal_paths.py --test --validate
   ```

#### 步骤3：重新生成RTL路径

运行RTL路径更新工具：

```bash
cd /path/to/workspace

# 使用默认配置
python3 tools/update_rtl_paths.py

# 使用自定义配置文件
python3 tools/update_rtl_paths.py -c config/custom_hierarchy.json

# 指定不同的条目文件
python3 tools/update_rtl_paths.py -e seq/custom_int_map_entries.svh
```

这个工具会：
- 读取hierarchy配置文件（默认：`config/hierarchy_config.json`）
- 读取更新后的`int_map_entries.svh`
- 使用新的hierarchy信息生成RTL路径
- 更新所有中断条目的`rtl_path_src`、`rtl_path_scp`、`rtl_path_mcp`等字段
- 创建备份文件`seq/int_map_entries.svh.backup`

### 步骤4：验证更新结果

1. **检查生成的路径**
   ```bash
   # 检查源路径是否正确
   grep "rtl_path_src" seq/int_map_entries.svh | head -10
   
   # 检查目标路径是否正确
   grep "rtl_path_scp.*iosub_to_scp_intr" seq/int_map_entries.svh | head -5
   ```

2. **验证路径统计**
   ```bash
   python3 tools/update_rtl_paths.py
   # 查看输出的统计信息，确保路径数量合理
   ```

3. **运行基本测试**
   ```bash
   # 编译检查
   make compile
   
   # 运行简单的中断测试
   make test TEST=basic_interrupt_test
   ```

## 完整的自动化脚本

创建一个自动化更新脚本：

```bash
#!/bin/bash
# update_interrupt_files.sh

set -e

WORKSPACE_DIR="/path/to/workspace"
EXCEL_FILE="$1"

if [ -z "$EXCEL_FILE" ]; then
    echo "Usage: $0 <excel_file>"
    exit 1
fi

cd $WORKSPACE_DIR

echo "Step 1: Generating interrupt map entries from Excel..."
python3 tools/excel_to_sv.py "$EXCEL_FILE" seq/int_map_entries.svh

echo "Step 2: Updating RTL paths with hierarchy information..."
python3 tools/update_rtl_paths.py

echo "Step 3: Validating generated files..."
# 基本语法检查
vlog -sv seq/int_map_entries.svh -work work

echo "Step 4: Running basic tests..."
make compile
make test TEST=basic_interrupt_test

echo "Update completed successfully!"
echo "Backup file created: seq/int_map_entries.svh.backup"
```

## 文件依赖关系

```
Excel文件 → int_map_entries.svh → RTL路径更新 → 最终验证文件
    ↓              ↓                    ↓
excel_to_sv.py  hierarchy信息    update_rtl_paths.py
                     ↓
            generate_signal_paths.py
```

## 注意事项

1. **备份重要文件**
   - 每次更新前自动创建备份
   - 保留多个版本的备份文件

2. **增量更新**
   - 如果只是hierarchy路径变化，只需运行步骤2和3
   - 如果只是Excel数据变化，只需运行步骤1和3

3. **验证检查**
   - 检查信号位宽是否匹配
   - 验证索引范围是否正确
   - 确保所有目标路径都有效

4. **版本控制**
   - 提交更新前的文件状态
   - 记录更新原因和变更内容
   - 标记重要的版本节点

## 故障排除

### 常见问题

1. **路径生成错误**
   - 检查hierarchy路径是否正确
   - 验证信号名称拼写
   - 确认信号位宽设置

2. **索引超出范围**
   - 更新`signal_widths`字典
   - 检查Excel中的索引值

3. **编译错误**
   - 检查SystemVerilog语法
   - 验证生成的文件格式

### 调试命令

```bash
# 检查特定中断的路径
grep "interrupt_name" seq/int_map_entries.svh

# 验证路径格式
python3 -c "
import sys
sys.path.append('tools')
from generate_signal_paths import SignalPathGenerator
gen = SignalPathGenerator()
print(gen.generate_source_path('test_intr', 'CSUB', 0))
"

# 检查文件差异
diff seq/int_map_entries.svh.backup seq/int_map_entries.svh
```

通过遵循这个流程，您可以确保在Excel表格或hierarchy信息更新时，能够快速、准确地重新生成所有必要的SystemVerilog文件。
