#!/bin/bash
# update_interrupt_files.sh
# 
# 自动化中断验证文件更新脚本
# 当Excel表格或hierarchy信号层次有更新时，使用此脚本重新生成SystemVerilog文件
#
# 用法: ./update_interrupt_files.sh [options]
#   -e, --excel FILE     指定Excel输入文件
#   -h, --hierarchy      只更新hierarchy路径（跳过Excel处理）
#   -v, --validate       运行验证测试
#   --help              显示帮助信息

set -e  # 遇到错误立即退出

# 默认配置
WORKSPACE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
EXCEL_FILE=""
HIERARCHY_ONLY=false
RUN_VALIDATION=false
BACKUP_DIR="$WORKSPACE_DIR/backup/$(date +%Y%m%d_%H%M%S)"

# 颜色输出
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# 日志函数
log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# 显示帮助信息
show_help() {
    cat << EOF
中断验证文件更新脚本

用法: $0 [选项]

选项:
    -e, --excel FILE     指定Excel输入文件路径
    -h, --hierarchy      只更新hierarchy路径（跳过Excel处理）
    -v, --validate       运行验证测试
    --help              显示此帮助信息

示例:
    # 从Excel文件完整更新
    $0 -e interrupt_spec.xlsx -v
    
    # 只更新hierarchy路径
    $0 -h -v
    
    # 只从Excel更新，不运行验证
    $0 -e interrupt_spec.xlsx

文件说明:
    输入文件: Excel表格 (可选)
    输出文件: seq/int_map_entries.svh
    工具文件: tools/generate_signal_paths.py, tools/update_rtl_paths.py
    备份目录: backup/YYYYMMDD_HHMMSS/

EOF
}

# 解析命令行参数
parse_args() {
    while [[ $# -gt 0 ]]; do
        case $1 in
            -e|--excel)
                EXCEL_FILE="$2"
                shift 2
                ;;
            -h|--hierarchy)
                HIERARCHY_ONLY=true
                shift
                ;;
            -v|--validate)
                RUN_VALIDATION=true
                shift
                ;;
            --help)
                show_help
                exit 0
                ;;
            *)
                log_error "未知选项: $1"
                show_help
                exit 1
                ;;
        esac
    done
}

# 创建备份
create_backup() {
    log_info "创建备份到 $BACKUP_DIR"
    mkdir -p "$BACKUP_DIR"
    
    # 备份关键文件
    if [ -f "$WORKSPACE_DIR/seq/int_map_entries.svh" ]; then
        cp "$WORKSPACE_DIR/seq/int_map_entries.svh" "$BACKUP_DIR/"
        log_success "已备份 int_map_entries.svh"
    fi
    
    if [ -f "$WORKSPACE_DIR/seq/int_routing_model.sv" ]; then
        cp "$WORKSPACE_DIR/seq/int_routing_model.sv" "$BACKUP_DIR/"
        log_success "已备份 int_routing_model.sv"
    fi
}

# 检查必要的工具和文件
check_prerequisites() {
    log_info "检查必要的工具和文件..."
    
    # 检查Python
    if ! command -v python3 &> /dev/null; then
        log_error "Python3 未找到，请安装Python3"
        exit 1
    fi
    
    # 检查工具文件
    local tools=("tools/generate_signal_paths.py" "tools/update_rtl_paths.py")
    for tool in "${tools[@]}"; do
        if [ ! -f "$WORKSPACE_DIR/$tool" ]; then
            log_error "工具文件不存在: $tool"
            exit 1
        fi
    done
    
    # 如果指定了Excel文件，检查是否存在
    if [ -n "$EXCEL_FILE" ] && [ ! -f "$EXCEL_FILE" ]; then
        log_error "Excel文件不存在: $EXCEL_FILE"
        exit 1
    fi
    
    # 检查excel_to_sv.py工具（如果需要处理Excel）
    if [ -n "$EXCEL_FILE" ] && [ ! -f "$WORKSPACE_DIR/tools/excel_to_sv.py" ]; then
        log_error "Excel转换工具不存在: tools/excel_to_sv.py"
        exit 1
    fi
    
    log_success "所有必要工具和文件检查通过"
}

