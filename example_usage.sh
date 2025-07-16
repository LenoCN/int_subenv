#!/bin/bash

# Excel中断向量表转换系统使用示例
# 
# 此脚本演示如何使用新的Excel转换系统

echo "=== Excel中断向量表转换系统 ==="
echo

# 1. 检查输入文件
echo "1. 检查输入文件..."
if [ ! -f "int_vector.xlsx" ]; then
    echo "❌ 错误: 找不到 int_vector.xlsx 文件"
    exit 1
fi
echo "✓ 找到 int_vector.xlsx 文件"

# 2. 运行转换脚本
echo
echo "2. 运行Excel转换脚本..."
python3 convert_xlsx_to_sv.py int_vector.xlsx -o seq/int_map_entries.svh

if [ $? -eq 0 ]; then
    echo "✓ 转换成功完成"
else
    echo "❌ 转换失败"
    exit 1
fi

# 3. 检查生成的文件
echo
echo "3. 检查生成的文件..."
if [ ! -f "seq/int_map_entries.svh" ]; then
    echo "❌ 错误: 未生成 int_map_entries.svh 文件"
    exit 1
fi
echo "✓ 生成了 seq/int_map_entries.svh 文件"

if [ ! -f "seq/int_routing_model.sv" ]; then
    echo "❌ 错误: 找不到 int_routing_model.sv 主文件"
    exit 1
fi
echo "✓ 找到 seq/int_routing_model.sv 主文件"

# 4. 统计生成的中断数量
echo
echo "4. 统计生成的中断数量..."
interrupt_count=$(grep -c "interrupt_map.push_back(entry);" seq/int_map_entries.svh)
echo "✓ 生成了 $interrupt_count 个中断条目"

# 5. 验证特定中断映射
echo
echo "5. 验证 psub_normal3_intr 映射..."
if grep -q "psub_normal3_intr.*group:PSUB.*dest_index_ap:110.*dest_index_scp:173.*dest_index_mcp:147" seq/int_map_entries.svh; then
    echo "✓ psub_normal3_intr 映射验证通过"
    echo "  - 组: PSUB"
    echo "  - AP目的地索引: 110"
    echo "  - SCP目的地索引: 173"
    echo "  - MCP目的地索引: 147"
else
    echo "❌ psub_normal3_intr 映射验证失败"
    exit 1
fi

# 6. 运行系统测试
echo
echo "6. 运行系统测试..."
python3 test_new_system.py

if [ $? -eq 0 ]; then
    echo "✓ 系统测试通过"
else
    echo "❌ 系统测试失败"
    exit 1
fi

# 7. 显示文件信息
echo
echo "7. 生成的文件信息:"
echo "   主文件: seq/int_routing_model.sv ($(wc -l < seq/int_routing_model.sv) 行)"
echo "   数据文件: seq/int_map_entries.svh ($(wc -l < seq/int_map_entries.svh) 行)"
echo "   数据结构: seq/int_def.sv ($(wc -l < seq/int_def.sv) 行)"

echo
echo "🎉 Excel转换系统使用示例完成！"
echo
echo "使用说明:"
echo "1. 修改 int_vector.xlsx 文件中的中断信息"
echo "2. 运行: python3 convert_xlsx_to_sv.py int_vector.xlsx"
echo "3. 生成的 seq/int_map_entries.svh 会自动更新"
echo "4. seq/int_routing_model.sv 主文件保持不变"
echo "5. 运行: python3 test_new_system.py 验证结果"
