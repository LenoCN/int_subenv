# 中断子环境验证系统 (int_subenv)

## 项目概述

这是一个基于UVM的中断路由验证环境，用于验证复杂SoC中的中断路由逻辑。系统支持多种中断类型、merge逻辑验证、以及完整的中断激励和检测机制。

## 核心功能

### 1. 中断路由建模
- **Excel驱动配置**: 从`int_vector.xlsx`自动生成中断映射
- **多目标路由**: 支持AP、SCP、MCP、IMU等多个目标
- **组织分类**: 按IOSUB、USB、SCP、MCP等组别管理中断

### 2. Merge中断验证
- **PLL中断合并**: 支持lock、unlock、frechangedone等PLL中断的merge逻辑
- **系统级merge**: 支持normal、error、RAS等系统级中断合并
- **源中断追踪**: 完整的merge源中断关系建模

### 3. 激励合规性
- **多种触发类型**: Level、Edge、Pulse触发支持
- **极性处理**: Active High/Low、Rising/Falling Edge
- **合规性检查**: 自动验证激励方法与中断规格的匹配度

### 4. UVM标准架构
- **Sequence-Driver架构**: 标准UVM组件分离
- **事件驱动握手**: 精确的stimulus-detection同步
- **模块化设计**: 易于扩展和维护

## 目录结构

```
int_subenv/
├── README.md                          # 项目主文档
├── int_vector.xlsx                     # 中断向量表配置文件
├── 中断向量表-iosub-V0.5.csv          # CSV格式中断向量表
├── cfg/                               # 配置文件
│   └── int.mk                         # Makefile配置
├── env/                               # UVM环境组件
│   ├── int_subenv.sv                  # 主环境
│   ├── int_driver.sv                  # 中断激励驱动器
│   ├── int_monitor.sv                 # 中断监控器
│   ├── int_scoreboard.sv              # 计分板
│   ├── int_sequencer.sv               # 序列器
│   └── int_event_manager.sv           # 事件管理器
├── seq/                               # 序列和模型
│   ├── int_base_sequence.sv           # 基础序列类
│   ├── int_lightweight_sequence.sv    # 轻量级测试序列
│   ├── int_routing_model.sv           # 中断路由预测模型
│   ├── int_stimulus_item.sv           # 激励事务类
│   ├── int_transaction.sv             # 基础事务类
│   ├── int_def.sv                     # 数据结构定义
│   └── int_map_entries.svh            # 自动生成的中断映射
├── test/                              # 测试用例
│   ├── int_tc_base.sv                 # 基础测试类
│   ├── tc_int_routing.sv              # 路由测试
│   ├── tc_merge_interrupt_test.sv     # Merge中断测试
│   ├── tc_handshake_test.sv           # 握手机制测试
│   └── tc_*.sv                        # 其他测试用例
├── tb/                                # 测试平台
│   ├── int_harness.sv                 # 测试线束
│   ├── int_interface.sv               # 接口定义
│   └── top_tb.f                       # 文件列表
├── rtl/                               # RTL参考模型
│   └── int_controller.sv              # 中断控制器
└── tools/                             # 工具脚本
    ├── convert_xlsx_to_sv.py          # Excel转换工具
    ├── check_stimulus_compliance.py   # 合规性检查
    ├── verify_merge_implementation.py # Merge逻辑验证
    └── analyze_interrupt_comments.py  # 注释分析工具
```

## 快速开始

### 1. 环境准备
```bash
# 确保有Python 3.6+环境
pip install pandas openpyxl

# 检查必要文件
ls int_vector.xlsx 中断向量表-iosub-V0.5.csv
```

### 2. 生成中断映射
```bash
# 从Excel生成SystemVerilog映射文件
python3 tools/convert_xlsx_to_sv.py int_vector.xlsx

# 验证生成结果
python3 tools/test_new_system.py
```

### 3. 运行合规性检查
```bash
# 检查激励方法合规性
python3 tools/check_stimulus_compliance.py

# 验证merge逻辑实现
python3 tools/verify_merge_implementation.py
```

### 4. 运行测试
```bash
# 基础路由测试
make -f cfg/int.mk tc_int_routing

# Merge中断测试
make -f cfg/int.mk tc_merge_interrupt_test

# 完整回归测试
make -f cfg/int.mk regression
```

## 主要特性

### Excel驱动配置
- 支持多页签Excel文件解析
- 自动提取中断名称、索引、目标路由信息
- 生成标准SystemVerilog数据结构

### 智能Merge逻辑
- 自动识别merge中断关系
- 支持复杂的多源中断合并
- 完整的源中断追踪和验证

### 高精度激励
- 基于中断规格的精确激励生成
- 支持Level、Edge、Pulse等多种触发类型
- 自动适配Active High/Low极性

### 事件驱动同步
- 替代固定延迟的精确握手机制
- Monitor-Sequence事件通信
- 提高仿真效率和准确性

## 验证覆盖率

当前系统验证状态：
- ✅ **中断映射**: 423个中断完整建模
- ✅ **Merge逻辑**: 12个merge中断100%实现
- ✅ **激励合规**: 96.2%合规率
- ✅ **架构完整**: UVM标准架构完全实现

## 接入DUT准备事项

### 已完成项目
1. ✅ 中断向量表建模完成
2. ✅ Merge逻辑实现完成
3. ✅ 激励方法合规性验证
4. ✅ UVM架构标准化
5. ✅ 事件驱动握手机制
6. ✅ 自动化工具链完善

### 待完成事项
1. **RTL接口适配**
   - 连接实际DUT的中断信号
   - 配置正确的信号路径
   - 验证时钟域和复位逻辑

2. **时序参数调优**
   - 根据实际DUT调整激励时序
   - 优化检测窗口和超时设置
   - 配置合适的时钟频率

3. **覆盖率配置**
   - 设置功能覆盖率收集点
   - 配置断言和检查器
   - 建立覆盖率目标和报告

4. **回归测试建立**
   - 建立完整的测试套件
   - 配置CI/CD流水线
   - 设置性能基准和质量门禁

## 工具使用

### Excel转换工具
```bash
python3 tools/convert_xlsx_to_sv.py int_vector.xlsx -o seq/int_map_entries.svh
```

### 合规性检查
```bash
python3 tools/check_stimulus_compliance.py
# 生成: stimulus_compliance_report.md
```

### Merge逻辑验证
```bash
python3 tools/verify_merge_implementation.py
# 验证所有merge关系的正确实现
```

## 贡献指南

1. 遵循UVM最佳实践
2. 保持代码简洁和可读性
3. 添加充分的注释和文档
4. 运行完整的回归测试
5. 更新相关文档

## 许可证

本项目采用内部开发许可证，仅供项目团队使用。

---
*最后更新: 2025-07-16*
*版本: v2.0*