# 从Excel生成中断映射条目
generate_from_excel() {
    if [ -z "$EXCEL_FILE" ]; then
        log_info "跳过Excel处理（未指定Excel文件）"
        return 0
    fi
    
    log_info "从Excel文件生成中断映射条目: $EXCEL_FILE"
    
    cd "$WORKSPACE_DIR"
    python3 tools/excel_to_sv.py "$EXCEL_FILE" seq/int_map_entries.svh
    
    if [ $? -eq 0 ]; then
        log_success "成功从Excel生成中断映射条目"
    else
        log_error "从Excel生成中断映射条目失败"
        exit 1
    fi
}

# 更新RTL路径
update_rtl_paths() {
    log_info "使用hierarchy信息更新RTL路径..."
    
    cd "$WORKSPACE_DIR"
    python3 tools/update_rtl_paths.py
    
    if [ $? -eq 0 ]; then
        log_success "成功更新RTL路径"
    else
        log_error "更新RTL路径失败"
        exit 1
    fi
}

# 验证生成的文件
validate_files() {
    log_info "验证生成的文件..."
    
    cd "$WORKSPACE_DIR"
    
    # 检查文件是否存在
    if [ ! -f "seq/int_map_entries.svh" ]; then
        log_error "生成的文件不存在: seq/int_map_entries.svh"
        exit 1
    fi
    
    # 检查文件是否为空
    if [ ! -s "seq/int_map_entries.svh" ]; then
        log_error "生成的文件为空: seq/int_map_entries.svh"
        exit 1
    fi
    
    # 统计信息
    local total_entries=$(grep -c "interrupt_map.push_back(entry);" seq/int_map_entries.svh || echo "0")
    local empty_src_paths=$(grep -c 'rtl_path_src:""' seq/int_map_entries.svh || echo "0")
    local scp_paths=$(grep -c 'iosub_to_scp_intr' seq/int_map_entries.svh || echo "0")
    local mcp_paths=$(grep -c 'iosub_to_mcp_intr' seq/int_map_entries.svh || echo "0")
    
    log_info "文件统计信息:"
    log_info "  总中断条目数: $total_entries"
    log_info "  空源路径数: $empty_src_paths"
    log_info "  SCP目标路径数: $scp_paths"
    log_info "  MCP目标路径数: $mcp_paths"
    
    if [ "$empty_src_paths" -gt 0 ]; then
        log_warning "发现 $empty_src_paths 个空的源路径，请检查hierarchy配置"
    fi
    
    log_success "文件验证完成"
}

# 运行编译和测试验证
run_validation_tests() {
    if [ "$RUN_VALIDATION" = false ]; then
        log_info "跳过验证测试"
        return 0
    fi
    
    log_info "运行验证测试..."
    
    cd "$WORKSPACE_DIR"
    
    # 检查是否有Makefile
    if [ ! -f "Makefile" ]; then
        log_warning "未找到Makefile，跳过编译测试"
        return 0
    fi
    
    # 尝试编译
    log_info "运行编译检查..."
    if make compile > /dev/null 2>&1; then
        log_success "编译检查通过"
    else
        log_warning "编译检查失败，请手动检查生成的文件"
    fi
    
    # 尝试运行基本测试
    log_info "运行基本中断测试..."
    if make test TEST=basic_interrupt_test > /dev/null 2>&1; then
        log_success "基本测试通过"
    else
        log_warning "基本测试失败，请手动验证功能"
    fi
}

# 显示更新摘要
show_summary() {
    log_info "更新摘要:"
    log_info "  工作目录: $WORKSPACE_DIR"
    log_info "  备份目录: $BACKUP_DIR"
    
    if [ -n "$EXCEL_FILE" ]; then
        log_info "  Excel文件: $EXCEL_FILE"
    fi
    
    if [ "$HIERARCHY_ONLY" = true ]; then
        log_info "  更新模式: 仅hierarchy路径"
    else
        log_info "  更新模式: 完整更新"
    fi
    
    log_info "  生成文件: seq/int_map_entries.svh"
    
    if [ -f "$WORKSPACE_DIR/seq/int_map_entries.svh.backup" ]; then
        log_info "  自动备份: seq/int_map_entries.svh.backup"
    fi
    
    log_success "所有更新操作完成！"
}

# 主函数
main() {
    log_info "开始中断验证文件更新流程..."
    
    # 解析参数
    parse_args "$@"
    
    # 检查先决条件
    check_prerequisites
    
    # 创建备份
    create_backup
    
    # 执行更新步骤
    if [ "$HIERARCHY_ONLY" = false ]; then
        generate_from_excel
    fi
    
    update_rtl_paths
    
    # 验证结果
    validate_files
    run_validation_tests
    
    # 显示摘要
    show_summary
}

# 运行主函数
main "$@"
