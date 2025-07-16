# Excel中断向量表转换系统

## 概述

本系统将之前基于CSV的中断信息生成方式升级为基于Excel的多页签方式，能够自动提取更加全面的中断源与目的地信号映射关系。

## Excel文件结构

### 主要页签

1. **IOSUB中断源** - 汇总所有路由信息的主页签
2. **iosub-to-AP中断列表** - AP目的地视角的中断排序
3. **SCP M7中断列表** - SCP目的地视角的中断排序  
4. **MCP M7中断列表** - MCP目的地视角的中断排序
5. **iosub-to-IMU中断列表** - IMU目的地视角的中断排序
6. **iosub-to-IO** - IO目的地视角的中断排序
7. **跨die中断列表** - 跨DIE目的地视角的中断排序

### 数据结构

每个中断源都有：
- **固定层次的多比特信号** - 连接到各个目的地
- **具体的bit位置** - 在目的地多比特信号中的位置
- **完整的路由信息** - 包含所有可能的目的地

## 核心功能

### 1. 自动映射提取

系统能够自动从Excel文件中提取：
- 中断源信息（名称、索引、组、触发方式、极性）
- 路由方向信息（to AP/SCP/MCP/IMU/IO/OTHER_DIE）
- 目的地索引信息（在各目的地中断向量中的具体位置）

### 2. 完整信号层次

生成的SystemVerilog文件包含：
```systemverilog
entry = '{
    name:"psub_normal3_intr", 
    index:6, 
    group:PSUB, 
    trigger:LEVEL, 
    polarity:ACTIVE_HIGH, 
    rtl_path_src:"", 
    to_ap:1, 
    rtl_path_ap:"// iosub-to-AP中断列表[110]", 
    dest_index_ap:110, 
    to_scp:1, 
    rtl_path_scp:"// SCP M7中断列表[173]", 
    dest_index_scp:173, 
    to_mcp:1, 
    rtl_path_mcp:"// MCP M7中断列表[147]", 
    dest_index_mcp:147, 
    to_imu:0, 
    rtl_path_imu:"", 
    dest_index_imu:-1, 
    to_io:0, 
    rtl_path_io:"", 
    dest_index_io:-1, 
    to_other_die:0, 
    rtl_path_other_die:"", 
    dest_index_other_die:-1
}; interrupt_map.push_back(entry);
```

## 使用方法

### 1. 转换Excel到SystemVerilog

```bash
# 生成include文件（推荐方式）
python3 convert_xlsx_to_sv.py int_vector.xlsx -o seq/int_map_entries.svh

# 或者使用默认输出路径
python3 convert_xlsx_to_sv.py int_vector.xlsx
```

### 2. 文件结构

新的系统采用分离式设计：

- **主文件**: `seq/int_routing_model.sv` - 包含类定义和merge逻辑
- **数据文件**: `seq/int_map_entries.svh` - 包含从Excel生成的中断条目
- **数据结构**: `seq/int_def.sv` - 包含数据结构定义

### 3. 数据结构

`int_def.sv` 中的 `interrupt_info_s` 结构已更新，包含目的地索引字段：
```systemverilog
typedef struct {
    string               name;
    int                  index;
    interrupt_group_e    group;
    interrupt_trigger_e  trigger;
    interrupt_polarity_e polarity;
    string               rtl_path_src;

    // 目的地路由信息和索引
    bit                  to_ap;
    string               rtl_path_ap;
    int                  dest_index_ap;      // AP目的地索引
    bit                  to_scp;
    string               rtl_path_scp;
    int                  dest_index_scp;     // SCP目的地索引
    bit                  to_mcp;
    string               rtl_path_mcp;
    int                  dest_index_mcp;     // MCP目的地索引
    bit                  to_imu;
    string               rtl_path_imu;
    int                  dest_index_imu;     // IMU目的地索引
    bit                  to_io;
    string               rtl_path_io;
    int                  dest_index_io;      // IO目的地索引
    bit                  to_other_die;
    string               rtl_path_other_die;
    int                  dest_index_other_die; // 跨DIE目的地索引
} interrupt_info_s;
```

## 示例：psub_normal3_intr映射

### Excel中的信息
- **主表**: 索引6，路由到AP/SCP/MCP均为YES
- **AP页签**: 在位置110
- **SCP页签**: 在位置173  
- **MCP页签**: 在位置147

### 生成的映射
- **组**: PSUB
- **源索引**: 6
- **AP目的地**: 索引110 (iosub-to-AP中断列表[110])
- **SCP目的地**: 索引173 (SCP M7中断列表[173])
- **MCP目的地**: 索引147 (MCP M7中断列表[147])

## 与CSV方式的改进

### 优势
1. **多页签支持** - 不同目的地视角的完整信息
2. **自动索引提取** - 无需手动维护目的地索引
3. **完整信号层次** - RTL层次下的具体信号映射
4. **易于维护** - 集中管理所有中断信息
5. **扩展性强** - 支持新增目的地和中断源

### 统计信息
- **总中断数**: 421个
- **支持的组**: 15个（IOSUB, USB, SCP, MCP, SMMU, IODAP, ACCEL, CSUB, PSUB, PCIE1, D2D, DDR0, DDR1, DDR2, IO_DIE）
- **目的地映射**: 
  - AP: 204个映射
  - SCP: 227个映射  
  - MCP: 161个映射

## 文件说明

- `convert_xlsx_to_sv.py` - Excel转换脚本
- `int_vector.xlsx` - 输入的Excel文件
- `seq/int_routing_model.sv` - 主SystemVerilog文件（包含类定义和merge逻辑）
- `seq/int_map_entries.svh` - 自动生成的中断条目include文件
- `seq/int_def.sv` - 数据结构定义
- `demo_xlsx_mapping.py` - 演示脚本
- `test_new_system.py` - 系统测试脚本

## 工作流程

1. **Excel更新** → 修改 `int_vector.xlsx` 文件
2. **运行转换** → `python3 convert_xlsx_to_sv.py int_vector.xlsx`
3. **自动生成** → 更新 `seq/int_map_entries.svh` 文件
4. **保持不变** → `seq/int_routing_model.sv` 主文件保持merge逻辑不变
5. **验证测试** → `python3 test_new_system.py` 验证生成结果

## 验证和测试

系统生成的映射可用于：
- RTL仿真中的信号路径验证
- 中断路由的自动化测试  
- 系统级验证环境的配置
- 软件驱动的中断处理验证
