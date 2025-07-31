#!/usr/bin/env python3
"""
验证IMU到ACCEL迁移的完整性检查脚本

本脚本检查所有文件中是否还有残留的IMU引用，确保统一使用ACCEL。

作者: AI Assistant
日期: 2025-07-31
"""

import os
import re
from pathlib import Path

def check_file_for_imu_references(file_path):
    """检查单个文件中的IMU引用"""
    try:
        with open(file_path, 'r', encoding='utf-8') as f:
            content = f.read()
        
        # 查找可能的IMU引用（排除注释中的历史引用）
        imu_patterns = [
            r'\bto_imu\b',
            r'\bdest_index_imu\b',
            r'\brtl_path_imu\b',
            r'"IMU"(?!.*中断列表)',  # 排除Excel表名中的IMU
            r"'IMU'(?!.*中断列表)",  # 排除Excel表名中的IMU
            r'\bIMU\b(?!.*中断列表)',  # 排除Excel表名中的IMU

        ]
        
        issues = []
        lines = content.split('\n')
        
        for i, line in enumerate(lines, 1):
            # 跳过注释行和文档中的历史说明
            if line.strip().startswith('//') or line.strip().startswith('#'):
                continue
            if 'iosub-to-IMU中断列表' in line or 'iosub-to-IMU' in line:  # Excel表名保持不变
                continue
            if 'IMU WS1' in line or 'imu_ws1' in line:  # 信号名保持不变
                continue
            if 'imu2scp' in line or 'scp2imu' in line or 'imu2mcp' in line or 'mcp2imu' in line:  # MHU信号名保持不变
                continue
            if 'imu_to_accel_unification_summary.md' in file_path.name:  # 跳过统一总结文档
                continue
                
            for pattern in imu_patterns:
                if re.search(pattern, line, re.IGNORECASE):
                    issues.append(f"Line {i}: {line.strip()}")
        
        return issues
        
    except Exception as e:
        return [f"Error reading file: {e}"]

def main():
    """主函数"""
    print("🔍 检查IMU到ACCEL迁移完整性...")
    
    # 需要检查的文件类型
    file_patterns = [
        "**/*.sv", "**/*.svh", "**/*.py", "**/*.json", "**/*.md"
    ]
    
    # 排除的目录
    exclude_dirs = {'.git', '__pycache__', '.pytest_cache'}
    
    total_issues = 0
    files_with_issues = 0
    
    for pattern in file_patterns:
        for file_path in Path('.').glob(pattern):
            # 跳过排除的目录
            if any(exclude_dir in file_path.parts for exclude_dir in exclude_dirs):
                continue
                
            issues = check_file_for_imu_references(file_path)
            if issues:
                files_with_issues += 1
                total_issues += len(issues)
                print(f"\n❌ {file_path}:")
                for issue in issues:
                    print(f"  {issue}")
    
    print(f"\n📊 检查结果:")
    print(f"  文件总数: {len(list(Path('.').glob('**/*')))}")
    print(f"  有问题的文件: {files_with_issues}")
    print(f"  问题总数: {total_issues}")
    
    if total_issues == 0:
        print("🎉 所有检查通过！IMU到ACCEL迁移完成。")
        return True
    else:
        print("⚠️  发现残留的IMU引用，需要进一步修复。")
        return False

if __name__ == "__main__":
    success = main()
    exit(0 if success else 1)
