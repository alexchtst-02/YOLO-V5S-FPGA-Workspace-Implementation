# Wait for the inference to finish, then read the three Detect output tensors from the board through JTAG-AXI.
# Run after pressing BTN0:
#   source -notrace retrieving_tensor.tcl
# Output files in this folder: status.txt, det0.txt, det1.txt, det2.txt (read by post_processing.ipynb)

namespace eval cnp {
    variable dir [file dirname [file normalize [info script]]]
    variable axi [lindex [get_hw_axis] 0]
    variable wr_rev 0
    variable rd_rev 0
}

proc cnp::hex8 {v} { return [format %08X [expr {$v & 0xFFFFFFFF}]] }

proc cnp::wr {addr words} {
    variable axi
    variable wr_rev
    set n [llength $words]
    if {$wr_rev} { set words [lreverse $words] }
    create_hw_axi_txn -force cnp_wr $axi -type write -address [hex8 $addr] -len $n -burst INCR -data [join $words _]
    run_hw_axi -quiet [get_hw_axi_txns cnp_wr]
}

proc cnp::rd_raw {addr n} {
    variable axi
    create_hw_axi_txn -force cnp_rd $axi -type read -address [hex8 $addr] -len $n -burst INCR
    run_hw_axi -quiet [get_hw_axi_txns cnp_rd]
    set d [string toupper [string map {_ "" " " "" "\n" ""} [get_property DATA [get_hw_axi_txns cnp_rd]]]]
    if {[string length $d] != 8 * $n} { error "read returned [string length $d] hex digits, expected [expr {8 * $n}]" }
    set words {}
    for {set i 0} {$i < $n} {incr i} { lappend words [string range $d [expr {8 * $i}] [expr {8 * $i + 7}]] }
    return $words
}

proc cnp::rd {addr n} {
    variable rd_rev
    set w [rd_raw $addr $n]
    if {$rd_rev} { set w [lreverse $w] }
    return $w
}

# detect the word order JTAG-AXI uses inside a burst
proc cnp::check_order {} {
    variable wr_rev
    variable rd_rev
    set a 0x0FF00000
    set pat {11111111 22222222 33333333 44444444}
    for {set i 0} {$i < 4} {incr i} { wr [expr {$a + 4 * $i}] [list [lindex $pat $i]] }
    set raw [rd_raw $a 4]
    if {$raw eq $pat} { set rd_rev 0 } elseif {$raw eq [lreverse $pat]} { set rd_rev 1 } else { error "read order test failed: $raw" }
    set pat2 {AAAA0000 BBBB1111 CCCC2222 DDDD3333}
    set wr_rev 0
    wr $a $pat2
    set got {}
    for {set i 0} {$i < 4} {incr i} { lappend got [lindex [rd_raw [expr {$a + 4 * $i}] 1] 0] }
    if {$got eq $pat2} { set wr_rev 0 } elseif {$got eq [lreverse $pat2]} { set wr_rev 1 } else { error "write order test failed: $got" }
}

proc cnp::read_region {name addr nbytes} {
    variable dir
    set t0 [clock seconds]
    set fh [open [file join $dir "$name.txt"] w]
    set a $addr
    set end [expr {$addr + $nbytes}]
    while {$a < $end} {
        set nxt [expr {min($end, ($a / 1024 + 1) * 1024)}]
        puts $fh "[hex8 $a] [join [rd $a [expr {($nxt - $a) / 4}]] { }]"
        set a $nxt
    }
    close $fh
    puts "$name.txt: $nbytes bytes ([expr {[clock seconds] - $t0}] s)"
}

if {$cnp::axi eq ""} { error "no hw_axi found: program the device with the .bit and .ltx files, then refresh_hw_device" }
reset_hw_axi $cnp::axi
cnp::check_order

# wait for the status block written at the end of the run (up to 300 s)
set t0 [clock seconds]
while {1} {
    set w [cnp::rd 0x00FFFF00 8]
    if {[lindex $w 0] eq "C0DE0001"} { break }
    if {[clock seconds] - $t0 > 300} { error "no result after 300 s: was sending_image.tcl run and BTN0 pressed?" }
    after 500
}
set cyc [scan [lindex $w 4] %x]
set flags [scan [lindex $w 1] %x]
puts [format "inference: %d cycles = %.2f ms at 100 MHz" $cyc [expr {$cyc / 1.0e5}]]
puts "error [expr {($flags >> 1) & 1}], code [scan [lindex $w 2] %x], pc [scan [lindex $w 3] %x]"

set fh [open [file join $cnp::dir status.txt] w]
puts $fh "[cnp::hex8 0x00FFFF00] [join $w { }]"
close $fh

if {($flags >> 1) & 1} { error "the run stopped with an error, tensors were not read" }
foreach {name addr nbytes} {det0 0x06AE0000 5242880 det1 0x06FE0000 1310720 det2 0x07120000 327680} {
    cnp::read_region $name $addr $nbytes
}
puts "tensors retrieved. Next: run post_processing.ipynb"
