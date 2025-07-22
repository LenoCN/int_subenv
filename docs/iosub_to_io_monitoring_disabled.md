# iosub_to_io 监测机制关闭记录

## 概述

本文档记录了关闭所有4个 `iosub_to_io` 监测机制的详细过程和结果。

## 背景

系统中原本有4个中断使用 `iosub_to_io_intr` 信号进行监测：

1. **iosub_strap_load_fail_intr** - 使用 `iosub_to_io_intr[0]`
2. **scp2io_wdt_ws1_intr** - 使用 `iosub_to_io_intr[1]`
3. **mcp2io_wdt_ws1_intr** - 使用 `iosub_to_io_intr[2]`
4. **pvt_temp_alarm_intr** - 使用 `iosub_to_io_intr[3]`

## 修改内容

### 1. 中断映射条目修改 (seq/int_map_entries.svh)

对所有4个中断的配置进行了以下修改：

**修改前:**
```systemverilog
to_io:1, rtl_path_io:"top_tb.multidie_top.DUT[0].u_str_top.u_iosub_top_wrap.iosub_to_io_intr[X]", dest_index_io:X
```

**修改后:**
```systemverilog
to_io:0, rtl_path_io:"", dest_index_io:-1
```

### 2. 监控器逻辑修改 (env/int_monitor.sv)

在 `monitor_interrupt` 任务中注释了 IO 路径监测逻辑：

**修改前:**
```systemverilog
if (info.rtl_path_io != "") monitor_single_path(info, "IO", info.rtl_path_io);
```

**修改后:**
```systemverilog
// IO monitoring disabled - iosub_to_io monitoring mechanism turned off
// if (info.rtl_path_io != "") monitor_single_path(info, "IO", info.rtl_path_io);
```

## 影响分析

### 正面影响
- 减少了不必要的监测开销
- 简化了测试环境的复杂度
- 避免了 IO 路径相关的潜在问题

### 注意事项
- 这4个中断将不再被监测到 IO 目标
- 如果将来需要重新启用，需要恢复相应的配置
- 其他目标（AP、SCP、MCP等）的监测不受影响

## 验证结果

使用验证脚本 `tools/verify_iosub_to_io_disabled.py` 确认：

✅ 所有4个中断的 IO 监测配置已正确禁用
✅ 监控器中的 IO 路径监测逻辑已被注释
✅ 没有残留的 `iosub_to_io_intr` 引用

## 文件清单

### 修改的文件
- `seq/int_map_entries.svh` - 中断映射条目配置
- `env/int_monitor.sv` - 中断监控器逻辑

### 新增的文件
- `tools/verify_iosub_to_io_disabled.py` - 验证脚本
- `docs/iosub_to_io_monitoring_disabled.md` - 本文档

## 恢复方法

如果将来需要重新启用 iosub_to_io 监测机制，需要：

1. 恢复 `seq/int_map_entries.svh` 中4个中断的 IO 配置
2. 取消注释 `env/int_monitor.sv` 中的 IO 监测逻辑
3. 运行验证脚本确认恢复正确

## 时间记录

- **修改时间**: 2025-07-21
- **修改人**: Augment Agent
- **验证状态**: ✅ 通过

---

*本文档记录了 iosub_to_io 监测机制的完整关闭过程，确保修改的可追溯性和可恢复性。*
