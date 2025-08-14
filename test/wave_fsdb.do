# ************************* JaguarMicro Confidential *************************
#https://blog.csdn.net/moon9999/article/details/108034192
#https:www.francisz.cn/2019/08/29/fsdb-dump/
# tcl language
if {[info exists ::env(WAVE)] && $env(WAVE) == "fsdb"} {
    puts "\$env(WAVE) :$env(WAVE)"
    call {$fsdbDumpvars(15,"top_tb","+all")}
    if {[info exists ::env(MEM)] && $env(MEM) == "on"} {
        call \$fsdbDumpMDA 15 "top_tb"
    }
    if {[info exists ::env(SVA)] && $env(SVA) == "on"} {
        call \$fsdbDumpSVA 0 "top_tb"
    }
}
force {top_tb.multidie_top.DUT[0].u_str_top.u_iosub_top_wrap.u0_iosub_top_wrap_hd.u0_iosub_top_wrap_raw.u_iosub_crg_sub.u_ioctl_crg_wrapper.u_ioctl_crg.u_mcp_crg.csr_mcp_sys_rst_n} {1} -freeze
force {top_tb.multidie_top.DUT[0].u_str_top.u_iosub_top_wrap.u0_iosub_top_wrap_hd.u0_iosub_top_wrap_raw.u_iosub_crg_sub.u_ioctl_crg_wrapper.u_ioctl_crg.u_mcp_crg.csr_mcp_sys_clk_en} {1} -freeze
force {top_tb.multidie_top.DUT[0].u_str_top.u_iosub_top_wrap.u0_iosub_top_wrap_hd.u0_iosub_top_wrap_raw.u_iosub_crg_sub.u_ioctl_crg_wrapper.u_ioctl_crg.u_mcp_crg.csr_mcp_cpu_rst_n} {1} -freeze
force {top_tb.multidie_top.DUT[0].u_str_top.u_iosub_top_wrap.u0_iosub_top_wrap_hd.u0_iosub_top_wrap_raw.u_iosub_crg_sub.u_ioctl_crg_wrapper.u_ioctl_crg.u_mcp_crg.csr_mcp_cpu_clk_en} {1} -freeze
if { (![info exists ::env(GUI)] ) || ($env(GUI) == "off") || ($env(GUI) == "") } {
    run
}
