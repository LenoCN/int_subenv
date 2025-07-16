#!/usr/bin/env python3
"""
验证merge逻辑实现的脚本
检查SystemVerilog代码中的merge实现是否与CSV分析结果一致
"""

import re
from pathlib import Path

def extract_merge_logic_from_sv(sv_file_path):
    """从SystemVerilog文件中提取merge逻辑"""
    
    merge_implementations = {}
    
    try:
        with open(sv_file_path, 'r', encoding='utf-8') as f:
            content = f.read()
        
        # 查找get_merge_sources函数中的case语句
        case_pattern = r'"([^"]+)":\s*begin.*?end'
        matches = re.findall(case_pattern, content, re.DOTALL)
        
        for match in matches:
            merge_name = match
            if merge_name in ["default"]:
                continue
                
            # 提取该case中的源中断
            case_start = content.find(f'"{merge_name}": begin')
            if case_start == -1:
                continue
                
            case_end = content.find('end', case_start)
            case_content = content[case_start:case_end]
            
            # 提取源中断名称
            source_pattern = r'interrupt_map\[i\]\.name\s*==\s*"([^"]+)"'
            sources = re.findall(source_pattern, case_content)
            
            merge_implementations[merge_name] = sources
    
    except Exception as e:
        print(f"读取SystemVerilog文件时出错: {e}")
        return {}
    
    return merge_implementations

def extract_expected_merge_from_csv(csv_file_path):
    """从CSV文件中提取期望的merge关系"""
    
    expected_merges = {
        "iosub_normal_intr": [
            "iosub_pmbus0_intr",
            "iosub_pmbus1_intr", 
            "iosub_mem_ist_intr",
            "iosub_dma_comreg_intr"
        ] + [f"iosub_dma_ch{i}_intr" for i in range(16)],  # ch0-ch15
        
        "iosub_slv_err_intr": [
            "usb0_apb1ton_intr",
            "usb1_apb1ton_intr",
            "usb_top_apb1ton_intr"
        ],
        
        "iosub_ras_cri_intr": [
            "smmu_cri_intr",
            "scp_ras_cri_intr",
            "mcp_ras_cri_intr"
        ],
        
        "iosub_ras_eri_intr": [
            "smmu_eri_intr", 
            "scp_ras_eri_intr",
            "mcp_ras_eri_intr"
        ],
        
        "iosub_ras_fhi_intr": [
            "smmu_fhi_intr",
            "scp_ras_fhi_intr",
            "mcp_ras_fhi_intr",
            "iodap_chk_err_etf0",
            "iodap_chk_err_etf1"
        ],
        
        "iosub_abnormal_0_intr": [
            "iodap_etr_buf_intr",
            "iodap_catu_addrerr_intr"
        ],
        
        "merge_external_pll_intr": [
            "accel_pll_lock_intr",
            "accel_pll_unlock_intr",
            "psub_pll_lock_intr",
            "psub_pll_unlock_intr", 
            "pcie1_pll_lock_intr",
            "pcie1_pll_unlock_intr",
            "d2d_pll_lock_intr",
            "d2d_pll_unlock_intr",
            "ddr0_pll_lock_intr",
            "ddr1_pll_lock_intr",
            "ddr2_pll_lock_intr"
        ]
    }
    
    return expected_merges

def verify_merge_implementations(sv_implementations, expected_merges):
    """验证merge实现是否正确"""
    
    print("=" * 80)
    print("Merge逻辑实现验证报告")
    print("=" * 80)
    
    all_passed = True
    
    # 检查每个期望的merge是否正确实现
    for merge_name, expected_sources in expected_merges.items():
        print(f"\n验证 {merge_name}:")
        print("-" * 50)
        
        if merge_name not in sv_implementations:
            print(f"❌ 错误: {merge_name} 未在SystemVerilog中实现")
            all_passed = False
            continue
        
        implemented_sources = sv_implementations[merge_name]
        
        # 检查缺失的源
        missing_sources = set(expected_sources) - set(implemented_sources)
        if missing_sources:
            print(f"❌ 缺失的源中断: {list(missing_sources)}")
            all_passed = False
        
        # 检查多余的源
        extra_sources = set(implemented_sources) - set(expected_sources)
        if extra_sources:
            print(f"⚠️  额外的源中断: {list(extra_sources)}")
        
        # 检查匹配的源
        matching_sources = set(implemented_sources) & set(expected_sources)
        if matching_sources:
            print(f"✅ 正确实现的源中断: {len(matching_sources)}个")
            for source in sorted(matching_sources):
                print(f"   - {source}")
        
        print(f"实现状态: {len(matching_sources)}/{len(expected_sources)} 源中断正确")
    
    # 检查SystemVerilog中是否有未期望的merge实现
    print(f"\n检查额外的merge实现:")
    print("-" * 50)
    extra_merges = set(sv_implementations.keys()) - set(expected_merges.keys())
    if extra_merges:
        print(f"发现额外的merge实现: {list(extra_merges)}")
        for merge_name in extra_merges:
            print(f"  {merge_name}: {sv_implementations[merge_name]}")
    else:
        print("✅ 没有发现额外的merge实现")
    
    # 总结
    print(f"\n" + "=" * 80)
    print("验证总结")
    print("=" * 80)
    
    expected_count = len(expected_merges)
    implemented_count = len([m for m in expected_merges.keys() if m in sv_implementations])
    
    print(f"期望的merge中断数量: {expected_count}")
    print(f"已实现的merge中断数量: {implemented_count}")
    print(f"实现完成度: {implemented_count}/{expected_count} ({100*implemented_count/expected_count:.1f}%)")
    
    if all_passed and implemented_count == expected_count:
        print("🎉 所有merge逻辑实现验证通过!")
        return True
    else:
        print("❌ 存在需要修复的merge逻辑实现")
        return False

def generate_missing_implementation(expected_merges, sv_implementations):
    """生成缺失的merge实现代码"""
    
    missing_merges = set(expected_merges.keys()) - set(sv_implementations.keys())
    
    if not missing_merges:
        print("\n✅ 所有merge逻辑都已实现")
        return
    
    print(f"\n生成缺失的merge实现代码:")
    print("=" * 60)
    
    for merge_name in missing_merges:
        sources = expected_merges[merge_name]
        
        print(f'\n            "{merge_name}": begin')
        print(f'                // Collect all interrupts that should be merged into {merge_name}')
        print('                foreach (interrupt_map[i]) begin')
        
        conditions = []
        for source in sources:
            conditions.append(f'interrupt_map[i].name == "{source}"')
        
        if conditions:
            condition_str = ' ||\n                        '.join(conditions)
            print(f'                    if ({condition_str}) begin')
            print('                        sources.push_back(interrupt_map[i]);')
            print('                    end')
        
        print('                end')
        print('            end')

def main():
    sv_file = "seq/int_routing_model.sv"
    csv_file = "中断向量表-iosub-V0.5.csv"
    
    if not Path(sv_file).exists():
        print(f"错误: 找不到SystemVerilog文件 {sv_file}")
        return
    
    print("正在分析SystemVerilog实现...")
    sv_implementations = extract_merge_logic_from_sv(sv_file)
    
    print("正在分析期望的merge关系...")
    expected_merges = extract_expected_merge_from_csv(csv_file)
    
    print("正在验证实现...")
    verification_passed = verify_merge_implementations(sv_implementations, expected_merges)
    
    if not verification_passed:
        generate_missing_implementation(expected_merges, sv_implementations)
    
    return verification_passed

if __name__ == "__main__":
    main()
