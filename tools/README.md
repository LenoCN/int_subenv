# 中断验证环境工具集

本目录包含用于中断验证环境的核心工具集，经过清理后保留了5个核心工具。

## 🔧 核心工具

### 1. `generate_interrupt_config.py` - 完整流程自动化工具 ⭐
**推荐使用的主要工具**

```bash
# 完整的一键生成流程
python3 tools/generate_interrupt_config.py int_vector.xlsx -o seq/int_map_entries.svh
```

**功能**：
- 执行完整的Excel到SystemVerilog转换流程
- 包含所有验证和检查步骤
- 提供详细的进度报告和问题诊断
- 自动创建备份文件

**流程步骤**：
1. 检查Excel命名一致性
2. 从Excel生成SystemVerilog配置文件
3. 更新RTL路径
4. 验证信号路径生成器配置
5. 验证生成结果

### 2. `convert_xlsx_to_sv.py` - Excel转换工具
```bash
python3 tools/convert_xlsx_to_sv.py int_vector.xlsx -o seq/int_map_entries.svh
```

**功能**：
- 解析Excel中断规格文件
- 生成SystemVerilog中断映射条目
- 处理多个工作表的数据合并
- 支持目标索引映射

### 3. `update_rtl_paths.py` - RTL路径更新工具
```bash
python3 tools/update_rtl_paths.py
```

**功能**：
- 基于hierarchy配置更新RTL路径
- 生成正确的源路径和目标路径
- 自动创建备份文件
- 验证生成的路径

### 4. `generate_signal_paths.py` - 信号路径生成器
```bash
# 验证配置
python3 tools/generate_signal_paths.py --validate

# 运行测试用例
python3 tools/generate_signal_paths.py --test
```

**功能**：
- 提供信号路径生成的核心逻辑
- 被update_rtl_paths.py调用
- 支持配置验证和测试
- 处理各种中断组的路径生成

### 5. `check_excel_naming_issues.py` - Excel命名检查工具
```bash
python3 tools/check_excel_naming_issues.py
```

**功能**：
- 检查Excel文件中的命名一致性
- 识别iosub_normal_int vs iosub_normal_intr等问题
- 提供修正建议
- 支持多个工作表的检查

## 📋 使用流程

### 快速开始（推荐）
```bash
# 一键生成完整配置
python3 tools/generate_interrupt_config.py int_vector.xlsx
```

### 手动执行步骤
```bash
# 1. 检查Excel命名
python3 tools/check_excel_naming_issues.py

# 2. 生成基础配置
python3 tools/convert_xlsx_to_sv.py int_vector.xlsx -o seq/int_map_entries.svh

# 3. 更新RTL路径
python3 tools/update_rtl_paths.py

# 4. 验证配置（可选）
python3 tools/generate_signal_paths.py --validate
```

## 📁 相关文件

### 输入文件
- `int_vector.xlsx` - Excel中断规格文件
- `config/hierarchy_config.json` - 层次结构配置

### 输出文件
- `seq/int_map_entries.svh` - 生成的SystemVerilog配置
- `seq/int_map_entries.svh.backup` - 自动备份文件

### 文档
- `docs/routing_configuration_fix_summary.md` - 路由配置修复总结
- `PROJECT_STATUS_SUMMARY.md` - 项目状态总结

## 🔍 故障排除

### 常见问题

1. **Excel命名不一致**
   ```
   问题: iosub_normal_int vs iosub_normal_intr
   解决: 修正Excel文件中的命名，然后重新生成
   ```

2. **路由配置问题**
   ```
   问题: to_<dest>=1 但 rtl_path_<dest> 为空
   原因: Excel中标记为"Possible"而不是"YES"，或目标表中缺少索引
   ```

3. **RTL路径为空**
   ```
   问题: 生成的RTL路径为空
   检查: config/hierarchy_config.json配置是否正确
   ```

### 调试技巧

```bash
# 检查生成的条目数量
grep -c "interrupt_map.push_back" seq/int_map_entries.svh

# 检查路由配置问题
grep -c 'to_.*:1.*rtl_path_.*:""' seq/int_map_entries.svh

# 查看特定中断的配置
grep "iosub_normal_intr" seq/int_map_entries.svh
```

## 📈 版本历史

- **v2.0** (2025-08-01): 大规模清理，保留5个核心工具
- **v1.5** (2025-07-30): 修复路由配置问题，添加完整流程自动化
- **v1.0** (2025-07-15): 初始版本，包含多个验证和分析工具

## 🎯 设计原则

1. **简化工具集**: 只保留必要的核心工具
2. **自动化优先**: 提供一键执行的完整流程
3. **详细反馈**: 每个步骤都有清晰的进度和错误报告
4. **向后兼容**: 支持手动执行各个步骤
5. **可维护性**: 清晰的代码结构和文档

---

*最后更新: 2025-08-01*  
*维护者: AI Assistant*
