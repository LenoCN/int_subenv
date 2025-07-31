#!/usr/bin/env python3
"""
验证ACCEL以及其他子系统mask实现的脚本
确保新增的mask处理逻辑正确实现
"""

import re
import sys
from pathlib import Path

def check_register_model_mask_support():
    """检查寄存器模型中的mask支持"""
    register_model_path = Path("seq/int_register_model.sv")
    
    if not register_model_path.exists():
        print("❌ 寄存器模型文件不存在")
        return False
    
    content = register_model_path.read_text()
    
    # 检查ACCEL mask处理
    accel_checks = [
        r'"ACCEL":\s*begin',
        r'ADDR_MASK_IOSUB_TO_ACCEL_INTR_0',
        r'dest_index.*ACCEL',
    ]
    
    print("🔍 检查ACCEL mask处理...")
    for check in accel_checks:
        if re.search(check, content):
            print(f"  ✅ 找到: {check}")
        else:
            print(f"  ❌ 缺失: {check}")
            return False
    
    # 检查PSUB mask处理
    psub_checks = [
        r'"PSUB":\s*begin',
        r'ADDR_MASK_PSUB_TO_IOSUB_INTR',
        r'sub_index.*PSUB',
    ]
    
    print("🔍 检查PSUB mask处理...")
    for check in psub_checks:
        if re.search(check, content):
            print(f"  ✅ 找到: {check}")
        else:
            print(f"  ❌ 缺失: {check}")
            return False
    
    # 检查PCIE1 mask处理
    pcie1_checks = [
        r'"PCIE1":\s*begin',
        r'ADDR_MASK_PCIE1_TO_IOSUB_INTR',
        r'sub_index.*PCIE1',
    ]
    
    print("🔍 检查PCIE1 mask处理...")
    for check in pcie1_checks:
        if re.search(check, content):
            print(f"  ✅ 找到: {check}")
        else:
            print(f"  ❌ 缺失: {check}")
            return False
    
    # 检查CSUB mask处理
    csub_checks = [
        r'"CSUB":\s*begin',
        r'CSUB.*SCP/MCP.*mask.*logic',
    ]
    
    print("🔍 检查CSUB mask处理...")
    for check in csub_checks:
        if re.search(check, content):
            print(f"  ✅ 找到: {check}")
        else:
            print(f"  ❌ 缺失: {check}")
            return False
    
    return True

def check_routing_model_support():
    """检查路由模型中的新子系统支持"""
    routing_model_path = Path("seq/int_routing_model.sv")
    
    if not routing_model_path.exists():
        print("❌ 路由模型文件不存在")
        return False
    
    content = routing_model_path.read_text()
    
    # 检查目标列表是否包含新子系统
    destinations_check = r'all_destinations.*=.*\{.*"ACCEL".*"PSUB".*"PCIE1".*"CSUB".*\}'
    
    print("🔍 检查路由模型目标支持...")
    if re.search(destinations_check, content, re.DOTALL):
        print("  ✅ 找到所有新增目标")
    else:
        print("  ❌ 缺失新增目标")
        return False
    
    # 检查路由状态检查逻辑
    routing_checks = [
        r'"ACCEL":\s*base_routing\s*=\s*info\.to_accel',
        r'"PSUB":\s*base_routing\s*=.*info\.group\s*==\s*PSUB',
        r'"PCIE1":\s*base_routing\s*=.*info\.group\s*==\s*PCIE1',
        r'"CSUB":\s*base_routing\s*=.*info\.group\s*==\s*CSUB',
    ]
    
    print("🔍 检查路由状态逻辑...")
    for check in routing_checks:
        if re.search(check, content):
            print(f"  ✅ 找到路由逻辑")
        else:
            print(f"  ❌ 缺失路由逻辑: {check}")
            return False
    
    return True

def check_register_addresses():
    """检查寄存器地址定义"""
    register_model_path = Path("seq/int_register_model.sv")
    content = register_model_path.read_text()
    
    # 检查关键寄存器地址
    address_checks = [
        (r'ADDR_MASK_IOSUB_TO_ACCEL_INTR_0\s*=\s*32\'h0001_C0A0', "ACCEL mask寄存器"),
        (r'ADDR_MASK_PSUB_TO_IOSUB_INTR\s*=\s*32\'h0001_C0B8', "PSUB mask寄存器"),
        (r'ADDR_MASK_PCIE1_TO_IOSUB_INTR\s*=\s*32\'h0001_C0BC', "PCIE1 mask寄存器"),
    ]
    
    print("🔍 检查寄存器地址定义...")
    for check, desc in address_checks:
        if re.search(check, content):
            print(f"  ✅ {desc}: 地址正确")
        else:
            print(f"  ❌ {desc}: 地址缺失或错误")
            return False
    
    return True

def check_mask_randomization():
    """检查mask寄存器随机化"""
    register_model_path = Path("seq/int_register_model.sv")
    content = register_model_path.read_text()
    
    # 检查随机化逻辑
    randomization_checks = [
        r'write_register\(ADDR_MASK_IOSUB_TO_ACCEL_INTR_0',
        r'write_register\(ADDR_MASK_PSUB_TO_IOSUB_INTR',
        r'write_register\(ADDR_MASK_PCIE1_TO_IOSUB_INTR',
    ]
    
    print("🔍 检查mask寄存器随机化...")
    for check in randomization_checks:
        if re.search(check, content):
            print(f"  ✅ 找到随机化逻辑")
        else:
            print(f"  ❌ 缺失随机化逻辑: {check}")
            return False
    
    return True

def check_print_config_support():
    """检查打印配置函数是否支持新寄存器"""
    register_model_path = Path("seq/int_register_model.sv")
    content = register_model_path.read_text()
    
    # 检查打印配置
    print_checks = [
        r'IOSUB->ACCEL\s+Mask',
        r'read_register\(ADDR_MASK_IOSUB_TO_ACCEL_INTR_0',
    ]
    
    print("🔍 检查打印配置支持...")
    for check in print_checks:
        if re.search(check, content):
            print(f"  ✅ 找到打印配置")
        else:
            print(f"  ❌ 缺失打印配置: {check}")
            return False
    
    return True

def main():
    """主函数"""
    print("🚀 开始验证ACCEL及其他子系统mask实现...")
    print("=" * 60)
    
    all_passed = True
    
    # 执行各项检查
    checks = [
        ("寄存器模型mask支持", check_register_model_mask_support),
        ("路由模型支持", check_routing_model_support),
        ("寄存器地址定义", check_register_addresses),
        ("mask寄存器随机化", check_mask_randomization),
        ("打印配置支持", check_print_config_support),
    ]
    
    for check_name, check_func in checks:
        print(f"\n📋 {check_name}:")
        if check_func():
            print(f"✅ {check_name}: 通过")
        else:
            print(f"❌ {check_name}: 失败")
            all_passed = False
    
    print("\n" + "=" * 60)
    if all_passed:
        print("🎉 所有检查通过！ACCEL及其他子系统mask实现正确。")
        return 0
    else:
        print("💥 部分检查失败，请检查实现。")
        return 1

if __name__ == "__main__":
    sys.exit(main())
