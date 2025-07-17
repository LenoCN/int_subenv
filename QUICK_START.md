# 🚀 快速开始指南

## 5分钟上手中断验证环境

### 📋 前置条件
```bash
# 检查Python版本 (需要3.6+)
python3 --version

# 安装依赖
pip install pandas openpyxl
```

### ⚡ 一键运行
```bash
# 1. 生成中断映射
python3 tools/convert_xlsx_to_sv.py int_vector.xlsx

# 2. 验证生成结果
python3 tools/test_new_system.py

# 3. 运行基础测试
make -f cfg/int.mk tc_int_routing
```

### 🔍 验证结果
```bash
# 检查合规性 (应该显示100%)
python3 tools/check_stimulus_compliance.py

# 验证merge逻辑 (应该显示12/12通过)
python3 tools/verify_merge_implementation.py
```

### ✅ 预期输出
- **中断映射**: 生成423个中断条目
- **合规性检查**: 100%通过率
- **Merge验证**: 12个merge中断全部验证通过
- **测试执行**: 所有基础测试PASS

### 🆘 常见问题

**Q: 找不到int_vector.xlsx文件**
```bash
# 检查文件是否存在
ls -la int_vector.xlsx 中断向量表-iosub-V0.5.csv
```

**Q: Python依赖安装失败**
```bash
# 使用国内镜像
pip install -i https://pypi.tuna.tsinghua.edu.cn/simple pandas openpyxl
```

**Q: 测试运行失败**
```bash
# 检查仿真器环境
which vcs  # 或 which questa_sim

# 检查环境变量
echo $VCS_HOME  # 或相应的仿真器环境变量
```

### 📚 下一步
- 阅读完整的 [README.md](README.md)
- 查看 [DUT接入清单](DUT_INTEGRATION_CHECKLIST.md)
- 了解 [项目状态](PROJECT_STATUS_SUMMARY.md)

---
*总用时: < 5分钟 | 难度: ⭐⭐☆☆☆*
