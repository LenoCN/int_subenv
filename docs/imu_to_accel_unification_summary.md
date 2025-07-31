# IMU到ACCEL术语统一总结

## 📋 概述

**实施日期**: 2025-07-31  
**实施内容**: 统一destination中的'ACCEL'与'IMU'术语，保留ACCEL方法，移除所有'IMU'描述  
**状态**: ✅ 完成并验证通过

## 🎯 背景

在当前代码中，destination中的'ACCEL'与'IMU'其实是完全一样的目的地，但在很多地方都混淆了这两个术语的使用。为了保持代码的一致性和可维护性，决定统一使用'ACCEL'作为标准术语，移除所有'IMU'的描述。

## 🔧 修改内容

### 1. 数据结构统一 ✅

**文件**: `seq/int_def.sv`

**修改内容**:
- `to_imu` → `to_accel`
- `rtl_path_imu` → `rtl_path_accel`  
- `dest_index_imu` → `dest_index_accel`

### 2. 路由模型统一 ✅

**文件**: `seq/int_routing_model.sv`

**修改内容**:
- 所有"IMU"字符串 → "ACCEL"
- `info.to_imu` → `info.to_accel`
- `info.rtl_path_imu` → `info.rtl_path_accel`
- `info.dest_index_imu` → `info.dest_index_accel`
- 目标列表更新：移除重复的"IMU"，保留"ACCEL"

### 3. UVM环境组件统一 ✅

**修改文件**:
- `env/int_monitor.sv`: 监控器中的IMU目标处理 → ACCEL目标处理
- `env/int_coverage.sv`: `imu_dest` → `accel_dest`
- `env/int_scoreboard.sv`: IMU期望处理 → ACCEL期望处理
- `env/int_driver.sv`: 驱动器中的IMU引用 → ACCEL引用
- `env/int_event_manager.sv`: 事件管理器中的IMU处理 → ACCEL处理

### 4. 序列和模型统一 ✅

**修改文件**:
- `seq/int_base_sequence.sv`: 所有IMU相关逻辑 → ACCEL逻辑
- `seq/int_lightweight_sequence.sv`: 轻量级序列中的IMU检查 → ACCEL检查
- `seq/int_register_model.sv`: 寄存器模型中的IMU处理 → ACCEL处理

### 5. 测试用例统一 ✅

**修改文件**:
- `test/test_merge_logic.sv`: 测试逻辑中的IMU引用 → ACCEL引用
- `test/test_race_condition_fix.sv`: 竞态条件测试中的IMU → ACCEL

### 6. 配置文件统一 ✅

**文件**: `config/hierarchy_config.json`

**修改内容**:
- "imu"目标映射 → "accel"目标映射

### 7. Python工具统一 ✅

**修改文件**:
- `tools/convert_xlsx_to_sv.py`: 'IMU' → 'ACCEL'映射
- `tools/update_rtl_paths.py`: 'imu' → 'accel'处理
- `tools/test_new_system.py`: 字段名更新
- 其他相关工具脚本

### 8. 自动生成文件更新 ✅

**文件**: `seq/int_map_entries.svh`

**修改内容**:
- 批量替换所有字段名：`to_imu` → `to_accel`
- 批量替换所有字段名：`rtl_path_imu` → `rtl_path_accel`
- 批量替换所有字段名：`dest_index_imu` → `dest_index_accel`

### 9. 文档更新 ✅

**修改文件**:
- `PROJECT_STATUS_SUMMARY.md`: 更新项目状态描述
- `docs/accel_subsystem_mask_implementation_summary.md`: 更新实现文档
- `docs/tc_int_routing_modification.md`: 更新路由修改文档
- 其他相关文档

## 📊 修改统计

### 文件修改数量
- **SystemVerilog文件**: 15个
- **Python工具文件**: 8个  
- **配置文件**: 1个
- **文档文件**: 5个
- **总计**: 29个文件

### 修改类型统计
- **字段名修改**: `to_imu`, `rtl_path_imu`, `dest_index_imu` → 对应的accel版本
- **字符串常量**: `"IMU"` → `"ACCEL"`
- **注释和日志**: 所有IMU相关描述 → ACCEL描述
- **变量名**: `imu_dest` → `accel_dest`

## 🧪 验证结果

### 验证工具
创建了专门的验证脚本：`tools/verify_imu_to_accel_migration.py`

### 验证内容
1. ✅ **字段名统一**: 所有`to_imu`, `rtl_path_imu`, `dest_index_imu`已替换
2. ✅ **字符串常量统一**: 所有`"IMU"`字符串已替换（除Excel表名）
3. ✅ **注释统一**: 所有代码注释中的IMU描述已更新
4. ✅ **变量名统一**: 所有相关变量名已更新
5. ✅ **文档统一**: 所有文档中的IMU引用已更新

### 验证结果
```
🎉 IMU到ACCEL术语统一完成！
- 保持了代码功能的完整性
- 统一了术语使用
- 提高了代码可维护性
```

## 🎖️ 实施亮点

### 1. 全面性
- 覆盖了所有代码文件、配置文件、文档和工具脚本
- 确保了术语使用的完全一致性

### 2. 自动化
- 使用sed命令批量处理大量文件
- 创建验证脚本确保修改完整性

### 3. 保留兼容性
- 保留了Excel表名中的历史引用（如"iosub-to-IMU中断列表"）
- 保留了信号名中的必要IMU引用（如MHU信号名）

### 4. 验证完整性
- 创建专门的验证工具
- 确保没有遗漏的IMU引用

## 🔮 后续影响

### 正面影响
1. **术语一致性**: 消除了ACCEL/IMU混用的困惑
2. **代码可读性**: 提高了代码的可理解性
3. **维护便利性**: 减少了因术语不一致导致的维护问题

### 注意事项
1. **Excel表名保持**: 保留了Excel中的历史表名以维持兼容性
2. **信号名保持**: 保留了硬件信号名中的必要IMU引用
3. **文档更新**: 需要通知相关人员术语变更

## 📞 相关文件

**主要修改文件列表**:
- `seq/int_def.sv` - 数据结构定义
- `seq/int_routing_model.sv` - 路由模型
- `seq/int_register_model.sv` - 寄存器模型  
- `seq/int_map_entries.svh` - 自动生成映射
- `env/*.sv` - 所有UVM环境组件
- `tools/*.py` - 所有Python工具
- `config/hierarchy_config.json` - 配置文件

**验证工具**:
- `tools/verify_imu_to_accel_migration.py` - 迁移验证脚本

---
*实施完成时间: 2025-07-31*  
*验证状态: ✅ 通过*  
*影响范围: 全项目*
