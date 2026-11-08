# Send the image prepared by preparation.ipynb (frame_load.txt) to the board through JTAG-AXI.
# Run after sending_param.tcl, then press BTN0 to start inference:
#   source -notrace sending_image.tcl

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

proc cnp::load_file {path} {
    set fh [open $path r]
    set i 0
    set t0 [clock seconds]
    while {[gets $fh line] >= 0} {
        wr [scan [lindex $line 0] %x] [lrange $line 1 end]
        if {[incr i] % 1000 == 0} { puts "$i transactions ([expr {[clock seconds] - $t0}] s)" }
    }
    close $fh
    puts "$i transactions done ([expr {[clock seconds] - $t0}] s)"
}

# read back every 50th transaction and compare
proc cnp::verify_file {path} {
    set fh [open $path r]
    set i 0
    set bad 0
    while {[gets $fh line] >= 0} {
        if {$i % 50 == 0} {
            set w [lrange $line 1 end]
            if {[rd [scan [lindex $line 0] %x] [llength $w]] ne $w} { incr bad }
        }
        incr i
    }
    close $fh
    if {$bad} { error "verify failed: $bad transactions differ" }
    puts "verify OK"
}

if {$cnp::axi eq ""} { error "no hw_axi found: program the device with the .bit and .ltx files, then refresh_hw_device" }
set f [file join $cnp::dir frame_load.txt]
if {![file exists $f]} { error "$f not found: run preparation.ipynb first" }

set fh [open $f r]
set n 0
while {[gets $fh line] >= 0} { incr n }
close $fh
if {$n != 3840} { error "frame_load.txt is incomplete: run preparation.ipynb again" }

reset_hw_axi $cnp::axi
cnp::check_order
cnp::load_file $f
cnp::verify_file $f

# clear the status block so retrieving_tensor.tcl waits for this run
cnp::wr 0x00FFFF00 {00000000 00000000 00000000 00000000 00000000 00000000 00000000 00000000}
puts "image sent. Press BTN0 on the board, then run retrieving_tensor.tcl"
