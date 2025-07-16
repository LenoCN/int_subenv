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
if { (![info exists ::env(GUI)] ) || ($env(GUI) == "off") || ($env(GUI) == "") } {
    run
}
